import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show protected, visibleForTesting;
import 'package:http/http.dart' as http;

import '../app_version.dart';
import '../commercials/commercial_pool.dart';
import '../library/library_index.dart';
import '../playback/playback_diagnostics.dart';
import '../server/languages.dart';
import '../server/live_tv.dart';
import '../server/media_server.dart';
import 'jellyfin_live_tv.dart';

class QuickConnectRequest {
  const QuickConnectRequest({required this.secret, required this.code});

  final String secret;
  final String code;
}

/// Thin client over the parts of the Jellyfin REST API this app needs.
/// Emby's API is close enough that [EmbyClient] only overrides what differs.
class JellyfinClient implements MediaServer {
  JellyfinClient({
    required String serverUrl,
    required this.deviceId,
    required this.deviceName,
    this.accessToken,
    this.userId,
    http.Client? httpClient,
  })  : serverUrl = normalizeServerUrl(serverUrl),
        // Diagnostics builds log every request (see DiagnosticHttpClient).
        _http = httpClient ?? (PlaybackDiagnostics.enabled ? DiagnosticHttpClient(http.Client()) : http.Client());

  factory JellyfinClient.fromSession(ServerSession session, {required String deviceName}) =>
      JellyfinClient(
        serverUrl: session.serverUrl,
        deviceId: session.deviceId,
        deviceName: deviceName,
        accessToken: session.accessToken,
        userId: session.userId,
      );

  @override
  ServerKind get kind => ServerKind.jellyfin;

  static const clientName = 'Nightingale TV';
  static const clientVersion = appVersion;
  static const _timeout = Duration(seconds: 30);

  @override
  final String serverUrl;
  @override
  final String deviceId;
  final String deviceName;
  String? accessToken;
  String? userId;
  final http.Client _http;

  /// Adds a scheme if missing and drops trailing slashes.
  /// `example.org:8920` → `https://example.org:8920`.
  static String normalizeServerUrl(String input) {
    var url = input.trim();
    // Tolerate "https:host" (missing slashes).
    url = url.replaceFirstMapped(RegExp(r'^(https?):/*', caseSensitive: false),
        (m) => '${m[1]!.toLowerCase()}://');
    if (!url.contains('://')) url = 'https://$url';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String get authorizationHeader {
    String q(String v) => v.replaceAll('"', "'");
    final parts = [
      'Client="${q(clientName)}"',
      'Device="${q(deviceName)}"',
      'DeviceId="${q(deviceId)}"',
      'Version="$clientVersion"',
      if (accessToken != null) 'Token="$accessToken"',
    ];
    return 'MediaBrowser ${parts.join(', ')}';
  }

  @override
  Map<String, String> get authHeaders => {'Authorization': authorizationHeader};

  Uri uri(String path, [Map<String, Object?>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value == null) return;
      params[key] = value is Iterable ? value.join(',') : '$value';
    });
    return Uri.parse('$serverUrl$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  @protected
  Future<Object?> send(String method, String path,
      {Map<String, Object?>? query, Object? body}) async {
    final request = http.Request(method, uri(path, query))
      ..headers.addAll(authHeaders)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    } else if (method == 'POST') {
      // Jellyfin rejects body-less POSTs without an explicit empty JSON body.
      request.headers['Content-Type'] = 'application/json';
      request.body = '{}';
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ServerException('The server took too long to respond.');
    } on http.ClientException catch (e) {
      throw ServerException('Could not reach the server (${e.message}).');
    } on Exception catch (e) {
      throw ServerException('Could not reach the server ($e).');
    }
    if (response.statusCode == 401) {
      throw ServerException('Wrong username or password, or the session expired.',
          statusCode: 401);
    }
    if (response.statusCode >= 400) {
      throw ServerException('Server error ${response.statusCode} on $path.',
          statusCode: response.statusCode, detail: _detail(response.body));
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return null;
    }
  }

  static String _detail(String body) => body.length > 400 ? body.substring(0, 400) : body;

  /// [send], for the Live TV client.
  Future<Object?> request(String method, String path, {Map<String, Object?>? query, Object? body}) =>
      send(method, path, query: query, body: body);

