// portrait-layout: the layout rule and canvas, full screen, and the portrait
// watch screen, run on Linux as an Android phone (or TV) through
// PlatformInfo's override.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_exit.dart';
import 'package:nightingale_tv/channels/break_notices.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/main.dart' show hasPhoneRemote;
import 'package:nightingale_tv/platform/android_back_bridge.dart';
import 'package:nightingale_tv/platform/orientation.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/portrait_watch_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/screen_layout.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fixtures.dart';
import 'portrait_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the layout rule', () {
    const square = Size(800, 800), tall = Size(412, 915), wide = Size(915, 412);

    void expectLayouts(Map<(Size, bool), bool> portrait) {
      for (final MapEntry(key: (window, full), value: want) in portrait.entries) {
        expect(ScreenLayout.forWindow(window, fullScreen: full).isPortrait, want, reason: '$window full=$full');
      }
    }

    test('an Android phone is portrait only in a tall window with full screen off', () {
      runAs(TargetPlatform.android);
      expectLayouts({
        (square, false): false,
        (tall, false): true,
        (wide, false): false,
        (square, true): false,
        (tall, true): false,
        (wide, true): false,
      });
    });

    test('an Android TV and Linux are never portrait', () {
      for (final (platform, tv) in [(TargetPlatform.android, true), (TargetPlatform.linux, false)]) {
        PlatformInfo.debugOverride = platform;
        PlatformInfo.debugTelevision = tv;
        expectLayouts({
          for (final w in [square, tall, wide])
            for (final full in [false, true]) (w, full): false,
        });
      }
      PlatformInfo.debugReset();
    });

    test('the portrait canvas is the window over max(width / 1080, 0.64)', () {
      runAs(TargetPlatform.android);
      Size canvas(Size w) => ScreenLayout.forWindow(w, fullScreen: false).canvas;
      expect(canvas(narrowPhone), narrowPhone / 0.64);
      expect(canvas(pixel8), pixel8 / 0.64);
      expect(canvas(tabletUpright), const Size(1080, 1728));
      expect(ScreenLayout.forWindow(tabletUpright, fullScreen: false).gutter, 32);
      expect(ScreenLayout.tv.gutter, 80);
    });
  });

  group('the canvas', () {
    Future<void> showButton(WidgetTester tester, Size window) async {
      setWindow(tester, window);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TvCanvas(child: child!),
        home: Builder(
          builder: (context) => Column(
            key: const Key('home'),
            children: [
              Text('${ScreenLayout.of(context).canvas}', key: const Key('canvas')),
              TvButton(label: 'Back to TV', icon: Icons.tv, onPressed: () {}),
            ],
          ),
        ),
      ));
    }

    String canvasOf(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('canvas'))).data!;

    for (final window in [narrowPhone, pixel8, tabletUpright]) {
      testWidgets('portrait at $window fills the window with no bars, and a button is 48 dp tall',
          (tester) async {
        runAs(TargetPlatform.android);
        await showButton(tester, window);
        expect(canvasOf(tester), '${ScreenLayout.forWindow(window, fullScreen: false).canvas}');
        expect(tester.getRect(find.byType(TvButton)).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(find.byKey(const Key('home'))), Offset.zero & window, reason: 'no black bars');
      });
    }

    testWidgets('Linux keeps 1920×1080 in a tall window', (tester) async {
      await showButton(tester, pixel8);
      expect(canvasOf(tester), '${TvCanvas.size}');
    });

    testWidgets('an Android TV keeps 1920×1080 in a tall window', (tester) async {
      runAs(TargetPlatform.android, television: true);
      await showButton(tester, pixel8);
      expect(canvasOf(tester), '${TvCanvas.size}');
    });

    testWidgets('the system bars show upright and hide sideways, set once per change', (tester) async {
      runAs(TargetPlatform.android);
      final modes = <Object?>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') modes.add(call.arguments);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await showButton(tester, pixel8);
      await tester.pump();
      expect(modes, ['SystemUiMode.edgeToEdge']);
      setWindow(tester, const Size(915, 412));
      await tester.pump();
      await tester.pump();
      expect(modes, ['SystemUiMode.edgeToEdge', 'SystemUiMode.immersiveSticky']);
    });
  });

  test('the phone remote is offered on TVs and PCs, not on phones or tablets', () {
    runAs(TargetPlatform.android);
    expect(hasPhoneRemote, isFalse);
    runAs(TargetPlatform.android, television: true);
    expect(hasPhoneRemote, isTrue);
    runAs(TargetPlatform.linux);
    expect(hasPhoneRemote, isTrue);
  });

  group('full screen', () {
    const channel = MethodChannel('nightingale_tv/orientation');

    List<String> record(WidgetTester tester) {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      return calls;
    }

    testWidgets('a phone asks Android to turn sideways and back', (tester) async {
      runAs(TargetPlatform.android);
      final calls = record(tester);
      await FullScreen.instance.enter();
      expect(FullScreen.instance.isOn, isTrue);
      await FullScreen.instance.exit();
      expect(FullScreen.instance.isOn, isFalse);
      expect(calls, ['enterFullScreen', 'exitFullScreen']);
    });

    testWidgets('turning the phone upright ends it', (tester) async {
      runAs(TargetPlatform.android);
      record(tester);
      await FullScreen.instance.enter();
      await FullScreen.instance.debugEndedByRotation();
      expect(FullScreen.instance.isOn, isFalse);
    });

    testWidgets('a TV and Linux never touch the channel', (tester) async {
      final calls = record(tester);
      for (final (platform, tv) in [(TargetPlatform.android, true), (TargetPlatform.linux, false)]) {
        runAs(platform, television: tv);
        await FullScreen.instance.enter();
        await FullScreen.instance.exit();
      }
      expect(calls, isEmpty);
    });
  });

  group('the TV screen', () {
    final realCloseApp = closeApp;
    var closed = 0;

    Future<PortraitHarness> start(WidgetTester tester, Size window,
        {TargetPlatform platform = TargetPlatform.android, bool television = false}) async {
      runAs(platform, television: television);
      setWindow(tester, window);
      closed = 0;
      closeApp = () async => closed++;
      addTearDown(() => closeApp = realCloseApp);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('nightingale_tv/orientation'), (call) async => null);
      if (platform == TargetPlatform.android) {
        final bridge = AndroidBackBridge();
        tester.binding.addObserver(bridge);
        addTearDown(() => tester.binding.removeObserver(bridge));
      }
      final h = await PortraitHarness.start(tester);
      await h.show(tester, const TvScreen());
      await tester.pump(const Duration(seconds: 1));
      return h;
    }

    /// A test of the TV screen in a [window], ending playback afterwards.
    void tvTest(String description, Size window, Future<void> Function(WidgetTester tester, PortraitHarness h) body,
        {TargetPlatform platform = TargetPlatform.android, bool television = false}) {
      testWidgets(description, (tester) async {
        final h = await start(tester, window, platform: platform, television: television);
        await body(tester, h);
        await h.end(tester);
      });
    }

    Future<void> systemBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
    }

    final prompt = find.text(TvScreen.exitPrompt);

    tvTest('Back in full screen leaves it, with no prompt', pixel8, (tester, h) async {
      expect(find.byType(PortraitWatchScreen), findsOneWidget);
      await FullScreen.instance.enter();
      await tester.pump();
      expect(find.byType(PortraitWatchScreen), findsNothing, reason: 'the TV layout, fitted to the window');
      expect(find.text('Exit full screen'), findsOneWidget);
      await systemBack(tester);
      expect(FullScreen.instance.isOn, isFalse);
      expect(prompt, findsNothing);
      expect(find.byType(PortraitWatchScreen), findsOneWidget);
      expect(closed, 0);
      await tester.pump(const Duration(seconds: 6));
    });

    tvTest('Exit full screen goes back to portrait', pixel8, (tester, h) async {
      await FullScreen.instance.enter();
      await tester.pump();
      // The banner and its buttons come up on entering full screen.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Exit full screen'));
      await tester.pump();
      expect(FullScreen.instance.isOn, isFalse);
      expect(find.byType(PortraitWatchScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    tvTest('Back in landscape without full screen still prompts', const Size(915, 412), (tester, h) async {
      expect(find.byType(PortraitWatchScreen), findsNothing);
      expect(find.text('Exit full screen'), findsNothing);
      await systemBack(tester);
      expect(prompt, findsOneWidget);
      await systemBack(tester);
      expect(closed, 1);
      await tester.pump(const Duration(seconds: 6));
    });

    tvTest('an Android TV: guide on tap, menu on long-press, no full-screen button', const Size(1920, 1080), television: true, (tester, h) async {
      expect(find.text('Exit full screen'), findsNothing);
      await tester.tap(find.byType(TvScreen));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GuideView), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.longPress(find.byType(TvScreen));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byType(MenuScreen), findsOneWidget);
    });

    tvTest('Linux: a tall window keeps the TV screen, and Escape opens the guide', pixel8, platform: TargetPlatform.linux, (tester, h) async {
      expect(find.byType(PortraitWatchScreen), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GuideView), findsOneWidget);
    });

    group('portrait watch screen', () {
      Finder row(String name) => find.ancestor(of: find.text(name), matching: find.byType(TvFocusable)).first;

      tvTest('shows the player, the now panel, the tabs and the list', pixel8, (tester, h) async {
        final tuned = h.tuner.channel!;
        expect(find.byType(TvPicture), findsOneWidget);
        expect(find.byType(PortraitNowPanel), findsOneWidget);
        expect(find.byType(GuideTabRow), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text(tuned.name.toUpperCase()), findsOneWidget, reason: 'the now panel');
        expect(find.textContaining('Next: '), findsOneWidget);
        // The player sits under the status bar's padding, full width at 16:9.
        final player = tester.getRect(find.byType(AspectRatio).first);
        expect(player.width, pixel8.width);
        expect(player.height, closeTo(pixel8.width * 9 / 16, 0.5));
      });

      tvTest('a tap tunes and moves the highlight', pixel8, (tester, h) async {
        final other = h.app.channels[2];
        await tester.tap(row(other.name));
        await tester.pump(const Duration(seconds: 1));
        expect(h.tuner.channel?.id, other.id);
        expect(find.byType(PortraitWatchScreen), findsOneWidget, reason: 'stays on the screen');
        expect(find.text(other.name.toUpperCase()), findsOneWidget);
        expect(find.descendant(of: row(other.name), matching: find.byIcon(Icons.volume_up)), findsOneWidget);
      });

      tvTest('a long-press shows the next 12 hours, and Watch tunes', pixel8, (tester, h) async {
        final other = h.app.channels[1];
        await tester.longPress(row(other.name));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.byType(ChannelScheduleSheet), findsOneWidget);
        expect(find.text('Now'), findsOneWidget);
        await tester.tap(find.text('Watch'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.byType(ChannelScheduleSheet), findsNothing);
        expect(h.tuner.channel?.id, other.id);
      });

      tvTest('a tab is picked and saved', pixel8, (tester, h) async {
        final tabs = h.app.guideTabs();
        final pick = tabs.firstWhere((t) => t.id != tabs.first.id);
        await tester.tap(find.text(pick.name.toUpperCase()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(h.app.settings.guideTab, pick.id);
        final shown = find.descendant(of: find.byType(ListView), matching: find.byType(TvFocusable));
        expect(shown, findsNWidgets(pick.channels.length));
      });

      tvTest('the player shows Full screen and Menu for 3 seconds on a tap', pixel8, (tester, h) async {
        await tester.pump(const Duration(seconds: 4));
        final controls = find.ancestor(of: find.text('Full screen'), matching: find.byType(AnimatedOpacity));
        expect(tester.widget<AnimatedOpacity>(controls).opacity, 0);
        await tester.tap(find.byType(TvPicture));
        await tester.pump();
        expect(tester.widget<AnimatedOpacity>(controls).opacity, 1);
        await tester.tap(find.text('Full screen'));
        await tester.pump();
        expect(FullScreen.instance.isOn, isTrue);
        await tester.pump(const Duration(seconds: 6));
      });

      tvTest('a long-press on the player opens the menu', pixel8, (tester, h) async {
        await tester.longPress(find.byType(TvPicture));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.byType(MenuScreen), findsOneWidget);
      });

      tvTest('Back twice exits', pixel8, (tester, h) async {
        await systemBack(tester);
        expect(prompt, findsOneWidget);
        await systemBack(tester);
        expect(closed, 1);
        await tester.pump(const Duration(seconds: 6));
      });

      tvTest('channel keys tune, the arrows move through the list and OK tunes', pixel8, (tester, h) async {
        final first = h.tuner.channel!;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump(const Duration(seconds: 1));
        expect(h.tuner.channel?.id, isNot(first.id));
        final second = h.tuner.channel!;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(seconds: 1));
        expect(h.tuner.channel?.id, isNot(second.id));
        expect(find.byType(PortraitWatchScreen), findsOneWidget);
      });

      tvTest('rotating keeps the channel and the picture', pixel8, (tester, h) async {
        final tuned = h.tuner.channel!;
        final picture = tester.element(find.byType(TvPicture));
        setWindow(tester, const Size(915, 412));
        await tester.pump();
        expect(find.byType(PortraitWatchScreen), findsNothing);
        expect(tester.element(find.byType(TvPicture)), same(picture), reason: 'moved, not rebuilt');
        setWindow(tester, pixel8);
        await tester.pump();
        expect(find.byType(PortraitWatchScreen), findsOneWidget);
        expect(h.tuner.channel?.id, tuned.id);
        await tester.pump(const Duration(seconds: 6));
      });

      for (final window in [narrowPhone, tabletUpright]) {
        tvTest('nothing overflows at $window', window, (tester, h) async {
          expect(tester.takeException(), isNull);
          await tester.longPress(row(h.app.channels.first.name));
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
        });
      }
    });
  });

  testWidgets('a break notice shows in the bottom-left corner of the portrait player', (tester) async {
    runAs(TargetPlatform.android);
    setWindow(tester, pixel8);
    var start = DateTime.now();
    final testStart = tester.binding.clock.now();
    final h = await PortraitHarness.start(tester,
        library: fakeLibrary(commercials: const [Duration(seconds: 30), Duration(seconds: 15)]),
        clock: () => start.add(tester.binding.clock.now().difference(testStart)));
    await tester.runAsync(() => h.app.setGlobalPlan(BreakPlan.automatic));
    final ch = h.app.channels.first;
    final schedule = h.app.scheduleFor(ch)!;
    // 3 seconds into the next "Commercial break" countdown.
    var t = DateTime.now();
    while (breakNoticeAt(schedule, t)?.kind != BreakNoticeKind.breakStarts) {
      t = t.add(const Duration(seconds: 1));
    }
    start = t.add(const Duration(seconds: 3)).subtract(tester.binding.clock.now().difference(testStart));
    h.tuner
      ..channel = ch
      ..status = TunerStatus.playing;
    await h.show(
        tester,
        PortraitWatchScreen(
            picture: const TvPicture(), onTune: (_) {}, onMenu: () {}, onFullScreen: () {}));
    await tester.pump(const Duration(milliseconds: 500));
    final card = find.byType(BreakNoticeCard);
    expect(card, findsOneWidget);
    expect(find.textContaining('Commercial break in '), findsOneWidget);
    // Inside the player, in its bottom-left corner, scaled with the picture.
    final player = tester.getRect(find.byType(TvPicture));
    final box = tester.getRect(find.descendant(of: card, matching: find.byType(Container)).first);
    expect(player.contains(box.topLeft) && player.contains(box.bottomRight - const Offset(1, 1)), isTrue,
        reason: '$box in $player');
    final scale = player.width / 1920;
    expect(box.left - player.left, closeTo(90 * scale, 1));
    expect(player.bottom - box.bottom, closeTo(70 * scale, 1));
    h.tuner.status = TunerStatus.idle;
    await h.end(tester);
  });

  testWidgets('the now panel says "Commercial break" during a break', (tester) async {
    runAs(TargetPlatform.android);
    setWindow(tester, pixel8);
    final h = await PortraitHarness.start(tester);
    final ch = h.app.channels.first;
    await h.show(tester, Builder(builder: (context) => PortraitNowPanel(channel: ch, now: DateTime.now(), inBreak: true, gutter: 32)));
    expect(find.text(commercialBreakLabel), findsOneWidget);
  });
}
