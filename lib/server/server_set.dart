import '../library/library_index.dart';
import 'keyed_server.dart';
import 'media_server.dart';
import '../l10n/tr.dart';

/// How a profile's server is doing (multi-server): shown in Servers, and
/// which copies the tuner may play.
enum ServerState {
  ok,
  unreachable,
  needsSignIn;

  String get label => switch (this) {
        ServerState.ok => tr.ok,
        ServerState.unreachable => tr.cantBeReached,
        ServerState.needsSignIn => tr.needsSignIn,
      };
}

/// One of a profile's servers: the main one (key [ServerSet.mainKey], the
/// sign-in in `session.json`) or an added one (`s2`, `s3`, …).
class ProfileServer {
  ProfileServer({required this.key, this.session, this.client, this.hint, this.qualityLimit, this.state = ServerState.ok});

  final String key;

  /// The sign-in; null for an added server restored from a backup that
  /// hasn't signed in again yet.
  ServerSession? session;
  MediaServer? client;

  /// What a backup knew of the sign-in (kind, URL, name, server id, user id
  /// and name), for Sign in again; no token.
  Map<String, Object?>? hint;

  /// This server's bitrate cap in bits per second (null: the profile's).
  int? qualityLimit;
  ServerState state;

  bool get isMain => key == ServerSet.mainKey;

  /// Signed in and not known to be failing: its copies may play.
  bool get usable => client != null && state == ServerState.ok;

  ServerKind get kind => session?.kind ?? ServerKind.fromJson(hint?['kind']);

  /// The server's own name, else its kind's (never "Jellyfin" for another
  /// kind).
  String get name => session?.serverName ?? hint?['serverName'] as String? ?? kind.label;
  String? get serverId => session?.serverId ?? hint?['serverId'] as String?;
  String? get serverUrl => session?.serverUrl ?? hint?['serverUrl'] as String?;
  String? get userName => session?.userName ?? hint?['userName'] as String?;
  String? get userId => session?.userId ?? hint?['userId'] as String?;

  /// The quality limit in kbps, as caps are kept elsewhere.
  int? get qualityLimitKbps => qualityLimit == null ? null : qualityLimit! ~/ 1000;

  /// The sign-in hint a backup keeps for this server (no token).
  Map<String, Object?> backupHint() => {
        'key': key,
        'kind': kind.name,
        if (serverUrl != null) 'serverUrl': serverUrl,
        'serverName': name,
        if (serverId != null) 'serverId': serverId,
        if (userId != null) 'userId': userId,
        if (userName != null) 'userName': userName,
        if (qualityLimit != null) 'qualityLimit': qualityLimit,
      };
}

/// A profile's servers (multi-server D1, D2): the main server and the added
/// ones, their Play from order and quality limits, and how global item ids
/// map to a server and its own id.
///
/// Ids from the main server are the server's own; an added server's are
/// `<key>~<id>`. `~` doesn't occur in Jellyfin or Emby ids or Plex rating
/// keys. Keys are never reused within a profile.
class ServerSet {
  ServerSet();

  static const mainKey = 'main';
  static const separator = '~';

  /// The file added servers are saved in, beside `session.json`.
  static const file = 'servers.json';

  final main = ProfileServer(key: mainKey);
  final List<ProfileServer> added = [];

  /// Keys in Play from order; always holds [mainKey] and every added key.
  List<String> order = [mainKey];

  /// The number the next added server's key gets (`s<n>`).
  int nextKey = 2;

  /// Every server, main first.
  List<ProfileServer> get all => [main, ...added];

  /// Every server in Play from order.
  List<ProfileServer> get ordered => [for (final k in order) ?byKey(k)];

  /// More than one server: labels name servers, scans ask for provider ids.
  bool get multiple => added.isNotEmpty;

  ProfileServer? byKey(String key) => key == mainKey ? main : added.where((s) => s.key == key).firstOrNull;

  /// The server with [serverId], if the profile has it.
  ProfileServer? byServerId(String? serverId) =>
      serverId == null ? null : all.where((s) => s.serverId == serverId).firstOrNull;

  /// [rawId] of the server [key] as stored in the library.
  static String globalId(String key, String rawId) => key == mainKey ? rawId : '$key$separator$rawId';

  /// The key of the server [id] comes from.
  static String keyOf(String id) {
    final i = id.indexOf(separator);
    return i < 0 ? mainKey : id.substring(0, i);
  }

  /// [id] as its server knows it.
  static String rawId(String id) {
    final i = id.indexOf(separator);
    return i < 0 ? id : id.substring(i + 1);
  }

