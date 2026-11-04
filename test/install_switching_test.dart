import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/platform/backup_files.dart';
import 'package:nightingale_tv/platform/install_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/backup_screen.dart';
import 'package:nightingale_tv/ui/install_switching.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'backup_fixtures.dart';
import 'fake_playback.dart';
import 'fixtures.dart';

const ownBuild = InstallInfo(ownBuild: true);
const ownBuildBeside = InstallInfo(ownBuild: true, counterpartInstalled: true, counterpartFirstInstallTime: 1000);
const play = InstallInfo(ownBuild: false, installer: InstallInfo.googlePlayInstaller);
const playBeside = InstallInfo(
    ownBuild: false, installer: InstallInfo.googlePlayInstaller, counterpartInstalled: true, counterpartFirstInstallTime: 2000);

void main() {
  group('what kind of install', () {
    test('the installer names the source; an own build is always one', () {
      expect(play.source, InstallSource.googlePlay);
      expect(const InstallInfo(ownBuild: false).source, InstallSource.officialApk);
      expect(const InstallInfo(ownBuild: false, installer: 'org.example.otherstore').source, InstallSource.officialApk);
      expect(const InstallInfo(ownBuild: false, installer: 'com.google.android.packageinstaller').source,
          InstallSource.officialApk);
      expect(const InstallInfo(ownBuild: true, installer: InstallInfo.googlePlayInstaller).source, InstallSource.ownBuild);
    });

    test('each install type has its own line and switching text', () {
      expect(play.sourceLine, 'Installed from Google Play');
      expect(play.switching, contains('install over this one and keep your setup'));
      expect(play.switching, contains('separate app, "Nightingale TV (own build)"'));
      expect(const InstallInfo(ownBuild: false).sourceLine, 'Official Nightingale TV APK');
      expect(ownBuild.sourceLine, 'Your own build');
      expect(ownBuild.switching, contains('separate app, "Nightingale TV"'));
      expect(ownBuild.switching, contains('Buying it supports the project'));
    });

    test('the names of this app and the other one', () {
      expect(ownBuild.appName, 'Nightingale TV (own build)');
      expect(ownBuild.counterpartName, 'Nightingale TV');
      expect(play.appName, 'Nightingale TV');
      expect(play.counterpartName, 'Nightingale TV (own build)');
    });

    test('read from the platform channel', () {
      final info = InstallInfo.fromMap({
        'ownBuild': true,
        'installer': null,
        'counterpartInstalled': true,
        'counterpartInstaller': 'com.android.vending',
        'counterpartFirstInstallTime': 1730000000000,
      });
      expect(info.ownBuild, isTrue);
      expect(info.counterpartInstalled, isTrue);
      expect(info.counterpartFirstInstallTime, 1730000000000);
    });

    test('no install info off Android', () async {
      expect(await InstallSwitching.info(), isNull);
    });

    test('moved and handed-over backups have their labels, and aren\'t this setup', () {
      expect(BackupReason.isReceived(BackupReason.fromOfficial), isTrue);
      expect(BackupReason.isReceived(BackupReason.fromOwnBuild), isTrue);
      expect(BackupReason.isReceived(BackupReason.file), isTrue);
      expect(BackupReason.isReceived(BackupReason.movingToOfficial), isFalse);
      expect(BackupReason.isSafety(BackupReason.movingToOwnBuild), isFalse);
    });
  });

  late Directory dir;
  late Household h;
  late Tuner tuner;
  late List<Uint8List?> sent;

  setUp(() {
    BackupArchive.useIsolate = false;
    BackupFiles.debugAvailable = true;
    debugResetInstallNotice();
    sent = [];
    InstallSwitching.debugSend = (bytes) async {
      sent.add(bytes);
      return true;
    };
  });
  tearDown(() {
    BackupArchive.useIsolate = true;
    BackupFiles.debugAvailable = null;
    InstallSwitching.debugReset();
  });

  Future<void> settle(WidgetTester tester, [int rounds = 15]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await settle(tester, 1);
    }
    expect(done(), isTrue, reason: 'still waiting');
  }

  Future<void> setUpHousehold(WidgetTester tester) async {
    tester.view.physicalSize = const Size(3200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_install_switching');
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      h = await openHousehold(dir);
      await h.backups!.backUp(BackupReason.manual);
      await h.select(h.profiles.firstWhere((p) => p.name == 'Mom'));
      final first = h.app!.allChannels.first;
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

  /// [screen] inside the host, as the app's shell has it.
  Future<void> show(WidgetTester tester, Widget screen) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(HouseholdScope(
      household: h,
      child: AppScope(
        app: h.app!,
        tuner: tuner,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: GuideTheme.cableGuide.toThemeData(),
          builder: (context, child) => InstallSwitchingHost(household: h, navigator: navigator, child: child!),
          home: screen,
        ),
      ),
    ));
    await settle(tester);
  }

  String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await settle(tester, 3);
  }

  Future<List<StoredBackup>> stored(WidgetTester tester) async =>
      (await tester.runAsync(() => h.backups!.store.list()))!;

  group('About this install', () {
    testWidgets('an own build says so, with the uninstall warning, and no move buttons alone', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = ownBuild;
      await show(tester, const BackupScreen());
      expect(find.text('ABOUT THIS INSTALL'), findsOneWidget);
      expect(find.text('Your own build'), findsOneWidget);
      expect(find.textContaining('The store version installs beside this one'), findsOneWidget);
      expect(find.text(InstallInfo.uninstallWarning), findsOneWidget);
      expect(find.textContaining('Move my setup'), findsNothing);
      // Back up now still has focus.
      expect(focused(), 'Back up now');
    });

    testWidgets('a Play install says so and that own builds are separate', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = play;
      await show(tester, const BackupScreen());
      expect(find.text('Installed from Google Play'), findsOneWidget);
      expect(find.textContaining('A build of your own installs as a separate app'), findsOneWidget);
      expect(find.text(InstallInfo.uninstallWarning), findsOneWidget);
    });

    testWidgets('not off Android', (tester) async {
      await setUpHousehold(tester);
      await show(tester, const BackupScreen());
      expect(find.text('ABOUT THIS INSTALL'), findsNothing);
      expect(find.text('Back up now'), findsOneWidget);
    });

    testWidgets('Move my setup with the remote backs up and hands the backup over', (tester) async {
      await setUpHousehold(tester);
      // The notice for this install of the other app was already shown.
      await tester.runAsync(() => h.root.writeJson(InstallSwitchingHost.noticeFile, {'counterpartFirstInstallTime': 1000}));
      InstallSwitching.debugInfo = ownBuildBeside;
      await show(tester, const BackupScreen());
      expect(focused(), 'Back up now');
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'Move my setup to Nightingale TV');
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(focused(), 'Bring my setup here from Nightingale TV');
      await press(tester, LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleUntil(tester, () => sent.isNotEmpty);
      final archive = BackupArchive.check(sent.single!);
      expect(archive.summary.profiles, ['Mom', 'Kids']);
      await settleUntil(tester, () => find.text('Moving to Nightingale TV').evaluate().isNotEmpty);
      expect(find.text('Moving to Nightingale TV'), findsOneWidget);
      expect(focused(), 'Move my setup to Nightingale TV');
    });

    test('Move with nothing set up says so and sends nothing', () async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_install_switching');
      addTearDown(() => dir.delete(recursive: true));
      // A new install's profile that never signed in, after a restart.
      await writeHousehold(dir, momAndKids().take(1).toList(), fakeLibrary());
      final profile = AppStorage.existing(Directory('${dir.path}/profiles/${momAndKids().first.id}'));
      await profile.delete('session.json');
      await profile.delete('channels.json');
      await profile.flush();
      h = await openHousehold(dir);
      addTearDown(() => h.backups!.dispose());
      expect(await h.hasNoSetup(), isTrue);
      await expectLater(moveSetupTo(h, ownBuildBeside), throwsA(isA<BackupException>()));
      expect(sent, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('Bring my setup here asks the other app, by touch', (tester) async {
      await setUpHousehold(tester);
      await tester.runAsync(() => h.root.writeJson(InstallSwitchingHost.noticeFile, {'counterpartFirstInstallTime': 2000}));
      InstallSwitching.debugInfo = playBeside;
      await show(tester, const BackupScreen());
      await tester.tap(find.widgetWithText(TvButton, 'Bring my setup here from Nightingale TV (own build)'));
      await settleUntil(tester, () => sent.isNotEmpty);
      expect(sent.single, isNull);
    });
  });

  group('the both-installed notice', () {
    testWidgets('in an own build: thanks, the warning, the move buttons, Not now focused', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = ownBuildBeside;
      await show(tester, const Scaffold());
      expect(find.text('Nightingale TV is also on this device'), findsOneWidget);
      expect(find.text('Thank you for supporting Nightingale TV!'), findsOneWidget);
      expect(find.textContaining('before moving the setup you want to keep deletes that setup'), findsOneWidget);
      expect(find.widgetWithText(TvButton, 'Move my setup to Nightingale TV'), findsOneWidget);
      expect(find.widgetWithText(TvButton, 'Bring my setup here from Nightingale TV'), findsOneWidget);
      expect(focused(), 'Not now');
    });

    testWidgets('a screen arriving under the notice doesn\'t take its focus', (tester) async {
      await setUpHousehold(tester);
      // As on a TV (main.dart).
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      InstallSwitching.debugInfo = ownBuildBeside;
      final arrived = ValueNotifier(false);
      // Like the TV screen after syncing: built later, with autofocus.
      await show(
          tester,
          ValueListenableBuilder(
            valueListenable: arrived,
            builder: (context, on, _) => on ? const Focus(autofocus: true, child: SizedBox()) : const SizedBox(),
          ));
      expect(focused(), 'Not now');
      arrived.value = true;
      await settle(tester);
      expect(focused(), 'Not now');
      // The remote moves between the notice's buttons, not the screen's.
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), isIn(['Move my setup to Nightingale TV', 'Bring my setup here from Nightingale TV']));
    });

    testWidgets('a field autofocused in the same frame as the notice doesn\'t take its focus', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = ownBuildBeside;
      // Built as the notice opens (the screen under it stops being current),
      // so both autofocus in one frame and the field's goes last.
      await show(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: ModalRoute.of(context)!.isCurrent
                  ? const SizedBox()
                  : const FocusScope(child: TextField(autofocus: true)),
            ),
          ));
      expect(find.byType(TextField), findsOneWidget);
      expect(focused(), 'Not now');
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('a sign-in field under the notice doesn\'t take its focus', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = ownBuildBeside;
      await show(tester, const Scaffold(body: FocusScope(child: TextField(autofocus: true))));
      expect(focused(), 'Not now');
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('in the official app: no thanks, the own build named', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = playBeside;
      await show(tester, const Scaffold());
      expect(find.text('Nightingale TV (own build) is also on this device'), findsOneWidget);
      expect(find.text('Thank you for supporting Nightingale TV!'), findsNothing);
      expect(find.widgetWithText(TvButton, 'Move my setup to Nightingale TV (own build)'), findsOneWidget);
    });

    testWidgets('shown once per install of the other app', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = ownBuildBeside;
      await show(tester, const Scaffold());
      await press(tester, LogicalKeyboardKey.enter); // Not now
      await settle(tester);
      expect(find.textContaining('is also on this device'), findsNothing);

      // Restarted: not again, and About this install keeps the buttons.
      debugResetInstallNotice();
      await tester.pumpWidget(const SizedBox());
      await show(tester, const BackupScreen());
      expect(find.textContaining('is also on this device'), findsNothing);
      expect(find.widgetWithText(TvButton, 'Move my setup to Nightingale TV'), findsOneWidget);

      // The other app reinstalled: shown again.
      debugResetInstallNotice();
      InstallSwitching.debugInfo =
          const InstallInfo(ownBuild: true, counterpartInstalled: true, counterpartFirstInstallTime: 5000);
      await tester.pumpWidget(const SizedBox());
      await show(tester, const Scaffold());
      expect(find.text('Nightingale TV is also on this device'), findsOneWidget);
    });

    testWidgets('Move from the notice hands the setup over', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = ownBuildBeside;
      await show(tester, const Scaffold());
      await tester.tap(find.widgetWithText(TvButton, 'Move my setup to Nightingale TV'));
      await settleUntil(tester, () => sent.isNotEmpty);
      expect(BackupArchive.check(sent.single!).summary.profiles, ['Mom', 'Kids']);
    });
  });

  group('a setup handed over', () {
    Future<void> noNotice(WidgetTester tester) async {
      InstallSwitching.debugInfo = playBeside;
      await tester.runAsync(() => h.root.writeJson(InstallSwitchingHost.noticeFile, {'counterpartFirstInstallTime': 2000}));
    }

    testWidgets('is kept as From …, and restored after the usual confirmation', (tester) async {
      await setUpHousehold(tester);
      await noNotice(tester);
      final backup = (await tester.runAsync(() async => h.backups!.store.read((await h.backups!.store.list()).first)))!;
      await show(tester, const Scaffold());
      InstallSwitching.pending.value = SetupReceived(backup);
      await settleUntil(tester, () => find.textContaining('Restore the backup from').evaluate().isNotEmpty);
      expect(find.textContaining('Your current setup is backed up first.'), findsOneWidget);
      expect(focused(), 'Cancel');
      expect((await stored(tester)).map((b) => b.kindLabel), contains('From Nightingale TV (own build)'));
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.enter);
      await settleUntil(tester, () => h.started && h.app == null);
      expect((await stored(tester)).map((b) => b.kind), contains(BackupReason.beforeRestore));
    });

    testWidgets('a file that isn\'t a backup is refused, nothing restored', (tester) async {
      await setUpHousehold(tester);
      await noNotice(tester);
      final before = (await stored(tester)).length;
      await show(tester, const Scaffold());
      InstallSwitching.pending.value = SetupReceived(Uint8List.fromList(List.filled(300, 7)));
      await settle(tester);
      expect(find.text('Couldn\'t restore'), findsOneWidget);
      expect(find.text(BackupArchive.damaged), findsOneWidget);
      expect(find.textContaining('Restore the backup from'), findsNothing);
      expect((await stored(tester)).length, before);
      expect(h.app, isNotNull);
    });

    testWidgets('one the other app couldn\'t read is refused the same way', (tester) async {
      await setUpHousehold(tester);
      await noNotice(tester);
      await show(tester, const Scaffold());
      InstallSwitching.pending.value = SetupReceived(Uint8List(0));
      await settle(tester);
      expect(find.text(BackupArchive.damaged), findsOneWidget);
    });

    testWidgets('one over the size cap is too big', (tester) async {
      await setUpHousehold(tester);
      await noNotice(tester);
      await show(tester, const Scaffold());
      InstallSwitching.pending.value = SetupReceived(Uint8List(32 * 1024 * 1024 + 1));
      await settle(tester);
      expect(find.text(BackupArchive.tooBig), findsOneWidget);
    });

    testWidgets('a request for this setup asks first, then sends it', (tester) async {
      await setUpHousehold(tester);
      await noNotice(tester);
      await show(tester, const Scaffold());
      InstallSwitching.pending.value = const SetupRequested();
      await settle(tester);
      expect(find.text('Send your setup to Nightingale TV (own build)?'), findsOneWidget);
      expect(focused(), 'Cancel');
      expect(sent, isEmpty);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.enter);
      await settleUntil(tester, () => sent.isNotEmpty);
      expect(BackupArchive.check(sent.single!).summary.profiles, ['Mom', 'Kids']);
      expect((await stored(tester)).map((b) => b.kindLabel), contains('Moving to Nightingale TV (own build)'));
    });
  });
}