  /// Whether the conversion at [template] keeps [source]'s video, as
  /// [copiesVideo] decides it for this kind of server.
  bool keepsSourceVideo(Uri template, Map<String, Object?> source) => copiesVideo(template, source);

  /// The signed-in user (with its policy).
  String get userPath => '/Users/Me';

  @override
  late final LiveTv liveTv = JellyfinLiveTv(this);

  @override
  Future<void> checkSession() => send('GET', '/Users/Me');

  @protected
  Future<Map<String, Object?>> getMap(String path, [Map<String, Object?>? query]) async =>
      (await send('GET', path, query: query)) as Map<String, Object?>;

  @override
  Future<ServerInfo> publicInfo() async {
    final Map<String, Object?> json;
    try {
      json = await getMap('/System/Info/Public');
    } on ServerException catch (e) {
      throw ServerException('No Jellyfin server found at $serverUrl. ${e.message}');
    } on TypeError {
      throw ServerException('$serverUrl did not answer like a Jellyfin server.');
    }
    // Emby answers the same request, but without Jellyfin's product name
    // ("Jellyfin Server") or its startup-wizard flag.
    final jellyfin = '${json['ProductName'] ?? ''}'.contains('Jellyfin') || json.containsKey('StartupWizardCompleted');
    final kind = jellyfin ? ServerKind.jellyfin : ServerKind.emby;
    return ServerInfo(
      url: serverUrl,
      name: json['ServerName'] as String? ?? kind.label,
      version: json['Version'] as String? ?? '?',
      id: json['Id'] as String?,
      kind: kind,
    );
  }

  /// The server's own id (see [ServerSession.serverId]).
  Future<String?> serverId() async => (await publicInfo()).id;

  /// [serverId] from a client made just for it, closed afterwards.
  Future<String?> serverIdOnce() async {
    try {
      return await serverId();
    } finally {
      close();
    }
  }

  ServerSession _sessionFrom(Map<String, Object?> json, String serverName) {
    final user = json['User'] as Map<String, Object?>;
    accessToken = json['AccessToken'] as String;
    userId = user['Id'] as String;
    return ServerSession(
      serverUrl: serverUrl,
      serverName: serverName,
      userId: userId!,
      userName: user['Name'] as String,
      accessToken: accessToken!,
      deviceId: deviceId,
      kind: kind,
    );
  }

  Future<ServerSession> authenticateByName(String username, String password,
      {required String serverName}) async {
    final json = await send('POST', '/Users/AuthenticateByName',
        body: {'Username': username, 'Pw': password}) as Map<String, Object?>;
    return _sessionFrom(json, serverName);
  }

  Future<bool> quickConnectEnabled() async {
    try {
      return await send('GET', '/QuickConnect/Enabled') == true;
    } on ServerException {
      return false;
    }
  }

  Future<QuickConnectRequest> quickConnectInitiate() async {
    final json = await send('POST', '/QuickConnect/Initiate') as Map<String, Object?>;
    return QuickConnectRequest(secret: json['Secret'] as String, code: json['Code'] as String);
  }

  Future<bool> quickConnectAuthorized(String secret) async {
    final json = await getMap('/QuickConnect/Connect', {'Secret': secret});
    return json['Authenticated'] == true;
  }

  Future<ServerSession> authenticateWithQuickConnect(String secret,
      {required String serverName}) async {
    final json = await send('POST', '/Users/AuthenticateWithQuickConnect',
        body: {'Secret': secret}) as Map<String, Object?>;
    return _sessionFrom(json, serverName);
  }

  @override
  Future<void> logout() async {
    await send('POST', '/Sessions/Logout');
  }

  @override
  Future<List<ServerLibrary>> libraries() async {
    final json = await getMap(viewsPath, viewsQuery);
    return [
      for (final v in (json['Items'] as List).cast<Map<String, Object?>>())
        ServerLibrary(
          id: v['Id'] as String,
          name: v['Name'] as String,
          collectionType: v['CollectionType'] as String?,
        ),
    ];
  }

