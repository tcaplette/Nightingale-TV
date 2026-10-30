import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/break_notices.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/analysis/break_points.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/break_sources.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_schedule.dart';

import 'fixtures.dart';

final _anchor = DateTime(2026, 10, 10, 18); // a Saturday, 6 PM
final _saturday = DateTime(2026, 10, 10); // blocks start counting at midnight

Duration _s(num s) => Duration(milliseconds: (s * 1000).round());
Duration _m(int m, [num s = 0]) => Duration(minutes: m) + _s(s);
DateTime _at(int hour, int minute, [num second = 0]) =>
    DateTime(_anchor.year, _anchor.month, _anchor.day, hour, minute).add(_s(second));

Channel _channel(List<String> playlist, {bool blockOnly = false}) => Channel(
      id: 'ch',
      number: 2,
      name: 'Test',
      icon: const ChannelIcon.builtin('tv'),
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: playlist,
      anchor: _anchor,
      blockOnly: blockOnly,
    );

MediaEntry _clip(String id, Duration length) =>
    MediaEntry(id: id, kind: MediaKind.commercial, title: id, runtime: length, poolIds: const ['ads']);

class _Points implements BreakPointSource {
  const _Points(this.info);

  final ProgramBreakInfo info;

  @override
  ProgramBreakInfo pointsFor(MediaEntry program, DateTime asOf) => info;
}

/// A schedule of fixed segments, for parts and runs the plans don't make.
class _Fixed implements ProgramSchedule {
  _Fixed(this.segments);

  final List<ScheduledProgram> segments;

  @override
  ScheduledProgram playbackAt(DateTime t) => segments.firstWhere((p) => p.isOnAt(t),
      orElse: () => ScheduledProgram(item: null, start: t, end: t.add(const Duration(hours: 1))));

  @override
  ScheduledProgram programAt(DateTime t) => playbackAt(t);

  @override
  bool get hasBreaks => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final library = fakeLibrary(shows: {'Archer': 10}); // 22-minute episodes
  final playlist = [for (var i = 1; i <= 10; i++) 'Archer-e$i'];
  final ads = [for (var i = 0; i < 12; i++) _clip('ad$i', _s(30)), for (var i = 0; i < 4; i++) _clip('short$i', _s(15))];
  final clips = FixedClips(ads, byPool: {'ads': ads});
  // Chapters at 7:10 and 14:40. Each half hour:
  //   pre 0:00–0:15, show –7:25, mid –10:25, show –17:55, mid –20:55,
  //   show –28:15, post –30:00.
  final points = _Points(ProgramBreakInfo(source: PointSource.chapters, candidates: [_m(7, 10), _m(14, 40)]));
  final breaks = BreakContext(plan: BreakPlan.automatic, clips: clips, points: points);
  final schedule = ChannelSchedule.build(_channel(playlist), library, const [], breaks)!;

  test('the layout the tests use', () {
    expect(schedule.playbackAt(_at(18, 7)).end, _at(18, 7, 25));
    expect(schedule.playbackAt(_at(18, 7, 25)).role, BreakRole.mid);
    expect(schedule.playbackAt(_at(18, 10, 24)).end, _at(18, 10, 25), reason: 'each clip is a segment');
    expect(schedule.playbackAt(_at(18, 29)).role, BreakRole.post);
    expect(schedule.playbackAt(_at(18, 30)).role, BreakRole.pre);
    expect(schedule.playbackAt(_at(18, 30)).end, _at(18, 30, 15));
  });

  test('a mid-roll counts down from 10 seconds out, and is gone at the cut', () {
    expect(breakNoticeAt(schedule, _at(18, 7, 14.9)), isNull);
    for (var left = 10; left >= 1; left--) {
      final n = breakNoticeAt(schedule, _at(18, 7, 25 - left))!;
      expect(n.kind, BreakNoticeKind.breakStarts);
      expect(n.at, _at(18, 7, 25));
      expect(n.resumes, isNull);
    }
    expect(breakNoticeAt(schedule, _at(18, 7, 24.999))!.at, _at(18, 7, 25));
    expect(breakNoticeAt(schedule, _at(18, 7, 25)), isNull, reason: 'the break has started');
    expect(breakNoticeAt(schedule, _at(18, 8)), isNull);
  });

