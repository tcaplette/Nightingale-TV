import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_exit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/platform/backup_files.dart';
import 'package:nightingale_tv/platform/install_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/store/store.dart';
import 'package:nightingale_tv/store/unlock.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/backup_screen.dart';
import 'package:nightingale_tv/ui/install_switching.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/unlock_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'backup_fixtures.dart';
import 'fake_playback.dart';
import 'fixtures.dart';

/// The Play version's trial and unlock on screen (play-unlock), against the
/// stand-in store.
void main() {
  late Directory dir;
  late Household h;
  late Tuner tuner;
  late int exits;
  late Future<void> Function() realClose;

  setUp(() {
    BackupArchive.useIsolate = false;
    BackupFiles.debugAvailable = true;
    UnlockNotices.debugReset();
    exits = 0;
    realClose = closeApp;
    closeApp = () async => exits++;
  });
  tearDown(() {
    BackupArchive.useIsolate = true;
    BackupFiles.debugAvailable = null;
    InstallSwitching.debugReset();
    closeApp = realClose;
  });

  /// Real file I/O between frames.
  Future<void> settle(WidgetTester tester, [int rounds = 15]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await settle(tester, 1);
    }
    expect(done(), isTrue, reason: 'still waiting');
  }

  Future<void> setUpHousehold(WidgetTester tester, {String watching = 'Mom'}) async {
    tester.view.physicalSize = const Size(3200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_unlock_screen');
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      h = await openHousehold(dir);
      await h.select(h.profiles.firstWhere((p) => p.name == watching));
    });
    tuner = Tuner(h.app!, player: FakePlayer([]));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      h.unlock?.dispose();
      h.unlock = null;
      tuner.dispose();
      await tester.runAsync(() async {
        h.leave();
        h.backups!.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // Bounded: a write begun on the test's fake clock may never finish.
        await h.root.flush().timeout(const Duration(seconds: 2), onTimeout: () {});
        await dir.delete(recursive: true);
      });
    });
  }

  /// A locked install on the stand-in store in [mode], [offsetDays] into
  /// its trial; or, with [mode] null, an install that isn't locked (the
  /// free flavor).
  Future<Unlock> lock(WidgetTester tester, String? mode,
      {int offsetDays = 0, DateTime Function()? now, Duration pendingFor = const Duration(milliseconds: 200)}) async {
    final unlock = h.unlock = Unlock(h.root,
        store: mode == null ? null : FakeStore(mode, h.root, pendingFor: pendingFor),
        offsetDays: offsetDays,
        now: now);
    await tester.runAsync(() => unlock.start(watchLifecycle: false));
    await settle(tester, 3);
    return unlock;
  }

  /// [home] in the app, as the shell has it: scopes above the app, the
  /// gate around the home screen.
  Future<void> show(WidgetTester tester, Widget home, {bool gate = true}) async {
    await tester.pumpWidget(HouseholdScope(
      household: h,
      child: AppScope(
        app: h.app!,
        tuner: tuner,
        child: MaterialApp(
          theme: GuideTheme.cableGuide.toThemeData(),
          home: gate ? UnlockGate(household: h, child: home) : home,
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

  const home = Text('HOME');

  group('the Unlock screen', () {
    testWidgets('replaces the home screen once the trial is over; the remote moves through it and buys', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'buy', offsetDays: 15);
      await show(tester, home);
      expect(find.text('HOME'), findsNothing);
      expect(find.text('Your free trial has ended'), findsOneWidget);
      expect(focused(), r'Unlock for $4.99');
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'Redeem a Play code');
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'Check my purchase again');
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'Backup & restore');
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'Exit Nightingale TV');
      for (var i = 0; i < 4; i++) {
        await press(tester, LogicalKeyboardKey.arrowUp);
      }
      expect(focused(), r'Unlock for $4.99');
      await press(tester, LogicalKeyboardKey.enter);
      await settleUntil(tester, () => find.text('HOME').evaluate().isNotEmpty);
      expect(h.unlock!.value.status, UnlockStatus.unlocked);
      await settleUntil(tester, () => h.notice.value == 'Unlocked. Thank you for supporting Nightingale TV.');
    });

    testWidgets('an air mouse points at its buttons and clicks; touch taps', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await setUpHousehold(tester);
      await lock(tester, 'cancel', offsetDays: 15);
      await show(tester, home);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byKey(UnlockScreen.checkKey)));
      await tester.pump();
      expect(focused(), 'Check my purchase again');
      await mouse.moveTo(tester.getCenter(find.byKey(UnlockScreen.buyKey)));
      await tester.pump();
      expect(focused(), r'Unlock for $4.99');
      // Cancelled: nothing changes, nothing is said.
      await mouse.down(tester.getCenter(find.byKey(UnlockScreen.buyKey)));
      await mouse.up();
      await settle(tester);
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      // Touch: Check my purchase again finds none and says so.
      await tester.tap(find.byKey(UnlockScreen.checkKey));
      await settleUntil(tester, () => find.text('No purchase found').evaluate().isNotEmpty);
      await tester.tap(find.widgetWithText(TvButton, 'OK'));
      await settle(tester);
      expect(find.byType(UnlockScreen), findsOneWidget);
    });

    testWidgets('a failed purchase says so and changes nothing', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'error', offsetDays: 15);
      await show(tester, home);
      await tester.tap(find.byKey(UnlockScreen.buyKey));
      await settleUntil(tester, () => find.text('Purchase not completed').evaluate().isNotEmpty);
      expect(h.unlock!.value.status, UnlockStatus.expired);
    });

    testWidgets('a pending purchase opens the home screen, then unlocks', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'pending', offsetDays: 15);
      await show(tester, home);
      await tester.tap(find.byKey(UnlockScreen.buyKey));
      await settleUntil(tester, () => find.text('HOME').evaluate().isNotEmpty);
      expect(h.unlock!.value.status, UnlockStatus.pending);
      // Said with the notice, not a dialog the TV screen would take focus from.
      expect(find.byType(Dialog), findsNothing);
      expect(h.notice.value, startsWith('Your purchase is waiting to complete.'));
      await settleUntil(tester, () => h.unlock!.value.status == UnlockStatus.unlocked);
    });

    testWidgets('Backup & restore opens from it and stays open', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'buy', offsetDays: 15);
      await show(tester, home);
      await tester.tap(find.byKey(UnlockScreen.backupKey));
      await settle(tester);
      expect(find.byType(BackupScreen), findsOneWidget);
      expect(find.text('Use your phone or computer'), findsOneWidget);
      // A language change rebuilds everything; the screen stays.
      await tester.pumpWidget(HouseholdScope(
        household: h,
        child: AppScope(
          app: h.app!,
          tuner: tuner,
          child: MaterialApp(theme: GuideTheme.cableGuide.toThemeData(), home: UnlockGate(household: h, child: home)),
        ),
      ));
      await settle(tester);
      expect(find.byType(BackupScreen), findsOneWidget);
    });

    testWidgets('its buttons in order, Unlock focused first', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'redeem', offsetDays: 15);
      await show(tester, home);
      const order = [
        UnlockScreen.buyKey,
        UnlockScreen.redeemKey,
        UnlockScreen.checkKey,
        UnlockScreen.backupKey,
        UnlockScreen.exitKey,
      ];
      final tops = [for (final k in order) tester.getTopLeft(find.byKey(k)).dy];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: '${order[i]} below ${order[i - 1]}');
      }
      expect(tester.widget<TvButton>(find.byKey(UnlockScreen.redeemKey)).label, 'Redeem a Play code');
      expect(focused(), r'Unlock for $4.99');
    });

    testWidgets('Redeem a Play code says where to redeem; the screen stays until Check my purchase again', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'redeem', offsetDays: 15);
      await show(tester, home);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'Redeem a Play code');
      await press(tester, LogicalKeyboardKey.enter);
      await settleUntil(tester, () => find.text('Redeem a code').evaluate().isNotEmpty);
      expect(find.textContaining('play.google.com/redeem'), findsOneWidget);
      expect(focused(), 'OK');
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(h.unlock!.value.status, UnlockStatus.expired);
      // Back closes the message too.
      await tester.tap(find.byKey(UnlockScreen.redeemKey));
      await settleUntil(tester, () => find.text('Redeem a code').evaluate().isNotEmpty);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(Dialog), findsNothing);
      expect(exits, 0);
      await tester.tap(find.byKey(UnlockScreen.checkKey));
      await settleUntil(tester, () => find.text('HOME').evaluate().isNotEmpty);
      expect(h.unlock!.value.status, UnlockStatus.unlocked);
    });

    testWidgets('an air mouse clicks Redeem a Play code and its OK', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await setUpHousehold(tester);
      await lock(tester, 'redeem', offsetDays: 15);
      await show(tester, home);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      final redeem = tester.getCenter(find.byKey(UnlockScreen.redeemKey));
      await mouse.moveTo(redeem);
      await tester.pump();
      expect(focused(), 'Redeem a Play code');
      await mouse.down(redeem);
      await mouse.up();
      await settleUntil(tester, () => find.text('Redeem a code').evaluate().isNotEmpty);
      final ok = tester.getCenter(find.widgetWithText(TvButton, 'OK'));
      await mouse.moveTo(ok);
      await mouse.down(ok);
      await mouse.up();
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(UnlockScreen), findsOneWidget);
    });

    testWidgets('on a kid profile, Unlock, Redeem a Play code and Backup & restore ask for the PIN', (tester) async {
      await setUpHousehold(tester, watching: 'Kids');
      await lock(tester, 'redeem', offsetDays: 15);
      await show(tester, home);
      for (final key in [UnlockScreen.buyKey, UnlockScreen.redeemKey, UnlockScreen.backupKey]) {
        await tester.tap(find.byKey(key));
        await settle(tester);
        expect(find.text('Parental controls'), findsOneWidget);
        Navigator.of(tester.element(find.text('Parental controls'))).pop();
        await settle(tester);
        expect(find.text('Parental controls'), findsNothing);
      }
      expect(find.byType(BackupScreen), findsNothing);
      expect(find.text('Redeem a code'), findsNothing);
      expect(h.unlock!.value.status, UnlockStatus.expired);
      await tester.runAsync(h.root.flush);
      expect(await tester.runAsync(() => h.root.readJson(FakeStore.file)), isNull, reason: 'nothing redeemed');
    });

    testWidgets('Back and Exit quit the app', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'buy', offsetDays: 15);
      await show(tester, home);
      await press(tester, LogicalKeyboardKey.escape);
      await settleUntil(tester, () => exits == 1);
      await tester.tap(find.byKey(UnlockScreen.exitKey));
      await settleUntil(tester, () => exits == 2);
      // The on-screen Back too.
      await tester.tap(find.text('Back'));
      await settleUntil(tester, () => exits == 3);
    });

    testWidgets('the trial ending shows it only at the next check, and playback stops then', (tester) async {
      await setUpHousehold(tester);
      var now = DateTime.now();
      final unlock = await lock(tester, 'buy', now: () => now);
      h.app!.client = FakeClient([]);
      await show(tester, home);
      await tester.runAsync(() => tuner.tune(h.app!.channels.first));
      await settle(tester, 3);
      expect(tuner.channel, isNotNull);
      // Mid-program the trial runs out: nothing changes yet.
      now = now.add(const Duration(days: 15));
      await settle(tester, 3);
      expect(find.text('HOME'), findsOneWidget);
      // Back in the foreground: the Unlock screen, and nothing plays.
      await tester.runAsync(unlock.refresh);
      await settle(tester);
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(tuner.channel, isNull);
      // The tuner's own timers go before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(tuner.stop);
      await tester.pump(const Duration(minutes: 10));
    });
  });

  group('the trial notices', () {
    Future<void> showNotices(WidgetTester tester) => show(
        tester,
        Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) => UnlockNotices.maybeShow(context));
          return home;
        }));

    testWidgets('the welcome shows once, with the price, Start my free trial focused', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'buy');
      await showNotices(tester);
      await settleUntil(tester, () => find.text('Free for 14 days').evaluate().isNotEmpty);
      expect(find.textContaining(r'one-time purchase of $4.99'), findsOneWidget);
      expect(focused(), 'Start my free trial');
      await press(tester, LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.text('Free for 14 days'), findsNothing);
      // The next start.
      UnlockNotices.debugReset();
      await tester.pumpWidget(const SizedBox());
      await showNotices(tester);
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('3 days left and the last day each show once; Unlock now buys', (tester) async {
      await setUpHousehold(tester);
      await tester.runAsync(() => h.root.writeJson(Unlock.noticesFile, {'welcome': true}));
      await lock(tester, 'buy', offsetDays: 11);
      await showNotices(tester);
      await settleUntil(tester, () => find.text('3 days left in your free trial').evaluate().isNotEmpty);
      await tester.tap(find.byKey(UnlockNotices.dismissKey));
      await settle(tester);

      Future<void> restart(int days) async {
        UnlockNotices.debugReset();
        h.unlock?.dispose();
        await tester.pumpWidget(const SizedBox());
        await lock(tester, 'buy', offsetDays: days);
        await showNotices(tester);
        await settle(tester);
      }

      await restart(11);
      expect(find.byType(Dialog), findsNothing);
      await restart(13);
      await settleUntil(tester, () => find.text('Last day of your free trial').evaluate().isNotEmpty);
      await tester.tap(find.byKey(UnlockNotices.unlockNowKey));
      await settleUntil(tester, () => h.unlock!.value.status == UnlockStatus.unlocked);
      await restart(13);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('the menu', () {
    testWidgets('Unlock Nightingale TV with the days left, after Error reports; gone once bought', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'buy');
      await show(tester, const MenuScreen(), gate: false);
      final labels = [for (final b in tester.widgetList<TvButton>(find.byType(TvButton))) b.label];
      expect(labels.indexOf('Unlock Nightingale TV'), labels.indexOf('Error reports') + 1);
      expect(find.text('14 days left in your free trial'), findsOneWidget);
      await tester.tap(find.byKey(UnlockMenuItem.buttonKey));
      await settleUntil(tester, () => find.byKey(UnlockMenuItem.buttonKey).evaluate().isEmpty);
      expect(h.unlock!.value.status, UnlockStatus.unlocked);
    });

    testWidgets('Purchase pending while a purchase waits', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'pending', pendingFor: const Duration(seconds: 3));
      await show(tester, const MenuScreen(), gate: false);
      await tester.tap(find.byKey(UnlockMenuItem.buttonKey));
      await settleUntil(tester, () => h.unlock!.value.status == UnlockStatus.pending);
      // The pending message, then the menu says so.
      await settleUntil(tester, () => find.widgetWithText(TvButton, 'OK').evaluate().isNotEmpty);
      await tester.tap(find.widgetWithText(TvButton, 'OK'));
      await settle(tester);
      expect(find.text('Purchase pending'), findsOneWidget);
      await settleUntil(tester, () => find.byKey(UnlockMenuItem.buttonKey).evaluate().isEmpty);
    });

    testWidgets('Redeem a Play code under it in the trial and after it, not while pending or once unlocked', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'pending', pendingFor: const Duration(seconds: 3));
      await show(tester, const MenuScreen(), gate: false);
      final labels = [for (final b in tester.widgetList<TvButton>(find.byType(TvButton))) b.label];
      expect(labels.indexOf('Redeem a Play code'), labels.indexOf('Unlock Nightingale TV') + 1);
      expect(find.text('14 days left in your free trial'), findsOneWidget);
      expect(tester.getTopLeft(find.text('14 days left in your free trial')).dy,
          greaterThan(tester.getBottomLeft(find.byKey(UnlockMenuItem.redeemKey)).dy));
      await tester.tap(find.byKey(UnlockMenuItem.buttonKey));
      await settleUntil(tester, () => h.unlock!.value.status == UnlockStatus.pending);
      await settleUntil(tester, () => find.widgetWithText(TvButton, 'OK').evaluate().isNotEmpty);
      await tester.tap(find.widgetWithText(TvButton, 'OK'));
      await settle(tester);
      expect(find.byKey(UnlockMenuItem.buttonKey), findsOneWidget);
      expect(find.byKey(UnlockMenuItem.redeemKey), findsNothing);
      await settleUntil(tester, () => h.unlock!.value.status == UnlockStatus.unlocked);
      await settle(tester);
      expect(find.byKey(UnlockMenuItem.redeemKey), findsNothing);
    });

    testWidgets('after the trial the menu offers Redeem a Play code too', (tester) async {
      await setUpHousehold(tester);
      await lock(tester, 'redeem', offsetDays: 15);
      await show(tester, const MenuScreen(), gate: false);
      expect(find.byKey(UnlockMenuItem.redeemKey), findsOneWidget);
    });

    testWidgets('Redeem a Play code says where to redeem; coming back to the foreground unlocks', (tester) async {
      await setUpHousehold(tester);
      final unlock = await lock(tester, 'redeem', offsetDays: 5);
      await show(tester, const MenuScreen(), gate: false);
      await tester.tap(find.byKey(UnlockMenuItem.redeemKey));
      await settleUntil(tester, () => find.text('Redeem a code').evaluate().isNotEmpty);
      await tester.tap(find.widgetWithText(TvButton, 'OK'));
      await settle(tester);
      expect(unlock.value.status, UnlockStatus.trial);
      // The return to the foreground's check.
      await tester.runAsync(unlock.refresh);
      await settleUntil(tester, () => find.byKey(UnlockMenuItem.redeemKey).evaluate().isEmpty);
      expect(find.byKey(UnlockMenuItem.buttonKey), findsNothing);
      expect(unlock.value.status, UnlockStatus.unlocked);
    });

    testWidgets('on a kid profile Redeem a Play code asks for the PIN', (tester) async {
      await setUpHousehold(tester, watching: 'Kids');
      await lock(tester, 'redeem');
      await show(tester, const MenuScreen(), gate: false);
      await tester.tap(find.byKey(UnlockMenuItem.redeemKey));
      await settle(tester);
      expect(find.text('Parental controls'), findsOneWidget);
      expect(find.text('Redeem a code'), findsNothing);
    });

    testWidgets('on a kid profile it isn\'t behind the menu lock, and buying asks for the PIN', (tester) async {
      await setUpHousehold(tester, watching: 'Kids');
      await lock(tester, 'buy');
      await show(tester, const MenuScreen(), gate: false);
      expect(tester.widget<TvButton>(find.byKey(UnlockMenuItem.buttonKey)).icon, isNot(Icons.lock));
      await tester.tap(find.byKey(UnlockMenuItem.buttonKey));
      await settle(tester);
      expect(find.text('Parental controls'), findsOneWidget);
      expect(h.unlock!.value.status, UnlockStatus.trial);
    });
  });

  group('About this install', () {
    const play = InstallInfo(ownBuild: false, installer: InstallInfo.googlePlayInstaller);

    String? line(WidgetTester tester) {
      final found = find.byKey(AboutThisInstall.unlockLineKey);
      return found.evaluate().isEmpty ? null : tester.widget<Text>(found).data;
    }

    testWidgets('a Play install in its trial, then unlocked', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = play;
      final unlock = await lock(tester, 'buy');
      await show(tester, const BackupScreen(), gate: false);
      expect(find.text('Installed from Google Play'), findsOneWidget);
      expect(line(tester), 'Free trial: 14 days left');
      await tester.runAsync(unlock.buy);
      await tester.pumpWidget(const SizedBox());
      await show(tester, const BackupScreen(), gate: false);
      expect(line(tester), 'Unlocked. Thank you for supporting Nightingale TV.');
    });

    testWidgets('a trial that has ended says so, not 0 days left', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = play;
      await lock(tester, 'buy', offsetDays: 15);
      await show(tester, const BackupScreen(), gate: false);
      expect(line(tester), 'Your free trial has ended');
    });

    testWidgets('a pending purchase', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = play;
      final unlock = await lock(tester, 'pending');
      await tester.runAsync(unlock.buy);
      await show(tester, const BackupScreen(), gate: false);
      expect(line(tester), 'Purchase pending');
    });

    testWidgets('an official free APK has no unlock line', (tester) async {
      await setUpHousehold(tester);
      InstallSwitching.debugInfo = const InstallInfo(ownBuild: false);
      await lock(tester, null);
      await show(tester, const BackupScreen(), gate: false);
      expect(find.text('Official Nightingale TV APK'), findsOneWidget);
      expect(line(tester), isNull);
    });
  });

  group('the free flavor', () {
    testWidgets('an expired trial file changes nothing: no Unlock screen, menu item or notice', (tester) async {
      await setUpHousehold(tester);
      // A Play install's files, left behind when the free APK went over it.
      await tester.runAsync(() => h.root.writeJson('store/trial.json', {'start': 1000, 'lastSeen': 2000}));
      await lock(tester, null);
      expect(h.unlock!.value, UnlockState.notLocked);
      await show(tester, Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => UnlockNotices.maybeShow(context));
        return home;
      }));
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await show(tester, const MenuScreen(), gate: false);
      expect(find.byKey(UnlockMenuItem.buttonKey), findsNothing);
      expect(find.byKey(UnlockMenuItem.redeemKey), findsNothing);
      expect(find.text('Redeem a Play code'), findsNothing);
      expect(find.textContaining('free trial'), findsNothing);
    });
  });
}
