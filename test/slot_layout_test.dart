import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/analysis/break_points.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/break_sources.dart';
import 'package:nightingale_tv/commercials/commercial_catalog.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'fixtures.dart';

final _anchor = DateTime(2026, 10, 10, 18); // a Saturday, 6 PM

Duration _s(num s) => Duration(milliseconds: (s * 1000).round());
Duration _m(int m, [num s = 0]) => Duration(minutes: m) + _s(s);
DateTime _at(int hour, int minute, [num second = 0]) =>
    DateTime(_anchor.year, _anchor.month, _anchor.day, hour, minute).add(_s(second));

Channel _channel(List<String> playlist) => Channel(
      id: 'ch',
      number: 2,
      name: 'Test',
      icon: const ChannelIcon.builtin('tv'),
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: playlist,
      anchor: _anchor,
    );

MediaEntry _clip(String id, Duration length, {String? reel, Duration? at, List<String> pools = const ['ads']}) =>
    MediaEntry(
      id: reel == null ? id : '$reel@${at!.inMilliseconds}',
      kind: MediaKind.commercial,
      title: id,
      runtime: length,
      sourceId: reel,
      clipStart: at,
      poolIds: pools,
    );

/// Break points that depend on when they were found.
class _Points implements BreakPointSource {
  _Points(this.byTime);

  /// (found at, info), oldest first.
  final List<(DateTime, ProgramBreakInfo)> byTime;

  @override
  ProgramBreakInfo pointsFor(MediaEntry program, DateTime asOf) =>
      byTime.lastWhere((e) => !e.$1.isAfter(asOf), orElse: () => (asOf, ProgramBreakInfo.unknown)).$2;
}

/// Every playback segment from [from] until [to].
List<ScheduledProgram> _segments(ChannelSchedule s, DateTime from, DateTime to) {
  final result = <ScheduledProgram>[];
  var p = s.playbackAt(from);
  while (p.start.isBefore(to)) {
    result.add(p);
    p = s.playbackAt(p.end);
  }
  return result;
}

/// Joins consecutive break segments of the same role.
List<String> _outline(List<ScheduledProgram> segments) {
  final out = <(String, int, int)>[];
  for (final p in segments) {
    final role = p.isBreak ? (p.role == BreakRole.fallback ? 'fill' : p.role!.name) : 'show';
    if (role != 'show' && out.isNotEmpty && (out.last.$1 == role || role == 'fill')) {
      final last = out.removeLast();
      out.add((last.$1, last.$2, last.$3 + p.duration.inSeconds));
      continue;
    }
    out.add(role == 'show' ? ('show', p.itemFrom.inSeconds, p.itemTo.inSeconds) : (role, 0, p.duration.inSeconds));
  }
  return [for (final (r, a, b) in out) r == 'show' ? 'show $a-$b' : '$r ${b}s'];
}

