// The Live TV export screen: PINs, kid profiles, and settings that last.
// Needs no server.
//
//   SNAP_DIR=/tmp/snaps flutter test integration_test/live_tv_export_test.dart -d linux
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/ui/live_tv_export_screen.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

import '../test/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export settings, PINs and kid profiles', (tester) async {
    final library = fakeLibrary(shows: {'Cheers': 40, 'Taxi': 30});
    final h = await UiHarness.start(tester, library, export: true);
    final household = h.household;
    final service = household.export!;

    Future<void> typePin(String pin) async {
      for (final d in pin.split('')) {
        await h.press(LogicalKeyboardKey(0x30 + int.parse(d)), after: const Duration(milliseconds: 200));
      }
      await h.wait(const Duration(milliseconds: 600));
    }

    // A grown-up with a PIN, and a kid who has signed in.
    final grownUp = household.current!..setPin('1234');
    late final Profile kid;
    await tester.runAsync(() async {
      await household.saveProfile(grownUp);
      kid = household.newProfile()
        ..name = 'Sam'
        ..kind = ProfileKind.kid
        ..rating = KidRating.young;
      await household.saveProfile(kid);
      final storage = await household.storageFor(kid);
      await storage.writeJson('session.json', {
        'serverUrl': 'http://127.0.0.1:9',
        'userId': 'u2',
        'userName': 'sam',
        'accessToken': 'none',
        'deviceId': 'test',
      });
      await storage.writeJson('library.json', library.toJson());
      await storage.writeJson(
          'channels.json', [for (final c in ChannelGenerator(library).generate()) c.toJson()]);
    });

    // 1. The grown-up opens the screen: off to begin with.
    await h.openMenuItem('Live TV export');
    expect(find.byType(LiveTvExportScreen), findsOneWidget);
    expect(find.text(LiveTvExportScreen.intro), findsOneWidget);
    await h.snap('x1-export-off');
    await h.tap('Live TV export');
    expect(service.settings.enabled, isTrue);

    // 2. Exporting a profile with a PIN asks for that PIN.
    await h.tap('${grownUp.name}: export this lineup');
    expect(find.text('PIN for ${grownUp.name}'), findsOneWidget);
    await typePin('0000');
    expect(find.text('That PIN isn\'t right. Try again.'), findsOneWidget);
    await typePin('1234');
    await h.wait(const Duration(seconds: 1));
    expect(service.settings.isExported(grownUp.id), isTrue);
    expect(find.text(LiveTvExportScreen.homeNetworkNotice), findsWidgets);
    expect(find.textContaining('/lineup.m3u'), findsOneWidget);

    // A kid's lineup needs no PIN of its own (the screen is behind one).
    await h.tap('${kid.name} (kid): export this lineup');
    await h.wait(const Duration(seconds: 1));
    expect(service.settings.isExported(kid.id), isTrue);
    await h.snap('x2-two-lineups');

    // 3. The settings last.
    final saved = service.settings;
    await tester.runAsync(() async {
      final again = ExportService(household, ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {});
      final before = household.exportStreaming.value;
      await again.load();
      expect(again.settings, saved);
      await again.stop();
      expect(household.exportStreaming.value, before);
      // The first service's servers are still the ones running.
      await service.setQuality(service.settings.quality);
    });

    // 4. Over to the kid: the screen asks for a grown-up's PIN.
    while (find.byType(TvScreen).evaluate().isEmpty || find.byType(MenuScreen).evaluate().isNotEmpty) {
      await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    }
    await tester.runAsync(() => household.select(kid));
    await h.wait(const Duration(seconds: 2));
    await h.openMenuItem('Live TV export');
    expect(find.byType(LiveTvExportScreen), findsNothing);
    await h.snap('x3-kid-pin');
    await typePin('1234');
    await h.wait(const Duration(seconds: 1));
    expect(find.byType(LiveTvExportScreen), findsOneWidget);

    await h.dispose();
  });
}
