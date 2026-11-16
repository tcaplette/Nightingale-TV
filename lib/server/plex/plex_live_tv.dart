import 'package:flutter/foundation.dart' show debugPrint;

import '../../live/live_data.dart';
import '../live_tv.dart';
import '../media_server.dart';
import 'plex_client.dart';
import '../../l10n/tr.dart';

/// Plex's Live TV (DVRs on the server), sent as Plex Web sends it (design:
/// "Confirmed server behavior").
class PlexLiveTv implements LiveTv {
  PlexLiveTv(this.client);

  final PlexClient client;

  static const _universal = '/video/:/transcode/universal';

  /// Each channel's DVR, guide provider and grid key, from [channels].
  final _where = <String, ({String dvr, String epg, String gridKey})>{};

  static List<Map<String, Object?>> _list(Map<String, Object?> m, String key) =>
      (m[key] as List? ?? const []).whereType<Map<String, Object?>>().toList();

  Future<List<Map<String, Object?>>> _dvrs() async => _list(await client.container('/livetv/dvrs'), 'Dvr');

  @override
  Future<LiveTvAvailability> availability() async {
    try {
      if ((await _dvrs()).isEmpty) return LiveTvAvailability.noChannels;
    } on ServerException catch (e) {
      // A Home user without tuner access, or a user of a shared server.
      if (e.statusCode == 401 || e.statusCode == 403) return LiveTvAvailability.noAccess;
      rethrow;
    }
    return (await channels()).isEmpty ? LiveTvAvailability.noChannels : LiveTvAvailability.available;
  }

  /// Every DVR's lineup channels, a channel on two DVRs once.
  @override
  Future<List<LiveChannelInfo>> channels() async {
    final out = <LiveChannelInfo>[];
    final seen = <String>{};
    // Built afresh: a channel a DVR no longer lists can't be tuned
    // (live-channel-repair D4).
    final where = <String, ({String dvr, String epg, String gridKey})>{};
    for (final dvr in await _dvrs()) {
      final key = '${dvr['key'] ?? ''}';
      final epg = dvr['epgIdentifier'] as String?;
      if (epg == null || key.isEmpty) continue;
      final lineup = await client.container('/$epg/lineups/dvr/channels');
      final group = dvr['lineupTitle'];
      out.addAll(readChannelEntries('plex', _list(lineup, 'Channel'), (c) {
        final id = c['id'] as String?;
        if (id == null || seen.contains(id)) return null;
        final gridKey = (c['gridKey'] as String?) ?? id;
        final thumb = c['thumb'] as String?;
        final info = LiveChannelInfo(
          key: id,
          name: ((c['title'] ?? c['callSign']) as String?)?.trim() ?? id,
          number: c['vcn'] as String?,
          group: group is String ? group : null,
          logo: thumb == null
              ? null
              : thumb.startsWith('/')
                  ? client.uri('/photo/:/transcode', {'url': thumb, 'height': 160, 'width': 320, 'minSize': 1}).toString()
                  : thumb,
          guideId: gridKey,
        );
        seen.add(id);
        where[id] = (dvr: key, epg: epg, gridKey: gridKey);
        return info;
      }));
    }
    _where
      ..clear()
      ..addAll(where);
    return out..sort(compareSourceOrder);
  }

  /// [failure] of a tune of [channelId], unless the DVRs no longer list
  /// the channel: Plex answers a deleted channel's tune with "Could not
  /// tune channel" (HTTP 200), not a 404, so the lineup is read again to
  /// tell (live-channel-repair D4).
  Future<LiveTvException> _orGone(String channelId, LiveTvException failure) async {
    if (failure.failure == LiveFailure.tunersBusy || failure.failure == LiveFailure.unreachable) return failure;
    try {
      await channels();
    } on Object catch (e) {
      debugPrint('Plex lineup after a failed tune: $e');
      return failure;
    }
    return _where.containsKey(channelId) ? failure : LiveTvException(LiveFailure.channelGone, failure.message);
  }

  Future<({String dvr, String epg, String gridKey})?> _whereIs(String id) async {
    if (!_where.containsKey(id)) await channels();
    return _where[id];
  }

  static String _date(DateTime d) =>
      '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

