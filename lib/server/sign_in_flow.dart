import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../jellyfin/jellyfin_client.dart';
import 'media_server.dart';
import 'plex/plex_account.dart';
import 'plex/plex_connections.dart';
import 'server_clients.dart';
import 'server_set.dart';
import 'smb/smb_discovery.dart';
import 'smb/smb_gateway.dart';
import 'smb/smb_library.dart';
import 'smb/smb_open.dart';
import 'smb/smb_share.dart';
import 'smb/smb_sign_in.dart';
import 'youtube/google_sign_in.dart';
import 'youtube/youtube_api.dart';
import 'youtube/youtube_client_config.dart';
import '../l10n/tr.dart';
import '../reporting/error_reports.dart';
import '../reporting/report_breadcrumbs.dart';

/// What the address step found: a client for the server, and its info.
typedef IdentifiedServer = ({MediaServer client, ServerInfo info});

/// Where a sign-in is (server-sign-in, media-servers).
enum SignInStage {
  server,
  method,
  password,
  quickConnect,
  plexCode,
  plexUsers,
  plexPin,
  plexServers,

  /// SMB: hosts found on the network, and an address to type.
  smbFind,

  /// SMB: the host's shares.
  smbShares,

  /// SMB: a user name and password, or a guest.
  smbSignIn,

  /// SMB: the share's folders mapped to what they hold.
  smbFolders,

  /// YouTube: the consent line and a code for google.com/device
  /// (youtube-subscriptions D3).
  youtubeCode,

  /// YouTube: the user's own Google client (D10).
  youtubeClient,

  /// YouTube: picking subscriptions after a first sign-in (D5).
  youtubePicker,

  /// Adding a server: the added server's guide colour
  /// (guide-server-colors).
  color,
}

/// A YouTube sign-in's state.
@immutable
class YouTubeStep {
  const YouTubeStep({this.code, this.subscriptions});

  /// The code shown for google.com/device.
  final DeviceCode? code;

