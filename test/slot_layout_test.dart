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

/// [p] with no tail: a Custom plan's breaks alone.
SlotPlan _withoutTail(SlotPlan p) => SlotPlan(
    runtime: p.runtime,
    preRoll: p.preRoll,
    midCount: p.midCount,
    midLength: p.midLength,
    postRoll: p.postRoll,
    tail: Duration.zero,
    roles: p.roles);

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
    // 52 minutes, padded to the half hour.
    expect(s.programAt(_at(18, 1)).end, _at(19, 0));
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
    // Custom plans always pad to the clock; these tests are about the
    // breaks, so they lay the slot out without its tail unless [tail].
    SlotLayout layout(BreakPlan plan, {MediaEntry? item, ClipSource? source, DateTime? at, bool tail = false}) {
      final program = item ?? show;
      final slot = resolve(plan, program.runtime);
      return SlotLayout.build(
        item: program,
        plan: tail ? slot : _withoutTail(slot),
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
      expect(l.length, _withoutTail(resolve(plan, show.runtime)).slotLength, reason: 'the post-roll makes up the rest');
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
          final l = layout(plan, item: item, at: _at(18, 0).add(Duration(minutes: seconds)), tail: true);
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

    group('bumpers', () {
      final idents = [for (var i = 0; i < 4; i++) _clip('ident$i', _s(10), pools: ['idents'])];
      FixedClips framed(List<MediaEntry> bumpers, {Map<String, List<MediaEntry>> byPool = const {}}) =>
          FixedClips(varied, byPool: {'ads': varied}, bumpers: bumpers, bumpersByPool: byPool);
      bool isBumper(LayoutSegment s) => s.item?.id.startsWith('ident') ?? false;
      BreakPlan custom(CustomRoles roles) => BreakPlan(mode: BreakMode.custom, roles: roles);
      const midAndPost = CustomRoles(
          preRoll: Duration(seconds: 30), midInterval: Duration(minutes: 10), postRoll: Duration(minutes: 1));

      test('no bumper pool: the layout is what it always was', () {
        for (final plan in [BreakPlan.automatic, BreakPlan.legacy, custom(midAndPost)]) {
          final plain = layout(plan), none = layout(plan, source: framed(const []));
          expect([for (final s in none.segments) (s.from, s.to, s.item?.id)],
              [for (final s in plain.segments) (s.from, s.to, s.item?.id)]);
        }
      });

      test('mid-rolls open and close, post-rolls open, pre-rolls close', () {
        final l = layout(custom(midAndPost), source: framed(idents));
        final breaks = breaksOf(l);
        for (final b in breaks) {
          final role = b.first.role!;
          expect(isBumper(b.first), role != BreakRole.pre, reason: '$role opening');
          expect(isBumper(b.last), role != BreakRole.post, reason: '$role closing');
          expect(b.where(isBumper), hasLength(role == BreakRole.mid ? 2 : 1), reason: '$role');
          expect(b.where((s) => !isBumper(s)), isNotEmpty, reason: 'commercials between');
        }
        for (final b in breaks.where((b) => b.first.role == BreakRole.mid)) {
          expect(b.first.item!.id, isNot(b.last.item!.id), reason: 'a close differs from its open');
        }
      });

      test('a tail holds only commercials', () {
        final l = layout(custom(const CustomRoles()), source: framed(idents), tail: true);
        expect(l.segments.where((s) => s.role == BreakRole.tail), isNotEmpty);
        expect(l.segments.where(isBumper), isEmpty);
      });

      test('room for one in a mid-roll: it closes, and commercials fill the rest', () {
        final l = layout(custom(const CustomRoles(midInterval: Duration(minutes: 10), midLength: Duration(seconds: 30))),
            source: framed(idents));
        for (final b in breaksOf(l)) {
          expect(isBumper(b.last), isTrue);
          expect(b.where(isBumper), hasLength(1));
        }
      });

      test('bumpers over half a mid-roll are skipped; a pre-roll\'s may fill it', () {
        final long = [_clip('ident-long', _s(20), pools: ['idents'])];
        final l = layout(custom(const CustomRoles(midInterval: Duration(minutes: 10), midLength: Duration(seconds: 30))),
            source: framed(long));
        expect(l.segments.where(isBumper), isEmpty);
        final pre = layout(custom(const CustomRoles(preRoll: Duration(seconds: 15))),
            source: framed([_clip('ident-15', _s(15), pools: ['idents'])]));
        expect(breaksOf(pre).single.map((s) => s.item!.id), ['ident-15']);
      });

      test('a bumper too long for the pre-roll: commercials only, and the program starts on time', () {
        const plan = CustomRoles(preRoll: Duration(seconds: 15));
        final l = layout(custom(plan), source: framed([_clip('ident-long', _s(30), pools: ['idents'])]));
        expect(l.segments.where(isBumper), isEmpty);
        expect(l.length, layout(custom(plan)).length);
      });

      test('one station ident opens and closes every mid-roll', () {
        final one = [_clip('ident', _s(5), pools: ['idents'])];
        final l = layout(custom(const CustomRoles(midInterval: Duration(minutes: 10))), source: framed(one));
        final breaks = breaksOf(l);
        expect(breaks, isNotEmpty);
        for (final b in breaks) {
          expect((b.first.item!.id, b.last.item!.id), ('ident', 'ident'));
        }
      });

      test('no commercials, no bumpers', () {
        final l = layout(custom(midAndPost), source: FixedClips(const [], bumpers: idents));
        expect(l.segments.where(isBumper), isEmpty);
      });

      test('commercials too long to fit: no bumpers around nothing', () {
        final longAds = [_clip('long', _m(2))];
        final l = layout(custom(const CustomRoles(midInterval: Duration(minutes: 10), midLength: Duration(seconds: 30),
                postRoll: Duration(minutes: 5))),
            source: FixedClips(longAds, bumpers: idents));
        final mids = l.segments.where((s) => s.role == BreakRole.mid);
        expect(mids.where(isBumper), isEmpty);
      });

      test('None gives no bumpers; a picked pool gives only its own, or all when it has none', () {
        final mine = [_clip('ident-mine', _s(5), pools: ['mine'])];
        final source = framed(idents, byPool: {'mine': mine, 'empty': const []});
        expect(layout(custom(midAndPost.withBumpers(null, none: true)), source: source).segments.where(isBumper), isEmpty);
        final picked = layout(custom(midAndPost.withBumpers('mine')), source: source).segments.where(isBumper);
        expect(picked.map((s) => s.item!.id).toSet(), {'ident-mine'});
        expect(layout(custom(midAndPost.withBumpers('empty')), source: source).segments.where(isBumper), isNotEmpty);
      });

      test('slots keep their length, tile exactly, and rebuild the same', () {
        for (final plan in [BreakPlan.automatic, BreakPlan.legacy, custom(midAndPost)]) {
          final plain = layout(plan), l = layout(plan, source: framed(idents));
          expect(l.length, plain.length);
          for (var i = 1; i < l.segments.length; i++) {
            expect(l.segments[i].from, l.segments[i - 1].to);
          }
          final again = layout(plan, source: framed(idents));
          expect([for (final s in again.segments) (s.from, s.to, s.item?.id)],
              [for (final s in l.segments) (s.from, s.to, s.item?.id)]);
          expect(total(l.segments.where((s) => s.isShow)), _m(22));
        }
      });

      test('the commercials\' shuffle isn\'t the bumpers\'', () {
        // With the same seed and bag the two orders would match.
        final same = [for (var i = 0; i < 8; i++) _clip('ident$i', _s(5), pools: ['idents'])];
        final ids = <String>{};
        for (var m = 0; m < 12; m++) {
          final l = layout(custom(const CustomRoles(preRoll: Duration(seconds: 15))),
              source: FixedClips(same, bumpers: same), at: _at(18, 0).add(Duration(minutes: m)));
          final b = breaksOf(l).single;
          ids.add(b.last.item!.id);
        }
        expect(ids.length, greaterThan(1), reason: 'the pick changes with the break');
      });

      test('a last mid-roll cuts its last commercial, and the closing bumper plays whole', () {
        // No post-roll: the last mid-roll is the slot's last break.
        const plan = CustomRoles(midInterval: Duration(minutes: 10), midLength: Duration(milliseconds: 60300));
        final ads = [_clip('a', _s(15)), _clip('b', _s(16)), _clip('c', _s(17)), _clip('d', _s(18)), _clip('e', _s(19))];
        final l = layout(custom(plan), source: FixedClips(ads, bumpers: [_clip('ident', _s(10), pools: ['idents'])]));
        expect(l.segments.last.isShow, isTrue);
        final last = breaksOf(l).last;
        expect(last.last.item!.id, 'ident');
        expect(last.last.length, _s(10));
        expect(total(last), greaterThan(Duration.zero));
        expect(l.length, _withoutTail(resolve(custom(plan), show.runtime)).slotLength);
      });

      test('a post-roll that ends the slot still ends it exactly', () {
        const plan = CustomRoles(postRoll: Duration(milliseconds: 47300));
        final l = layout(custom(plan), source: framed(idents));
        final post = breaksOf(l).single;
        expect(isBumper(post.first), isTrue);
        expect(post.first.length, _s(10));
        expect(post.last.to, l.length);
        expect(l.length, _m(22) + _s(47.3));
      });

      test('Truncate cuts whatever crosses the slot\'s end, even a bumper', () {
        final base = resolve(custom(const CustomRoles(preRoll: Duration(seconds: 15))), show.runtime);
        final cut = base.withRule(length: _s(10), offline: false, truncate: true);
        final l = SlotLayout.build(
          item: show,
          plan: cut,
          layoutStart: _at(18, 0),
          info: ProgramBreakInfo.unknown,
          clips: FixedClips(varied, bumpers: [_clip('ident', _s(15), pools: ['idents'])]),
          seed: 7,
        );
        expect(l.length, _s(10));
        expect(l.segments.last.to, _s(10));
      });

      test('the BREAKFILL line counts them', () {
        final lines = <String>[];
        SlotLayout.log = lines.add;
        addTearDown(() => SlotLayout.log = null);
        layout(custom(const CustomRoles(midInterval: Duration(minutes: 10))), source: framed(idents));
        expect(lines.first, endsWith('bumpers 1+1'));
      });
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
          .withPool(BreakRole.post, 'ads')
          .withPool(BreakRole.tail, 'ads'),
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
    expect(_outline(_segments(s, _at(18, 0), _at(18, 30))),
        ['show 0-480', 'mid 180s', 'show 600-880', 'mid 60s', 'show 880-1320', 'tail 360s'],
        reason: 'the skipped 2 minutes are break time instead');
    expect(s.programAt(_at(18, 1)).end, _at(18, 30));
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

  test('with a slot length, a program resumed after a block continues in its slot, its break not repeated', () {
    // Automatic in 30-minute slots: Archer-e1 at 18:00–18:30 with its first
    // break 7:35–10:35 into the slot. A block from 17:00 to 18:12 cuts it.
    // (Without a slot length, the loop meets blocks on whole programs.)
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
    final s = ChannelSchedule.build(_channel(playlist), library, [block],
        BreakContext(plan: BreakPlan.automatic, clips: clips, slotRule: const SlotRule(length: Duration(minutes: 30))))!;
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

  group('slot length and tails (slot-duration)', () {
    ChannelSchedule ruled(SlotRule? rule, {BreakPlan plan = BreakPlan.off, ClipSource? source, LibraryIndex? lib, List<String>? items}) =>
        ChannelSchedule.build(_channel(items ?? playlist), lib ?? library, const [],
            BreakContext(plan: plan, clips: source ?? clips, slotRule: rule))!;
    // A 100-minute movie and a 22-minute episode.
    final movies = fakeLibrary(shows: {'Archer': 2}, movies: 1, lengths: {});
    final movieLib = LibraryIndex(
      series: movies.series,
      episodes: movies.episodes,
      movies: [
        MediaEntry(id: 'movie-1', kind: MediaKind.movie, title: 'Movie', runtime: _m(100)),
      ],
      fetchedAt: DateTime(2026),
    );

    /// Checks the slot at [t] lays out with no gaps, ending exactly at its end.
    void gapless(ChannelSchedule s, DateTime t) {
      final slot = s.programAt(t);
      final segments = _segments(s, slot.start, slot.end);
      expect(segments.first.start, slot.start);
      for (var i = 1; i < segments.length; i++) {
        expect(segments[i].start, segments[i - 1].end, reason: 'no gap before segment $i');
      }
      expect(segments.last.end, slot.end);
    }

    test('22-minute episodes in 30-minute filler slots: 8 minutes of filler, every slot on the half hour', () {
      final s = ruled(const SlotRule(length: Duration(minutes: 30)));
      for (final p in s.programsBetween(_at(18, 0), _at(21, 0))) {
        expect(p.start.minute % 30, 0);
        expect(p.duration, _m(30));
      }
      expect(_outline(_segments(s, _at(18, 0), _at(18, 30))), ['show 0-1320', 'tail 480s']);
      gapless(s, _at(18, 10));
    });

    test('a 100-minute movie in 60-minute offline slots: 120 minutes, the last 20 the offline card', () {
      final s = ruled(const SlotRule(length: Duration(minutes: 60), tail: TailMode.offline),
          lib: movieLib, items: ['movie-1']);
      final slot = s.programAt(_at(18, 30));
      expect(slot.duration, _m(120));
      final tail = s.playbackAt(_at(19, 50));
      expect(tail.item, isNull);
      expect(tail.offline, isTrue);
      expect(tail.isOffAir, isFalse);
      expect(tail.start, _at(19, 40));
      expect(tail.end, _at(20, 0));
      expect(slot.endsEarly, isFalse);
      gapless(s, _at(18, 30));
    });

    test('Truncate cuts the movie at 60 minutes and the next program starts on time', () {
      final s = ruled(const SlotRule(length: Duration(minutes: 60), tail: TailMode.truncate),
          lib: movieLib, items: ['movie-1', 'Archer-e1']);
      final slot = s.programAt(_at(18, 30));
      expect(slot.item!.id, 'movie-1');
      expect(slot.duration, _m(60));
      expect(slot.endsEarly, isTrue);
      final last = s.playbackAt(_at(18, 59, 59));
      expect(last.item!.id, 'movie-1');
      expect(last.itemTo, _m(60));
      expect(last.endsEarly, isTrue);
      final next = s.playbackAt(_at(19, 0));
      expect(next.item!.id, 'Archer-e1');
      expect(next.start, _at(19, 0));
      // The short one is padded with filler to the hour.
      expect(_outline(_segments(s, _at(19, 0), _at(20, 0))), ['show 0-1320', 'tail 2280s']);
    });

    test('Truncate with breaks: the layout is cut at the slot end, the crossing segment trimmed', () {
      final s = ruled(const SlotRule(length: Duration(minutes: 60), tail: TailMode.truncate),
          plan: BreakPlan.automatic, lib: movieLib, items: ['movie-1']);
      final slot = s.programAt(_at(18, 0));
      expect(slot.duration, _m(60));
      final segments = _segments(s, slot.start, slot.end);
      expect(segments.last.end, slot.end);
      expect(segments.any((p) => p.role == BreakRole.post), isFalse, reason: 'the post-roll falls after the cut');
      gapless(s, _at(18, 10));
    });

    test('a cut that only shortens the post-roll does not end the program early', () {
      final plan = resolve(const BreakPlan(mode: BreakMode.custom, roles: CustomRoles(postRoll: Duration(minutes: 5))),
          _m(28));
      final cut = plan.withRule(length: _m(30), offline: false, truncate: true);
      expect(cut.slotLength, _m(30));
      expect(cut.endsEarly, isFalse);
      expect(resolve(BreakPlan.off, _m(40)).withRule(length: _m(30), offline: false, truncate: true).endsEarly, isTrue);
    });

    test('break plans still place pre-, mid- and post-rolls; the rule replaces their tail', () {
      final s = ruled(const SlotRule(length: Duration(minutes: 60)),
          plan: const BreakPlan(
              mode: BreakMode.custom,
              roles: CustomRoles(
                  preRoll: Duration(seconds: 30), postRoll: Duration(minutes: 1), tailGrid: Duration(minutes: 15))));
      final slot = s.programAt(_at(18, 0));
      expect(slot.duration, _m(60), reason: '22 + 1.5 minutes rounded up to the hour, not to the quarter');
      final outline = _outline(_segments(s, slot.start, slot.end));
      expect(outline.first, 'pre 30s');
      expect(outline, contains('post 60s'));
      expect(outline.last, 'tail ${(60 - 22) * 60 - 90}s');
    });

    test('a filler tail with an empty pool shows the offline card', () {
      final s = ruled(const SlotRule(length: Duration(minutes: 30), poolId: 'empty'),
          source: const FixedClips([], byPool: {}));
      final tail = s.playbackAt(_at(18, 25));
      expect(tail.item, isNull);
      expect(tail.offline, isTrue);
      expect(tail.start, _at(18, 22));
      expect(tail.end, _at(18, 30));
    });

    test('Off gives the same guide as no rule at all', () {
      final plain = ChannelSchedule.build(
          _channel(playlist), library, const [], BreakContext(plan: BreakPlan.automatic, clips: clips))!;
      final off = ruled(null, plan: BreakPlan.automatic);
      String guide(ChannelSchedule s) => [
            for (final p in s.programsBetween(_at(18, 0), _at(23, 0))) '${p.item?.id} ${p.start} ${p.end}',
          ].join('\n');
      expect(guide(off), guide(plain));
    });

    test('programming blocks keep their own layout', () {
      final block = ProgramBlock(
        id: 'b',
        title: 'Block',
        channelId: 'ch',
        days: {for (var d = 1; d <= 7; d++) d},
        startMinute: 20 * 60,
        endMinute: 21 * 60,
        source: const ChannelSource(),
        order: PlaybackOrder.cyclic,
        playlist: playlist,
        anchor: DateTime(2026, 10, 1),
      );
      final s = ChannelSchedule.build(_channel(playlist), library, [block],
          BreakContext(plan: BreakPlan.off, clips: clips, slotRule: const SlotRule(length: Duration(minutes: 30))))!;
      final inBlock = s.programAt(_at(20, 5));
      expect(inBlock.blockTitle, 'Block');
      expect(inBlock.duration, _m(22));
    });
  });
}
