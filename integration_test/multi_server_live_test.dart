// Multi-server checks against real servers (multi-server tasks 10.2, 10.3):
//
//   Different libraries: the test server (Jellyfin) as main, Docker Plex
//   added.
//     MULTI=different JF_URL=... JF_USER=... JF_PASSWORD=... PLEX_TOKEN=... \
//       flutter test integration_test/multi_server_live_test.dart -d linux \
//       --dart-define=NIGHTINGALE_TV_DEBUG_PLAYBACK=1
//
//   Mirrored library: Docker Emby as main, Docker Plex added, both on the
//   generated library (tool/test_servers/test_servers.sh up emby+plex).
//     MULTI=mirrored EMBY_USER=... EMBY_PASSWORD=... PLEX_TOKEN=... ...
//
// PLEX_TOKEN is the Docker Plex server's own token (its Preferences.xml
// PlexOnlineToken): the server is claimed, and signing in through plex.tv
// needs a person to link a code. Credentials only ever come from the
// environment.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_clients.dart';
import 'package:nightingale_tv/server/server_set.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

import 'media_servers_live_test.dart' show Recording;

final _env = Platform.environment;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final mode = _env['MULTI'];

  testWidgets('a profile with two servers (${mode ?? 'MULTI unset'})', (tester) async {
    if (mode != 'different' && mode != 'mirrored') {
      markTestSkipped('Set MULTI=different or MULTI=mirrored, with the servers up.');
      return;
    }
    MediaKit.ensureInitialized();
    // Down servers are tried again sooner than the app's minute.
    AppState.serverPingInterval = const Duration(seconds: 5);
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_multi');
    final household = Household(await AppStorage.at(dir));
    late final AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<T> io<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;

    Future<void> refreshed() async {
      await wait(const Duration(milliseconds: 300));
      for (var i = 0; i < 2400 && app.refreshing; i++) {
        await wait(const Duration(milliseconds: 250));
      }
    }

    // ---- The main server ----
    await io(() async {
      await household.start();
      app = household.app!;
      final url = mode == 'different' ? _env['JF_URL']! : (_env['EMBY_URL'] ?? 'http://127.0.0.1:8096');
      final user = mode == 'different' ? _env['JF_USER']! : _env['EMBY_USER']!;
      final password = mode == 'different' ? _env['JF_PASSWORD']! : _env['EMBY_PASSWORD']!;
      final found = await identifyServer(url, deviceId: app.settings.installId, deviceName: app.deviceName);
      final client = found.client as JellyfinClient;
      final session = await client.authenticateByName(user, password, serverName: found.info.name);
      await app.completeSignIn(session, client);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    final mainOnly = app.library;
    debugPrint('Main (${app.session!.serverName}): ${mainOnly.series.length} shows, ${mainOnly.episodes.length} '
        'episodes, ${mainOnly.movies.length} movies; ${app.channels.length} channels');
    final channelsBefore = {for (final c in app.channels) c.id: (c.number, [...c.playlist])};
    final now0 = DateTime.now();
    final airingBefore = {
      for (final c in app.channels) c.id: app.scheduleFor(c)?.programAt(now0.add(const Duration(minutes: 7))).item?.id,
    };

    // ---- Docker Plex, added ----
    await io(() async {
      const url = 'http://127.0.0.1:32400';
      final found = await identifyServer(url, deviceId: app.settings.installId, deviceName: app.deviceName);
      found.client.close();
      final session = ServerSession(
        kind: ServerKind.plex,
        serverUrl: url,
        serverName: found.info.name,
        serverId: found.info.id,
        userId: 'local',
        userName: 'local',
        accessToken: _env['PLEX_TOKEN'] ?? '',
        deviceId: app.settings.installId,
      );
      await app.addServer(session, app.clientForSession(session, key: 's2'), refresh: false);
      await app.refreshLibrary(background: true);
    });
    await refreshed();
    expect(app.servers.multiple, isTrue);
    expect(app.servers.byKey('s2')!.state, ServerState.ok, reason: app.syncError ?? '');
    final lib = app.library;
    final plexEpisodes = [
      for (final e in lib.episodes)
        for (final c in e.copies)
          if (ServerSet.keyOf(c.id) == 's2') c.id
    ];
    debugPrint('Merged: ${lib.series.length} shows, ${lib.episodes.length} episodes '
        '(${plexEpisodes.length} Plex copies), ${lib.movies.length} movies; ${app.channels.length} channels');
    expect(plexEpisodes, hasLength(24), reason: "the generated library's episodes, on Plex");

    // Labels: every library named after its server.
    final libraries = await io(app.allLibraries);
    debugPrint('Libraries: ${libraries.map((l) => l.name).join(' | ')}');
    expect(libraries.where((l) => l.id.startsWith('s2~')).map((l) => l.name),
        everyElement(startsWith('${app.servers.byKey('s2')!.name} › ')));
    expect(libraries.where((l) => !l.id.startsWith('s2~')).map((l) => l.name),
        everyElement(startsWith('${app.servers.main.name} › ')));

    if (mode == 'mirrored') {
      // Each generated show once, its episodes merged.
      expect(lib.series.map((s) => s.name).toSet(), {'Maple Street', 'Signal Hill', 'Night Desk'});
      expect(lib.episodes, hasLength(24));
      expect(lib.episodes.where((e) => e.alternates.isNotEmpty), hasLength(24), reason: 'every episode has its Plex copy');
    } else {
      expect(lib.series.where((s) => s.name == 'Maple Street'), hasLength(1));
      expect(lib.series.length, greaterThan(mainOnly.series.length));
      // Adding a server with other programs leaves what's on the air alone.
      final now = DateTime.now();
      for (final c in app.channels) {
        if (!channelsBefore.containsKey(c.id) || airingBefore[c.id] == null) continue;
        expect(c.number, channelsBefore[c.id]!.$1, reason: c.name);
        if (now.isBefore(now0.add(const Duration(minutes: 6)))) {
          expect(app.scheduleFor(c)?.programAt(now0.add(const Duration(minutes: 7))).item?.id, airingBefore[c.id],
              reason: '${c.name} airs the same program');
        }
      }
    }
    final both = app.channels.where((c) =>
        c.playlist.any((id) => ServerSet.keyOf(id) == 's2') && c.playlist.any((id) => ServerSet.keyOf(id) == 'main'));
    debugPrint('Channels with programs from both servers: ${both.map((c) => c.name).join(', ')}');
    if (mode == 'different') expect(both, isNotEmpty, reason: 'channels play programs from both servers');

    // Every request through recorders.
    final home = Recording(app.client!);
    final plex = Recording(app.servers.byKey('s2')!.client!);
    app.client = home;
    app.servers.byKey('s2')!.client = plex;

    // ---- The TV ----
    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 2));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    for (var i = 0; i < 80 && tuner.status != TunerStatus.playing; i++) {
      await wait(const Duration(milliseconds: 250));
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    Future<void> tuneAndPlay(Channel ch) async {
      await io(() => tuner.tune(ch));
      for (var i = 0; i < 80 && tuner.status != TunerStatus.playing; i++) {
        await wait(const Duration(milliseconds: 250));
      }
      expect(tuner.status, TunerStatus.playing, reason: '${ch.name}: ${tuner.error}');
    }

    /// A channel and the next program part on it whose entry has a copy on
    /// [key] ([only]: no other copy), brought on the air now by moving the
    /// channel's anchor.
    Future<Channel> bringOnAir(String key, {bool only = false}) async {
      final now = DateTime.now();
      for (final c in app.channels.where((c) => !c.isMusic && !c.isLive)) {
        final schedule = app.scheduleFor(c);
        if (schedule == null) continue;
        var t = now;
        for (var i = 0; i < 400; i++) {
          final p = schedule.playbackAt(t);
          final from = t.isAfter(p.start) ? t : p.start;
          final item = p.item;
          if (item != null &&
              !p.isCommercial &&
              !p.isBreak &&
              item.copies.any((x) => ServerSet.keyOf(x.id) == key) &&
              (!only || item.copies.every((x) => ServerSet.keyOf(x.id) == key)) &&
              p.end.difference(from) > const Duration(seconds: 90)) {
            c.anchor = c.anchor.subtract(from.add(const Duration(seconds: 20)).difference(now));
            await io(() => app.updateChannel(c));
            return c;
          }
          t = p.end;
        }
      }
      throw StateError('Nothing from $key is on any channel');
    }

    // ---- A Plex program, and a main server one ----
    if (mode == 'mirrored') await io(() => app.moveServer('s2', -1));
    home.log.clear();
    plex.log.clear();
    final onPlex = await bringOnAir('s2', only: mode == 'different');
    await tuneAndPlay(onPlex);
    await wait(const Duration(seconds: 6));
    expect(tuner.debugPlayingKey, 's2', reason: 'Plex is first in Play from, or the only copy');
    final plexItem = tuner.segment!.item!;
    final plexRaw = ServerSet.rawId(plexItem.copies.firstWhere((c) => ServerSet.keyOf(c.id) == 's2').id);
    debugPrint('On ${onPlex.name} from Plex: ${plexItem.title} (Plex $plexRaw) — Plex: ${plex.log.join(' ')}');
    expect(plex.log, contains('stream:$plexRaw'));
    expect(plex.log, contains('start:$plexRaw'));
    expect(home.log.where((l) => l.startsWith('start:') || l.startsWith('stream:')), isEmpty,
        reason: 'nothing of this program goes to the other server');

    if (mode == 'different') {
      home.log.clear();
      final onMain = await bringOnAir('main', only: true);
      await tuneAndPlay(onMain);
      await wait(const Duration(seconds: 6));
      expect(tuner.debugPlayingKey, 'main');
      final mainItem = tuner.segment!.item!;
      debugPrint('On ${onMain.name} from ${app.servers.main.name}: ${mainItem.title}');
      expect(home.log, contains('start:${mainItem.id}'));
      expect(plex.log.where((l) => l.contains(mainItem.id)), isEmpty);
    }
    for (final l in [...home.log, ...plex.log]) {
      expect(l, isNot(contains('~')), reason: 'servers see only their own ids');
    }

    if (mode == 'mirrored') {
      // ---- Failover: Plex stops mid-program ----
      final ch = await bringOnAir('s2');
      await tuneAndPlay(ch);
      await wait(const Duration(seconds: 5));
      expect(tuner.debugPlayingKey, 's2');
      final program = tuner.program!;
      debugPrint('Stopping Plex during ${program.item!.title}');
      await io(() => Process.run('sg', ['docker', '-c', 'docker stop nightingale-plex']));
      for (var i = 0; i < 240 && tuner.debugPlayingKey != 'main'; i++) {
        await wait(const Duration(milliseconds: 500));
      }
      expect(tuner.debugPlayingKey, 'main', reason: 'the program carries on from Emby: ${tuner.error}');
      for (var i = 0; i < 80 && tuner.status != TunerStatus.playing; i++) {
        await wait(const Duration(milliseconds: 250));
      }
      expect(tuner.status, TunerStatus.playing, reason: '${tuner.error}');
      expect(tuner.program!.item!.id, program.item!.id, reason: 'the same program, at its scheduled position');
      expect(app.servers.byKey('s2')!.state, ServerState.unreachable);

      // A refresh with Plex down keeps its copies.
      await io(() => app.refreshLibrary(background: true));
      await refreshed();
      expect(app.library.episodes.where((e) => e.alternates.isNotEmpty), hasLength(24),
          reason: "Plex's copies stay while it's down");
      expect(app.servers.byKey('s2')!.state, ServerState.unreachable);

      // Back up: tried again, and used again.
      await io(() => Process.run('sg', ['docker', '-c', 'docker start nightingale-plex']));
      for (var i = 0; i < 240 && app.servers.byKey('s2')!.state != ServerState.ok; i++) {
        await wait(const Duration(milliseconds: 500));
      }
      expect(app.servers.byKey('s2')!.state, ServerState.ok, reason: 'Plex answers again');
      final again = await bringOnAir('s2');
      await tuneAndPlay(again);
      expect(tuner.debugPlayingKey, 's2', reason: 'Plex is used again');
    } else {
      // ---- A custom channel from both servers ----
      final plexLibraries = [for (final l in libraries) if (l.id.startsWith('s2~')) l];
      final plexTv = plexLibraries.firstWhere((l) => l.collectionType == 'tvshows');
      final maple = app.library.series.firstWhere((s) => s.name == 'Maple Street');
      final mainTv = libraries.firstWhere((l) => !l.id.startsWith('s2~') && l.collectionType == 'tvshows');
      final mainShow = app.library.series.firstWhere((s) => !s.id.startsWith('s2~'));
      final custom = await io(() => app.createCustomChannel(
          'Both servers',
          ChannelSource(roots: [
            PoolRoot(itemId: maple.id, libraryId: plexTv.id, label: '${plexTv.name} › Maple Street'),
            PoolRoot(itemId: mainShow.id, libraryId: mainTv.id, label: '${mainTv.name} › ${mainShow.name}'),
          ])));
      final fromPlex = custom.playlist.where((id) => ServerSet.keyOf(id) == 's2').length;
      final fromMain = custom.playlist.where((id) => ServerSet.keyOf(id) == 'main').length;
      debugPrint('Custom channel: $fromPlex Plex episodes, $fromMain from ${mainShow.name}');
      expect(fromPlex, 8, reason: "Maple Street's episodes");
      expect(fromMain, greaterThan(0));

      // ---- A commercial pool from both servers ----
      FolderNode? named(List<FolderNode> nodes, String name) {
        for (final n in nodes) {
          if (n.name.toLowerCase() == name) return n;
          if (named(n.children, name) case final inside?) return inside;
        }
        return null;
      }

      final plexHome = plexLibraries.firstWhere((l) => l.name.endsWith('Home Videos'));
      final plexAds = named(await io(() => app.clientOf(plexHome.id)!.folderTree(plexHome.id)), 'commercials')!;
      final mainAds = libraries.firstWhere((l) => !l.id.startsWith('s2~') && l.name.toLowerCase().contains('commercial'));
      final pool = await io(app.createPool);
      await io(() => app.setPoolRoots(pool, [
            PoolRoot(itemId: plexAds.id, libraryId: plexHome.id, label: 'Commercials'),
            PoolRoot(itemId: mainAds.id, libraryId: mainAds.id, label: 'Commercials'),
          ]));
      await refreshed();
      final ads = app.library.commercials.where((c) => c.poolIds.contains(pool.id));
      final plexAdCount = ads.where((c) => ServerSet.keyOf(c.id) == 's2').length;
      final mainAdCount = ads.where((c) => ServerSet.keyOf(c.id) == 'main').length;
      debugPrint('Pool: $plexAdCount Plex clips, $mainAdCount from ${mainAds.name}');
      expect(plexAdCount, greaterThan(30));
      expect(mainAdCount, greaterThan(30));

      // ---- Live TV per server ----
      for (final s in app.servers.ordered) {
        debugPrint('Live TV on ${s.name}: ${await io(() => app.liveTvAvailability(key: s.key))}');
      }

      // ---- Removing Plex ----
      await io(() => app.removeServer('s2'));
      await refreshed();
      expect(app.servers.multiple, isFalse);
      expect([for (final e in app.library.episodes) if (e.id.startsWith('s2~')) e], isEmpty);
      expect(app.allChannels.expand((c) => c.playlist).where((id) => id.startsWith('s2~')), isEmpty);
      final kept = app.channelById(custom.id)!;
      expect(kept.playlist, isNotEmpty, reason: 'it airs what is left');
      expect(app.rootMissing(kept.source.roots.first), isTrue, reason: 'the Plex source shows as not found');
      for (final c in app.channels) {
        if (channelsBefore[c.id] case final before?) expect(c.number, before.$1, reason: c.name);
      }
    }

    await io(tuner.stop);
    await io(household.closeAll);
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 40)));
}