  /// Fetches every item matching [query], following pagination.
  Future<List<Map<String, Object?>>> allItems(Map<String, Object?> query,
      {int pageSize = 500}) async {
    final results = <Map<String, Object?>>[];
    var start = 0;
    while (true) {
      final page = await getMap(itemsPath, {
        ...query,
        ...itemsQuery,
        'StartIndex': start,
        'Limit': pageSize,
      });
      final items = (page['Items'] as List).cast<Map<String, Object?>>();
      results.addAll(items);
      final total = page['TotalRecordCount'] as int? ?? results.length;
      start += items.length;
      if (items.isEmpty || start >= total) return results;
    }
  }

  /// Downloads the index for every video and music library the user can see:
  /// shows, episodes and movies, plus music videos from the video libraries
  /// and songs from the music libraries.
  ///
  /// Videos under any of [pools]' folders become commercials (tagged with the
  /// pools they're in) and are left out of the programs, even when their
  /// folder sits inside a library of shows or movies. A library that is itself
  /// a pool folder isn't scanned for programs at all.
  ///
  /// Each of [channelRoots] is listed once, ids only, and the episodes and
  /// movies under it are recorded ([LibraryIndex.rootsByItem]).
  @override
  Future<LibraryIndex> fetchLibraryIndex(
      {List<CommercialPool> pools = const [],
      Set<String> channelRoots = const {},
      bool providerIds = false,
      void Function(String status)? onStatus,
      void Function(List<ServerLibrary> libraries)? onLibraries}) async {
    final libraries = (await this.libraries()).where((l) => l.isVideo || l.isMusic).toList();
    // Only a profile with several servers asks for them (multi-server D4).
    final ids = providerIds ? ',ProviderIds' : '';
    onLibraries?.call(libraries);
    final poolsByItem = <String, List<String>>{};
    final commercials = <String, Map<String, Object?>>{};
    final poolRoots = <String>{};
    for (final pool in pools) {
      for (final root in pool.roots) {
        poolRoots.add(root.itemId);
        onStatus?.call('Scanning ${pool.name}…');
        final items = await itemsUnder(root.itemId);
        for (final item in items) {
          final id = item['Id'] as String;
          commercials[id] = item;
          final ids = poolsByItem.putIfAbsent(id, () => []);
          if (!ids.contains(pool.id)) ids.add(pool.id);
        }
      }
    }
    final series = <Map<String, Object?>>[];
    final episodes = <Map<String, Object?>>[];
    final movies = <Map<String, Object?>>[];
    final songs = <Map<String, Object?>>[];
    final musicVideos = <Map<String, Object?>>[];
    // Minimal fields and no images: music libraries can hold 50,000 songs.
    const musicFields = 'Genres,ProductionYear,Artists,AlbumArtist,Album,AlbumId,OfficialRating,Etag,MediaSources';
    for (final lib in libraries) {
      if (poolRoots.contains(lib.id)) continue;
      onStatus?.call('Scanning ${lib.name}…');
      final scanStart = DateTime.now();
      final common = {'ParentId': lib.id, 'Recursive': 'true', 'ImageTypeLimit': 1};
      if (lib.isMusic) {
        songs.addAll(await allItems({
          ...common,
          'IncludeItemTypes': 'Audio',
          'IsMissing': 'false',
          'Fields': musicFields,
          'EnableImages': 'false',
          'EnableUserData': 'false',
        }));
        PlaybackDiagnostics.note('SCAN', '${lib.name}: ${songs.length} songs so far, '
            '${DateTime.now().difference(scanStart).inMilliseconds} ms');
        continue;
      }
      series.addAll(await allItems({
        ...common,
        'IncludeItemTypes': 'Series',
        // Provider ids always: they tell a server's copies of a show apart
        // (lineup-dedup D1).
        'Fields': 'Genres,OfficialRating,ProviderIds',
      }));
      episodes.addAll(await allItems({
        ...common,
        'IncludeItemTypes': 'Episode',
        'IsMissing': 'false',
        'Fields': 'Overview,Chapters,Etag,DateCreated$ids',
        'EnableImages': 'false',
        // Play counts, for Least watched first.
        'EnableUserData': 'true',
      }));
      movies.addAll(await allItems({
        ...common,
        'IncludeItemTypes': 'Movie',
        'Fields': 'Overview,Genres,OfficialRating,Chapters,Etag$ids',
        'EnableImages': 'false',
        'EnableUserData': 'true',
      }));
      musicVideos.addAll(await allItems({
        ...common,
        'IncludeItemTypes': 'MusicVideo',
        'IsMissing': 'false',
        'Fields': musicFields,
        'EnableImages': 'false',
        'EnableUserData': 'false',
      }));
      PlaybackDiagnostics.note('SCAN', '${lib.name}: ${DateTime.now().difference(scanStart).inMilliseconds} ms');
    }
    final index = LibraryIndex.fromJellyfinItems(
      seriesItems: series,
      episodeItems: episodes,
      movieItems: movies,
      commercialItems: commercials.values.toList(),
      songItems: songs,
      musicVideoItems: musicVideos,
      poolsByItem: poolsByItem,
    );
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
    Future<List<Map<String, Object?>>> under(String id, String types) => allItems({
          'ParentId': id,
          'Recursive': 'true',
          'IncludeItemTypes': types,
          'IsMissing': 'false',
          'EnableImages': 'false',
          'EnableUserData': 'false',
        });
    final items = await under(rootId, 'Movie,Episode,Series,BoxSet');
    final ids = [for (final i in items) if (i['Type'] == 'Movie' || i['Type'] == 'Episode') i['Id'] as String];
    // A folder of collections: each one's items are its own.
    for (final box in items.where((i) => i['Type'] == 'BoxSet' && i['Id'] != rootId)) {
      ids.addAll(await idsUnder(box['Id'] as String));
    }
    // A collection holds its shows, not their episodes: shows none of whose
    // episodes came with them are listed on their own.
    final covered = {for (final i in items) if (i['Type'] == 'Episode') i['SeriesId']};
    for (final show in items.where((i) => i['Type'] == 'Series' && !covered.contains(i['Id']))) {
      ids.addAll([for (final e in await under(show['Id'] as String, 'Episode')) e['Id'] as String]);
    }
    return ids;
  }

