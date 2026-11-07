import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_set.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/servers_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'backup_fixtures.dart';
import 'fake_playback.dart';
import 'fixtures.dart';

/// Menu → Servers on the TV (multi-server 7.1): rows, Move up/down, quality
/// limit and Remove, by D-pad and by touch.
void main() {
  late Directory dir;
  late Household h;
  late Tuner tuner;

  Future<void> settle(WidgetTester tester, [int rounds = 15]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(3200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('servers_screen');
      await writeHousehold(dir, momAndKids().take(1).toList(), fakeLibrary());
      h = await openHousehold(dir);
      await h.select(h.profiles.first);
      final plex = ServerSession(
          kind: ServerKind.plex,
          serverUrl: 'http://plex.example:32400',
          serverName: 'Basement Plex',
          serverId: 'plex-1',
          userId: '7',
          userName: 'dad',
          accessToken: 't',
          deviceId: 'd');
      await h.app!.addServer(plex, FakeClient([], serverUrl: plex.serverUrl), refresh: false);
    });
    tuner = Tuner(h.app!, player: FakePlayer([]));
    addTearDown(() async {
      tuner.dispose();
      await tester.runAsync(() async {
        final app = h.app;
        h.leave();
        h.backups!.dispose();
        // Writes still under way finish before the folder goes.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await app?.storage.flush().timeout(const Duration(seconds: 2), onTimeout: () {});
        await dir.delete(recursive: true);
      });
    });
    // The scopes above the app, as main() has them, so pushed screens see them.
    await tester.pumpWidget(HouseholdScope(
      household: h,
      child: AppScope(
        app: h.app!,
        tuner: tuner,
        child: MaterialApp(theme: GuideTheme.cableGuide.toThemeData(), home: const ServersScreen()),
      ),
    ));
    await settle(tester);
  }

  String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

  testWidgets('every server is listed with its kind, state and user; the main one has no Remove', (tester) async {
    await start(tester);
    expect(find.textContaining('Basement Plex'), findsWidgets);
    expect(find.textContaining('Plex · OK'), findsOneWidget);
    expect(find.textContaining('Main server'), findsOneWidget);
    expect(find.textContaining('Signed in as dad'), findsOneWidget);
    expect(find.text('Signing out of this profile changes its main server.'), findsOneWidget);
    expect(find.widgetWithText(TvButton, 'Remove'), findsOneWidget);
    expect(focused(), 'Add a server');
  });

  testWidgets('Move up with the D-pad puts Plex first, kept after a restart', (tester) async {
    await start(tester);
    // Down to the Plex row's buttons: Move up is its first enabled one.
    for (var i = 0; i < 12 && !(focused() == 'Move up' && _onRowOf(tester, 'Basement Plex')); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester, 3);
      if (focused() == 'Move down' && !_onRowOf(tester, 'Basement Plex')) continue;
    }
    expect(focused(), 'Move up');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(h.app!.servers.order, ['s2', ServerSet.mainKey]);
    await tester.runAsync(() async {
      final again = await openHousehold(dir);
      await again.select(again.profiles.first);
      expect(again.app!.servers.order, ['s2', ServerSet.mainKey]);
      final reopened = again.app;
      again.leave();
      again.backups!.dispose();
      // Its writes finish before the folder goes.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await reopened?.storage.flush().timeout(const Duration(seconds: 2), onTimeout: () {});
    });
  });

  testWidgets('a quality limit and Remove by touch', (tester) async {
    await start(tester);
    await tester.tap(find.widgetWithText(TvButton, 'Quality limit').last);
    await settle(tester);
    await tester.tap(find.text('2 Mbps'));
    // The page's pop transition ends before the next tap.
    await settle(tester, 30);
    expect(h.app!.servers.byKey('s2')!.qualityLimit, 2000000);
    expect(find.textContaining('Quality: 2 Mbps'), findsOneWidget);
    await tester.tap(find.widgetWithText(TvButton, 'Remove'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TvButton, 'Remove').last);
    await settle(tester, 40);
    expect(h.app!.servers.multiple, isFalse);
    expect(find.textContaining('Basement Plex'), findsNothing);
  });
}

/// Whether focus is inside the card that names [server].
bool _onRowOf(WidgetTester tester, String server) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var found = false;
  context.visitAncestorElements((e) {
    if (e.widget is Column) {
      final texts = find.descendant(of: find.byElementPredicate((x) => x == e), matching: find.textContaining(server));
      if (texts.evaluate().isNotEmpty) {
        found = true;
        return false;
      }
    }
    return true;
  });
  return found;
}