  /// The account's subscriptions, for the picker.
  final List<YouTubeSubscription>? subscriptions;
}

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
    this.smb = const SmbStep(),
    this.youtube = const YouTubeStep(),
    this.colorKey,
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

  /// An SMB sign-in's state.
  final SmbStep smb;

  /// A YouTube sign-in's state.
  final YouTubeStep youtube;

  bool get isYouTube => const {SignInStage.youtubeCode, SignInStage.youtubeClient, SignInStage.youtubePicker}.contains(stage);

  /// The colour step: the key of the server just added.
  final String? colorKey;

  bool get isSmb => const {SignInStage.smbFind, SignInStage.smbShares, SignInStage.smbSignIn, SignInStage.smbFolders}.contains(stage);

  ServerKind get kind => isSmb
      ? ServerKind.smb
      : isYouTube
          ? ServerKind.youtube
          : info?.kind ?? ServerKind.jellyfin;

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
    SmbStep? smb,
    YouTubeStep? youtube,
    String? Function()? colorKey,
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
        smb: smb ?? this.smb,
        youtube: youtube ?? this.youtube,
        colorKey: colorKey == null ? this.colorKey : colorKey(),
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
    if (_disposed) return;
    // Left on the colour step: the server keeps the colour it has now.
    if (!_finished && step.stage == SignInStage.color) unawaited(_keepColor());
    _disposed = true;
    _poll?.cancel();
    _youTubeRun++;
    if (!_finished) unawaited(_dropYouTubeSignIn());
    _google?.close();
    unawaited(_discovery?.dispose());
    unawaited(_smbShare?.close());
    _client?.close();
    if (_givenAccount == null) _account?.close();
  }

  /// A restored profile's sign-in hint (backup-restore D6): its server
  /// address, and its user name for Jellyfin and Emby.
  ({String server, String? user, bool plex})? get hint {
    final hint = _hintJson;
    if (hint case {'serverUrl': final String url, 'userName': final String user}) {
      final plex = ServerKind.fromJson(hint['kind']) == ServerKind.plex;
      return (server: url, user: plex || hint['guest'] == true ? null : user, plex: plex);
    }
    return null;
  }

  /// Starts from the hint: a link code for Plex (its server and Home user
  /// then chosen without asking), or the server's password step.
  Future<void> startFromHint() async {
    final h = hint;
    if (h == null) return;
    final raw = _hintJson!;
    if (ServerKind.fromJson(raw['kind']) == ServerKind.youtube) {
      // Signing in again with the code; an own client's screen comes first,
      // since its secret never went with the backup (backup-restore). In
      // server mode it always does (docker-youtube D4).
      if (raw['ownClient'] == true || GoogleClient.ownOnly) {
        _set(step.copyWith(stage: SignInStage.youtubeClient, error: () => null));
      } else {
        await startYouTube();
      }
      return;
    }
    if (ServerKind.fromJson(raw['kind']) == ServerKind.smb) {
      // A share: as a guest at once, else only its password is asked.
      final address = SmbAddress.parse(h.server);
      if (address == null) return;
      _smbHintId = raw['serverId'] as String?;
      _set(step.copyWith(stage: SignInStage.smbSignIn, smb: step.smb.copyWith(host: () => address.withShare(''), share: () => address.share, user: h.user ?? '')));
      if (raw['guest'] == true) await smbAsGuest();
      return;
    }
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
        // An SMB address: no media server is asked about it.
        if (SmbAddress.looksLike(address)) {
          await _smbAddress(address);
          return;
        }
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
      final added = await app.addServer(session, client);
      // Its guide colour is chosen last, while the guide shows colours.
      if (app.guideColorsOn && !_disposed) {
        _set(step.copyWith(stage: SignInStage.color, colorKey: () => added.key, error: () => null));
        return;
      }
    } else {
      await app.completeSignIn(session, client);
    }
    _finished = true;
  }

  // ---- SMB shares (smb-sources) ---------------------------------------------

  SmbDiscovery? _discovery;
  StreamSubscription<List<SmbHost>>? _found;
  SmbCredentials? _smbCredentials;
  SmbShare? _smbShare;
  String? _smbId;

  /// A restored share's id, which signing in again must find.
  String? _smbHintId;

  /// Tests: how shares are opened and listed instead of the network.
  @visibleForTesting
  Future<SmbShare> Function(SmbAddress address, SmbCredentials credentials)? openShare;
  @visibleForTesting
  Future<({List<SmbShareInfo> shares, bool smb1})> Function(SmbAddress address, SmbCredentials credentials)? listShares;

  /// Tests: what looks for hosts instead of the network.
  @visibleForTesting
  SmbDiscovery Function() newDiscovery = SmbDiscovery.new;

  /// "SMB share": the hosts on the network, found while the step is open.
  Future<void> startSmb() async {
    _set(step.copyWith(stage: SignInStage.smbFind, error: () => null, smb: const SmbStep()));
    await searchSmb();
  }

  /// Looks for hosts again.
  Future<void> searchSmb() async {
    final d = _discovery ??= newDiscovery();
    await _found?.cancel();
    _found = d.hosts.listen((hosts) {
      _set(step.copyWith(smb: step.smb.copyWith(hosts: hosts, searching: d.running)));
    });
    _set(step.copyWith(smb: step.smb.copyWith(searching: true)));
    // The step is shown at once; hosts come in as they answer (the web
    // admin asks for the step again while it says it's searching).
    unawaited(d.start());
  }

  /// Leaves the find step: its sockets close.
  Future<void> _stopSearch() async => _discovery?.stop();

  Future<void> _smbAddress(String typed) async {
    final address = SmbAddress.parse(typed);
    if (address == null) throw ServerException(tr.smbNotAnAddress);
    await _stopSearch();
    _set(step.copyWith(smb: step.smb.copyWith(host: () => address.withShare(''), share: () => null, shares: const [])));
    if (address.share.isEmpty) {
      await _listSmbShares();
    } else {
      await _openSmbShare(address.share);
    }
  }

  /// A typed address on the find step.
  Future<void> smbConnect(String typed) => _run(() => _smbAddress(typed));

  Future<void> pickSmbHost(SmbHost host) => _run(() async {
        await _stopSearch();
        _set(step.copyWith(smb: step.smb.copyWith(host: () => SmbAddress(host: host.address, port: host.port), share: () => null)));
        await _listSmbShares();
      });

  /// Sign-ins to try on [host] before asking: those of the profile's other
  /// shares on it, then a guest's.
  Future<List<SmbCredentials>> _knownSignIns(SmbAddress host) async {
    final known = <SmbCredentials>[];
    for (final s in app.servers.all) {
      final session = s.session;
      if (session == null || session.kind != ServerKind.smb) continue;
      final a = SmbAddress.parse(session.serverUrl);
      if (a == null || a.withShare('') != host.withShare('')) continue;
      if (await app.smb.credentials(session.accessToken) case final c? when !c.isGuest) known.add(c);
    }
    return [...known, const SmbCredentials.guest()];
  }

  Future<void> _listSmbShares() async {
    final host = step.smb.host!;
    final tries = _smbCredentials != null ? [_smbCredentials!] : await _knownSignIns(host);
    SmbException? last;
    for (final who in tries) {
      try {
        final found = await (listShares?.call(host, who) ?? listSmbShares(host, who));
        _smbCredentials = who;
        _set(step.copyWith(
            stage: SignInStage.smbShares,
            smb: step.smb.copyWith(shares: found.shares, smb1: found.smb1, user: who.isGuest ? step.smb.user : who.user)));
        return;
      } on SmbException catch (e) {
        last = e;
        if (e.kind == SmbErrorKind.unreachable || e.kind == SmbErrorKind.gone) break;
      }
    }
    _smbCredentials = null;
    if (last != null && (last.kind == SmbErrorKind.unreachable || last.kind == SmbErrorKind.gone)) throw _smbFailure(last);
    // Asked for a sign-in, with why when a sign-in was given.
    _set(step.copyWith(stage: SignInStage.smbSignIn));
    if (tries.length == 1 && !tries.single.isGuest) throw _smbFailure(last!);
    if (last?.kind == SmbErrorKind.guestsRefused) _set(step.copyWith(error: () => tr.smbGuestsRefused));
  }

  ServerException _smbFailure(SmbException e) => switch (e.kind) {
        SmbErrorKind.unreachable => ServerException(tr.smbCantReach(step.smb.host?.host ?? '')),
        SmbErrorKind.wrongSignIn => ServerException(tr.wrongUsernameOr, statusCode: 401),
        SmbErrorKind.guestsRefused => ServerException(tr.smbGuestsRefused, statusCode: 401),
        SmbErrorKind.noAccess => ServerException(tr.smbNoAccess, statusCode: 403),
        SmbErrorKind.gone => ServerException(tr.smbShareGone(step.smb.share ?? step.smb.host?.host ?? ''), statusCode: 404),
        SmbErrorKind.other => ServerException(tr.smbCantReach(step.smb.host?.host ?? '')),
      };

  /// A share picked from the host's list.
  Future<void> pickSmbShare(String name) => _run(() => _openSmbShare(name));

  /// The sign-in step's user name and password.
  Future<void> smbSignIn(String user, String password, {String domain = ''}) => _run(() async {
        if (user.trim().isEmpty) throw ServerException(tr.enterYourUsername);
        var name = user.trim(), realm = domain.trim();
        // DOMAIN\user and user@domain both name the domain.
        if (realm.isEmpty && name.contains(r'\')) (realm, name) = (name.split(r'\').first, name.split(r'\').last);
        _smbCredentials = SmbCredentials(user: name, password: password, domain: realm);
        await _afterSignIn();
      });

  /// "Connect as guest".
  Future<void> smbAsGuest() => _run(() async {
        _smbCredentials = const SmbCredentials.guest();
        await _afterSignIn();
      });

  Future<void> _afterSignIn() async {
    final share = step.smb.share;
    if (share == null) {
      await _listSmbShares();
    } else {
      await _openSmbShare(share);
    }
  }

  Future<void> _openSmbShare(String name) async {
    final address = step.smb.host!.withShare(name);
    _set(step.copyWith(smb: step.smb.copyWith(share: () => name)));
    final tries = _smbCredentials != null ? [_smbCredentials!] : await _knownSignIns(address);
    SmbShare? share;
    SmbException? last;
    for (final who in tries) {
      try {
        share = await (openShare?.call(address, who) ?? openSmbShare(address, who, workers: 1));
        _smbCredentials = who;
        break;
      } on SmbException catch (e) {
        last = e;
        if (e.kind == SmbErrorKind.unreachable || e.kind == SmbErrorKind.gone || e.kind == SmbErrorKind.noAccess) break;
      }
    }
    if (share == null) {
      if (last!.kind == SmbErrorKind.wrongSignIn || last.kind == SmbErrorKind.guestsRefused) {
        _set(step.copyWith(stage: SignInStage.smbSignIn));
      }
      throw _smbFailure(last);
    }
    try {
      final (:id, :writable) = await smbServerId(share, address);
      final again = _again;
      if (again != null && again.serverId != null && again.serverId != id) throw ServerException(tr.smbAnotherShare(again.name));
      if (_smbHintId != null && _smbHintId != id && again == null && !adding) throw ServerException(tr.smbAnotherShare(name));
      _checkNotAdded(id, name);
      if (!adding && againKey == null && app.servers.byServerId(id) != null && app.session?.serverId == id) {
        throw ServerException(tr.isAlreadyIn(name));
      }
      _smbId = id;
      await _smbShare?.close();
      _smbShare = share;
      final config = app.smb.configOf(id);
      config.smb1 = share.smb1;
      // Signing in again, or a restored share: its folders are mapped.
      if (againKey != null || config.mappings.isNotEmpty) {
        await _finishSmb();
        return;
      }
      final top = await share.list('');
      final folders = [for (final e in top) if (e.isFolder && !e.hidden && !e.name.startsWith('.')) e.name];
      _set(step.copyWith(
        stage: SignInStage.smbFolders,
        smb: step.smb.copyWith(
          smb1: share.smb1,
          folder: '',
          folders: folders..sort(FolderNode.naturalCompare),
          mappings: {for (final f in folders) f: ?SmbFolderType.suggested(f)},
          historyName: app.smb.profileName,
          keepLocal: false,
          writable: writable,
        ),
      ));
    } on Object {
      if (!identical(_smbShare, share)) await share.close();
      rethrow;
    }
  }

  /// The mapping step's folder [path]: its folders, with the types around.
  Future<void> openSmbFolder(String path) => _run(() async {
        final share = _smbShare;
        if (share == null) return;
        final entries = await share.list(path);
        final folders = [for (final e in entries) if (e.isFolder && !e.hidden && !e.name.startsWith('.')) e.name]
          ..sort(FolderNode.naturalCompare);
        final suggested = {
          ...step.smb.mappings,
          // Suggestions only where nothing above is mapped.
          if (step.smb.typeAt(path) == null)
            for (final f in folders)
              if (SmbFolderType.suggested(f) case final t? when !step.smb.mappings.containsKey(smbJoin(path, f)))
                smbJoin(path, f): t,
        };
        _set(step.copyWith(stage: SignInStage.smbFolders, smb: step.smb.copyWith(folder: path, folders: folders, mappings: suggested)));
      });

  /// Maps folder [path] to [type]; null takes its mapping away (it then
  /// has the type of the mapped folder around it, if any).
  void mapSmbFolder(String path, SmbFolderType? type) {
    final mappings = {...step.smb.mappings};
    if (type == null) {
      mappings.remove(path);
    } else {
      mappings[path] = type;
    }
    _set(step.copyWith(error: () => null, smb: step.smb.copyWith(mappings: mappings)));
  }

  void setSmbHistory({String? name, bool? keepLocal}) =>
      _set(step.copyWith(smb: step.smb.copyWith(historyName: name, keepLocal: keepLocal)));

  /// The mapping step's Done: at least one folder mapped.
  Future<void> finishSmb({String? historyName}) => _run(() async {
        if (historyName != null) setSmbHistory(name: historyName);
        if (step.smb.mappings.isEmpty) throw ServerException(tr.smbMapOne);
        final config = app.smb.configOf(_smbId!)
          ..mappings = [for (final e in step.smb.mappings.entries) SmbMapping(e.key, e.value)]
          ..keepLocal = step.smb.keepLocal || !step.smb.writable
          ..historyName = step.smb.historyName.trim().isEmpty || step.smb.historyName.trim() == app.smb.profileName
              ? null
              : step.smb.historyName.trim();
        config.smb1 = step.smb.smb1;
        await _finishSmb();
      });

  Future<void> _finishSmb() async {
    final id = _smbId!, who = _smbCredentials!;
    final address = step.smb.host!.withShare(step.smb.share!);
    await _smbShare?.close();
    _smbShare = null;
    final again = _again;
    final ref = await app.smb.secrets.put(who);
    if (again?.session?.accessToken case final old? when old != ref) await app.smb.secrets.remove(old);
    await app.smb.saveConfig(id);
    final session = ServerSession(
      kind: ServerKind.smb,
      serverUrl: address.url,
      serverName: again?.name ?? tr.smbShareOnHost(address.share, address.host),
      serverId: id,
      userId: who.isGuest ? 'guest' : who.user.toLowerCase(),
      userName: who.isGuest ? tr.guest : who.user,
      accessToken: ref,
      deviceId: app.settings.installId,
    );
    await SmbGateway.ensureStarted();
    final MediaServer client = completeSignIn != null ? _SmbPlaceholder(session) : app.clientForSession(session);
    await _finish(session, client);
  }

  // ---- YouTube (youtube-subscriptions) ----------------------------------------

  GoogleDeviceSignIn? _google;
  GoogleClient? _youTubeClient;
  ServerSession? _youTubeSession;

  /// Whether the YouTube sign-in under way uses the user's own Google client
  /// (its picker has no limit).
  bool get youTubeOwnClient => _youTubeClient?.own ?? false;

  /// Bumped when a code stops being waited for (Back, Cancel, a new code).
  int _youTubeRun = 0;

  /// Tests: a fake Google.
  @visibleForTesting
  GoogleEndpoints? googleEndpoints;

  /// Tests: how long to wait between token checks.
  @visibleForTesting
  Future<void> Function(Duration wait)? googleDelay;

  /// The connect step's YouTube: the code for [client] (else the server's
  /// own client, else the app's). A build with no client to use stays on
  /// the connect step and says so (youtube-shared-client D3): Add a server
  /// never opens the own-client screen.
  Future<void> startYouTube({GoogleClient? client}) async {
    final again = _again?.session;
    final use = client ??
        (again != null && again.kind == ServerKind.youtube ? await app.youtube.googleClientOf(again) : null) ??
        GoogleClient.shared;
    if (use == null) {
      _set(step.copyWith(error: () => GoogleClient.ownOnly ? tr.youTubeServerOwnClient : tr.youTubeNoClient));
      return;
    }
    // Back to Nightingale TV's client only within its channel limit (D6).
    final key = againKey;
    if (!use.own && key != null && app.youTubeOwnClient(key) && !app.youTubeFitsSharedClient(key)) {
      _set(step.copyWith(error: () => tr.youTubeSharedTooMany(AppState.youTubeSharedLimit)));
      return;
    }
    await _youTubeCode(use);
  }

  /// Opens the own-client screen (Servers → YouTube → Google client): the
  /// only way in, besides re-signing a server that uses its own client.
  void showGoogleClient() => _set(step.copyWith(stage: SignInStage.youtubeClient, error: () => null));

  Future<void> _youTubeCode(GoogleClient client) => _run(() async {
        _google?.close();
        final google = _google = GoogleDeviceSignIn(client,
            endpoints: googleEndpoints ?? app.youtube.endpoints, delay: googleDelay);
        _youTubeClient = client;
        final run = ++_youTubeRun;
        final DeviceCode code;
        try {
          code = await google.requestCode();
        } on GoogleSignInException catch (e) {
          if (e.failure == GoogleSignInFailure.invalidClient) {
            // Only an own client goes back to its screen; Nightingale TV's
            // stays on the step it was started from.
            if (client.own) _set(step.copyWith(stage: SignInStage.youtubeClient));
            throw ServerException(tr.clientRefused);
          }
          throw ServerException(tr.couldNotReachGoogle);
        }
        if (run != _youTubeRun) return;
        _set(step.copyWith(stage: SignInStage.youtubeCode, youtube: YouTubeStep(code: code), error: () => null));
        unawaited(_waitForGoogle(google, code, run));
      });

  Future<void> _waitForGoogle(GoogleDeviceSignIn google, DeviceCode code, int run) async {
    bool stopped() => _disposed || run != _youTubeRun;
    try {
      final tokens = await google.waitForTokens(code, cancelled: stopped);
      if (tokens == null || stopped()) return;
      await _run(() => _afterGoogle(google, tokens));
    } on GoogleSignInException catch (e) {
      if (stopped()) return;
      switch (e.failure) {
        case GoogleSignInFailure.expired:
          // A new code, without leaving the step.
          await _youTubeCode(_youTubeClient!);
        case GoogleSignInFailure.cancelled:
          _set(step.copyWith(stage: SignInStage.server, error: () => tr.signInWasCancelled, youtube: const YouTubeStep()));
        case GoogleSignInFailure.invalidClient:
          _set(step.copyWith(
              stage: _youTubeClient!.own ? SignInStage.youtubeClient : SignInStage.server,
              error: () => tr.clientRefused,
              youtube: const YouTubeStep()));
        case GoogleSignInFailure.invalidGrant || GoogleSignInFailure.failed:
          _set(step.copyWith(stage: SignInStage.server, error: () => tr.couldNotReachGoogle, youtube: const YouTubeStep()));
      }
    }
  }

  /// Google said yes: the account's id, name and subscriptions. A first
  /// sign-in goes on to the picker; signing in again (or a restore) keeps
  /// the channels it has.
  Future<void> _afterGoogle(GoogleDeviceSignIn google, GoogleTokens tokens) async {
    // YouTube's box left unticked on Google's page: nothing can be read, so
    // the grant goes and a new code is shown with why.
    if (!tokens.canReadYouTube) {
      await google.revoke(tokens.refreshToken);
      await _youTubeCode(_youTubeClient!);
      _set(step.copyWith(error: () => tr.youTubeAccessNeeded));
      return;
    }
    final sub = tokens.subject;
    if (sub == null) throw ServerException(tr.couldNotReachGoogle);
    final serverId = 'yt:$sub';
    try {
      _checkNotAdded(serverId, tr.youTube);
    } on ServerException {
      await google.revoke(tokens.refreshToken);
      _set(step.copyWith(stage: SignInStage.server, youtube: const YouTubeStep()));
      rethrow;
    }
    final client = _youTubeClient!;
    final api = YouTubeApi(GoogleAuth(google, tokens), endpoints: googleEndpoints ?? app.youtube.endpoints, meter: app.youtube.meter);
    String? title;
    try {
      title = await api.myChannelTitle();
    } on Object catch (e) {
      debugPrint('YouTube channel title: ${e.runtimeType}');
    }
    final ref = await app.youtube.saveTokens(tokens, client);
    _youTubeSession = ServerSession(
      kind: ServerKind.youtube,
      serverUrl: 'https://www.youtube.com',
      serverName: tr.youTube,
      serverId: serverId,
      userId: sub,
      userName: title ?? tr.youTubeAccount,
      accessToken: ref,
      deviceId: app.settings.installId,
      clientId: client.own ? client.id : null,
    );
    if (againKey != null || _hintJson != null) {
      await _finishYouTube(null);
      return;
    }
    final List<YouTubeSubscription> subscriptions;
    try {
      subscriptions = await api.subscriptions();
    } on YouTubeQuotaException {
      app.youtube.quotaReached(client.own ? client.id : null);
      throw ServerException(tr.youTubeAlreadyRemovedQuota);
    } on Object {
      throw ServerException(tr.couldNotReachGoogle);
    }
    _set(step.copyWith(stage: SignInStage.youtubePicker, youtube: YouTubeStep(subscriptions: subscriptions)));
  }

  /// The picker's Done on a first sign-in: the server is added (or signed
  /// in) with a channel for each pick, then the colour step.
  Future<void> youTubePicked(List<YouTubeSubscription> picks) => _run(() => _finishYouTube(picks));

  Future<void> _finishYouTube(List<YouTubeSubscription>? picks) async {
    final session = _youTubeSession!;
    if (completeSignIn case final complete?) {
      await complete(session, app.youtube.client(session, againKey ?? ServerSet.mainKey));
      _finished = true;
      _youTubeSession = null;
      return;
    }
    if (_disposed) return;
    if (againKey case final key?) {
      final old = _again?.session;
      await app.signInAgainTo(key, session, app.clientForSession(session, key: key));
      _youTubeSession = null;
      // The old token is no longer used. Revoked only from another client:
      // Google's revoke ends the whole grant, the new sign-in's too.
      if (old != null && old.kind == ServerKind.youtube && old.accessToken != session.accessToken) {
        final oldClient = await app.youtube.googleClientOf(old);
        await app.youtube.retire(old, revoke: oldClient?.id != _youTubeClient?.id);
      }
      _finished = true;
      _set(step.copyWith(busy: false));
      return;
    }
    if (adding) {
      final client = app.clientForSession(session, key: app.servers.peekKey());
      final added = await app.addServer(session, client, refresh: picks == null);
      _youTubeSession = null;
      if (picks != null) await app.setYouTubePicks(added.key, picks);
      if (app.guideColorsOn && !_disposed) {
        _set(step.copyWith(stage: SignInStage.color, colorKey: () => added.key, error: () => null));
        return;
      }
    } else {
      if (picks != null) await app.setYouTubePicks(ServerSet.mainKey, picks, refresh: false);
      _youTubeSession = null;
      await app.completeSignIn(session, app.clientForSession(session));
    }
    _finished = true;
  }

  /// A sign-in left before it was used (Back on the picker): its token is
  /// revoked and forgotten.
  Future<void> _dropYouTubeSignIn() async {
    final session = _youTubeSession;
    _youTubeSession = null;
    if (session != null) await app.youtube.retire(session);
  }

  // ---- The added server's guide colour (guide-server-colors) ---------------

  /// The colour step: [name] (a palette colour) is the added server's guide
  /// colour, and the sign-in is finished.
  Future<void> chooseColor(String name) async {
    final key = step.colorKey;
    if (step.stage != SignInStage.color || key == null || _finished || ServerColor.byName(name) == null) return;
    await app.setServerColor(key, name);
    _finishColor();
  }

  /// The colour step left without choosing: the colour selected (the
  /// server's suggestion) is kept, and the sign-in is finished.
  Future<void> keepColor() async {
    if (step.stage != SignInStage.color || _finished) return;
    await _keepColor();
    _finishColor();
  }

  Future<void> _keepColor() async {
    final key = step.colorKey;
    if (key == null) return;
    if (app.serverColors[key] case final c?) await app.setServerColor(key, c.name);
  }

  void _finishColor() {
    _finished = true;
    _set(step.copyWith(busy: false, error: () => null));
  }

  /// One step back; checking a code stops. On the colour step the server is
  /// already added: it keeps its colour.
  void back() {
    _poll?.cancel();
    if (step.isYouTube) {
      _youTubeRun++;
      unawaited(_dropYouTubeSignIn());
      _set(step.copyWith(error: () => null, stage: SignInStage.server, youtube: const YouTubeStep()));
      return;
    }
    if (step.stage == SignInStage.color) {
      unawaited(keepColor());
      return;
    }
    final stage = switch (step.stage) {
      SignInStage.server || SignInStage.method || SignInStage.plexCode => SignInStage.server,
      SignInStage.password || SignInStage.quickConnect => _skipsMethod ? SignInStage.server : SignInStage.method,
      SignInStage.plexPin || SignInStage.plexServers =>
        step.homeUsers.length > 1 ? SignInStage.plexUsers : SignInStage.server,
      SignInStage.plexUsers => SignInStage.server,
      SignInStage.smbFind => SignInStage.server,
      SignInStage.smbShares => SignInStage.smbFind,
      SignInStage.smbSignIn => step.smb.shares.isNotEmpty && step.smb.share != null ? SignInStage.smbShares : SignInStage.smbFind,
      SignInStage.color => SignInStage.color,
      SignInStage.youtubeCode || SignInStage.youtubeClient || SignInStage.youtubePicker => SignInStage.server,
      SignInStage.smbFolders => step.smb.folder.isNotEmpty
          ? SignInStage.smbFolders
          : step.smb.shares.isNotEmpty
              ? SignInStage.smbShares
              : SignInStage.smbFind,
    };
    if (step.stage == SignInStage.smbFolders && step.smb.folder.isNotEmpty) {
      final up = step.smb.folder.contains('/') ? step.smb.folder.substring(0, step.smb.folder.lastIndexOf('/')) : '';
      unawaited(openSmbFolder(up));
      return;
    }
    if (stage == SignInStage.smbFind && step.stage != SignInStage.smbFind) unawaited(searchSmb());
    if (step.stage == SignInStage.smbFind) unawaited(_discovery?.stop());
    if (step.stage == SignInStage.smbFolders || step.stage == SignInStage.smbSignIn) {
      unawaited(_smbShare?.close());
      _smbShare = null;
    }
    if (stage == SignInStage.server) _pin = null;
    _set(step.copyWith(error: () => null, stage: stage, plexCode: stage == SignInStage.server ? () => null : null));
  }
}

/// Tests: a share's sign-in handed to [SignInFlow.completeSignIn] with no
/// client behind it.
class _SmbPlaceholder implements MediaServer {
  _SmbPlaceholder(this.session);

  final ServerSession session;

  @override
  ServerKind get kind => ServerKind.smb;

  @override
  String get serverUrl => session.serverUrl;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