  /// As Plex Web: one grid request per channel and day.
  @override
  Future<Map<String, List<LiveProgramme>>> programs(List<String> channelIds, DateTime from, DateTime to) async {
    final out = <String, List<LiveProgramme>>{};
    // Plex's grid days are the server's own calendar days, which needn't be
    // this device's: a day either side covers any time zone, and the
    // programmes are cut to the window below.
    final days = <String>[
      for (var d = DateTime(from.year, from.month, from.day - 1);
          d.isBefore(to.add(const Duration(days: 1)));
          d = DateTime(d.year, d.month, d.day + 1))
        _date(d),
    ];
    for (final id in channelIds) {
      final where = await _whereIs(id);
      if (where == null) continue;
      final seen = <int>{};
      final list = <LiveProgramme>[];
      for (final day in days) {
        final grid = await client.container('/${where.epg}/grid', query: {'channelGridKey': where.gridKey, 'date': day});
        for (final m in _list(grid, 'Metadata')) {
          for (final media in _list(m, 'Media')) {
            if (media['channelIdentifier'] != null && media['channelIdentifier'] != id) continue;
            final p = programmeFrom(m, media);
            if (p == null || !p.end.isAfter(from) || !p.start.isBefore(to)) continue;
            if (seen.add(p.start.millisecondsSinceEpoch)) list.add(p);
          }
        }
      }
      final tidy = tidyProgrammes(list, from);
      if (tidy.isNotEmpty) out[id] = tidy;
    }
    return out;
  }

  /// A grid item airing as [media], as a programme.
  static LiveProgramme? programmeFrom(Map<String, Object?> m, Map<String, Object?> media) {
    final begins = (media['beginsAt'] as num?)?.toInt(), ends = (media['endsAt'] as num?)?.toInt();
    if (begins == null || ends == null) return null;
    final movie = m['type'] == 'movie';
    final show = m['grandparentTitle'] as String?;
    final title = movie || show == null ? m['title'] as String? : show;
    if (title == null || title.trim().isEmpty) return null;
    return LiveProgramme(
      start: DateTime.fromMillisecondsSinceEpoch(begins * 1000),
      end: DateTime.fromMillisecondsSinceEpoch(ends * 1000),
      title: title.trim(),
      subtitle: movie || show == null ? null : m['title'] as String?,
      description: m['summary'] as String?,
      categories: [for (final g in _list(m, 'Genre')) ?g['tag'] as String?],
      year: movie ? (m['year'] as num?)?.toInt() : null,
      rating: m['contentRating'] as String?,
      season: movie ? null : (m['parentIndex'] as num?)?.toInt(),
      episode: movie ? null : (m['index'] as num?)?.toInt(),
      isNew: media['premiere'] == '1' || media['premiere'] == true || media['premiere'] == 1,
      isMovie: movie,
    );
  }

