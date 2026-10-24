import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'live_data.dart';

/// When a source's parts last refreshed, and the last error (live-tv-sources
/// "Refreshing and caching").
class LiveRefreshState {
  LiveRefreshState({this.channelsAt, this.guideAt, this.lastError, this.errorAt, this.failures = 0});

  /// When the channel list (playlist, server list) and the guide last
  /// refreshed.
  DateTime? channelsAt;
  DateTime? guideAt;

  /// The last refresh's error, shown on the source's row; null after a
  /// success.
  String? lastError;
  DateTime? errorAt;

  /// Refreshes failed in a row (for the 5, 15, 60 minute retries).
  int failures;

  /// The latest successful refresh.
  DateTime? get lastRefresh => switch ((channelsAt, guideAt)) {
        (final a?, final b?) => a.isAfter(b) ? a : b,
        (final a, final b) => a ?? b,
      };

  Map<String, Object?> toJson() => {
        if (channelsAt != null) 'channelsAt': channelsAt!.toUtc().toIso8601String(),
        if (guideAt != null) 'guideAt': guideAt!.toUtc().toIso8601String(),
        'lastError': ?lastError,
        if (errorAt != null) 'errorAt': errorAt!.toUtc().toIso8601String(),
        if (failures > 0) 'failures': failures,
      };

  factory LiveRefreshState.fromJson(Map<String, Object?> j) {
    DateTime? t(String k) => j[k] is String ? DateTime.tryParse(j[k] as String)?.toLocal() : null;
    return LiveRefreshState(
      channelsAt: t('channelsAt'),
      guideAt: t('guideAt'),
      lastError: j['lastError'] as String?,
      errorAt: t('errorAt'),
      failures: j['failures'] as int? ?? 0,
    );
  }
}

/// What's cached for one source.
class LiveCacheEntry {
  LiveCacheEntry({
    this.channels = const [],
    Map<String, List<LiveProgramme>>? guide,
    this.guideIndex = const [],
    LiveRefreshState? state,
  })  : guide = guide ?? {},
        state = state ?? LiveRefreshState();

  /// The source's channel list, in its order.
  List<LiveChannelInfo> channels;

  /// Programmes by channel key.
  Map<String, List<LiveProgramme>> guide;

  /// The XMLTV guide's channels (M3U sources).
  List<GuideChannel> guideIndex;
  final LiveRefreshState state;
}

/// Each source's cached channels and guide under the profile folder:
/// `live_cache/<sourceId>/{channels,guide,guide_index,state}.json`. Never
/// backed up; rebuilt by a refresh.
class LiveCache {
  LiveCache(Directory profileDir) : dir = Directory('${profileDir.path}/$folder');

  static const folder = 'live_cache';
  static var _tmpCounter = 0;

  final Directory dir;

  Directory _sourceDir(String sourceId) => Directory('${dir.path}/$sourceId');
  File _file(String sourceId, String name) => File('${_sourceDir(sourceId).path}/$name');

  /// Everything cached for [sourceId]; empty when nothing is (or it's
  /// unreadable). Parsed off the UI isolate: a guide can be large.
  Future<LiveCacheEntry> load(String sourceId) async {
    final paths = [for (final n in const ['channels.json', 'guide.json', 'guide_index.json', 'state.json']) _file(sourceId, n).path];
    final raw = await Isolate.run(() {
      Object? read(String path) {
        final f = File(path);
        if (!f.existsSync()) return null;
        try {
          return jsonDecode(f.readAsStringSync());
        } on FormatException {
          return null;
        }
      }

      return [for (final p in paths) read(p)];
    });
    return LiveCacheEntry(
      channels: [
        if (raw[0] case final List list)
          for (final c in list.whereType<Map<String, Object?>>()) LiveChannelInfo.fromJson(c),
      ],
      guide: {
        if (raw[1] case final Map map)
          for (final e in map.entries)
            if (e.value is List)
              e.key as String: [
                for (final p in (e.value as List).whereType<Map<String, Object?>>()) LiveProgramme.fromJson(p),
              ],
      },
      guideIndex: [
        if (raw[2] case final List list)
          for (final c in list.whereType<Map<String, Object?>>()) GuideChannel.fromJson(c),
      ],
      state: raw[3] is Map<String, Object?> ? LiveRefreshState.fromJson(raw[3] as Map<String, Object?>) : null,
    );
  }

  Future<void> saveChannels(String sourceId, List<LiveChannelInfo> channels) =>
      _write(sourceId, 'channels.json', [for (final c in channels) c.toJson()]);

  Future<void> saveGuide(String sourceId, Map<String, List<LiveProgramme>> guide) =>
      _write(sourceId, 'guide.json', {
        for (final e in guide.entries) e.key: [for (final p in e.value) p.toJson()],
      });

  Future<void> saveGuideIndex(String sourceId, List<GuideChannel> index) =>
      _write(sourceId, 'guide_index.json', [for (final c in index) c.toJson()]);

  Future<void> saveState(String sourceId, LiveRefreshState state) => _write(sourceId, 'state.json', state.toJson());

  Future<void> delete(String sourceId) async {
    final d = _sourceDir(sourceId);
    if (await d.exists()) await d.delete(recursive: true);
  }

  /// Atomically (temp file and rename); the playlist's URLs can hold the
  /// provider's credentials, so the files are private.
  Future<void> _write(String sourceId, String name, Object data) async {
    final d = _sourceDir(sourceId);
    await d.create(recursive: true);
    final file = _file(sourceId, name);
    final tmp = File('${file.path}.${pid}_${_tmpCounter++}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    if (!Platform.isAndroid) await Process.run('chmod', ['600', tmp.path]);
    await tmp.rename(file.path);
  }
}
