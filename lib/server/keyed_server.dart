import '../commercials/commercial_pool.dart';
import '../library/library_index.dart';
import 'live_tv.dart';
import 'media_server.dart';
import 'server_set.dart';

/// An added server's client as the rest of the app sees it (multi-server
/// D2): it takes and gives the ids the library holds (`s2~48213`), and the
/// server only ever sees its own. The main server's client is used as it is.
class KeyedServer implements MediaServer {
  KeyedServer(this.inner, this.key);

  final MediaServer inner;
  final String key;

  String _raw(String id) => ServerSet.rawId(id);
  String _global(String id) => ServerSet.globalId(key, id);

  FolderNode _node(FolderNode n) => FolderNode(
      id: _global(n.id), name: n.name, type: n.type, index: n.index, children: [for (final c in n.children) _node(c)]);

  PlaybackReport _report(PlaybackReport r) => PlaybackReport(
      itemId: _raw(r.itemId),
      playSessionId: r.playSessionId,
      position: r.position,
      isPaused: r.isPaused,
      playMethod: r.playMethod,
      runtime: r.runtime);

  @override
  ServerKind get kind => inner.kind;
  @override
  String get serverUrl => inner.serverUrl;
  @override
  String get deviceId => inner.deviceId;
  @override
  Map<String, String> get authHeaders => inner.authHeaders;
  @override
  Future<ServerInfo> publicInfo() => inner.publicInfo();
  @override
  Future<void> checkSession() => inner.checkSession();
  @override
  Future<void> logout() => inner.logout();

  @override
  Future<List<ServerLibrary>> libraries() async => [
        for (final l in await inner.libraries())
          ServerLibrary(id: _global(l.id), name: l.name, collectionType: l.collectionType)
      ];

  @override
  Future<LibraryIndex> fetchLibraryIndex(
      {List<CommercialPool> pools = const [],
      Set<String> channelRoots = const {},
      bool providerIds = false,
      void Function(String status)? onStatus,
      void Function(List<ServerLibrary> libraries)? onLibraries}) async {
    final index = await inner.fetchLibraryIndex(
        pools: [
          for (final p in pools)
            CommercialPool(id: p.id, name: p.name, kind: p.kind, roots: [
              for (final r in p.roots) PoolRoot(itemId: _raw(r.itemId), libraryId: _raw(r.libraryId), label: r.label)
            ])
        ],
        channelRoots: {for (final r in channelRoots) _raw(r)},
        providerIds: providerIds,
        onStatus: onStatus,
        onLibraries: onLibraries == null
            ? null
            : (libraries) => onLibraries([
                  for (final l in libraries) ServerLibrary(id: _global(l.id), name: l.name, collectionType: l.collectionType)
                ]));
    return index.withServerKey(_global);
  }

  @override
  Future<List<String>> idsUnder(String rootId) async => [for (final id in await inner.idsUnder(_raw(rootId))) _global(id)];

  @override
  Future<List<FolderNode>> folderTree(String libraryId) async =>
      [for (final n in await inner.folderTree(_raw(libraryId))) _node(n)];

  @override
  Future<List<MediaSegment>> commercialSegments(String itemId) => inner.commercialSegments(_raw(itemId));

  @override
  Uri streamUri(String sourceId) => inner.streamUri(_raw(sourceId));

  @override
  Uri get pingUri => inner.pingUri;

  @override
  Future<PlaybackDecision> playbackDecision(String itemId,
          {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero, Map<String, Object?>? profile}) =>
      inner.playbackDecision(_raw(itemId),
          maxBitrate: maxBitrate, forceTranscode: forceTranscode, startAt: startAt, profile: profile);

  @override
  Future<Uri> transcodeUri(Uri template, {required String playSessionId, required Duration startAt}) =>
      inner.transcodeUri(template, playSessionId: playSessionId, startAt: startAt);

  @override
  Future<void> stopTranscode(String playSessionId) => inner.stopTranscode(playSessionId);

  @override
  bool get transcodeKeepsSourceTime => inner.transcodeKeepsSourceTime;

  @override
  Uri imageUri(String itemId, ImageKind kind, {int? maxHeight, String? tag}) =>
      inner.imageUri(_raw(itemId), kind, maxHeight: maxHeight, tag: tag);

  @override
  Future<void> reportPlaybackStart(PlaybackReport report) => inner.reportPlaybackStart(_report(report));
  @override
  Future<void> reportPlaybackProgress(PlaybackReport report) => inner.reportPlaybackProgress(_report(report));
  @override
  Future<void> reportPlaybackStopped(PlaybackReport report) => inner.reportPlaybackStopped(_report(report));

  @override
  LiveTv? get liveTv => inner.liveTv;

  /// The server's own client is closed by its owner, never through this.
  @override
  void close() {}
}
