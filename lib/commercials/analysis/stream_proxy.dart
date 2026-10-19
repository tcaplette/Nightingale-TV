import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// How fast the proxy may download for the analyzer.
@immutable
class Budget {
  const Budget.unlimited()
      : bytesPerSecond = null,
        paused = false;

  /// Nothing is read from upstream; TCP backpressure holds the transfer
  /// where it is, so no data is lost.
  const Budget.paused()
      : bytesPerSecond = 0,
        paused = true;

  /// At most [bytesPerSecond] in any 1-second window.
  const Budget.limited(int this.bytesPerSecond) : paused = false;

  final int? bytesPerSecond;
  final bool paused;

  bool get unlimited => bytesPerSecond == null;

  List<Object?> toMessage() => [paused, bytesPerSecond];

  static Budget fromMessage(List<Object?> m) => switch (m) {
        [true, _] => const Budget.paused(),
        [false, final int rate] => Budget.limited(rate),
        _ => const Budget.unlimited(),
      };

  @override
  bool operator ==(Object other) => other is Budget && other.paused == paused && other.bytesPerSecond == bytesPerSecond;

  @override
  int get hashCode => Object.hash(paused, bytesPerSecond);

  @override
  String toString() => paused ? 'Budget.paused' : unlimited ? 'Budget.unlimited' : 'Budget.limited($bytesPerSecond B/s)';
}

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

  /// The download budget; [start] applies it, and [setBudget] changes it.
  Budget budget = const Budget.unlimited();

  /// Changes the download budget, including for transfers in progress.
  Future<void> setBudget(Budget b) async {
    budget = b;
    if (running) await _send(['budget', ...b.toMessage()]);
  }

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
    await setBudget(budget);
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

  /// Bytes sent to ffmpeg since [start] (0 when not running), for
  /// diagnostics.
  Future<int> bytesServed() async => running ? (await _send(['stats']) as int? ?? 0) : 0;

  Future<Object?> _send(List<Object?> command) async {
    final local = _local;
    if (local != null) return local.handle(command);
    final commands = _commands;
    if (commands == null) throw StateError('The stream proxy is not running.');
    final reply = ReceivePort();
    commands.send([...command, reply.sendPort]);
    return reply.first;
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
    reply.send(await core.handle(command));
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

  /// Shared by every transfer, so the budget is for the analyzer as a whole.
  final _bucket = _TokenBucket();

  /// Bytes sent to ffmpeg so far.
  int _served = 0;

  Future<int> bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((r) => unawaited(_handle(r)));
    return server.port;
  }

  Future<Object?> handle(List<Object?> command) async {
    switch (command) {
      case ['stats']:
        return _served;
      case ['allow', final String id, final String uri, final Map<String, String> headers]:
        _allowed[id] = (Uri.parse(uri), headers);
      case ['disallow', final String id]:
        _allowed.remove(id);
      case ['budget', final bool paused, final int? rate]:
        _bucket.budget = Budget.fromMessage([paused, rate]);
      case ['close']:
        await close();
    }
    return null;
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
      await response.addStream(_metered(upstream.stream));
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

  /// [source] at the budget's pace. Waiting for the budget stops reading
  /// [source], so the upstream transfer stalls instead of buffering here.
  Stream<List<int>> _metered(Stream<List<int>> source) async* {
    await for (final chunk in source) {
      if (_bucket.budget.unlimited) {
        _served += chunk.length;
        yield chunk;
        continue;
      }
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      var at = 0;
      while (at < bytes.length) {
        final n = min(bytes.length - at, _bucket.piece);
        await _bucket.take(n);
        if (_bucket.budget.unlimited) {
          // Lifted while waiting: send the rest at once.
          _served += bytes.length - at;
          yield Uint8List.sublistView(bytes, at);
          break;
        }
        _served += n;
        yield Uint8List.sublistView(bytes, at, at + n);
        at += n;
      }
    }
  }

  Future<void> close() async {
    _allowed.clear();
    _bucket.budget = const Budget.unlimited();
    client.close();
    await _server?.close(force: true);
    _server = null;
  }
}

/// A token bucket that keeps any 1-second window within the budget: it
/// refills at 90% of the rate and holds at most 10% (a burst can't push a
/// window over), starting empty after a change.
class _TokenBucket {
  Budget _budget = const Budget.unlimited();
  double _tokens = 0;
  final _clock = Stopwatch()..start();
  Duration _refilledAt = Duration.zero;
  Completer<void>? _changed;

  Budget get budget => _budget;

  set budget(Budget b) {
    if (b == _budget) return;
    _budget = b;
    _tokens = 0;
    _refilledAt = _clock.elapsed;
    _changed?.complete();
    _changed = null;
  }

  double get _rate => (_budget.bytesPerSecond ?? 0) * 0.9;
  double get _burst => (_budget.bytesPerSecond ?? 0) * 0.1;

  /// The most bytes taken at once.
  int get piece => max(1, min(64 * 1024, _burst.floor()));

  void _refill() {
    final now = _clock.elapsed;
    _tokens = min(_burst, _tokens + _rate * (now - _refilledAt).inMicroseconds / 1e6);
    _refilledAt = now;
  }

  /// Waits until [n] bytes (at most [piece]) may be sent.
  Future<void> take(int n) async {
    while (true) {
      final b = _budget;
      if (b.unlimited) return;
      Duration? wait;
      if (!b.paused) {
        _refill();
        if (_tokens >= n) {
          _tokens -= n;
          return;
        }
        wait = Duration(microseconds: ((n - _tokens) / _rate * 1e6).ceil());
      }
      final changed = (_changed ??= Completer<void>()).future;
      final done = Completer<void>();
      void wake([_]) {
        if (!done.isCompleted) done.complete();
      }

      final timer = wait == null ? null : Timer(wait, wake);
      unawaited(changed.then(wake));
      await done.future;
      timer?.cancel();
    }
  }
}
