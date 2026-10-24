// Music video channels against a real Jellyfin server: the scan, the
// generated channel, tuning, the banner, the logo, the guide's hour cells and
// Music tab, no Up next card, and nothing reported to Jellyfin:
//
//   JF_SERVER=https://... JF_USER=... JF_PW=... SNAP_DIR=/tmp/snaps \
//     flutter test integration_test/music_live_test.dart -d linux
//
// Needs some music videos. Takes up to ten minutes.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/channels/logo_windows.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/channel_logo_bug.dart';

final _env = Platform.environment;

// ignore: avoid_print
void _say(String s) => print('${DateTime.now().toIso8601String()} $s');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a music video channel on a real server', (tester) async {
    final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
    if (server == null || user == null || password == null) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW to run against a server.');
      return;
    }
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_music');
    final household = Household(await AppStorage.at(dir), runAnalysis: false);
    late final AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> waitUntil(DateTime t) =>
        wait(t.isBefore(DateTime.now()) ? Duration.zero : t.difference(DateTime.now()));

    Future<void> snap(String name) async {
      _say('snap $name');
      final snapDir = _env['SNAP_DIR'];
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

    bool logoUp() => find
        .descendant(of: find.byType(ChannelLogoBug), matching: find.byType(AnimatedOpacity))
        .evaluate()
        .any((e) => (e.widget as AnimatedOpacity).opacity == logoOpacity);

    bool upNextUp() => find
        .ancestor(of: find.textContaining('UP NEXT'), matching: find.byType(AnimatedOpacity))
        .evaluate()
        .any((e) => (e.widget as AnimatedOpacity).opacity == 1);

    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      final client = app.clientFor(ServerKind.jellyfin, server) as JellyfinClient;
      final info = await client.publicInfo();
      await app.completeSignIn(await client.authenticateByName(user, password, serverName: info.name), client);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    final client = app.client! as JellyfinClient;

    /// Each music video's play count and last played time in Jellyfin.
    Future<Map<String, String>> userData() async {
      final r = await tester.runAsync(() => http.get(
          client.uri('/Items', {
            'userId': client.userId,
            'IncludeItemTypes': 'MusicVideo',
            'Recursive': 'true',
            'Fields': 'UserData',
            'EnableImages': 'false',
          }),
          headers: client.authHeaders));
      return {
        for (final i in ((jsonDecode(r!.body) as Map)['Items'] as List).cast<Map<String, Object?>>())
          i['Id'] as String: '${(i['UserData'] as Map?)?['PlayCount']}/${(i['UserData'] as Map?)?['LastPlayedDate']}',
      };
    }

    // ---- The scan and the channel ---------------------------------------------
    final videos = app.library.musicVideos;
    _say('${videos.length} music videos: ${[for (final v in videos) '${v.artist} – ${v.title}'].join('; ')}');
    expect(videos, isNotEmpty);
    expect(videos.where((v) => v.artist != null), isNotEmpty, reason: 'artists from tags or "Artist - Title" names');
    final channel = app.channels.firstWhere((c) => c.name == 'Music Videos');
    _say('channel ${channel.number} ${channel.name}: ${channel.playlist.length} videos');
    expect(channel.icon.value, 'music_video');
    expect(channel.commercialPlan, BreakPlan.off);
    expect(app.channels.indexOf(channel), greaterThan(app.channels.lastIndexWhere((c) => c.source.includeMovies)));
    final artists = [for (final id in channel.playlist) app.library[id]!.artist];
    for (var i = 1; i < artists.length; i++) {
      if (artists[i] != null) expect(artists[i], isNot(artists[i - 1]), reason: 'artists spread out');
    }
    final before = await userData();

    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 2));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));

    // ---- Tuning, and the logo from the next video's start ------------------
    // Move the channel's start so the next video begins 25 s from now,
    // rather than waiting for the one on air to end.
    final boundary = DateTime.now().add(const Duration(seconds: 25));
    final onNow = app.scheduleFor(channel)!.programAt(DateTime.now());
    channel.anchor = channel.anchor.add(boundary.difference(onNow.end));
    await tester.runAsync(() => app.updateChannel(channel));
    final schedule = app.scheduleFor(channel)!;
    final next = schedule.programAt(boundary);
    expect(next.start, boundary);
    final watch = Stopwatch()..start();
    await tester.runAsync(() => tuner.tune(channel));
    while (tuner.status != TunerStatus.playing && watch.elapsed < const Duration(seconds: 20)) {
      await wait(const Duration(milliseconds: 50));
    }
    _say('tuned in ${watch.elapsedMilliseconds} ms; on now: ${tuner.program!.title}');
    expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    expect(tuner.program!.item!.isMusic, isTrue);
    await press(LogicalKeyboardKey.keyI);
    final item = tuner.program!.item!;
    expect(find.text(item.guideTitle), findsWidgets, reason: 'the banner says "Artist – Title"');
    await snap('music-1-banner');

    // No Up next card as the video ends.
    await waitUntil(next.start.subtract(const Duration(seconds: 6)));
    expect(upNextUp(), isFalse, reason: 'no Up next card on a music channel');
    await snap('music-2-no-up-next');
    // The next video: the logo from its start, as for any program part.
    final t = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    await waitUntil(next.start);
    final limit = next.start.add(const Duration(seconds: 15));
    while ((t.segment == null || t.segment!.start.isBefore(next.start)) && DateTime.now().isBefore(limit)) {
      await wait(const Duration(milliseconds: 100));
    }
    _say('hand-over to ${next.title} after ${DateTime.now().difference(next.start).inMilliseconds} ms');
    await wait(const Duration(seconds: 1));
    expect(t.segment!.item!.id, next.item!.id);
    expect(logoUp(), isTrue, reason: 'the logo at the start of a music video');
    await snap('music-3-logo');
    await waitUntil(next.start.add(logoWindowLength + const Duration(seconds: 1)));
    expect(logoUp(), isFalse);

    // ---- The guide: the Music tab and hour-long cells ------------------------
    await press(LogicalKeyboardKey.keyG);
    expect(app.guideTabs().map((t) => t.id), contains(GuideTabs.music));
    await tester.tap(find.text('MUSIC'), kind: PointerDeviceKind.mouse);
    await wait(const Duration(milliseconds: 500));
    final cells = schedule.guideProgramsBetween(DateTime.now(), DateTime.now().add(const Duration(minutes: 90)));
    expect(cells.first.title, 'Music Videos');
    expect(cells.first.end.difference(cells.first.start), const Duration(hours: 1));
    expect(find.textContaining('Now playing: '), findsOneWidget);
    await snap('music-4-guide');
    await press(LogicalKeyboardKey.escape);

    // ---- Nothing reported to Jellyfin ----------------------------------------
    await tester.runAsync(() async {
      await tuner.stop();
      await tuner.flushReports();
    });
    await wait(const Duration(seconds: 3));
    final after = await userData();
    expect(after, before, reason: 'play counts and last played are unchanged');
    _say('Jellyfin user data unchanged for ${after.length} music videos');

    await tester.runAsync(() async {
      await household.app?.close();
      await dir.delete(recursive: true);
    });
  }, timeout: const Timeout(Duration(minutes: 15)));
}
