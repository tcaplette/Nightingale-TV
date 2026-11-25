import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../commercials/commercial_pool.dart';
import '../../data/app_storage.dart';
import '../../library/library_index.dart';
import '../../playback/playback_diagnostics.dart';
import '../live_tv.dart';
import '../media_server.dart';
import '../server_set.dart';
import '../smb/secret_store.dart';
import 'google_sign_in.dart';
import 'youtube_api.dart';
import 'youtube_catalog.dart';
import 'youtube_client_config.dart';

/// The next midnight in America/Los_Angeles after [now], when YouTube's
/// daily limit resets (D11). US daylight time: from the second Sunday of
/// March to the first Sunday of November, at 2:00.
DateTime nextPacificMidnight(DateTime now) {
  final utc = now.toUtc();
  DateTime sunday(int year, int month, int nth) {
    var d = DateTime.utc(year, month, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(Duration(days: 7 * (nth - 1)));
  }

  int offsetHours(DateTime u) {
    // Daylight time starts 2:00 PST (10:00 UTC) and ends 2:00 PDT (9:00 UTC).
    final start = sunday(u.year, 3, 2).add(const Duration(hours: 10));
    final end = sunday(u.year, 11, 1).add(const Duration(hours: 9));
    return !u.isBefore(start) && u.isBefore(end) ? -7 : -8;
  }

  final local = utc.add(Duration(hours: offsetHours(utc)));
  final midnightLocal = DateTime.utc(local.year, local.month, local.day + 1);
  // The offset at that midnight (it can differ from now's on a change day).
  var at = midnightLocal.subtract(Duration(hours: offsetHours(utc)));
  final again = midnightLocal.subtract(Duration(hours: offsetHours(at)));
  if (again != at) at = again;
  return at;
}

/// Revokes every YouTube sign-in saved in the profile folder [storage]
/// (main and added), before the profile is deleted (D12). Never throws.
Future<void> revokeYouTubeSignIns(AppStorage storage, {GoogleEndpoints? endpoints}) async {
  final sessions = <ServerSession>[];
  void add(Object? json) {
    if (json is! Map<String, Object?> || ServerKind.fromJson(json['kind']) != ServerKind.youtube) return;
    try {
      sessions.add(ServerSession.fromJson(json));
    } on Object {
      // Unreadable: nothing to revoke.
    }
  }

  add(await storage.readJson('session.json'));
  final servers = await storage.readJson(ServerSet.file);
  if (servers is Map) {
    for (final s in (servers['servers'] as List? ?? const []).whereType<Map>()) {
      add(s['session']);
    }
  }
  if (sessions.isEmpty) return;
  final secrets = SecretStore(storage);
  for (final session in sessions) {
    try {
      final values = await secrets.values(session.accessToken);
      final refresh = values?['refresh'];
      final id = session.clientId, secret = values?['clientSecret'];
      final client = id == null ? GoogleClient.shared : secret == null ? null : GoogleClient(id: id, secret: secret, own: true);
      if (refresh == null || client == null) continue;
      final signIn = GoogleDeviceSignIn(client, endpoints: endpoints);
      await signIn.revoke(refresh);
      signIn.close();
    } on Object catch (e) {
      debugPrint('YouTube revoke on profile delete: ${e.runtimeType}');
    }
  }
}

/// What a profile keeps of YouTube (youtube-subscriptions D4, D6, D11):
/// its servers' clients, catalogs and secrets.
class YouTubeProfile {
  YouTubeProfile(this.storage, this.secrets,
      {required this.picksOf, this.onChanged, DateTime Function()? now, this.endpointsOverride})
      : _now = now ?? DateTime.now;

  final AppStorage storage;
  final SecretStore secrets;

  /// The YouTube channel ids picked on server [key], in channel order.
  final List<String> Function(String key) picksOf;

  /// Something shown about a YouTube server changed (its daily limit, a
  /// lost sign-in).
  final VoidCallback? onChanged;
  final DateTime Function() _now;
  /// Tests: a fake Google.
  final GoogleEndpoints? endpointsOverride;
  GoogleEndpoints get endpoints => endpointsOverride ?? GoogleEndpoints.current;

  DateTime now() => _now();

  /// Counts the units of every request this profile sends (1.3/9.6), for
  /// the Pacific day: kept in [meterFile] across restarts.
  late final meter = YouTubeQuotaMeter(now: _now, onCount: (m) {
    _meterSaved = _meterLoaded.then((_) => storage.writeJson(meterFile, m.toJson()));
  });

  static const meterFile = 'youtube/units.json';
  late final Future<void> _meterLoaded = () async {
    try {
      meter.restore(await storage.readJson(meterFile));
    } on Object {
      // None yet, or unreadable: the count starts from this run.
    }
  }();
  Future<void>? _meterSaved;

  /// Tests: the count read and the last one written.
  @visibleForTesting
  Future<void> get meterSettled async {
    await _meterLoaded;
    await _meterSaved;
  }

  final _servers = <String, YouTubeServer>{};

  /// The client of sign-in [session] as the profile's server [key].
  YouTubeServer client(ServerSession session, String key) =>
      _servers[key] = YouTubeServer(session, key, this);

  YouTubeServer? serverOf(String key) => _servers[key];

  /// The Google client [session] signs in with: the shared one, or its own
  /// (whose secret is with the token); null when neither is there.
  Future<GoogleClient?> googleClientOf(ServerSession session) async {
    final id = session.clientId;
    if (id == null) return GoogleClient.shared;
    final secret = (await secrets.values(session.accessToken))?['clientSecret'];
    return secret == null ? null : GoogleClient(id: id, secret: secret, own: true);
  }

  /// Saves a new sign-in's [tokens] (and an own [client]'s secret) and
  /// returns the reference the session keeps.
  Future<String> saveTokens(GoogleTokens tokens, GoogleClient client) => secrets.putValues('yt', {
        'refresh': tokens.refreshToken,
        if (client.own) 'clientSecret': client.secret,
      });

  Future<YouTubeCatalog> catalogOf(String key) async {
    final server = _servers[key];
    if (server != null) return server.catalog;
    return YouTubeCatalog.fromJson(await storage.readJson(YouTubeCatalog.fileOf(key)));
  }

  Future<void> saveCatalog(String key, YouTubeCatalog catalog) async {
    if (catalog.isEmpty) {
      await storage.delete(YouTubeCatalog.fileOf(key));
    } else {
      await storage.writeJson(YouTubeCatalog.fileOf(key), catalog.toJson());
    }
  }

  /// The daily limit was reached on [clientId]: every YouTube server of the
  /// profile on that client holds off until Pacific midnight.
  void quotaReached(String? clientId) {
    final until = nextPacificMidnight(_now());
    for (final s in _servers.values) {
      if (s.session.clientId == clientId) {
        s.catalog.quotaBlockedUntil = until;
        unawaited(saveCatalog(s.key, s.catalog));
      }
    }
    PlaybackDiagnostics.note('YOUTUBE', 'daily limit until ${until.toIso8601String()}');
    onChanged?.call();
  }

  /// A sign-in no longer used (another client chosen, or left before it was
  /// added): its token is revoked and its secret forgotten.
  /// [revoke]: false when the new sign-in uses the same Google client, as
  /// Google's revoke ends the whole grant of a client and account, the new
  /// token with it; then only the old secret goes.
  Future<void> retire(ServerSession session, {bool revoke = true}) async {
    final refresh = (await secrets.values(session.accessToken))?['refresh'];
    final client = await googleClientOf(session);
    if (revoke && refresh != null && client != null) {
      final signIn = GoogleDeviceSignIn(client, endpoints: endpoints);
      await signIn.revoke(refresh);
      signIn.close();
    }
    await secrets.remove(session.accessToken);
  }

  /// Sign-out, Remove or profile deletion of server [key] (D12): the token
  /// is revoked, and the secret, catalog and cached art deleted. A failed
  /// revoke keeps nothing.
  Future<void> forget(ServerSession session, String key) async {
    final server = _servers.remove(key);
    final values = await secrets.values(session.accessToken);
    final refresh = values?['refresh'];
    final client = await googleClientOf(session);
    if (refresh != null && client != null) {
      final signIn = GoogleDeviceSignIn(client, endpoints: endpoints);
      await signIn.revoke(refresh);
      signIn.close();
    }
    server?.close();
    await secrets.remove(session.accessToken);
    await storage.delete(YouTubeCatalog.fileOf(key));
    try {
      final dir = Directory(storage.pathOf(YouTubeCatalog.folderOf(key)));
      if (await dir.exists()) await dir.delete(recursive: true);
      // The last YouTube sign-in gone: the day's unit count goes with it.
      final all = Directory(storage.pathOf('youtube'));
      if (await all.exists() && !await all.list().any((e) => e is Directory)) await all.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// A YouTube sign-in as one of a profile's servers (D1): the picked
/// channels' videos are its library; YouTube's own player plays them, so
/// nothing streams through here.
class YouTubeServer implements MediaServer {
  YouTubeServer(this.session, this.key, this._profile) {
    _loaded = _load();
  }

  ServerSession session;
  final String key;
  final YouTubeProfile _profile;

  YouTubeCatalog catalog = YouTubeCatalog();
  late Future<void> _loaded;

  /// Set once the sign-in was found revoked or expired.
  bool get signInLost => catalog.signInLostAt != null;

  YouTubeApi? _api;
  GoogleDeviceSignIn? _signIn;

  Future<void> _load() async {
    catalog = YouTubeCatalog.fromJson(await _profile.storage.readJson(YouTubeCatalog.fileOf(key)));
    if (catalog.purge(_profile.now())) await _profile.saveCatalog(key, catalog);
  }

  Future<void> get ready => _loaded;

  /// The account's API, signed in from the saved refresh token. Throws
  /// [ServerException] 401 when the token or own client is gone.
  Future<YouTubeApi> api() async {
    if (_api case final api?) return api;
    final values = await _profile.secrets.values(session.accessToken);
    final client = await _profile.googleClientOf(session);
    final refresh = values?['refresh'];
    if (refresh == null || client == null) throw ServerException('YouTube', statusCode: 401);
    final signIn = _signIn = GoogleDeviceSignIn(client, endpoints: _profile.endpoints, now: _profile.now);
    final auth = GoogleAuth(
        signIn, GoogleTokens(accessToken: '', refreshToken: refresh, expiresAt: DateTime(0)),
        now: _profile.now);
    return _api = YouTubeApi(auth, endpoints: _profile.endpoints, meter: _profile.meter);
  }

  /// Runs [call] on the API, turning Google's answers into the app's:
  /// the daily limit holds requests off, a lost sign-in is a 401.
  Future<T> _call<T>(Future<T> Function(YouTubeApi api) call) async {
    try {
      final result = await call(await api());
      if (catalog.signInLostAt != null) {
        catalog.signInLostAt = null;
        await _profile.saveCatalog(key, catalog);
      }
      return result;
    } on YouTubeQuotaException {
      _profile.quotaReached(session.clientId);
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.failure == GoogleSignInFailure.invalidGrant || e.failure == GoogleSignInFailure.invalidClient) {
        catalog.signInLostAt ??= _profile.now();
        await _profile.saveCatalog(key, catalog);
        throw ServerException('YouTube', statusCode: 401, detail: e.failure.name);
      }
      throw ServerException('YouTube', detail: e.failure.name);
    } on YouTubeApiException catch (e) {
      throw ServerException('YouTube', statusCode: e.statusCode, detail: e.detail);
    }
  }

  /// The daily limit holds until then; null when it doesn't.
  DateTime? get quotaBlockedUntil => catalog.blocked(_profile.now()) ? catalog.quotaBlockedUntil : null;

  /// The account's subscriptions, for the picker.
  Future<List<YouTubeSubscription>> subscriptions() async {
    if (quotaBlockedUntil != null) throw const YouTubeQuotaException();
    return _call((api) => api.subscriptions());
  }

  /// The catalog's videos as this server's library part (D2), under the
  /// library's ids; what's 30 days old already gone.
  LibraryIndex part() {
    catalog.purge(_profile.now());
    final index = LibraryIndex(
        series: const [],
        episodes: const [],
        movies: const [],
        youtubeVideos: catalog.entries(),
        fetchedAt: catalog.refreshedAt ?? _profile.now());
    return key == ServerSet.mainKey ? index : index.withServerKey((id) => ServerSet.globalId(key, id));
  }

  /// A video the player refused (100, 101, 150): dropped at the next
  /// refresh.
  Future<void> refuse(String videoId) async {
    await _loaded;
    catalog.refused.add(ServerSet.rawId(videoId));
    await _profile.saveCatalog(key, catalog);
  }

  @override
  ServerKind get kind => ServerKind.youtube;

  @override
  String get serverUrl => session.serverUrl;

  @override
  String get deviceId => session.deviceId;

  /// Nothing of the sign-in goes with any request but the API's own.
  @override
  Map<String, String> get authHeaders => const {};

  @override
  Future<ServerInfo> publicInfo() async =>
      ServerInfo(url: serverUrl, name: session.serverName, version: 'YouTube', id: session.serverId, kind: ServerKind.youtube);

  /// A token refresh: the daily authorization check (D11).
  @override
  Future<void> checkSession() => _call((api) => api.auth.accessToken(force: true));

  @override
  Future<void> logout() => _profile.forget(session, key);

  @override
  Future<List<ServerLibrary>> libraries() async => const [];

  /// The catalog brought up to date (at most every 6 hours, never while the
  /// daily limit holds), as the library's YouTube videos (D2, D6).
  @override
  Future<LibraryIndex> fetchLibraryIndex(
      {List<CommercialPool> pools = const [],
      Set<String> channelRoots = const {},
      bool providerIds = false,
      void Function(String status)? onStatus,
      void Function(List<ServerLibrary> libraries)? onLibraries}) async {
    await _loaded;
    final now = _profile.now();
    final picks = _profile.picksOf(key);
    var changed = catalog.purge(now);
    if (catalog.due(now, picks) && !catalog.blocked(now) && catalog.signInLostAt == null) {
      try {
        await _call((api) => catalog.refresh(api, picks, now));
        catalog.quotaBlockedUntil = null;
      } on YouTubeQuotaException {
        // Channels keep playing what they have (D11).
      } on ServerException catch (e) {
        // A lost sign-in is the scan's failure; anything else (no network)
        // keeps what the catalog has, tried again at the next scan.
        if (e.statusCode == 401) rethrow;
        PlaybackDiagnostics.note('YOUTUBE', 'refresh failed: ${e.detail ?? e.statusCode}');
      }
      changed = true;
    } else if (catalog.signInLostAt != null) {
      // Lost sign-ins stay lost until signed in again; the 7-day deletion
      // runs in purge.
      throw ServerException('YouTube', statusCode: 401);
    }
    if (changed) await _profile.saveCatalog(key, catalog);
    return LibraryIndex(
      series: const [],
      episodes: const [],
      movies: const [],
      youtubeVideos: catalog.entries(),
      fetchedAt: catalog.refreshedAt ?? now,
    );
  }

  @override
  Future<List<String>> idsUnder(String rootId) async => const [];

  @override
  Future<List<FolderNode>> folderTree(String libraryId) async => const [];

  @override
  Future<List<MediaSegment>> commercialSegments(String itemId) async => const [];

  /// YouTube's terms allow playback only in its embedded player.
  @override
  Uri streamUri(String sourceId) => throw UnsupportedError('YouTube videos play only in YouTube\'s player.');

  @override
  Uri get pingUri => Uri.parse('https://www.youtube.com/generate_204');

  @override
  Future<PlaybackDecision> playbackDecision(String itemId,
          {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero, Map<String, Object?>? profile}) async =>
      const PlaybackDecision.direct();

  @override
  Future<Uri> transcodeUri(Uri template, {required String playSessionId, required Duration startAt, SubtitleTrack? burn}) =>
      throw UnsupportedError('YouTube videos are never converted.');

  @override
  Future<List<SubtitleTrack>> subtitleTracks(String itemId) async => const [];

  @override
  Uri? subtitleUri(String itemId, SubtitleTrack track, {Duration startAt = Duration.zero, String? format}) => null;

  @override
  Future<void> stopTranscode(String playSessionId) async {}

  @override
  Future<void> keepTranscodeAlive(String playSessionId) async {}

  @override
  Future<Duration> resumePoint(String itemId) async => Duration.zero;

  @override
  bool get transcodeKeepsSourceTime => false;

  /// A video's thumbnail, from the catalog or YouTube's usual address.
  @override
  Uri imageUri(String itemId, ImageKind kind, {int? maxHeight, String? tag}) {
    final id = ServerSet.rawId(itemId);
    return Uri.parse(catalog.thumbnailOf(id) ?? 'https://i.ytimg.com/vi/$id/hqdefault.jpg');
  }

  @override
  Future<void> reportPlaybackStart(PlaybackReport report) async {}
  @override
  Future<void> reportPlaybackProgress(PlaybackReport report) async {}
  @override
  Future<void> reportPlaybackStopped(PlaybackReport report) async {}

  @override
  LiveTv? get liveTv => null;

  @override
  void close() {
    _signIn?.close();
    _api?.close();
    _signIn = null;
    _api = null;
  }
}
