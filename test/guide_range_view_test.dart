import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/format.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

/// Remembers how far ahead the guide asked for live guide data.
class _AskingApp extends AppState {
  _AskingApp(super.storage) : super(runAnalysis: false);

  final asked = <DateTime>[];

  @override
  void needLiveGuideUntil(Channel ch, DateTime until) => asked.add(until);
}

void main() {
  late Directory dir;
  late _AskingApp app;
  late Tuner tuner;
  // 8:10 PM, as in the spec.
  late DateTime now;

  final library = fakeLibrary(shows: const {'Alpha': 40, 'Beta': 40}, movies: 6);

  Future<void> show(WidgetTester tester, {required int hours, bool live = false}) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    now = DateTime(2026, 11, 3, 20, 10);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_guide_range');
      final seeded = await signedInApp(dir, library);
      await seeded.close();
      app = _AskingApp(seeded.storage);
      await app.start();
      app.client = FakeClient([]);
      await app.setGuideRange(hours);
      if (live) {
        final source =
            LiveSource(id: 'iptv', kind: LiveSourceKind.m3u, name: 'IPTV', playlistUrl: 'http://127.0.0.1:9/x.m3u');
        await app.live.addSource(source, [LiveChannelInfo(key: 'k0', name: 'Live 0', number: '1.1', url: 'http://p/0.ts')]);
        await app.chooseLiveChannels(source, {'k0'});
      }
    });
    tuner = Tuner(app, player: FakePlayer([]))
      ..prefetch = false
      ..preload = false;
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: AppScope(
        app: app,
        tuner: tuner,
        child: TvCanvas(child: GuideView(onWatch: (_) {}, onClose: () {}, onMenu: () {}, clock: () => now)),
      ),
    ));
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tuner.dispose();
      await tester.runAsync(() async {
        await app.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await dir.delete(recursive: true);
      });
    });
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The first channel's schedule, which the cursor starts on.
  Channel first() => app.guideTabs().first.channels.first;

  /// Where each program cell starts, read off the grid (it starts at 300
  /// and is 1620 wide, for 90 minutes from the first header time).
  List<DateTime> cellStarts(WidgetTester tester, DateTime windowStart) => [
        for (final e in find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ProgramCell').evaluate())
          windowStart.add(Duration(
              seconds: ((tester.getRect(find.byWidget(e.widget)).left - 300) / 1620 * 90 * 60).round())),
      ];

  /// The window start the grid shows: its first header time.
  DateTime windowStartShown(WidgetTester tester) {
    for (var t = floorToHalfHour(now); t.isBefore(now.add(const Duration(hours: 12))); t = t.add(const Duration(minutes: 30))) {
      if (find.text(formatTime(t)).evaluate().isNotEmpty) return t;
    }
    fail('No header time found.');
  }

  for (final hours in GuideRange.choices) {
    testWidgets('holding Right stops on the program airing at the end of a $hours-hour range', (tester) async {
      await show(tester, hours: hours);
      await press(tester, LogicalKeyboardKey.arrowRight, times: 60);
      final end = now.add(Duration(hours: hours));
      final last = app.scheduleFor(first())!.guideProgramAt(end);
      expect(find.textContaining(formatRange(last.start, last.end)), findsOneWidget);
      // The window doesn't pass the half hour holding the end of the range.
      final start = windowStartShown(tester);
      final floor = floorToHalfHour(end);
      final cap = floor == end ? end : floor.add(const Duration(minutes: 30));
      expect(start.add(const Duration(minutes: 90)).isAfter(cap), isFalse);
      for (final s in cellStarts(tester, start)) {
        expect(s.isBefore(end), isTrue, reason: 'a program starting at $s is past the range end $end');
      }
    });
  }

  testWidgets('the end of the range moves with the clock; Left still works', (tester) async {
    await show(tester, hours: 3);
    await press(tester, LogicalKeyboardKey.arrowRight, times: 40);
    final schedule = app.scheduleFor(first())!;
    final last = schedule.guideProgramAt(now.add(const Duration(hours: 3)));
    expect(find.textContaining(formatRange(last.start, last.end)), findsOneWidget);

    // Left goes back to the program before.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    final before = schedule.guideProgramAt(last.start.subtract(const Duration(seconds: 1)));
    expect(find.textContaining(formatRange(before.start, before.end)), findsOneWidget);

    // 30 minutes later, Right reaches 30 minutes further.
    now = now.add(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 6));
    await press(tester, LogicalKeyboardKey.arrowRight, times: 40);
    final later = schedule.guideProgramAt(now.add(const Duration(hours: 3)));
    expect(later.end.isAfter(last.end), isTrue);
    expect(find.textContaining(formatRange(later.start, later.end)), findsOneWidget);
  });

  testWidgets('live guide asks never pass the end of the range', (tester) async {
    await show(tester, hours: 3, live: true);
    // The lineup comes from the real date, so its programs fall anywhere. The
    // range ends a minute into one: the window showing that program's start
    // always reaches past the end, and the ask stops there.
    final schedule = app.scheduleFor(first())!;
    final last = schedule.guideProgramAt(now.add(const Duration(hours: 4)));
    now = last.start.add(const Duration(minutes: 1)).subtract(const Duration(hours: 3));
    await tester.pump(const Duration(seconds: 6));
    await press(tester, LogicalKeyboardKey.arrowRight, times: 60);
    await tester.pump();
    final end = now.add(const Duration(hours: 3));
    expect(app.asked, isNotEmpty);
    expect(app.asked.where((t) => t.isAfter(end)), isEmpty);
    expect(app.asked.last, end);
  });
}
