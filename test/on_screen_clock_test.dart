import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/playback/sleep_timer.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/format.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/broadcast_cards.dart';
import 'package:nightingale_tv/ui/widgets/transport_bar.dart';
import 'package:nightingale_tv/ui/widgets/on_screen_clock.dart';

import 'portrait_harness.dart';

void main() {
  late DateTime now;
  late PortraitHarness h;

  final clock = find.byType(OnScreenClock);
  bool shown(WidgetTester tester) => tester.widget<OnScreenClock>(clock).visible;
  String clockText(WidgetTester tester) =>
      tester.widget<Text>(find.descendant(of: clock, matching: find.byType(Text))).data!;

  /// The TV screen with the clock [on], playing the first generated channel.
  /// The tuner's clock runs half an hour behind the real one, so the wall
  /// clock and the schedule's time never read the same.
  Future<void> start(WidgetTester tester, {bool on = true, Size window = const Size(1920, 1080)}) async {
    runAs(window.height > window.width ? TargetPlatform.android : TargetPlatform.linux);
    setWindow(tester, window);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('nightingale_tv/orientation'), (call) async => null);
    now = DateTime.now().subtract(const Duration(minutes: 30));
    h = await PortraitHarness.start(tester, clock: () => now, sleep: true);
    await tester.runAsync(() async {
      await h.app.setPlayback(PlaybackSettings(onScreenClock: on));
      await h.app.setLastChannel(h.app.channels.firstWhere((c) => !c.isMusic));
    });
    await h.show(tester, const TvScreen());
    for (var i = 0; i < 20 && h.tuner.status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(h.tuner.status, TunerStatus.playing);
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The wall clock now, or a minute either side (the test may cross one).
  Matcher wallClock() {
    final t = DateTime.now();
    return anyOf([for (final d in [-1, 0, 1]) formatTime(t.add(Duration(minutes: d)))]);
  }

  testWidgets('shows top right once the banner goes, with the setting on', (tester) async {
    await start(tester);
    expect(shown(tester), isFalse, reason: 'the banner is up, with its own clock');
    await tester.pump(const Duration(seconds: 6));
    expect(shown(tester), isTrue);
    expect(clockText(tester), wallClock());
    final box = tester.getRect(clock);
    expect(box.top, 60);
    expect(box.right, 1920 - 90);
    expect(find.descendant(of: clock, matching: find.byIcon(Icons.bedtime)), findsNothing);
    await h.end(tester);
  });

  testWidgets('not there with the setting off', (tester) async {
    await start(tester, on: false);
    await tester.pump(const Duration(seconds: 6));
    expect(clock, findsNothing);
    await h.end(tester);
  });

  testWidgets('reads the wall clock while behind', (tester) async {
    await start(tester);
    await tester.runAsync(h.tuner.pause);
    now = now.add(const Duration(minutes: 12));
    await tester.runAsync(h.tuner.resume);
    await tester.pump(const Duration(seconds: 6));
    expect(h.tuner.behind, const Duration(minutes: 12));
    expect(shown(tester), isTrue);
    expect(clockText(tester), wallClock());
    expect(clockText(tester), isNot(formatTime(h.tuner.viewNow())));
    await h.end(tester);
  });

  testWidgets('makes way for the channel number and the Paused chip, and comes back', (tester) async {
    await start(tester);
    await tester.pump(const Duration(seconds: 6));
    await key(tester, LogicalKeyboardKey.digit1);
    expect(find.byType(ChannelNumberOsd), findsOneWidget);
    expect(shown(tester), isFalse);
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(ChannelNumberOsd), findsNothing);
    expect(shown(tester), isTrue);
    await tester.runAsync(h.tuner.pause);
    await tester.pump();
    expect(find.byType(PausedChip), findsOneWidget);
    expect(shown(tester), isFalse);
    await tester.runAsync(h.tuner.resume);
    await tester.pump();
    expect(shown(tester), isTrue);
    await h.end(tester);
  });

  testWidgets('shows in stand-by and off the air', (tester) async {
    await start(tester);
    await tester.pump(const Duration(seconds: 6));
    h.tuner.status = TunerStatus.standby;
    h.sleep!.choose(SleepChoice.off);
    await tester.pump();
    expect(shown(tester), isTrue);
    late Channel empty;
    await tester.runAsync(() async {
      empty = await h.app.createCustomChannel('Empty', const ChannelSource(seriesKeys: ['alpha|2000']));
      empty.playlist = const [];
      await h.app.updateChannel(empty);
      await h.tuner.tune(h.app.channelById(empty.id)!);
    });
    await tester.pump(const Duration(seconds: 6));
    expect(h.tuner.status, TunerStatus.offAir);
    expect(shown(tester), isTrue);
    await h.end(tester);
  });

  testWidgets('a moon shows before the time while a sleep timer is set', (tester) async {
    await start(tester);
    await tester.pump(const Duration(seconds: 6));
    h.sleep!.choose(const SleepChoice.after(30));
    await tester.pump(const Duration(seconds: 4));
    final moon = find.descendant(of: clock, matching: find.byIcon(Icons.bedtime));
    expect(moon, findsOneWidget);
    expect(tester.getCenter(moon).dx, lessThan(tester.getCenter(find.descendant(of: clock, matching: find.byType(Text))).dx));
    h.sleep!.choose(SleepChoice.off);
    await tester.pump();
    expect(moon, findsNothing);
    await h.end(tester);
  });

  testWidgets('shows in the portrait player, top right, scaled with the picture', (tester) async {
    await start(tester, window: pixel8);
    await tester.pump(const Duration(seconds: 1));
    expect(shown(tester), isTrue, reason: 'no banner in portrait');
    final picture = tester.getRect(find.byType(TvPicture));
    final box = tester.getRect(clock);
    expect(picture.contains(box.topLeft) && picture.contains(box.bottomRight - const Offset(1, 1)), isTrue);
    final scale = picture.width / 1920;
    expect(box.top - picture.top, closeTo(60 * scale, 1));
    expect(picture.right - box.right, closeTo(90 * scale, 1));
    await h.end(tester);
  });

  testWidgets('ticks over on the minute', (tester) async {
    final base = DateTime(2026, 10, 31, 21, 41, 50);
    final start = tester.binding.clock.now();
    DateTime fake() => base.add(tester.binding.clock.now().difference(start));
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: Center(child: OnScreenClock(visible: true, clock: fake)),
    ));
    expect(find.text('9:41 PM'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('9:41 PM'), findsOneWidget);
    // Just past the minute.
    await tester.pump(const Duration(seconds: 1, milliseconds: 10));
    expect(find.text('9:42 PM'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('9:43 PM'), findsOneWidget);
  });
}
