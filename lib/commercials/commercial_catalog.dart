import 'package:flutter/foundation.dart';

import '../library/library_index.dart';
import 'analysis/analysis_cache.dart';
import 'break_sources.dart';

/// The clips available at one point in time, by pool.
class ClipSnapshot {
  ClipSnapshot(this.effectiveFrom, this.byPool, {this.bumperPools = const {}})
      : all = _union(byPool, (p) => !bumperPools.contains(p)),
        bumpers = _union(byPool, bumperPools.contains);

  /// Breaks starting at or after this use these clips.
  final DateTime effectiveFrom;
  final Map<String, List<MediaEntry>> byPool;

  /// The pools in [byPool] that hold bumpers.
  final Set<String> bumperPools;

  /// Every clip in any commercial pool, each once.
  final List<MediaEntry> all;

  /// Every clip in any bumper pool, each once.
  final List<MediaEntry> bumpers;

  /// [poolId]'s clips, of either type; null for all commercial pools.
  List<MediaEntry> clipsFor(String? poolId) => poolId == null ? all : byPool[poolId] ?? const [];

  /// The clips a break can air as commercials from [poolId]: none from a
  /// bumper pool.
  List<MediaEntry> adsFor(String? poolId) => bumperPools.contains(poolId) ? const [] : clipsFor(poolId);

  /// [poolId]'s bumpers, or all bumper pools' when it has none.
  List<MediaEntry> bumpersFor(String? poolId) {
    final own = bumperPools.contains(poolId) ? byPool[poolId] ?? const <MediaEntry>[] : const <MediaEntry>[];
    return own.isEmpty ? bumpers : own;
  }

  static List<MediaEntry> _union(Map<String, List<MediaEntry>> byPool, bool Function(String) include) {
    final seen = <String>{};
    return [
      for (final MapEntry(key: pool, value: clips) in byPool.entries)
        if (include(pool))
          for (final c in clips)
            if (seen.add(c.id)) c,
    ];
  }
}

/// The commercial clips the pools hold, derived from the library's pool
/// items and the analysis cache (clips aren't stored anywhere themselves).
///
/// Short videos are one clip each. Reels expand into the clips analysis cut
/// them into (`<reelId>@<startMs>`), and give none until analyzed.
///
/// So that a change never alters a break already on air, each change makes
/// a new [ClipSnapshot] that applies from that moment; breaks keep using
/// the snapshot that was current when they started.
class CommercialCatalog extends ChangeNotifier implements ClipSource {
  CommercialCatalog({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Snapshots kept, newest last.
  static const keep = 2;

  /// Bumped whenever the clips change.
  int version = 0;
  final _snapshots = <ClipSnapshot>[];
  String _signature = '';

  /// The snapshot in effect now.
  ClipSnapshot get current => _snapshots.isEmpty ? ClipSnapshot(_epoch, const {}) : _snapshots.last;

  List<ClipSnapshot> get snapshots => List.unmodifiable(_snapshots);

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  List<MediaEntry> clipsFor(String? poolId) => current.clipsFor(poolId);

  /// Whether [poolId] has clips that can air as commercials.
  bool hasClips(String? poolId) => current.adsFor(poolId).isNotEmpty;

  /// The snapshot a break starting at [breakStart] uses.
  ClipSnapshot? _snapshotAt(DateTime breakStart) {
    for (final s in _snapshots.reversed) {
      if (!s.effectiveFrom.isAfter(breakStart)) return s;
    }
    return _snapshots.firstOrNull;
  }

  /// The clips a break starting at [breakStart] draws from.
  @override
  List<MediaEntry> clipsAt(String? poolId, DateTime breakStart) =>
      _snapshotAt(breakStart)?.adsFor(poolId) ?? const [];

  /// The bumpers a break starting at [breakStart] draws from.
  @override
  List<MediaEntry> bumpersAt(String? poolId, DateTime breakStart) =>
      _snapshotAt(breakStart)?.bumpersFor(poolId) ?? const [];

  /// Rebuilds from the library's pool [items], keeping only the pools in
  /// [poolIds], of which [bumperPools] hold bumpers. A change starts a new
  /// snapshot (from the epoch for the first one, e.g. at launch).
  void update(List<MediaEntry> items, AnalysisStore? cache, Iterable<String> poolIds,
      {Iterable<String> bumperPools = const []}) {
    final pools = poolIds.toSet();
    final bumpers = bumperPools.toSet();
    final byPool = <String, List<MediaEntry>>{for (final p in pools) p: []};
    for (final item in items) {
      final inPools = [for (final p in item.poolIds) if (pools.contains(p)) p];
      if (inPools.isEmpty) continue;
      for (final clip in clipsOf(item, cache?.latest(item))) {
        for (final p in inPools) {
          byPool[p]!.add(clip);
        }
      }
    }
    final signature = [
      for (final e in byPool.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        '${e.key}:${[for (final c in e.value) '${c.id}/${c.runtime.inMilliseconds}'].join(',')}',
      'bumpers:${(bumpers.toList()..sort()).join(',')}',
    ].join(';');
    if (signature == _signature && _snapshots.isNotEmpty) return;
    _signature = signature;
    _snapshots.add(ClipSnapshot(_snapshots.isEmpty ? _epoch : _clock(), byPool, bumperPools: bumpers));
    while (_snapshots.length > keep) {
      _snapshots.removeAt(0);
    }
    version++;
    notifyListeners();
  }

  /// [item]'s clips: itself when it's clip-length, its analyzed cuts when
  /// it's a reel, nothing otherwise.
  static List<MediaEntry> clipsOf(MediaEntry item, AnalysisResult? analysis) {
    if (item.runtime < LibraryIndex.minClip) return const [];
    if (item.runtime <= LibraryIndex.maxClip) return [item];
    return [
      for (final cut in analysis?.cuts ?? const [])
        MediaEntry(
          id: '${item.id}@${cut.start.inMilliseconds}',
          kind: MediaKind.commercial,
          title: item.title,
          runtime: cut.length,
          sourceId: item.id,
          clipStart: cut.start,
          etag: item.etag,
          container: item.container,
          size: item.size,
          poolIds: item.poolIds,
          streamPath: item.streamPath,
        ),
    ];
  }
}
