import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/analysis_cache.dart';
import 'package:nightingale_tv/commercials/analysis/break_points.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/analysis/reel_cutter.dart';
import 'package:nightingale_tv/library/library_index.dart';

Duration _s(num s) => Duration(milliseconds: (s * 1000).round());
Span _span(num a, num b) => Span(_s(a), _s(b));

MediaEntry _reel(String etag) => MediaEntry(
    id: 'reel', kind: MediaKind.commercial, title: 'Reel', runtime: const Duration(minutes: 122), etag: etag);

MediaEntry _episode(String etag) => MediaEntry(
      id: 'ep',
      kind: MediaKind.episode,
      title: 'Ep',
      runtime: const Duration(minutes: 22),
      etag: etag,
      chapters: const [Duration.zero, Duration(minutes: 6), Duration(minutes: 21)],
    );

void main() {
  late Directory dir;
  final t0 = DateTime(2026, 10, 17, 18);

  setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_analysis'));
  tearDown(() => dir.delete(recursive: true));

  test('results survive a restart', () async {
    final cache = await AnalysisCache.open(dir, 'srv-1', debounce: const Duration(milliseconds: 10));
    cache.recordReel(_reel('a'), ReelCuts(CutSource.detection, [_span(0.5, 60), _span(62, 122)]), at: t0);
    await cache.close();
    expect(File('${dir.path}/srv-1.json').existsSync(), isTrue);

    final again = await AnalysisCache.open(dir, 'srv-1');
    expect(again.isAnalyzed(_reel('a')), isTrue);
    expect(again.latest(_reel('a'))!.cuts, [_span(0.5, 60), _span(62, 122)]);
    expect(again.latest(_reel('a'))!.cutSource, CutSource.detection);
    expect(again['reel']!.current!.analyzedAt, t0);
    final other = await AnalysisCache.open(dir, 'srv-2');
    expect(other.latest(_reel('a')), isNull, reason: 'each server has its own cache');
  });

  test('a changed Etag means analyzing again, with the old result in use until then', () async {
    final cache = await AnalysisCache.open(dir, 'srv');
    cache.recordReel(_reel('a'), ReelCuts(CutSource.detection, [_span(0, 30)]), at: t0);
    expect(cache.isAnalyzed(_reel('b')), isFalse);
    expect(cache.latest(_reel('b'))!.cuts, [_span(0, 30)], reason: 'old clips stay in use');
    cache.recordReel(_reel('b'), ReelCuts(CutSource.chapters, [_span(0, 45)]), at: t0.add(const Duration(hours: 1)));
    expect(cache.isAnalyzed(_reel('b')), isTrue);
    expect(cache.latest(_reel('b'))!.cuts, [_span(0, 45)]);
    expect(cache['reel']!.previous!.cuts, [_span(0, 30)]);
    expect(cache['reel']!.etag, 'b');
    await cache.close();
  });

  test('a write that never finished leaves the cache as it was', () async {
    final cache = await AnalysisCache.open(dir, 'srv', debounce: const Duration(milliseconds: 10));
    cache.recordReel(_reel('a'), ReelCuts(CutSource.detection, [_span(0, 30)]), at: t0);
    await cache.close();
    // A crash mid-write leaves a temp file behind, maybe truncated.
    await File('${dir.path}/srv.json.${pid}_99.tmp').writeAsString('{"version":1,"items":{"reel":{"etag":"zz"');
    await File('${dir.path}/srv.json.tmp').writeAsString('{"version":1,"items":{}}');
    final again = await AnalysisCache.open(dir, 'srv');
    expect(again.isAnalyzed(_reel('a')), isTrue);
    expect(again.latest(_reel('a'))!.cuts, [_span(0, 30)]);
    // A damaged cache file itself just means analyzing again.
    await File('${dir.path}/srv.json').writeAsString('{"version":1,"ite');
    final damaged = await AnalysisCache.open(dir, 'srv');
    expect(damaged.latest(_reel('a')), isNull);
  });

  test('writes are batched', () async {
    final cache = await AnalysisCache.open(dir, 'srv', debounce: const Duration(milliseconds: 200));
    cache.recordReel(_reel('a'), null, at: t0);
    expect(File('${dir.path}/srv.json').existsSync(), isFalse);
    // Written after the debounce; a loaded machine may take longer than it.
    final file = File('${dir.path}/srv.json');
    for (var i = 0; i < 100 && !file.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(file.existsSync(), isTrue);
    await cache.close();
  });

  test('pointsFor uses what was known at the given time', () async {
    final cache = await AnalysisCache.open(dir, 'srv');
    final ep = _episode('a');
    // Before analysis: chapters only.
    expect(cache.pointsFor(ep, t0).candidates, [const Duration(minutes: 6)]);
    expect(cache.pointsFor(ep, t0).source, PointSource.chapters);

    final t1 = t0.add(const Duration(hours: 1));
    cache.recordSegments(ep, [Span(const Duration(minutes: 8), const Duration(minutes: 10))], at: t1);
    final t2 = t0.add(const Duration(hours: 2));
    cache.recordWindow(
        ep,
        ScanWindow(
          range: Span(const Duration(minutes: 10), const Duration(minutes: 12)),
          analyzedAt: t2,
          detections: Detections(blacks: [_span(700, 700.5)], silences: const []),
        ));

    expect(cache.pointsFor(ep, t0).source, PointSource.chapters, reason: 'a slot from before keeps its breaks');
    final at1 = cache.pointsFor(ep, t1);
    expect(at1.source, PointSource.segments);
    expect(at1.candidates, [const Duration(minutes: 8)]);
    expect(at1.skips, hasLength(1));
    expect(at1.scanned, isEmpty, reason: 'the window was scanned later');
    final at2 = cache.pointsFor(ep, t2);
    expect(at2.scanned, hasLength(1));
    expect(at2.scenes.blacks.single.start, _s(700));

    // The file is replaced: the next result replaces the current one, and
    // slots from before it still see the older result.
    final t3 = t0.add(const Duration(hours: 3));
    cache.recordSegments(_episode('b'), const [], at: t3);
    expect(cache.pointsFor(_episode('b'), t3).source, PointSource.chapters);
    expect(cache.pointsFor(_episode('b'), t2).source, PointSource.segments, reason: 'asOf picks the previous result');
    await cache.close();
  });

  test('failures count up, give up, and reset when the file changes', () async {
    final cache = await AnalysisCache.open(dir, 'srv');
    final reel = _reel('a');
    for (var i = 0; i < 4; i++) {
      cache.recordFailure(reel, at: t0, maxFailures: 4);
    }
    expect(cache.failuresOf(reel).$1, 4);
    expect(cache.gaveUpOn(reel), isTrue);
    expect(cache.gaveUpOn(_reel('b')), isFalse);
    expect(cache.failuresOf(_reel('b')).$1, 0);
    await cache.close();
  });
}
