// The Language setting on a real server with real playback (app-languages
// 8.4–8.6).
//
// Signs in with the test-data.md server's account. On a device, run
// integration_test/caption_size_host.py beside it (real keys, taps and
// screenshots), and on the TV tool/uhid_mouse/drive.py for the mouse:
//   flutter test integration_test/languages_live_test.dart -d emulator-5554 \
//     --dart-define=LANG_PLAT=tv --dart-define=CAP_URL=… --dart-define=CAP_USER=… --dart-define=CAP_PW=…
// LANG_PLAT is linux, tv, phone, or automatic:<language> to check what a
// device set to that language shows. On Linux in a private X server, the same
// variables and SNAP_DIR come from the environment.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/platform/android_back_bridge.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/server_clients.dart';
import 'package:nightingale_tv/ui/backup_screen.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/commercials_screen.dart';
import 'package:nightingale_tv/ui/language_picker.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/playback_screen.dart';
import 'package:nightingale_tv/ui/portrait_watch_screen.dart';
import 'package:nightingale_tv/ui/profiles_screen.dart';
import 'package:nightingale_tv/ui/retro_look_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

final _env = <String, String?>{
  ...Platform.environment,
  for (final (k, v) in const [
    ('LANG_PLAT', String.fromEnvironment('LANG_PLAT')),
    ('CAP_URL', String.fromEnvironment('CAP_URL')),
    ('CAP_USER', String.fromEnvironment('CAP_USER')),
    ('CAP_PW', String.fromEnvironment('CAP_PW')),
  ])
    if (v != '') k: v,
};

