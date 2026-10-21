// One press of Back is one Back, whether Android delivers it as a key, as a
// pop, or (Android TV remotes) as a key and then a pop.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/platform/android_back_bridge.dart';

void main() {
  late DateTime now;
  late List<LogicalKeyboardKey> sent;
  late AndroidBackBridge bridge;

  setUp(() {
    now = DateTime(2026, 10, 20, 20);
    sent = [];
  });

  void later(int ms) => now = now.add(Duration(milliseconds: ms));

  /// An app whose screen [takesBack] (or not), with [bridge] set up as
  /// main() sets it up; the screen has focus.
  Future<void> show(WidgetTester tester, {required bool takesBack}) async {
    bridge = AndroidBackBridge(
      dispatch: (key, physical) {
        sent.add(key);
        return takesBack;
      },
      clock: () => now,
    );
    tester.binding.addObserver(bridge);
    HardwareKeyboard.instance.addHandler(bridge.handleKey);
    addTearDown(() {
      tester.binding.removeObserver(bridge);
      HardwareKeyboard.instance.removeHandler(bridge.handleKey);
    });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => BackKeyWatcher(bridge: bridge, child: child!),
      home: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (!AndroidBackBridge.isBack(event)) return KeyEventResult.ignored;
          if (event is KeyDownEvent) sent.add(event.logicalKey);
          return takesBack ? KeyEventResult.handled : KeyEventResult.ignored;
        },
        child: const SizedBox.expand(),
      ),
    ));
    await tester.pump();
  }

  /// The remote's Back key, as Android TV delivers it: down, up.
  Future<void> backKey(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
  }

  testWidgets('a key and then its pop: one Back', (tester) async {
    await show(tester, takesBack: true);
    await backKey(tester);
    later(3);
    expect(await bridge.didPopRoute(), isTrue, reason: 'taken: nothing more happens');
    expect(sent, hasLength(1));
  });

  testWidgets('two presses in a row are two Backs (the second quits)', (tester) async {
    await show(tester, takesBack: true);
    await backKey(tester);
    await bridge.didPopRoute();
    later(300);
    await backKey(tester);
    await bridge.didPopRoute();
    expect(sent, hasLength(2));
  });

  testWidgets('a pop alone (the back gesture) goes to the screen', (tester) async {
    await show(tester, takesBack: true);
    expect(await bridge.didPopRoute(), isTrue);
    expect(sent, hasLength(1));
    later(1000);
    expect(await bridge.didPopRoute(), isTrue);
    expect(sent, hasLength(2));
  });

  testWidgets('a key no screen takes leaves its pop to the Navigator', (tester) async {
    await show(tester, takesBack: false);
    await backKey(tester);
    later(3);
    expect(await bridge.didPopRoute(), isFalse, reason: 'the Navigator pops (a dialog closes)');
    expect(sent, hasLength(1), reason: 'not sent again');
  });

  testWidgets('with nothing focused, the pop goes to the Navigator too', (tester) async {
    await show(tester, takesBack: true);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await backKey(tester);
    later(3);
    expect(await bridge.didPopRoute(), isFalse);
  });

  testWidgets('a pop long after a key is a press of its own', (tester) async {
    await show(tester, takesBack: true);
    await backKey(tester);
    later(1000);
    expect(await bridge.didPopRoute(), isTrue);
    expect(sent, hasLength(2));
  });
}
