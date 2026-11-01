import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../../commercials/commercial_pool.dart';
import '../../jellyfin/jellyfin_client.dart';
import '../../library/library_index.dart';
import '../../playback/playback_diagnostics.dart';
import '../live_tv.dart';
import '../media_server.dart';
import 'plex_account.dart';
import 'plex_library.dart';
import 'plex_live_tv.dart';

/// A Plex Media Server, reached at one of its addresses (design D6–D9).
class PlexClient implements MediaServer {
  PlexClient({
    required String serverUrl,
    required this.deviceId,
    required this.deviceName,
    this.accessToken,
    this.userId,
    this.accountToken,
    this.relay = false,
    http.Client? httpClient,
  })  : serverUrl = JellyfinClient.normalizeServerUrl(serverUrl),
        _http = httpClient ?? (PlaybackDiagnostics.enabled ? DiagnosticHttpClient(http.Client()) : http.Client());

  factory PlexClient.fromSession(ServerSession session, {required String deviceName}) => PlexClient(
        serverUrl: session.serverUrl,
        deviceId: session.deviceId,
        deviceName: deviceName,
        accessToken: session.accessToken,
        userId: session.userId,
        accountToken: session.accountToken,
        relay: session.relay,
      );

  @override
  ServerKind get kind => ServerKind.plex;

  @override
  final String serverUrl;
  @override
  final String deviceId;
  final String deviceName;
  String? accessToken;
  String? userId;

  /// The plex.tv token, for signing out.
  final String? accountToken;

  /// Connected through Plex's relay (quality is limited).
  final bool relay;
  final http.Client _http;

  /// The loaded library, for part paths (see [streamUri]).
  LibraryIndex Function()? index;

  /// The part path of one of this server's own ids, looked up in the loaded
  /// library (multi-server: the library holds global ids, and a copy may be
  /// another entry's alternate). Used before [index] when set.
  String? Function(String sourceId)? partPath;

  /// Part paths from this client's own last scan, until [index] has them.
  final _scanned = <String, String>{};

  static const _timeout = Duration(seconds: 30);
  static const _pageSize = 500;

  @override
  Map<String, String> get authHeaders => {
        for (final e in plexHeaders(clientId: deviceId, deviceName: deviceName, token: accessToken).entries)
          if (e.key != 'Accept') e.key: e.value,
      };

