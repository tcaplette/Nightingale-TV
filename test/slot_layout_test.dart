import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/channels/slot_layout.dart';
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
    final role = p.isBreak ? p.role!.name : 'show';
    if (role != 'show' && out.isNotEmpty && out.last.$1 == role) {
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

  group('best fit', () {
    // 242 clips of 10–35 s, to the millisecond.
    final varied = [for (var i = 0; i < 242; i++) _clip('v$i', Duration(milliseconds: 10000 + (i * 7919) % 25000))];
    final pool = FixedClips(varied, byPool: {'ads': varied});
    final show = MediaEntry(id: 'show', kind: MediaKind.episode, title: 'Show', runtime: _m(22));
    SlotLayout layout(BreakPlan plan, {MediaEntry? item, ClipSource? source, DateTime? at}) {
      final program = item ?? show;
      return SlotLayout.build(
        item: program,
        plan: resolve(plan, program.runtime),
        layoutStart: at ?? _at(18, 0),
        info: ProgramBreakInfo.unknown,
        clips: source ?? pool,
        seed: 7,
      );
    }

    Duration total(Iterable<LayoutSegment> s) => s.fold(Duration.zero, (t, x) => t + x.length);

    /// The breaks, each its run of clips.
    List<List<LayoutSegment>> breaksOf(SlotLayout l) {
      final out = <List<LayoutSegment>>[];
      for (final (i, s) in l.segments.indexed) {
        if (s.isShow) continue;
        if (i == 0 || l.segments[i - 1].isShow) out.add([]);
        out.last.add(s);
      }
      return out;
    }

    test('a break is filled to within 1 s, and its shortfall carries to the next', () {
      const plan = BreakPlan(
          mode: BreakMode.custom,
          roles: CustomRoles(midInterval: Duration(minutes: 10), midLength: Duration(seconds: 93), postRoll: Duration(minutes: 1)));
      final l = layout(plan);
      final breaks = breaksOf(l);
      expect(breaks, hasLength(3));
      final first = total(breaks[0]), second = total(breaks[1]);
      expect(first, lessThanOrEqualTo(_s(93)));
      expect(first, greaterThan(_s(92)));
      final carried = _s(93) - first;
      expect(second, lessThanOrEqualTo(_s(93) + carried));
      expect(second, greaterThan(_s(92) + carried));
      expect(l.length, resolve(plan, show.runtime).slotLength, reason: 'the post-roll makes up the rest');
    });

    test('the show resumes early by the shortfall; the next break makes it up', () {
      // Two 59.2 s clips are the best fit for 2 minutes: 118.4 s.
      final clips = [for (var i = 0; i < 4; i++) _clip('c$i', _s(59.2))];
      const plan = BreakPlan(
          mode: BreakMode.custom, roles: CustomRoles(midInterval: Duration(minutes: 10), midLength: Duration(minutes: 2)));
      final l = layout(plan, source: FixedClips(clips));
      final shows = l.segments.where((s) => s.isShow).toList();
      final breaks = breaksOf(l);
      expect(total(breaks[0]), _s(118.4));
      expect(shows[1].from, shows[0].to + _s(118.4), reason: 'resumes 1.6 s early');
      expect(total(breaks[1]), _s(121.6), reason: 'its own 2 minutes plus 1.6 s');
      expect(l.length, _m(26), reason: 'the slot still ends on time');
      expect(shows.last.to, _m(26));
    });

    test('the last break ends the slot exactly, its last clip cut by the excess', () {
      // 30 + 17.5 = 47.5 s is the least reaching 47.3 s.
      final clips = [_clip('a', _s(30)), _clip('b', _s(17.5)), _clip('c', _s(40)), _clip('d', _s(25))];
      const plan = BreakPlan(mode: BreakMode.custom, roles: CustomRoles(postRoll: Duration(milliseconds: 47300)));
      final l = layout(plan, source: FixedClips(clips));
      final post = breaksOf(l).single;
      expect({for (final s in post) s.item!.id}, {'a', 'b'});
      expect(post.last.length, post.last.item!.runtime - _s(0.2));
      expect(l.length, _m(22) + _s(47.3));
      expect(post.last.to, l.length);
    });

    test('too few clips: one repeats, the last time cut short, and no card', () {
      final one = [_clip('only', _s(30))];
      const plan = BreakPlan(mode: BreakMode.custom, roles: CustomRoles(postRoll: Duration(seconds: 45)));
      final l = layout(plan, source: FixedClips(one));
      final post = breaksOf(l).single;
      expect([for (final s in post) s.item!.id], ['only', 'only']);
      expect([for (final s in post) s.length], [_s(30), _s(15)]);
      expect(l.segments.every((s) => s.item != null), isTrue);
    });

    test('a role whose pool has no clips draws from all pools', () {
      final plan = BreakPlan(
        mode: BreakMode.custom,
        roles: const CustomRoles(midInterval: Duration(minutes: 10), postRoll: Duration(minutes: 1))
            .withPool(BreakRole.mid, 'empty')
            .withPool(BreakRole.post, 'ads'),
      );
      final l = layout(plan, source: FixedClips(varied, byPool: {'ads': varied, 'empty': const []}));
      final mids = l.segments.where((s) => s.role == BreakRole.mid).toList();
      expect(mids, isNotEmpty);
      expect(mids.every((s) => s.item != null), isTrue);
    });

    test('every layout tiles its slot exactly, with no gaps or overlaps', () {
      for (var seconds = 60; seconds <= 150 * 60; seconds += 397) {
        final item = MediaEntry(id: 'p$seconds', kind: MediaKind.episode, title: 'P', runtime: _s(seconds));
        for (final plan in [BreakPlan.automatic, BreakPlan.legacy]) {
          final l = layout(plan, item: item, at: _at(18, 0).add(Duration(minutes: seconds)));
          final why = '$plan ${item.runtime}';
          expect(l.segments.first.from, Duration.zero, reason: why);
          for (var i = 1; i < l.segments.length; i++) {
            expect(l.segments[i].from, l.segments[i - 1].to, reason: why);
          }
          expect(l.segments.every((s) => s.length > Duration.zero), isTrue, reason: why);
          expect(l.length, resolve(plan, item.runtime).slotLength, reason: why);
          expect(total(l.segments.where((s) => s.isShow)), item.runtime, reason: why);
        }
      }
    });

    test('the same inputs give the same fill', () {
      List<(String?, Duration, Duration)> fill(SlotLayout l) => [for (final s in l.segments) (s.item?.id, s.from, s.to)];
      expect(fill(layout(BreakPlan.automatic)), fill(layout(BreakPlan.automatic)));
      expect(fill(layout(BreakPlan.automatic, at: _at(18, 30))), isNot(fill(layout(BreakPlan.automatic))),
          reason: 'another slot gets other clips');
    });

    test('no clip repeats within a slot while unused clips fit', () {
      for (final runtime in [_m(22), _m(28, 12), _m(44), _m(100)]) {
        final item = MediaEntry(id: 'r', kind: MediaKind.episode, title: 'R', runtime: runtime);
        final ids = [for (final s in layout(BreakPlan.automatic, item: item).segments) if (!s.isShow) s.item!.id];
        expect(ids.toSet(), hasLength(ids.length), reason: '$runtime');
      }
    });

    test('one BREAKFILL line per break', () {
      final lines = <String>[];
      SlotLayout.log = lines.add;
      addTearDown(() => SlotLayout.log = null);
      final l = layout(BreakPlan.automatic);
      expect(lines, hasLength(breaksOf(l).length));
      expect(lines.last, contains('post target '));
      expect(lines.last, contains('trimmed 0.'));
      expect(lines.first, contains('carried '));
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
    for (final p in segments.where((p) => p.isBreak)) {
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
