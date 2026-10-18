/// A stretch of time inside a video, [start] to [end].
class Span implements Comparable<Span> {
  const Span(this.start, this.end);

  final Duration start;
  final Duration end;

  Duration get length => end - start;

  bool contains(Duration t) => t >= start && t < end;

  /// Whether this and [other] overlap, or come within [slack] of each other.
  bool near(Span other, Duration slack) => other.start <= end + slack && other.end >= start - slack;

  @override
  int compareTo(Span other) {
    final c = start.compareTo(other.start);
    return c != 0 ? c : end.compareTo(other.end);
  }

  List<int> toJson() => [start.inMilliseconds, end.inMilliseconds];

  factory Span.fromJson(Object? j) {
    final l = (j as List).cast<int>();
    return Span(Duration(milliseconds: l[0]), Duration(milliseconds: l[1]));
  }

  @override
  bool operator ==(Object other) => other is Span && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Span(${start.inMilliseconds / 1000}–${end.inMilliseconds / 1000})';
}

/// Black frames and silences found by ffmpeg in (part of) a video. Times
/// are positions in the whole video.
class Detections {
  const Detections({required this.blacks, required this.silences});

  static const none = Detections(blacks: [], silences: []);

  final List<Span> blacks;
  final List<Span> silences;

  /// A black interval that overlaps silence (within this) is a strong cut:
  /// the picture and the sound both stop, as between two ads.
  static const strongSlack = Duration(milliseconds: 500);

  bool isStrong(Span black) => silences.any((s) => s.near(black, strongSlack));

  Map<String, Object?> toJson() => {
        'blacks': [for (final b in blacks) b.toJson()],
        'silences': [for (final s in silences) s.toJson()],
      };

  factory Detections.fromJson(Map<String, Object?> j) => Detections(
        blacks: [for (final b in j['blacks'] as List? ?? const []) Span.fromJson(b)],
        silences: [for (final s in j['silences'] as List? ?? const []) Span.fromJson(s)],
      );
}

final _black = RegExp(r'black_start:\s*(-?[\d.]+)\s+black_end:\s*(-?[\d.]+)');
final _silenceStart = RegExp(r'silence_start:\s*(-?[\d.]+)');
final _silenceEnd = RegExp(r'silence_end:\s*(-?[\d.]+)');

/// Reads `blackdetect` and `silencedetect` results from ffmpeg's stderr.
///
/// ffmpeg reports times from the start of what it scanned; [offset] is where
/// that was in the video (the `-ss` of a windowed scan). A silence still
/// open when the scan stops ends at [end], when given.
Detections parseFfmpegDetections(String stderr, {Duration offset = Duration.zero, Duration? end}) {
  Duration at(String seconds) {
    final t = Duration(microseconds: (double.parse(seconds) * 1e6).round());
    return (t.isNegative ? Duration.zero : t) + offset;
  }

  final blacks = <Span>[];
  final silences = <Span>[];
  Duration? openSilence;
  for (final line in stderr.split(RegExp(r'[\r\n]+'))) {
    if (_black.firstMatch(line) case final m?) {
      final b = Span(at(m[1]!), at(m[2]!));
      if (b.end > b.start) blacks.add(b);
      continue;
    }
    if (_silenceStart.firstMatch(line) case final m?) {
      openSilence = at(m[1]!);
      continue;
    }
    if (_silenceEnd.firstMatch(line) case final m?) {
      final s = Span(openSilence ?? offset, at(m[1]!));
      if (s.end > s.start) silences.add(s);
      openSilence = null;
    }
  }
  if (openSilence != null && end != null && end > openSilence) silences.add(Span(openSilence, end));
  blacks.sort();
  silences.sort();
  return Detections(blacks: blacks, silences: silences);
}
