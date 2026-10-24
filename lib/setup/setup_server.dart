import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../backup/backup_archive.dart';
import '../backup/backup_restorer.dart';
import '../backup/backup_store.dart';
import '../backup/transfer_server.dart';
import '../channels/channel.dart';
import '../channels/channel_generator.dart';
import '../channels/channel_groups.dart';
import '../channels/premieres.dart';
import '../channels/program_block.dart';
import '../channels/schedule.dart';
import '../commercials/break_plan.dart';
import '../commercials/commercial_pool.dart';
import '../data/app_storage.dart';
import '../export/export_service.dart';
import '../export/export_settings.dart';
import '../icons/custom_icons.dart';
import '../live/live_download.dart';
import '../live/live_source.dart';
import '../live/live_source_files.dart';
import '../live/live_tv_manager.dart';
import '../live/url_privacy.dart';
import '../platform/platform_info.dart';
import '../profiles/household.dart';
import '../profiles/profile.dart';
import '../remote/remote_control.dart';
import '../server/live_tv.dart';
import '../server/media_server.dart';
import '../server/server_log.dart';
import '../server/sign_in_flow.dart';
import '../ui/format.dart';
import 'accounts.dart';
import 'api/routes.dart';
import 'web_files.dart';

part 'api/core_api.dart';
part 'api/accounts_api.dart';
part 'api/profiles_api.dart';
part 'api/library_api.dart';
part 'api/channels_api.dart';
part 'api/station_api.dart';
part 'api/live_api.dart';
part 'api/admin_api.dart';

/// Server mode's web admin and its JSON API (server-setup, admin-api), on
/// [port] (8484, or `NTV_SETUP_PORT`).
///
/// Home network only. Every route in [routes] says who may call it
/// (user-accounts' profile access), checked before it runs; every change
/// also needs the `X-Nightingale-TV: 1` header, which other web pages
/// can't send.
class SetupServer {
  SetupServer(this.household, this.accounts,
      {this.port = defaultPort, this.lanHost, this.signInFlow, WebFiles? web})
      : web = web ?? WebFiles.fromEnvironment(Platform.environment) {
    routes = ApiRoutes([
      ..._coreRoutes,
      ..._accountRoutes,
      ..._profileRoutes,
      ..._libraryRoutes,
      ..._channelRoutes,
      ..._stationRoutes,
      ..._liveRoutes,
      ..._adminRoutes,
    ]);
  }

  static const defaultPort = 8484;

  /// The header every change needs (a CSRF guard).
  static const actionHeader = 'x-nightingale-tv';
  static const sessionCookie = 'ntv_session';

  /// The most a backup upload may be.
  static const maxUpload = TransferServer.maxUpload;

  /// A borrowed state of a profile that isn't exported is let go after
  /// this long without a request for it (design D4).
  static const borrowIdle = Duration(minutes: 10);

  static const conflictText = 'Changed in another window. Showing the latest.';
  static const signedOutText = 'Sign in to this profile first.';

  final Household household;
  final Accounts accounts;
  final int port;

  /// `NTV_LAN_HOST`: the host shown in URLs; without it, the one the
  /// browser used.
  final String? lanHost;

  /// The web admin's files.
  final WebFiles web;

  /// Tests: the sign-in flow for a profile's state.
  final SignInFlow Function(AppState app)? signInFlow;

  /// Every API route.
  late final ApiRoutes routes;

  /// Who may use the page: the home network (tests change it).
  @visibleForTesting
  bool Function(InternetAddress address) allowed = RemoteControl.isPrivate;

  /// Tests: the time, for borrowed states.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  HttpServer? _server;
  Timer? _reaper;

  /// The port it listens on (the real one when [port] is 0).
  int? get boundPort => _server?.port;

  /// Sign-ins in progress (or just finished), by profile id.
  final _signIns = <String, _SignIn>{};

  /// Profiles made by Start fresh, exported once signed in.
  final _fresh = <String>{};

  /// An uploaded backup waiting for its Restore.
  ({String id, Uint8List bytes})? _upload;
  bool _restoring = false;

