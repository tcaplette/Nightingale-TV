import 'package:flutter/foundation.dart' show debugPrint;

import '../live/live_data.dart';
import '../server/live_tv.dart';
import '../server/media_server.dart';
import 'jellyfin_client.dart';

/// Jellyfin's and Emby's Live TV (the same routes; Emby's auth comes from
/// [EmbyClient]), as their web clients use it (design: "Confirmed server
/// behavior").
class JellyfinLiveTv implements LiveTv {
  JellyfinLiveTv(this.client);

  final JellyfinClient client;

  /// Channels per guide request.
  static const programChunk = 50;

  /// Sent when there's no cap: without a bitrate, Jellyfin turns live
  /// direct play down (`ContainerBitrateExceedsLimit`).
  static const noCap = 1000000000;

  Future<Map<String, Object?>> _get(String path, [Map<String, Object?>? query]) async =>
      (await client.request('GET', path, query: query)) as Map<String, Object?>? ?? const {};

  @override
  Future<LiveTvAvailability> availability() async {
    final user = await _get(client.userPath);
    final policy = user['Policy'];
    if (policy is Map && policy['EnableLiveTvAccess'] == false) return LiveTvAvailability.noAccess;
    final info = await _get('/LiveTv/Info');
    if (info['IsEnabled'] == false) return LiveTvAvailability.noChannels;
    final users = info['EnabledUsers'];
    if (users is List && users.isNotEmpty && client.userId != null && !users.contains(client.userId)) {
      return LiveTvAvailability.noAccess;
    }
    final page = await _get('/LiveTv/Channels', {'UserId': client.userId, 'Limit': 0});
    return (page['TotalRecordCount'] as num? ?? 0) > 0 ? LiveTvAvailability.available : LiveTvAvailability.noChannels;
  }

  @override
  Future<List<LiveChannelInfo>> channels() async {
    final page = await _get('/LiveTv/Channels', {
      'UserId': client.userId,
      'EnableImages': 'true',
      'ImageTypeLimit': 1,
      'EnableUserData': 'false',
      'Fields': 'ChannelInfo',
    });
    final channels = [
      for (final c in (page['Items'] as List? ?? const []).cast<Map<String, Object?>>())
        if (c['Id'] case final String id)
          LiveChannelInfo(
            key: id,
            name: (c['Name'] as String?)?.trim() ?? 'Channel',
            number: (c['Number'] ?? c['ChannelNumber']) as String?,
            logo: switch (c['ImageTags']) {
              {'Primary': final String tag} => client.imageUri(id, ImageKind.primary, maxHeight: 160, tag: tag).toString(),
              _ => null,
            },
            guideId: id,
          ),
    ];
    return channels..sort(compareSourceOrder);
  }

  @override
  Future<Map<String, List<LiveProgramme>>> programs(List<String> channelIds, DateTime from, DateTime to) async {
    final out = <String, List<LiveProgramme>>{};
    for (var i = 0; i < channelIds.length; i += programChunk) {
      final ids = channelIds.sublist(i, (i + programChunk).clamp(0, channelIds.length));
      final page = (await client.request('POST', '/LiveTv/Programs', body: {
        'UserId': client.userId,
        'ChannelIds': ids,
        'MinEndDate': from.toUtc().toIso8601String(),
        'MaxStartDate': to.toUtc().toIso8601String(),
        'Fields': ['Overview', 'Genres'],
        'EnableImages': false,
        'EnableUserData': false,
        'EnableTotalRecordCount': false,
        'SortBy': ['StartDate'],
      })) as Map<String, Object?>? ?? const {};
      for (final p in (page['Items'] as List? ?? const []).cast<Map<String, Object?>>()) {
        final programme = programmeFrom(p);
        final channel = p['ChannelId'] as String?;
        if (programme != null && channel != null) out.putIfAbsent(channel, () => []).add(programme);
      }
    }
    return {for (final e in out.entries) e.key: tidyProgrammes(e.value, from)};
  }

  /// One of `/LiveTv/Programs`' items as a programme.
  static LiveProgramme? programmeFrom(Map<String, Object?> p) {
    final start = DateTime.tryParse(p['StartDate'] as String? ?? '')?.toLocal();
    final end = DateTime.tryParse(p['EndDate'] as String? ?? '')?.toLocal();
    final title = (p['Name'] as String?)?.trim();
    if (start == null || end == null || title == null || title.isEmpty) return null;
    final movie = p['IsMovie'] == true;
    return LiveProgramme(
      start: start,
      end: end,
      title: title,
      subtitle: movie ? null : (p['EpisodeTitle'] as String?)?.trim(),
      description: p['Overview'] as String?,
      categories: (p['Genres'] as List?)?.whereType<String>().toList() ?? const [],
      year: (p['ProductionYear'] as num?)?.toInt(),
      rating: p['OfficialRating'] as String?,
      season: movie ? null : (p['ParentIndexNumber'] as num?)?.toInt(),
      episode: movie ? null : (p['IndexNumber'] as num?)?.toInt(),
      isNew: p['IsPremiere'] == true || p['IsNew'] == true,
      isMovie: movie,
    );
  }