  test('tuning in mid-countdown gives the notice at once', () {
    final n = breakNoticeAt(schedule, _at(18, 7, 21))!;
    expect(n.kind, BreakNoticeKind.breakStarts);
    expect(n.at.difference(_at(18, 7, 21)), _s(4));
  });

  test('after a mid-roll: "Back to" the same show, for the last 5 seconds', () {
    expect(breakNoticeAt(schedule, _at(18, 10, 19.9)), isNull);
    for (var left = 5; left >= 1; left--) {
      final n = breakNoticeAt(schedule, _at(18, 10, 25 - left))!;
      expect(n.kind, BreakNoticeKind.resumes);
      expect(n.at, _at(18, 10, 25));
      expect(n.continues, isTrue);
      expect(n.resumes!.item!.id, 'Archer-e1');
      expect(n.opensBlock, isNull);
    }
    expect(breakNoticeAt(schedule, _at(18, 10, 25)), isNull, reason: 'the show is back');
  });

  test('the end of a program: a break notice, then one notice for post-roll and pre-roll together', () {
    final n = breakNoticeAt(schedule, _at(18, 28, 6))!;
    expect(n.kind, BreakNoticeKind.breakStarts);
    expect(n.at, _at(18, 28, 15));
    // Not at the end of the post-roll alone.
    for (final t in [_at(18, 29, 55), _at(18, 29, 59.9), _at(18, 30), _at(18, 30, 9.9)]) {
      expect(breakNoticeAt(schedule, t), isNull, reason: '$t');
    }
    final up = breakNoticeAt(schedule, _at(18, 30, 10))!;
    expect(up.kind, BreakNoticeKind.resumes);
    expect(up.at, _at(18, 30, 15));
    expect(up.continues, isFalse);
    expect(up.resumes!.item!.id, 'Archer-e2');
    expect(up.opensBlock, isNull);
  });

  test('"Up next" names the block a program opens', () {
    final block = ProgramBlock(
      id: 'b1',
      title: 'Saturday Night Archer',
      channelId: 'ch',
      days: const {DateTime.saturday},
      startMinute: 19 * 60,
      endMinute: 20 * 60,
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: playlist.reversed.toList(),
      anchor: _saturday,
    );
    final s = ChannelSchedule.build(_channel(playlist), library, [block], breaks)!;
    final opens = breakNoticeAt(s, _at(19, 0, 12))!;
    expect(opens.kind, BreakNoticeKind.resumes);
    expect(opens.resumes!.blockTitle, 'Saturday Night Archer');
    expect(opens.opensBlock, 'Saturday Night Archer');
    // Inside the block, the next program doesn't open it.
    final inside = breakNoticeAt(s, _at(19, 30, 12))!;
    expect(inside.resumes!.blockTitle, 'Saturday Night Archer');
    expect(inside.opensBlock, isNull);
    // After a mid-roll in the block: back to the show.
    final back = breakNoticeAt(s, _at(19, 10, 22))!;
    expect(back.continues, isTrue);
    expect(back.opensBlock, isNull);
  });

  test('a show part under 10 seconds gets the notice from its start', () {
    final show = library['Archer-e1']!;
    final t0 = _at(18, 0);
    final s = _Fixed([
      ScheduledProgram(item: show, start: t0, end: t0.add(_s(6))),
      ScheduledProgram(item: ads[0], start: t0.add(_s(6)), end: t0.add(_s(36)), role: BreakRole.mid, program: show),
    ]);
    expect(breakNoticeAt(s, t0)!.at, t0.add(_s(6)));
    expect(breakNoticeAt(s, t0)!.kind, BreakNoticeKind.breakStarts);
  });

  test('a run under 5 seconds gets the resume notice from its start', () {
    final show = library['Archer-e1']!;
    final t0 = _at(18, 0);
    final s = _Fixed([
      ScheduledProgram(item: show, start: t0, end: t0.add(_s(60))),
      ScheduledProgram(
          item: ads[0], start: t0.add(_s(60)), end: t0.add(_s(63)), layoutStart: t0, role: BreakRole.mid, program: show),
      ScheduledProgram(item: show, start: t0.add(_s(63)), end: t0.add(_s(600)), layoutStart: t0),
    ]);
    final n = breakNoticeAt(s, t0.add(_s(60)))!;
    expect(n.kind, BreakNoticeKind.resumes);
    expect(n.at, t0.add(_s(63)));
    expect(n.continues, isTrue);
  });

