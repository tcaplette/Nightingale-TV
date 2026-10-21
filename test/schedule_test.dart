import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';

import 'fixtures.dart';

Channel _channel(List<String> playlist, DateTime anchor) => Channel(
      id: 'test',
      number: 2,
      name: 'Test',
      icon: const ChannelIcon.builtin('tv'),
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: playlist,
      anchor: anchor,
    );

void main() {
  final library = fakeLibrary(shows: {'Alpha': 3});
  final anchor = DateTime(2026, 10, 13, 18);
  final schedule =
      LoopSchedule.build(_channel(['Alpha-e1', 'Alpha-e2', 'Alpha-e3'], anchor), library)!;

  test('programAt joins mid-program with the right offset', () {
    final p = schedule.programAt(anchor.add(const Duration(minutes: 30)));
    expect(p.item!.id, 'Alpha-e2');
    expect(p.start, anchor.add(const Duration(minutes: 22)));
    expect(p.offsetAt(anchor.add(const Duration(minutes: 30))), const Duration(minutes: 8));
  });

  test('the playlist loops forever', () {
    final p = schedule.programAt(anchor.add(const Duration(minutes: 66 * 100 + 1)));
    expect(p.item!.id, 'Alpha-e1');
    expect(p.start, anchor.add(const Duration(minutes: 66 * 100)));
  });

  test('times before the anchor still resolve (negative loops)', () {
    final p = schedule.programAt(anchor.subtract(const Duration(minutes: 1)));
    expect(p.item!.id, 'Alpha-e3');
    expect(p.end, anchor);
  });

  test('programsBetween is contiguous and covers the window', () {
    final from = anchor.add(const Duration(minutes: 10));
    final to = from.add(const Duration(minutes: 90));
    final programs = ChannelSchedule.build(_channel(['Alpha-e1', 'Alpha-e2', 'Alpha-e3'], anchor), library)!
        .programsBetween(from, to);
    expect(programs.first.isOnAt(from), isTrue);
    for (var i = 1; i < programs.length; i++) {
      expect(programs[i].start, programs[i - 1].end);
    }
    expect(programs.last.end.isAfter(to) || programs.last.end == to, isTrue);
  });

  test('a saved channel reloads in local time, so the guide shows local times', () {
    final reloaded = Channel.fromJson(_channel(['Alpha-e1'], anchor).toJson());
    expect(reloaded.anchor.isUtc, isFalse);
    expect(reloaded.anchor, anchor);
    expect(LoopSchedule.build(reloaded, library)!.programAt(anchor).start.hour, anchor.hour);
  });

  test('items missing from the library are skipped; empty playlists yield null', () {
    final s = LoopSchedule.build(_channel(['gone', 'Alpha-e1'], anchor), library)!;
    expect(s.loopLength, const Duration(minutes: 22));
    expect(LoopSchedule.build(_channel(['gone'], anchor), library), isNull);
  });

  test('a music channel: song by song for playback, hour-long cells for the guide', () {
    final music = fakeLibrary(shows: const {}, songs: fakeMusic(40));
    final radio = Channel(
      id: 'auto:radio',
      number: 40,
      name: '80s Radio',
      icon: const ChannelIcon.builtin('radio'),
      source: const ChannelSource(includeEpisodes: false, includeSongs: true),
      order: PlaybackOrder.random,
      playlist: [for (final s in music.songs) s.id],
      anchor: DateTime(2026, 10, 13, 18, 7),
    );
    final s = ChannelSchedule.build(radio, music)!;
    final at = DateTime(2026, 10, 13, 19, 10);
    expect(s.programAt(at).item!.kind.name, 'song');
    expect(s.programAt(at).duration, const Duration(minutes: 3, seconds: 30));
    final cells = s.guideProgramsBetween(DateTime(2026, 10, 13, 19), DateTime(2026, 10, 13, 20, 30));
    expect([for (final c in cells) (c.start.hour, c.end.hour)], [(19, 20), (20, 21)]);
    expect(cells.map((c) => c.title), everyElement('80s Radio'));
    expect(cells.first.isMusicHour, isTrue);
    // The hour's songs, the first being the one on at the top of the hour or right after.
    expect(cells.first.songs!.first.isOnAt(DateTime(2026, 10, 13, 19)), isTrue);
    expect(cells.first.detail, cells.first.item!.guideTitle);
    expect(s.guideProgramAt(at).start, DateTime(2026, 10, 13, 19));
    // Other channels' guide cells are their programs.
    final shows = ChannelSchedule.build(_channel(['Alpha-e1', 'Alpha-e2'], anchor), library)!;
    expect(shows.guideProgramAt(anchor).item!.id, 'Alpha-e1');
  });

  test('commercials on a music channel play between songs, never inside one', () {
    final music = fakeLibrary(shows: const {}, songs: fakeMusic(20), commercials: const [Duration(seconds: 30)]);
    final radio = Channel(
      id: 'auto:radio',
      number: 40,
      name: 'Music Radio',
      icon: const ChannelIcon.builtin('radio'),
      source: const ChannelSource(includeEpisodes: false, includeSongs: true),
      order: PlaybackOrder.random,
      playlist: [for (final s in music.songs) s.id],
      anchor: DateTime(2026, 10, 13, 18),
    );
    // A plan with a mid-roll every 2 minutes.
    const plan = BreakPlan(mode: BreakMode.custom, roles: CustomRoles(midInterval: Duration(minutes: 2), midLength: Duration(seconds: 30)));
    expect(resolve(plan, const Duration(minutes: 3, seconds: 30)).midCount, 1, reason: 'a show this long would break');
    final s = ChannelSchedule.build(radio, music, const [], const BreakContext(plan: plan))!;
    final song = music.songs.first;
    final slot = s.slotPlanFor(song);
    expect(slot.midCount, 0);
    expect(slot.postRoll, const Duration(seconds: 30), reason: 'the mid-roll time airs after the song');
    expect(slot.slotLength, resolve(plan, song.runtime).slotLength, reason: 'slots keep their length');
    // Playback: the song plays whole, then the break.
    final start = s.programAt(DateTime(2026, 10, 13, 19)).start;
    final first = s.playbackAt(start);
    expect(first.isBreak, isFalse);
    expect(first.duration, song.runtime);
    expect(s.playbackAt(first.end).isBreak, isTrue);
  });
}
