import 'package:flutter/foundation.dart' show visibleForTesting;

import '../jellyfin/jellyfin_client.dart';
import 'media_server.dart';

/// Emby: the Jellyfin client with Emby's auth headers and per-user routes.
/// Emby has no media segments, so breaks come from chapters and the app's
/// own analysis.
class EmbyClient extends JellyfinClient {
  EmbyClient({
    required super.serverUrl,
    required super.deviceId,
    required super.deviceName,
    super.accessToken,
    super.userId,
    super.httpClient,
  });

  factory EmbyClient.fromSession(ServerSession session, {required String deviceName}) => EmbyClient(
        serverUrl: session.serverUrl,
        deviceId: session.deviceId,
        deviceName: deviceName,
        accessToken: session.accessToken,
        userId: session.userId,
      );

  @override
  ServerKind get kind => ServerKind.emby;

  @override
  String get authorizationHeader {
    String q(String v) => v.replaceAll('"', "'");
    return 'Emby Client="${q(JellyfinClient.clientName)}", Device="${q(deviceName)}", '
        'DeviceId="${q(deviceId)}", Version="${JellyfinClient.clientVersion}"';
  }

  @override
  Map<String, String> get authHeaders => {
        'X-Emby-Authorization': authorizationHeader,
        'X-Emby-Token': ?accessToken,
      };

  @override
  Future<void> checkSession() => send('GET', '/Users/$userId');

  @override
  String get userPath => '/Users/$userId';

  @override
  String get viewsPath => '/Users/$userId/Views';
  @override
  Map<String, Object?> get viewsQuery => const {};
  @override
  String get itemsPath => '/Users/$userId/Items';
  @override
  Map<String, Object?> get itemsQuery => const {};

  @override
  Future<ServerInfo> publicInfo() async {
    final info = await super.publicInfo();
    return ServerInfo(url: info.url, name: info.name, version: info.version, id: info.id, kind: ServerKind.emby);
  }

  /// Emby ignores a parent it doesn't know and lists every item, so a
  /// deleted root is found by asking for it first (404: gone).
  @override
  Future<List<String>> idsUnder(String rootId) async {
    await getMap('$userPath/Items/$rootId');
    return super.idsUnder(rootId);
  }

  @override
  Future<List<MediaSegment>> commercialSegments(String itemId) async => const [];

  /// Emby's sources have their own ids (`mediasource_<item id>`); left out,
  /// Emby uses the first, as the app does on Jellyfin.
  @override
  String? mediaSourceIdOf(String itemId) => null;

  @override
  Map<String, Object?> reportJson(PlaybackReport report) => report.toJson()..remove('MediaSourceId');

  /// Emby's reasons can name only the audio while its URL also limits the
  /// video (`hevc-videobitdepth=8`, `hevc-profile=main`): it then converts
  /// the video at stream time. A copy only when the source's video fits.
  @override
  bool copiesVideo(Uri template, Map<String, Object?> source) =>
      super.copiesVideo(template, source) && videoFits(template, source);

  @visibleForTesting
  static bool videoFits(Uri template, Map<String, Object?> source) {
    final video = (source['MediaStreams'] as List? ?? const [])
        .cast<Map<String, Object?>>()
        .where((m) => m['Type'] == 'Video')
        .firstOrNull;
    if (video == null) return true;
    final q = {for (final e in template.queryParameters.entries) e.key.toLowerCase(): e.value.toLowerCase()};
    final codec = '${video['Codec'] ?? ''}'.toLowerCase();
    final codecs = q['videocodec']?.split(',');
    if (codecs != null && !codecs.contains(codec)) return false;
    final depth = int.tryParse(q['$codec-videobitdepth'] ?? '');
    if (depth != null && ((video['BitDepth'] as num?)?.toInt() ?? 8) > depth) return false;
    final profiles = q['$codec-profile']?.split(RegExp('[,|]'));
    final profile = (video['Profile'] as String?)?.toLowerCase();
    if (profiles != null && profile != null && !profiles.contains(profile)) return false;
    return true;
  }

  /// Items Emby lists without an Etag get one from when the file changed
  /// (and its size, when listed), for the index cache.
  @override
  Future<List<Map<String, Object?>>> allItems(Map<String, Object?> query, {int pageSize = 500}) async {
    final fields = query['Fields'];
    final wantsEtag = fields is String && fields.split(',').contains('Etag');
    final items = await super.allItems(wantsEtag ? {...query, 'Fields': '$fields,DateModified'} : query,
        pageSize: pageSize);
    if (!wantsEtag) return items;
    return [
      for (final item in items)
        if (item['Etag'] == null && item['DateModified'] != null)
          {...item, 'Etag': '${item['DateModified']}|${_size(item) ?? ''}'}
        else
          item,
    ];
  }

  static Object? _size(Map<String, Object?> item) => switch (item['MediaSources']) {
        [final Map<String, Object?> source, ...] => source['Size'],
        _ => item['Size'],
      };
}
