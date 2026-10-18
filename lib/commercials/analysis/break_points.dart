import 'detections.dart';

/// Where a program's candidate mid-roll points came from.
enum PointSource {
  /// The starts of Jellyfin Commercial media segments.
  segments,

  /// Chapter starts that look like real act breaks.
  chapters,

  /// None: breaks go at evenly spaced points.
  even,
}

/// What's known about where a program can be interrupted.
class ProgramBreakInfo {
  const ProgramBreakInfo({
    this.source = PointSource.even,
    this.candidates = const [],
    this.skips = const [],
    this.scenes = Detections.none,
    this.scanned = const [],
  });

  static const unknown = ProgramBreakInfo();

  final PointSource source;

  /// Candidate break points, in order.
  final List<Duration> candidates;

  /// Commercial segments inside the program, replaced by breaks.
  final List<Span> skips;

  /// Black frames and silences found around evenly spaced points.
  final Detections scenes;

  /// The windows [scenes] covers.
  final List<Span> scanned;

  bool isScanned(Duration t) => scanned.any((w) => t >= w.start && t <= w.end);
}

/// Picks where mid-roll breaks go inside episodes and movies.
abstract final class BreakPointFinder {
  /// Chapters this close to the start or end are intros and credits.
  static const edge = Duration(minutes: 2);

  /// Chapter gaps all within this of each other were generated, not authored.
  static const generatedTolerance = Duration(seconds: 2);
  static const generatedMinGaps = 4;

  /// Candidates closer together than this keep only the earlier one.
  static const minSpacing = Duration(minutes: 4);

  /// Evenly spaced points move to a black frame at most this far away.
  static const snapRadius = Duration(seconds: 60);

  /// The usable chapter starts of a program [runtime] long: no intros or
  /// credits, not generated, at least [minSpacing] apart.
  static List<Duration> chapterCandidates(Duration runtime, List<Duration> chapters) {
    final starts = {...chapters}.toList()..sort();
    if (looksGenerated(starts)) return const [];
    final result = <Duration>[];
    for (final c in starts) {
      if (c < edge || c > runtime - edge) continue;
      if (result.isNotEmpty && c - result.last < minSpacing) continue;
      result.add(c);
    }
    return result;
  }

  /// [generatedMinGaps] or more gaps between chapters, all the same length
  /// (within [generatedTolerance]): chapters a tool added every N minutes.
  static bool looksGenerated(List<Duration> sortedStarts) {
    if (sortedStarts.length < generatedMinGaps + 1) return false;
    final gaps = [for (var i = 1; i < sortedStarts.length; i++) sortedStarts[i] - sortedStarts[i - 1]];
    final shortest = gaps.reduce((a, b) => a < b ? a : b);
    final longest = gaps.reduce((a, b) => a > b ? a : b);
    return longest - shortest <= generatedTolerance;
  }

  /// Candidate points from the first source that gives any: Commercial
  /// segment starts, then usable chapters.
  static (PointSource, List<Duration>) candidatesFor(Duration runtime,
      {List<Span> segments = const [], List<Duration> chapters = const []}) {
    if (segments.isNotEmpty) {
      return (PointSource.segments, [for (final s in [...segments]..sort()) s.start]);
    }
    final fromChapters = chapterCandidates(runtime, chapters);
    if (fromChapters.isNotEmpty) return (PointSource.chapters, fromChapters);
    return (PointSource.even, const []);
  }

  /// Where [count] breaks would go if spaced evenly through [runtime].
  static List<Duration> idealPoints(Duration runtime, int count) {
    if (count <= 0) return const [];
    final step = runtime.inMicroseconds / (count + 1);
    return [for (var i = 1; i <= count; i++) Duration(microseconds: (step * i).round())];
  }

  /// [ideal] moved to the nearest black frame within [snapRadius],
  /// preferring one with silence; null when there's none.
  static Duration? snap(Duration ideal, Detections scenes) {
    Duration? nearest(bool strongOnly) {
      Duration? best;
      for (final b in scenes.blacks) {
        if (strongOnly && !scenes.isStrong(b)) continue;
        final d = (b.start - ideal).abs();
        if (d > snapRadius) continue;
        if (best == null || d < (best - ideal).abs()) best = b.start;
      }
      return best;
    }

    return nearest(true) ?? nearest(false);
  }

  /// The windows ffmpeg should scan so the breaks [choose] can't put on a
  /// candidate snap to a scene break.
  static List<Span> windowsNeeded(Duration runtime, int count, ProgramBreakInfo info) {
    final assigned = _assign(runtime, count, info.candidates);
    return [
      for (final (i, ideal) in idealPoints(runtime, count).indexed)
        if (assigned[i] == null && !info.isScanned(ideal))
          Span(_clamp(ideal - snapRadius, runtime), _clamp(ideal + snapRadius, runtime)),
    ];
  }

  /// Where [count] mid-rolls go: each at the unused candidate nearest its
  /// evenly spaced ideal point (within a quarter of the spacing), otherwise
  /// at the ideal point, snapped to a scene break when analysis found one.
  static List<Duration> choose(Duration runtime, int count, ProgramBreakInfo info) {
    final ideals = idealPoints(runtime, count);
    final assigned = _assign(runtime, count, info.candidates);
    final points = [
      for (final (i, ideal) in ideals.indexed) assigned[i] ?? snap(ideal, info.scenes) ?? ideal,
    ];
    final unique = {for (final p in points) if (p > Duration.zero && p < runtime) p}.toList()..sort();
    return unique;
  }

  /// For each ideal point, the candidate it gets, if any. Closest pairs are
  /// matched first; each candidate is used once.
  static List<Duration?> _assign(Duration runtime, int count, List<Duration> candidates) {
    final ideals = idealPoints(runtime, count);
    final result = List<Duration?>.filled(ideals.length, null);
    if (ideals.isEmpty || candidates.isEmpty) return result;
    final reach = Duration(microseconds: runtime.inMicroseconds ~/ (count + 1) ~/ 4);
    final pairs = <(Duration, int, int)>[
      for (final (i, ideal) in ideals.indexed)
        for (final (j, c) in candidates.indexed)
          if ((c - ideal).abs() <= reach) ((c - ideal).abs(), i, j),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final used = <int>{};
    for (final (_, i, j) in pairs) {
      if (result[i] != null || used.contains(j)) continue;
      result[i] = candidates[j];
      used.add(j);
    }
    return result;
  }

  static Duration _clamp(Duration t, Duration runtime) =>
      t < Duration.zero ? Duration.zero : (t > runtime ? runtime : t);
}
