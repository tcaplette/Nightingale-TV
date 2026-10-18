import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/break_points.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';

Duration _ticks(int t) => Duration(microseconds: t ~/ 10);
List<Duration> _chapters(List<int> ticks) => [for (final t in ticks) _ticks(t)];
Duration _min(num m) => Duration(milliseconds: (m * 60000).round());
double _minutes(Duration d) => (d.inMilliseconds / 6000).round() / 10;

// Chapter tables from the test server.
final _archer = (
  runtime: _ticks(12928309999),
  chapters: _chapters([0, 1493580000, 4105770000, 7390300000, 12212620000]),
);
// Shameless S02E05: a chapter exactly every 5 minutes.
final _shamelessGenerated = (
  runtime: _ticks(32103250000),
  chapters: _chapters([
    0, 3000080000, 6000160000, 9000240000, 12000320000, 15000820000, //
    18000070000, 21000150000, 24000640000, 27000310000, 30000800000,
  ]),
);
// Shameless S02E04: real act breaks.
final _shameless = (
  runtime: _ticks(32433490000),
  chapters: _chapters([0, 1350520000, 5717800000, 11460620000, 17981710000, 23579810000, 31072290000]),
);
// The White Lotus, "Special Treatments": intro and credits chapters.
final _whiteLotus = (
  runtime: _ticks(36603240000),
  chapters: _chapters([0, 55050000, 1076500000, 7581320000, 14323890000, 21560280000, 27993790000, 35886260000]),
);

void main() {
  group('chapter filtering', () {
    test('Archer: act-break chapters are candidates; the credits chapter is not', () {
      final (source, points) = BreakPointFinder.candidatesFor(_archer.runtime, chapters: _archer.chapters);
      expect(source, PointSource.chapters);
      expect(points.map(_minutes), [2.5, 6.8, 12.3]);
    });

    test('Shameless: chapters every 5 minutes are generated and rejected', () {
      expect(BreakPointFinder.looksGenerated(_shamelessGenerated.chapters), isTrue);
      final (source, points) =
          BreakPointFinder.candidatesFor(_shamelessGenerated.runtime, chapters: _shamelessGenerated.chapters);
      expect(source, PointSource.even);
      expect(points, isEmpty);
    });

    test('Shameless with real chapters keeps them', () {
      expect(BreakPointFinder.looksGenerated(_shameless.chapters), isFalse);
      final points = BreakPointFinder.chapterCandidates(_shameless.runtime, _shameless.chapters);
      // 51.8 is more than 2 minutes before the end (54.1).
      expect(points.map(_minutes), [2.3, 9.5, 19.1, 30.0, 39.3, 51.8]);
    });

    test('The White Lotus: intro and credits chapters are dropped', () {
      final points = BreakPointFinder.chapterCandidates(_whiteLotus.runtime, _whiteLotus.chapters);
      expect(points.map(_minutes), [12.6, 23.9, 35.9, 46.7]);
    });

    test('candidates are at least 4 minutes apart, keeping the earlier one', () {
      final points = BreakPointFinder.chapterCandidates(_min(40), [_min(5), _min(7), _min(9.5), _min(20)]);
      expect(points, [_min(5), _min(9.5), _min(20)]);
    });

    test('a movie without chapters or segments uses evenly spaced points', () {
      final (source, points) = BreakPointFinder.candidatesFor(_min(100));
      expect(source, PointSource.even);
      expect(points, isEmpty);
      expect(BreakPointFinder.choose(_min(100), 4, ProgramBreakInfo.unknown), [_min(20), _min(40), _min(60), _min(80)]);
    });

    test('Commercial segment starts come before chapters', () {
      final (source, points) = BreakPointFinder.candidatesFor(_archer.runtime,
          segments: [Span(_min(8), _min(10))], chapters: _archer.chapters);
      expect(source, PointSource.segments);
      expect(points, [_min(8)]);
    });
  });

  group('choosing points', () {
    ProgramBreakInfo chapters(Duration runtime, List<Duration> c) =>
        ProgramBreakInfo(source: PointSource.chapters, candidates: BreakPointFinder.chapterCandidates(runtime, c));

    test('Archer under Automatic (2 mid-rolls) breaks at the chapter in reach', () {
      // Ideal points 7.2 and 14.4, each reaching 1.8 minutes: 6.8 is used,
      // 12.3 is too far from 14.4.
      final points = BreakPointFinder.choose(_archer.runtime, 2, chapters(_archer.runtime, _archer.chapters));
      expect(points.map(_minutes), [6.8, 14.4]);
      // With one mid-roll (ideal 10.8, reach 2.7), 12.3 is used.
      expect(BreakPointFinder.choose(_archer.runtime, 1, chapters(_archer.runtime, _archer.chapters)).map(_minutes),
          [12.3]);
    });

    test('fewer chapters than breaks: the rest fall at their even points', () {
      final runtime = _min(50);
      final info = ProgramBreakInfo(source: PointSource.chapters, candidates: [_min(9), _min(31)]);
      expect(BreakPointFinder.choose(runtime, 4, info), [_min(9), _min(20), _min(31), _min(40)]);
    });

    test('a candidate is used only once, and only within a quarter of the spacing', () {
      final info = ProgramBreakInfo(source: PointSource.chapters, candidates: [_min(13)]);
      // Ideals at 10 and 20 (spacing 10, reach 2.5): 13 is out of reach of both.
      expect(BreakPointFinder.choose(_min(30), 2, info), [_min(10), _min(20)]);
      final near = ProgramBreakInfo(source: PointSource.chapters, candidates: [_min(11)]);
      expect(BreakPointFinder.choose(_min(30), 2, near), [_min(11), _min(20)]);
    });

    test('an even point snaps to a black-and-silent gap nearby', () {
      final scenes = Detections(
        blacks: [Span(_min(11.7), _min(11.71)), Span(_min(10.9), _min(10.91))],
        silences: [Span(_min(11.69), _min(11.72))],
      );
      final info = ProgramBreakInfo(scenes: scenes, scanned: [Span(_min(10), _min(12))]);
      // 10:54 is closer, but 11:42 has silence too.
      expect(BreakPointFinder.choose(_min(22), 1, info), [_min(11.7)]);
    });

    test('without silence, the nearest black frame wins', () {
      final scenes = Detections(blacks: [Span(_min(11.7), _min(11.71)), Span(_min(10.9), _min(10.91))], silences: const []);
      expect(BreakPointFinder.snap(_min(11), scenes), _min(10.9));
    });

    test('no black frame within 60 seconds: the point stays', () {
      final scenes = Detections(blacks: [Span(_min(12.1), _min(12.11))], silences: const []);
      final info = ProgramBreakInfo(scenes: scenes, scanned: [Span(_min(10), _min(12))]);
      expect(BreakPointFinder.choose(_min(22), 1, info), [_min(11)]);
    });

    test('scan windows are asked for only where no candidate is used', () {
      final info = ProgramBreakInfo(source: PointSource.chapters, candidates: [_min(9)]);
      final windows = BreakPointFinder.windowsNeeded(_min(50), 4, info);
      expect(windows, [Span(_min(19), _min(21)), Span(_min(29), _min(31)), Span(_min(39), _min(41))]);
      final scanned = ProgramBreakInfo(
          source: PointSource.chapters, candidates: [_min(9)], scanned: [Span(_min(19), _min(31))]);
      expect(BreakPointFinder.windowsNeeded(_min(50), 4, scanned), [Span(_min(39), _min(41))]);
    });
  });
}
