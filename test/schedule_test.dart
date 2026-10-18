import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';

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
}
