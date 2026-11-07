// text-entry: a text field and its on-screen keyboard can always be left, on
// an Android TV, on a phone or tablet, and on the PC (which keeps its keys).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/remote/key_dispatch.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/widgets/adaptive.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'portrait_harness.dart';

const sideways = Size(915, 412);
const keyboard = FakeViewPadding(bottom: 250);

/// A form as the app's screens have them: a control on either side of the
/// field, and one below.
class _Form extends StatefulWidget {
  const _Form({this.autofocus = false, this.obscure = false, this.onSubmitted});

  final bool autofocus;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _text = TextEditingController(text: 'Name');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvPage(
      title: 'Form',
      child: Column(
        children: [
          Row(
            children: [
              TvButton(label: 'Left', onPressed: () {}),
              Expanded(
                child: TvTextField(
                  controller: _text,
                  label: 'Field',
                  autofocus: widget.autofocus,
                  obscure: widget.obscure,
                  onSubmitted: widget.onSubmitted,
                ),
              ),
              TvButton(label: 'Right', onPressed: () {}),
            ],
          ),
          TvButton(label: 'Below', onPressed: () {}),
          const Expanded(child: SizedBox(key: Key('empty'))),
        ],
      ),
    );
  }
}

Future<void> showForm(WidgetTester tester, Widget form) async {
  setWindow(tester, const Size(1920, 1080));
  await tester.pumpWidget(MaterialApp(builder: (context, child) => TvCanvas(child: child!), home: form));
  await tester.pump();
}

Finder get field => find.byType(EditableText);

bool fieldFocused(WidgetTester tester) => tester.widget<EditableText>(field).focusNode.hasFocus;

String? focusedButton() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

Future<void> focusField(WidgetTester tester) async {
  tester.widget<EditableText>(field).focusNode.requestFocus();
  await tester.pump();
  await tester.pump();
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
}

/// A click from a mouse or air mouse, not a finger.
Future<void> click(WidgetTester tester, Finder target) async {
  final mouse = await tester.startGesture(tester.getCenter(target), kind: PointerDeviceKind.mouse);
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await tester.pump();
}