  @override
  Future<LiveStream> open(String channelId,
      {int? maxBitrate, bool forceTranscode = false, Map<String, Object?>? profile}) async {
    final Map<String, Object?> json;
    try {
      json = await client.request('POST', '/Items/$channelId/PlaybackInfo', body: {
        'UserId': client.userId,
        'AutoOpenLiveStream': true,
        'MaxStreamingBitrate': maxBitrate ?? (profile?['MaxStreamingBitrate'] as num?)?.toInt() ?? noCap,
        'StartTimeTicks': 0,
        'EnableDirectPlay': !forceTranscode,
        'EnableDirectStream': !forceTranscode,
        'EnableTranscoding': true,
        'AllowVideoStreamCopy': !forceTranscode,
        'AllowAudioStreamCopy': !forceTranscode,
        'DeviceProfile': profile ?? JellyfinClient.deviceProfile(maxBitrate),
      }) as Map<String, Object?>? ?? const {};
    } on ServerException catch (e) {
      throw LiveTvException.fromServer(e);
    }
    final source = (json['MediaSources'] as List? ?? const []).cast<Map<String, Object?>>().firstOrNull;
    if (source == null) {
      throw LiveTvException.fromMessage('${json['ErrorCode'] ?? 'No live stream'}');
    }
    final liveStreamId = source['LiveStreamId'] as String?;
    final playSessionId = json['PlaySessionId'] as String?;
    final path = source['Path'] as String? ?? '';
    final shared = path.indexOf('/LiveTv/LiveStreamFiles/');
    final transcoding = source['TranscodingUrl'] as String?;
    Uri uri;
    PlayMethod method;
    if (!forceTranscode && source['SupportsDirectPlay'] == true && shared >= 0) {
      // The server's shared stream, at the address this app reaches it by.
      uri = Uri.parse('${client.serverUrl}${path.substring(shared)}');
      method = PlayMethod.directPlay;
    } else if (transcoding != null) {
      uri = client.transcodeTemplate(transcoding);
      method = client.keepsSourceVideo(uri, source) && !forceTranscode ? PlayMethod.directStream : PlayMethod.transcode;
    } else {
      if (liveStreamId != null) await _closeLiveStream(liveStreamId);
      throw const LiveTvException(LiveFailure.cantDecode, 'The server would not convert this channel.');
    }
    return LiveStream(
      channelId: channelId,
      uri: uri,
      headers: client.authHeaders,
      method: method,
      playSessionId: playSessionId,
      liveStreamId: liveStreamId,
      mediaSourceId: source['Id'] as String?,
      transcodeSession: method == PlayMethod.directPlay ? null : playSessionId,
    );
  }

  Future<void> _closeLiveStream(String id) async {
    try {
      await client.request('POST', '/LiveStreams/Close', query: {'LiveStreamId': id});
    } on ServerException catch (e) {
      debugPrint('Closing live stream $id: ${e.message}');
    }
  }

  @override
  Future<void> close(LiveStream stream) async {
    if (stream.closed) return;
    stream.closed = true;
    if (stream.transcodeSession case final session?) {
      try {
        await client.request('DELETE', '/Videos/ActiveEncodings',
            query: {'deviceId': client.deviceId, 'playSessionId': session});
      } on ServerException catch (e) {
        debugPrint('Stopping the live transcode: ${e.message}');
      }
    }
    if (stream.liveStreamId case final id?) await _closeLiveStream(id);
  }

  Map<String, Object?> _report(LiveStream s, Duration position) => {
        'ItemId': s.channelId,
        'MediaSourceId': ?s.mediaSourceId,
        'LiveStreamId': ?s.liveStreamId,
        'PlaySessionId': ?s.playSessionId,
        'PositionTicks': position.inMicroseconds * 10,
        'IsPaused': false,
        'CanSeek': false,
        'PlayMethod': s.method.json,
      };

  @override
  Future<void> reportStart(LiveStream stream) =>
      client.request('POST', '/Sessions/Playing', body: _report(stream, Duration.zero));

  @override
  Future<void> reportProgress(LiveStream stream, Duration position) =>
      client.request('POST', '/Sessions/Playing/Progress', body: _report(stream, position));

  @override
  Future<void> reportStopped(LiveStream stream, Duration position) =>
      client.request('POST', '/Sessions/Playing/Stopped', body: _report(stream, position));
}