  /// Every video under pool root [rootId] (a folder, show, season or
  /// collection), with what the index keeps of commercials.
  @protected
  Future<List<Map<String, Object?>>> itemsUnder(String rootId) => allItems({
        'ParentId': rootId,
        'Recursive': 'true',
        'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Trailer',
        'IsMissing': 'false',
        'Fields': 'Chapters,Etag',
        'EnableImages': 'false',
        'EnableUserData': 'false',
      });

  /// The media source to name for [itemId]: Jellyfin's first source has the
  /// item's id. Null leaves it to the server (its first source).
  @protected
  String? mediaSourceIdOf(String itemId) => itemId;

  /// A playback report's body.
  @protected
  Map<String, Object?> reportJson(PlaybackReport report) => report.toJson();

  /// Where libraries and items are listed, and what each listing is asked
  /// with: Jellyfin names the user in the query, Emby in the path.
  @protected
  String get viewsPath => '/UserViews';
  @protected
  Map<String, Object?> get viewsQuery => {'userId': userId};
  @protected
  String get itemsPath => '/Items';
  @protected
  Map<String, Object?> get itemsQuery => {'userId': userId};

  /// The folders inside library [libraryId], as a tree (see
  /// [FolderNode.buildTree]).
  @override
  Future<List<FolderNode>> folderTree(String libraryId) async => FolderNode.buildTree(await allItems({
        'ParentId': libraryId,
        'Recursive': 'true',
        'IncludeItemTypes': FolderNode.itemTypes,
        'Fields': 'ParentId',
        'EnableImages': 'false',
        'EnableUserData': 'false',
      }));