bool keyboardShown(WidgetTester tester) =>
    tester.testTextInput.hasAnyClients && tester.testTextInput.isVisible;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('on a TV', () {
    testWidgets('focus highlights the field, with no keyboard', (tester) async {
      runAs(TargetPlatform.android, television: true);
      await showForm(tester, const _Form());
      await focusField(tester);
      expect(fieldFocused(tester), isTrue);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(tester.widget<EditableText>(field).readOnly, isTrue);
    });

    for (final (name, key, to) in [
      ('Down', LogicalKeyboardKey.arrowDown, 'Right'),
      ('Up', LogicalKeyboardKey.arrowUp, 'Left'),
      ('Left', LogicalKeyboardKey.arrowLeft, 'Left'),
      ('Right', LogicalKeyboardKey.arrowRight, 'Right'),
    ]) {
      testWidgets('$name leaves a field that is not being edited', (tester) async {
        runAs(TargetPlatform.android, television: true);
        await showForm(tester, const _Form());
        await focusField(tester);
        await press(tester, key);
        expect(focusedButton(), to);
      });
    }

    for (final (name, key) in [
      ('OK', LogicalKeyboardKey.select),
      ('Enter', LogicalKeyboardKey.enter),
    ]) {
      testWidgets('$name opens the keyboard', (tester) async {
        runAs(TargetPlatform.android, television: true);
        await showForm(tester, const _Form());
        await focusField(tester);
        await press(tester, key);
        expect(keyboardShown(tester), isTrue);
        expect(tester.widget<EditableText>(field).readOnly, isFalse);
      });
    }

    testWidgets("the phone remote's OK opens the keyboard too", (tester) async {
      runAs(TargetPlatform.android, television: true);
      await showForm(tester, const _Form());
      await focusField(tester);
      final (key, physical) = remoteKeys['ok']!;
      expect(dispatchKey(key, physical), isTrue);
      await tester.pump();
      await tester.pump();
      expect(keyboardShown(tester), isTrue);
    });

    testWidgets('OK asks for the keyboard even when the field thinks it is open', (tester) async {
      runAs(TargetPlatform.android, television: true);
      await showForm(tester, const _Form());
      await focusField(tester);
      await press(tester, LogicalKeyboardKey.select);
      // A keyboard that reports no inset, closed behind the field's back.
      tester.testTextInput.hide();
      expect(tester.testTextInput.isVisible, isFalse);
      await press(tester, LogicalKeyboardKey.select);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    for (final obscure in [false, true]) {
      testWidgets('a click opens the keyboard (${obscure ? 'password' : 'text'})', (tester) async {
        runAs(TargetPlatform.android, television: true);
        await showForm(tester, _Form(obscure: obscure));
        await click(tester, field);
        expect(fieldFocused(tester), isTrue);
        expect(keyboardShown(tester), isTrue);
      });
    }

    testWidgets('a field made for typing opens the keyboard by itself', (tester) async {
      runAs(TargetPlatform.android, television: true);
      await showForm(tester, const _Form(autofocus: true));
      await tester.pump();
      expect(fieldFocused(tester), isTrue);
      expect(keyboardShown(tester), isTrue);
    });

    testWidgets('✓ runs the action, closes the keyboard and keeps focus', (tester) async {
      runAs(TargetPlatform.android, television: true);
      final submitted = <String>[];
      await showForm(tester, _Form(onSubmitted: submitted.add));
      await focusField(tester);
      await press(tester, LogicalKeyboardKey.select);
      tester.testTextInput.enterText('New');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(submitted, ['New']);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(fieldFocused(tester), isTrue);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focusedButton(), 'Right');
    });

    testWidgets('Back closing the keyboard ends editing; OK opens it again', (tester) async {
      runAs(TargetPlatform.android, television: true);
      await showForm(tester, const _Form());
      await focusField(tester);
      await press(tester, LogicalKeyboardKey.select);
      tester.view.viewInsets = keyboard;
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(tester.widget<EditableText>(field).readOnly, isFalse);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pump();
      expect(tester.widget<EditableText>(field).readOnly, isTrue);
      expect(fieldFocused(tester), isTrue);
      await press(tester, LogicalKeyboardKey.select);
      expect(keyboardShown(tester), isTrue);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focusedButton(), 'Right', reason: 'leaving ends editing');
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    for (final (name, key, to) in [
      ('Left', LogicalKeyboardKey.arrowLeft, 'Left'),
      ('Right', LogicalKeyboardKey.arrowRight, 'Right'),
    ]) {
      testWidgets('a floating keyboard reports no inset: $name reaching the field still leaves', (tester) async {
        runAs(TargetPlatform.android, television: true);
        await showForm(tester, const _Form());
        await focusField(tester);
        await press(tester, LogicalKeyboardKey.select);
        expect(tester.widget<EditableText>(field).readOnly, isFalse);
        PlatformInfo.dpadArrows.value++; // Android saw it get past the keyboard.
        await press(tester, key);
        expect(focusedButton(), to);
        expect(tester.testTextInput.hasAnyClients, isFalse);
      });
    }

    testWidgets("the keyboard's own caret keys move the caret and leave it open", (tester) async {
      runAs(TargetPlatform.android, television: true);
      await showForm(tester, const _Form());
      await focusField(tester);
      await press(tester, LogicalKeyboardKey.select);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(fieldFocused(tester), isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      final editable = tester.widget<EditableText>(field);
      expect(editable.controller.selection.baseOffset, 'Name'.length - 1);
    });

    testWidgets('a click outside closes the keyboard on release and keeps focus', (tester) async {
      runAs(TargetPlatform.android, television: true);
      await showForm(tester, const _Form());
      await focusField(tester);
      await press(tester, LogicalKeyboardKey.select);
      final mouse = await tester.startGesture(tester.getCenter(find.byKey(const Key('empty'))),
          kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue, reason: 'still pressed');
      await mouse.up();
      await tester.pump();
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(fieldFocused(tester), isTrue);
    });

    testWidgets('Backspace on a field not being edited goes back, as an air mouse sends it', (tester) async {
      runAs(TargetPlatform.android, television: true);
      var backs = 0;
      final text = TextEditingController(text: 'Name');
      addTearDown(text.dispose);
      await showForm(
          tester,
          TvPage(
            title: 'Form',
            onBack: () => backs++,
            child: TvTextField(controller: text, label: 'Field'),
          ));
      await focusField(tester);
      await press(tester, LogicalKeyboardKey.backspace);
      expect(backs, 1);
      await press(tester, LogicalKeyboardKey.select);
      await press(tester, LogicalKeyboardKey.backspace);
      expect(backs, 1, reason: 'while typing it deletes');
    });
  });

  group('on a phone', () {
    testWidgets('focus opens the keyboard, as usual', (tester) async {
      runAs(TargetPlatform.android);
      await showForm(tester, const _Form());
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      expect(keyboardShown(tester), isTrue);
    });

    testWidgets('✓ runs the action, closes the keyboard and gives up focus to the page', (tester) async {
      runAs(TargetPlatform.android);
      final submitted = <String>[];
      await showForm(tester, _Form(onSubmitted: submitted.add));
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      tester.testTextInput.enterText('New');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(submitted, ['New']);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(fieldFocused(tester), isFalse);
      expect(isTvPageFocus(FocusManager.instance.primaryFocus), isTrue, reason: 'Back still works');
    });

    testWidgets('a tap outside closes the keyboard only when the finger lifts', (tester) async {
      runAs(TargetPlatform.android);
      await showForm(tester, const _Form());
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      final finger = await tester.startGesture(tester.getCenter(find.byKey(const Key('empty'))));
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue, reason: 'still pressed');
      await finger.up();
      await tester.pump();
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    testWidgets('a button tapped with the keyboard up closes it and still acts', (tester) async {
      runAs(TargetPlatform.android);
      var pressed = 0;
      final text = TextEditingController();
      addTearDown(text.dispose);
      await showForm(
          tester,
          TvPage(
            title: 'Form',
            child: Column(children: [
              TvTextField(controller: text, label: 'Field'),
              TvButton(label: 'Press', onPressed: () => pressed++),
            ]),
          ));
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Press'));
      await tester.pump();
      await tester.pump();
      expect(pressed, 1);
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    testWidgets("the phone remote's OK brings back a closed keyboard", (tester) async {
      runAs(TargetPlatform.android);
      await showForm(tester, const _Form());
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      tester.testTextInput.hide();
      final (key, physical) = remoteKeys['ok']!;
      dispatchKey(key, physical);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });

  group('on Linux', () {
    testWidgets('focus is typing, and OK leaves nothing to do', (tester) async {
      runAs(TargetPlatform.linux);
      await showForm(tester, const _Form());
      await focusField(tester);
      expect(tester.widget<EditableText>(field).readOnly, isFalse);
      expect(tester.testTextInput.hasAnyClients, isTrue);
    });

    testWidgets('Enter submits and keeps focus, and the keyboard connection stays', (tester) async {
      runAs(TargetPlatform.linux);
      final submitted = <String>[];
      await showForm(tester, _Form(onSubmitted: submitted.add));
      await focusField(tester);
      tester.testTextInput.enterText('New');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, ['New']);
      expect(fieldFocused(tester), isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
    });

    testWidgets('Up and Down move between controls; Left and Right stay in the text', (tester) async {
      runAs(TargetPlatform.linux);
      await showForm(tester, const _Form());
      await focusField(tester);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(fieldFocused(tester), isTrue);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(fieldFocused(tester), isTrue);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focusedButton(), 'Right');
    });

    testWidgets('a click outside drops focus on the press, as it did', (tester) async {
      runAs(TargetPlatform.linux);
      await showForm(tester, const _Form());
      await focusField(tester);
      final mouse = await tester.startGesture(tester.getCenter(find.byKey(const Key('empty'))),
          kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump();
      expect(fieldFocused(tester), isFalse);
      await mouse.up();
    });

    testWidgets('the hints stay beside the back button', (tester) async {
      runAs(TargetPlatform.linux);
      await showForm(tester, TvPage(title: 'Form', hints: 'Keys', onBack: () {}, child: const SizedBox()));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Keys'), findsOneWidget);
    });
  });

  group('renaming a channel', () {
    Future<PortraitHarness> openEditor(WidgetTester tester, Size window, {bool television = false}) async {
      runAs(TargetPlatform.android, television: television);
      setWindow(tester, window);
      final h = await PortraitHarness.start(tester);
      await h.show(tester, const ChannelEditorScreen());
      await tester.pump(const Duration(milliseconds: 500));
      return h;
    }

    testWidgets('on a TV, ✓ saves, closes the keyboard and stays on the page', (tester) async {
      final h = await openEditor(tester, sideways, television: true);
      final ch = h.app.allChannels.first;
      await focusField(tester);
      await press(tester, LogicalKeyboardKey.select);
      tester.testTextInput.enterText('Renamed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ch.name, 'Renamed');
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(find.byType(ChannelEditorScreen), findsOneWidget);
      expect(find.text('Renamed'), findsWidgets, reason: 'the heading and the list row');
      expect(fieldFocused(tester), isTrue);
      await h.end(tester);
    });

    testWidgets('sideways on a phone, Rename saves, closes the keyboard and stays', (tester) async {
      final h = await openEditor(tester, sideways);
      final ch = h.app.allChannels.first;
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      tester.testTextInput.enterText('Renamed');
      await tester.tap(find.text('Rename'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ch.name, 'Renamed');
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(find.byType(ChannelEditorScreen), findsOneWidget);
      await h.end(tester);
    });

    testWidgets('a blank name is not saved, and the box shows the current one', (tester) async {
      final h = await openEditor(tester, sideways);
      final ch = h.app.allChannels.first;
      final name = ch.name;
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      tester.testTextInput.enterText('   ');
      await tester.tap(find.text('Rename'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ch.name, name);
      expect(tester.widget<EditableText>(field).controller.text, name);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      await h.end(tester);
    });

    testWidgets("upright, the channel's page stays, under its new title", (tester) async {
      final h = await openEditor(tester, pixel8);
      final ch = h.app.allChannels[2];
      await tester.ensureVisible(find.text(ch.name).first);
      await tester.pump();
      await tester.tap(find.text(ch.name).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      tester.testTextInput.enterText('Renamed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ch.name, 'Renamed');
      expect(find.text('RENAMED'), findsOneWidget, reason: "the page's title");
      expect(tester.testTextInput.hasAnyClients, isFalse);
      await h.end(tester);
    });
  });

  group('the landscape layout', () {
    Future<PortraitHarness> openEditor(WidgetTester tester, {bool television = false}) async {
      runAs(TargetPlatform.android, television: television);
      setWindow(tester, sideways);
      addTearDown(tester.view.resetViewInsets);
      final h = await PortraitHarness.start(tester);
      await h.show(tester, const ChannelEditorScreen());
      await tester.pump(const Duration(milliseconds: 500));
      return h;
    }

    testWidgets('on a phone the hints and pinned rows give way to the keyboard, and come back unchanged', (tester) async {
      final h = await openEditor(tester);
      expect(find.text('CHANNEL LOGO').hitTestable(), findsOneWidget);
      final hints = find.textContaining('ESC Back');
      expect(hints, findsOneWidget);
      await tester.tap(find.text('3 hours'));
      await tester.pump(const Duration(milliseconds: 300));
      final logoState = tester.state(find.ancestor(of: find.text('3 hours'), matching: find.byType(TvFocusable)));

      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      tester.view.viewInsets = keyboard;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(hints, findsNothing);
      expect(find.text('3 hours').hitTestable(), findsNothing);
      final box = tester.getRect(field);
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(sideways.height - 250), reason: 'above the keyboard');
      expect(box.height, greaterThan(0));

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(hints, findsOneWidget);
      expect(find.text('3 hours').hitTestable(), findsOneWidget);
      expect(tester.state(find.ancestor(of: find.text('3 hours'), matching: find.byType(TvFocusable))), same(logoState),
          reason: 'the same widgets, their state kept');
      expect(h.app.settings.guideRangeHours, 3);
      await h.end(tester);
    });

    testWidgets('a rename scrolls back to the heading the keyboard pushed away', (tester) async {
      final h = await openEditor(tester);
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      tester.view.viewInsets = keyboard;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final scrolled = tester.widget<EditableText>(field).focusNode.context!;
      Scrollable.of(scrolled).position.jumpTo(100);
      await tester.pump();
      tester.testTextInput.enterText('Renamed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(Scrollable.of(tester.widget<EditableText>(field).focusNode.context!).position.pixels, 0);
      await h.end(tester);
    });

    testWidgets('a side panel gives way to the keyboard, its state kept', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, sideways);
      addTearDown(tester.view.resetViewInsets);
      final text = TextEditingController();
      addTearDown(text.dispose);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TvCanvas(child: child!),
          home: AdaptiveColumns(
            sideWidth: 400,
            main: [TvTextField(controller: text, label: 'Field')],
            side: const SizedBox.expand(key: Key('side')),
          )));
      await tester.pump();
      expect(find.byKey(const Key('side')), findsOneWidget);
      tester.view.viewInsets = keyboard;
      await tester.pump();
      expect(find.byKey(const Key('side')), findsNothing);
      expect(find.byKey(const Key('side'), skipOffstage: false), findsOneWidget, reason: 'still in the tree');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a dialog made for typing fits above the keyboard, with no overflow', (tester) async {
      runAs(TargetPlatform.android);
      setWindow(tester, sideways);
      addTearDown(tester.view.resetViewInsets);
      final text = TextEditingController();
      addTearDown(text.dispose);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TvCanvas(child: child!),
          home: Builder(
            builder: (context) => Dialog(
              child: dialogBody(
                context,
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 200),
                  TvTextField(controller: text, label: 'Name', autofocus: true),
                  const SizedBox(height: 200),
                ]),
              ),
            ),
          )));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('a TV keeps its layout under the keyboard', (tester) async {
      final h = await openEditor(tester, television: true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('ESC Back'), findsOneWidget);
      expect(find.text('CHANNEL LOGO').hitTestable(), findsOneWidget);
      await h.end(tester);
    });
  });
}