// ignore: avoid_print
void _say(String s) => print('CAP $s');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final plat = _env['LANG_PLAT'] ?? '';

  testWidgets('languages on $plat', (tester) async {
    if (plat.isEmpty) {
      markTestSkipped('Set LANG_PLAT and CAP_URL, CAP_USER, CAP_PW.');
      return;
    }
    final linux = plat == 'linux';
    final phone = plat == 'phone';
    final automatic = plat.startsWith('automatic:') ? plat.substring('automatic:'.length) : null;
    if (!linux) {
      binding.shouldPropagateDevicePointerEvents = true;
    }
    if (linux) MediaKit.ensureInitialized();
    await languageDataReady;
    await PlatformInfo.init();
    if (!linux) {
      // As main() does: Back goes through the app's own handling.
      final back = androidBack = AndroidBackBridge();
      WidgetsBinding.instance.addObserver(back);
      HardwareKeyboard.instance.addHandler(back.handleKey);
    }
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_languages_live');
    final household = Household(await AppStorage.at(dir), runAnalysis: false);
    household.backups = BackupScheduler(household, BackupStore(Directory('${dir.path}/backups')));
    WidgetsBinding.instance.addObserver(household.language);
    late AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> host(String command) async {
      _say('HOST $command');
      await wait(const Duration(milliseconds: 1300));
    }

    Future<void> snap(String name) async {
      await wait(const Duration(milliseconds: 700));
      final snapDir = _env['SNAP_DIR'];
      if (linux && snapDir != null) {
        final view = tester.binding.renderViews.first;
        final layer = view.debugLayer! as OffsetLayer;
        final image = await tester.runAsync(() => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
        final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        await File('$snapDir/$plat-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      } else if (!linux) {
        await host('snap $plat-$name');
      }
    }

    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      final found = await identifyServer(_env['CAP_URL']!, deviceId: app.settings.installId, deviceName: app.deviceName);
      final client = found.client as JellyfinClient;
      await app.completeSignIn(await client.authenticateByName(_env['CAP_USER']!, _env['CAP_PW']!, serverName: found.info.name), client);
      await app.setPlayback(app.settings.playback.copyWith(reportPlayback: false));
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');

    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 3));

    if (automatic != null) {
      expect(household.current!.language, isNull);
      expect(activeLanguage, automatic);
      expect(find.byType(TvScreen), findsOneWidget);
      await snap('automatic');
      _say('automatic shows $activeLanguage');
      binding.shouldPropagateDevicePointerEvents = false;
      return;
    }

    final tv = find.byType(phone ? PortraitWatchScreen : TvScreen);
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    Future<void> playing() async {
      for (var i = 0; i < 600 && tuner.status != TunerStatus.playing; i++) {
        await wait(const Duration(milliseconds: 100));
      }
      expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    }

    await tester.runAsync(() => tuner.tune(app.channels.firstWhere((c) => !c.blockOnly)));
    await playing();
    final channel = tuner.channel;
    _say('playing ${channel?.number}');

    final adb = {
      LogicalKeyboardKey.arrowUp: 'DPAD_UP',
      LogicalKeyboardKey.arrowDown: 'DPAD_DOWN',
      LogicalKeyboardKey.select: 'DPAD_CENTER',
      LogicalKeyboardKey.goBack: 'BACK',
      LogicalKeyboardKey.keyM: 'M',
      LogicalKeyboardKey.keyG: 'G',
      LogicalKeyboardKey.keyI: 'I',
    };
    final ok = linux ? LogicalKeyboardKey.enter : LogicalKeyboardKey.select;
    final back = linux ? LogicalKeyboardKey.escape : LogicalKeyboardKey.goBack;
    final seen = <LogicalKeyboardKey>{};
    bool handler(KeyEvent e) {
      if (e is KeyDownEvent) seen.add(e.logicalKey);
      return false;
    }

    HardwareKeyboard.instance.addHandler(handler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));

    Future<void> press(LogicalKeyboardKey k) async {
      if (linux) {
        await tester.sendKeyEvent(k);
        await wait(const Duration(milliseconds: 450));
        return;
      }
      for (var attempt = 0; attempt < 4; attempt++) {
        seen.clear();
        await host('key ${adb[k]}');
        for (var i = 0; i < 40 && !seen.contains(k); i++) {
          await wait(const Duration(milliseconds: 100));
        }
        if (seen.contains(k)) {
          await wait(const Duration(milliseconds: 300));
          return;
        }
      }
      fail('key ${adb[k]} never arrived');
    }

    String? focused() {
      final c = FocusManager.instance.primaryFocus?.context;
      return c?.findAncestorWidgetOfExactType<TvToggle>()?.label ?? c?.findAncestorWidgetOfExactType<TvButton>()?.label;
    }

    Future<void> moveTo(String label, {int limit = 30}) async {
      for (var dir = 0; dir < 2 && focused() != label; dir++) {
        for (var i = 0; i < limit && focused() != label; i++) {
          final before = focused();
          await press(dir == 0 ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowUp);
          if (focused() == before) break;
        }
      }
      expect(focused(), label);
    }

    String physical(Finder f) {
      final c = tester.getCenter(f.first);
      final r = tester.view.devicePixelRatio;
      return '${(c.dx * r).round()} ${(c.dy * r).round()}';
    }

    Future<void> touch(Finder f) async {
      await tester.ensureVisible(f.first);
      await wait(const Duration(milliseconds: 400));
      await host('tap ${physical(f)}');
      await wait(const Duration(seconds: 1));
    }

    Future<void> checkPlayback() async {
      expect(tuner.status, TunerStatus.playing, reason: 'a language change keeps playing');
      expect(tuner.channel, same(channel));
    }

    final start = tuner.media.position;

    Future<void> screens(String language) async {
      final context = tester.element(tv);
      for (final (name, screen) in <(String, Widget)>[
        ('playback', const PlaybackScreen()),
        ('retro', const RetroLookScreen()),
        ('channels', const ChannelEditorScreen()),
        ('commercials', const CommercialsScreen()),
        ('profiles', const ProfilesScreen()),
        ('backup', const BackupScreen()),
      ]) {
        final navigator = Navigator.of(context);
        navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
        await wait(const Duration(seconds: 1));
        final problem = tester.takeException();
        if (problem is Error) _say('$name: $problem\n${problem.stackTrace}');
        expect(problem, isNull, reason: '$name in $language');
        await snap('$language-$name');
        navigator.pop();
        await wait(const Duration(milliseconds: 500));
      }
    }

    Future<void> choose(String language, {required int index}) async {
      final name = languageNativeNames[language]!;
      if (phone) {
        // The first tap over the picture shows the controls.
        for (var i = 0; i < 4 && find.byType(MenuScreen).evaluate().isEmpty; i++) {
          final menu = find.text(stringsFor(activeLanguage).menu);
          await touch(menu.evaluate().isEmpty ? find.byType(PortraitWatchScreen) : menu);
          await wait(const Duration(seconds: 1));
        }
        expect(find.byType(MenuScreen), findsOneWidget);
        await touch(find.text(stringsFor(activeLanguage).languageTitle));
        await touch(find.text(name));
      } else {
        await press(LogicalKeyboardKey.keyM);
        await wait(const Duration(seconds: 1));
        expect(find.byType(MenuScreen), findsOneWidget);
        await moveTo(stringsFor(activeLanguage).languageTitle);
        await press(ok);
        await wait(const Duration(seconds: 1));
        await moveTo(name);
        await press(ok);
      }
      await wait(const Duration(seconds: 1));
      expect(activeLanguage, language);
      expect(household.current!.language, language);
      expect(find.text(stringsFor(language).languageTitle), findsWidgets, reason: 'the picker changed at once');
      expect(find.byType(MenuScreen), findsOneWidget, reason: 'the menu stayed');
      if (!phone) {
        expect(focused(), name, reason: 'focus stayed on the picker');
      }
      await checkPlayback();
      await snap('$language-picker');
    }

    Future<void> closeDialogAndMenu() async {
      if (phone) {
        await host('key BACK');
        await wait(const Duration(seconds: 1));
        await snap('$activeLanguage-menu');
        await host('key BACK');
      } else {
        await press(back);
        await wait(const Duration(milliseconds: 800));
        await snap('$activeLanguage-menu');
        await press(back);
      }
      await wait(const Duration(seconds: 1));
    }

    final only = _env['LANG_ONLY'];
    final languages = only != null ? only.split(',') : (linux ? supportedLanguages.reversed.toList() : const ['de', 'fr']);
    for (final (i, language) in languages.indexed) {
      await choose(language, index: i);
      await closeDialogAndMenu();
      if (!phone) {
        await press(LogicalKeyboardKey.keyG);
        await wait(const Duration(seconds: 2));
        await snap('$language-guide');
        await press(back);
        await wait(const Duration(seconds: 1));
        await press(LogicalKeyboardKey.keyI);
        await wait(const Duration(seconds: 1));
        await snap('$language-overlay');
        await press(LogicalKeyboardKey.keyI);
        await wait(const Duration(seconds: 1));
      } else {
        await snap('$language-watch');
      }
      await screens(language);
      await checkPlayback();
      _say('$language OK');
    }

    final moved = tuner.media.position;
    expect(moved != start, isTrue, reason: 'the picture kept moving');

    if (plat == 'tv') {
      // By mouse: the picker's Italiano row.
      await press(LogicalKeyboardKey.keyM);
      await wait(const Duration(seconds: 1));
      await moveTo(tr.languageTitle);
      await press(ok);
      await wait(const Duration(seconds: 1));
      _say('UHID ${physical(find.text('Italiano'))}');
      for (var i = 0; i < 400 && activeLanguage != 'it'; i++) {
        await wait(const Duration(milliseconds: 100));
      }
      expect(activeLanguage, 'it', reason: 'the mouse chose Italiano');
      await checkPlayback();
      await snap('it-mouse');
      _say('mouse OK');
    }

    await tester.runAsync(tuner.stop);
    await tester.pumpWidget(const SizedBox());
    await wait(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      household.leave();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(showLanguagePicker, isNotNull);
    binding.shouldPropagateDevicePointerEvents = false;
  }, timeout: const Timeout(Duration(minutes: 40)));
}
