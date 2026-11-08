import 'dart:ui' as ui;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/sleep_timer.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/remote/key_dispatch.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/sleep_overlay.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'portrait_harness.dart';

void main() {
  late DateTime now;
  late PortraitHarness h;

  Tuner tuner() => h.tuner;
  SleepTimer sleep() => h.sleep!;
  final guide = find.byType(GuideView);
  final menu = find.byType(MenuScreen);
  final warning = find.byType(SleepWarning);
  final asleep = find.byType(SleepScreen);
  final dialog = find.byType(Dialog);
  Finder toast(String text) => find.widgetWithText(SleepToast, text);

  /// The on-screen buttons (Guide, Menu, Sleep) are showing.
  bool buttonsUp(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('Sleep'), matching: find.byType(AnimatedOpacity)).first)
          .opacity ==
      1;

  /// The TV screen with a sleep timer, playing the first generated channel.
  Future<void> start(WidgetTester tester,
      {Size window = const Size(1920, 1080),
      TargetPlatform platform = TargetPlatform.linux,
      bool television = true}) async {
    runAs(platform, television: television);
    setWindow(tester, window);
    now = DateTime.now();
    h = await PortraitHarness.start(tester, clock: () => now, sleep: true);
    final ch = h.app.channels.firstWhere((c) => !c.isMusic);
    await tester.runAsync(() => h.app.setLastChannel(ch));
    await h.show(tester, const TvScreen());
    for (var i = 0; i < 20 && tuner().status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(tuner().status, TunerStatus.playing);
    await tester.pump(const Duration(seconds: 6));
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Moves the clock on by [d], and lets a second of timers run.
  Future<void> jump(WidgetTester tester, Duration d) async {
    now = now.add(d);
    await tester.pump(const Duration(seconds: 1));
  }

  /// Sets [choice] without the picker, and lets its toast go.
  Future<void> setTimer(WidgetTester tester, SleepChoice choice) async {
    sleep().choose(choice);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
  }

  Future<void> intoWarning(WidgetTester tester) async {
    await setTimer(tester, const SleepChoice.after(15));
    await jump(tester, const Duration(minutes: 14));
    expect(sleep().phase, SleepPhase.warning);
    expect(warning, findsOneWidget);
  }

  /// Runs the fade to its end, and the tuner's stop.
  Future<void> fadeOut(WidgetTester tester) async {
    await jump(tester, const Duration(seconds: 60));
    expect(sleep().phase, SleepPhase.fading);
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(sleep().phase, SleepPhase.asleep);
  }

  group('the picker, four ways in', () {
    testWidgets('S opens it with focus on Off; the D-pad picks 30 min', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.keyS);
      expect(dialog, findsOneWidget);
      expect(find.text('Sleep timer'), findsOneWidget);
      final end = sleep().programEnd()!;
      expect(find.textContaining('End of this program · '), findsOneWidget, reason: 'with $end');
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(find.descendant(of: find.byWidget(focused.widget), matching: find.text('Off')).evaluate(), isNotEmpty);
      for (var i = 0; i < 3; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 400));
      expect(dialog, findsNothing);
      expect(sleep().choice, const SleepChoice.after(30));
      expect(toast('Sleep in 30 min'), findsOneWidget);
      expect(guide, findsNothing, reason: 'Enter went to the picker only');
      await h.end(tester);
    });

    testWidgets('the air mouse: moving shows Sleep beside Guide and Menu; clicks pick 60 min', (tester) async {
      await start(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 300));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(910, 310));
      await tester.pump(const Duration(milliseconds: 300));
      expect(buttonsUp(tester), isTrue);
      expect(tester.getTopLeft(find.text('Sleep')).dx, greaterThan(tester.getTopLeft(find.text('Menu')).dx));
      await tester.tap(find.text('Sleep'), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(dialog, findsOneWidget);
      final setAt = now;
      await tester.tap(find.text('60 min'), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(sleep().deadline, setAt.add(const Duration(minutes: 60)));
      expect(guide, findsNothing);
      await h.end(tester);
    });

    testWidgets('the Menu: Sleep timer under Back to TV; a choice goes back to the TV', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.keyM);
      await tester.pump(const Duration(milliseconds: 500));
      expect(menu, findsOneWidget);
      expect(tester.getTopLeft(find.text('Sleep timer')).dy, greaterThan(tester.getTopLeft(find.text('Back to TV')).dy));
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.enter);
      expect(dialog, findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 500));
      expect(menu, findsNothing, reason: 'back to the TV');
      expect(sleep().choice, const SleepChoice.after(30));
      expect(toast('Sleep in 30 min'), findsOneWidget);
      await h.end(tester);
    });

    testWidgets('touch: a tap shows Sleep; with a timer set the picker says what\'s left, and Off turns it off',
        (tester) async {
      await start(tester, platform: TargetPlatform.android, window: const Size(915, 412), television: false);
      await setTimer(tester, const SleepChoice.after(30));
      await tester.tapAt(const Offset(450, 120), kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sleep'), kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Sleep timer · 30 min left'), findsOneWidget);
      await tester.tap(find.text('Off'), kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 400));
      expect(sleep().phase, SleepPhase.idle);
      expect(toast('Sleep timer off'), findsOneWidget);
      await h.end(tester);
    });
  });

  group('in the guide', () {
    /// The guide's highlighted header buttons.
    List<String> lit(WidgetTester tester) => [
          for (final b in tester.widgetList<TvPointerButton>(
              find.descendant(of: guide, matching: find.byType(TvPointerButton))))
            if (b.highlighted) b.label,
        ];

    Future<void> openGuide(WidgetTester tester) async {
      await key(tester, LogicalKeyboardKey.enter);
      expect(guide, findsOneWidget);
      // The tuned channel is a row down; Up to the first row.
      for (var i = 0; i < 10 && lit(tester).isEmpty; i++) {
        await key(tester, LogicalKeyboardKey.arrowUp);
      }
    }

    testWidgets('Up to Menu, Right to Sleep, OK; 45 min shows its toast and the guide stays', (tester) async {
      await start(tester);
      await openGuide(tester);
      expect(lit(tester), ['Menu']);
      expect(tester.getTopLeft(find.descendant(of: guide, matching: find.text('Sleep'))).dx,
          greaterThan(tester.getTopLeft(find.descendant(of: guide, matching: find.text('Menu'))).dx));
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(lit(tester), ['Sleep']);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(lit(tester), ['Back'], reason: 'the end of the header');
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(lit(tester), ['Sleep']);
      await key(tester, LogicalKeyboardKey.enter);
      expect(dialog, findsOneWidget);
      // Off, End of this program, 15, 30, 45.
      for (var i = 0; i < 4; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 400));
      expect(dialog, findsNothing);
      expect(sleep().choice, const SleepChoice.after(45));
      expect(toast('Sleep in 45 min'), findsOneWidget);
      expect(guide, findsOneWidget, reason: 'the guide stays open');
      expect(lit(tester), ['Sleep']);
      // The guide still has the keys.
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(lit(tester), ['Menu']);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(lit(tester), isEmpty);
      await h.end(tester);
    });

    testWidgets('S opens the picker anywhere in the guide', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.enter);
      expect(guide, findsOneWidget);
      await key(tester, LogicalKeyboardKey.keyS);
      expect(dialog, findsOneWidget);
      await key(tester, LogicalKeyboardKey.escape);
      expect(dialog, findsNothing);
      expect(guide, findsOneWidget);
      await h.end(tester);
    });

    testWidgets('hover and keys keep one highlight on the header', (tester) async {
      await start(tester);
      await openGuide(tester);
      expect(lit(tester), ['Menu']);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 600));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.descendant(of: guide, matching: find.text('Sleep'))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(lit(tester), ['Sleep']);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(lit(tester), ['Menu'], reason: 'the keys move on from where the pointer left it');
      await h.end(tester);
    });
  });

  testWidgets('the banner says how long is left, rounded up', (tester) async {
    await start(tester);
    await setTimer(tester, const SleepChoice.after(30));
    await jump(tester, const Duration(minutes: 7, seconds: 16));
    await key(tester, LogicalKeyboardKey.keyI);
    expect(find.text('Sleep in 23 min'), findsOneWidget);
    // A minute into the next program, so its end is well over a minute away.
    final schedule = tuner().schedule!;
    now = schedule.programAt(tuner().viewNow()).end.add(const Duration(minutes: 1)).add(tuner().behind);
    await setTimer(tester, SleepChoice.programEnd);
    expect(sleep().phase, SleepPhase.armed);
    await key(tester, LogicalKeyboardKey.keyI);
    expect(find.text('Sleep at end of program'), findsOneWidget);
    await h.end(tester);
  });

  testWidgets('keys work as usual while a timer is set but not in its last minute', (tester) async {
    await start(tester);
    await setTimer(tester, const SleepChoice.after(15));
    final before = tuner().channel;
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(tuner().channel?.id, isNot(before?.id));
    await key(tester, LogicalKeyboardKey.enter);
    expect(guide, findsOneWidget);
    await h.end(tester);
  });

  group('the last minute', () {
    testWidgets('counts down over the TV; Down turns it off and doesn\'t change channel', (tester) async {
      await start(tester);
      await intoWarning(tester);
      expect(find.textContaining('Going to sleep in '), findsOneWidget);
      expect(find.text(SleepWarning.hint), findsOneWidget);
      final first = sleep().secondsLeft;
      await jump(tester, const Duration(seconds: 18));
      expect(sleep().secondsLeft, first - 18);
      expect(find.text('Going to sleep in ${first - 18}'), findsOneWidget);
      final ch = tuner().channel;
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(sleep().phase, SleepPhase.idle);
      expect(warning, findsNothing);
      expect(toast('Sleep timer off'), findsOneWidget);
      expect(tuner().channel?.id, ch?.id);
      await h.end(tester);
    });

    testWidgets('shows over the guide and the Menu', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.keyG);
      expect(guide, findsOneWidget);
      await intoWarning(tester);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(sleep().phase, SleepPhase.idle);
      expect(guide, findsOneWidget, reason: 'nothing else happened');
      await key(tester, LogicalKeyboardKey.escape);
      await key(tester, LogicalKeyboardKey.keyM);
      await tester.pump(const Duration(milliseconds: 500));
      expect(menu, findsOneWidget);
      await intoWarning(tester);
      await key(tester, LogicalKeyboardKey.enter);
      expect(sleep().phase, SleepPhase.idle);
      expect(menu, findsOneWidget, reason: 'Enter did not pick Back to TV');
      await h.end(tester);
    });

    testWidgets('a pointer move, a click and a tap each turn it off, and do nothing else', (tester) async {
      await start(tester);
      await intoWarning(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 300));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(910, 310));
      await tester.pump(const Duration(milliseconds: 300));
      expect(sleep().phase, SleepPhase.idle);
      expect(buttonsUp(tester), isFalse, reason: 'the move did not bring up the buttons');
      await tester.pump(const Duration(seconds: 6));
      await intoWarning(tester);
      await tester.tapAt(const Offset(910, 310), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(sleep().phase, SleepPhase.idle);
      expect(guide, findsNothing, reason: 'the click did not open the guide');
      await intoWarning(tester);
      await tester.tapAt(const Offset(910, 310), kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 300));
      expect(sleep().phase, SleepPhase.idle);
      expect(guide, findsNothing);
      await h.end(tester);
    });

    testWidgets('an air mouse\'s stream of moves turns it off and the rest of the movement does nothing', (tester) async {
      await start(tester);
      await intoWarning(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 300));
      addTearDown(mouse.removePointer);
      for (var i = 1; i <= 12; i++) {
        await mouse.moveTo(Offset(900 + i * 10.0, 300 + i * 5.0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(sleep().phase, SleepPhase.idle);
      expect(buttonsUp(tester), isFalse, reason: 'the movement did not bring up the buttons');
      await tester.pump(const Duration(seconds: 6));
      await h.end(tester);
    });

    testWidgets('a key-state sync (focus coming back with a modifier down) is not a press', (tester) async {
      await start(tester);
      await intoWarning(tester);
      tester.binding.platformDispatcher.onKeyData!(ui.KeyData(
        timeStamp: Duration.zero,
        type: ui.KeyEventType.down,
        physical: PhysicalKeyboardKey.altLeft.usbHidUsage,
        logical: LogicalKeyboardKey.altLeft.keyId,
        character: null,
        synthesized: true,
      ));
      await tester.pump();
      expect(sleep().phase, SleepPhase.warning);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(sleep().phase, SleepPhase.idle, reason: 'a real press still turns it off');
      await h.end(tester);
    });

    testWidgets('Android Back turns it off and the app stays', (tester) async {
      await start(tester, platform: TargetPlatform.android);
      await intoWarning(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
      await tester.pump();
      expect(sleep().phase, SleepPhase.idle);
      expect(find.text(TvScreen.exitPrompt), findsNothing, reason: 'Back did nothing else');
      // Android 13+: Back comes as a pop, which the app turns into a key.
      await tester.pump(const Duration(seconds: 4));
      await intoWarning(tester);
      expect(dispatchKey(LogicalKeyboardKey.goBack, PhysicalKeyboardKey.browserBack), isTrue);
      await tester.pump();
      expect(sleep().phase, SleepPhase.idle);
      expect(find.text(TvScreen.exitPrompt), findsNothing);
      await h.end(tester);
    });
  });

  group('asleep', () {
    testWidgets('the fade ends in the black sleep screen; its message goes after 10 s', (tester) async {
      await start(tester);
      final ch = tuner().channel;
      await intoWarning(tester);
      await fadeOut(tester);
      expect(asleep, findsOneWidget);
      expect(find.text(SleepScreen.message), findsOneWidget);
      expect(tuner().status, TunerStatus.idle);
      expect(h.screenOn, [false]);
      expect(sleep().sleptOn?.id, ch?.id);
      await tester.pump(const Duration(seconds: 11));
      expect(find.text(SleepScreen.message), findsNothing);
      expect(asleep, findsOneWidget, reason: 'still black');
      await h.end(tester);
    });

    testWidgets('OK wakes it and tunes the channel again, without opening the guide', (tester) async {
      await start(tester);
      final ch = tuner().channel;
      await intoWarning(tester);
      await fadeOut(tester);
      await key(tester, LogicalKeyboardKey.enter);
      for (var i = 0; i < 20 && tuner().status != TunerStatus.playing; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(asleep, findsNothing);
      expect(sleep().phase, SleepPhase.idle);
      expect(h.screenOn, [false, true]);
      expect(tuner().channel?.id, ch?.id);
      expect(tuner().status, TunerStatus.playing);
      expect(guide, findsNothing);
      await h.end(tester);
    });

    testWidgets('asleep over the Menu, waking leaves the channel until the viewer goes back', (tester) async {
      await start(tester);
      final ch = tuner().channel;
      await key(tester, LogicalKeyboardKey.keyM);
      await tester.pump(const Duration(milliseconds: 500));
      await intoWarning(tester);
      await fadeOut(tester);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(menu, findsOneWidget, reason: 'the screen underneath is kept');
      expect(tuner().channel, isNull);
      await key(tester, LogicalKeyboardKey.escape);
      for (var i = 0; i < 20 && tuner().status != TunerStatus.playing; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 1));
      expect(menu, findsNothing);
      expect(tuner().channel?.id, ch?.id);
      await h.end(tester);
    });
  });
}
