import '../commercials/commercial_pool.dart';
import '../library/library_index.dart';
import 'live_tv.dart';

/// The kinds of media server a profile can sign in to.
enum ServerKind {
  jellyfin('Jellyfin'),
  emby('Emby'),
  plex('Plex');

  const ServerKind(this.label);

  final String label;

  /// Sign-ins and hints saved before server kinds existed are Jellyfin.
  static ServerKind fromJson(Object? name) =>
      values.where((k) => k.name == name).firstOrNull ?? ServerKind.jellyfin;
}

class ServerException implements Exception {
  ServerException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;

  /// The start of the server's answer, for telling causes apart (a busy
  /// tuner, say); never shown as it is.
  final String? detail;

  /// The server couldn't be reached at all (no answer, timeout), as opposed
  /// to answering with an error.
  bool get unreachable => statusCode == null;

  @override
  String toString() => message;
}

class ServerSession {
  const ServerSession({
    required this.serverUrl,
    required this.serverName,
    required this.userId,
    required this.userName,
    required this.accessToken,
    required this.deviceId,
    this.serverId,
    this.kind = ServerKind.jellyfin,
    this.accountToken,
    this.relay = false,
  });

  final String serverUrl;
  final String serverName;
  final String userId;
  final String userName;

  /// The token for the server itself. On Plex it's the server's token from
  /// the account's resource list, which differs from [accountToken] on
  /// shared servers.
  final String accessToken;
  final String deviceId;

  /// The server's own id, which stays the same if its address changes
  /// (Plex's machine identifier). Sign-ins saved before it was recorded
  /// don't have it yet.
  final String? serverId;
  final ServerKind kind;

  /// Plex only: the plex.tv token of the signed-in (Home) user, to find the
  /// server again when its address changes and to sign out.
  final String? accountToken;

  /// Plex only: [serverUrl] is Plex's relay, which limits quality.
  final bool relay;

  /// Jellyfin sign-ins are saved exactly as before server kinds existed.
  Map<String, Object?> toJson() => {
        'serverUrl': serverUrl,
        'serverName': serverName,
        'userId': userId,
        'userName': userName,
        'accessToken': accessToken,
        'deviceId': deviceId,
        if (serverId != null) 'serverId': serverId,
        if (kind != ServerKind.jellyfin) 'kind': kind.name,
        if (accountToken != null) 'accountToken': accountToken,
        if (relay) 'relay': true,
      };

  ServerSession _copy({String? serverUrl, String? deviceId, String? serverId, bool? relay, String? accessToken}) =>
      ServerSession(
        serverUrl: serverUrl ?? this.serverUrl,
        serverName: serverName,
        userId: userId,
        userName: userName,
        accessToken: accessToken ?? this.accessToken,
        deviceId: deviceId ?? this.deviceId,
        serverId: serverId ?? this.serverId,
        kind: kind,
        accountToken: accountToken,
        relay: relay ?? this.relay,
      );

  /// The same sign-in, identifying this PC as [id].
  ServerSession withDeviceId(String id) => _copy(deviceId: id);

  /// The same sign-in, knowing the server's [id].
  ServerSession withServerId(String id) => _copy(serverId: id);

  /// The same sign-in, reaching the server at [url] ([relay]: Plex's relay),
  /// with the server's current [accessToken].
  ServerSession withServerUrl(String url, {bool relay = false, String? accessToken}) =>
      _copy(serverUrl: url, relay: relay, accessToken: accessToken);

  factory ServerSession.fromJson(Map<String, Object?> json) {
    final kind = ServerKind.fromJson(json['kind']);
    return ServerSession(
      serverUrl: json['serverUrl'] as String,
      serverName: json['serverName'] as String? ?? kind.label,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      accessToken: json['accessToken'] as String,
      deviceId: json['deviceId'] as String,
      serverId: json['serverId'] as String?,
      kind: kind,
      accountToken: json['accountToken'] as String?,
      relay: json['relay'] == true,
    );
  }
}

class ServerInfo {
  const ServerInfo({required this.url, required this.name, required this.version, this.id, this.kind = ServerKind.jellyfin});

  final String url;
  final String name;
  final String version;

  /// Null only for servers too old to report it.
  final String? id;
  final ServerKind kind;
}

/// A stretch of a video, e.g. a Jellyfin media segment.
typedef MediaSegment = ({Duration start, Duration end});

