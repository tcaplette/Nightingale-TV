import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/analysis/reel_cutter.dart';

Duration _s(num seconds) => Duration(microseconds: (seconds * 1e6).round());
Span _span(num a, num b) => Span(_s(a), _s(b));

/// Black frames at [blacks] (start, end), with silence at those listed in
/// [silent].
Detections _detections(List<(num, num)> blacks, {Set<int> silent = const {}}) => Detections(
      blacks: [for (final (a, b) in blacks) _span(a, b)],
      silences: [
        for (final (i, (a, b)) in blacks.indexed)
          if (silent.contains(i)) _span(a, b + 0.2),
      ],
    );

void main() {
  group('source order', () {
    test('Commercial media segments come first, one clip each', () {
      final cuts = ReelCutter.fromMetadata(_s(600),
          segments: [_span(30, 60), _span(0, 30), _span(60, 75)], chapters: [_s(0), _s(100)])!;
      expect(cuts.source, CutSource.segments);
      expect(cuts.clips, [_span(0, 30), _span(30, 60), _span(60, 75)]);
    });

    test('a reel with 40 chapters and no segments gives one clip per chapter', () {
      final chapters = [for (var i = 0; i < 40; i++) _s(i * 30)];
      final cuts = ReelCutter.fromMetadata(_s(1200), chapters: chapters)!;
      expect(cuts.source, CutSource.chapters);
      expect(cuts.clips, hasLength(40));
      expect(cuts.clips[3], _span(90, 120));
      expect(cuts.clips.last, _span(1170, 1200));
    });

    test('a reel with neither needs detection', () {
      expect(ReelCutter.fromMetadata(_s(7329)), isNull);
      expect(ReelCutter.fromMetadata(_s(7329), chapters: [_s(0)]), isNull, reason: 'one chapter is no cut');
      // Chapters that only give pieces too long to use don't count either.
      expect(ReelCutter.fromMetadata(_s(7329), chapters: [_s(0), _s(3600)]), isNull);
    });
  });

  group('detection', () {
    test('30-second spots between black-and-silent gaps', () {
      final cuts = ReelCutter.fromDetections(
          _s(140), _detections([(47.06, 48.23), (78.09, 78.35), (108.33, 108.58)], silent: {0, 1, 2}));
      expect(cuts.source, CutSource.detection);
      expect(cuts.clips, contains(_span(48.23, 78.09)));
      expect(cuts.clips, contains(_span(78.35, 108.33)));
      expect(cuts.clips.first, _span(0, 47.06));
      expect(cuts.clips.last, _span(108.58, 140));
    });

    test('black frames without silence only cut pieces over 3 minutes', () {
      // Strong cuts at 10 s and 230 s leave a 220-second piece; the black
      // frames without silence inside it split it.
      final cuts = ReelCutter.fromDetections(
          _s(260), _detections([(9, 10), (50, 50.5), (100, 101), (160, 161), (230, 231)], silent: {0, 4}));
      expect(cuts.clips,
          [_span(0, 9), _span(10, 50), _span(50.5, 100), _span(101, 160), _span(161, 230), _span(231, 260)]);
      // Under 3 minutes, a black frame without silence is not a cut.
      final short = ReelCutter.fromDetections(_s(100), _detections([(9, 10), (50, 50.5)], silent: {0}));
      expect(short.clips, [_span(0, 9), _span(10, 100)]);
    });

    test('a piece still over 3 minutes is not used', () {
      final cuts = ReelCutter.fromDetections(_s(400), _detections([(30, 31), (250, 251)], silent: {0, 1}));
      expect(cuts.clips, [_span(0, 30), _span(251, 400)]);
    });

    test('a 3-second fragment becomes the start of the clip after it', () {
      final cuts = ReelCutter.fromDetections(
          _s(100), _detections([(30, 30.5), (33.5, 34), (64, 64.5)], silent: {0, 1, 2}));
      expect(cuts.clips, [_span(0, 30), _span(30.5, 64), _span(64.5, 100)]);
    });

    test('a short piece at the end joins the clip before it', () {
      final cuts = ReelCutter.fromDetections(_s(65), _detections([(30, 30.5), (61, 61.2)], silent: {0, 1}));
      expect(cuts.clips, [_span(0, 30), _span(30.5, 65)]);
    });

    test('a fragment that would make the next clip too long is dropped', () {
      final cuts = ReelCutter.fromDetections(
          _s(300), _detections([(10, 11), (14, 14.2), (192, 193)], silent: {0, 1, 2}));
      expect(cuts.clips, [_span(0, 10), _span(14.2, 192), _span(193, 300)]);
    });

    test('a fragment next to an unusable piece is dropped with it', () {
      final cuts = ReelCutter.fromDetections(_s(400), _detections([(20, 21), (24, 24.5)], silent: {0, 1}));
      expect(cuts.clips, [_span(0, 20)]);
    });

    test('the real reel scan splits into ads of 30 s to 2 min', () {
      final d = parseFfmpegDetections(File('test/fixtures/reel_window_600.txt').readAsStringSync());
      final cuts = ReelCutter.fromDetections(_s(300), d);
      expect(cuts.clips.map((c) => c.start.inMilliseconds ~/ 100 / 10), [0, 48.2, 78.3, 108.5, 226.3, 256.6]);
      expect(cuts.clips[1].end, _s(78.094761));
      for (final c in cuts.clips) {
        expect(c.length >= ReelCutter.minClip && c.length <= ReelCutter.maxClip, isTrue, reason: "$c");
      }
    });
  });

  test('chapter clips follow the same length limits', () {
    final cuts = ReelCutter.fromMetadata(_s(500), chapters: [_s(0), _s(3), _s(40), _s(80), _s(400)])!;
    // 0–3 joins 3–40; 80–400 is too long; 400–500 is fine.
    expect(cuts.clips, [_span(0, 40), _span(40, 80), _span(400, 500)]);
  });
}
