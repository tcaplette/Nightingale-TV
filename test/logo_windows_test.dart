import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/logo_windows.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/library/library_index.dart';

const _show = MediaEntry(id: 'e1', kind: MediaKind.episode, title: 'Pilot', runtime: Duration(minutes: 22));
const _ad = MediaEntry(id: 'ad', kind: MediaKind.commercial, title: 'Ad', runtime: Duration(seconds: 30));
const _song = MediaEntry(id: 's1', kind: MediaKind.song, title: 'Song', runtime: Duration(minutes: 4));
const _video = MediaEntry(id: 'mv', kind: MediaKind.musicVideo, title: 'Video', runtime: Duration(minutes: 4));

DateTime _at(int h, int m, [int s = 0]) => DateTime(2026, 10, 20, h, m, s);

ScheduledProgram _part(DateTime start, DateTime end, [MediaEntry item = _show]) =>
    ScheduledProgram(item: item, start: start, end: end);

ScheduledProgram _break(DateTime start, DateTime end) =>
    ScheduledProgram(item: _ad, start: start, end: end, role: BreakRole.mid, program: _show);

void main() {
  // 7:00 program part to 7:10, break to 7:12:40, part to 7:22.
  final evening = [
    _part(_at(19, 0), _at(19, 10)),
    _break(_at(19, 10), _at(19, 12, 40)),
    _part(_at(19, 12, 40), _at(19, 22)),
  ];

  test('Now and then: each part start and each quarter hour, for 20 seconds', () {
    final w = logoWindows(LogoMode.nowAndThen, evening, _at(19, 0), _at(19, 22));
    expect(w, [
      (start: _at(19, 0), end: _at(19, 0, 20)),
      // Back from a break.
      (start: _at(19, 12, 40), end: _at(19, 13)),
      // Quarter hour.
      (start: _at(19, 15), end: _at(19, 15, 20)),
    ]);
  });

  test('Always: throughout program parts, never in the break', () {
    final w = logoWindows(LogoMode.always, evening, _at(19, 0), _at(19, 22));
    expect(w, [
      (start: _at(19, 0), end: _at(19, 10)),
      (start: _at(19, 12, 40), end: _at(19, 22)),
    ]);
  });

  test('Off: never', () {
    expect(logoWindows(LogoMode.off, evening, _at(19, 0), _at(19, 22)), isEmpty);
  });

  test('a quarter hour inside a break shows nothing', () {
    final w = logoWindows(LogoMode.nowAndThen, [
      _part(_at(19, 0), _at(19, 14, 50)),
      _break(_at(19, 14, 50), _at(19, 17)),
      _part(_at(19, 17), _at(19, 25)),
    ], _at(19, 1), _at(19, 25));
    expect(w, [(start: _at(19, 17), end: _at(19, 17, 20))]);
  });

  test('a window is cut off where its part ends', () {
    final w = logoWindows(LogoMode.nowAndThen, [
      _part(_at(19, 0), _at(19, 15, 10)),
      _break(_at(19, 15, 10), _at(19, 18)),
    ], _at(19, 14), _at(19, 18));
    expect(w, [(start: _at(19, 15), end: _at(19, 15, 10))]);
  });

  test('tuning in mid-part: nothing until the next quarter hour', () {
    final w = logoWindows(LogoMode.nowAndThen, [_part(_at(19, 0), _at(19, 45))], _at(19, 21), _at(19, 45));
    expect(w.first, (start: _at(19, 30), end: _at(19, 30, 20)));
  });

  test('a part starting on a quarter hour has one window', () {
    final w = logoWindows(LogoMode.nowAndThen, [_part(_at(19, 30), _at(19, 40))], _at(19, 30), _at(19, 40));
    expect(w, [(start: _at(19, 30), end: _at(19, 30, 20))]);
  });

  test('songs and off-air show nothing; music videos show like programs', () {
    final segments = [
      _part(_at(19, 0), _at(19, 4), _song),
      ScheduledProgram(item: null, start: _at(19, 4), end: _at(19, 15)),
      _part(_at(19, 15), _at(19, 19), _video),
    ];
    expect(logoWindows(LogoMode.always, segments, _at(19, 0), _at(19, 19)), [
      (start: _at(19, 15), end: _at(19, 19)),
    ]);
  });

  test('nextQuarterHour', () {
    expect(nextQuarterHour(_at(19, 21)), _at(19, 30));
    expect(nextQuarterHour(_at(19, 15)), _at(19, 15));
    expect(nextQuarterHour(_at(19, 14, 59)), _at(19, 15));
    expect(nextQuarterHour(_at(23, 50)), DateTime(2026, 10, 21));
  });
}
