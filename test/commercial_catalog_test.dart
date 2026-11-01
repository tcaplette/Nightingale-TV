import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/analysis_cache.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/analysis/reel_cutter.dart';
import 'package:nightingale_tv/commercials/commercial_catalog.dart';
import 'package:nightingale_tv/library/library_index.dart';

Duration _s(num s) => Duration(milliseconds: (s * 1000).round());

MediaEntry _item(String id, Duration length, List<String> pools) =>
    MediaEntry(id: id, kind: MediaKind.commercial, title: id, runtime: length, etag: 'e', poolIds: pools);

void main() {
  late Directory dir;
  late AnalysisCache cache;
  var now = DateTime(2026, 10, 17, 18);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_catalog');
    cache = await AnalysisCache.open(dir, 'srv');
  });
  tearDown(() async {
    await cache.close();
    await dir.delete(recursive: true);
  });

  final reel = _item('reel', const Duration(minutes: 122), ['ads']);
  final spot = _item('spot', _s(30), ['ads', 'bumpers']);
  final tiny = _item('tiny', _s(3), ['ads']);
  final orphan = _item('orphan', _s(30), ['deleted-pool']);

  test('short videos are one clip; an unanalyzed reel gives nothing', () {
    final catalog = CommercialCatalog(clock: () => now)..update([reel, spot, tiny, orphan], cache, ['ads', 'bumpers']);
    expect([for (final c in catalog.clipsFor('ads')) c.id], ['spot']);
    expect([for (final c in catalog.clipsFor('bumpers')) c.id], ['spot']);
    expect([for (final c in catalog.clipsFor(null)) c.id], ['spot'], reason: 'all pools, each clip once');
    expect(catalog.hasClips('other'), isFalse);
  });

  test('an analyzed reel expands into clips named <reelId>@<startMs>', () {
    cache.recordReel(reel, ReelCuts(CutSource.detection, [Span(_s(48.231), _s(78.094)), Span(_s(78.345), _s(108.333))]),
        at: now);
    final catalog = CommercialCatalog(clock: () => now)..update([reel], cache, ['ads']);
    final clips = catalog.clipsFor('ads');
    expect([for (final c in clips) c.id], ['reel@48231', 'reel@78345']);
    final first = clips.first;
    expect(first.sourceId, 'reel');
    expect(first.clipStart, _s(48.231));
    expect(first.runtime, _s(29.863));
    expect(first.kind, MediaKind.commercial);
    expect(first.isClip, isTrue);
  });

  test('a change starts a new snapshot from that moment; the last two are kept', () {
    final catalog = CommercialCatalog(clock: () => now)..update([spot, reel], cache, ['ads']);
    expect(catalog.version, 1);
    expect(catalog.snapshots.single.effectiveFrom, DateTime.fromMillisecondsSinceEpoch(0));
    // Nothing changed: no new snapshot.
    catalog.update([spot, reel], cache, ['ads']);
    expect(catalog.version, 1);

    final splitAt = now = now.add(const Duration(minutes: 7));
    cache.recordReel(reel, ReelCuts(CutSource.detection, [Span(_s(0), _s(30))]), at: now);
    catalog.update([spot, reel], cache, ['ads']);
    expect(catalog.version, 2);
    expect(catalog.snapshots.last.effectiveFrom, splitAt);
    // A break that started before the reel was split keeps its clips.
    expect(catalog.clipsAt('ads', splitAt.subtract(const Duration(minutes: 1))).map((c) => c.id), ['spot']);
    expect(catalog.clipsAt('ads', splitAt).map((c) => c.id), ['spot', 'reel@0']);

    now = now.add(const Duration(minutes: 7));
    catalog.update([reel], cache, ['ads']);
    expect(catalog.snapshots, hasLength(2));
    expect(catalog.version, 3);
    // Older than every snapshot kept: the oldest one is the best there is.
    expect(catalog.clipsAt('ads', DateTime(2000)).map((c) => c.id), ['spot', 'reel@0']);
  });

  group('bumper pools', () {
    final ad = _item('ad', _s(30), ['ads']);
    final ident = _item('ident', _s(5), ['idents']);
    final other = _item('other', _s(5), ['others']);
    final at = DateTime(2026, 10, 17, 19);

    test('all pools means commercial pools, and bumpers have their own union', () {
      final catalog = CommercialCatalog(clock: () => now)
        ..update([ad, ident, other], null, ['ads', 'idents', 'others'], bumperPools: ['idents', 'others']);
      expect(catalog.clipsAt(null, at).map((c) => c.id), ['ad']);
      expect(catalog.bumpersAt(null, at).map((c) => c.id), ['ident', 'other']);
      expect(catalog.clipsFor('idents').map((c) => c.id), ['ident'], reason: 'counts still see its clips');
      expect(catalog.clipsAt('idents', at), isEmpty, reason: 'never as ads, even if a plan names it');
      expect(catalog.hasClips('idents'), isFalse);
      expect(catalog.hasClips('ads'), isTrue);
    });

    test('a picked pool with no bumpers falls back to all of them', () {
      final catalog = CommercialCatalog(clock: () => now)
        ..update([ident, other], null, ['ads', 'idents', 'others', 'empty'], bumperPools: ['idents', 'others', 'empty']);
      expect(catalog.bumpersAt('others', at).map((c) => c.id), ['other']);
      expect(catalog.bumpersAt('empty', at).map((c) => c.id), ['ident', 'other']);
      expect(catalog.bumpersAt('ads', at).map((c) => c.id), ['ident', 'other'], reason: 'not a bumper pool');
    });

    test('a type change starts a new snapshot; breaks before it keep theirs', () {
      final catalog = CommercialCatalog(clock: () => now)..update([ad, ident], null, ['ads', 'idents']);
      expect(catalog.clipsAt(null, at).map((c) => c.id), ['ad', 'ident']);
      final changedAt = now = now.add(const Duration(minutes: 5));
      catalog.update([ad, ident], null, ['ads', 'idents'], bumperPools: ['idents']);
      expect(catalog.version, 2);
      expect(catalog.clipsAt(null, changedAt.subtract(const Duration(seconds: 1))).map((c) => c.id), ['ad', 'ident']);
      expect(catalog.bumpersAt(null, changedAt.subtract(const Duration(seconds: 1))), isEmpty);
      expect(catalog.clipsAt(null, changedAt).map((c) => c.id), ['ad']);
      expect(catalog.bumpersAt(null, changedAt).map((c) => c.id), ['ident']);
    });
  });
}
