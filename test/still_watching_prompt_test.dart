// "Are you still watching?" (idle-power): the prompt over the TV screen and
// the portrait player, with D-pad, air mouse and touch.
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/sleep_timer.dart';
import 'package:nightingale_tv/playback/still_watching.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/portrait_watch_screen.dart';
import 'package:nightingale_tv/ui/sleep_overlay.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

import 'portrait_harness.dart';

void main() {
  late DateTime now;
  late PortraitHarness h;
  const after = Duration(minutes: 2);
  final prompt = find.byType(StillWatchingPrompt);
  final guide = find.byType(GuideView);
  final asleep = find.byType(SleepScreen);

  /// Moves the clock and fake time on together, a second at a time.
  Future<void> pass(WidgetTester tester, Duration d) async {
    for (var left = d; left > Duration.zero; left -= const Duration(seconds: 1)) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> start(WidgetTester tester,
      {Size window = const Size(1920, 1080), TargetPlatform platform = TargetPlatform.linux, bool television = true}) async {
    runAs(platform, television: television);
    setWindow(tester, window);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('nightingale_tv/orientation'), (call) async => null);
    now = DateTime.now();
    h = await PortraitHarness.start(tester, clock: () => now, sleep: true, stillWatching: after);
    final ch = h.app.channels.firstWhere((c) => !c.isMusic);
    await tester.runAsync(() => h.app.setLastChannel(ch));
    await h.show(tester, const TvScreen());
    for (var i = 0; i < 20 && h.tuner.status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(h.tuner.status, TunerStatus.playing);
    // The banner and controls from the tune go.
    await pass(tester, const Duration(seconds: 6));
  }

  /// Until the prompt shows (the set time from the last input or tune).
  Future<void> untilPrompt(WidgetTester tester) async {
    for (var i = 0; i < 200 && prompt.evaluate().isEmpty; i++) {
      await pass(tester, const Duration(seconds: 1));
    }
    expect(prompt, findsOneWidget);
  }

  testWidgets('shows the question, a focused Keep watching and the countdown', (tester) async {
    await start(tester);
    final since = h.still!.lastInput;
    await untilPrompt(tester);
    expect(now.difference(since), greaterThanOrEqualTo(after));
    expect(find.text(StillWatchingPrompt.question), findsOneWidget);
    expect(find.text(StillWatchingPrompt.keepWatching), findsOneWidget);
    expect(find.text('Going to sleep in 0:60'), findsOneWidget);
    await pass(tester, const Duration(seconds: 18));
    expect(find.text('Going to sleep in 0:42'), findsOneWidget);
    await h.end(tester);
  });

  testWidgets('OK closes it and does nothing else; the channel plays on', (tester) async {
    await start(tester);
    final ch = h.tuner.channel;
    await untilPrompt(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(prompt, findsNothing);
    expect(guide, findsNothing, reason: 'OK did not open the guide');
    expect(h.tuner.channel?.id, ch?.id);
    expect(h.still!.phase, StillWatchingPhase.watching);
    await pass(tester, const Duration(seconds: 70));
    expect(h.sleep!.phase, SleepPhase.idle);
    await h.end(tester);
  });

  testWidgets('an air-mouse move closes it without reaching the screen behind', (tester) async {
    await start(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(900, 300));
    addTearDown(mouse.removePointer);
    await untilPrompt(tester);
    // An air mouse sends a stream of moves: the first closes the prompt, the
    // rest of that movement reaches nothing either.
    for (var i = 1; i <= 12; i++) {
      await mouse.moveTo(Offset(900 + i * 10.0, 300 + i * 5.0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(prompt, findsNothing);
    final buttons = find.ancestor(of: find.text('Sleep'), matching: find.byType(AnimatedOpacity)).first;
    expect(tester.widget<AnimatedOpacity>(buttons).opacity, 0, reason: 'the movement did not bring up the buttons');
    // Once the pointer has settled, moving it works as usual again.
    await tester.pump(const Duration(seconds: 1));
    await mouse.moveTo(const Offset(700, 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AnimatedOpacity>(buttons).opacity, 1, reason: 'a later move shows the buttons');
    await tester.pump(const Duration(seconds: 6));
    // A click closes it too, and doesn't open the guide.
    await tester.pump(const Duration(seconds: 1));
    await untilPrompt(tester);
    await tester.tapAt(const Offset(910, 310), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(prompt, findsNothing);
    expect(guide, findsNothing);
    await h.end(tester);
  });

  testWidgets('pointer use on the screens counts as someone there', (tester) async {
    await start(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(900, 300));
    addTearDown(mouse.removePointer);
    await pass(tester, after - const Duration(seconds: 20));
    await mouse.moveTo(const Offset(920, 320));
    await pass(tester, const Duration(seconds: 60));
    expect(prompt, findsNothing);
    await h.end(tester);
  });

  testWidgets('in the portrait player a tap closes it without opening the controls', (tester) async {
    await start(tester, window: pixel8, platform: TargetPlatform.android, television: false);
    expect(find.byType(PortraitWatchScreen), findsOneWidget);
    await untilPrompt(tester);
    await tester.tapAt(tester.getCenter(find.byType(TvPicture)), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 300));
    expect(prompt, findsNothing);
    final controls = find.ancestor(of: find.text('Full screen'), matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(controls).opacity, 0, reason: 'the tap did not open the controls');
    await h.end(tester);
  });

  testWidgets('no answer: at 0 the sound fades and the app sleeps; waking tunes again and waits the full time',
      (tester) async {
    await start(tester);
    final ch = h.tuner.channel;
    await untilPrompt(tester);
    await pass(tester, const Duration(seconds: 60));
    expect(prompt, findsNothing);
    expect(h.sleep!.phase, SleepPhase.fading);
    await pass(tester, const Duration(seconds: 11));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(h.sleep!.phase, SleepPhase.asleep);
    expect(asleep, findsOneWidget);
    expect(h.tuner.channel, isNull);
    // Asleep for a while, then OK.
    await pass(tester, const Duration(minutes: 5));
    expect(prompt, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    for (var i = 0; i < 20 && h.tuner.status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(asleep, findsNothing);
    expect(h.tuner.channel?.id, ch?.id);
    expect(guide, findsNothing);
    final woke = now;
    await untilPrompt(tester);
    expect(now.difference(woke), greaterThanOrEqualTo(after - const Duration(seconds: 1)));
    await h.end(tester);
  });

  testWidgets('a sleep timer set: no prompt', (tester) async {
    await start(tester);
    h.sleep!.choose(const SleepChoice.after(15));
    await pass(tester, const Duration(minutes: 5));
    expect(prompt, findsNothing);
    await h.end(tester);
  });
}
