import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/break_sources.dart';
import 'package:nightingale_tv/commercials/commercial_catalog.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'fixtures.dart';

final _anchor = DateTime(2026, 10, 10, 18); // a Saturday, 6 PM

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

DateTime _at(int hour, int minute, [int second = 0]) =>
    DateTime(_anchor.year, _anchor.month, _anchor.day, hour, minute, second);

/// Every playback segment from [from] until [to], following the schedule.
List<ScheduledProgram> _segments(ChannelSchedule s, DateTime from, DateTime to) {
  final result = <ScheduledProgram>[];
  var p = s.playbackAt(from);
  while (p.start.isBefore(to)) {
    result.add(p);
    p = s.playbackAt(p.end);
  }
  return result;
}

/// Breaks as they were before break plans (the plan upgrades get).
BreakContext _legacy(LibraryIndex library) => BreakContext(plan: BreakPlan.legacy, clips: FixedClips(library.commercials));

void main() {
  // 45-second ads: an 8-minute tail takes eleven, the last cut to 30 s.
  final library = fakeLibrary(
    shows: {'Alpha': 10},
    commercials: List.filled(4, const Duration(seconds: 45)),
  );
  final playlist = [for (var i = 1; i <= 10; i++) 'Alpha-e$i'];

  test('slots are padded to the next quarter hour', () {
    Duration pad(int minutes) => resolve(BreakPlan.legacy, Duration(minutes: minutes)).slotLength;
    expect(pad(22), const Duration(minutes: 30));
    expect(pad(30), const Duration(minutes: 30));
    expect(pad(31), const Duration(minutes: 45));
    expect(pad(95), const Duration(minutes: 105));
    expect(resolve(BreakPlan.off, const Duration(minutes: 22)).slotLength, const Duration(minutes: 22));
  });

  group('with the old-behavior plan', () {
    final schedule = ChannelSchedule.build(_channel(playlist), library, const [], _legacy(library))!;

    test('the guide shows half-hour slots', () {
      final p = schedule.programAt(_at(18, 25));
      expect(p.item!.id, 'Alpha-e1');
      expect(p.start, _at(18, 0));
      expect(p.end, _at(18, 30));
      expect(schedule.playbackAt(_at(18, 21)).end, _at(18, 22), reason: 'the show ends at 18:22');
      expect(schedule.programAt(_at(18, 31)).item!.id, 'Alpha-e2');
      expect(schedule.programAt(_at(18, 31)).start, _at(18, 30));
    });

    test('the show plays, then commercials to the end of the slot', () {
      final show = schedule.playbackAt(_at(18, 10));
      expect(show.item!.id, 'Alpha-e1');
      expect(show.end, _at(18, 22));

      final segments = _segments(schedule, _at(18, 22), _at(18, 30));
      expect(segments.first.start, _at(18, 22));
      for (var i = 1; i < segments.length; i++) {
        expect(segments[i].start, segments[i - 1].end);
      }
      expect(segments, hasLength(11));
      expect(segments.every((s) => s.isBreak && s.isCommercial), isTrue, reason: 'no card');
      expect(segments.first.program!.id, 'Alpha-e1', reason: 'breaks know their program');
      expect(segments.last.start, _at(18, 29, 30));
      expect(segments.last.end, _at(18, 30));
      expect(segments.last.itemTo - segments.last.itemFrom, const Duration(seconds: 30), reason: 'cut short');
      expect(schedule.playbackAt(_at(18, 30)).item!.id, 'Alpha-e2');
    });

    test('a break plays the same ads every time it is worked out', () {
      final again = ChannelSchedule.build(_channel(playlist), library, const [], _legacy(library))!;
      List<String?> ids(ChannelSchedule s) =>
          [for (final p in _segments(s, _at(18, 22), _at(18, 30))) p.item?.id];
      expect(ids(again), ids(schedule));
    });

    test('ads are never part of the regular programming', () {
      final mixed = ChannelSchedule.build(_channel(['ad-1', ...playlist]), library)!;
      expect(mixed.programAt(_at(18, 1)).item!.id, 'Alpha-e1');
    });

    test('programming blocks get breaks too, and still continue week to week', () {
      final block = ProgramBlock(
        id: 'b',
        title: 'Cartoons',
        channelId: 'ch',
        days: {DateTime.saturday},
        startMinute: 7 * 60,
        endMinute: 8 * 60,
        source: const ChannelSource(),
        order: PlaybackOrder.cyclic,
        playlist: playlist,
        anchor: DateTime(2026, 10, 10),
      );
      final s = ChannelSchedule.build(_channel(playlist), library, [block], _legacy(library))!;
      final programs = s.programsBetween(_at(7, 0), _at(8, 0));
      expect([for (final p in programs) p.item!.id], ['Alpha-e1', 'Alpha-e2']);
      expect(programs[1].start, _at(7, 30));
      expect(s.playbackAt(_at(7, 51)).end, _at(7, 52));
      expect(s.playbackAt(_at(7, 55)).isCommercial, isTrue);
      expect(s.programAt(DateTime(2026, 10, 17, 7, 1)).item!.id, 'Alpha-e3');
    });
  });

  test('Automatic: a show just under the half hour keeps the half hour, its ads shrunk to fit', () {
    // Californication: 28.2 minutes.
    final cali = fakeLibrary(
      shows: {'Cali': 4},
      episodeLength: const Duration(minutes: 28, seconds: 12),
      commercials: [for (var i = 0; i < 40; i++) Duration(milliseconds: 10000 + (i * 7919) % 25000)],
    );
    final s = ChannelSchedule.build(_channel([for (var i = 1; i <= 4; i++) 'Cali-e$i']), cali, const [],
        BreakContext(plan: BreakPlan.automatic, clips: FixedClips(cali.commercials)))!;
    final slot = s.programAt(_at(18, 5));
    expect((slot.start, slot.end), (_at(18, 0), _at(18, 30)));
    expect(s.programAt(_at(18, 31)).item!.id, 'Cali-e2');
    expect(s.programAt(_at(18, 31)).start, _at(18, 30), reason: 'the next program starts on the half hour');
    final segments = _segments(s, _at(18, 0), _at(18, 30));
    for (var i = 1; i < segments.length; i++) {
      expect(segments[i].start, segments[i - 1].end);
    }
    expect(segments.last.end, _at(18, 30));
    expect(segments.every((p) => p.item != null), isTrue, reason: 'no card');
    expect(s.playbackAt(_at(18, 30)).start, _at(18, 30));
  });

  test('without commercials nothing is padded', () {
    final s = ChannelSchedule.build(_channel(playlist), library)!;
    expect(s.hasBreaks, isFalse);
    final p = s.programAt(_at(18, 25));
    expect(p.item!.id, 'Alpha-e2');
    expect(p.start, _at(18, 22));
    expect(s.playbackAt(_at(18, 25)).end, p.end);
  });

  test('pools keep everything 5 seconds or longer; only clip-length videos are clips until split', () {
    final lib = fakeLibrary(
      shows: {'Alpha': 1},
      commercials: const [Duration(seconds: 3), Duration(seconds: 30), Duration(hours: 2)],
    );
    expect([for (final c in lib.commercials) c.id], ['ad-2', 'ad-3']);
    expect(lib.commercials.every((c) => c.kind == MediaKind.commercial), isTrue);
    expect(lib.commercials.first.subtitle, 'Commercial');
    final reloaded = LibraryIndex.fromJson(lib.toJson());
    expect(reloaded['ad-3']!.runtime, const Duration(hours: 2));
    final catalog = CommercialCatalog()..update(reloaded.commercials, null, const [fakePoolId]);
    expect([for (final c in catalog.clipsFor(null)) c.id], ['ad-2'], reason: 'the reel waits for analysis');
  });
}
