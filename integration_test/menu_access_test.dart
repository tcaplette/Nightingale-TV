// Getting to the menu with an air mouse or a remote that has no Menu key.
// Needs no server.
//
//   SNAP_DIR=/tmp/snaps flutter test integration_test/menu_access_test.dart -d linux
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';

import '../test/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the menu is reachable by pointer and by arrow keys', (tester) async {
    final h = await UiHarness.start(
      tester,
      fakeLibrary(
        shows: {'Cheers': 40, 'Taxi': 30, 'Wings': 30},
        genres: {
          'Cheers': ['Comedy'],
          'Taxi': ['Comedy'],
          'Wings': ['Drama'],
        },
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));

    Future<void> backToTv() async {
      while (find.byType(MenuScreen).evaluate().isNotEmpty || find.byType(GuideView).evaluate().isNotEmpty) {
        await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
      }
    }

    // 1. On the TV screen, moving the air mouse shows Guide and Menu buttons.
    await h.wait(const Duration(seconds: 6)); // let the power-on banner fade
    await mouse.moveTo(const Offset(600, 500));
    await h.wait(const Duration(milliseconds: 600));
    await h.snap('m1-tv-pointer-buttons');
    await tester.tap(find.text('Menu'), kind: PointerDeviceKind.mouse);
    await h.wait(const Duration(seconds: 1));
    expect(find.byType(MenuScreen), findsOneWidget);
    await backToTv();

    // 2. In the guide, Up from the top channel reaches the Menu button.
    await h.press(LogicalKeyboardKey.keyG, after: const Duration(seconds: 1));
    expect(find.byType(GuideView), findsOneWidget);
    for (var i = 0; i < h.app.channels.length; i++) {
      await h.press(LogicalKeyboardKey.arrowUp, after: const Duration(milliseconds: 200));
    }
    await h.snap('m2-guide-menu-highlighted');
    await h.press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    expect(find.byType(MenuScreen), findsOneWidget);
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    expect(find.byType(GuideView), findsOneWidget, reason: 'back from the menu returns to the guide');

    // Down from the Menu button goes to the tabs, and Down again back to
    // the channels.
    await h.press(LogicalKeyboardKey.arrowUp);
    await h.press(LogicalKeyboardKey.arrowDown);
    await h.press(LogicalKeyboardKey.arrowDown);
    await h.press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    expect(find.byType(GuideView), findsNothing, reason: 'OK on a channel watches it');

    // 3. The "M Menu" hint in the guide can be clicked.
    await h.press(LogicalKeyboardKey.keyG, after: const Duration(seconds: 1));
    await tester.tap(find.text('M Menu'), kind: PointerDeviceKind.mouse);
    await h.wait(const Duration(seconds: 1));
    expect(find.byType(MenuScreen), findsOneWidget);
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));

    // 4. Right-click in the guide opens the menu too.
    await tester.tap(find.byType(GuideView), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await h.wait(const Duration(seconds: 1));
    expect(find.byType(MenuScreen), findsOneWidget);
    await backToTv();

    await mouse.removePointer();
    await h.dispose();
  });
}
