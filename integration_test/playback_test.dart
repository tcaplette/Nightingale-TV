// Menu → Playback: behind the grown-up PIN on a kid profile, and usable
// with arrow keys alone. Needs no server.
//
//   SNAP_DIR=/tmp/snaps flutter test integration_test/playback_test.dart -d linux
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/playback_screen.dart';

import '../test/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a kid needs the PIN for Playback; a grown-up sets it up with arrow keys', (tester) async {
    final h = await UiHarness.start(tester, fakeLibrary(shows: {'Cheers': 40, 'Taxi': 30}));
    final household = h.household;
    // A PIN-locked grown-up, and the profile watching turned into a kid's.
    await tester.runAsync(() async {
      await household.saveProfile(household.newProfile()
        ..name = 'Parent'
        ..setPin('1234'));
      await household.saveProfile(household.current!.copy()
        ..kind = ProfileKind.kid
        ..rating = KidRating.older);
    });
    await h.wait(const Duration(seconds: 2));
    expect(household.current!.isKid, isTrue);
    expect(h.app.settings.playback, PlaybackSettings.off);

    // The kid picks Playback: the PIN comes first.
    await h.press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
    expect(find.byType(MenuScreen), findsOneWidget);
    await h.choose('Playback', LogicalKeyboardKey.arrowDown);
    expect(find.byType(PlaybackScreen), findsNothing);
    expect(find.text('Enter a grown-up\'s PIN.'), findsOneWidget);
    await h.snap('pb1-pin');
    for (final d in '1234'.split('')) {
      await h.press(LogicalKeyboardKey(0x30 + int.parse(d)), after: const Duration(milliseconds: 200));
    }
    await h.wait(const Duration(seconds: 1));
    expect(find.byType(PlaybackScreen), findsOneWidget);
    await h.snap('pb2-off');

    // Off: the toggle has focus, and the bitrate list can't be reached.
    expect(h.focusedLabel(), PlaybackScreen.toggleLabel);
    await h.press(LogicalKeyboardKey.arrowDown, after: const Duration(milliseconds: 300));
    expect(h.focusedLabel(), PlaybackScreen.toggleLabel, reason: 'the bitrate choice is disabled');
    expect(find.text(PlaybackScreen.toggleHelp), findsOneWidget);

    // On, then 8 Mbps, with arrows and OK only.
    await h.press(LogicalKeyboardKey.enter, after: const Duration(milliseconds: 700));
    expect(h.app.settings.playback.transcodeIfNeeded, isTrue);
    await h.choose('8 Mbps · 1080p', LogicalKeyboardKey.arrowDown);
    await h.snap('pb3-8mbps');
    await tester.scrollUntilVisible(find.text(PlaybackScreen.bitrateHelp), 200, scrollable: find.byType(Scrollable).last);
    expect(h.app.settings.playback, const PlaybackSettings(transcodeIfNeeded: true, maxBitrateMbps: 8));

    // Saved for next time.
    final saved = await tester.runAsync(() => h.app.storage.readJson('settings.json')) as Map<String, Object?>;
    expect(saved['playback'], {'transcodeIfNeeded': true, 'maxBitrateMbps': 8});

    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    expect(find.byType(MenuScreen), findsOneWidget);
    await h.dispose();
  });
}