/// A folder in a library, for picking commercial folders. Built from the
/// folder-like items the server lists to any user (folders, shows, seasons,
/// collections), never from server file-system paths.
class FolderNode {
  FolderNode({required this.id, required this.name, required this.type, this.index, List<FolderNode>? children})
      : children = children ?? [];

  final String id;
  final String name;

  /// `Folder`, `Series`, `Season` or `BoxSet` (Jellyfin's item types).
  final String type;
  final int? index;
  final List<FolderNode> children;

  static const itemTypes = 'Folder,Series,Season,BoxSet';

  /// Rebuilds the tree from a recursive Jellyfin listing. Each item's
  /// `ParentId` points at its folder; items whose parent isn't in the
  /// listing are the top level (a library's storage folders). Virtual items
  /// (placeholder seasons for missing episodes) are left out.
  static List<FolderNode> buildTree(List<Map<String, Object?>> items) {
    final real = [for (final i in items) if (i['LocationType'] != 'Virtual') i];
    final nodes = <String, FolderNode>{
      for (final i in real)
        i['Id'] as String: FolderNode(
          id: i['Id'] as String,
          name: (i['Name'] as String?)?.trim() ?? '',
          type: i['Type'] as String? ?? 'Folder',
          index: i['IndexNumber'] as int?,
        ),
    };
    final top = <FolderNode>[];
    for (final i in real) {
      final node = nodes[i['Id'] as String]!;
      final parent = nodes[i['ParentId']];
      if (parent != null && parent != node) {
        parent.children.add(node);
      } else {
        top.add(node);
      }
    }
    for (final n in nodes.values) {
      n.children.sort(compare);
    }
    top.sort(compare);
    return top;
  }

  /// Seasons by number; everything else by name, numbers in order
  /// ("Season 2" before "Season 10").
  static int compare(FolderNode a, FolderNode b) {
    if (a.type == 'Season' && b.type == 'Season' && a.index != null && b.index != null) {
      final byIndex = a.index!.compareTo(b.index!);
      if (byIndex != 0) return byIndex;
    }
    return naturalCompare(a.name, b.name);
  }

  static int naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final x = re.allMatches(a.toLowerCase()).toList(), y = re.allMatches(b.toLowerCase()).toList();
    for (var i = 0; i < x.length && i < y.length; i++) {
      final p = x[i][0]!, q = y[i][0]!;
      final c = x[i][1] != null && y[i][1] != null ? int.parse(p).compareTo(int.parse(q)) : p.compareTo(q);
      if (c != 0) return c;
    }
    return x.length.compareTo(y.length);
  }
}

class ServerLibrary {
  const ServerLibrary({required this.id, required this.name, this.collectionType});

  final String id;
  final String name;

  /// In Jellyfin's terms, for every server: `movies`, `tvshows`, `music`,
  /// `homevideos`, `musicvideos`, `mixed` (null), ...
  final String? collectionType;

  bool get isVideo =>
      collectionType == null ||
      const {'movies', 'tvshows', 'homevideos', 'musicvideos', 'mixed'}
          .contains(collectionType);

  /// A library of songs.
  bool get isMusic => collectionType == 'music';

  /// Jellyfin's and Emby's view of the collections: browsed for pools and
  /// sources, never scanned for programs (its items are in other libraries).
  bool get isCollections => collectionType == 'boxsets';
}

/// What [MediaServer.playbackDecision] decided: direct play (from
/// [MediaServer.streamUri]), or a conversion whose URL template is
/// [transcodeTemplate]: a direct stream when it keeps the video
/// ([directStream]), a transcode otherwise.
class PlaybackDecision {
  const PlaybackDecision.direct()
      : transcodeTemplate = null,
        directStream = false,
        sourceBitrate = null,
        sourceCodec = null;
  const PlaybackDecision.transcode(Uri this.transcodeTemplate,
      {this.directStream = false, this.sourceBitrate, this.sourceCodec});

  final Uri? transcodeTemplate;

  /// The conversion copies the video (remux, or audio only).
  final bool directStream;

  /// The original video's bitrate (bits per second) and codec, as the server
  /// knows them; null when it doesn't.
  final int? sourceBitrate;
  final String? sourceCodec;

  bool get transcode => transcodeTemplate != null;
}

enum PlayMethod {
  directPlay('DirectPlay'),
  directStream('DirectStream'),
  transcode('Transcode');