  static String _session(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  @override
  Future<LiveStream> open(String channelId,
      {int? maxBitrate, bool forceTranscode = false, Map<String, Object?>? profile}) async {
    final where = await _whereIs(channelId);
    // Not in any DVR's lineup, read again just now: gone from the server.
    if (where == null) throw LiveTvException(LiveFailure.channelGone, tr.channelIsNot(channelId));
    final session = _session('live');
    final Map<String, Object?> tuned;
    try {
      tuned = await client.container('/livetv/dvrs/${where.dvr}/channels/${Uri.encodeComponent(channelId)}/tune',
          method: 'POST', headers: {'X-Plex-Session-Identifier': session});
    } on ServerException catch (e) {
      throw await _orGone(channelId, LiveTvException.fromServer(e));
    }
    final op = _list(_list(tuned, 'MediaSubscription').firstOrNull ?? const {}, 'MediaGrabOperation').firstOrNull;
    final item = op?['Metadata'] as Map<String, Object?>?;
    final media = item == null ? null : _list(item, 'Media').elementAtOrNull((op!['mediaIndex'] as num?)?.toInt() ?? 0);
    final part = media == null ? null : _list(media, 'Part').firstOrNull;
    final itemKey = item?['key'] as String?;
    if (itemKey == null || part?['key'] == null) {
      throw await _orGone(channelId, LiveTvException.fromMessage('${tuned['message'] ?? 'Could not tune channel'}'));
    }
    final extra = {
      'key': itemKey,
      'ratingKey': '${item!['ratingKey'] ?? ''}',
      'duration': '${item['duration'] ?? 0}',
    };
    // Always through the decision and the universal transcoder, as Plex Web
    // plays it (copying what the device plays): stopping that session is
    // what frees the tuner at once. Reading the tuned session's own HLS
    // holds the tuner until Plex times it out.
    final transcode = _session('livetc');
    final query = <String, Object?>{
      'path': itemKey,
      'mediaIndex': 0,
      'partIndex': 0,
      'protocol': 'hls',
      'fastSeek': 1,
      'directPlay': 0,
      'directStream': forceTranscode ? 0 : 1,
      'directStreamAudio': forceTranscode ? 0 : 1,
      'subtitles': 'none',
      'location': client.relay ? 'wan' : 'lan',
      'maxVideoBitrate': ?switch (maxBitrate ?? (profile?['MaxStreamingBitrate'] as num?)?.toInt()) {
        final b? when b < 1000000000 => b ~/ 1000,
        _ => null,
      },
      'offset': -1,
      'session': transcode,
      'X-Plex-Client-Profile-Name': 'Generic',
      'X-Plex-Client-Profile-Extra': PlexClient.profileExtra(profile),
    };
    final Map<String, Object?> decision;
    try {
      decision = await client.container('$_universal/decision', query: query, headers: {'X-Plex-Session-Identifier': session});
    } on ServerException catch (e) {
      await _stop(session, extra, null);
      throw LiveTvException.fromServer(e);
    }
    final code = (decision['transcodeDecisionCode'] as num?)?.toInt();
    if (code == null || code >= 2000) {
      await _stop(session, extra, null);
      throw LiveTvException(LiveFailure.cantDecode, '${decision['transcodeDecisionText'] ?? code}');
    }
    final streams = _list(
        _list(_list(_list(decision, 'Metadata').firstOrNull ?? const {}, 'Media').firstOrNull ?? const {}, 'Part')
                .firstOrNull ??
            const {},
        'Stream');
    final video = streams.where((s) => (s['streamType'] as num?)?.toInt() == 1).firstOrNull;
    return LiveStream(
      channelId: channelId,
      uri: client.uri('$_universal/start.m3u8', {...query, 'X-Plex-Session-Identifier': session}),
      headers: client.authHeaders,
      method: video?['decision'] == 'copy' ? PlayMethod.directStream : PlayMethod.transcode,
      playSessionId: session,
      transcodeSession: transcode,
      extra: extra,
    );
  }

  Future<void> _timeline(String session, Map<String, String> extra, String state, Duration position) =>
      client.container('/:/timeline', query: {
        'ratingKey': extra['ratingKey'],
        'key': extra['key'],
        'state': state,
        'time': position.inMilliseconds,
        'duration': extra['duration'],
        'playbackTime': position.inMilliseconds,
        'hasMDE': 1,
      }, headers: {
        'X-Plex-Session-Identifier': session,
      });

  /// Stopping the tuned session frees its tuner within seconds.
  Future<void> _stop(String session, Map<String, String> extra, String? transcode) async {
    try {
      await _timeline(session, extra, 'stopped', Duration.zero);
    } on ServerException catch (e) {
      debugPrint('Stopping the Plex live session: ${e.message}');
    }
    if (transcode == null) return;
    try {
      await client.container('$_universal/stop', query: {'session': transcode});
    } on ServerException catch (e) {
      // Plex has often stopped it with the session already (404).
      if (e.statusCode != 404) debugPrint('Stopping the Plex live transcode: ${e.message}');
    }
  }

  @override
  Future<void> close(LiveStream stream) async {
    if (stream.closed) return;
    stream.closed = true;
    await _stop(stream.playSessionId!, stream.extra, stream.transcodeSession);
  }

  @override
  Future<void> reportStart(LiveStream stream) => _timeline(stream.playSessionId!, stream.extra, 'playing', Duration.zero);

  @override
  Future<void> reportProgress(LiveStream stream, Duration position) =>
      _timeline(stream.playSessionId!, stream.extra, 'playing', position);

  /// Closing sends `stopped`; this is the same report, kept for the
  /// interface.
  @override
  Future<void> reportStopped(LiveStream stream, Duration position) =>
      _timeline(stream.playSessionId!, stream.extra, 'stopped', position);

  /// Plex ends a tuned session that gets no timeline for about 3 minutes,
  /// pings or not.
  @override
  bool get needsReports => true;

  /// The universal transcoder's ping for the stream's job. Closing still
  /// sends the tuned session's `stopped`, which frees the tuner.
  @override
  Future<void> keepAlive(LiveStream stream) async {
    final transcode = stream.transcodeSession;
    if (transcode == null) return;
    await client.container('$_universal/ping', query: {'session': transcode});
  }
}
