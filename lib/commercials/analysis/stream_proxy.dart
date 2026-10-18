import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Lets ffmpeg read Jellyfin streams without the access token ever being on
/// a command line (`/proc/<pid>/cmdline` is readable by any local user).
///
/// It listens on the loopback address only, behind a random per-session
/// path secret, and serves only the items currently [allow]ed. It forwards
/// `Range` (ffmpeg seeks in MP4s and in windowed scans) and adds Jellyfin's
/// auth headers itself.
///
/// The server runs in a background isolate, so copying gigabytes of video
/// never competes with drawing the UI. Given [httpClient] (tests), it runs
/// in this isolate instead.
class LoopbackStreamProxy {
  LoopbackStreamProxy({required this.upstream, required this.headers, http.Client Function()? httpClient})
      : _testClient = httpClient;

  /// The Jellyfin stream URL for an item.
  final Uri Function(String itemId) upstream;

  /// The auth headers to send upstream.
  final Map<String, String> Function() headers;
  final http.Client Function()? _testClient;

  _ProxyCore? _local;
  Isolate? _isolate;
  SendPort? _commands;
  int? _port;
  String? _secret;

  bool get running => _port != null;

  Future<void> start() async {
    if (_port != null) return;
    final rng = Random.secure();
    final secret = List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final testClient = _testClient;
    if (testClient != null) {
      final core = _local = _ProxyCore(secret, testClient());
      _port = await core.bind();
    } else {
      final ready = ReceivePort();
      _isolate = await Isolate.spawn(_serve, (ready.sendPort, secret), debugName: 'stream proxy');
      final (SendPort commands, int port) = await ready.first as (SendPort, int);
      _commands = commands;
      _port = port;
    }
    _secret = secret;
  }

  /// The URL ffmpeg reads [itemId] from. [start] first.
  Uri urlFor(String itemId) {
    final port = _port;
    if (port == null) throw StateError('The stream proxy is not running.');
    return Uri(scheme: 'http', host: '127.0.0.1', port: port, path: '/$_secret/$itemId');
  }

  /// Serves [itemId] (once this completes) until [disallow]ed.
  Future<void> allow(String itemId) =>
      _send(['allow', itemId, upstream(itemId).toString(), Map<String, String>.of(headers())]);

  Future<void> disallow(String itemId) => _send(['disallow', itemId]);

  Future<void> _send(List<Object?> command) async {
    final local = _local;
    if (local != null) return local.handle(command);
    final commands = _commands;
    if (commands == null) throw StateError('The stream proxy is not running.');
    final reply = ReceivePort();
    commands.send([...command, reply.sendPort]);
    await reply.first;
  }

  /// Stops listening and drops any streams in flight. A new [start] picks a
  /// new secret.
  Future<void> close() async {
    if (_port == null) return;
    _port = null;
    _secret = null;
    final local = _local;
    _local = null;
    if (local != null) {
      await local.close();
      return;
    }
    final reply = ReceivePort();
    _commands?.send(['close', reply.sendPort]);
    await reply.first.timeout(const Duration(seconds: 5), onTimeout: () => null);
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commands = null;
  }
}

/// The background isolate: binds, reports its port, then follows commands.
Future<void> _serve((SendPort, String) args) async {
  final (ready, secret) = args;
  final core = _ProxyCore(secret, http.Client());
  final port = await core.bind();
  final commands = ReceivePort();
  ready.send((commands.sendPort, port));
  await for (final message in commands) {
    final command = (message as List<Object?>).sublist(0, message.length - 1);
    final reply = message.last as SendPort;
    await core.handle(command);
    reply.send(null);
    if (command.first == 'close') {
      commands.close();
      break;
    }
  }
}

/// The proxy server itself.
class _ProxyCore {
  _ProxyCore(this.secret, this.client);

  final String secret;
  final http.Client client;
  HttpServer? _server;

  /// Allowed item ids → their stream URL and auth headers.
  final _allowed = <String, (Uri, Map<String, String>)>{};

  Future<int> bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((r) => unawaited(_handle(r)));
    return server.port;
  }

  Future<void> handle(List<Object?> command) async {
    switch (command) {
      case ['allow', final String id, final String uri, final Map<String, String> headers]:
        _allowed[id] = (Uri.parse(uri), headers);
      case ['disallow', final String id]:
        _allowed.remove(id);
      case ['close']:
        await close();
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final parts = request.uri.pathSegments;
      final target = parts.length == 2 && parts[0] == secret ? _allowed[parts[1]] : null;
      if (target == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final (uri, headers) = target;
      final forward = http.Request('GET', uri)..headers.addAll(headers);
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) forward.headers[HttpHeaders.rangeHeader] = range;
      final upstream = await client.send(forward);
      response.statusCode = upstream.statusCode;
      for (final name in const [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
      ]) {
        final value = upstream.headers[name];
        if (value != null) response.headers.set(name, value);
      }
      final length = upstream.contentLength;
      if (length != null) response.headers.contentLength = length;
      await response.addStream(upstream.stream);
    } on Object catch (e) {
      // ffmpeg closes connections when it seeks; that's not an error.
      if (e is! HttpException && e is! SocketException) debugPrint('Stream proxy: $e');
      try {
        response.statusCode = HttpStatus.badGateway;
      } on StateError {
        // Headers already sent.
      }
    } finally {
      try {
        await response.close();
      } on Object {
        // The reader is gone.
      }
    }
  }

  Future<void> close() async {
    _allowed.clear();
    client.close();
    await _server?.close(force: true);
    _server = null;
  }
}