void main() {
  final library = fakeLibrary(shows: {'Archer': 10}); // 22-minute episodes
  final playlist = [for (var i = 1; i <= 10; i++) 'Archer-e$i'];
  final ads = [
    for (var i = 0; i < 12; i++) _clip('ad$i', _s(30)),
    for (var i = 0; i < 4; i++) _clip('short$i', _s(15)),
  ];
  final clips = FixedClips(ads, byPool: {'ads': ads});

  ChannelSchedule schedule(BreakPlan plan, {ClipSource? source, BreakPointSource? points, List<ProgramBlock> blocks = const []}) =>
      ChannelSchedule.build(_channel(playlist), library, blocks,
          BreakContext(plan: plan, clips: source ?? clips, points: points ?? const ChapterPoints()))!;

  test('two mid-rolls at the break points', () {
    final s = schedule(BreakPlan.automatic,
        points: _Points([
          (DateTime(2000), ProgramBreakInfo(source: PointSource.chapters, candidates: [_m(7, 10), _m(14, 40)])),
        ]));
    final slot = s.programAt(_at(18, 5));
    expect((slot.start, slot.end), (_at(18, 0), _at(18, 30)), reason: 'one guide cell for the whole slot');
    expect(_outline(_segments(s, _at(18, 0), _at(18, 30))), [
      'pre 15s',
      'show 0-430',
      'mid 180s',
      'show 430-880',
      'mid 180s',
      'show 880-1320',
      'post 105s',
    ]);
    // Each show part resumes exactly where the last one stopped.
    final second = s.playbackAt(_at(18, 10, 25));
    expect(second.role, isNull);
    expect(second.item!.id, 'Archer-e1');
    expect(second.start, _at(18, 10, 25));
    expect(second.itemFrom, _m(7, 10));
    expect(second.positionAt(_at(18, 11, 25)), _m(8, 10));
  });

  test('segments tile the slot exactly, every slot', () {
    final s = schedule(BreakPlan.automatic);
    final segments = _segments(s, _at(18, 0), _at(21, 0));
    for (var i = 1; i < segments.length; i++) {
      expect(segments[i].start, segments[i - 1].end);
    }
    for (final slot in s.programsBetween(_at(18, 0), _at(21, 0))) {
      expect(slot.start.minute % 30, 0);
      final shows = segments.where((p) => !p.isBreak && p.start.isBefore(slot.end) && !p.start.isBefore(slot.start));
      expect(shows.fold(Duration.zero, (t, p) => t + p.duration), _m(22), reason: 'the whole episode plays');
    }
  });

  test('fewer chapters than breaks: the rest at their even points', () {
    // 44 minutes, a mid-roll every 10 minutes: 4 breaks; chapters at 8:00
    // and 27:00 cover two.
    final long = fakeLibrary(shows: {'Lotus': 2}, episodeLength: _m(44));
    const plan = BreakPlan(
        mode: BreakMode.custom, roles: CustomRoles(midInterval: Duration(minutes: 10), midLength: Duration(minutes: 2)));
    final s = ChannelSchedule.build(
        _channel(['Lotus-e1', 'Lotus-e2']),
        long,
        const [],
        BreakContext(
          plan: plan,
          clips: clips,
          points: _Points([(DateTime(2000), ProgramBreakInfo(source: PointSource.chapters, candidates: [_m(8), _m(27)]))]),
        ))!;
    final shows = [for (final p in _segments(s, _at(18, 0), _at(18, 52))) if (!p.isBreak) p.itemTo.inMinutes];
    // Ideal points at 8:48, 17:36, 26:24, 35:12.
    expect(shows, [8, 17, 27, 35, 44]);
    expect(s.programAt(_at(18, 1)).end, _at(18, 52));
  });

  test('tuning away and back shows the same clips at the same positions', () {
    final a = schedule(BreakPlan.automatic);
    final b = schedule(BreakPlan.automatic);
    final t = _at(18, 8, 10);
    final first = a.playbackAt(t), again = b.playbackAt(t);
    expect(first.isBreak, isTrue);
    expect(again.item!.id, first.item!.id);
    expect(again.positionAt(t), first.positionAt(t));
    expect([for (final p in _segments(b, _at(18, 0), _at(18, 30))) p.item?.id],
        [for (final p in _segments(a, _at(18, 0), _at(18, 30))) p.item?.id]);
  });

  test('no clip repeats within a break while an unused one fits', () {
    final s = schedule(BreakPlan.automatic);
    final breaks = _segments(s, _at(18, 0), _at(18, 30)).where((p) => p.role == BreakRole.mid).toList();
    final firstBreak = breaks.takeWhile((p) => p.start.isBefore(breaks.first.start.add(_m(3)))).toList();
    expect(firstBreak.fold(Duration.zero, (t, p) => t + p.duration), _m(3));
    expect({for (final p in firstBreak) p.item!.id}, hasLength(firstBreak.length));
  });

  group('leftover seconds', () {
    // A 50-second post-roll of 30-second clips leaves 20 seconds.
    final thirty = [for (var i = 0; i < 4; i++) _clip('ad$i', _s(30))];
    const roles = CustomRoles(postRoll: Duration(seconds: 50));

    test('go to the station ID', () {
      final s = schedule(const BreakPlan(mode: BreakMode.custom, roles: roles), source: FixedClips(thirty));
      final ident = s.playbackAt(_at(18, 22, 40));
      expect(ident.isIdent, isTrue);
      expect(ident.role, BreakRole.fallback);
      expect((ident.start, ident.end), (_at(18, 22, 30), _at(18, 22, 50)));
      expect(ident.item, isNull);
    });

    test('or to a pool clip cut short', () {
      final bumpers = [_clip('bumper', _s(40), pools: ['bumpers'])];
      final s = schedule(
        BreakPlan(
            mode: BreakMode.custom,
            roles: roles.copyWith(fallback: FallbackKind.pool).withPool(BreakRole.fallback, 'bumpers')),
        source: FixedClips(thirty, byPool: {'bumpers': bumpers}),
      );
      final fill = s.playbackAt(_at(18, 22, 40));
      expect(fill.item!.id, 'bumper');
      expect(fill.role, BreakRole.fallback);
      expect((fill.start, fill.end), (_at(18, 22, 30), _at(18, 22, 50)));
      expect(fill.itemTo, _s(20), reason: 'the bumper, cut off after 20 seconds');
    });
  });

  test('roles draw from their own pools', () {
    final bumpers = [for (var i = 0; i < 3; i++) _clip('bumper$i', _s(15), pools: ['bumpers'])];
    final plan = BreakPlan(
      mode: BreakMode.custom,
      roles: const CustomRoles(preRoll: Duration(seconds: 15), midInterval: Duration(minutes: 10), postRoll: Duration(minutes: 1))
          .withPool(BreakRole.pre, 'bumpers')
          .withPool(BreakRole.mid, 'ads')
          .withPool(BreakRole.post, 'ads'),
    );
    final s = schedule(plan, source: FixedClips([...ads, ...bumpers], byPool: {'ads': ads, 'bumpers': bumpers}));
    final segments = _segments(s, _at(18, 0), s.programAt(_at(18, 0)).end);
    for (final p in segments.where((p) => p.isBreak && !p.isIdent)) {
      expect(p.item!.poolIds.single, p.role == BreakRole.pre ? 'bumpers' : 'ads');
    }
  });

  test('Commercial segments in a program are skipped and become breaks', () {
    // A 2-minute ad block at 8:00 in an episode; mid-rolls every 8 minutes
    // (ideal points 7:20 and 14:40), the first landing on the segment.
    const plan = BreakPlan(
        mode: BreakMode.custom, roles: CustomRoles(midInterval: Duration(minutes: 8), midLength: Duration(minutes: 1)));
    final s = schedule(plan,
        points: _Points([
          (
            DateTime(2000),
            ProgramBreakInfo(source: PointSource.segments, candidates: [_m(8)], skips: [Span(_m(8), _m(10))]),
          )
        ]));
    expect(_outline(_segments(s, _at(18, 0), _at(18, 24))),
        ['show 0-480', 'mid 180s', 'show 600-880', 'mid 60s', 'show 880-1320']);
    expect(s.programAt(_at(18, 1)).end, _at(18, 24), reason: 'the skipped 2 minutes are break time instead');
  });

  test('clips from a reel play only their range, joining partway through', () {
    final reelClips = [_clip('reel', _s(30), reel: 'reel', at: _s(47))];
    final s = schedule(BreakPlan.legacy, source: FixedClips(reelClips));
    // 22 minutes of show, then the tail from 18:22.
    final clip = s.playbackAt(_at(18, 22, 10));
    expect(clip.item!.sourceId, 'reel');
    expect(clip.start, _at(18, 22));
    expect(clip.positionAt(_at(18, 22, 10)), _s(57));
    expect(clip.itemTo, _s(77));
    expect(clip.isCommercial, isTrue);
  });

  test('a reel finishing during a break: that break plays out, new clips from the next', () {
    var now = DateTime(2000);
    final catalog = CommercialCatalog(clock: () => now)..update([_clip('old', _s(30))], null, ['ads']);
    final before = schedule(BreakPlan.automatic, source: catalog);
    List<ScheduledProgram> mids(ChannelSchedule s) =>
        _segments(s, _at(18, 0), _at(18, 30)).where((p) => p.role == BreakRole.mid).toList();
    final firstBreak = mids(before).first;
    final during = firstBreak.start.add(_s(40));

    // The reel's clips arrive mid-break.
    now = during;
    catalog.update([_clip('old', _s(30)), for (var i = 0; i < 8; i++) _clip('new$i', _s(30))], null, ['ads']);
    final after = schedule(BreakPlan.automatic, source: catalog);
    final breaksAfter = mids(after);
    final sameBreak = breaksAfter.where((p) => p.start.isBefore(firstBreak.start.add(_m(3))));
    expect(sameBreak.map((p) => p.item!.id), everyElement('old'), reason: 'the break on air plays out as scheduled');
    final laterBreak = breaksAfter.where((p) => !p.start.isBefore(firstBreak.start.add(_m(3))));
    expect(laterBreak.map((p) => p.item!.id), contains(startsWith('new')));
  });

  test('break points found while an episode airs: this airing keeps its breaks, the next uses them', () {
    final found = _at(18, 11);
    final points = _Points([
      (found, ProgramBreakInfo(source: PointSource.chapters, candidates: [_m(6), _m(13)])),
    ]);
    final s = schedule(BreakPlan.automatic, points: points);
    // Ideal points 7:20 and 14:40; the chapters at 6:00 and 13:00 are in
    // reach, but only for slots starting after they were found.
    final now = [for (final p in _segments(s, _at(18, 0), _at(18, 30))) if (!p.isBreak) p.itemTo];
    expect(now, [_m(7, 20), _m(14, 40), _m(22)]);
    final next = [for (final p in _segments(s, _at(18, 30), _at(19, 0))) if (!p.isBreak) p.itemTo];
    expect(next, [_m(6), _m(13), _m(22)]);
    // The guide is the same either way.
    expect(s.programAt(_at(18, 31)).start, _at(18, 30));
  });

  test('analysis never moves a slot in the guide', () {
    final before = schedule(BreakPlan.automatic);
    final after = schedule(BreakPlan.automatic,
        points: _Points([(DateTime(2000), ProgramBreakInfo(source: PointSource.chapters, candidates: [_m(5)]))]));
    for (var h = 0; h < 48; h++) {
      final t = _at(18, 0).add(Duration(minutes: 37 * h));
      expect(after.programAt(t).start, before.programAt(t).start);
      expect(after.programAt(t).end, before.programAt(t).end);
    }
  });

  test('a program resumed after a block continues in its slot, its break not repeated', () {
    // Automatic: Archer-e1 at 18:00–18:30 with its first break 7:35–10:35
    // into the slot. A block from 17:00 to 18:12 cuts it.
    final block = ProgramBlock(
      id: 'b',
      title: 'Cartoons',
      channelId: 'ch',
      days: {DateTime.saturday},
      startMinute: 17 * 60,
      endMinute: 18 * 60 + 12,
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: const ['Archer-e5'],
      anchor: DateTime(2026, 10, 10),
    );
    final s = schedule(BreakPlan.automatic, blocks: [block]);
    final resumed = s.programAt(_at(18, 12));
    expect(resumed.item!.id, 'Archer-e1');
    expect(resumed.start, _at(18, 12));
    expect(resumed.layoutStart, _at(18, 0));
    final first = s.playbackAt(_at(18, 12));
    expect(first.role, isNull, reason: 'back in the second show part, not the break');
    expect(first.itemFrom, _m(12) - _s(15) - _m(3));
    final rest = _segments(s, _at(18, 12), _at(18, 30));
    expect(rest.where((p) => p.role == BreakRole.mid).first.start.isAfter(_at(18, 14)), isTrue);
    // Blocks' own programs get the plan's breaks too, and lengths decide fit.
    final inBlock = s.programsBetween(_at(17, 0), _at(18, 12));
    expect(inBlock.first.duration, _m(30));
    expect(s.playbackAt(_at(17, 0, 5)).role, BreakRole.pre);
  });

  test('a block cuts its last program short, breaks and all', () {
    final block = ProgramBlock(
      id: 'b',
      title: 'Cartoons',
      channelId: 'ch',
      days: {DateTime.saturday},
      startMinute: 7 * 60,
      endMinute: 7 * 60 + 20,
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: const ['Archer-e1'],
      anchor: DateTime(2026, 10, 10),
    );
    final s = schedule(BreakPlan.automatic, blocks: [block]);
    final cut = s.programAt(_at(7, 10));
    expect((cut.start, cut.end), (_at(7, 0), _at(7, 20)));
    final last = s.playbackAt(_at(7, 19, 59));
    expect(last.end, _at(7, 20));
    expect(s.playbackAt(_at(7, 20)).blockTitle, isNull);
  });
}
