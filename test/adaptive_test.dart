// portrait-layout's shared pieces in both layouts: the page frame, dialog
// widths, the main-and-side columns, and the list whose detail is a page of
// its own upright (with the hand-off when the window turns).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/platform/android_back_bridge.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/widgets/adaptive.dart';
import 'package:nightingale_tv/ui/widgets/screen_layout.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fake_playback.dart';
import 'portrait_harness.dart';

const sideways = Size(915, 412);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> showBare(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(builder: (context, child) => TvCanvas(child: child!), home: home));
    await tester.pump();
  }

  group('TvPage', () {
    Widget page(VoidCallback? onBack) =>
        TvPage(title: 'Programming blocks', hints: '▲▼ Move    OK Edit    ESC Back', onBack: onBack, child: const SizedBox.expand(key: Key('body')));

    testWidgets('upright: a back arrow, no key hints, clear of the status bar', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, pixel8);
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
      var backs = 0;
      await showBare(tester, page(() => backs++));
      expect(find.text('▲▼ Move    OK Edit    ESC Back'), findsNothing);
      final title = tester.getRect(find.text('PROGRAMMING BLOCKS'));
      expect(title.top, greaterThan(40), reason: 'under the status bar');
      expect(tester.getRect(find.byKey(const Key('body'))).bottom, lessThanOrEqualTo(pixel8.height - 24));
      expect(tester.getRect(find.byIcon(Icons.arrow_back)).height, greaterThanOrEqualTo(24));
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backs, 1);
    });

    testWidgets('upright with no Back: no arrow', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, pixel8);
      await showBare(tester, page(null));
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('the TV layout is as before: hints, no arrow, 110-unit title bar', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, sideways);
      await showBare(tester, page(() {}));
      expect(find.text('▲▼ Move    OK Edit    ESC Back'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      final scale = TvCanvas.canvasScale(sideways);
      expect(tester.getRect(find.byKey(const Key('body'))).top, closeTo(110 * scale, 0.01));
    });
  });

  group('dialogWidth', () {
    Future<double> widthIn(WidgetTester tester, Size window) async {
      setWindow(tester, window);
      late double width;
      await showBare(tester, Builder(builder: (context) {
        width = dialogWidth(context, 820, padding: dialogPadding(context));
        return const SizedBox();
      }));
      return width;
    }

    testWidgets('upright it fits between the gutters; on a TV it is as asked', (tester) async {
      runAs(TargetPlatform.android);
      final canvas = ScreenLayout.forWindow(narrowPhone, fullScreen: false).canvas;
      expect(await widthIn(tester, narrowPhone), canvas.width - 2 * 32 - 2 * 32);
      expect(await widthIn(tester, tabletUpright), 820);
      expect(await widthIn(tester, sideways), 820);
    });
  });

  group('AdaptiveColumns', () {
    Widget columns({bool sideFirst = false}) => AdaptiveColumns(
          sideWidth: 400,
          sideFirst: sideFirst,
          main: const [SizedBox(key: Key('main'), height: 100)],
          side: const SizedBox(key: Key('side'), height: 100),
        );

    testWidgets('the TV layout: the panel to the right of the main column', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, sideways);
      await showBare(tester, columns());
      final main = tester.getRect(find.byKey(const Key('main')));
      final side = tester.getRect(find.byKey(const Key('side')));
      expect(side.left, greaterThanOrEqualTo(main.right));
      expect(side.width, closeTo(400 * TvCanvas.canvasScale(sideways), 0.01));
    });

    testWidgets('upright: the panel after the main content, or before it', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, pixel8);
      await showBare(tester, columns());
      expect(tester.getRect(find.byKey(const Key('side'))).top,
          greaterThan(tester.getRect(find.byKey(const Key('main'))).bottom));
      await showBare(tester, columns(sideFirst: true));
      expect(tester.getRect(find.byKey(const Key('side'))).bottom,
          lessThan(tester.getRect(find.byKey(const Key('main'))).top));
    });
  });

  group('the menu', () {
    testWidgets('upright: the summary first, then the buttons; nothing focused on touch', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, pixel8);
      final h = await PortraitHarness.start(tester);
      await h.show(tester, const MenuScreen());
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(find.text('WATCHING')).top, lessThan(tester.getRect(find.text('Back to TV')).top));
      expect(tester.getRect(find.text('COMMERCIALS')).top, lessThan(tester.getRect(find.text('Back to TV')).top));
      expect(tester.getRect(find.text('WATCHING')).top, greaterThan(0), reason: 'the page opens at the top');
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>(), isNull);
    });

    testWidgets('the TV layout: the buttons on the left, the summary beside them, Back to TV focused', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, sideways);
      final h = await PortraitHarness.start(tester);
      await h.show(tester, const MenuScreen());
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(find.text('WATCHING')).left, greaterThan(tester.getRect(find.text('Back to TV')).right));
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label, 'Back to TV');
    });
  });

  group('Guide range (the channel editor)', () {
    for (final (name, window) in [('upright', pixel8), ('the TV layout', sideways)]) {
      testWidgets('$name: picking a choice saves it and does not re-tune', (tester) async {
        runAs(TargetPlatform.android);
        setWindow(tester, window);
        final h = await PortraitHarness.start(tester);
        final ch = h.app.channels.first;
        await tester.runAsync(() => h.tuner.tune(ch));
        final player = h.tuner.media as FakePlayer;
        final opens = player.opens.length;
        await h.show(tester, const ChannelEditorScreen());
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('GUIDE RANGE'), findsOneWidget);
        expect(h.app.settings.guideRangeHours, 8);
        await tester.ensureVisible(find.text('3 hours'));
        await tester.pump();
        await tester.tap(find.text('3 hours'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(h.app.settings.guideRangeHours, 3);
        expect(h.tuner.channel?.id, ch.id);
        expect(player.opens.length, opens, reason: 'nothing re-tunes');
        await h.end(tester);
      });
    }
  });

  group('ListDetail (the channel editor)', () {
    Future<PortraitHarness> open(WidgetTester tester, Size window) async {
      runAs(TargetPlatform.android);
      setWindow(tester, window);
      final bridge = AndroidBackBridge();
      tester.binding.addObserver(bridge);
      addTearDown(() => tester.binding.removeObserver(bridge));
      final h = await PortraitHarness.start(tester);
      await h.show(tester, const ChannelEditorScreen());
      await tester.pump(const Duration(milliseconds: 500));
      return h;
    }

    Future<void> turn(WidgetTester tester, Size window) async {
      setWindow(tester, window);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('upright, a tap opens the channel as a page; Back returns to the list', (tester) async {
      final h = await open(tester, pixel8);
      final ch = h.app.allChannels[2];
      expect(find.byType(TvTextField), findsNothing, reason: 'just the list');
      await tester.tap(find.text(ch.name).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text(ch.name.toUpperCase()), findsOneWidget, reason: 'the page is titled with the channel');
      expect(tester.widget<TvTextField>(find.byType(TvTextField)).controller.text, ch.name);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TvTextField), findsNothing);
      expect(find.text(ch.name), findsWidgets, reason: 'the row is still in view');
    });

    testWidgets('typed in portrait, then turned sideways: side by side, with the text kept', (tester) async {
      final h = await open(tester, pixel8);
      final ch = h.app.allChannels[2];
      await tester.tap(find.text(ch.name).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'My new name');
      await turn(tester, sideways);
      expect(find.byType(TvTextField), findsOneWidget, reason: 'one editor: the page closed');
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('CHANNEL ${ch.number}'), findsOneWidget, reason: 'that channel is selected');
      expect(find.text('My new name'), findsOneWidget);
      // And back upright: the selected channel opens as its page again.
      await turn(tester, pixel8);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text(ch.name.toUpperCase()), findsOneWidget);
      expect(find.text('My new name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the TV layout: the list and the detail side by side, focus selects', (tester) async {
      final h = await open(tester, sideways);
      expect(find.byType(TvTextField), findsOneWidget);
      expect(find.text('CHANNEL ${h.app.allChannels.first.number}'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CHANNEL ${h.app.allChannels[1].number}'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}
