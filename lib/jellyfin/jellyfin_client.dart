import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class JellyfinException implements Exception {
  JellyfinException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class JellyfinSession {
  const JellyfinSession({
    required this.serverUrl,
    required this.serverName,
    required this.userId,
    required this.userName,
    required this.accessToken,
    required this.deviceId,
    this.serverId,
  });

  final String serverUrl;
  final String serverName;
  final String userId;
  final String userName;
  final String accessToken;
  final String deviceId;

  /// The server's own id, which stays the same if its address changes.
  /// Sign-ins saved before it was recorded don't have it yet.
  final String? serverId;

  Map<String, Object?> toJson() => {
        'serverUrl': serverUrl,
        'serverName': serverName,
        'userId': userId,
        'userName': userName,
        'accessToken': accessToken,
        'deviceId': deviceId,
        if (serverId != null) 'serverId': serverId,
      };

  /// The same sign-in, identifying this PC as [id].
  JellyfinSession withDeviceId(String id) => JellyfinSession(
        serverUrl: serverUrl,
        serverName: serverName,
        userId: userId,
        userName: userName,
        accessToken: accessToken,
        deviceId: id,
        serverId: serverId,
      );

  /// The same sign-in, knowing the server's [id].
  JellyfinSession withServerId(String id) => JellyfinSession(
        serverUrl: serverUrl,
        serverName: serverName,
        userId: userId,
        userName: userName,
        accessToken: accessToken,
        deviceId: deviceId,
        serverId: id,
      );

  factory JellyfinSession.fromJson(Map<String, Object?> json) => JellyfinSession(
        serverUrl: json['serverUrl'] as String,
        serverName: json['serverName'] as String? ?? 'Jellyfin',
        userId: json['userId'] as String,
        userName: json['userName'] as String,
        accessToken: json['accessToken'] as String,
        deviceId: json['deviceId'] as String,
        serverId: json['serverId'] as String?,
      );
}

class ServerInfo {
  const ServerInfo({required this.url, required this.name, required this.version, this.id});

  final String url;
  final String name;
  final String version;

  /// Null only for servers too old to report it.
  final String? id;
}

/// A stretch of a video, e.g. a Jellyfin media segment.
typedef MediaSegment = ({Duration start, Duration end});

/// A folder in a library, for picking commercial folders. Built from the
/// folder-like items Jellyfin lists to any user (folders, shows, seasons,
/// collections), never from server file-system paths.
class FolderNode {
  FolderNode({required this.id, required this.name, required this.type, this.index, List<FolderNode>? children})
      : children = children ?? [];

  final String id;
  final String name;

  /// Jellyfin's item type: `Folder`, `Series`, `Season` or `BoxSet`.
  final String type;
  final int? index;
  final List<FolderNode> children;

  static const itemTypes = 'Folder,Series,Season,BoxSet';

  /// Rebuilds the tree from a recursive listing. Each item's `ParentId`
  /// points at its folder; items whose parent isn't in the listing are the
  /// top level (a library's storage folders). Virtual items (placeholder
  /// seasons for missing episodes) are left out.
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
      n.children.sort(_compare);
    }
    top.sort(_compare);
    return top;
  }

  /// Seasons by number; everything else by name, numbers in order
  /// ("Season 2" before "Season 10").
  static int _compare(FolderNode a, FolderNode b) {
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

class QuickConnectRequest {
  const QuickConnectRequest({required this.secret, required this.code});

  final String secret;
  final String code;
}

class JellyfinLibrary {
  const JellyfinLibrary({required this.id, required this.name, this.collectionType});

  final String id;
  final String name;

  /// `movies`, `tvshows`, `music`, `homevideos`, `mixed` (null), ...
  final String? collectionType;

  bool get isVideo =>
      collectionType == null ||
      const {'movies', 'tvshows', 'homevideos', 'musicvideos', 'mixed'}
          .contains(collectionType);
}

/// Thin client over the parts of the Jellyfin REST API this app needs.
class JellyfinClient {
  JellyfinClient({
    required String serverUrl,
    required this.deviceId,
    required this.deviceName,
    this.accessToken,
    this.userId,
    http.Client? httpClient,
  })  : serverUrl = normalizeServerUrl(serverUrl),
        _http = httpClient ?? http.Client();

  factory JellyfinClient.fromSession(JellyfinSession session, {required String deviceName}) =>
      JellyfinClient(
        serverUrl: session.serverUrl,
        deviceId: session.deviceId,
        deviceName: deviceName,
        accessToken: session.accessToken,
        userId: session.userId,
      );

  static const clientName = 'Nightingale TV';
  static const clientVersion = '0.1.0';
  static const _timeout = Duration(seconds: 30);

  final String serverUrl;
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

  Map<String, String> get authHeaders => {'Authorization': authorizationHeader};

  Uri uri(String path, [Map<String, Object?>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value == null) return;
      params[key] = value is Iterable ? value.join(',') : '$value';
    });
    return Uri.parse('$serverUrl$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<Object?> _send(String method, String path,
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
      throw JellyfinException('The server took too long to respond.');
    } on http.ClientException catch (e) {
      throw JellyfinException('Could not reach the server (${e.message}).');
    } on Exception catch (e) {
      throw JellyfinException('Could not reach the server ($e).');
    }
    if (response.statusCode == 401) {
      throw JellyfinException('Wrong username or password, or the session expired.',
          statusCode: 401);
    }
    if (response.statusCode >= 400) {
      throw JellyfinException('Server error ${response.statusCode} on $path.',
          statusCode: response.statusCode);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return null;
    }
  }

  /// Throws [JellyfinException] (401) if the sign-in is no longer valid.
  Future<void> checkSession() => _send('GET', '/Users/Me');

  Future<Map<String, Object?>> _getMap(String path, [Map<String, Object?>? query]) async =>
      (await _send('GET', path, query: query)) as Map<String, Object?>;

  Future<ServerInfo> publicInfo() async {
    final Map<String, Object?> json;
    try {
      json = await _getMap('/System/Info/Public');
    } on JellyfinException catch (e) {
      throw JellyfinException('No Jellyfin server found at $serverUrl. ${e.message}');
    } on TypeError {
      throw JellyfinException('$serverUrl did not answer like a Jellyfin server.');
    }
    return ServerInfo(
      url: serverUrl,
      name: json['ServerName'] as String? ?? 'Jellyfin',
      version: json['Version'] as String? ?? '?',
      id: json['Id'] as String?,
    );
  }

  /// The server's own id (see [JellyfinSession.serverId]).
  Future<String?> serverId() async => (await publicInfo()).id;

  /// [serverId] from a client made just for it, closed afterwards.
  Future<String?> serverIdOnce() async {
    try {
      return await serverId();
    } finally {
      close();
    }
  }

  JellyfinSession _sessionFrom(Map<String, Object?> json, String serverName) {
    final user = json['User'] as Map<String, Object?>;
    accessToken = json['AccessToken'] as String;
    userId = user['Id'] as String;
    return JellyfinSession(
      serverUrl: serverUrl,
      serverName: serverName,
      userId: userId!,
      userName: user['Name'] as String,
      accessToken: accessToken!,
      deviceId: deviceId,
    );
  }

  Future<JellyfinSession> authenticateByName(String username, String password,
      {required String serverName}) async {
    final json = await _send('POST', '/Users/AuthenticateByName',
        body: {'Username': username, 'Pw': password}) as Map<String, Object?>;
    return _sessionFrom(json, serverName);
  }

  Future<bool> quickConnectEnabled() async {
    try {
      return await _send('GET', '/QuickConnect/Enabled') == true;
    } on JellyfinException {
      return false;
    }
  }

  Future<QuickConnectRequest> quickConnectInitiate() async {
    final json = await _send('POST', '/QuickConnect/Initiate') as Map<String, Object?>;
    return QuickConnectRequest(secret: json['Secret'] as String, code: json['Code'] as String);
  }

  Future<bool> quickConnectAuthorized(String secret) async {
    final json = await _getMap('/QuickConnect/Connect', {'Secret': secret});
    return json['Authenticated'] == true;
  }

  Future<JellyfinSession> authenticateWithQuickConnect(String secret,
      {required String serverName}) async {
    final json = await _send('POST', '/Users/AuthenticateWithQuickConnect',
        body: {'Secret': secret}) as Map<String, Object?>;
    return _sessionFrom(json, serverName);
  }

  Future<void> logout() async {
    await _send('POST', '/Sessions/Logout');
  }

  Future<List<JellyfinLibrary>> libraries() async {
    final json = await _getMap('/UserViews', {'userId': userId});
    return [
      for (final v in (json['Items'] as List).cast<Map<String, Object?>>())
        JellyfinLibrary(
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
      final page = await _getMap('/Items', {
        ...query,
        'userId': userId,
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

  /// The folders inside library [libraryId], as a tree (see
  /// [FolderNode.buildTree]).
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
  Future<List<MediaSegment>> commercialSegments(String itemId) async {
    final Object? json;
    try {
      json = await _send('GET', '/MediaSegments/$itemId', query: {'includeSegmentTypes': 'Commercial'});
    } on JellyfinException catch (e) {
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
  Uri streamUri(String itemId) => uri('/Videos/$itemId/stream', {
        'static': 'true',
        'mediaSourceId': itemId,
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

  /// Asks Jellyfin whether [itemId] can be direct-played under [maxBitrate]
  /// (bits per second; null for no limit). With [forceTranscode], direct
  /// play and stream copy are ruled out, so the answer is always a full
  /// transcode.
  Future<PlaybackDecision> playbackInfo(String itemId,
      {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero}) async {
    final json = await _send('POST', '/Items/$itemId/PlaybackInfo', body: {
      'UserId': userId,
      'MediaSourceId': itemId,
      'MaxStreamingBitrate': ?maxBitrate,
      'StartTimeTicks': startAt.inMicroseconds * 10,
      'AutoOpenLiveStream': false,
      'EnableDirectPlay': !forceTranscode,
      'EnableDirectStream': !forceTranscode,
      'EnableTranscoding': true,
      'AllowVideoStreamCopy': !forceTranscode,
      'AllowAudioStreamCopy': !forceTranscode,
      'DeviceProfile': deviceProfile(maxBitrate),
    }) as Map<String, Object?>;
    final sources = (json['MediaSources'] as List? ?? const []).cast<Map<String, Object?>>();
    final source = sources.where((s) => s['Id'] == itemId).firstOrNull ?? sources.firstOrNull;
    if (source == null) throw JellyfinException('The server has no playable version of this item.');
    final url = source['TranscodingUrl'] as String?;
    if (!forceTranscode && source['SupportsDirectPlay'] == true) return const PlaybackDecision.direct();
    if (url == null) throw JellyfinException('The server would not convert this item.');
    return PlaybackDecision.transcode(transcodeTemplate(url));
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
  /// [startAt], under its own [playSessionId].
  static Uri transcodeUri(Uri template, {required String playSessionId, required Duration startAt}) =>
      template.replace(queryParameters: {
        for (final e in template.queryParameters.entries)
          if (e.key.toLowerCase() != 'starttimeticks' && e.key.toLowerCase() != 'playsessionid') e.key: e.value,
        'PlaySessionId': playSessionId,
        'StartTimeTicks': '${startAt.inMicroseconds * 10}',
      });

  /// Stops the transcode job [playSessionId] started by this device.
  Future<void> stopEncoding(String playSessionId) => _send('DELETE', '/Videos/ActiveEncodings',
      query: {'deviceId': deviceId, 'playSessionId': playSessionId});

  Uri imageUri(String itemId, String imageType, {int? maxHeight, String? tag}) =>
      uri('/Items/$itemId/Images/$imageType', {
        'maxHeight': maxHeight,
        'tag': tag,
        'quality': 90,
      });

  Future<void> reportPlaybackStart(PlaybackReport report) =>
      _send('POST', '/Sessions/Playing', body: report.toJson());

  Future<void> reportPlaybackProgress(PlaybackReport report) =>
      _send('POST', '/Sessions/Playing/Progress', body: report.toJson());

  Future<void> reportPlaybackStopped(PlaybackReport report) =>
      _send('POST', '/Sessions/Playing/Stopped', body: report.toJson());

  void close() => _http.close();
}

/// What [JellyfinClient.playbackInfo] decided: direct play (from
/// [JellyfinClient.streamUri]), or a transcode whose URL template is
/// [transcodeTemplate].
class PlaybackDecision {
  const PlaybackDecision.direct() : transcodeTemplate = null;
  const PlaybackDecision.transcode(Uri this.transcodeTemplate);

  final Uri? transcodeTemplate;

  bool get transcode => transcodeTemplate != null;
}

enum PlayMethod {
  directPlay('DirectPlay'),
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
  });

  final String itemId;
  final String playSessionId;
  final Duration position;
  final bool isPaused;
  final PlayMethod playMethod;

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