  /// The Commercial media segments of [itemId], in order. Servers without
  /// media segments (older than 10.10, or with none for this item) answer
  /// 404, which means there are none.
  @override
  Future<List<MediaSegment>> commercialSegments(String itemId) async {
    final Object? json;
    try {
      json = await send('GET', '/MediaSegments/$itemId', query: {'includeSegmentTypes': 'Commercial'});
    } on ServerException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
    if (json is! Map<String, Object?>) return const [];
    final segments = [
      for (final s in (json['Items'] as List? ?? const []).cast<Map<String, Object?>>())
        if (s['Type'] == null || s['Type'] == 'Commercial')
          if ((s['StartTicks'], s['EndTicks']) case (final int start, final int end) when end > start)
            (start: Duration(microseconds: start ~/ 10), end: Duration(microseconds: end ~/ 10)),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return segments;
  }

  /// Direct (no transcode) stream. mpv handles virtually any container/codec.
  ///
  /// Must stay static-only (the direct-play spec): every segment that isn't
  /// a transcoded program part, and every analyzer read, comes from here.
  /// Transcode URLs come only from [playbackInfo].
  @override
  Uri streamUri(String itemId) => uri('/Videos/$itemId/stream', {
        'static': 'true',
        'mediaSourceId': mediaSourceIdOf(itemId),
      });

  /// The device profile sent with [playbackInfo]: direct play accepts every
  /// container and codec (mpv decodes them all), so Jellyfin only chooses a
  /// transcode for bitrate, or when told to. The transcode is a progressive
  /// MPEG-TS stream (H.264, stereo AAC): on Jellyfin 10.11 it honors
  /// `StartTimeTicks` with one server-side seek, where HLS needs a second
  /// ffmpeg start to join mid-file.
  static Map<String, Object?> deviceProfile(int? maxBitrate) => {
        'Name': clientName,
        'MaxStreamingBitrate': ?maxBitrate,
        'DirectPlayProfiles': [
          {'Type': 'Video'},
          {'Type': 'Audio'},
        ],
        'TranscodingProfiles': [
          {
            'Container': 'ts',
            'Type': 'Video',
            'VideoCodec': 'h264',
            'AudioCodec': 'aac',
            'Protocol': 'http',
            'Context': 'Streaming',
            'MaxAudioChannels': '2',
            'BreakOnNonKeyFrames': false,
          },
        ],
        'ContainerProfiles': const [],
        'CodecProfiles': const [],
        'SubtitleProfiles': [
          for (final format in const ['srt', 'subrip', 'ass', 'ssa', 'vtt']) {'Format': format, 'Method': 'External'},
        ],
      };

  @override
  Uri get pingUri => uri('/System/Ping');

  /// Asks Jellyfin whether [itemId] can be direct-played under [maxBitrate]
  /// (bits per second; null for no limit) on a device described by
  /// [profile] (the Linux one, [deviceProfile], when null). With
  /// [forceTranscode], direct play and stream copy are ruled out, so the
  /// answer is always a full transcode.
  @override
  Future<PlaybackDecision> playbackDecision(String itemId,
      {int? maxBitrate,
      bool forceTranscode = false,
      Duration startAt = Duration.zero,
      Map<String, Object?>? profile}) async {
    final json = await send('POST', '/Items/$itemId/PlaybackInfo', body: {
      'UserId': userId,
      'MediaSourceId': ?mediaSourceIdOf(itemId),
      'MaxStreamingBitrate': ?(maxBitrate ?? profile?['MaxStreamingBitrate']),
      'StartTimeTicks': startAt.inMicroseconds * 10,
      'AutoOpenLiveStream': false,
      'EnableDirectPlay': !forceTranscode,
      'EnableDirectStream': !forceTranscode,
      'EnableTranscoding': true,
      'AllowVideoStreamCopy': !forceTranscode,
      'AllowAudioStreamCopy': !forceTranscode,
      'DeviceProfile': profile ?? deviceProfile(maxBitrate),
    }) as Map<String, Object?>;
    final sources = (json['MediaSources'] as List? ?? const []).cast<Map<String, Object?>>();
    final source = sources.where((s) => s['Id'] == itemId).firstOrNull ?? sources.firstOrNull;
    if (source == null) throw ServerException('The server has no playable version of this item.');
    final url = source['TranscodingUrl'] as String?;
    if (!forceTranscode && source['SupportsDirectPlay'] == true) return const PlaybackDecision.direct();
    if (url == null) throw ServerException('The server would not convert this item.');
    final template = transcodeTemplate(url);
    final video = (source['MediaStreams'] as List? ?? const [])
        .cast<Map<String, Object?>>()
        .where((m) => m['Type'] == 'Video')
        .firstOrNull;
    return PlaybackDecision.transcode(template,
        directStream: !forceTranscode && copiesVideo(template, source),
        sourceBitrate: ((video?['BitRate'] ?? source['Bitrate']) as num?)?.toInt(),
        sourceCodec: video?['Codec'] as String?);
  }

  /// Whether the conversion at [template] copies [source]'s video.
  @protected
  bool copiesVideo(Uri template, Map<String, Object?> source) => keepsVideo(template, source);

  /// Whether a conversion copies the video (only the container, audio or
  /// subtitles need converting): Jellyfin's reasons for it, from
  /// [template]'s `TranscodeReasons` (or [source]'s), name nothing about
  /// the video.
  @visibleForTesting
  static bool keepsVideo(Uri template, Map<String, Object?> source) {
    final query = {for (final e in template.queryParameters.entries) e.key.toLowerCase(): e.value};
    final raw = query['transcodereasons'] ?? switch (source['TranscodeReasons']) {
      final List<Object?> l => l.join(','),
      final String s => s,
      _ => null,
    };
    final reasons = [for (final r in (raw ?? '').split(',')) if (r.trim().isNotEmpty) r.trim()];
    if (reasons.isEmpty) return false;
    return reasons.every((r) =>
        (r.startsWith('Container') && r != 'ContainerBitrateExceedsLimit') ||
        r.startsWith('Audio') ||
        r.startsWith('SecondaryAudio') ||
        r.startsWith('Subtitle') ||
        r == 'UnknownAudioStreamInfo');
  }

  /// [TranscodingUrl] made absolute against [serverUrl], without the access
  /// token Jellyfin puts in it (auth goes in headers, like every request).
  Uri transcodeTemplate(String transcodingUrl) {
    final relative = Uri.parse(transcodingUrl);
    final query = <String, String>{
      for (final e in relative.queryParameters.entries)
        if (e.key.isNotEmpty && !_tokenParams.contains(e.key.toLowerCase())) e.key: e.value,
    };
    return Uri.parse('$serverUrl${relative.path}').replace(queryParameters: query);
  }

  static const _tokenParams = {'apikey', 'api_key'};

  /// One transcode job's URL: [template] (see [transcodeTemplate]) joined at
  /// [startAt], under its own [playSessionId]. [burn]: the subtitle stream
  /// drawn into the picture (`SubtitleStreamIndex` with the Encode method;
  /// the server then re-encodes the video).
  @override
  Future<Uri> transcodeUri(Uri template,
          {required String playSessionId, required Duration startAt, SubtitleTrack? burn}) async =>
      template.replace(queryParameters: {
        for (final e in template.queryParameters.entries)
          if (!_jobParams.contains(e.key.toLowerCase())) e.key: e.value,
        'PlaySessionId': playSessionId,
        'StartTimeTicks': '${startAt.inMicroseconds * 10}',
        if (burn != null) ...{'SubtitleStreamIndex': burn.id, 'SubtitleMethod': 'Encode'},
      });

  static const _jobParams = {'starttimeticks', 'playsessionid', 'subtitlestreamindex', 'subtitlemethod'};

  /// The item's subtitle streams, from its own listing (not `PlaybackInfo`,
  /// which the direct-play path never asks).
  @override
  Future<List<SubtitleTrack>> subtitleTracks(String itemId) async =>
      parseSubtitleTracks(await getMap('/Users/$userId/Items/$itemId', {'Fields': 'MediaStreams,MediaSources'}));

  /// [item]'s subtitle streams (its first media source's), external ones
  /// as such, embedded ones numbered in the file's order.
  @visibleForTesting
  static List<SubtitleTrack> parseSubtitleTracks(Map<String, Object?> item) {
    final source = (item['MediaSources'] as List? ?? const []).cast<Map<String, Object?>>().firstOrNull;
    final streams = ((source?['MediaStreams'] ?? item['MediaStreams']) as List? ?? const [])
        .cast<Map<String, Object?>>()
        .where((m) => m['Type'] == 'Subtitle' && m['Index'] is num)
        .toList();
    final embedded = [for (final m in streams) if (m['IsExternal'] != true) m]
      ..sort((a, b) => (a['Index'] as num).compareTo(b['Index'] as num));
    return [
      for (final m in streams)
        if ('${m['Codec'] ?? ''}'.toLowerCase() case final codec)
          SubtitleTrack(
            id: '${(m['Index'] as num).toInt()}',
            codec: codec,
            language: normalizeLanguage(m['Language'] as String?),
            title: switch ((m['Title'] as String?)?.trim()) { final t? when t.isNotEmpty => t, _ => null },
            isDefault: m['IsDefault'] == true,
            isForced: m['IsForced'] == true,
            isExternal: m['IsExternal'] == true,
            position: m['IsExternal'] == true ? null : embedded.indexOf(m),
            source: source?['Id'] as String?,
            burnsWhenConverting: SubtitleTrack.isImageCodec(codec),
          ),
    ];
  }

  /// The server's subtitle stream for [track]. Joined after the start, it's
  /// asked as WebVTT: Jellyfin hands a track in its own format out as it is,
  /// without moving its cues to the join.
  @override
  Uri? subtitleUri(String itemId, SubtitleTrack track, {Duration startAt = Duration.zero, String? format}) {
    if (track.isImage) return null;
    final ticks = startAt.inMicroseconds * 10;
    final fmt = ticks > 0 ? 'vtt' : (format ?? track.textFormat);
    final source = track.source ?? mediaSourceIdOf(itemId) ?? itemId;
    return uri('/Videos/$itemId/$source/Subtitles/${track.id}/$ticks/Stream.$fmt');
  }

  @override
  bool get transcodeKeepsSourceTime => false;

  @override
  Future<void> stopTranscode(String playSessionId) => send('DELETE', '/Videos/ActiveEncodings',
      query: {'deviceId': deviceId, 'playSessionId': playSessionId});

  /// The sessions ping: keeps the job's encoding alive and records no user
  /// data (Jellyfin and Emby).
  @override
  Future<void> keepTranscodeAlive(String playSessionId) =>
      send('POST', '/Sessions/Playing/Ping', query: {'playSessionId': playSessionId});

  @override
  Future<Duration> resumePoint(String itemId) async =>
      parseResumePoint(await getMap('/Users/$userId/Items/$itemId', {'Fields': 'UserData'}));

  /// [item]'s `UserData.PlaybackPositionTicks` (100 ns ticks); zero without.
  @visibleForTesting
  static Duration parseResumePoint(Map<String, Object?> item) => switch (item['UserData']) {
        {'PlaybackPositionTicks': final num ticks} when ticks > 0 => Duration(microseconds: ticks ~/ 10),
        _ => Duration.zero,
      };

  @override
  Uri imageUri(String itemId, ImageKind kind, {int? maxHeight, String? tag}) =>
      uri('/Items/$itemId/Images/${kind == ImageKind.logo ? 'Logo' : 'Primary'}', {
        'maxHeight': maxHeight,
        'tag': tag,
        'quality': 90,
      });

  @override
  Future<void> reportPlaybackStart(PlaybackReport report) =>
      send('POST', '/Sessions/Playing', body: reportJson(report));

  @override
  Future<void> reportPlaybackProgress(PlaybackReport report) =>
      send('POST', '/Sessions/Playing/Progress', body: reportJson(report));

  @override
  Future<void> reportPlaybackStopped(PlaybackReport report) =>
      send('POST', '/Sessions/Playing/Stopped', body: reportJson(report));

  @override
  void close() => _http.close();
}
