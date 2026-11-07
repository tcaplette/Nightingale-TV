import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/folder_picker_screen.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

/// A Jellyfin with more libraries than fit in the folder picker's column.
class _ManyLibraries extends FakeClient {
  _ManyLibraries() : super([]);

  @override
  Future<List<ServerLibrary>> libraries() async =>
      [for (var i = 0; i < 20; i++) ServerLibrary(id: 'lib$i', name: 'Library $i', collectionType: 'movies')];

  /// Two folders; the second holds 14.
  @override
  Future<List<FolderNode>> folderTree(String libraryId) async => [
        FolderNode(id: 'a', name: 'Folder A', type: 'Folder', children: [
          FolderNode(id: 'a1', name: 'Inside A', type: 'Folder'),
        ]),
        FolderNode(id: 'b', name: 'Folder B', type: 'Folder', children: [
          for (var i = 0; i < 14; i++) FolderNode(id: 'b$i', name: 'Show $i', type: 'Series'),
        ]),
      ];
}

const _genres = [
  'Comedy', 'Drama', 'Action', 'Animation', 'Documentary', 'Crime', //
  'Horror', 'Western', 'Mystery', 'Romance', 'Family', 'Fantasy',
];

void main() {
  const count = 30;
  final nodes = <FocusNode>[];
  final pressed = <int>[];

  setUp(() {
    pressed.clear();
    nodes
      ..clear()
      ..addAll([for (var i = 0; i < count; i++) FocusNode(debugLabel: 'b$i')]);
  });
  tearDown(() {
    for (final n in nodes) {
      n.dispose();
    }
  });

  /// A menu-style page with more buttons than fit.
  Future<void> showMenu(WidgetTester tester, {int? autofocus}) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: TvPage(
        title: 'Menu',
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TvButton(
                  label: 'Button $i',
                  focusNode: nodes[i],
                  autofocus: i == autofocus,
                  onPressed: () => pressed.add(i),
                ),
              ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  double offset(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

  int? focused() {
    final i = nodes.indexWhere((n) => n.hasPrimaryFocus);
    return i < 0 ? null : i;
  }

  /// Whether button [i] is wholly inside the list's viewport.
  bool inView(WidgetTester tester, int i) {
    final list = tester.getRect(find.byType(Scrollable).first);
    final f = find.text('Button $i');
    if (f.evaluate().isEmpty) return false;
    final r = tester.getRect(f);
    return r.top >= list.top && r.bottom <= list.bottom;
  }

  /// The lowest button wholly in view.
  int lowestInView(WidgetTester tester) {
    var last = 0;
    for (var i = 0; i < count; i++) {
      if (inView(tester, i)) last = i;
    }
    return last;
  }

  Future<TestGesture> mouse(WidgetTester tester) async {
    final m = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await m.addPointer(location: Offset.zero);
    addTearDown(m.removePointer);
    return m;
  }

  Future<void> hover(WidgetTester tester, TestGesture m, Finder f) async {
    await m.moveTo(tester.getCenter(f));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets('hovering down the visible buttons focuses each and never scrolls', (tester) async {
    await showMenu(tester);
    final m = await mouse(tester);
    final lowest = lowestInView(tester);
    expect(lowest, greaterThan(3));
    for (var i = 0; i <= lowest; i++) {
      // Slowly: several moves inside each button.
      final r = tester.getRect(find.text('Button $i'));
      for (final dy in [0.2, 0.5, 0.8]) {
        await m.moveTo(Offset(r.center.dx, r.top + r.height * dy));
        await tester.pumpAndSettle();
      }
      expect(focused(), i);
      expect(offset(tester), 0);
    }
    // Clicking the lowest visible one activates it.
    await m.down(tester.getCenter(find.text('Button $lowest')));
    await m.up();
    await tester.pumpAndSettle();
    expect(pressed, [lowest]);
    expect(offset(tester), 0);
  });

  testWidgets('with the pointer parked over the list, ▼ scrolls it and focus follows the keys', (tester) async {
    await showMenu(tester);
    final m = await mouse(tester);
    await hover(tester, m, find.text('Button 2'));
    expect(focused(), 2);
    for (var i = 3; i < count; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), i, reason: 'the button under the pointer took focus');
      expect(inView(tester, i), isTrue);
    }
    expect(offset(tester), greaterThan(0));
  });

  testWidgets('point at the third button, then ▼ focuses the fourth', (tester) async {
    await showMenu(tester);
    final m = await mouse(tester);
    await hover(tester, m, find.text('Button 2'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 3);
  });

  testWidgets('▼ to the fifth button, then pointing at the second focuses it', (tester) async {
    await showMenu(tester, autofocus: 0);
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focused(), 4);
    final m = await mouse(tester);
    await hover(tester, m, find.text('Button 1'));
    expect(focused(), 1);
  });

  testWidgets('the wheel scrolls past the focused button and the list stays put', (tester) async {
    await showMenu(tester);
    final m = await mouse(tester);
    await hover(tester, m, find.text('Button 1'));
    expect(focused(), 1);
    final pointer = TestPointer(2, PointerDeviceKind.mouse)..hover(tester.getCenter(find.text('Button 1')));
    // Not so far that the list drops the button.
    for (var i = 0; i < 2; i++) {
      tester.binding.handlePointerEvent(pointer.scroll(const Offset(0, 200)));
      await tester.pumpAndSettle();
    }
    expect(inView(tester, 1), isFalse);
    final after = offset(tester);
    expect(after, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(offset(tester), after);
    expect(focused(), 1);
  });

  testWidgets('▼ on the lowest visible button still scrolls', (tester) async {
    await showMenu(tester);
    final m = await mouse(tester);
    final lowest = lowestInView(tester);
    await hover(tester, m, find.text('Button $lowest'));
    expect(offset(tester), 0);
    // Move the pointer off the list, as a user reaching for the remote would.
    await m.moveTo(const Offset(5, 5));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), lowest + 1);
    expect(offset(tester), greaterThan(0));
    expect(inView(tester, lowest + 1), isTrue);
  });

  testWidgets('autofocus and requestFocus() from code still scroll into view', (tester) async {
    // Just below the visible ones, so the list has built it.
    await showMenu(tester, autofocus: 11);
    expect(focused(), 11);
    expect(inView(tester, 11), isTrue);
    expect(offset(tester), greaterThan(0));
    // Above the view, but still built.
    expect(inView(tester, 3), isFalse);
    nodes[3].requestFocus();
    await tester.pumpAndSettle();
    expect(inView(tester, 3), isTrue);
    final below = lowestInView(tester) + 1;
    nodes[below].requestFocus();
    await tester.pumpAndSettle();
    expect(inView(tester, below), isTrue);
  });

  testWidgets('a pointer button with onHover reports hover and draws only its owner\'s highlight', (tester) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var hovers = 0;
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: Scaffold(
        body: Center(
          child: TvPointerButton(label: 'Menu', icon: Icons.settings, onPressed: () {}, onHover: () => hovers++),
        ),
      ),
    ));
    final g = GuideTheme.cableGuide;
    Color fill() =>
        (tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration).color!;
    expect(fill(), isNot(g.focus));
    final m = await mouse(tester);
    await hover(tester, m, find.text('Menu'));
    expect(hovers, 1);
    expect(fill(), isNot(g.focus));
  });

  group('signed in', () {
    late Directory dir;
    late AppState app;
    late Tuner tuner;

    Future<void> showApp(WidgetTester tester, Widget child, {FakeClient? client}) async {
      tester.view.physicalSize = TvCanvas.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('nightingale_tv_pointer_focus');
        app = await signedInApp(dir, fakeLibrary(
          shows: {for (var i = 0; i < 24; i++) 'Show $i': 20},
          // A channel per genre: more than the guide shows at once.
          genres: {for (var i = 0; i < 24; i++) 'Show $i': [_genres[i ~/ 2]]},
          // Uneven lengths, so a different cell lands under a still pointer as rows scroll.
          lengths: {for (var i = 0; i < 24; i++) 'Show $i': Duration(minutes: 11 + 13 * (i % 5))},
        ));
        app.client = client ?? FakeClient([]);
      });
      tuner = Tuner(app, player: FakePlayer([]))
        ..prefetch = false
        ..preload = false;
      await tester.pumpWidget(MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: AppScope(app: app, tuner: tuner, child: TvCanvas(child: child)),
      ));
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

    group('folder picker', () {
      Future<void> showPicker(WidgetTester tester) async {
        await showApp(tester, const FolderPickerScreen(initial: [], poolName: 'Commercials'),
            client: _ManyLibraries());
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(find.text('Library 0'), findsOneWidget);
      }

      double libOffset(WidgetTester tester) =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

      bool libFocused(WidgetTester tester, int i) =>
          FocusManager.instance.primaryFocus?.debugLabel == 'lib:lib$i';

      bool libInView(WidgetTester tester, int i) {
        final list = tester.getRect(find.byType(Scrollable).first);
        final f = find.text('Library $i');
        if (f.evaluate().isEmpty) return false;
        final r = tester.getRect(f);
        return r.top >= list.top && r.bottom <= list.bottom;
      }

      testWidgets('hovering the rows focuses them without scrolling', (tester) async {
        await showPicker(tester);
        final m = await mouse(tester);
        var lowest = 0;
        while (libInView(tester, lowest + 1)) {
          lowest++;
        }
        expect(lowest, greaterThan(3));
        for (var i = 0; i <= lowest; i++) {
          await hover(tester, m, find.text('Library $i'));
          expect(libFocused(tester, i), isTrue, reason: 'Library $i');
          expect(libOffset(tester), 0);
        }
      });

      /// The rows drawn with the focus outline.
      int outlined(WidgetTester tester) => tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where((c) => switch (c.decoration) {
                BoxDecoration(border: Border(top: final side)) => side.width == 4 && side.color != Colors.transparent,
                _ => false,
              })
          .length;

      testWidgets('opening a folder leaves one row highlighted', (tester) async {
        await showPicker(tester);
        final m = await mouse(tester);
        await hover(tester, m, find.text('Library 0'));
        // Off to an empty corner of the title bar (the back button is at the other end).
        await m.moveTo(const Offset(1900, 5));
        expect(libFocused(tester, 0), isTrue);
        await press(tester, LogicalKeyboardKey.arrowRight);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'f:b');
        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'f:b0');
        expect(outlined(tester), 1);
      });

      testWidgets('a parked pointer doesn\'t take focus from ▼', (tester) async {
        await showPicker(tester);
        final m = await mouse(tester);
        await hover(tester, m, find.text('Library 2'));
        expect(libFocused(tester, 2), isTrue);
        for (var i = 3; i < 20; i++) {
          await press(tester, LogicalKeyboardKey.arrowDown);
          expect(libFocused(tester, i), isTrue, reason: 'the row under the pointer took focus');
          expect(libInView(tester, i), isTrue);
        }
        expect(libOffset(tester), greaterThan(0));
      });
    });

    group('guide', () {
      Future<void> showGuide(WidgetTester tester) async {
        await showApp(tester, GuideView(onWatch: (_) {}, onClose: () {}, onMenu: () {}));
        await tester.pump();
      }

      /// The channel names in the grid, top to bottom.
      List<String> grid(WidgetTester tester) {
        final names = {for (final c in app.channels) c.name};
        return {
          for (final t in tester.widgetList<Text>(find.byType(Text)))
            if (names.contains(t.data)) t.data!,
        }.toList();
      }

      Future<void> guidePress(WidgetTester tester, LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump(const Duration(milliseconds: 300));
      }

      /// The channel whose row holds the yellow cursor.
      String cursorChannel(WidgetTester tester) {
        final rows = tester
            .widgetList(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_GuideRow'))
            .where((w) => (w as dynamic).focused == true);
        expect(rows, hasLength(1));
        return ((rows.single as dynamic).channel).name as String;
      }

      testWidgets('with the pointer parked over the grid, ▼ moves one channel per press', (tester) async {
        await showGuide(tester);
        final visible = grid(tester);
        expect(app.channels.length, greaterThan(visible.length));
        final m = await mouse(tester);
        // Park the pointer on the second row's programs, right of its channel cell.
        final row = tester.getRect(find.text(visible[1]));
        await m.moveTo(Offset(row.right + 600, row.center.dy));
        await tester.pump(const Duration(milliseconds: 300));
        expect(cursorChannel(tester), visible[1]);
        final names = [for (final c in app.channels) c.name];
        for (var i = 2; i < names.length; i++) {
          await guidePress(tester, LogicalKeyboardKey.arrowDown);
          expect(cursorChannel(tester), names[i], reason: 'the program under the pointer pulled the cursor');
        }
        expect(grid(tester).first, isNot(visible.first), reason: 'the guide scrolled');
      });

      testWidgets('hovering a program selects it', (tester) async {
        await showGuide(tester);
        final visible = grid(tester);
        final m = await mouse(tester);
        final row = tester.getRect(find.text(visible[3]));
        await m.moveTo(Offset(row.right + 600, row.center.dy));
        await tester.pump(const Duration(milliseconds: 300));
        expect(cursorChannel(tester), visible[3]);
      });
    });
  });
}
