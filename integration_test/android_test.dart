// Android's remote, touch, Back and lifecycle behavior, run on Linux through
// PlatformInfo's override, and the same screens on Linux, which must not
// change. Needs no server.
//
//   flutter test integration_test/android_test.dart -d linux
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/app_exit.dart';
import 'package:nightingale_tv/platform/android_back_bridge.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/remote/key_dispatch.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

import '../test/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final realCloseApp = closeApp;
  var closed = 0;

  /// Starts the app as [platform], with closing the app counted instead of
  /// done and, on Android, system Back going through the bridge as in main().
  Future<UiHarness> start(WidgetTester tester, TargetPlatform platform) async {
    PlatformInfo.debugOverride = platform;
    closed = 0;
    closeApp = () async => closed++;
    if (platform == TargetPlatform.android) {
      final bridge = AndroidBackBridge();
      tester.binding.addObserver(bridge);
      addTearDown(() => tester.binding.removeObserver(bridge));
    }
    addTearDown(() {
      PlatformInfo.debugReset();
      closeApp = realCloseApp;
    });
    final h = await UiHarness.start(
      tester,
      fakeLibrary(
        shows: {'Cheers': 40, 'Taxi': 30, 'Wings': 30, 'Frasier': 30},
        genres: {
          'Cheers': ['Comedy'],
          'Taxi': ['Comedy'],
          'Wings': ['Drama'],
          'Frasier': ['Drama'],
        },
      ),
    );
    // Let the power-on banner fade.
    await h.wait(const Duration(seconds: 6));
    return h;
  }

  /// A key from an Android TV remote. Flutter's key simulator has no
  /// physical keys for Back, Guide or Last Channel, so it's delivered
  /// through the focused screen the way the phone remote delivers keys.
  Future<void> remote(UiHarness h, LogicalKeyboardKey key, {Duration after = const Duration(milliseconds: 500)}) async {
    h.tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.tester.pump();
    dispatchKey(key, PhysicalKeyboardKey.browserBack);
    await h.wait(after);
  }

  /// Android's system Back (button or gesture), which arrives as a pop.
  Future<void> systemBack(UiHarness h, {Duration after = const Duration(milliseconds: 800)}) async {
    // As in UiHarness.press: the test window may be in the background, and
    // Flutter drops focus then. Back nothing handles closes the app.
    h.tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull, reason: 'a screen has focus to take Back');
    await h.tester.binding.handlePopRoute();
    await h.wait(after);
  }

  /// A test of the app started as [platform].
  void uiTest(String description, TargetPlatform platform, Future<void> Function(UiHarness h) body) {
    testWidgets(description, (tester) async {
      final h = await start(tester, platform);
      try {
        await body(h);
      } finally {
        await h.dispose();
      }
    });
  }

  bool onTv() => find.byType(MenuScreen).evaluate().isEmpty && find.byType(GuideView).evaluate().isEmpty;
  final prompt = find.text(TvScreen.exitPrompt);

  group('menu', () {
    uiTest('Android: no full screen or Live TV export, and Exit quits', TargetPlatform.android, (h) async {
      var hookRan = false;
      Future<void> hook() async => hookRan = true;
      exitHooks.add(hook);
      addTearDown(() => exitHooks.remove(hook));

      await h.press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
      expect(find.byType(MenuScreen), findsOneWidget);
      expect(find.text('Full screen on/off (F11)'), findsNothing);
      expect(find.text('Live TV export'), findsNothing);
      expect(h.household.export, isNull);

      await h.tap('Exit Nightingale TV');
      expect(hookRan, isTrue, reason: 'exit hooks run');
      expect(h.tuner.channel, isNull, reason: 'playback stopped');
      expect(closed, 1);
    });

    uiTest('Linux: full screen is offered, and Exit runs the hooks', TargetPlatform.linux, (h) async {
      var hookRan = false;
      Future<void> hook() async => hookRan = true;
      exitHooks.add(hook);
      addTearDown(() => exitHooks.remove(hook));

      await h.press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
      await h.tap('Exit Nightingale TV');
      expect(hookRan, isTrue);
      expect(closed, 1);
    });

    uiTest('Linux: the full-screen button is there', TargetPlatform.linux, (h) async {
      await h.press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
      final list = find.byType(Scrollable).first;
      await h.tester.scrollUntilVisible(find.text('Full screen on/off (F11)'), 300, scrollable: list);
      expect(find.text('Full screen on/off (F11)'), findsOneWidget);
    });
  });

  group('Back on Android', () {
    uiTest('closes sub-screens and the guide like Escape', TargetPlatform.android, (h) async {

      await h.openMenuItem('Channels & icons');
      expect(find.byType(ChannelEditorScreen), findsOneWidget);
      await systemBack(h);
      expect(find.byType(ChannelEditorScreen), findsNothing);
      expect(find.byType(MenuScreen), findsOneWidget, reason: 'back to the menu, as Escape does');
      await systemBack(h);
      expect(onTv(), isTrue);
      expect(prompt, findsNothing, reason: 'leaving a screen is not the TV screen\'s Back');

      await h.press(LogicalKeyboardKey.keyG, after: const Duration(seconds: 1));
      expect(find.byType(GuideView), findsOneWidget);
      await systemBack(h);
      expect(onTv(), isTrue);
      expect(closed, 0);
    });

    uiTest('cancels channel-number entry', TargetPlatform.android, (h) async {
      final channel = h.tuner.channel;
      await remote(h, LogicalKeyboardKey.digit2, after: const Duration(milliseconds: 200));
      expect(find.text('2_'), findsOneWidget);
      await systemBack(h, after: const Duration(milliseconds: 200));
      expect(find.text('2_'), findsNothing);
      expect(prompt, findsNothing);
      await h.wait(const Duration(seconds: 2));
      expect(h.tuner.channel, channel, reason: 'the number was never tuned');
    });

    uiTest('twice within 3 seconds quits', TargetPlatform.android, (h) async {
      var hookRan = false;
      Future<void> hook() async => hookRan = true;
      exitHooks.add(hook);
      addTearDown(() => exitHooks.remove(hook));

      await systemBack(h);
      expect(prompt, findsOneWidget);
      expect(closed, 0);
      await systemBack(h);
      expect(closed, 1);
      expect(hookRan, isTrue);
      expect(h.tuner.channel, isNull, reason: 'playback stopped');
    });

    uiTest('once, then waiting, keeps playing', TargetPlatform.android, (h) async {
      final channel = h.tuner.channel;
      await systemBack(h);
      expect(prompt, findsOneWidget);
      await h.wait(const Duration(milliseconds: 3500));
      expect(prompt, findsNothing);
      expect(h.tuner.channel, channel);
      // A Back after the prompt timed out asks again rather than quitting.
      await systemBack(h);
      expect(prompt, findsOneWidget);
      expect(closed, 0);
    });

    uiTest('another key cancels the prompt', TargetPlatform.android, (h) async {
      await systemBack(h);
      expect(prompt, findsOneWidget);
      await remote(h, LogicalKeyboardKey.arrowLeft);
      expect(prompt, findsNothing);
      await systemBack(h);
      expect(prompt, findsOneWidget, reason: 'asks again');
      expect(closed, 0);
    });

    uiTest('the Back key (older Android) works the same, and Escape opens the guide', TargetPlatform.android, (h) async {
      await remote(h, LogicalKeyboardKey.goBack);
      expect(prompt, findsOneWidget);
      await remote(h, LogicalKeyboardKey.goBack);
      expect(closed, 1);

      await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
      expect(find.byType(GuideView), findsOneWidget, reason: 'a keyboard\'s Escape still opens the guide');
    });
  });

  uiTest('Linux: Back and Escape on the TV screen open the guide', TargetPlatform.linux, (h) async {
    await remote(h, LogicalKeyboardKey.goBack, after: const Duration(seconds: 1));
    expect(find.byType(GuideView), findsOneWidget);
    expect(prompt, findsNothing);
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    expect(onTv(), isTrue);
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    expect(find.byType(GuideView), findsOneWidget);
    expect(closed, 0);
  });

  group('Guide and Last Channel buttons', () {
    uiTest('Android: Guide toggles the guide and Last Channel flips back', TargetPlatform.android, (h) async {
      await remote(h, LogicalKeyboardKey.guide, after: const Duration(seconds: 1));
      expect(find.byType(GuideView), findsOneWidget);
      await remote(h, LogicalKeyboardKey.guide, after: const Duration(seconds: 1));
      expect(onTv(), isTrue);

      final first = h.tuner.channel;
      await remote(h, LogicalKeyboardKey.channelUp, after: const Duration(seconds: 1));
      final second = h.tuner.channel;
      expect(second, isNot(first));
      await remote(h, LogicalKeyboardKey.mediaLast, after: const Duration(seconds: 1));
      expect(h.tuner.channel?.id, first?.id);
      await remote(h, LogicalKeyboardKey.mediaLast, after: const Duration(seconds: 1));
      expect(h.tuner.channel?.id, second?.id);
    });

    uiTest('Linux: both are ignored, as before', TargetPlatform.linux, (h) async {
      final first = h.tuner.channel;
      await remote(h, LogicalKeyboardKey.channelUp, after: const Duration(seconds: 1));
      final second = h.tuner.channel;
      await remote(h, LogicalKeyboardKey.guide, after: const Duration(seconds: 1));
      expect(find.byType(GuideView), findsNothing);
      await remote(h, LogicalKeyboardKey.mediaLast, after: const Duration(seconds: 1));
      expect(h.tuner.channel?.id, second?.id);
      expect(second, isNot(first));
    });
  });

  group('touch', () {
    uiTest('Android: long-press opens the menu', TargetPlatform.android, (h) async {
      await h.tester.longPress(find.byType(TvScreen));
      await h.wait(const Duration(seconds: 1));
      expect(find.byType(MenuScreen), findsOneWidget);
    });

    uiTest('Linux: long-press doesn\'t open the menu', TargetPlatform.linux, (h) async {
      await h.tester.longPress(find.byType(TvScreen));
      await h.wait(const Duration(seconds: 1));
      expect(find.byType(MenuScreen), findsNothing);
    });

    /// Drags the guide's channel list up by [rows] rows, slowly (no fling),
    /// then picks the highlighted channel.
    Future<void> dragGuide(UiHarness h, int rows) async {
      await h.press(LogicalKeyboardKey.keyG, after: const Duration(seconds: 1));
      final guide = h.tester.getRect(find.byType(GuideView));
      final scale = guide.width / 1920;
      // On the first channel row (the grid starts below the 440-unit info
      // panel and the time header).
      final gesture = await h.tester.startGesture(
          Offset(guide.center.dx, guide.top + guide.height * 560 / 1080),
          kind: PointerDeviceKind.touch);
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, -87.0 * rows * scale / 20));
        await h.tester.pump(const Duration(milliseconds: 16));
      }
      await h.wait(const Duration(milliseconds: 300));
      await gesture.up();
      await h.wait(const Duration(milliseconds: 500));
      await h.press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    }

    uiTest('Android: dragging the guide moves it by rows', TargetPlatform.android, (h) async {
      final channels = h.app.channels;
      expect(h.tuner.channel?.id, channels.first.id);
      await dragGuide(h, 2);
      expect(h.tuner.channel?.id, channels[2].id);
    });

    uiTest('Linux: dragging the guide does nothing', TargetPlatform.linux, (h) async {
      final channels = h.app.channels;
      await dragGuide(h, 2);
      expect(h.tuner.channel?.id, channels.first.id);
    });
  });

  group('background and return', () {
    Future<void> hide(UiHarness h) async {
      h.tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      h.tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // No frames are drawn while hidden, so wait without pumping.
      await h.tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    }

    Future<void> show(UiHarness h) async {
      h.tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      h.tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await h.wait(const Duration(seconds: 1));
    }

    uiTest('Android: hidden stops playback; shown tunes the same channel live', TargetPlatform.android, (h) async {
      await remote(h, LogicalKeyboardKey.channelUp, after: const Duration(seconds: 1));
      final channel = h.tuner.channel!;

      await hide(h);
      expect(h.tuner.channel, isNull);
      expect(h.tuner.program, isNull);

      await show(h);
      expect(h.tuner.channel?.id, channel.id);
      final now = DateTime.now();
      final live = h.app.scheduleFor(channel)!.programAt(now);
      expect(h.tuner.program?.start, live.start, reason: 'joins what\'s airing now');
    });

    uiTest('Android: nothing tunes on return if nothing was playing', TargetPlatform.android, (h) async {
      await h.tester.runAsync(h.tuner.stop);
      await hide(h);
      await show(h);
      expect(h.tuner.channel, isNull);
    });

    uiTest('Linux: no change when hidden', TargetPlatform.linux, (h) async {
      final channel = h.tuner.channel;
      await hide(h);
      expect(h.tuner.channel, channel);
      await show(h);
      expect(h.tuner.channel, channel);
    });
  });
}
