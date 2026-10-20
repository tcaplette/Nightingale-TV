// End-to-end smoke test against a real Jellyfin server.
//
//   JF_SERVER=https://... JF_USER=... JF_PW=... SNAP_DIR=/tmp/snaps \
//     flutter test integration_test/smoke_test.dart -d linux
//
// or, with a saved sign-in instead of a password (it's read from the file,
// and isn't signed out at the end):
//
//   JF_SESSION=~/.local/share/com.coffeehauslabs.nightingale_tv/profiles/<id>/session.json ...
//
// Signs in, waits for the lineup, checks that playback really starts, drives
// the guide with the keyboard, and saves screenshots to SNAP_DIR (if set).
//
// The second test sets up commercial breaks from the server's commercials
// folder (JF_POOL_FOLDER, default 80s-2000s-commercial-compilation), lets
// analysis split its reels, and watches a real break. JF_ANALYSIS_CACHE (a
// folder) keeps the analysis between runs.
import 'dart:convert';
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
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/analysis/break_points.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

final _env = Platform.environment;

/// Signs [app] in with JF_SESSION (a saved sign-in) or JF_SERVER, JF_USER
/// and JF_PW. False when none are set. With a saved sign-in, [borrowed] is
/// set, and the test must not sign out (that would revoke it).
Future<bool> _signIn(AppState app, void Function() borrowed) async {
  final sessionFile = _env['JF_SESSION'];
  if (sessionFile != null) {
    final json = jsonDecode(await File(sessionFile.replaceFirst('~', _env['HOME']!)).readAsString());
    final session = JellyfinSession.fromJson(json as Map<String, Object?>);
    borrowed();
    await app.completeSignIn(session, JellyfinClient.fromSession(session, deviceName: app.deviceName));
    return true;
  }
  final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
  if (server == null || user == null || password == null) return false;
  final client = app.clientFor(server);
  final info = await client.publicInfo();
  final session = await client.authenticateByName(user, password, serverName: info.name);
  await app.completeSignIn(session, client);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final env = _env;

  testWidgets('sign in, tune, surf, guide', (tester) async {
    if (env['JF_SESSION'] == null && (env['JF_SERVER'] == null || env['JF_USER'] == null || env['JF_PW'] == null)) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW (or JF_SESSION) to run against a server.');
      return;
    }
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_test');
    final household = Household(await AppStorage.at(dir));
    late final AppState app;
    late final Tuner tuner;

    // Draws frames all along, so animations run to the end.
    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> snap(String name) async {
      final snapDir = env['SNAP_DIR'];
      if (snapDir == null) return;
      await tester.pump();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image = await tester.runAsync(
          () => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      await File('$snapDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    Future<void> press(LogicalKeyboardKey key, {Duration after = const Duration(milliseconds: 600)}) async {
      // Flutter drops keyboard focus while the window is in the background.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.sendKeyEvent(key);
      await wait(after);
    }

    var borrowed = false;
    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      await _signIn(app, () => borrowed = true);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    expect(app.channels, isNotEmpty);

    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 1));
    tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    expect(tuner.channel, isNotNull, reason: 'TV powers on to a channel');

    // Playback: the stream must open and the position must move.
    for (var i = 0; i < 30 && tuner.status != TunerStatus.playing; i++) {
      await wait(const Duration(milliseconds: 500));
    }
    expect(tuner.status, TunerStatus.playing, reason: 'error: ${tuner.error}');
    // The first position report can come before mpv has jumped to the
    // start position; give it a moment.
    await wait(const Duration(seconds: 2));
    final p1 = tuner.media.position;
    final expected = tuner.segment!.positionAt(DateTime.now());
    await wait(const Duration(seconds: 3));
    expect(tuner.media.position, greaterThan(p1), reason: 'video is advancing');
    expect((p1 - expected).abs(), lessThan(const Duration(seconds: 15)),
        reason: 'joined mid-program at the scheduled offset');
    await snap('1-watch-banner');

    // Channel up, then number entry.
    final firstChannel = tuner.channel!.number;
    await press(LogicalKeyboardKey.arrowUp, after: const Duration(seconds: 2));
    expect(tuner.channel!.number, isNot(firstChannel));
    await snap('2-channel-up');
    final target = app.channels[app.channels.length ~/ 2].number;
    for (final d in '$target'.split('')) {
      await press(LogicalKeyboardKey(0x30 + int.parse(d)), after: const Duration(milliseconds: 200));
    }
    await snap('3-number-entry');
    await press(LogicalKeyboardKey.enter, after: const Duration(seconds: 2));
    expect(tuner.channel!.number, target);

    // Guide.
    await press(LogicalKeyboardKey.keyG, after: const Duration(seconds: 2));
    await snap('4-guide');
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowRight);
    await snap('5-guide-moved');
    await press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));

    // Menu → channel editor → icon picker tabs.
    await press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
    await snap('6-menu');
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    await snap('7-channel-editor');
    await tester.tap(find.text('Change icon'));
    await wait(const Duration(seconds: 1));
    await snap('8-icons-builtin');
    for (final tab in ['9-icons-badges', '10-icons-shows', '11-icons-mine']) {
      await press(LogicalKeyboardKey.arrowRight, after: const Duration(seconds: 2));
      await snap(tab);
    }
    // Choose a built-in icon and check the channel picked it up.
    await press(LogicalKeyboardKey.arrowLeft);
    await press(LogicalKeyboardKey.arrowLeft);
    await press(LogicalKeyboardKey.arrowLeft, after: const Duration(seconds: 1));
    final edited = app.allChannels.first;
    await tester.tap(find.byIcon(Icons.connected_tv).first);
    await wait(const Duration(seconds: 1));
    expect(edited.icon.value, 'connected_tv');
    await snap('12-editor-after-icon');

    await tester.runAsync(() async {
      await tuner.stop();
      if (!borrowed) await app.client?.logout();
      await app.close();
    });
    await tester.pumpWidget(const SizedBox());
    await wait(const Duration(milliseconds: 500));
    await dir.delete(recursive: true);
  });

  testWidgets('commercial breaks from the server\'s commercials folder', (tester) async {
    if (env['JF_SESSION'] == null && (env['JF_SERVER'] == null || env['JF_USER'] == null || env['JF_PW'] == null)) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW (or JF_SESSION) to run against a server.');
      return;
    }
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_test');
    final household = Household(await AppStorage.at(dir));
    late final AppState app;
    var borrowed = false;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> snap(String name) async {
      final snapDir = env['SNAP_DIR'];
      if (snapDir == null) return;
      await tester.pump();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image = await tester.runAsync(
          () => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      await File('$snapDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    Future<Map<String, Object?>> userData(JellyfinClient client, String id) async {
      final item = (await tester.runAsync(() => client.allItems({'Ids': id})))!.single;
      return (item['UserData'] as Map?)?.cast<String, Object?>() ?? const {};
    }

    // JF_ANALYSIS_CACHE: a folder to keep analysis results in between runs
    // (splitting the reels takes a while).
    final keep = env['JF_ANALYSIS_CACHE'];
    if (keep != null && Directory(keep).existsSync()) {
      await Directory('${dir.path}/analysis').create(recursive: true);
      for (final f in Directory(keep).listSync().whereType<File>()) {
        await f.copy('${dir.path}/analysis/${f.uri.pathSegments.last}');
      }
    }
    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      await _signIn(app, () => borrowed = true);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    final client = app.client!;

    // A pool on the commercials folder.
    final folderName = env['JF_POOL_FOLDER'] ?? '80s-2000s-commercial-compilation';
    PoolRoot? root;
    for (final lib in (await tester.runAsync(client.libraries))!.where((l) => l.isVideo)) {
      final tree = (await tester.runAsync(() => client.folderTree(lib.id)))!;
      FolderNode? find(List<FolderNode> nodes) {
        for (final n in nodes) {
          if (n.name == folderName) return n;
          final inside = find(n.children);
          if (inside != null) return inside;
        }
        return null;
      }

      final node = find(tree);
      if (node != null) root = PoolRoot(itemId: node.id, libraryId: lib.id, label: '${lib.name} › ${node.name}');
    }
    expect(root, isNotNull, reason: 'no folder named $folderName');
    final pool = (await tester.runAsync(app.createPool))!;
    await tester.runAsync(() => app.setPoolRoots(pool, [root!]));
    for (var i = 0; i < 360 && (app.refreshing || app.library.commercials.isEmpty); i++) {
      await wait(const Duration(milliseconds: 500));
    }
    final reels = [for (final c in app.library.commercials) if (c.runtime > LibraryIndex.maxClip) c];
    expect(reels, isNotEmpty, reason: 'the folder holds long commercial videos');
    final before = {for (final r in reels) r.id: await userData(client, r.id)};

    // Analysis splits the reels (ffmpeg, through the loopback proxy).
    final watch = Stopwatch()..start();
    for (var i = 0; i < 60 * 40 && app.analysisProgress.value.reelsDone < reels.length; i++) {
      await wait(const Duration(seconds: 1));
    }
    debugPrint('Split ${reels.length} reels in ${watch.elapsed.inSeconds} s');
    for (final reel in reels) {
      final clips = [for (final c in app.catalog.clipsFor(pool.id)) if (c.sourceId == reel.id) c];
      final lengths = [for (final c in clips) c.runtime.inMilliseconds / 1000]..sort();
      debugPrint('${reel.title}: ${clips.length} clips, median ${lengths[lengths.length ~/ 2]} s');
      expect(clips.length, greaterThan(50), reason: '${reel.title} splits into ads');
      expect(lengths[lengths.length ~/ 2], inInclusiveRange(15, 75));
      expect(clips.every((c) => c.runtime <= LibraryIndex.maxClip && c.runtime >= LibraryIndex.minClip), isTrue);
    }

    if (keep != null) {
      await tester.runAsync(() async {
        await app.analysisCache!.flush();
        await Directory(keep).create(recursive: true);
        for (final f in Directory('${dir.path}/analysis').listSync().whereType<File>()) {
          if (f.path.endsWith('.json')) await f.copy('$keep/${f.uri.pathSegments.last}');
        }
      });
    }
    await tester.runAsync(() => app.setGlobalPlan(BreakPlan.automatic));
    expect(app.channels.every(app.breaksFor), isTrue);

    /// A channel airing [item], and its layout of [item] for a slot now.
    (ChannelSchedule, List<({Duration from, Duration to})>)? layoutOf(MediaEntry item) {
      for (final ch in app.channels) {
        if (!ch.playlist.contains(item.id)) continue;
        final schedule = app.scheduleFor(ch)!;
        final layout = schedule.layoutFor(item, DateTime.now());
        return (
          schedule,
          [for (final s in layout.segments) if (s.isShow) (from: s.itemFrom, to: s.itemFrom + s.length)],
        );
      }
      return null;
    }

    // An Archer episode breaks at its chapter points.
    final archer = app.library.episodes
        .where((e) => (e.seriesName ?? '').startsWith('Archer') && e.chapters.length > 2)
        .firstOrNull;
    expect(archer, isNotNull, reason: 'an Archer episode with chapters');
    final (_, archerParts) = layoutOf(archer!)!;
    final chapterPoints = BreakPointFinder.chapterCandidates(archer.runtime, archer.chapters);
    final stops = [for (final p in archerParts.take(archerParts.length - 1)) p.to];
    debugPrint('${archer.title}: chapters $chapterPoints, breaks at $stops');
    expect(stops, isNotEmpty);
    expect(stops.any(chapterPoints.contains), isTrue, reason: 'a mid-roll on a chapter point');

    // A movie gets mid-rolls.
    final movie = app.library.movies.firstWhere((m) => layoutOf(m) != null);
    final (movieSchedule, movieParts) = layoutOf(movie)!;
    expect(movieSchedule.slotPlanFor(movie).midCount, greaterThan(0));
    expect(movieParts.length, movieSchedule.slotPlanFor(movie).midCount + 1, reason: '${movie.title} breaks inside');

    // A real break, on screen: the channel whose next break is soonest.
    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 1));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    final now = DateTime.now();
    var best = (channel: app.channels.first, at: now.add(const Duration(days: 1)));
    for (final ch in app.channels) {
      final schedule = app.scheduleFor(ch)!;
      var t = now;
      for (var i = 0; i < 40; i++) {
        final p = schedule.playbackAt(t);
        if (p.isCommercial && p.end.difference(now) > const Duration(seconds: 20)) {
          final at = p.start.isAfter(now) ? p.start : now;
          if (at.isBefore(best.at)) best = (channel: ch, at: at);
          break;
        }
        t = p.end;
      }
    }
    debugPrint('Next break on ${best.channel.name} at ${best.at}');
    await tester.runAsync(() => tuner.tune(best.channel));
    while (!tuner.inBreak || !tuner.segment!.isCommercial) {
      await wait(const Duration(seconds: 1));
      expect(DateTime.now().isBefore(best.at.add(const Duration(minutes: 2))), isTrue, reason: 'the break came');
    }
    for (var i = 0; i < 30 && tuner.status != TunerStatus.playing; i++) {
      await wait(const Duration(milliseconds: 500));
    }
    expect(tuner.status, TunerStatus.playing, reason: 'the clip plays: ${tuner.error}');
    final clip = tuner.segment!;
    await wait(const Duration(seconds: 2));
    final position = tuner.media.position;
    final scheduled = clip.positionAt(DateTime.now());
    debugPrint('Clip ${clip.item!.id}: ${clip.itemFrom}–${clip.itemTo}, playing at $position, scheduled $scheduled');
    expect(position >= clip.itemFrom && position <= clip.itemTo, isTrue,
        reason: 'plays its range of the reel: $position in ${clip.itemFrom}–${clip.itemTo}');
    expect((position - scheduled).abs(), lessThan(const Duration(seconds: 5)), reason: 'at the scheduled point');
    // ◀ shows the banner.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await wait(const Duration(seconds: 1));
    expect(find.textContaining('Commercial break'), findsOneWidget);
    await snap('13-commercial-break');

    // Wait out the clip; the reel is never reported to Jellyfin.
    await wait(clip.end.difference(DateTime.now()) + const Duration(seconds: 3));
    await tester.runAsync(() async {
      await tuner.stop();
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    for (final r in reels) {
      final after = await userData(client, r.id);
      expect(after['PlayCount'], before[r.id]!['PlayCount'], reason: '${r.title} was never reported');
      expect(after['PlaybackPositionTicks'], before[r.id]!['PlaybackPositionTicks']);
      expect(after['Played'], before[r.id]!['Played']);
    }

    await tester.runAsync(() async {
      if (!borrowed) await app.client?.logout();
      await app.close();
    });
    await tester.pumpWidget(const SizedBox());
    await wait(const Duration(milliseconds: 500));
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 75)));
}
