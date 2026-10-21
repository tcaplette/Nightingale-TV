import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../channels/channel.dart';
import '../remote/remote_control.dart';
import 'export_settings.dart';
import 'm3u_writer.dart';
import 'xmltv_writer.dart';

/// Plays a channel as one continuous stream (channel-streaming spec).
abstract interface class ChannelStreamer {
  Future<void> serve(HttpRequest request, LineupServer server, AppState app, Channel channel);
}

/// Draws a channel's logo as a PNG.
abstract interface class LogoSource {
  Future<Uint8List?> pngFor(AppState app, Channel channel);
}

/// Answers the HDHomeRun endpoints (`discover.json` and so on); null for
/// paths it doesn't know.
typedef DeviceEndpoints = Future<bool> Function(HttpRequest request, LineupServer server, List<Channel> lineup);

/// One exported profile's server: its M3U, XMLTV, images, tuner endpoints
/// and streams, on its own port, for the home network only.
class LineupServer {
  LineupServer({
    required this.profileId,
    required this.appFor,
    required this.profileName,
    required this.export,
    this.streamer,
    this.logos,
    this.device,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String profileId;

  /// The profile's state right now (it changes when it moves on or off
  /// screen, or is reloaded).
  final AppState? Function() appFor;
  final String Function() profileName;

  /// Port and tuner identity.
  ProfileExport export;
  final ChannelStreamer? streamer;
  final LogoSource? logos;
  final DeviceEndpoints? device;
  final http.Client _http;

  HttpServer? _server;

  int? get port => _server?.port;
  bool get running => _server != null;

  /// Opens [port] (the saved one; 0 in tests). Throws [SocketException]
  /// when it's taken: the caller reports it rather than trying another.
  Future<void> start({int? port}) async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port ?? export.port);
    server.listen((r) => unawaited(_handle(r)));
    _server = server;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _dropGuide();
    await server?.close(force: true);
  }

  /// The profile's state, when it has a lineup to serve: signed in, with
  /// channels.
  AppState? get app {
    final app = appFor();
    if (app == null || app.client == null || app.phase == AppPhase.signedOut) return null;
    return app;
  }

  /// The channels served: visible ones, by number; none while signed out.
  List<Channel> lineupOf(AppState? app) => app?.channels ?? const [];

