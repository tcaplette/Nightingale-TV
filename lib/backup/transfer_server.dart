import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../playback/playback_diagnostics.dart';
import '../remote/remote_control.dart';
import 'backup_archive.dart';
import 'backup_scheduler.dart';
import 'backup_store.dart';
import 'transfer_page.dart';

/// "Use your phone or computer" (D12): a short-lived page on the home
/// network, at an address holding a random token, that downloads a fresh
/// backup and takes one to restore. It runs while its dialog is open, and
/// stops after [idleTimeout] with no requests.
class TransferServer {
  TransferServer(this.backups, {required this.onUpload, this.onIdle, this.idleTimeout = const Duration(minutes: 15)});

  final BackupScheduler backups;

  /// An uploaded backup, checked and kept in the store as "From a file":
  /// the TV opens its restore confirmation.
  final void Function(StoredBackup backup) onUpload;

  /// The page stopped for lack of requests.
  final void Function()? onIdle;

  final Duration idleTimeout;

  /// The most an upload may be.
  static const maxUpload = 32 * 1024 * 1024;

  HttpServer? _server;
  Timer? _idle;
  late final String _token = _newToken();

  /// Where phones and computers open the page, while it runs.
  Uri? url;

  bool get running => _server != null;

  /// 128 random bits.
  static String _newToken() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<Uri> start() async {
    final server = _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    server.listen(_handle);
    url = Uri(scheme: 'http', host: await RemoteControl.lanAddress() ?? 'localhost', port: server.port, path: '/b/$_token/');
    _touch();
    return url!;
  }

  Future<void> stop() async {
    _idle?.cancel();
    _idle = null;
    final server = _server;
    _server = null;
    url = null;
    await server?.close(force: true);
  }

  void _touch() {
    _idle?.cancel();
    _idle = Timer(idleTimeout, () {
      unawaited(stop());
      onIdle?.call();
    });
  }

  /// A backup file's name: `nightingale-tv-2026-10-20-2105.ntvbackup`.
  static String fileName(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'nightingale-tv-${l.year}-${two(l.month)}-${two(l.day)}-${two(l.hour)}${two(l.minute)}${BackupStore.extension}';
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    final segments = request.uri.pathSegments;
    // What diagnostics log: never the token.
    final logged = segments.length >= 2 && segments[0] == 'b' ? '/b/…/${segments.skip(2).join('/')}' : request.uri.path;
    try {
      if (!RemoteControl.isPrivate(request.connectionInfo!.remoteAddress)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (segments.length < 2 || segments[0] != 'b' || segments[1] != _token || segments.length > 3) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      _touch();
      if (segments.length == 2) {
        // The page's links are relative to its folder.
        response.statusCode = HttpStatus.movedPermanently;
        response.headers.set(HttpHeaders.locationHeader, '/b/$_token/');
        return;
      }
      final action = segments[2];
      if (request.method == 'GET' && action == '') {
        response.headers.contentType = ContentType.html;
        response.write(transferPageHtml());
      } else if (request.method == 'GET' && action == 'backup') {
        final built = await backups.build(BackupReason.manual);
        response.headers
          ..contentType = ContentType('application', 'octet-stream')
          ..set('Content-Disposition', 'attachment; filename="${fileName(built.createdAt)}"')
          ..contentLength = built.bytes.length;
        response.add(built.bytes);
      } else if (request.method == 'POST' && action == 'restore') {
        await _upload(request);
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } on Object catch (e) {
      debugPrint('Transfer page request failed: $e');
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      PlaybackDiagnostics.note('TRANSFER', '${request.method} $logged ${response.statusCode}');
      await response.close();
    }
  }

  Future<void> _upload(HttpRequest request) async {
    final response = request.response;
    // Other web pages can't add this header (see RemoteControl.actionHeader).
    if (request.headers.value(RemoteControl.actionHeader) != '1') {
      response.statusCode = HttpStatus.forbidden;
      return;
    }
    void tooBig() {
      // Answered at once, and the rest of the upload isn't read: the
      // connection closes.
      response
        ..statusCode = HttpStatus.requestEntityTooLarge
        ..persistentConnection = false;
      _json(response, {'error': BackupArchive.tooBig});
    }

    if (request.contentLength > maxUpload) return tooBig();
    final body = BytesBuilder(copy: false);
    await for (final chunk in request) {
      body.add(chunk);
      if (body.length > maxUpload) return tooBig();
    }
    final bytes = body.takeBytes();
    try {
      BackupArchive.check(bytes);
    } on BackupException catch (e) {
      response.statusCode = HttpStatus.badRequest;
      _json(response, {'error': e.message});
      return;
    }
    final stored = await backups.store.save(bytes, kind: BackupReason.file);
    backups.changed();
    _json(response, {'ok': true});
    onUpload(stored);
  }

  static void _json(HttpResponse response, Object? data) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
  }
}