  test('a break plan that never ends gives no resume notice', () {
    final show = library['Archer-e1']!;
    final t0 = _at(18, 0);
    final s = _Fixed([
      for (var i = 0; i < 300; i++)
        ScheduledProgram(
            item: ads[0], start: t0.add(_s(30 * i)), end: t0.add(_s(30 * i + 30)), role: BreakRole.mid, program: show),
    ]);
    expect(breakNoticeAt(s, t0.add(_s(30 * 299 + 28))), isNull);
  });

  group('off the air', () {
    final block = ProgramBlock(
      id: 'b1',
      title: 'Archer Hour',
      channelId: 'ch',
      days: const {DateTime.saturday},
      startMinute: 19 * 60,
      endMinute: 20 * 60,
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: playlist,
      anchor: _saturday,
    );
    final s = ChannelSchedule.build(_channel(const [], blockOnly: true), library, [block], breaks)!;

    test('no resume notice before off air', () {
      expect(s.playbackAt(_at(19, 59)).role, BreakRole.post);
      expect(s.playbackAt(_at(20, 0)).isOffAir, isTrue);
      expect(breakNoticeAt(s, _at(19, 59, 57)), isNull);
      expect(breakNoticeAt(s, _at(20, 0, 30)), isNull);
      // The last show part still warns of its post-roll.
      expect(breakNoticeAt(s, _at(19, 58, 10))!.kind, BreakNoticeKind.breakStarts);
    });

    test('a run after off air: no break notice, but a resume notice at its end', () {
      expect(breakNoticeAt(s, _at(18, 59, 55)), isNull);
      expect(breakNoticeAt(s, _at(19, 0, 5)), isNull);
      final n = breakNoticeAt(s, _at(19, 0, 11))!;
      expect(n.kind, BreakNoticeKind.resumes);
      expect(n.at, _at(19, 0, 15));
      expect(n.continues, isFalse);
      expect(n.opensBlock, 'Archer Hour', reason: 'off the air before it');
    });
  });

  test('breaks Off: never a notice', () {
    final off = ChannelSchedule.build(_channel(playlist), library, const [], const BreakContext(plan: BreakPlan.off))!;
    for (var t = _at(18, 0); t.isBefore(_at(19, 0)); t = t.add(_s(1))) {
      expect(breakNoticeAt(off, t), isNull, reason: '$t');
    }
  });

  test('music channels: never a notice', () {
    final music = fakeLibrary(shows: const {}, songs: fakeMusic(20));
    final radio = Channel(
      id: 'auto:radio',
      number: 40,
      name: 'Music Radio',
      icon: const ChannelIcon.builtin('radio'),
      source: const ChannelSource(includeEpisodes: false, includeSongs: true),
      order: PlaybackOrder.random,
      playlist: [for (final s in music.songs) s.id],
      anchor: _anchor,
    );
    final s = ChannelSchedule.build(radio, music, const [],
        BreakContext(plan: BreakPlan.automatic, clips: clips))!;
    expect(s.hasBreaks, isTrue);
    var sawBreak = false;
    for (var t = _at(18, 0); t.isBefore(_at(19, 0)); t = t.add(_s(1))) {
      sawBreak |= s.playbackAt(t).isBreak;
      expect(breakNoticeAt(s, t), isNull, reason: '$t');
    }
    expect(sawBreak, isTrue, reason: 'the channel has breaks, yet no notices');
  });

  test('live channels: never a notice', () {
    final live = LiveSchedule(channelId: 'live:1', channelName: 'News', programmes: [
      LiveProgramme(title: 'News', start: _at(18, 0), end: _at(18, 30)),
      LiveProgramme(title: 'Weather', start: _at(18, 30), end: _at(19, 0)),
    ]);
    expect(breakNoticeAt(live, _at(18, 29, 55)), isNull);
  });
}
