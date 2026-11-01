import 'package:flutter/foundation.dart';

import '../../library/library_index.dart';
import '../../server/server_set.dart';
import 'analysis_cache.dart';
import 'break_points.dart';
import 'detections.dart';
import 'reel_cutter.dart';

/// Analysis results of a profile with several servers (multi-server D6):
/// each item's in its own server's [AnalysisCache] (`analysis/<serverId>.json`),
/// under the id that server knows it by, so results are shared with other
/// profiles on that server and survive a server being removed and added
/// again. Items of a server with no cache open yet have only their chapters.
class ServerAnalysis extends ChangeNotifier implements AnalysisStore {
  ServerAnalysis(this.caches) {
    for (final c in caches.values) {
      c.addListener(notifyListeners);
    }
  }

  /// By server key.
  final Map<String, AnalysisCache> caches;

  AnalysisCache? _cacheOf(MediaEntry item) => caches[ServerSet.keyOf(item.sourceId)];

  /// [item] as its server knows it.
  static MediaEntry _raw(MediaEntry item) =>
      ServerSet.keyOf(item.sourceId) == ServerSet.mainKey ? item : item.withIds(ServerSet.rawId);

  void detach() {
    for (final c in caches.values) {
      c.removeListener(notifyListeners);
    }
  }

  @override
  bool isAnalyzed(MediaEntry item) => _cacheOf(item)?.isAnalyzed(_raw(item)) ?? false;

  @override
  bool gaveUpOn(MediaEntry item) => _cacheOf(item)?.gaveUpOn(_raw(item)) ?? false;

  @override
  (int, DateTime?) failuresOf(MediaEntry item) => _cacheOf(item)?.failuresOf(_raw(item)) ?? (0, null);

  @override
  AnalysisResult? latest(MediaEntry item) => _cacheOf(item)?.latest(_raw(item));

  @override
  void recordReel(MediaEntry reel, ReelCuts? cuts, {required DateTime at}) =>
      _cacheOf(reel)?.recordReel(_raw(reel), cuts, at: at);

  @override
  void recordSegments(MediaEntry program, List<Span> skips, {required DateTime at}) =>
      _cacheOf(program)?.recordSegments(_raw(program), skips, at: at);

  @override
  void recordWindow(MediaEntry program, ScanWindow window) => _cacheOf(program)?.recordWindow(_raw(program), window);

  @override
  void recordFailure(MediaEntry item, {required DateTime at, required int maxFailures}) =>
      _cacheOf(item)?.recordFailure(_raw(item), at: at, maxFailures: maxFailures);

  @override
  ProgramBreakInfo pointsFor(MediaEntry program, DateTime asOf) {
    final cache = _cacheOf(program);
    if (cache != null) return cache.pointsFor(_raw(program), asOf);
    final (source, candidates) = BreakPointFinder.candidatesFor(program.runtime, chapters: program.chapters);
    return ProgramBreakInfo(source: source, candidates: candidates);
  }

  @override
  Future<void> flush() => Future.wait([for (final c in caches.values) c.flush()]);
}
