// screen-back-button: every screen with a previous screen has a back button,
// on every platform and for every input.
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/login_screen.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'portrait_harness.dart';

const sideways = Size(915, 412);
const tabletSideways = Size(1280, 800);
const tv = Size(1920, 1080);

const up = LogicalKeyboardKey.arrowUp, down = LogicalKeyboardKey.arrowDown;
const left = LogicalKeyboardKey.arrowLeft, right = LogicalKeyboardKey.arrowRight;
const ok = LogicalKeyboardKey.select;

final arrow = find.byIcon(Icons.arrow_back);

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> showHome(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(builder: (context, child) => TvCanvas(child: child!), home: home));
  await tester.pump();
  await tester.pump();
}

String? focusedButton() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

bool backFocused() => FocusManager.instance.primaryFocus?.debugLabel == 'back button';

/// A page with a column of controls.
Widget page({VoidCallback? onBack, bool autofocus = false, List<String> controls = const ['First', 'Second']}) => TvPage(
      title: 'A page',
      hints: 'Keys',
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, c) in controls.indexed)
            TvButton(label: c, autofocus: autofocus && i == 0, onPressed: () {}),
        ],
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('it shows and goes back, everywhere', () {
    final setups = <(String, TargetPlatform, bool, Size)>[
      ('an Android TV', TargetPlatform.android, true, tv),
      ('Linux', TargetPlatform.linux, false, tv),
      ('a phone sideways', TargetPlatform.android, false, sideways),
      ('a tablet sideways', TargetPlatform.android, false, tabletSideways),
      ('an upright phone', TargetPlatform.android, false, pixel8),
      ('an upright tablet', TargetPlatform.android, false, tabletUpright),
    ];
    for (final (name, platform, television, window) in setups) {
      testWidgets('on $name', (tester) async {
        runAs(platform, television: television);
        setWindow(tester, window);
        var backs = 0;
        await showHome(tester, page(onBack: () => backs++));
        expect(arrow, findsOneWidget);
        expect(find.text('Back'), window.height > window.width ? findsNothing : findsOneWidget);
        await tester.tap(arrow);
        expect(backs, 1);
        await tester.pumpWidget(const SizedBox());
        await showHome(tester, page());
        expect(arrow, findsNothing, reason: 'nowhere to go back to');
        expect(find.text('Back'), findsNothing);
      });
    }

    testWidgets('the title bar is pressable top to bottom', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, sideways);
      var backs = 0;
      await showHome(tester, page(onBack: () => backs++));
      final scale = TvCanvas.canvasScale(sideways);
      final x = tester.getCenter(arrow).dx;
      await tester.tapAt(Offset(x, 2 * scale));
      await tester.tapAt(Offset(x, 108 * scale));
      expect(backs, 2);
      await tester.tapAt(tester.getTopLeft(find.byType(TvPage)) + Offset(2 * scale, 55 * scale));
      expect(backs, 3, reason: 'out to the left edge');
    });

    testWidgets('it stays clear of a camera cutout', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, sideways);
      tester.view.padding = const FakeViewPadding(left: 60);
      await showHome(tester, page(onBack: () {}));
      expect(tester.getRect(arrow).left, greaterThan(60));
      var backs = 0;
      await showHome(tester, page(onBack: () => backs++));
      await tester.tapAt(const Offset(40, 20));
      expect(backs, 0, reason: 'under the cutout');
    });

    testWidgets('a long title gives way, and the button stays', (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      final title = 'A very long title ' * 12;
      await showHome(tester, TvPage(title: title, onBack: () {}, child: const SizedBox()));
      expect(tester.takeException(), isNull);
      final back = tester.getRect(arrow);
      final text = tester.getRect(find.text(title.toUpperCase()));
      expect(text.left, greaterThan(back.right));
      expect(text.right, lessThanOrEqualTo(1920));
      expect(text.height, lessThanOrEqualTo(110), reason: 'one line');
    });
  });

  group('every input', () {
    for (final (name, window) in [('the TV layout', tv), ('upright', pixel8)]) {
      testWidgets('D-pad, $name: Up reaches it, OK presses it, Down leaves it', (tester) async {
        // Upright is a phone or tablet with a keyboard or remote attached.
        runAs(TargetPlatform.android, television: window == tv);
        setWindow(tester, window);
        var backs = 0;
        await showHome(tester, page(onBack: () => backs++, autofocus: true));
        expect(focusedButton(), 'First');
        await press(tester, up);
        expect(backFocused(), isTrue);
        await press(tester, down);
        expect(focusedButton(), 'First');
        expect(backs, 0, reason: 'the screen stays');
        await press(tester, up);
        await press(tester, ok);
        expect(backs, 1);
      });
    }

    testWidgets('Right leaves it too', (tester) async {
      runAs(TargetPlatform.linux);
      setWindow(tester, tv);
      await showHome(tester, TvPage(
        title: 'A page',
        onBack: () {},
        child: Align(alignment: Alignment.topRight, child: TvButton(label: 'Over here', autofocus: true, onPressed: () {})),
      ));
      await press(tester, up);
      expect(backFocused(), isTrue);
      await press(tester, right);
      expect(focusedButton(), 'Over here');
    });

    testWidgets('Linux: the arrow keys and Enter', (tester) async {
      runAs(TargetPlatform.linux);
      setWindow(tester, tv);
      var backs = 0;
      await showHome(tester, page(onBack: () => backs++, autofocus: true));
      await press(tester, up);
      expect(backFocused(), isTrue);
      await press(tester, LogicalKeyboardKey.enter);
      expect(backs, 1);
    });

    testWidgets('Up from further down a scrolled list reaches it only at the top', (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      await showHome(tester, TvPage(
        title: 'A page',
        onBack: () {},
        child: ListView(children: [
          for (var i = 0; i < 30; i++) TvButton(label: 'Row $i', autofocus: i == 0, onPressed: () {}),
        ]),
      ));
      for (var i = 0; i < 15; i++) {
        await press(tester, down);
      }
      expect(focusedButton(), 'Row 15');
      for (var i = 14; i >= 0; i--) {
        await press(tester, up);
        expect(focusedButton(), 'Row $i');
      }
      await press(tester, up);
      expect(backFocused(), isTrue);
    });

    testWidgets("a text field's Up reaches it", (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      final text = TextEditingController();
      addTearDown(text.dispose);
      final node = FocusNode();
      addTearDown(node.dispose);
      await showHome(tester, TvPage(
        title: 'A form',
        onBack: () {},
        child: TvTextField(controller: text, label: 'Name', focusNode: node),
      ));
      node.requestFocus();
      await tester.pump();
      await press(tester, up);
      expect(backFocused(), isTrue);
      await press(tester, down);
      expect(node.hasPrimaryFocus, isTrue);
    });

    for (final (name, adding) in [('Add a server', true), ('Sign in again', false)]) {
      testWidgets('$name: the keys leave the step for the button and come back', (tester) async {
        runAs(TargetPlatform.android, television: true);
        setWindow(tester, tv);
        final h = await PortraitHarness.start(tester);
        final key = h.app.servers.all.first.key;
        await h.show(tester, adding ? const LoginScreen(adding: true) : LoginScreen(againKey: key));
        await tester.pump(const Duration(milliseconds: 500));
        for (var i = 0; i < 6 && !backFocused(); i++) {
          await press(tester, up);
        }
        expect(backFocused(), isTrue);
        await press(tester, down);
        expect(backFocused(), isFalse);
        expect(find.byType(LoginScreen), findsOneWidget);
        await h.end(tester);
      });
    }

    testWidgets('hover highlights it, without scrolling; a click presses it', (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      var backs = 0;
      await showHome(tester, page(onBack: () => backs++, autofocus: true));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 900));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(arrow));
      await tester.pump();
      await tester.pump();
      expect(backFocused(), isTrue);
      await tester.tap(arrow, kind: PointerDeviceKind.mouse);
      expect(backs, 1);
    });

    testWidgets('a tap takes no focus', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, pixel8);
      var backs = 0;
      await showHome(tester, page(onBack: () => backs++));
      await tester.tap(arrow);
      await tester.pump();
      expect(backs, 1);
      expect(backFocused(), isFalse);
    });

    for (final (name, window) in [('sideways', sideways), ('upright', pixel8)]) {
      testWidgets('a tap with the keyboard up, $name, closes it and goes back', (tester) async {
        runAs(TargetPlatform.android);
        setWindow(tester, window);
        addTearDown(tester.view.resetViewInsets);
        final text = TextEditingController(text: 'Name');
        addTearDown(text.dispose);
        await showHome(tester, Builder(builder: (context) => TvButton(
          label: 'Open',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => TvPage(
            title: 'A form',
            onBack: () => Navigator.of(context).pop(),
            child: TvTextField(controller: text, label: 'Name'),
          ))),
        )));
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.testTextInput.hasAnyClients, isTrue);

        await tester.tap(arrow);
        tester.view.resetViewInsets();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.testTextInput.hasAnyClients, isFalse);
        expect(find.byType(TvPage), findsNothing, reason: 'the previous screen shows');
        expect(find.text('Open'), findsOneWidget);
      });
    }
  });

  group('how a screen opens', () {
    testWidgets('an autofocus control keeps the focus', (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      await showHome(tester, page(onBack: () {}, autofocus: true));
      expect(focusedButton(), 'First');
      expect(backFocused(), isFalse);
    });

    for (final (name, key) in [('Up', up), ('Down', down), ('Left', left), ('Right', right)]) {
      testWidgets('with nothing focused, $name goes to the content', (tester) async {
        runAs(TargetPlatform.android, television: true);
        setWindow(tester, tv);
        await showHome(tester, page(onBack: () {}));
        expect(isTvPageFocus(FocusManager.instance.primaryFocus), isTrue);
        await press(tester, key);
        expect(focusedButton(), 'First');
      });
    }

    testWidgets('a page with nothing else on it: an arrow reaches the button', (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      var backs = 0;
      await showHome(tester, page(onBack: () => backs++, controls: const []));
      await press(tester, down);
      expect(backFocused(), isTrue);
      await press(tester, ok);
      expect(backs, 1);
    });

    testWidgets('no back button and no controls: arrows do nothing and nothing breaks', (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      await showHome(tester, page(controls: const []));
      await press(tester, down);
      expect(isTvPageFocus(FocusManager.instance.primaryFocus), isTrue);
    });

    testWidgets('going back returns focus to the control that opened the screen', (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      await showHome(tester, Builder(builder: (context) => TvPage(
        title: 'First page',
        onBack: () {},
        child: Column(children: [
          TvButton(label: 'One', autofocus: true, onPressed: () {}),
          TvButton(
            label: 'Open',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (context) => page(onBack: () => Navigator.of(context).pop(), autofocus: true))),
          ),
        ]),
      )));
      await press(tester, down);
      await press(tester, ok);
      await tester.pump(const Duration(milliseconds: 500));
      expect(focusedButton(), 'First');
      await press(tester, up);
      expect(backFocused(), isTrue);
      await press(tester, ok);
      await tester.pump(const Duration(milliseconds: 500));
      expect(focusedButton(), 'Open');
    });

    testWidgets('the menu opens on Back to TV, not the back button', (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      final h = await PortraitHarness.start(tester);
      await h.show(tester, const MenuScreen());
      await tester.pump(const Duration(milliseconds: 500));
      expect(focusedButton(), 'Back to TV');
      await h.end(tester);
    });
  });

  testWidgets('after renaming a channel, the back button reaches the menu', (tester) async {
    runAs(TargetPlatform.android, television: true);
    setWindow(tester, tv);
    final h = await PortraitHarness.start(tester);
    await h.show(tester, Builder(builder: (context) => TvButton(
      label: 'The menu',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChannelEditorScreen())),
    )));
    await tester.tap(find.text('The menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final ch = h.app.allChannels.first;
    final field = find.byType(EditableText);
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.tap(field);
    await tester.pump();
    await tester.pump();
    tester.testTextInput.enterText('Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));
    expect(ch.name, 'Renamed');
    expect(arrow, findsOneWidget);
    await tester.tap(arrow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChannelEditorScreen), findsNothing);
    expect(find.text('The menu'), findsOneWidget);
    await h.end(tester);
  });

  group('the guide', () {
    late PortraitHarness h;
    var closes = 0;

    List<String> lit(WidgetTester tester) => [
          for (final b in tester.widgetList<TvPointerButton>(find.byType(TvPointerButton)))
            if (b.highlighted) b.label,
        ];

    Future<void> start(WidgetTester tester, {bool sleep = true}) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, tv);
      closes = 0;
      h = await PortraitHarness.start(tester);
      await h.show(tester, GuideView(onWatch: (_) {}, onClose: () => closes++, onMenu: () {}, onSleep: sleep ? () {} : null));
      await tester.pump();
    }

    Future<void> toMenu(WidgetTester tester) async {
      for (var i = 0; i < 100 && lit(tester).isEmpty; i++) {
        await press(tester, up);
      }
      expect(lit(tester), ['Menu'], reason: 'Up from the grid lands on Menu first');
    }

    testWidgets('it comes after Menu and Sleep', (tester) async {
      await start(tester);
      final x = tester.getTopLeft(find.text('Back')).dx;
      expect(x, greaterThan(tester.getTopLeft(find.text('Sleep')).dx));
      expect(tester.getRect(find.text('NIGHTINGALE TV GUIDE')).right, lessThan(tester.getRect(find.text('Menu')).left));
      await h.end(tester);
    });

    testWidgets('the D-pad: Up to Menu, Right to Back, OK closes it', (tester) async {
      await start(tester);
      await toMenu(tester);
      await press(tester, right);
      expect(lit(tester), ['Sleep']);
      await press(tester, right);
      expect(lit(tester), ['Back']);
      await press(tester, right);
      expect(lit(tester), ['Back'], reason: 'Right stops at the end');
      expect(closes, 0);
      await press(tester, ok);
      expect(closes, 1);
      await h.end(tester);
    });

    testWidgets('with no Sleep, Back comes right after Menu', (tester) async {
      await start(tester, sleep: false);
      await toMenu(tester);
      await press(tester, right);
      expect(lit(tester), ['Back']);
      await press(tester, ok);
      expect(closes, 1);
      await h.end(tester);
    });

    testWidgets('a pointer highlights and clicks it', (tester) async {
      await start(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 900));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Back')));
      await tester.pump();
      expect(lit(tester), ['Back']);
      await tester.tap(find.text('Back'), kind: PointerDeviceKind.mouse);
      expect(closes, 1);
      await h.end(tester);
    });
  });
}
