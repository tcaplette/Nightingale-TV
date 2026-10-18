import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../playback/tuner.dart';
import '../profiles/household.dart';
import 'key_dispatch.dart';
import 'remote_page.dart';

typedef KeyDispatcher = bool Function(LogicalKeyboardKey key, PhysicalKeyboardKey physical);

/// The phone remote: a small web server on the home network whose page
/// works like the TV's remote. Off until turned on in the menu.
class RemoteControl extends ChangeNotifier {
  RemoteControl(this.household, {this._dispatch = dispatchKey, this._wake});

  static const _settingsFile = 'remote.json';
  static const defaultPort = 8642;

  /// Requests that change something must carry this header. Browsers won't
  /// let other websites add it without permission, which this server never
  /// gives, so a web page can't drive the TV behind the user's back.
  static const actionHeader = 'x-nightingale-remote';

  final Household household;
  final KeyDispatcher _dispatch;

  /// Brings the TV window to the front, so key presses reach it.
  final Future<void> Function()? _wake;

  /// The tuner of whoever is watching; attached by the UI.
  Tuner? tuner;

  bool enabled = false;
  HttpServer? _server;
  String? error;

  /// Where phones can reach the remote, while it's running.
  Uri? url;

  int? get port => _server?.port;

  Future<void> load() async {
    final json = await household.root.readJson(_settingsFile);
    enabled = json is Map<String, Object?> && json['enabled'] == true;
    if (enabled) await _start();
  }

  Future<void> setEnabled(bool on, {int port = defaultPort}) async {
    enabled = on;
    await household.root.writeJson(_settingsFile, {'enabled': on});
    if (on) {
      await _start(port: port);
    } else {
      await stop();
    }
    notifyListeners();
  }

  Future<void> _start({int port = defaultPort}) async {
    if (_server != null) return;
    error = null;
    // Try a few ports in case something else is using ours.
    for (var p = port; p < port + 10; p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        break;
      } on SocketException {
        if (port == 0) break;
      }
    }
    final server = _server;
    if (server == null) {
      error = 'Couldn\'t open a network port for the remote.';
      notifyListeners();
      return;
    }
    server.listen(_handle);
    url = Uri(scheme: 'http', host: await lanAddress() ?? 'localhost', port: server.port);
    notifyListeners();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    url = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// This PC's address on the home network.
  static Future<String?> lanAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final addresses = [for (final i in interfaces) ...i.addresses.where(isPrivate)]
        .where((a) => !a.isLoopback)
        .toList()
      // Home routers almost always hand out 192.168.x.x.
      ..sort((a, b) => (b.address.startsWith('192.168.') ? 1 : 0) - (a.address.startsWith('192.168.') ? 1 : 0));
    return addresses.firstOrNull?.address;
  }

  /// Loopback, or a private (home network) address.
  static bool isPrivate(InternetAddress a) {
    if (a.isLoopback || a.isLinkLocal) return true;
    if (a.type != InternetAddressType.IPv4) return false;
    final b = a.rawAddress;
    return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] < 32) || (b[0] == 192 && b[1] == 168);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    try {
      if (!isPrivate(request.connectionInfo!.remoteAddress)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final path = request.uri.path;
      if (request.method == 'GET' && (path == '/' || path == '/index.html')) {
        response.headers.contentType = ContentType.html;
        response.write(remotePageHtml);
      } else if (request.method == 'GET' && path == '/api/state') {
        _json(response, state());
      } else if (request.method == 'POST' && path.startsWith('/api/')) {
        if (request.headers.value(actionHeader) != '1') {
          response.statusCode = HttpStatus.forbidden;
          return;
        }
        final body = jsonDecode(await utf8.decodeStream(request));
        if (body is! Map<String, Object?>) throw const FormatException('Expected a JSON object');
        switch (path) {
          case '/api/key':
            final key = remoteKeys[body['key']];
            if (key == null) throw FormatException('Unknown key ${body['key']}');
            await _wake?.call();
            _json(response, {'handled': _dispatch(key.$1, key.$2)});
          case '/api/tune':
            final number = body['number'];
            if (number is! int) throw const FormatException('Expected a channel number');
            await _wake?.call();
            _json(response, {'tuned': await tuner?.tuneNumber(number) ?? false});
          default:
            response.statusCode = HttpStatus.notFound;
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } on FormatException catch (e) {
      response.statusCode = HttpStatus.badRequest;
      _json(response, {'error': e.message});
    } on Object catch (e) {
      debugPrint('Remote request failed: $e');
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  static void _json(HttpResponse response, Object? data) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
  }

  /// What the remote page shows: who's watching, what's on, the lineup.
  Map<String, Object?> state() {
    final app = household.app;
    final profile = household.current;
    if (app == null || profile == null) return {'profile': null};
    final now = DateTime.now();
    final channel = tuner?.channel;
    Map<String, Object?>? program;
    final p = tuner?.program;
    if (p != null) {
      program = {
        'title': p.title,
        'subtitle': p.subtitle,
        'start': p.start.toIso8601String(),
        'end': p.end.toIso8601String(),
        if (p.blockTitle != null) 'block': p.blockTitle,
        'commercial': tuner?.inBreak ?? false,
      };
    }
    return {
      'profile': profile.name,
      'kid': profile.isKid,
      'now': now.toIso8601String(),
      if (channel != null) 'channel': {'number': channel.number, 'name': channel.name},
      'program': program,
      'channels': [
        for (final c in app.channels)
          {
            'number': c.number,
            'name': c.name,
            'now': app.scheduleFor(c)?.programAt(now).title,
          },
      ],
    };
  }
}
