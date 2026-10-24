import 'dart:async';

import 'live_cache.dart';
import 'live_source.dart';

/// What's due for a source, and the refresh that does it.
typedef RefreshCall = Future<void> Function(LiveSource source, {required bool channels, required bool guide});

/// Keeps the on-screen profile's Live TV sources fresh (live-tv-sources
/// "Refreshing and caching", D6): server Live TV's channel list at start
/// and hourly, its guide at start and every 30 minutes; M3U playlists when
/// older than a day, XMLTV guides when older than 12 hours. A failed
/// refresh is tried again after 5, 15, then 60 minutes.
class LiveRefresher {
  LiveRefresher({
    required this.sources,
    required this.stateOf,
    required this.refresh,
    DateTime Function()? now,
    this.tick = const Duration(minutes: 1),
  }) : _now = now ?? DateTime.now;

  final List<LiveSource> Function() sources;
  final LiveRefreshState Function(LiveSource) stateOf;
  final RefreshCall refresh;
  final DateTime Function() _now;

  /// How often it looks at what's due.
  final Duration tick;

  static const serverChannels = Duration(hours: 1);
  static const serverGuide = Duration(minutes: 30);
  static const playlistAge = Duration(hours: 24);
  static const guideAge = Duration(hours: 12);

  /// Waits after the 1st, 2nd and 3rd (and later) failures in a row.
  static const backoff = [Duration(minutes: 5), Duration(minutes: 15), Duration(minutes: 60)];

  Timer? _timer;
  final _running = <String>{};

  /// Server sources refresh at start whatever their age.
  final _atStart = <String>{};

  bool get running => _timer != null;

  void start() {
    if (_timer != null) return;
    _atStart
      ..clear()
      ..addAll([for (final s in sources()) if (s.kind == LiveSourceKind.server) s.id]);
    _timer = Timer.periodic(tick, (_) => check());
    check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// What's due for [s] at [now].
  ({bool channels, bool guide}) due(LiveSource s, DateTime now) {
    final state = stateOf(s);
    if (state.failures > 0 && state.errorAt != null) {
      final wait = backoff[(state.failures - 1).clamp(0, backoff.length - 1)];
      if (now.isBefore(state.errorAt!.add(wait))) return (channels: false, guide: false);
    }
    bool older(DateTime? at, Duration age) => at == null || !now.isBefore(at.add(age));
    final server = s.kind == LiveSourceKind.server;
    final start = _atStart.contains(s.id);
    return (
      channels: start || older(state.channelsAt, server ? serverChannels : playlistAge),
      guide: start || older(state.guideAt, server ? serverGuide : guideAge),
    );
  }

  /// Refreshes whatever is due, one refresh per source at a time.
  void check() {
    final now = _now();
    for (final s in sources()) {
      final d = due(s, now);
      if (!d.channels && !d.guide) continue;
      _atStart.remove(s.id);
      _run(s, channels: d.channels, guide: d.guide);
    }
  }

  /// "Refresh now": everything, at once, whatever's due.
  Future<void> refreshNow(LiveSource s) => _run(s, channels: true, guide: true);

  Future<void> _run(LiveSource s, {required bool channels, required bool guide}) async {
    if (!_running.add(s.id)) return;
    try {
      await refresh(s, channels: channels, guide: guide);
    } finally {
      _running.remove(s.id);
    }
  }
}
