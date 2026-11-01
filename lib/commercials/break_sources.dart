import '../library/library_index.dart';
import 'analysis/break_points.dart';

/// Where a schedule gets the clips for a break.
abstract interface class ClipSource {
  /// [poolId]'s clips (null: all pools) for a break starting at
  /// [breakStart].
  List<MediaEntry> clipsAt(String? poolId, DateTime breakStart);

  /// [poolId]'s bumpers for a break starting at [breakStart]: all bumper
  /// pools' when [poolId] is null or has none then.
  List<MediaEntry> bumpersAt(String? poolId, DateTime breakStart);
}

/// Where a schedule learns where a program can be interrupted.
abstract interface class BreakPointSource {
  /// What was known about [program] at [asOf].
  ProgramBreakInfo pointsFor(MediaEntry program, DateTime asOf);
}

/// No clips at all.
class NoClips implements ClipSource {
  const NoClips();

  @override
  List<MediaEntry> clipsAt(String? poolId, DateTime breakStart) => const [];

  @override
  List<MediaEntry> bumpersAt(String? poolId, DateTime breakStart) => const [];
}

/// Fixed clips, whatever the pool and time (handy in tests).
class FixedClips implements ClipSource {
  const FixedClips(this.clips, {this.byPool = const {}, this.bumpers = const [], this.bumpersByPool = const {}});

  final List<MediaEntry> clips;
  final Map<String, List<MediaEntry>> byPool;
  final List<MediaEntry> bumpers;
  final Map<String, List<MediaEntry>> bumpersByPool;

  @override
  List<MediaEntry> clipsAt(String? poolId, DateTime breakStart) =>
      poolId == null ? clips : byPool[poolId] ?? const [];

  @override
  List<MediaEntry> bumpersAt(String? poolId, DateTime breakStart) {
    final own = bumpersByPool[poolId];
    return own == null || own.isEmpty ? bumpers : own;
  }
}

/// Break points from chapters alone, with no analysis.
class ChapterPoints implements BreakPointSource {
  const ChapterPoints();

  @override
  ProgramBreakInfo pointsFor(MediaEntry program, DateTime asOf) {
    final (source, candidates) = BreakPointFinder.candidatesFor(program.runtime, chapters: program.chapters);
    return ProgramBreakInfo(source: source, candidates: candidates);
  }
}