  /// The server [id] comes from and the id it knows the item by; null when
  /// that server isn't signed in (or no longer in the profile).
  ({MediaServer client, String rawId, ProfileServer server})? resolve(String id) {
    final server = byKey(keyOf(id));
    final client = server?.client;
    if (server == null || client == null) return null;
    return (client: client, rawId: rawId(id), server: server);
  }

  final _keyed = <String, KeyedServer>{};

  /// The client to ask about [id] (any id the library holds), taking and
  /// giving library ids: the main server's own client, or an added server's
  /// through a [KeyedServer]. Null when that server isn't signed in.
  MediaServer? clientFor(String id) {
    final server = byKey(keyOf(id));
    final client = server?.client;
    if (server == null || client == null) return null;
    if (server.isMain) return client;
    final keyed = _keyed[server.key];
    if (keyed != null && identical(keyed.inner, client)) return keyed;
    return _keyed[server.key] = KeyedServer(client, server.key);
  }

  /// [entry]'s copies to try, in Play from order, skipping servers that
  /// can't be used now (D5).
  List<MediaCopy> copiesOf(MediaEntry entry) {
    final copies = entry.copies;
    if (copies.length == 1) return byKey(keyOf(entry.id))?.usable == true ? copies : const [];
    final rank = {for (final (i, k) in order.indexed) k: i};
    return [
      for (final c in copies)
        if (byKey(keyOf(c.id))?.usable == true) c
    ]..sort((a, b) => (rank[keyOf(a.id)] ?? 1 << 20).compareTo(rank[keyOf(b.id)] ?? 1 << 20));
  }

  /// A new added server's key; never one used before in this profile.
  String takeKey() => 's${nextKey++}';

  /// Moves [key] [delta] places in Play from.
  void move(String key, int delta) {
    final i = order.indexOf(key);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= order.length) return;
    order
      ..removeAt(i)
      ..insert(j, key);
  }

  /// `servers.json`; null when there's nothing to save (one server and no
  /// main quality limit), so a one-server profile writes no file.
  Map<String, Object?>? toJson() {
    if (added.isEmpty && main.qualityLimit == null) return null;
    return {
      'servers': [
        for (final s in added)
          {
            'key': s.key,
            if (s.session != null) 'session': s.session!.toJson(),
            if (s.session == null && s.hint != null) 'hint': s.hint,
            if (s.qualityLimit != null) 'qualityLimit': s.qualityLimit,
          }
      ],
      'order': order,
      'mainQualityLimit': main.qualityLimit,
      'nextKey': nextKey,
    };
  }

  /// Loads `servers.json` ([json] null: only the main server). Added
  /// servers' clients are made by [clientFor].
  void load(Object? json, MediaServer Function(ServerSession session, String key) clientFor) {
    added.clear();
    order = [mainKey];
    nextKey = 2;
    main.qualityLimit = null;
    if (json is! Map<String, Object?>) return;
    for (final s in (json['servers'] as List? ?? const []).whereType<Map<String, Object?>>()) {
      final key = s['key'];
      if (key is! String || key == mainKey || byKey(key) != null) continue;
      final session = s['session'] is Map<String, Object?> ? ServerSession.fromJson(s['session'] as Map<String, Object?>) : null;
      added.add(ProfileServer(
        key: key,
        session: session,
        client: session == null ? null : clientFor(session, key),
        hint: s['hint'] as Map<String, Object?>?,
        qualityLimit: (s['qualityLimit'] as num?)?.toInt(),
        state: session == null ? ServerState.needsSignIn : ServerState.ok,
      ));
    }
    main.qualityLimit = (json['mainQualityLimit'] as num?)?.toInt();
    final keys = {mainKey, for (final s in added) s.key};
    order = [
      for (final k in (json['order'] as List? ?? const []).whereType<String>())
        if (keys.contains(k)) k,
    ];
    for (final k in keys) {
      if (!order.contains(k)) order.add(k);
    }
    final used = [for (final s in added) int.tryParse(s.key.substring(1)) ?? 0];
    nextKey = [(json['nextKey'] as num?)?.toInt() ?? 2, for (final n in used) n + 1].reduce((a, b) => a > b ? a : b);
  }

  /// Adds a signed-in server at the end of Play from.
  ProfileServer add(ServerSession session, MediaServer client) {
    final server = ProfileServer(key: takeKey(), session: session, client: client);
    added.add(server);
    order.add(server.key);
    return server;
  }

  /// Takes [key] out of the profile (its key is never given out again).
  ProfileServer? remove(String key) {
    final server = added.where((s) => s.key == key).firstOrNull;
    if (server == null) return null;
    added.remove(server);
    order.remove(key);
    return server;
  }
}
