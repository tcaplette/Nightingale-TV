// Phone remote test: drives the real app through the remote's web API, the
// way the phone page does. Needs no server. With SNAP_DIR set and Firefox
// installed, it also screenshots the phone page at phone size.
//
//   SNAP_DIR=/tmp/snaps flutter test integration_test/remote_test.dart -d linux
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/remote/remote_control.dart';
import 'package:nightingale_tv/ui/break_plan_editor_screen.dart';
import 'package:nightingale_tv/ui/commercials_screen.dart';
import 'package:nightingale_tv/ui/folder_picker_screen.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/phone_remote_screen.dart';
import 'package:nightingale_tv/ui/pool_editor_screen.dart';

import '../test/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the phone remote drives the TV', (tester) async {
    const shows = {'Cheers': 40, 'Taxi': 30, 'Wings': 30, 'Frasier': 30};
    const genres = {
      'Cheers': ['Comedy'],
      'Taxi': ['Comedy'],
      'Wings': ['Drama'],
      'Frasier': ['Drama'],
    };
    const ads = [Duration(seconds: 30), Duration(seconds: 45), Duration(hours: 2)];
    final h = await UiHarness.start(
      tester,
      fakeLibrary(shows: shows, genres: genres, commercials: ads),
      // A fake server, so the commercials screens can list folders.
      server: fakeItems(shows: shows, genres: genres, commercials: ads),
      reelCuts: {
        'ad-3': [for (var i = 0; i < 20; i++) Span(Duration(seconds: i * 31), Duration(seconds: i * 31 + 30))],
      },
      remote: true,
    );
    final remote = h.household.remote!;
    final http = HttpClient();

    Future<Object?> post(String path, Map<String, Object?> body) async {
      final result = await tester.runAsync(() async {
        final request = await http.postUrl(Uri.parse('http://127.0.0.1:${remote.port}$path'));
        request.headers.contentType = ContentType.json;
        request.headers.set(RemoteControl.actionHeader, '1');
        request.write(jsonEncode(body));
        final response = await request.close();
        return jsonDecode(await utf8.decodeStream(response));
      });
      await h.wait(const Duration(milliseconds: 800));
      return result;
    }

    Future<void> button(String key) => post('/api/key', {'key': key});

    expect(remote.tuner, isNotNull, reason: 'the watching profile\'s tuner is attached');

    await button('menu');
    expect(find.byType(MenuScreen), findsOneWidget);
    await button('back');
    expect(find.byType(MenuScreen), findsNothing);

    await button('guide');
    expect(find.byType(GuideView), findsOneWidget);
    await button('down');
    await button('back');
    expect(find.byType(GuideView), findsNothing);

    final channels = h.app.channels;
    final target = channels[1].number;
    expect(await post('/api/tune', {'number': target}), {'tuned': true});
    expect(h.tuner.channel!.number, target);

    // Number keys, like typing a channel on the remote.
    final other = channels.first.number;
    await button('$other');
    await h.wait(const Duration(seconds: 2));
    expect(h.tuner.channel!.number, other);

    await button('chup');
    expect(h.tuner.channel!.number, isNot(other));

    // The commercials screens, from the phone alone.
    Future<void> remoteTo(String label, String key) async {
      for (var i = 0; i < 15 && h.focusedLabel() != label; i++) {
        await button(key);
      }
      expect(h.focusedLabel(), label, reason: 'the remote\'s "$key" never reached "$label"');
    }

    await button('menu');
    await remoteTo('Commercials', 'down');
    await button('ok');
    expect(find.byType(CommercialsScreen), findsOneWidget);
    await remoteTo('Automatic', 'right');
    await button('ok');
    expect(h.app.settings.commercialPlan.mode, BreakMode.automatic);
    await remoteTo('Custom', 'right');
    await button('ok');
    await remoteTo('Break settings…', 'right');
    await button('ok');
    expect(find.byType(BreakPlanEditorScreen), findsOneWidget);
    await remoteTo('15 s', 'right');
    await button('ok');
    await button('down');
    await remoteTo('10 min', 'right');
    await button('ok');
    await button('back');
    expect(find.text('Leave without saving?'), findsOneWidget);
    await remoteTo('Leave', 'right');
    await button('ok');
    expect(find.byType(CommercialsScreen), findsOneWidget);
    expect(h.app.settings.commercialPlan.roles.preRoll, Duration.zero, reason: 'left without saving');
    await remoteTo('Commercials  ·  1 folder  ·  22 clips', 'down');
    await button('ok');
    expect(find.byType(PoolEditorScreen), findsOneWidget);
    await remoteTo('Add folders…', 'down');
    await button('ok');
    await h.wait(const Duration(seconds: 1));
    expect(find.byType(FolderPickerScreen), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'lib:ads');
    await button('right');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'f:reels');
    await button('ok');
    await button('back');
    await button('back');
    expect(find.byType(PoolEditorScreen), findsOneWidget, reason: 'back out of the picker, unchanged');
    await button('back');
    await button('back');
    await button('back');
    expect(find.byType(MenuScreen), findsNothing);
    await h.snap('r0-after-commercials');

    // The menu screen that turns it on, with the QR code.
    await h.openMenuItem('Phone remote');
    expect(find.byType(PhoneRemoteScreen), findsOneWidget);
    await h.snap('r1-phone-remote-screen');

    // The phone page itself, in a phone-sized headless Firefox.
    final snapDir = Platform.environment['SNAP_DIR'];
    if (snapDir != null && File('/usr/bin/firefox').existsSync()) {
      await tester.runAsync(() async {
        // Snap Firefox can only write inside its own folder.
        final work = Directory('${Platform.environment['HOME']}/snap/firefox/common/nightingale-tv-remote-test');
        await work.create(recursive: true);
        try {
          final shot = '${work.path}/remote.png';
          final result = await Process.run('firefox', [
            '--headless',
            '--no-remote',
            '--profile',
            work.path,
            '--window-size=412,915',
            '--screenshot',
            shot,
            'http://127.0.0.1:${remote.port}/',
          ]).timeout(const Duration(seconds: 60));
          if (File(shot).existsSync()) {
            await File(shot).copy('$snapDir/r2-phone-page.png');
          } else {
            debugPrint('Firefox screenshot failed: ${result.stderr}');
          }
        } finally {
          await work.delete(recursive: true);
        }
      });
    }

    http.close();
    await h.dispose();
  });
}