  Uri uri(String path, [Map<String, Object?>? query]) {
    final params = <String, String>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return Uri.parse('$serverUrl$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<Object?> _send(String method, String path, {Map<String, Object?>? query, Map<String, String>? headers}) async {
    final request = http.Request(method, uri(path, query))
      ..headers.addAll(authHeaders)
      ..headers['Accept'] = 'application/json'
      ..headers.addAll(headers ?? const {});
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ServerException('The server took too long to respond.');
    } on Exception catch (e) {
      throw ServerException('Could not reach the server ($e).');
    }
    if (response.statusCode == 401) {
      throw ServerException('The Plex sign-in expired.', statusCode: 401);
    }
    if (response.statusCode >= 400) {
      final body = response.body;
      throw ServerException('Server error ${response.statusCode} on $path.',
          statusCode: response.statusCode, detail: body.length > 400 ? body.substring(0, 400) : body);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  /// A request's `MediaContainer`, for the Live TV client.
  Future<Map<String, Object?>> container(String path, {Map<String, Object?>? query, Map<String, String>? headers, String method = 'GET'}) async {
    final json = await _send(method, path, query: query, headers: headers);
    return (json as Map<String, Object?>?)?['MediaContainer'] as Map<String, Object?>? ?? const {};
  }

  @override
  late final LiveTv liveTv = PlexLiveTv(this);

  Future<Map<String, Object?>> _container(String path, [Map<String, Object?>? query, Map<String, String>? headers]) async {
    final json = await _send('GET', path, query: query, headers: headers);
    return (json as Map<String, Object?>?)?['MediaContainer'] as Map<String, Object?>? ?? const {};
  }

  static List<Map<String, Object?>> _list(Map<String, Object?> container, String key) =>
      (container[key] as List? ?? const []).cast<Map<String, Object?>>();

  // ---- Sign-in ----------------------------------------------------------

  @override
  Future<ServerInfo> publicInfo() async {
    final Map<String, Object?> c;
    try {
      c = await _container('/identity');
    } on ServerException catch (e) {
      throw ServerException('No Plex server found at $serverUrl. ${e.message}');
    } on TypeError {
      throw ServerException('$serverUrl did not answer like a Plex server.');
    }
    final id = c['machineIdentifier'] as String?;
    if (id == null) throw ServerException('$serverUrl did not answer like a Plex server.');
    var name = 'Plex';
    if (accessToken != null) {
      try {
        name = (await _container('/'))['friendlyName'] as String? ?? name;
      } on ServerException {
        // The name is only for showing.
      }
    }
    return ServerInfo(url: serverUrl, name: name, version: c['version'] as String? ?? '?', id: id, kind: ServerKind.plex);
  }

  /// The server root needs a valid token (401 otherwise).
  @override
  Future<void> checkSession() => _send('GET', '/');

  /// Plex has no per-device sign-out on the server: the device is removed
  /// from the account instead (when the account allows it).
  @override
  Future<void> logout() async {
    final token = accountToken;
    if (token == null) return;
    final account = PlexAccount(clientId: deviceId, deviceName: deviceName);
    try {
      await account.signOut(token);
    } finally {
      account.close();
    }
  }

  // ---- Libraries --------------------------------------------------------

  /// Library ids carry a prefix: Plex's section keys and item keys are both
  /// small numbers, and a pool root's library must never look like one of
  /// its own items.
  static const _libraryPrefix = 'library:';

  static String _section(String libraryId) =>
      libraryId.startsWith(_libraryPrefix) ? libraryId.substring(_libraryPrefix.length) : libraryId;

  @override
  Future<List<ServerLibrary>> libraries() async {
    final c = await _container('/library/sections');
    return [
      for (final d in _list(c, 'Directory'))
        if (switch (d['type']) {
          'show' => 'tvshows',
          // Libraries of plain video files (Plex's "Other Videos").
          'movie' when '${d['scanner']}'.contains('Video Files') => 'homevideos',
          'movie' => 'movies',
          'artist' => 'music',
          // Photo libraries appear nowhere in the app.
          _ => null,
        }
            case final type?)
          ServerLibrary(id: '$_libraryPrefix${d['key']}', name: d['title'] as String? ?? 'Library', collectionType: type),
    ];
  }

  /// Every item of [type] (Plex's numbers: 1 movie, 2 show, 4 episode,
  /// 10 track) in [section], a page at a time.
  Future<List<Map<String, Object?>>> _all(String section, int type, {Map<String, Object?>? query}) =>
      _paged('/library/sections/$section/all', {'type': type, ...?query});

  Future<List<Map<String, Object?>>> _paged(String path, Map<String, Object?> query) async {
    final results = <Map<String, Object?>>[];
    var start = 0;
    while (true) {
      final c = await _container(path, {'includeGuids': 0, ...query}, {
        'X-Plex-Container-Start': '$start',
        'X-Plex-Container-Size': '$_pageSize',
      });
      final items = _list(c, 'Metadata');
      results.addAll(items);
      final total = (c['totalSize'] as num?)?.toInt() ?? results.length;
      start += items.length;
      if (items.isEmpty || start >= total) return results;
    }
  }

  @override
  Future<LibraryIndex> fetchLibraryIndex(
      {List<CommercialPool> pools = const [],
      Set<String> channelRoots = const {},
      bool providerIds = false,
      void Function(String status)? onStatus,
      void Function(List<ServerLibrary> libraries)? onLibraries}) async {
    final libraries = await this.libraries();
    // Only a profile with several servers asks for them (multi-server D4).
    final guids = providerIds ? const {'includeGuids': 1} : null;
    onLibraries?.call(libraries);
    final poolsByItem = <String, List<String>>{};
    final commercials = <String, Map<String, Object?>>{};
    final poolRoots = <String>{};
    for (final pool in pools) {
      for (final root in pool.roots) {
        poolRoots.add(root.itemId);
        onStatus?.call('Scanning ${pool.name}…');
        for (final item in await _withChapters(await itemsUnder(root.itemId))) {
          final id = '${item['ratingKey']}';
          commercials[id] = item;
          final ids = poolsByItem.putIfAbsent(id, () => []);
          if (!ids.contains(pool.id)) ids.add(pool.id);
        }
      }
    }
    final shows = <Map<String, Object?>>[];
    final episodes = <Map<String, Object?>>[];
    final movies = <Map<String, Object?>>[];
    final tracks = <Map<String, Object?>>[];
    final musicVideos = <Map<String, Object?>>[];
    for (final lib in libraries) {
      if (poolRoots.contains(lib.id)) continue;
      onStatus?.call('Scanning ${lib.name}…');
      final scanStart = DateTime.now();
      final section = _section(lib.id);
      if (lib.isMusic) {
        tracks.addAll(await _all(section, 10));
        musicVideos.addAll(await _musicVideos(section));
      } else if (lib.collectionType == 'tvshows') {
        shows.addAll(await _all(section, 2, query: guids));
        episodes.addAll(await _withChapters(await _all(section, 4, query: guids)));
      } else if (lib.collectionType == 'movies') {
        movies.addAll(await _withChapters(await _all(section, 1, query: guids)));
      }
      // A library of plain video files has no programs, as on Jellyfin,
      // where its videos aren't movies: it's only a source of pools.
      PlaybackDiagnostics.note('SCAN', '${lib.name}: ${DateTime.now().difference(scanStart).inMilliseconds} ms');
    }
    final index = libraryIndexFromPlex(
      shows: shows,
      episodes: episodes,
      movies: movies,
      commercials: commercials.values.toList(),
      tracks: tracks,
      musicVideos: musicVideos,
      poolsByItem: poolsByItem,
    );
    _scanned
      ..clear()
      ..addAll({
        for (final e in [...index.episodes, ...index.movies, ...index.commercials, ...index.songs, ...index.musicVideos])
          e.id: ?e.streamPath,
      });
    if (channelRoots.isEmpty) return index;
    onStatus?.call('Scanning channel sources…');
    final rootsStart = DateTime.now();
    final roots = await fetchRoots(this, channelRoots);
    PlaybackDiagnostics.note('SCAN', '${channelRoots.length} channel roots: '
        '${DateTime.now().difference(rootsStart).inMilliseconds} ms');
    return index.withRoots(roots.found, missing: roots.missing);
  }

  @override
  Future<List<String>> idsUnder(String rootId) async {
    if (rootId.startsWith(_libraryPrefix)) {
      final section = _section(rootId);
      final lib = (await libraries()).where((l) => l.id == rootId).firstOrNull;
      return [for (final i in await _all(section, lib?.collectionType == 'tvshows' ? 4 : 1)) '${i['ratingKey']}'];
    }
    // A collection lists its shows and seasons, not their episodes.
    final ids = <String>[];
    for (final i in await itemsUnder(rootId)) {
      if (i['type'] == 'show' || i['type'] == 'season') {
        ids.addAll([for (final e in await _paged('/library/metadata/${i['ratingKey']}/allLeaves', const {})) '${e['ratingKey']}']);
      } else {
        ids.add('${i['ratingKey']}');
      }
    }
    return ids;
  }

  /// How many items one batched metadata request asks for.
  static const _batch = 50;

  /// [keys]' full metadata, [_batch] at a time (`/library/metadata/1,2,3`),
  /// with [query].
  Future<List<Map<String, Object?>>> _metadata(List<String> keys, Map<String, Object?> query) async {
    final results = <Map<String, Object?>>[];
    for (var i = 0; i < keys.length; i += _batch) {
      final batch = keys.sublist(i, i + _batch > keys.length ? keys.length : i + _batch);
      results.addAll(_list(await _container('/library/metadata/${batch.join(',')}', query), 'Metadata'));
    }
    return results;
  }

  /// [items] with their chapters: section listings leave them out, so the
  /// items that have any (`chapterSource`) are asked for them in batches.
  Future<List<Map<String, Object?>>> _withChapters(List<Map<String, Object?>> items) async {
    final keys = [for (final i in items) if (i['chapterSource'] != null) '${i['ratingKey']}'];
    if (keys.isEmpty) return items;
    final chapters = {
      for (final m in await _metadata(keys, {'includeChapters': 1}))
        if (m['Chapter'] != null) '${m['ratingKey']}': m['Chapter'],
    };
    return [
      for (final i in items)
        if (chapters['${i['ratingKey']}'] case final c?) {...i, 'Chapter': c} else i,
    ];
  }

  /// The music videos of the artists in music [section]: Plex keeps them as
  /// the artists' extras, which only per-item metadata lists.
  Future<List<Map<String, Object?>>> _musicVideos(String section) async {
    final artists = await _all(section, 8);
    final withExtras = await _metadata([for (final a in artists) '${a['ratingKey']}'], {'includeExtras': 1});
    return [
      for (final artist in withExtras)
        for (final extra in _list((artist['Extras'] as Map<String, Object?>?) ?? const {}, 'Metadata'))
          if (extra['subtype'] == 'musicVideo') {'grandparentTitle': artist['title'], ...extra},
    ];
  }

  // ---- Folders for commercial pools -------------------------------------

  /// Node ids of folders: `folder:<section>:<folder key>`. Shows, seasons
  /// and collections use their item key.
  static const _folderPrefix = 'folder:';

  @override
  Future<List<FolderNode>> folderTree(String libraryId) async {
    final section = _section(libraryId);
    final libraries = await this.libraries();
    final lib = libraries.where((l) => l.id == libraryId).firstOrNull;
    final nodes = <FolderNode>[];
    if (lib?.collectionType == 'tvshows') {
      final shows = await _all(section, 2);
      final seasons = await _all(section, 3);
      final byShow = <String, List<FolderNode>>{};
      for (final s in seasons) {
        byShow.putIfAbsent('${s['parentRatingKey']}', () => []).add(FolderNode(
            id: '${s['ratingKey']}', name: s['title'] as String? ?? 'Season', type: 'Season', index: (s['index'] as num?)?.toInt()));
      }
      for (final s in shows) {
        nodes.add(FolderNode(
            id: '${s['ratingKey']}',
            name: s['title'] as String? ?? 'Show',
            type: 'Series',
            children: (byShow['${s['ratingKey']}'] ?? [])..sort(FolderNode.compare)));
      }
    } else {
      nodes.addAll(await _folders(section, null));
    }
    try {
      for (final c in _list(await _container('/library/sections/$section/collections'), 'Metadata')) {
        nodes.add(FolderNode(id: '${c['ratingKey']}', name: c['title'] as String? ?? 'Collection', type: 'BoxSet'));
      }
    } on ServerException catch (e) {
      // Libraries without collections answer 404 on some versions.
      if (e.statusCode != 404) rethrow;
    }
    return nodes..sort(FolderNode.compare);
  }

  /// The sub-folders of [parent] (the library's top when null), and theirs,
  /// level by level.
  Future<List<FolderNode>> _folders(String section, String? parent) async {
    final c = await _container('/library/sections/$section/folder', {'parent': ?parent});
    final nodes = <FolderNode>[];
    for (final d in _list(c, 'Metadata')) {
      if (d['type'] != null && d['type'] != 'folder') continue;
      final key = _folderKey(d['key'] as String? ?? '');
      if (key == null) continue;
      nodes.add(FolderNode(
          id: '$_folderPrefix$section:$key',
          name: (d['title'] as String? ?? '').trim(),
          type: 'Folder',
          children: await _folders(section, key)));
    }
    return nodes..sort(FolderNode.compare);
  }

  /// A folder's own key, from its listing key (`…/folder?parent=12`).
  static String? _folderKey(String key) => Uri.tryParse(key)?.queryParameters['parent'];

  /// Every video under pool root [rootId]: a whole library, a folder (walked
  /// level by level), a show, a season or a collection.
  @visibleForTesting
  Future<List<Map<String, Object?>>> itemsUnder(String rootId) async {
    if (rootId.startsWith(_libraryPrefix)) {
      final section = _section(rootId);
      final lib = (await libraries()).where((l) => l.id == rootId).firstOrNull;
      return _all(section, lib?.collectionType == 'tvshows' ? 4 : 1, query: {'includeChapters': 1});
    }
    if (rootId.startsWith(_folderPrefix)) {
      final [section, key] = rootId.substring(_folderPrefix.length).split(':');
      return _folderItems(section, key);
    }
    final item = (_list(await _container('/library/metadata/$rootId'), 'Metadata')).firstOrNull;
    return switch (item?['type']) {
      'show' => _paged('/library/metadata/$rootId/allLeaves', const {}),
      'collection' || 'season' => _paged('/library/metadata/$rootId/children', const {}),
      'episode' || 'movie' || 'clip' => [?item],
      _ => const [],
    };
  }

  Future<List<Map<String, Object?>>> _folderItems(String section, String parent) async {
    final c = await _container('/library/sections/$section/folder', {'parent': parent});
    final items = <Map<String, Object?>>[];
    for (final d in _list(c, 'Metadata')) {
      if (d['type'] == null || d['type'] == 'folder') {
        if (_folderKey(d['key'] as String? ?? '') case final key?) items.addAll(await _folderItems(section, key));
      } else if (const {'movie', 'episode', 'clip'}.contains(d['type'])) {
        items.add(d);
      }
    }
    return items;
  }

  // ---- Playback ---------------------------------------------------------

  /// Commercial markers (Plex DVR's commercial detection).
  @override
  Future<List<MediaSegment>> commercialSegments(String itemId) async {
    final c = await _container('/library/metadata/$itemId', {'includeMarkers': 1});
    final item = _list(c, 'Metadata').firstOrNull;
    return [
      for (final m in _list(item ?? const {}, 'Marker'))
        if (m['type'] == 'commercial')
          if ((m['startTimeOffset'], m['endTimeOffset']) case (final num start, final num end) when end > start)
            (start: Duration(milliseconds: start.toInt()), end: Duration(milliseconds: end.toInt())),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  /// The original file, from its part path.
  @override
  Uri streamUri(String sourceId) {
    final path = partPath?.call(sourceId) ?? index?.call()[sourceId]?.streamPath ?? _scanned[sourceId];
    if (path == null) throw ServerException('The server has no file for this item; refresh the library.');
    return uri(path);
  }

  @override
  Uri get pingUri => uri('/identity');

  static const _universal = '/video/:/transcode/universal';

  /// What Linux plays (mpv decodes everything), as a Plex client profile.
  static const _linuxContainers = 'mkv,mp4,mov,m4v,avi,ts,mpegts,m2ts,webm,wmv,asf,flv,mpeg,mpg,ogg,3gp';
  static const _linuxVideo = 'h264,hevc,h265,mpeg2video,mpeg4,msmpeg4v3,vc1,vp8,vp9,av1,wmv3,mjpeg';
  static const _linuxAudio = 'aac,ac3,eac3,dca,dts,truehd,mp3,mp2,flac,opus,vorbis,pcm,alac,wmav2,wmapro';

  /// Song files, for the music profile (Plex can't decide a song without one).
  static const _musicContainers = 'mp3,mp4,m4a,aac,flac,ogg,oga,opus,wav,mka';
  static const _musicTarget =
      'add-transcode-target(type=musicProfile&context=streaming&protocol=hls&container=mpegts&audioCodec=aac)';

  /// [profile], a Jellyfin-style device profile (the Android one), as Plex's
  /// client profile extra; everything Linux plays when null.
  static String profileExtra(Map<String, Object?>? profile) {
    String plexCodecs(String list) => list.split(',').map((c) => c == 'dts' ? 'dca' : c).join(',');
    final parts = <String>[];
    if (profile == null) {
      parts.add('add-direct-play-profile(type=videoProfile&container=$_linuxContainers'
          '&videoCodec=$_linuxVideo&audioCodec=$_linuxAudio)');
      parts.add('add-transcode-target(type=videoProfile&context=streaming&protocol=hls'
          '&container=mpegts&videoCodec=h264,hevc,mpeg2video&audioCodec=aac,ac3,eac3,mp3)');
      parts.add('add-direct-play-profile(type=musicProfile&container=$_musicContainers&audioCodec=$_linuxAudio)');
      parts.add(_musicTarget);
      return parts.join('+');
    }
    for (final p in (profile['DirectPlayProfiles'] as List? ?? const []).cast<Map<String, Object?>>()) {
      if (p['Type'] == 'Audio') {
        parts.add('add-direct-play-profile(type=musicProfile&container=${p['Container'] ?? _musicContainers}'
            '&audioCodec=${plexCodecs('${p['AudioCodec']}')})');
        continue;
      }
      if (p['Type'] != 'Video' || p['Container'] == null) continue;
      parts.add('add-direct-play-profile(type=videoProfile&container=${p['Container']}'
          '&videoCodec=${p['VideoCodec']}&audioCodec=${plexCodecs('${p['AudioCodec']}')})');
    }
    final target = (profile['TranscodingProfiles'] as List? ?? const []).cast<Map<String, Object?>>().firstOrNull;
    final video = target?['VideoCodec'] ?? 'h264';
    final audio = plexCodecs('${target?['AudioCodec'] ?? 'aac'}');
    parts.add('add-transcode-target(type=videoProfile&context=streaming&protocol=hls'
        '&container=mpegts&videoCodec=$video&audioCodec=$audio)');
    parts.add(_musicTarget);
    if (target?['MaxAudioChannels'] case final channels?) {
      parts.add('add-limitation(scope=videoAudioCodec&scopeName=*&type=upperBound&name=audio.channels&value=$channels)');
    }
    const names = {'VideoBitDepth': 'video.bitDepth', 'Width': 'video.width', 'Height': 'video.height', 'VideoFramerate': 'video.frameRate'};
    for (final cp in (profile['CodecProfiles'] as List? ?? const []).cast<Map<String, Object?>>()) {
      // Conditions that apply only to some sizes don't translate.
      if (cp['Type'] != 'Video' || cp['ApplyConditions'] != null) continue;
      for (final c in (cp['Conditions'] as List? ?? const []).cast<Map<String, Object?>>()) {
        final codec = cp['Codec'];
        if (c['Property'] == 'VideoProfile' && c['Condition'] == 'EqualsAny') {
          parts.add('add-limitation(scope=videoCodec&scopeName=$codec&type=match&name=video.profile&list=${c['Value']})');
        } else if (names[c['Property']] case final name? when c['Condition'] == 'LessThanEqual') {
          parts.add('add-limitation(scope=videoCodec&scopeName=$codec&type=upperBound&name=$name&value=${c['Value']})');
        }
      }
    }
    return parts.join('+');
  }

  /// The query a decision and its transcode share.
  Map<String, Object?> _transcodeQuery(String itemId,
          {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero, Map<String, Object?>? profile}) =>
      {
        'path': '/library/metadata/$itemId',
        'mediaIndex': 0,
        'partIndex': 0,
        'protocol': 'hls',
        'fastSeek': 1,
        'directPlay': forceTranscode ? 0 : 1,
        'directStream': forceTranscode ? 0 : 1,
        'directStreamAudio': forceTranscode ? 0 : 1,
        'subtitles': 'none',
        'location': relay ? 'wan' : 'lan',
        'maxVideoBitrate': ?switch (maxBitrate ?? (profile?['MaxStreamingBitrate'] as num?)?.toInt()) {
          final b? when b < 1000000000 => b ~/ 1000,
          _ => null,
        },
        // Plex starts the transcoder at the offset either way, but whether
        // its playlist covers the whole item or starts at the offset varies
        // between servers; with copyts it is always the whole item, in the
        // source's own times (see transcodeKeepsSourceTime).
        'copyts': 1,
        'offset': startAt.inMilliseconds / 1000,
        // Plex has no profile of its own for this app: the generic one is
        // empty, and the extra says what plays.
        'X-Plex-Client-Profile-Name': 'Generic',
        'X-Plex-Client-Profile-Extra': profileExtra(profile),
      };

  @override
  Future<PlaybackDecision> playbackDecision(String itemId,
      {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero, Map<String, Object?>? profile}) async {
    final query = _transcodeQuery(itemId,
        maxBitrate: maxBitrate, forceTranscode: forceTranscode, startAt: startAt, profile: profile);
    final session = _newSession();
    final c = await _container('$_universal/decision', {...query, 'session': session},
        {'X-Plex-Session-Identifier': session});
    final part = _list(_list(_list(c, 'Metadata').firstOrNull ?? const {}, 'Media').firstOrNull ?? const {}, 'Part')
        .firstOrNull;
    final video = _list(part ?? const {}, 'Stream').where((s) => (s['streamType'] as num?)?.toInt() == 1).firstOrNull;
    if (!forceTranscode && (c['directPlayDecisionCode'] as num?)?.toInt() == 1000) {
      return const PlaybackDecision.direct();
    }
    final code = (c['transcodeDecisionCode'] as num?)?.toInt();
    if (code == null || code >= 2000) {
      throw ServerException('The server would not convert this item (${c['transcodeDecisionText'] ?? code}).');
    }
    // The decision describes the conversion; the original is the item's.
    final source = _list(
            _list(await _container('/library/metadata/$itemId'), 'Metadata').firstOrNull ?? const {}, 'Media')
        .firstOrNull;
    return PlaybackDecision.transcode(uri('$_universal/start.m3u8', query),
        directStream: !forceTranscode && video?['decision'] == 'copy',
        sourceBitrate: switch (source?['bitrate']) { final num kbps => kbps.toInt() * 1000, _ => null },
        sourceCodec: source?['videoCodec'] as String?);
  }

  /// Plex starts a transcode only for a session it has made a decision for,
  /// so each job asks its own first, with the job's query.
  @override
  Future<Uri> transcodeUri(Uri template, {required String playSessionId, required Duration startAt}) async {
    final query = {
      for (final e in template.queryParameters.entries)
        if (e.key != 'session' && e.key != 'offset') e.key: e.value,
      'session': playSessionId,
      'offset': '${startAt.inMilliseconds / 1000}',
    };
    await _send('GET', '$_universal/decision', query: query, headers: {'X-Plex-Session-Identifier': playSessionId});
    return template.replace(queryParameters: {...query, 'X-Plex-Session-Identifier': playSessionId});
  }

  @override
  bool get transcodeKeepsSourceTime => true;

  @override
  Future<void> stopTranscode(String playSessionId) =>
      _send('GET', '$_universal/stop', query: {'session': playSessionId});

  /// Posters and logos through Plex's photo transcoder. An item without a
  /// clear logo answers 404, which the app treats as no logo.
  @override
  Uri imageUri(String itemId, ImageKind kind, {int? maxHeight, String? tag}) {
    final height = maxHeight ?? 640;
    return uri('/photo/:/transcode', {
      'url': '/library/metadata/$itemId/${kind == ImageKind.logo ? 'clearLogo' : 'thumb'}',
      'height': height,
      'width': kind == ImageKind.logo ? height * 4 : height * 2,
      'minSize': 1,
      'upscale': 1,
      // Logos keep their transparency.
      if (kind == ImageKind.logo) 'format': 'png',
    });
  }

  // ---- Reports ----------------------------------------------------------

  Future<void> _timeline(PlaybackReport report, String state) => _send('GET', '/:/timeline', query: {
        'ratingKey': report.itemId,
        'key': '/library/metadata/${report.itemId}',
        'state': state,
        'time': report.position.inMilliseconds,
        'duration': ?report.runtime?.inMilliseconds,
        'playbackTime': report.position.inMilliseconds,
        'hasMDE': 1,
      }, headers: {
        'X-Plex-Session-Identifier': report.playSessionId,
      });

  @override
  Future<void> reportPlaybackStart(PlaybackReport report) => _timeline(report, 'playing');

  @override
  Future<void> reportPlaybackProgress(PlaybackReport report) =>
      _timeline(report, report.isPaused ? 'paused' : 'playing');

  @override
  Future<void> reportPlaybackStopped(PlaybackReport report) => _timeline(report, 'stopped');

  static String _newSession() => 'decide-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  @override
  void close() => _http.close();
}
