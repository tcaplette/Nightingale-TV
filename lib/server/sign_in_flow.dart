import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../jellyfin/jellyfin_client.dart';
import 'media_server.dart';
import 'plex/plex_account.dart';
import 'plex/plex_connections.dart';
import 'server_clients.dart';
import 'server_set.dart';
import '../l10n/tr.dart';
import '../reporting/error_reports.dart';
import '../reporting/report_breadcrumbs.dart';

/// What the address step found: a client for the server, and its info.
typedef IdentifiedServer = ({MediaServer client, ServerInfo info});

/// Where a sign-in is (server-sign-in, media-servers).
enum SignInStage { server, method, password, quickConnect, plexCode, plexUsers, plexPin, plexServers }

/// Everything a sign-in view shows at one moment.
@immutable
class SignInStep {
  const SignInStep({
    this.stage = SignInStage.server,
    this.busy = false,
    this.error,
    this.info,
    this.quickConnectAvailable = false,
    this.quickConnectCode,
    this.plexCode,
    this.homeUsers = const [],
    this.homeUser,
    this.servers,
    this.added = const {},
  });

  final SignInStage stage;

  /// A request is running.
  final bool busy;
  final String? error;

  /// The Jellyfin or Emby server the address step found (or Plex's, when
  /// an address was typed).
  final ServerInfo? info;
  final bool quickConnectAvailable;
  final String? quickConnectCode;

  /// The Plex link code shown.
  final String? plexCode;
  final List<PlexHomeUser> homeUsers;

  /// The Home user whose PIN is asked.
  final PlexHomeUser? homeUser;
  final List<PlexResource>? servers;

  /// Adding a server (multi-server): the server ids already in the profile,
  /// shown as added and not pickable in the Plex server list.
  final Set<String> added;

  ServerKind get kind => info?.kind ?? ServerKind.jellyfin;

  SignInStep copyWith({
    SignInStage? stage,
    bool? busy,
    String? Function()? error,
    ServerInfo? Function()? info,
    bool? quickConnectAvailable,
    String? Function()? quickConnectCode,
    String? Function()? plexCode,
    List<PlexHomeUser>? homeUsers,
    PlexHomeUser? Function()? homeUser,
    List<PlexResource>? Function()? servers,
  }) =>
      SignInStep(
        stage: stage ?? this.stage,
        busy: busy ?? this.busy,
        error: error == null ? this.error : error(),
        info: info == null ? this.info : info(),
        quickConnectAvailable: quickConnectAvailable ?? this.quickConnectAvailable,
        quickConnectCode: quickConnectCode == null ? this.quickConnectCode : quickConnectCode(),
        plexCode: plexCode == null ? this.plexCode : plexCode(),
        homeUsers: homeUsers ?? this.homeUsers,
        homeUser: homeUser == null ? this.homeUser : homeUser(),
        servers: servers == null ? this.servers : servers(),
        added: added,
      );
}

/// Signing one profile in to Jellyfin, Emby or Plex: the TV's sign-in
/// screen and the server's setup page both drive this (design D6).
///
/// Addresses, user names and passwords come from the caller; the flow keeps
/// the server's answers and where it is in [state].
class SignInFlow {
  SignInFlow(
    this.app, {
    String? message,
    this.identify,
    PlexAccount? plexAccount,
    this.pickPlexConnection,
    this.completeSignIn,
    this.adding = false,
    this.againKey,
  })  : _givenAccount = plexAccount,
        state = ValueNotifier(SignInStep(
            error: message,
            added: adding || againKey != null ? {for (final s in app.servers.all) ?s.serverId} : const {}));

  final AppState app;

  /// Adds a server to the signed-in profile (multi-server D7) instead of
  /// signing it in.
  final bool adding;

  /// Signs the profile's server [againKey] in again, keeping its key.
  final String? againKey;

  /// The server being signed in again.
  ProfileServer? get _again => againKey == null ? null : app.servers.byKey(againKey!);

  /// Tests: what the address step asks instead of the network.
  final Future<IdentifiedServer> Function(String address)? identify;

  /// Tests: how an address is picked for a Plex server.
  final Future<PlexConnection?> Function(PlexResource server)? pickPlexConnection;

  /// Tests: what's done with a finished sign-in instead of the app's
  /// (which checks a Plex sign-in, then scans the library).
  final Future<void> Function(ServerSession session, MediaServer client)? completeSignIn;

  /// How often a link code is checked.
  static const plexPoll = Duration(seconds: 2);

  /// How often a Quick Connect code is checked.
  static const quickConnectPoll = Duration(seconds: 3);

