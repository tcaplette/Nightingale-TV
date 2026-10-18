import 'detections.dart';

/// Where a reel's cut points came from.
enum CutSource {
  /// Jellyfin media segments of type Commercial.
  segments,
  chapters,

  /// ffmpeg black-frame and silence detection.
  detection,
}

/// A reel split into clips.
class ReelCuts {
  const ReelCuts(this.source, this.clips);

  final CutSource source;

  /// Each clip's range in the reel, in order.
  final List<Span> clips;
}

/// Splits long commercial videos ("reels") into individual ads.
abstract final class ReelCutter {
  /// Clips are at least this long; shorter pieces join a neighbor.
  static const minClip = Duration(seconds: 5);

  /// Clips are at most this long; longer pieces aren't used.
  static const maxClip = Duration(minutes: 3);

  /// Cuts from the reel's own metadata: Commercial media segments (one clip
  /// each), else chapters (one clip each). Null when neither gives a usable
  /// clip, so detection is needed.
  static ReelCuts? fromMetadata(Duration runtime,
      {List<Span> segments = const [], List<Duration> chapters = const []}) {
    if (segments.isNotEmpty) {
      final clips = _limit([...segments]..sort(), runtime);
      if (clips.isNotEmpty) return ReelCuts(CutSource.segments, clips);
    }
    final starts = {for (final c in chapters) if (c >= Duration.zero && c < runtime) c}.toList()..sort();
    if (starts.length > 1) {
      final pieces = [
        if (starts.first > Duration.zero) Span(Duration.zero, starts.first),
        for (var i = 0; i < starts.length; i++) Span(starts[i], i + 1 < starts.length ? starts[i + 1] : runtime),
      ];
      final clips = _limit(pieces, runtime);
      if (clips.isNotEmpty) return ReelCuts(CutSource.chapters, clips);
    }
    return null;
  }

  /// Cuts at black frames: first where picture and sound both stop (strong
  /// cuts), then, inside pieces still too long, at the other black frames.
  /// Each clip starts after one black interval and ends before the next.
  static ReelCuts fromDetections(Duration runtime, Detections d) {
    final whole = Span(Duration.zero, runtime);
    final strong = [for (final b in d.blacks) if (d.isStrong(b)) b];
    final pieces = <Span?>[];
    for (final piece in _split(whole, strong)) {
      if (piece.length <= maxClip) {
        pieces.add(piece);
        continue;
      }
      final inside = [for (final b in d.blacks) if (b.start > piece.start && b.end < piece.end) b];
      for (final sub in _split(piece, inside)) {
        // Still too long: not usable. Null keeps neighbors from merging
        // across it.
        pieces.add(sub.length <= maxClip ? sub : null);
      }
    }
    return ReelCuts(CutSource.detection, _limit(pieces, runtime));
  }

  /// [range] split at [cuts] (sorted), leaving the cut intervals out.
  static List<Span> _split(Span range, List<Span> cuts) {
    final result = <Span>[];
    var from = range.start;
    for (final c in cuts) {
      if (c.end <= from || c.start >= range.end) continue;
      if (c.start > from) result.add(Span(from, c.start));
      if (c.end > from) from = c.end;
    }
    if (range.end > from) result.add(Span(from, range.end));
    return result;
  }

  /// Applies the clip length limits to consecutive [pieces] (null: a gap
  /// that's not usable). A piece under [minClip] becomes the start of the
  /// clip after it, or at the end the tail of the clip before it; one that
  /// would make its neighbor too long is dropped. Pieces over [maxClip] are
  /// dropped.
  static List<Span> _limit(List<Span?> pieces, Duration runtime) {
    final clips = <Span>[];
    Span? carry; // Short pieces waiting to join the next clip.
    var lastWasClip = false;
    for (final p in pieces) {
      if (p == null || p.length > maxClip) {
        carry = null;
        lastWasClip = false;
        continue;
      }
      final merged = carry == null ? p : Span(carry.start, p.end);
      if (merged.length < minClip) {
        carry = merged;
        continue;
      }
      // Too long with the short pieces in front: drop them instead. (Then p
      // alone is over maxClip − minClip, so still long enough.)
      clips.add(merged.length <= maxClip ? merged : p);
      carry = null;
      lastWasClip = true;
    }
    if (carry != null && lastWasClip && clips.isNotEmpty) {
      final joined = Span(clips.last.start, carry.end);
      if (joined.length <= maxClip) clips[clips.length - 1] = joined;
    }
    return [
      for (final c in clips)
        if (c.start >= Duration.zero && c.end <= runtime && c.length >= minClip) c,
    ];
  }
}