  /// Starts listening; throws [SocketException] when the port is taken.
  Future<void> start() async {
    final server = _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    // Server backups carry the accounts.
    household.backups?.serverSection = accounts.backupSection;
    _reaper = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(releaseIdle()));
    server.listen((r) => unawaited(_handle(r)));
  }

  Future<void> stop() async {
    _reaper?.cancel();
    for (final s in _signIns.values) {
      s.flow.dispose();
    }
    _signIns.clear();
    for (final id in [..._borrowed.keys]) {
      _borrowed.remove(id);
      await household.releaseSetup(id);
    }
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  /// The setup link: the one log line that carries the token.
  void logSetupLink(String host) {
    final token = accounts.setupToken;
    if (token != null) ServerLog.raw('Open http://$host:$port/setup?token=$token to set up Nightingale TV.');
  }

  /// Tokens of the saved sign-ins, so the log never shows one (once the
  /// household has started, and after a restore).
  Future<void> rememberSecrets() async {
    for (final p in household.profiles) {
      final session = await (await household.storageFor(p)).readRaw('session.json');
      if (session is Map<String, Object?>) {
        ServerLog.secret(session['accessToken'] as String?);
        ServerLog.secret(session['accountToken'] as String?);
      }
    }
  }

  // ---- Requests --------------------------------------------------------------

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    try {
      if (!allowed(request.connectionInfo!.remoteAddress)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      await _route(request);
    } on ApiError catch (e) {
      response.statusCode = e.status;
      if (e.message != null || e.extra != null) _json(response, {'error': ?e.message, ...?e.extra});
    } on Object catch (e, st) {
      debugPrint('Setup page request ${request.method} ${request.uri.path} failed: $e\n$st');
      try {
        response.statusCode = HttpStatus.internalServerError;
        _json(response, {'error': 'Something went wrong: $e'});
      } on Object {
        // Headers already sent.
      }
    } finally {
      await response.close();
    }
  }

  Future<void> _route(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/health') {
      final ok = household.started && !_restoring;
      request.response.statusCode = ok ? HttpStatus.ok : HttpStatus.serviceUnavailable;
      _json(request.response, {'status': ok ? 'ok' : 'starting'});
      return;
    }
    if (path == '/api' || path.startsWith('/api/')) {
      final segments = request.uri.pathSegments;
      if (segments.length < 3 || segments[1] != 'v1') throw ApiError(HttpStatus.notFound);
      return _api(request, segments.sublist(2));
    }
    if (request.method == 'GET' || request.method == 'HEAD') return web.serve(request, path);
    throw ApiError(HttpStatus.notFound);
  }

  Future<void> _api(HttpRequest request, List<String> path) async {
    final method = request.method == 'HEAD' ? 'GET' : request.method;
    // Other web pages can't add this header.
    if (method != 'GET' && request.headers.value(actionHeader) != '1') throw ApiError(HttpStatus.forbidden);
    final found = routes.find(method, path) ?? (throw ApiError(HttpStatus.notFound));
    final route = found.route;
    final session = _cookie(request);
    final r = ApiRequest(request, found.params, account: accounts.accountFor(session), session: session);
    _checkAccess(route, r);
    if (route.needsIfMatch) {
      final sent = request.headers.value(HttpHeaders.ifMatchHeader);
      if (sent == null) throw ApiError(HttpStatus.preconditionRequired, 'Reload the page and try again.');
      if (sent != _etag(route, r)) await _conflict(path, r);
    }
    final result = await route.handler(r);
    if (route.changes) _bump(route, r);
    if (route.revision != Revision.none && request.response.headers.value(HttpHeaders.etagHeader) == null) {
      request.response.headers.set(HttpHeaders.etagHeader, _etag(route, r));
    }
    if (!identical(result, ApiRequest.handled)) _json(request.response, result);
  }

  /// Refuses a stale edit with 409 and the current data (what the GET of
  /// the same path answers).
  Future<Never> _conflict(List<String> path, ApiRequest r) async {
    final get = routes.find('GET', path);
    Object? current;
    if (get != null) {
      final read = ApiRequest(r.http, get.params, account: r.account, session: r.session);
      current = await get.route.handler(read);
      r.response.headers.set(HttpHeaders.etagHeader, _etag(get.route, read));
    }
    throw ApiError(HttpStatus.conflict, conflictText, {'current': current});
  }

  // ---- Access (design D7) -------------------------------------------------------

  static const pinText = "Enter this profile's PIN.";
  static const grownUpText = "Enter a grown-up's PIN to change a kid profile's settings.";
  static const notYoursText = "That profile isn't assigned to you.";

  void _checkAccess(ApiRoute route, ApiRequest r) {
    if (route.access == Access.public) return;
    final account = r.account ?? (throw ApiError(HttpStatus.unauthorized, 'Sign in first.'));
    switch (route.access) {
      case Access.public || Access.signedIn:
        return;
      case Access.admin:
        if (!account.isAdmin) throw ApiError(HttpStatus.forbidden, 'Only an admin can do that.');
      case Access.profile || Access.profileSettings:
        final id = r['id'];
        if (!account.mayUse(id)) throw ApiError(HttpStatus.forbidden, notYoursText);
        final profile = household.profileById(id) ?? (throw ApiError(HttpStatus.notFound, 'No such profile.'));
        if (account.isAdmin) return;
        if (profile.hasPin && !accounts.profileUnlocked(r.session, id)) {
          throw ApiError(HttpStatus.forbidden, pinText, {'needs': 'pin'});
        }
        if (route.access == Access.profileSettings && profile.isKid && !accounts.grownUpUnlocked(r.session)) {
          throw ApiError(HttpStatus.forbidden, grownUpText, {'needs': 'grownUp'});
        }
    }
  }

  // ---- Revisions (design D5) ------------------------------------------------------

  // Bumped by every change made through the API, a sign-in and a restore.
  // Background refreshes (library scans, live sources) only touch what the
  // server owns (playlists, anchors, guides), so they don't make an edit
  // in progress stale.

  final _profileRevisions = <String, int>{};
  int _householdRevision = 1;

  int profileRevision(String id) => _profileRevisions[id] ?? 1;
  int get householdRevision => _householdRevision;

  String _etag(ApiRoute route, ApiRequest r) => switch (route.revision) {
        Revision.profile => '"p${profileRevision(r['id'])}"',
        Revision.household => '"h$_householdRevision"',
        Revision.none => '',
      };

  void _bump(ApiRoute route, ApiRequest r) {
    switch (route.revision) {
      case Revision.profile:
        _bumpProfile(r['id']);
      case Revision.household:
        _householdRevision++;
      case Revision.none:
        break;
    }
  }

  void _bumpProfile(String id) => _profileRevisions[id] = profileRevision(id) + 1;

  /// A restore replaced everything.
  void _bumpAll() {
    _householdRevision++;
    for (final p in household.profiles) {
      _bumpProfile(p.id);
    }
    for (final id in [..._profileRevisions.keys]) {
      _bumpProfile(id);
    }
  }

  // ---- Profile states (design D4) -----------------------------------------------

  /// States lent for requests about profiles that aren't exported, and when
  /// each was last used.
  final _borrowed = <String, DateTime>{};

  /// [id]'s state: the exported one, else one lent until [borrowIdle]
  /// passes without a request. With [library], a signed-out profile is
  /// refused with 503.
  Future<AppState> _app(String id, {bool library = false}) async {
    if (household.appFor(id) == null) _borrowed[id] = clock();
    // An exported profile's state may still be loading: this waits for it.
    final app = await household.appForSetup(id) ?? (throw ApiError(HttpStatus.notFound, 'No such profile.'));
    if (library && (app.phase == AppPhase.signedOut || app.session == null)) {
      throw ApiError(HttpStatus.serviceUnavailable, signedOutText);
    }
    return app;
  }

  /// Lets go of borrowed states unused for [borrowIdle] (run every minute).
  @visibleForTesting
  Future<void> releaseIdle() async {
    final now = clock();
    for (final e in [..._borrowed.entries]) {
      if (now.difference(e.value) < borrowIdle) continue;
      // A sign-in in progress keeps it; an exported profile has it off-screen.
      if (_signIns[e.key]?.flow.finished == false) continue;
      _borrowed.remove(e.key);
      await household.releaseSetup(e.key);
    }
  }

  /// Whether a borrowed state of [id] is open (tests).
  @visibleForTesting
  bool isBorrowed(String id) => _borrowed.containsKey(id);

  // ---- Helpers ----------------------------------------------------------------

  String? _cookie(HttpRequest r) => r.cookies.where((c) => c.name == sessionCookie).firstOrNull?.value;

  void _setCookie(HttpResponse response, String value, Duration life) {
    response.headers.add(HttpHeaders.setCookieHeader,
        '$sessionCookie=$value; Path=/; Max-Age=${life.inSeconds}; HttpOnly; SameSite=Strict');
  }

  Profile _profile(String id) =>
      household.profileById(id) ?? (throw ApiError(HttpStatus.notFound, 'No such profile.'));

  static String _urlHost(String host) => host.contains(':') && !host.startsWith('[') ? '[$host]' : host;

  static Map<String, Object?>? _hintJson(Object? hint) => hint is Map<String, Object?>
      ? {
          'kind': hint['kind'] ?? 'jellyfin',
          'server': hint['serverUrl'],
          'serverName': hint['serverName'],
          'user': hint['userName'],
        }
      : null;

  static void _json(HttpResponse response, Object? data) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
  }
}

class _SignIn {
  _SignIn(this.app, this.flow);
  final AppState app;
  final SignInFlow flow;
  bool done = false;
}
