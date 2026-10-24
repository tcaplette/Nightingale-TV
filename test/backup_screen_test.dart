import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/platform/backup_files.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/backup_screen.dart';
import 'package:nightingale_tv/ui/login_screen.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'backup_fixtures.dart';
import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  late Household h;
  late Tuner tuner;
  final mom = momAndKids().first;
  String? originalName;

  setUp(() {
    BackupArchive.useIsolate = false;
    BackupFiles.debugAvailable = true;
  });
  tearDown(() {
    BackupArchive.useIsolate = true;
    BackupFiles.debugAvailable = null;
  });

  /// Lets the screen's file work finish: real I/O between frames.
  Future<void> settle(WidgetTester tester, [int rounds = 15]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      // Timers (the tuner stopping, animations) move on too.
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// [settle]s until [done], for as long as a restore takes.
  Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await settle(tester, 1);
    }
    expect(done(), isTrue, reason: 'still waiting');
  }

  /// Mom and Kids, Mom watching, with a backup made by you; then Mom's
  /// first channel renamed, so a restore shows.
  Future<void> setUpHousehold(WidgetTester tester, {String watching = 'Mom'}) async {
    // Wider than the TV's 1920: the test font is wider than Barlow, and the
    // button row would wrap.
    tester.view.physicalSize = const Size(3200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_backup_screen');
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      h = await openHousehold(dir);
      await h.backups!.backUp(BackupReason.manual);
      await h.select(h.profiles.firstWhere((p) => p.name == watching));
      final first = h.app!.allChannels.first;
      originalName = first.name;
      await h.app!.updateChannel(first, name: 'Renamed');
    });
    tuner = Tuner(h.app!, player: FakePlayer([]));
    addTearDown(() async {
      tuner.dispose();
      await tester.runAsync(() async {
        h.leave();
        h.backups!.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await dir.delete(recursive: true);
      });
    });
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: HouseholdScope(household: h, child: AppScope(app: h.app!, tuner: tuner, child: screen)),
    ));
    await settle(tester);
  }

  /// The focused button's label, "row" for a backup in the list.
  String? focused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    final button = context.findAncestorWidgetOfExactType<TvButton>();
    if (button != null) return button.label;
    String? row;
    context.visitAncestorElements((e) {
      final key = e.widget.key;
      if (key is ValueKey<String> && key.value.endsWith(BackupStore.extension)) {
        row = 'row';
        return false;
      }
      return true;
    });
    return row;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await settle(tester, 3);
  }

  Future<String?> firstChannelName(WidgetTester tester) async {
    final channels = await tester.runAsync(() async =>
        await AppStorage.existing(Directory('${dir.path}/profiles/${mom.id}')).readRaw('channels.json') as List);
    return (channels!.first as Map)['name'] as String?;
  }

  testWidgets('the remote moves through the buttons, then the backups', (tester) async {
    await setUpHousehold(tester);
    await show(tester, const BackupScreen());
    expect(find.textContaining('Last backup: today'), findsOneWidget);
    expect(find.textContaining('(made by you)'), findsOneWidget);
    expect(find.text('Made by you'), findsOneWidget);
    expect(focused(), 'Back up now');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Open a backup file');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Use your phone or computer');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'row');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), isNot('row'));

    // Back up now keeps its focus while it works and after.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), 'Back up now');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(focused(), 'Back up now');
    await settleUntil(tester, () => find.text('Made by you').evaluate().length == 2);
    expect(focused(), 'Back up now');
  });

  testWidgets('a backup is restored with the remote alone', (tester) async {
    await setUpHousehold(tester);
    await show(tester, const BackupScreen());
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'row');
    await press(tester, LogicalKeyboardKey.enter);
    expect(focused(), 'Restore');
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.textContaining('Restore the backup from'), findsOneWidget);
    expect(find.textContaining('Your current setup is backed up first.'), findsOneWidget);
    expect(find.textContaining('Mom, Kids · '), findsOneWidget);
    expect(focused(), 'Cancel');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Restore');
    await press(tester, LogicalKeyboardKey.enter);
    // Restored: back to "Who's watching?" (two profiles).
    await settleUntil(tester, () => h.started && h.app == null);

    expect(await firstChannelName(tester), originalName);
    expect(h.profiles.map((p) => p.name), ['Mom', 'Kids']);
    final kinds = await tester.runAsync(() async => [for (final b in await h.backups!.store.list()) b.kind]);
    expect(kinds, contains(BackupReason.beforeRestore));
  });

  testWidgets('Cancel has focus, and Cancel or Back leave everything as it was', (tester) async {
    await setUpHousehold(tester);
    await show(tester, const BackupScreen());
    Future<void> openConfirmation() async {
      await tester.tap(find.byKey(ValueKey(
          (await tester.runAsync(() => h.backups!.store.list()))!.firstWhere((b) => b.kind == BackupReason.manual).name)));
      await settle(tester);
      await tester.tap(find.widgetWithText(TvButton, 'Restore'));
      await settle(tester);
      expect(find.textContaining('Restore the backup from'), findsOneWidget);
      expect(focused(), 'Cancel');
    }

    await openConfirmation();
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.textContaining('Restore the backup from'), findsNothing);
    await openConfirmation();
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.textContaining('Restore the backup from'), findsNothing);

    expect(await firstChannelName(tester), 'Renamed');
    final kinds = await tester.runAsync(() async => [for (final b in await h.backups!.store.list()) b.kind]);
    expect(kinds, [BackupReason.manual]);
  });

  testWidgets('an air mouse points at and clicks, and touch taps', (tester) async {
    // As on a TV: pointing at a button focuses it.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await setUpHousehold(tester);
    await show(tester, const BackupScreen());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.widgetWithText(TvButton, 'Use your phone or computer')));
    await tester.pump();
    expect(focused(), 'Use your phone or computer');
    await mouse.moveTo(tester.getCenter(find.widgetWithText(TvButton, 'Back up now')));
    await tester.pump();
    expect(focused(), 'Back up now');
    await mouse.down(tester.getCenter(find.widgetWithText(TvButton, 'Back up now')));
    await mouse.up();
    await settleUntil(tester, () => find.text('Made by you').evaluate().length == 2);

    // Touch: a tap on a backup opens its actions; Delete, then confirm.
    final names = (await tester.runAsync(() => h.backups!.store.list()))!;
    await tester.tap(find.byKey(ValueKey(names.first.name)));
    await settle(tester);
    expect(find.widgetWithText(TvButton, 'Save to file'), findsOneWidget);
    await tester.tap(find.widgetWithText(TvButton, 'Delete'));
    await settle(tester);
    expect(find.text('Delete this backup?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TvButton, 'Delete'));
    await settleUntil(tester, () => find.text('Made by you').evaluate().length == 1);
  });

  testWidgets('without a file picker, Save to file and Open a backup file are hidden', (tester) async {
    BackupFiles.debugAvailable = false;
    await setUpHousehold(tester);
    await show(tester, const BackupScreen());
    expect(find.widgetWithText(TvButton, 'Open a backup file'), findsNothing);
    expect(find.widgetWithText(TvButton, 'Use your phone or computer'), findsOneWidget);
    final names = (await tester.runAsync(() => h.backups!.store.list()))!;
    await tester.tap(find.byKey(ValueKey(names.first.name)));
    await settle(tester);
    expect(find.widgetWithText(TvButton, 'Restore'), findsOneWidget);
    expect(find.widgetWithText(TvButton, 'Save to file'), findsNothing);
    expect(find.widgetWithText(TvButton, 'Delete'), findsOneWidget);
  });

  testWidgets('the transfer dialog shows an address and a code, with Close focused', (tester) async {
    await setUpHousehold(tester);
    await show(tester, const BackupScreen());
    await tester.tap(find.widgetWithText(TvButton, 'Use your phone or computer'));
    await settle(tester);
    expect(find.text('Use your phone or computer'), findsWidgets);
    expect(find.textContaining(RegExp(r'^http://.+:\d+/b/[0-9a-f]{32}/$')), findsOneWidget);
    expect(focused(), 'Close');
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.textContaining('/b/'), findsNothing);
  });

  testWidgets('on a kid profile, Backup & restore asks for a grown-up\'s PIN', (tester) async {
    await setUpHousehold(tester, watching: 'Kids');
    await show(tester, const MenuScreen());
    await tester.tap(find.widgetWithText(TvButton, 'Backup & restore'));
    await settle(tester);
    expect(find.text('Parental controls'), findsOneWidget);
    expect(find.byType(BackupScreen), findsNothing);
  });

  testWidgets('Welcome back offers the backup; Restore it is focused', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Directory fresh;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_welcome');
      final old = await Directory('${dir.path}/old').create();
      await writeHousehold(old, momAndKids(), fakeLibrary());
      final bytes = (await (await openHousehold(old, start: false)).backups!.build(BackupReason.daily)).bytes;
      fresh = await Directory('${dir.path}/fresh').create();
      final store = BackupStore(Directory('${fresh.path}/backups'));
      await store.cloudDir.create(recursive: true);
      await store.cloudCopy.writeAsBytes(bytes);
      h = await openHousehold(fresh);
    });
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    expect(h.welcomeBack, isNotNull);
    await tester.pumpWidget(NightingaleTvApp(household: h));
    await settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('Mom, Kids · '), findsOneWidget);
    expect(focused(), 'Restore it');
    await press(tester, LogicalKeyboardKey.enter);
    await settleUntil(tester, () => h.started && h.profiles.isNotEmpty);
    await settle(tester);
    expect(h.welcomeBack, isNull);
    expect(h.profiles.map((p) => p.name), ['Mom', 'Kids']);
    expect(find.text('Who\'s watching?'), findsOneWidget);
    expect(find.textContaining('Restored the backup from'), findsOneWidget);
  });

  testWidgets('a new install\'s sign-in offers Restore from a backup', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_first_run');
      h = await openHousehold(dir);
    });
    addTearDown(() => tester.runAsync(() async {
          h.leave();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await dir.delete(recursive: true);
        }));
    expect(h.firstRun, isTrue);
    tuner = Tuner(h.app!, player: FakePlayer([]));
    addTearDown(tuner.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      builder: (context, child) => TvCanvas(child: child!),
      home: HouseholdScope(household: h, child: AppScope(app: h.app!, tuner: tuner, child: const LoginScreen())),
    ));
    await settle(tester);
    await tester.tap(find.widgetWithText(TvButton, 'Restore from a backup'));
    await settle(tester);
    expect(find.widgetWithText(TvButton, 'Open a backup file'), findsOneWidget);
    expect(find.widgetWithText(TvButton, 'Use your phone or computer'), findsOneWidget);
    expect(focused(), 'Open a backup file');
    await press(tester, LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.widgetWithText(TvButton, 'Open a backup file'), findsNothing);

    // Without a file picker (most Android TVs): the phone or computer.
    BackupFiles.debugAvailable = false;
    await tester.tap(find.widgetWithText(TvButton, 'Restore from a backup'));
    await settle(tester);
    expect(find.widgetWithText(TvButton, 'Open a backup file'), findsNothing);
    expect(focused(), 'Use your phone or computer');
    await press(tester, LogicalKeyboardKey.escape);
  });

  testWidgets('a profile added later doesn\'t offer Restore from a backup', (tester) async {
    await setUpHousehold(tester);
    await tester.runAsync(() async {
      h.leave();
      await h.select(h.profiles.first);
      await h.app!.signOut();
    });
    expect(h.firstRun, isFalse);
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      builder: (context, child) => TvCanvas(child: child!),
      home: HouseholdScope(household: h, child: AppScope(app: h.app!, tuner: tuner, child: const LoginScreen())),
    ));
    await settle(tester);
    expect(find.widgetWithText(TvButton, 'Connect'), findsOneWidget);
    expect(find.widgetWithText(TvButton, 'Restore from a backup'), findsNothing);
  });

  testWidgets('a restored profile\'s sign-in is filled in, asking only for the password', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late HttpServer server;
    late AppState app;
    // A real HTTP client, for the local server below.
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
    await tester.runAsync(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((r) async {
        r.response.headers.contentType = ContentType.json;
        r.response.write(r.uri.path == '/System/Info/Public'
            ? '{"ServerName":"Home","Version":"10.10.0","ProductName":"Jellyfin Server","Id":"s1"}'
            : 'false');
        await r.response.close();
      });
      dir = await Directory.systemTemp.createTemp('nightingale_tv_hint');
      final storage = await AppStorage.at(dir);
      await storage.writeJson(AppState.signInHintFile, {
        'serverUrl': 'http://127.0.0.1:${server.port}',
        'serverName': 'Home',
        'serverId': 's1',
        'userName': 'mom',
      });
      await storage.flush();
      h = Household(await AppStorage.at(await Directory('${dir.path}/root').create()), runAnalysis: false);
      app = AppState(storage, runAnalysis: false);
      await app.start();
    });
    addTearDown(() => tester.runAsync(() async {
          await server.close(force: true);
          await app.close();
          await dir.delete(recursive: true);
        }));
    expect(app.phase, AppPhase.signedOut);
    tuner = Tuner(app, player: FakePlayer([]));
    addTearDown(tuner.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      builder: (context, child) => TvCanvas(child: child!),
      home: HouseholdScope(household: h, child: AppScope(app: app, tuner: tuner, child: const LoginScreen())),
    ));
    await settleUntil(tester, () => find.text('Sign in to Home').evaluate().isNotEmpty);
    final user = tester.widget<TvTextField>(find.byWidgetPredicate((w) => w is TvTextField && w.label == 'Username'));
    expect(user.controller.text, 'mom');
    final field = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvTextField>();
    expect(field?.label, 'Password');
    // The sign-in requests' timeouts.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  });
}