  final ValueNotifier<SignInStep> state;
  SignInStep get step => state.value;

  /// True once the profile is signed in.
  bool get finished => _finished;
  bool _finished = false;

  final PlexAccount? _givenAccount;
  PlexAccount? _account;
  JellyfinClient? _client;
  QuickConnectRequest? _quickConnect;
  PlexPin? _pin;
  String? _linkedToken;
  String? _userToken;
  Timer? _poll;
  bool _disposed = false;

  /// The server (machine id) and Home user (plex.tv id) to choose without
  /// asking: from the address typed, or a restored profile's backup.
  String? _wantedServer;
  String? _wantedUser;

  void _set(SignInStep next) {
    if (!_disposed) state.value = next;
  }

  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _client?.close();
    if (_givenAccount == null) _account?.close();
  }

  /// A restored profile's sign-in hint (backup-restore D6): its server
  /// address, and its user name for Jellyfin and Emby.
  ({String server, String? user, bool plex})? get hint {
    final hint = _hintJson;
    if (hint case {'serverUrl': final String url, 'userName': final String user}) {
      final plex = ServerKind.fromJson(hint['kind']) == ServerKind.plex;
      return (server: url, user: plex ? null : user, plex: plex);
    }
    return null;
  }

  /// Starts from the hint: a link code for Plex (its server and Home user
  /// then chosen without asking), or the server's password step.
  Future<void> startFromHint() async {
    final h = hint;
    if (h == null) return;
    final raw = _hintJson!;
    if (h.plex) {
      await startPlex(server: raw['serverId'] as String?, user: raw['userId'] as String?);
    } else {
      await connect(h.server, then: SignInStage.password);
    }
  }

  /// What's known of the sign-in being made: a restored profile's hint, or
  /// the server being signed in again (its sign-in or backup hint).
  Map<String, Object?>? get _hintJson {
    final again = _again;
    if (again != null) return again.backupHint();
    return adding ? null : app.signInHint;
  }

  /// Adding or signing in again: [id] (a server id) must not be another of
  /// the profile's servers.
  void _checkNotAdded(String? id, String name) {
    if (!adding && againKey == null) return;
    final other = app.servers.byServerId(id);
    if (other != null && other.key != againKey) throw ServerException(tr.isAlreadyIn(name));
  }

  Future<void> _run(Future<void> Function() task) async {
    _set(step.copyWith(busy: true, error: () => null));
    try {
      await task();
    } on ServerException catch (e, stack) {
      debugPrint('Sign-in failed: ${e.message}');
      // A wrong password or an unreachable server is a trail entry only.
      reportServerResult('sign-in', step.kind, e);
      ErrorReports.capture(e, stack, area: 'sign-in');
      _set(step.copyWith(error: () => e.message));
    } finally {
      _set(step.copyWith(busy: false));
    }
  }

  /// Emby without Quick Connect goes straight to the password.
  bool get _skipsMethod => step.kind == ServerKind.emby && !step.quickConnectAvailable;

  /// The address step: finds the server at [address]. Jellyfin goes to
  /// [then] (choosing Quick Connect or a password), Plex to a link code.
  Future<void> connect(String address, {SignInStage then = SignInStage.method}) => _run(() async {
        if (address.trim().isEmpty) throw ServerException(tr.enterYourServer);
        final found = await (identify?.call(address) ??
            identifyServer(address, deviceId: app.settings.installId, deviceName: app.deviceName));
        if (_disposed) {
          found.client.close();
          return;
        }
        try {
          _checkNotAdded(found.info.id, found.info.name);
        } on ServerException {
          found.client.close();
          rethrow;
        }
        if (found.info.kind == ServerKind.plex) {
          found.client.close();
          _set(step.copyWith(info: () => found.info));
          await _startPlexNow(server: found.info.id);
          return;
        }
        final client = found.client as JellyfinClient;
        final qc = await client.quickConnectEnabled();
        _client?.close();
        _client = client;
        _set(step.copyWith(info: () => found.info, quickConnectAvailable: qc));
        // Emby without Quick Connect has only the password to choose.
        _set(step.copyWith(stage: _skipsMethod ? SignInStage.password : then));
      });

  /// "Sign in with password" on the method step.
  void choosePassword() => _set(step.copyWith(stage: SignInStage.password));

  Future<void> signInWithPassword(String user, String password) => _run(() async {
        if (user.trim().isEmpty) throw ServerException(tr.enterYourUsername);
        final session = await _client!.authenticateByName(user.trim(), password, serverName: step.info!.name);
        if (_disposed) return;
        final client = _client!;
        _client = null;
        await _finish(session, client);
      });

  Future<void> startQuickConnect() => _run(() async {
        final request = await _client!.quickConnectInitiate();
        _quickConnect = request;
        _set(step.copyWith(stage: SignInStage.quickConnect, quickConnectCode: () => request.code));
        _poll?.cancel();
        _poll = Timer.periodic(quickConnectPoll, (_) => _checkQuickConnect());
      });

  Future<void> _checkQuickConnect() async {
    final request = _quickConnect;
    if (request == null || step.busy) return;
    try {
      if (!await _client!.quickConnectAuthorized(request.secret)) return;
      _poll?.cancel();
      final session = await _client!.authenticateWithQuickConnect(request.secret, serverName: step.info!.name);
      if (_disposed) return;
      final client = _client!;
      _client = null;
      await _finish(session, client);
    } on ServerException catch (e, stack) {
      _poll?.cancel();
      debugPrint('Quick Connect stopped: ${e.message}');
      reportServerResult('sign-in', step.kind, e);
      ErrorReports.capture(e, stack, area: 'sign-in');
      _set(step.copyWith(error: () => tr.quickConnectStopped(e.message)));
    }
  }

  // ---- Plex -----------------------------------------------------------------

  PlexAccount get _plex =>
      _account ??= _givenAccount ?? PlexAccount(clientId: app.settings.installId, deviceName: app.deviceName);

  /// Shows a link code and checks it every [plexPoll] until it's linked.
  /// [server] and [user] are chosen without asking when the account has
  /// them.
  Future<void> startPlex({String? server, String? user}) => _run(() => _startPlexNow(server: server, user: user));

  Future<void> _startPlexNow({String? server, String? user}) async {
    _wantedServer = server;
    _wantedUser = user;
    _linkedToken = _userToken = null;
    _set(step.copyWith(homeUser: () => null, servers: () => null));
    final pin = await _plex.createPin();
    if (_disposed) return;
    _pin = pin;
    _set(step.copyWith(stage: SignInStage.plexCode, plexCode: () => pin.code));
    _poll?.cancel();
    _poll = Timer.periodic(plexPoll, (_) => _checkPin());
  }

  bool _checking = false;

  /// Checks to skip after plex.tv said "too many requests" (429): about
  /// 15 s at first, doubling up to a minute while it keeps saying so.
  int _skipChecks = 0;
  int _backoff = 0;

  Future<void> _checkPin() async {
    final pin = _pin;
    if (pin == null || _checking || step.stage != SignInStage.plexCode) return;
    if (_skipChecks > 0) {
      _skipChecks--;
      return;
    }
    _checking = true;
    try {
      final now = await _plex.checkPin(pin);
      _backoff = 0;
      if (_disposed || _pin != pin || step.stage != SignInStage.plexCode) return;
      if (now == null || (now.expiresAt != null && DateTime.now().isAfter(now.expiresAt!))) {
        // Expired: a new code replaces it, and the old one isn't checked again.
        final fresh = await _plex.createPin();
        if (!_disposed && step.stage == SignInStage.plexCode) {
          _pin = fresh;
          _set(step.copyWith(plexCode: () => fresh.code));
        }
        return;
      }
      if (!now.linked) return;
      _poll?.cancel();
      _linkedToken = now.authToken;
      await _run(_afterLink);
    } on ServerException catch (e) {
      if (e.statusCode == 429) {
        _backoff = _backoff == 0 ? 7 : (_backoff * 2).clamp(7, 30);
        _skipChecks = _backoff;
      }
      // A dropped check is retried on the next tick (or after the wait).
      debugPrint('Plex link check failed: ${e.message}');
    } finally {
      _checking = false;
    }
  }

  /// After linking: the Home user (when the Home has more than one), then
  /// the server.
  Future<void> _afterLink() async {
    final users = await _plex.homeUsers(_linkedToken!);
    if (_disposed) return;
    _set(step.copyWith(homeUsers: users));
    if (users.length <= 1) {
      _userToken = _linkedToken;
      await _loadServers();
      return;
    }
    final wanted = users.where((u) => u.id == _wantedUser).firstOrNull;
    if (wanted != null && !wanted.protected) {
      await _switchTo(wanted);
      return;
    }
    _set(step.copyWith(homeUser: () => wanted, stage: wanted != null ? SignInStage.plexPin : SignInStage.plexUsers));
  }

  /// A Home user picked from the list: their PIN next, if they have one.
  Future<void> pickUser(PlexHomeUser user) async {
    if (user.protected) {
      _set(step.copyWith(homeUser: () => user, error: () => null, stage: SignInStage.plexPin));
      return;
    }
    await _run(() => _switchTo(user));
  }

  Future<void> _switchTo(PlexHomeUser user, {String? pin}) async {
    _set(step.copyWith(homeUser: () => user));
    _userToken = await _plex.switchUser(_linkedToken!, user, pin: pin);
    await _loadServers();
  }

  /// The Home user's PIN. Returns false when it was wrong (the message is
  /// in [step]).
  Future<bool> enterHomePin(String pin) async {
    var wrong = false;
    await _run(() async {
      try {
        await _switchTo(step.homeUser!, pin: pin);
      } on PlexWrongPin {
        wrong = true;
        rethrow;
      }
    });
    return !wrong;
  }

  Future<void> _loadServers() async {
    final servers = await _plex.servers(_userToken!);
    if (_disposed) return;
    final wanted = servers.where((s) => s.clientIdentifier == _wantedServer).firstOrNull;
    // Servers already in the profile can't be added again.
    final open = [for (final s in servers) if (!_takenBy(s)) s];
    if (wanted != null && !_takenBy(wanted) || servers.length == 1 && open.length == 1) {
      await _chooseServer(wanted != null && !_takenBy(wanted) ? wanted : open.single);
      return;
    }
    _set(step.copyWith(
      servers: () => servers,
      stage: SignInStage.plexServers,
      error: servers.isEmpty
          ? () => tr.thisPlexAccount
          : open.isEmpty
              ? () => tr.everyServerOn
              : null,
    ));
  }

  /// [server] is already another of the profile's servers (adding, or
  /// signing in again).
  bool _takenBy(PlexResource server) {
    if (!adding && againKey == null) return false;
    final other = app.servers.byServerId(server.clientIdentifier);
    return other != null && other.key != againKey;
  }

  Future<void> pickServer(PlexResource server) => _run(() async {
        _checkNotAdded(server.clientIdentifier, server.name);
        await _chooseServer(server);
      });

  Future<void> _chooseServer(PlexResource server) async {
    final connection = await (pickPlexConnection?.call(server) ?? pickConnection(server));
    if (connection == null) {
      // The servers to choose from (this one again, to retry), not a code
      // that's already linked.
      _set(step.copyWith(servers: () => step.servers ?? [server], stage: SignInStage.plexServers));
      throw ServerException(tr.isNotAnswering(server.name));
    }
    final user = await _plex.user(_userToken!);
    if (_disposed) return;
    final session = ServerSession(
      kind: ServerKind.plex,
      serverUrl: connection.uri,
      serverName: server.name,
      serverId: server.clientIdentifier,
      userId: user.id,
      userName: step.homeUser?.title ?? user.title,
      accessToken: server.accessToken,
      accountToken: _userToken,
      deviceId: app.settings.installId,
      relay: connection.relay,
    );
    await _finish(session, app.clientForSession(session));
  }

  Future<void> _finish(ServerSession session, MediaServer client) async {
    // Added servers need their id from the start (duplicates, analysis).
    if (session.serverId == null && step.info?.id != null && (adding || againKey != null)) {
      session = session.withServerId(step.info!.id!);
    }
    if (completeSignIn case final complete?) {
      await complete(session, client);
      _finished = true;
      return;
    }
    if (session.kind == ServerKind.plex) {
      try {
        await client.checkSession();
      } on ServerException {
        client.close();
        rethrow;
      }
    }
    if (_disposed) return;
    if (againKey case final key?) {
      await app.signInAgainTo(key, session, client);
    } else if (adding) {
      await app.addServer(session, client);
    } else {
      await app.completeSignIn(session, client);
    }
    _finished = true;
  }

  /// One step back; checking a code stops.
  void back() {
    _poll?.cancel();
    final stage = switch (step.stage) {
      SignInStage.server || SignInStage.method || SignInStage.plexCode => SignInStage.server,
      SignInStage.password || SignInStage.quickConnect => _skipsMethod ? SignInStage.server : SignInStage.method,
      SignInStage.plexPin || SignInStage.plexServers =>
        step.homeUsers.length > 1 ? SignInStage.plexUsers : SignInStage.server,
      SignInStage.plexUsers => SignInStage.server,
    };
    if (stage == SignInStage.server) _pin = null;
    _set(step.copyWith(error: () => null, stage: stage, plexCode: stage == SignInStage.server ? () => null : null));
  }
}
