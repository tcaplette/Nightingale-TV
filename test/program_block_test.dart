import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/schedule.dart';

import 'fixtures.dart';

final _saturday = DateTime(2026, 10, 10); // a Saturday

Channel _channel(List<String> playlist, {bool blockOnly = false}) => Channel(
      id: 'ch',
      number: 2,
      name: 'Test',
      icon: const ChannelIcon.builtin('tv'),
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: playlist,
      anchor: _saturday,
      blockOnly: blockOnly,
    );

ProgramBlock _block(
  List<String> playlist, {
  Set<int> days = const {DateTime.saturday},
  int start = 7 * 60,
  int end = 8 * 60,
  DateTime? anchor,
  MonthDay? seasonStart,
  MonthDay? seasonEnd,
  String channelId = 'ch',
  String id = 'b1',
}) =>
    ProgramBlock(
      id: id,
      title: 'Saturday Morning Cartoons',
      channelId: channelId,
      days: days,
      startMinute: start,
      endMinute: end,
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: playlist,
      anchor: anchor ?? _saturday,
      seasonStart: seasonStart,
      seasonEnd: seasonEnd,
    );

DateTime _at(int hour, int minute, {int dayOffset = 0}) =>
    DateTime(_saturday.year, _saturday.month, _saturday.day + dayOffset, hour, minute);

