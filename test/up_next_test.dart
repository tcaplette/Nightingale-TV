import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

import 'fixtures.dart';

void main() {
  final library = fakeLibrary(shows: {'Alpha': 2, 'Short': 1}, lengths: {'Short': const Duration(minutes: 3)});
  final start = DateTime(2026, 10, 10, 7);
  final show = ScheduledProgram(item: library['Alpha-e1'], start: start, end: start.add(const Duration(minutes: 22)));
  final next = ScheduledProgram(
      item: library['Alpha-e2'], start: show.end, end: show.end.add(const Duration(minutes: 22)));

  test('comes up a minute before the show ends, for 15 seconds', () {
    final w = upNextWindow(show, show, next, lastPart: true)!;
    expect(w.from, start.add(const Duration(minutes: 21)));
    expect(w.to, start.add(const Duration(minutes: 21, seconds: 15)));
  });

  test('waits for the part the show ends in', () {
    final firstPart = ScheduledProgram(
        item: show.item, start: start, end: start.add(const Duration(minutes: 8)), layoutStart: start);
    expect(upNextWindow(show, firstPart, next, lastPart: false), isNull);
  });

  test('stays away during breaks, short programs, and before sign-off', () {
    final ad = ScheduledProgram(
        item: show.item, start: start, end: start.add(const Duration(minutes: 1)), role: BreakRole.post);
    expect(upNextWindow(show, ad, next, lastPart: true), isNull);
    final short = ScheduledProgram(item: library['Short-e1'], start: start, end: start.add(const Duration(minutes: 3)));
    expect(upNextWindow(short, short, next, lastPart: true), isNull);
    final offAir = ScheduledProgram(item: null, start: show.end, end: show.end.add(const Duration(hours: 1)));
    expect(upNextWindow(show, show, offAir, lastPart: true), isNull);
    expect(upNextWindow(show, show, null, lastPart: true), isNull);
  });
}
