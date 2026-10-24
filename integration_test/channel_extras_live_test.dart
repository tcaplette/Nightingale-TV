// Channel extras against a real Jellyfin server, so programs really play:
// the channel logo (at a part's start, in a break, at a quarter hour), the
// guide tabs by keyboard and mouse, and a new episode premiere slot moved a
// few minutes ahead:
//
//   JF_SERVER=https://... JF_USER=... JF_PW=... SNAP_DIR=/tmp/snaps \
//     flutter test integration_test/channel_extras_live_test.dart -d linux
//
// Needs a "Commercials" library of short clips. Takes up to 20 minutes (it
// waits for the next quarter hour).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/channels/logo_windows.dart';
import 'package:nightingale_tv/channels/premieres.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/channel_logo_bug.dart';
import 'package:nightingale_tv/ui/widgets/new_tag.dart';

final _env = Platform.environment;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logo, guide tabs and premieres on a real server', (tester) async {
    final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
    if (server == null || user == null || password == null) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW to run against a server.');
      return;
    }
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_extras');
    final household = Household(await AppStorage.at(dir), runAnalysis: false);
    late AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> waitUntil(DateTime t) => wait(t.difference(DateTime.now()).isNegative ? Duration.zero : t.difference(DateTime.now()));

    Future<void> snap(String name) async {
      final snapDir = _env['SNAP_DIR'];
      // ignore: avoid_print
      print('${DateTime.now().toIso8601String()} snap $name');
      if (snapDir == null) return;
      await tester.pump();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image = await tester.runAsync(
          () => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      await File('$snapDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    Future<void> press(LogicalKeyboardKey key) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.sendKeyEvent(key);
      await wait(const Duration(milliseconds: 500));
    }

    /// The logo is fully showing (it stays in the tree, faded out, while hidden).
    bool logoUp() => find
        .descendant(of: find.byType(ChannelLogoBug), matching: find.byType(AnimatedOpacity))
        .evaluate()
        .any((e) => (e.widget as AnimatedOpacity).opacity == logoOpacity);

    /// Waits for the tuner to hand over to the segment starting at [start]
    /// (a hand-over can land a few seconds late on a slow connection), then
    /// [settle] more; returns how late it was.
    Future<Duration> handedOver(DateTime start, {Duration settle = const Duration(seconds: 1)}) async {
      final t = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
      await waitUntil(start);
      final limit = start.add(const Duration(seconds: 15));
      while ((t.segment == null || t.segment!.start.isBefore(start)) && DateTime.now().isBefore(limit)) {
        await wait(const Duration(milliseconds: 100));
      }
      final late = DateTime.now().difference(start);
      // ignore: avoid_print
      print('hand-over to the segment at $start after ${late.inMilliseconds} ms');
      await wait(settle);
      return late;
    }

    /// What the logo goes by, for the log.
    void dumpLogo(String at) {
      final bugs = tester.widgetList<ChannelLogoBug>(find.byType(ChannelLogoBug));
      final t = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
      final seg = t.segment;
      // ignore: avoid_print
      print('${DateTime.now().toIso8601String()} logo@$at: status ${t.status.name}, segment ${seg?.item?.guideTitle} '
          '${seg?.start}–${seg?.end} break ${seg?.isBreak}; bugs ${bugs.length} '
          '${[for (final b in bugs) 'mode ${b.mode.name} hidden ${b.hidden} seg ${b.segment?.start}–${b.segment?.end}']}; up ${logoUp()}');
    }

    // ---- Sign in, with breaks from the Commercials library -------------------
    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      final client = app.clientFor(ServerKind.jellyfin, server) as JellyfinClient;
      final info = await client.publicInfo();
      final session = await client.authenticateByName(user, password, serverName: info.name);
      await app.completeSignIn(session, client);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    final libraries = (await tester.runAsync(app.client!.libraries))!;
    final ads = libraries.firstWhere((l) => l.name == 'Commercials');
    final pool = (await tester.runAsync(app.createPool))!;
    await tester.runAsync(
        () => app.setPoolRoots(pool, [PoolRoot(itemId: ads.id, libraryId: ads.id, label: ads.name)]));
    for (var i = 0; i < 240 && (app.refreshing || app.library.commercials.isEmpty); i++) {
      await wait(const Duration(milliseconds: 500));
    }
    expect(app.library.commercials, isNotEmpty);
    await tester.runAsync(() async {
      await app.setGlobalPlan(BreakPlan.automatic);
      // Open the profile again, as a launch does: clips known from the
      // start, so every slot has its breaks (a slot only uses the clips
      // known when it started).
      final profile = household.current!;
      household.leave();
      await Future<void>.delayed(const Duration(seconds: 2));
      await household.select(profile);
      app = household.app!;
    });
    expect(app.phase, AppPhase.ready);
    expect(app.channels.where((c) => !c.isMusic).every(app.breaksFor), isTrue, reason: 'breaks on every channel but music');
    expect(app.channels.where((c) => c.isMusic).any(app.breaksFor), isFalse, reason: 'music channels start with breaks off');
    expect(app.settings.logoMode, LogoMode.nowAndThen, reason: 'the default');
    // ignore: avoid_print
    print('Lineup: ${[for (final c in app.channels) '${c.number} ${c.name}'].join(', ')}');

    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 2));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));

    // The premiere slot, moved to the minute after next.
    final premiereAt = DateTime.now().add(const Duration(minutes: 2));
    await tester.runAsync(() => app.setPremiereSettings(PremiereSettings(startMinute: premiereAt.hour * 60 + premiereAt.minute)));
    final slotStart = DateTime(premiereAt.year, premiereAt.month, premiereAt.day, premiereAt.hour, premiereAt.minute);

    /// Moves [ch]'s schedule so what happens at [at] happens at [to]
    /// instead (no waiting on the clock for an event).
    Future<void> bringClose(Channel ch, DateTime at, DateTime to) async {
      ch.anchor = ch.anchor.add(to.difference(at));
      await tester.runAsync(() => app.updateChannel(ch));
    }

    // ---- The logo hides in a break, even set to Always, and comes back -------
    final inBreak = app.channels.first;
    await tester.runAsync(() => app.setChannelLogoMode(inBreak, LogoMode.always));
    var schedule = app.scheduleFor(inBreak)!;
    final brk = playbackSegmentsBetween(schedule, DateTime.now(), DateTime.now().add(const Duration(minutes: 40)))
        .firstWhere((seg) => seg.isBreak && seg.start.isAfter(DateTime.now()));
    var back = brk;
    while (back.isBreak) {
      back = schedule.playbackAt(back.end);
    }
    // The program comes back 30 s from now: the end of the break is on now.
    await bringClose(inBreak, back.start, DateTime.now().add(const Duration(seconds: 30)));
    schedule = app.scheduleFor(inBreak)!;
    final soon = playbackSegmentsBetween(schedule, DateTime.now(), DateTime.now().add(const Duration(minutes: 1)));
    back = [for (var i = 1; i < soon.length; i++) if (soon[i - 1].isBreak && !soon[i].isBreak) soon[i]].first;
    // ignore: avoid_print
    print('Break check on ${inBreak.number} ${inBreak.name}: back at ${back.start}');
    await tester.runAsync(() => tuner.tune(inBreak));
    await wait(const Duration(seconds: 12));
    expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    expect(tuner.inBreak, isTrue);
    dumpLogo('no logo in a break, even set to Always');
    expect(logoUp(), isFalse, reason: 'no logo in a break, even set to Always');
    await snap('extras-1-break-no-logo');
    await handedOver(back.start);
    expect(tuner.inBreak, isFalse);
    dumpLogo('back with the program');
    expect(logoUp(), isTrue, reason: 'back with the program');
    await snap('extras-2-logo-back-after-break');

    // ---- Now and then: the logo from a program's start -------------------------
    final other = app.channels[1];
    await tester.runAsync(() => app.setChannelPlan(other, BreakPlan.off));
    final onAir = app.scheduleFor(other)!.programAt(DateTime.now());
    final starts = DateTime.now().add(const Duration(seconds: 25));
    await bringClose(other, onAir.end, starts);
    // ignore: avoid_print
    print('Logo check on ${other.number} ${other.name}: a program at $starts');
    await tester.runAsync(() => tuner.tune(other));
    await wait(const Duration(seconds: 8));
    expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    await handedOver(starts);
    dumpLogo('the logo from the start of the program');
    expect(logoUp(), isTrue, reason: 'the logo from the start of the program');
    await snap('extras-3-logo-at-start');
    await waitUntil(starts.add(logoWindowLength + const Duration(seconds: 1)));
    dumpLogo('gone 20 s later');
    expect(logoUp(), isFalse, reason: 'gone 20 s later');
    await snap('extras-4-logo-gone');
    final target = (channel: other);

    // ---- Guide tabs: keyboard and mouse ------------------------------------
    await press(LogicalKeyboardKey.keyG);
    expect(find.byType(GuideView), findsOneWidget);
    final tabs = app.guideTabs();
    // ignore: avoid_print
    print('Tabs: ${[for (final t in tabs) '${t.name} (${t.channels.length})'].join(', ')}');
    expect(tabs.length, greaterThan(1), reason: 'at least All and Movies');
    // The guide opens on the tuned channel: Up to the first row, then once
    // more to the tabs.
    final row = app.channels.indexWhere((c) => c.id == target.channel.id);
    for (var i = 0; i <= row; i++) {
      await press(LogicalKeyboardKey.arrowUp);
    }
    await press(LogicalKeyboardKey.arrowRight);
    expect(app.settings.guideTab, tabs[1].id);
    await snap('extras-5-tab-by-keyboard');
    await press(LogicalKeyboardKey.arrowDown);
    await tester.tap(find.text(GuideTabs.builtinName(GuideTabs.all)!.toUpperCase()), kind: PointerDeviceKind.mouse);
    await wait(const Duration(milliseconds: 500));
    expect(app.settings.guideTab, GuideTabs.all);
    await snap('extras-6-tab-by-mouse');
    await press(LogicalKeyboardKey.escape);

    // ---- The premiere slot --------------------------------------------------
    final plan = app.premierePlan!;
    final home = app.channels.firstWhere((c) {
      final p = app.scheduleFor(c)?.programAt(slotStart.add(const Duration(seconds: 30)));
      return p != null && p.isPremiere && plan.homeOf.values.contains(c.id);
    });
    final premiere = app.scheduleFor(home)!.programAt(slotStart.add(const Duration(seconds: 30)));
    // ignore: avoid_print
    print('Premiere at $slotStart on ${home.number} ${home.name}: ${premiere.item!.guideTitle} ${premiere.item!.subtitle}');
    await waitUntil(slotStart.add(const Duration(seconds: 5)));
    await tester.runAsync(() => tuner.tune(home));
    await wait(const Duration(seconds: 4));
    expect(tuner.program!.isPremiere, isTrue);
    // Info brings up the banner, as the remote's button does.
    await press(LogicalKeyboardKey.keyI);
    expect(find.descendant(of: find.byType(ChannelBanner), matching: find.byType(NewTag)).hitTestable(), findsOneWidget,
        reason: 'NEW in the banner, on screen');
    await snap('extras-7-premiere-banner');
    await press(LogicalKeyboardKey.keyG);
    expect(find.byType(NewTag), findsWidgets, reason: 'NEW in the guide');
    await snap('extras-8-premiere-guide');
    await press(LogicalKeyboardKey.escape);

    await tester.runAsync(() async {
      await tuner.stop();
      await household.app?.close();
      // Keep the playback diagnostics log (diagnostics builds) for the record.
      final snapDir = _env['SNAP_DIR'];
      if (snapDir != null) {
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          if (f.path.endsWith('playback-debug.log')) await f.copy('$snapDir/playback-debug.log');
        }
      }
      await dir.delete(recursive: true);
    });
  }, timeout: const Timeout(Duration(minutes: 15)));
}