void main() {
  final library = fakeLibrary(
    shows: {'Alpha': 10, 'Beta': 4, 'Short': 5},
    lengths: {'Short': const Duration(minutes: 11)},
  );
  final beta = ['Beta-e1', 'Beta-e2', 'Beta-e3', 'Beta-e4'];
  final alpha = [for (var i = 1; i <= 10; i++) 'Alpha-e$i'];

  group('a block on a regular channel', () {
    // Beta loops every 88 min from midnight: Beta-e4 airs 6:58–7:20.
    final schedule = ChannelSchedule.build(_channel(beta), library, [_block(alpha)])!;

    test('cuts the regular program off when the block starts', () {
      final p = schedule.programAt(_at(6, 59));
      expect(p.item!.id, 'Beta-e4');
      expect(p.start, _at(6, 58));
      expect(p.end, _at(7, 0));
      expect(p.blockTitle, isNull);
    });

    test('plays the block from its first program, and ends on time', () {
      final programs = schedule.programsBetween(_at(7, 0), _at(8, 0));
      expect([for (final p in programs) p.item!.id], ['Alpha-e1', 'Alpha-e2', 'Alpha-e3']);
      expect(programs.first.start, _at(7, 0));
      expect(programs.every((p) => p.blockTitle == 'Saturday Morning Cartoons'), isTrue);
      // Nothing else fits the last 16 minutes, so Alpha-e3 is cut at 8:00.
      expect(programs.last.start, _at(7, 44));
      expect(programs.last.end, _at(8, 0));
    });

    test('regular programming resumes in progress after the block', () {
      // Beta-e2 airs 7:42–8:04 on the regular loop.
      final p = schedule.programAt(_at(8, 1));
      expect(p.item!.id, 'Beta-e2');
      expect(p.start, _at(8, 0));
      expect(p.end, _at(8, 4));
      expect(p.slotOffset, const Duration(minutes: 18));
      expect(p.layoutStart, _at(7, 42), reason: 'still the slot it had before the block');
      expect(p.positionAt(_at(8, 1)), const Duration(minutes: 19));
    });

    test('next week picks up where this week stopped', () {
      final p = schedule.programAt(_at(7, 1, dayOffset: 7));
      // Alpha-e3 was cut short, so it airs in full this time.
      expect(p.item!.id, 'Alpha-e3');
      expect(p.start, _at(7, 0, dayOffset: 7));
      final third = schedule.programAt(_at(7, 50, dayOffset: 14));
      expect(third.item!.id, 'Alpha-e7');
    });

    test('other days are untouched', () {
      final sunday = schedule.programAt(_at(7, 30, dayOffset: 1));
      expect(sunday.blockTitle, isNull);
      expect(beta, contains(sunday.item!.id));
    });

    test('the timeline stays contiguous across a whole day', () {
      final programs = schedule.programsBetween(_at(0, 0), _at(0, 0, dayOffset: 1));
      for (var i = 1; i < programs.length; i++) {
        expect(programs[i].start, programs[i - 1].end);
        expect(programs[i].end.isAfter(programs[i].start), isTrue);
      }
    });
  });

  test('a rerun that fits fills the end of a block', () {
    final block = _block(['Short-e1', 'Alpha-e1', 'Alpha-e2', 'Alpha-e3'], end: 8 * 60 + 10);
    final schedule = ChannelSchedule.build(_channel(beta), library, [block])!;
    final programs = schedule.programsBetween(_at(7, 0), _at(8, 10));
    expect([for (final p in programs) p.item!.id],
        ['Short-e1', 'Alpha-e1', 'Alpha-e2', 'Short-e1', 'Alpha-e3']);
    expect(programs[3].start, _at(7, 55));
    expect(programs.last.end, _at(8, 10));
    // Alpha-e3 only got 4 minutes, so next week opens with it.
    expect(schedule.programAt(_at(7, 0, dayOffset: 7)).item!.id, 'Alpha-e3');
  });

  test('a block-only channel is off the air between blocks', () {
    final schedule =
        ChannelSchedule.build(_channel(const [], blockOnly: true), library, [_block(alpha)])!;
    final before = schedule.programAt(_at(6, 30));
    expect(before.isOffAir, isTrue);
    expect(before.start, _at(6, 0));
    expect(before.end, _at(7, 0));
    expect(schedule.programAt(_at(7, 30)).item!.id, 'Alpha-e2');
    final after = schedule.programAt(_at(8, 0));
    expect(after.isOffAir, isTrue);
    expect(after.end, _at(9, 0));
    expect(ChannelSchedule.build(_channel(const [], blockOnly: true), library), isNull);
  });

  test('nextBlockAiring finds the next airing, even months away', () {
    final christmas = _block(alpha,
        days: {1, 2, 3, 4, 5, 6, 7}, seasonStart: const MonthDay(12, 1), seasonEnd: const MonthDay(12, 25));
    final schedule =
        ChannelSchedule.build(_channel(const [], blockOnly: true), library, [christmas])!;
    final next = schedule.nextBlockAiring(_at(12, 0))!;
    expect(next.title, 'Saturday Morning Cartoons');
    expect(next.start, DateTime(2026, 12, 1, 7));
  });

  test('blocks can run past midnight', () {
    // Friday 11 PM to 1 AM.
    final block = _block(alpha,
        days: {DateTime.friday}, start: 23 * 60, end: 60, anchor: DateTime(2026, 10, 2));
    final schedule = ChannelSchedule.build(_channel(beta), library, [block])!;
    expect(schedule.programAt(_at(0, 30)).blockTitle, isNotNull);
    expect(schedule.programAt(_at(1, 0)).blockTitle, isNull);
    expect(block.length, const Duration(hours: 2));
  });

  test('airings before the anchor day do not happen', () {
    final block = _block(alpha, anchor: _saturday.add(const Duration(days: 7)));
    final schedule = ChannelSchedule.build(_channel(beta), library, [block])!;
    expect(schedule.programAt(_at(7, 30)).blockTitle, isNull);
    expect(schedule.programAt(_at(7, 30, dayOffset: 7)).item!.id, 'Alpha-e2');
  });

  test('disabled blocks and blocks with nothing to play are ignored', () {
    final off = _block(alpha)..enabled = false;
    expect(ChannelSchedule.build(_channel(beta), library, [off])!.blocks, isEmpty);
    expect(ChannelSchedule.build(_channel(beta), library, [_block(['gone'])])!.blocks, isEmpty);
  });

  group('seasons', () {
    final christmas = _block(alpha,
        days: {1, 2, 3, 4, 5, 6, 7},
        seasonStart: const MonthDay(12, 1),
        seasonEnd: const MonthDay(12, 25));
    final holidays = _block(alpha,
        days: {1, 2, 3, 4, 5, 6, 7},
        seasonStart: const MonthDay(12, 20),
        seasonEnd: const MonthDay(1, 5));

    test('only air inside their date range', () {
      expect(christmas.airsOn(DateTime(2026, 11, 30)), isFalse);
      expect(christmas.airsOn(DateTime(2026, 12, 1)), isTrue);
      expect(christmas.airsOn(DateTime(2026, 12, 25)), isTrue);
      expect(christmas.airsOn(DateTime(2026, 12, 26)), isFalse);
    });

    test('can wrap past New Year', () {
      expect(holidays.airsOn(DateTime(2026, 12, 31)), isTrue);
      expect(holidays.airsOn(DateTime(2027, 1, 3)), isTrue);
      expect(holidays.airsOn(DateTime(2027, 1, 6)), isFalse);
      expect(holidays.airsOn(DateTime(2026, 12, 19)), isFalse);
    });

    test('survive a JSON round trip', () {
      final copy = holidays.copy();
      expect(copy.seasonStart, const MonthDay(12, 20));
      expect(copy.seasonEnd, const MonthDay(1, 5));
      expect(copy.days, holidays.days);
    });

    test('month-day stepping wraps', () {
      expect(const MonthDay(12, 31).addDays(1), const MonthDay(1, 1));
      expect(const MonthDay(2, 28).addDays(1), const MonthDay(2, 29));
      expect(const MonthDay(1, 31).addMonths(1), const MonthDay(2, 29));
      expect(const MonthDay(12, 5).addMonths(1), const MonthDay(1, 5));
    });
  });

  group('overlap', () {
    test('same channel and time on a shared day', () {
      expect(blocksOverlap(_block(alpha), _block(alpha, id: 'b2', start: 7 * 60 + 30, end: 9 * 60)),
          isTrue);
    });

    test('different days, channels or back-to-back times do not clash', () {
      expect(blocksOverlap(_block(alpha), _block(alpha, id: 'b2', days: {DateTime.sunday})), isFalse);
      expect(blocksOverlap(_block(alpha), _block(alpha, id: 'b2', channelId: 'other')), isFalse);
      expect(blocksOverlap(_block(alpha), _block(alpha, id: 'b2', start: 8 * 60, end: 9 * 60)), isFalse);
    });

    test('a late-night block spilling into the next day clashes', () {
      final friday = _block(alpha, days: {DateTime.friday}, start: 23 * 60, end: 60);
      final saturday = _block(alpha, id: 'b2', start: 30, end: 120);
      expect(blocksOverlap(friday, saturday), isTrue);
    });

    test('blocks in different seasons do not clash', () {
      final a = _block(alpha, seasonStart: const MonthDay(12, 1), seasonEnd: const MonthDay(12, 25));
      final b = _block(alpha, id: 'b2', seasonStart: const MonthDay(6, 1), seasonEnd: const MonthDay(8, 31));
      expect(blocksOverlap(a, b), isFalse);
    });
  });

  test('describeDays', () {
    expect(describeDays({1, 2, 3, 4, 5, 6, 7}), 'Every day');
    expect(describeDays({1, 2, 3, 4, 5}), 'Weekdays');
    expect(describeDays({6, 7}), 'Weekends');
    expect(describeDays({6}), 'Sat');
    expect(describeDays({1, 3, 5}), 'Mon, Wed, Fri');
  });
}