  const PlayMethod(this.json);

  final String json;
}

class PlaybackReport {
  const PlaybackReport({
    required this.itemId,
    required this.playSessionId,
    required this.position,
    this.isPaused = false,
    this.playMethod = PlayMethod.directPlay,
    this.runtime,
  });

  final String itemId;
  final String playSessionId;
  final Duration position;
  final bool isPaused;
  final PlayMethod playMethod;

  /// The item's length, for servers whose reports carry it (Plex).
  final Duration? runtime;

  Map<String, Object?> toJson() => {
        'ItemId': itemId,
        'MediaSourceId': itemId,
        'PlaySessionId': playSessionId,
        'PositionTicks': position.inMicroseconds * 10,
        'IsPaused': isPaused,
        'CanSeek': false,
        'PlayMethod': playMethod.json,
      };
}

/// Artwork the app shows.
enum ImageKind {
  /// Posters and thumbnails.
  primary,

  /// A show's or channel's clear logo.
  logo,
}

/// A Jellyfin, Emby or Plex server, signed in or not: what the app asks of
/// it. Every client keeps the same rules for when it's asked and what a
/// failure means (media-servers spec).
abstract interface class MediaServer {
  ServerKind get kind;
  String get serverUrl;

  /// This profile's device id (Plex's client identifier).
  String get deviceId;

  /// Headers every request to the server carries, media included.
  Map<String, String> get authHeaders;

  /// The server's name, version and id, from a request that needs no
  /// sign-in. Throws [ServerException] when no server of this kind answers.
  Future<ServerInfo> publicInfo();

  /// Throws [ServerException] (401) if the sign-in is no longer valid.
  Future<void> checkSession();

  /// Ends the sign-in on the server.
  Future<void> logout();

  Future<List<ServerLibrary>> libraries();

  /// The whole index of the user's video and music libraries (see
  /// `fetchLibraryIndex`), with the programs under each of [channelRoots]
  /// (channel and block source roots) recorded. With [providerIds], titles'
  /// TVDB, TMDB and IMDb ids are asked for too (multi-server).
  Future<LibraryIndex> fetchLibraryIndex(
      {List<CommercialPool> pools = const [],
      Set<String> channelRoots = const {},
      bool providerIds = false,
      void Function(String status)? onStatus,
      void Function(List<ServerLibrary> libraries)? onLibraries});

  /// The ids of the videos under root [rootId] (a library, folder, show,
  /// season or collection), recursively; nothing else of them.
  Future<List<String>> idsUnder(String rootId);

  /// The folders inside library [libraryId], as a tree.
  Future<List<FolderNode>> folderTree(String libraryId);

  /// The commercial stretches the server knows in [itemId], in order; none
  /// when it has no such feature.
  Future<List<MediaSegment>> commercialSegments(String itemId);

  /// The original file of [sourceId], for direct play and analysis.
  Uri streamUri(String sourceId);

  /// A cheap request that keeps connections to the server open.
  Uri get pingUri;

  /// Whether [itemId] can be direct-played under [maxBitrate] (bits per
  /// second; null for no limit) on a device described by [profile] (a
  /// Jellyfin-style device profile; the Linux one when null). With
  /// [forceTranscode], direct play and stream copy are ruled out.
  Future<PlaybackDecision> playbackDecision(String itemId,
      {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero, Map<String, Object?>? profile});

  /// One transcode job's URL: [template] joined at [startAt], under its own
  /// [playSessionId]. Plex asks for the job's decision first.
  Future<Uri> transcodeUri(Uri template, {required String playSessionId, required Duration startAt});

  /// Stops the transcode job [playSessionId] started by this device.
  Future<void> stopTranscode(String playSessionId);

  /// Whether a transcode's stream keeps the source's own times (Plex's HLS
  /// playlists cover the whole item, and the player starts at the join
  /// point), rather than starting at 0 where it joined (Jellyfin and Emby).
  bool get transcodeKeepsSourceTime;

  Uri imageUri(String itemId, ImageKind kind, {int? maxHeight, String? tag});

  Future<void> reportPlaybackStart(PlaybackReport report);
  Future<void> reportPlaybackProgress(PlaybackReport report);
  Future<void> reportPlaybackStopped(PlaybackReport report);

  /// The server's Live TV (live-tv-sources); null for a server without the
  /// capability.
  LiveTv? get liveTv;

  void close();
}
