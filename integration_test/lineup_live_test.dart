// Lineup blocks and the "Up next" card against a real Jellyfin server, so
// programs really play:
//
//   JF_SERVER=https://... JF_USER=... JF_PW=... SNAP_DIR=/tmp/snaps \
//     flutter test integration_test/lineup_live_test.dart -d linux
//
// Sets up blocks timed so a program ends a minute or two after tuning in,
// then waits for the card. Takes about five minutes.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

final _env = Platform.environment;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Up next card comes up before lineup episodes and blocks', (tester) async {
    final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
    if (server == null || user == null || password == null) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW to run against a server.');
      return;
    }
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_lineup');
    final household = Household(await AppStorage.at(dir));
    late final AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> snap(String name) async {
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

    /// The Up next card is fully up (it stays in the tree, faded out,
    /// while hidden).
    bool cardUp() => find
        .ancestor(of: find.textContaining('UP NEXT'), matching: find.byType(AnimatedOpacity))
        .evaluate()
        .any((e) => (e.widget as AnimatedOpacity).opacity == 1);

    /// Pumps until the card is up, or [limit] passes; then lets it slide
    /// in.
    Future<DateTime?> waitForCard(Duration limit) async {
      final end = DateTime.now().add(limit);
      while (DateTime.now().isBefore(end)) {
        await wait(const Duration(milliseconds: 500));
        if (cardUp()) {
          final at = DateTime.now();
          await wait(const Duration(milliseconds: 600));
          return at;
        }
      }
      return null;
    }

    int minuteOf(DateTime t) => t.hour * 60 + t.minute;

    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      final client = app.clientFor(ServerKind.jellyfin, server) as JellyfinClient;
      final info = await client.publicInfo();
      final session = await client.authenticateByName(user, password, serverName: info.name);
      await app.completeSignIn(session, client);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 1));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));

    // Two shows with full-length first episodes.
    final shows = [
      for (final s in app.library.series)
        if (app.library.episodesBySeries[s.key] case final eps?
            when eps.length >= 2 && eps.first.runtime >= const Duration(minutes: 10) &&
                eps.first.runtime <= const Duration(minutes: 70))
          (key: s.key, episodes: eps),
    ];
    expect(shows.length, greaterThanOrEqualTo(2), reason: 'needs two shows with episodes');
    final first = shows[0], second = shows[1];
    final opener = first.episodes.first;

    // 1. A lineup whose first episode ends 70–130 s from now: the card
    //    names the next slot's episode.
    var now = DateTime.now();
    final start = now.add(const Duration(seconds: 130)).subtract(opener.runtime);
    final lineup = app.newBlock()
      ..title = 'Live Lineup'
      ..channelId = app.channels.first.id
      ..days = {1, 2, 3, 4, 5, 6, 7}
      ..startMinute = minuteOf(start)
      ..endMinute = (minuteOf(start) + 180) % (24 * 60)
      ..lineup = [LineupSlot(seriesKey: first.key), LineupSlot(seriesKey: second.key)];
    await tester.runAsync(() => app.saveBlock(lineup));
    await tester.runAsync(() => tuner.tune(app.channels.first));
    await wait(const Duration(seconds: 3));
    expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    expect(tuner.program!.item!.id, opener.id);
    expect(cardUp(), isFalse, reason: 'up too early');
    final programEnd = tuner.program!.end;
    final shown = await waitForCard(const Duration(seconds: 150));
    await snap('live1-up-next-lineup');
    expect(shown, isNotNull, reason: 'no Up next card before ${opener.guideTitle} ended at $programEnd');
    final lead = programEnd.difference(shown!);
    expect(lead.inSeconds, inInclusiveRange(55, 61), reason: 'came up $lead before the end');
    expect(find.text(second.episodes.first.guideTitle), findsWidgets);
    expect(find.text(second.episodes.first.subtitle), findsOneWidget);
    // It goes away after 15 seconds.
    await wait(const Duration(seconds: 16));
    expect(cardUp(), isFalse, reason: 'still up after 15 s');
    await snap('live2-up-next-gone');

    // 2. A block starting in 75–135 s on another channel cuts its regular
    //    program short: the card announces the block.
    await tester.runAsync(() => app.deleteBlock(lineup));
    final regular = app.channels[1];
    now = DateTime.now();
    final blockStart = minuteOf(now.add(const Duration(seconds: 135)));
    final block = app.newBlock()
      ..title = 'Live Block'
      ..channelId = regular.id
      ..days = {1, 2, 3, 4, 5, 6, 7}
      ..startMinute = blockStart
      ..endMinute = (blockStart + 60) % (24 * 60)
      ..lineup = [LineupSlot(seriesKey: second.key)];
    await tester.runAsync(() => app.saveBlock(block));
    await tester.runAsync(() => tuner.tune(regular));
    await wait(const Duration(seconds: 3));
    expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    expect(cardUp(), isFalse, reason: 'up too early');
    final cutAt = tuner.program!.end;
    final announced = await waitForCard(const Duration(seconds: 150));
    await snap('live3-up-next-block');
    expect(announced, isNotNull,
        reason: 'no Up next card before the block; ${tuner.program?.title} on until $cutAt');
    expect(find.text('Live Block'), findsOneWidget);
    expect(find.textContaining('Starting with'), findsOneWidget);

    await tester.runAsync(() async {
      await tuner.stop();
      await app.client?.logout();
    });
    await dir.delete(recursive: true);
  });
}