  /// The address clients reached this server at.
  static ExportUrls urlsFor(HttpRequest request) {
    final u = request.requestedUri;
    return ExportUrls(Uri(scheme: 'http', host: u.host, port: u.port));
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    var streaming = false;
    try {
      if (!RemoteControl.isPrivate(request.connectionInfo!.remoteAddress)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final path = request.uri.path;
      final app = this.app;
      final lineup = lineupOf(app);
      if (request.method != 'GET' && request.method != 'HEAD' && request.method != 'POST') {
        response.statusCode = HttpStatus.methodNotAllowed;
      } else if (path == '/lineup.m3u' || path == '/playlist.m3u') {
        response.headers.contentType = ContentType('audio', 'x-mpegurl', charset: 'utf-8');
        response.headers.set('Cache-Control', 'no-store');
        final profile = profileName();
        response.write(buildM3u(
            channels: lineup,
            urls: urlsFor(request),
            profileName: profile,
            groupOf: app == null ? null : (c) => app.m3uGroupFor(c, fallback: profileGroup(profile))));
      } else if (path == '/xmltv.xml' || path == '/guide.xml') {
        response.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
        response.headers.set('Cache-Control', 'no-store');
        response.write(app == null ? _emptyGuide : _guide(app, urlsFor(request)));
      } else if (path.startsWith('/images/') && path.endsWith('.jpg')) {
        await _image(response, app, path.substring('/images/'.length, path.length - '.jpg'.length));
      } else if (path.startsWith('/logos/') && path.endsWith('.png')) {
        await _logo(response, app, lineup, path.substring('/logos/'.length, path.length - '.png'.length));
      } else if (path.startsWith('/stream/') && path.endsWith('.ts')) {
        final number = int.tryParse(path.substring('/stream/'.length, path.length - '.ts'.length));
        final channel = lineup.where((c) => c.number == number).firstOrNull;
        final streamer = this.streamer;
        if (app == null || channel == null || streamer == null) {
          response.statusCode = HttpStatus.notFound;
        } else {
          streaming = true;
          await streamer.serve(request, this, app, channel);
        }
      } else if (device != null && await device!(request, this, lineup)) {
        // Answered.
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } on Object catch (e) {
      debugPrint('Live TV export request failed: $e');
      if (!streaming) {
        try {
          response.statusCode = HttpStatus.internalServerError;
        } on StateError {
          // Headers already sent.
        }
      }
    } finally {
      if (!streaming) {
        try {
          await response.close();
        } on Object {
          // The client went away.
        }
      }
    }
  }

  // ---- XMLTV ---------------------------------------------------------------

  static const _emptyGuide = '<?xml version="1.0" encoding="UTF-8"?>\n<tv generator-info-name="Nightingale TV">\n</tv>\n';

  ({AppState app, DateTime hour, String host, String doc})? _cachedGuide;
  AppState? _guideApp;

  /// The guide, cached until the profile changes anything or the hour
  /// turns.
  String _guide(AppState app, ExportUrls urls) {
    final now = DateTime.now();
    final hour = DateTime(now.year, now.month, now.day, now.hour);
    final host = '${urls.base}';
    final cached = _cachedGuide;
    if (cached != null && identical(cached.app, app) && cached.hour == hour && cached.host == host) return cached.doc;
    if (!identical(_guideApp, app)) {
      _guideApp?.removeListener(_dropCachedGuide);
      _guideApp = app..addListener(_dropCachedGuide);
    }
    final doc = buildXmltv(
        channels: lineupOf(app), scheduleFor: app.scheduleFor, library: app.library, urls: urls, now: now);
    _cachedGuide = (app: app, hour: hour, host: host, doc: doc);
    return doc;
  }

  void _dropCachedGuide() => _cachedGuide = null;

  void _dropGuide() {
    _guideApp?.removeListener(_dropCachedGuide);
    _guideApp = null;
    _cachedGuide = null;
  }

  @visibleForTesting
  bool get hasCachedGuide => _cachedGuide != null;

  // ---- Images --------------------------------------------------------------

  /// Posters by item id, most recently used last.
  final _posters = <String, ({List<int> bytes, String type})>{};
  static const _posterCacheSize = 200;

  /// Only posters the guide refers to: series (for episodes) and movies in
  /// this profile's library. Anything else is 404 without asking Jellyfin.
  Future<void> _image(HttpResponse response, AppState? app, String id) async {
    final library = app?.library;
    final client = app?.client;
    final allowed = library != null &&
        (library.series.any((s) => s.id == id) || library.movies.any((m) => m.id == id));
    if (!allowed || client == null) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    var poster = _posters.remove(id);
    if (poster == null) {
      final uri = client.imageUri(id, 'Primary', maxHeight: 600);
      final upstream = await _http
          .get(uri.replace(queryParameters: {...uri.queryParameters, 'format': 'Jpg'}), headers: client.authHeaders)
          .timeout(const Duration(seconds: 15));
      if (upstream.statusCode != HttpStatus.ok) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      poster = (bytes: upstream.bodyBytes, type: upstream.headers['content-type'] ?? 'image/jpeg');
      if (_posters.length >= _posterCacheSize) _posters.remove(_posters.keys.first);
    }
    _posters[id] = poster;
    response.headers.set('Content-Type', poster.type);
    response.headers.set('Cache-Control', 'max-age=86400');
    response.add(poster.bytes);
  }

  Future<void> _logo(HttpResponse response, AppState? app, List<Channel> lineup, String number) async {
    final channel = lineup.where((c) => '${c.number}' == number).firstOrNull;
    final png = app == null || channel == null ? null : await logos?.pngFor(app, channel);
    if (png == null) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    response.headers.contentType = ContentType('image', 'png');
    response.headers.set('Cache-Control', 'max-age=86400');
    response.add(png);
  }

  /// JSON answer helper for [device] endpoints.
  static void json(HttpResponse response, Object? data) {
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    response.write(jsonEncode(data));
  }
}
