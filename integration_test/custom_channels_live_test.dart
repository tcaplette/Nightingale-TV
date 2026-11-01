// Custom channels against a real Jellyfin server (custom-channels 2.7, 11.2,
// 11.6), in a temporary profile:
//
//   JF_SERVER=https://... JF_USER=... JF_PW=... SNAP_DIR=/tmp/snaps \
//     flutter test integration_test/custom_channels_live_test.dart -d linux \
//     --dart-define=NIGHTINGALE_TV_DEBUG_PLAYBACK=1
//
// Needs a "Commercials" library of short clips. Scan timings, a channel from a
// server root plus a show, then filler, offline and truncate hand-overs on the
// TV and in an exported stream, with each event's schedule moved a minute away.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

/// From the environment, or on a device from --dart-define.
final _env = <String, String?>{
  ...Platform.environment,
  if (const String.fromEnvironment('JF_SERVER') != '') 'JF_SERVER': const String.fromEnvironment('JF_SERVER'),
  if (const String.fromEnvironment('JF_USER') != '') 'JF_USER': const String.fromEnvironment('JF_USER'),
  if (const String.fromEnvironment('JF_PW') != '') 'JF_PW': const String.fromEnvironment('JF_PW'),
  if (const String.fromEnvironment('CC_SKIP_FILLER') != '') 'CC_SKIP_FILLER': '1',
  if (const String.fromEnvironment('CC_CLEAN_CUT') != '') 'CC_CLEAN_CUT': '1',
};

// ignore: avoid_print
void _say(String s) => print('${DateTime.now().toIso8601String()} $s');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a custom channel with slots on a real server', (tester) async {
    final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
    if (server == null || user == null || password == null) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW to run against a server.');
      return;
    }
    // Android plays with ExoPlayer: there's no mpv to load.
    if (!Platform.isAndroid) MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_custom_live');
    final household = Household(await AppStorage.at(dir), runAnalysis: false);
    late AppState app;

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
      final image =
          await tester.runAsync(() => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      await File('$snapDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    // ---- Sign in, with the Commercials library as the pool ---------------------
    late JellyfinClient client;
    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      client = app.clientFor(ServerKind.jellyfin, server) as JellyfinClient;
      final info = await client.publicInfo();
      await app.completeSignIn(await client.authenticateByName(user, password, serverName: info.name), client);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    final libraries = (await tester.runAsync(client.libraries))!;
    final ads = libraries.firstWhere((l) => l.name == 'Commercials');
    await tester.runAsync(() async {
      final pool = await app.createPool();
      await app.setPoolRoots(pool, [PoolRoot(itemId: ads.id, libraryId: ads.id, label: ads.name)]);
    });
    for (var i = 0; i < 2400 && (app.refreshing || app.library.commercials.isEmpty); i++) {
      await wait(const Duration(milliseconds: 100));
    }
    expect(app.library.commercials, isNotEmpty);

    // ---- 2.7: what user data costs a scan ----------------------------------------
    await tester.runAsync(() async {
      for (final lib in libraries.where((l) => l.isVideo && l.id != ads.id)) {
        for (final userData in ['false', 'true', 'false', 'true']) {
          final sw = Stopwatch()..start();
          final items = await client.allItems({
            'ParentId': lib.id,
            'Recursive': 'true',
            'IncludeItemTypes': 'Episode,Movie',
            'IsMissing': 'false',
            'Fields': 'Overview,Chapters,Etag,DateCreated',
            'EnableImages': 'false',
            'EnableUserData': userData,
          });
          _say('TIMING ${lib.name}: ${items.length} items, user data $userData: ${sw.elapsedMilliseconds} ms');
        }
      }
    });
    final library = app.library;
    _say('play counts: ${library.episodes.where((e) => e.playCount > 0).length} of ${library.episodes.length} episodes, '
        '${library.movies.where((e) => e.playCount > 0).length} of ${library.movies.length} movies');

    // ---- 11.2: a root (the test server has no collections: a show's folder node,
    // season 1) plus one show, least watched first --------------------------------
    FolderNode? box, season, show;
    late ServerLibrary tvLibrary;
    for (final lib in libraries.where((l) => l.isCollections || (l.collectionType == 'tvshows' && l.id != ads.id))) {
      void look(List<FolderNode> nodes) {
        for (final n in nodes) {
          if (box == null && n.type == 'BoxSet') {
            box = n;
            tvLibrary = lib;
          }
          if (box == null && season == null && n.type == 'Season') {
            season = n;
            tvLibrary = lib;
          }
          if (show == null && n.type == 'Series') show = n;
          look(n.children);
        }
      }

      look((await tester.runAsync(() => client.folderTree(lib.id)))!);
      if (box == null && season == null && show != null) tvLibrary = lib;
    }
    _say('collection on the server: ${box?.name}');
    final node = box ?? season ?? show;
    expect(node, isNotNull);
    final root = PoolRoot(itemId: node!.id, libraryId: tvLibrary.id, label: node.name);
    final other = library.series.lastWhere((s) => (library.episodesBySeries[s.key]?.length ?? 0) >= 4);
    final ch = (await tester.runAsync(() => app.createCustomChannel(
        '80s TV', ChannelSource(roots: [root], seriesKeys: [other.key], includeEpisodes: true),
        order: PlaybackOrder.weighted)))!;
    _say('channel ${ch.number}: ${ch.playlist.length} programs; root holds ${app.library.itemsByRoot[root.itemId]?.length}');
    expect(app.library.itemsByRoot[root.itemId], isNotEmpty);
    expect(ch.playlist, containsAll(app.library.itemsByRoot[root.itemId]!));

    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 2));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));

    // CC_CLEAN_CUT=1: only a slot watched from its start to its cut, with no
    // mid-program join behind schedule. Takes 15 minutes.
    if (_env['CC_CLEAN_CUT'] != null) {
      await tester.runAsync(() => app.setSlotRule(ch, const SlotRule(length: Duration(minutes: 15), tail: TailMode.truncate)));
      final slots = app.scheduleFor(ch)!.programsBetween(DateTime.now(), DateTime.now().add(const Duration(days: 2)));
      final cutSlot = slots.skip(1).firstWhere((p) => p.endsEarly);
      final start = DateTime.now().add(const Duration(seconds: 10));
      ch.anchor = ch.anchor.add(start.difference(cutSlot.start));
      ch.slotCarry = null;
      await tester.runAsync(() => app.updateChannel(ch));
      await wait(start.add(const Duration(milliseconds: 300)).difference(DateTime.now()));
      await tester.runAsync(() => tuner.tune(ch));
      final cut = start.add(const Duration(minutes: 15));
      await wait(cut.subtract(const Duration(seconds: 60)).difference(DateTime.now()));
      expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
      expect(tuner.program?.endsEarly, isTrue);
      final item = tuner.segment?.item?.id;
      await wait(cut.difference(DateTime.now()));
      final limit = cut.add(const Duration(seconds: 15));
      while ((tuner.segment == null || tuner.segment!.start.isBefore(cut)) && DateTime.now().isBefore(limit)) {
        await wait(const Duration(milliseconds: 50));
      }
      final lateBy = DateTime.now().difference(cut);
      await wait(const Duration(seconds: 6));
      _say('clean cut ${lateBy.inMilliseconds} ms late: ${tuner.status.name} ${tuner.segment?.title}');
      expect(tuner.segment?.item?.id, isNot(item));
      expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
      expect(lateBy, lessThan(const Duration(seconds: 3)));
      await tester.runAsync(() async {
        await tuner.stop();
        await household.app?.close();
      });
      return;
    }

    /// Moves [ch]'s schedule so [event] comes [lead] from now.
    Future<DateTime> bringClose(Channel c, DateTime event, {Duration lead = const Duration(seconds: 45)}) async {
      final at = DateTime.now().add(lead);
      c.anchor = c.anchor.add(at.difference(event));
      c.slotCarry = null;
      await tester.runAsync(() => app.updateChannel(c));
      return at;
    }

    /// The first segment from now that [test] picks.
    ScheduledProgram find_(Channel c, bool Function(ScheduledProgram s) test) {
      final s = app.scheduleFor(c)!;
      var seg = s.playbackAt(DateTime.now());
      for (var i = 0; i < 5000; i++) {
        if (test(seg)) return seg;
        seg = s.playbackAt(seg.end);
      }
      throw StateError('no such segment');
    }

    /// Waits for the tuner to reach the segment at [t]; how late it was.
    Future<Duration> handedOver(DateTime t) async {
      await wait(t.difference(DateTime.now()).isNegative ? Duration.zero : t.difference(DateTime.now()));
      final limit = t.add(const Duration(seconds: 20));
      while ((tuner.segment == null || tuner.segment!.start.isBefore(t)) && DateTime.now().isBefore(limit)) {
        await wait(const Duration(milliseconds: 100));
      }
      return DateTime.now().difference(t);
    }

    late DateTime next;
    late ScheduledProgram tail, slot;
    late Duration late_;
    // CC_EXPORT_ONLY=1 skips the TV's hand-overs (one waits out a whole tail).
    if (_env['CC_EXPORT_ONLY'] == null) {
    // ---- 30-minute filler slots, into the next program --------------------------
    // CC_SKIP_FILLER=1 skips it: it waits out a whole tail.
    if (_env['CC_SKIP_FILLER'] == null) {
    await tester.runAsync(() => app.setSlotRule(ch, const SlotRule(length: Duration(minutes: 30))));
    for (final p in app.scheduleFor(ch)!.programsBetween(DateTime.now(), DateTime.now().add(const Duration(hours: 6))).skip(1)) {
      expect(p.start.minute % 30, 0, reason: '${p.item?.title} ${p.start}');
      expect(p.start.second, 0);
    }
    // The shortest tail, starting just ahead of now: clips count only for
    // breaks that start after they were found.
    final slots = app.scheduleFor(ch)!.programsBetween(DateTime.now(), DateTime.now().add(const Duration(hours: 24)));
    final plans = app.scheduleFor(ch)! as ChannelSchedule;
    final tails = [for (final p in slots) if (plans.slotPlanFor(p.item!, ruled: true).tail > const Duration(seconds: 20)) p]
      ..sort((a, b) => plans.slotPlanFor(a.item!, ruled: true).tail.compareTo(plans.slotPlanFor(b.item!, ruled: true).tail));
    final shortest = tails.first;
    final tailLength = plans.slotPlanFor(shortest.item!, ruled: true).tail;
    _say('filler: shortest tail ${tailLength.inSeconds} s');
    next = await bringClose(ch, shortest.end, lead: tailLength + const Duration(seconds: 25));
    await wait(next.subtract(tailLength).add(const Duration(seconds: 1)).difference(DateTime.now()));
    await tester.runAsync(() => tuner.tune(ch));
    await wait(const Duration(seconds: 6));
    _say('filler: ${tuner.status.name} ${tuner.segment?.title} role ${tuner.segment?.role}');
    expect(tuner.segment?.isCommercial, isTrue);
    expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    await snap('live-filler');
    late_ = await handedOver(next);
    await wait(const Duration(seconds: 5));
    _say('filler -> program ${late_.inMilliseconds} ms late: ${tuner.status.name} ${tuner.segment?.title}');
    expect(tuner.segment?.isBreak, isFalse);
    expect(tuner.status, TunerStatus.playing);
    expect(late_, lessThan(const Duration(seconds: 3)));

    }

    // ---- 60-minute offline tail, with a movie ----------------------------------
    final movie = library.movies.firstWhere((m) => m.runtime.inMinutes % 60 > 5 && m.runtime.inMinutes % 60 < 58);
    await tester.runAsync(() => app.setChannelSource(ch, ChannelSource(roots: [root], seriesKeys: [other.key], includeMovies: true, includeEpisodes: true)));
    ch.playlist = [movie.id, ...ch.playlist.where((id) => id != movie.id)];
    await tester.runAsync(() => app.setSlotRule(ch, const SlotRule(length: Duration(minutes: 60), tail: TailMode.offline)));
    tail = find_(ch, (s) => s.offline);
    next = await bringClose(ch, tail.end);
    await tester.runAsync(() => tuner.tune(ch));
    await wait(const Duration(seconds: 10));
    _say('offline: ${tuner.status.name} offline=${tuner.segment?.offline}; next in ${next.difference(DateTime.now()).inSeconds} s');
    expect(tuner.status, TunerStatus.offAir);
    expect(tuner.segment?.offline, isTrue);
    expect(find.textContaining('Back at'), findsOneWidget);
    await snap('live-offline');
    late_ = await handedOver(next);
    await wait(const Duration(seconds: 5));
    _say('offline -> program ${late_.inMilliseconds} ms late: ${tuner.status.name} ${tuner.segment?.title}');
    expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    expect(late_, lessThan(const Duration(seconds: 3)));

    // ---- Truncate: the cut --------------------------------------------------------
    await tester.runAsync(() => app.setSlotRule(ch, const SlotRule(length: Duration(minutes: 15), tail: TailMode.truncate)));
    slot = app.scheduleFor(ch)!.programsBetween(DateTime.now(), DateTime.now().add(const Duration(days: 2))).firstWhere((p) => p.endsEarly);
    next = await bringClose(ch, slot.end);
    await tester.runAsync(() => tuner.tune(ch));
    await wait(const Duration(seconds: 12));
    expect(tuner.program?.endsEarly, isTrue);
    expect(find.textContaining('Ends early'), findsWidgets);
    await snap('live-truncate');
    final cutItem = tuner.segment?.item?.id;
    late_ = await handedOver(next);
    await wait(const Duration(seconds: 5));
    _say('cut ${late_.inMilliseconds} ms late: ${tuner.status.name} ${tuner.segment?.title}');
    expect(tuner.segment?.item?.id, isNot(cutItem));
    expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    // This tunes in mid-program: a keyframe join runs behind schedule by up to
    // a keyframe interval, and hands that lag on. CC_CLEAN_CUT measures the cut
    // itself, from a slot watched from its start.
    expect(late_, lessThan(const Duration(seconds: 6)));
    await tester.runAsync(tuner.stop);
    } else {
      final movie = library.movies.firstWhere((m) => m.runtime.inMinutes % 60 > 5 && m.runtime.inMinutes % 60 < 58);
      await tester.runAsync(() => app.setChannelSource(
          ch, ChannelSource(roots: [root], seriesKeys: [other.key], includeMovies: true, includeEpisodes: true)));
      ch.playlist = [movie.id, ...ch.playlist.where((id) => id != movie.id)];
    }

    // ---- 11.6: the same moments in an exported stream ------------------------------
    // Live TV export is desktop-only.
    if (Platform.isAndroid) {
      await tester.runAsync(() async => household.app?.close());
      return;
    }
    await tester.runAsync(() async {
      final profile = household.current!;
      final service = ExportService(household, ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {});
      service.streams.onEvent = (e) => _say('export: $e');
      await service.load();
      await service.setProfileExported(profile.id, true);
      final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = free.port;
      await free.close();
      await service.setPort(profile.id, port);
      await service.setEnabled(true);

      /// Pulls [ch]'s stream across the change at [at] with ffmpeg; returns how
      /// far from [at] the picture changes.
      Future<Duration> pull(String name, DateTime at) async {
        final file = '${dir.path}/$name.ts';
        final started = DateTime.now();
        final ff = await Process.run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
          '-i', 'http://127.0.0.1:$port/stream/${ch.number}.ts', '-t', '${at.difference(started).inSeconds + 20}', '-c', 'copy', file]);
        expect(await File(file).length(), greaterThan(0), reason: '${ff.stderr}');
        // A cut, the end of a still card, or the black a program opens on.
        final scenes = await Process.run('ffmpeg', ['-hide_banner', '-i', file, '-vf',
          "freezedetect=n=0.003:d=2,blackdetect=d=0.1:pix_th=0.1,select='gt(scene,0.25)',showinfo", '-an', '-f', 'null', '-']);
        final times = [
          for (final m in RegExp(r'(?:pts_time:|freeze_end: |black_start:)([0-9.]+)').allMatches('${scenes.stderr}'))
            double.parse(m[1]!),
        ];
        final want = at.difference(started).inMilliseconds / 1000;
        _say('$name: picture changes at $times, wanted $want s after the start');
        expect(times, isNotEmpty);
        final best = times.reduce((a, b) => (a - want).abs() < (b - want).abs() ? a : b);
        return Duration(milliseconds: ((best - want) * 1000).round());
      }

      await app.setSlotRule(ch, const SlotRule(length: Duration(minutes: 60), tail: TailMode.offline));
      tail = find_(ch, (s) => s.offline);
      next = DateTime.now().add(const Duration(seconds: 40));
      ch.anchor = ch.anchor.add(next.difference(tail.end));
      ch.slotCarry = null;
      await app.updateChannel(ch);
      final offlineOff = await pull('offline', next);
      _say('offline card to program in the stream: $offlineOff off the TV');
      expect(offlineOff.abs(), lessThan(const Duration(seconds: 4)));

      await app.setSlotRule(ch, const SlotRule(length: Duration(minutes: 15), tail: TailMode.truncate));
      slot = app.scheduleFor(ch)!.programsBetween(DateTime.now(), DateTime.now().add(const Duration(days: 2))).firstWhere((p) => p.endsEarly);
      next = DateTime.now().add(const Duration(seconds: 40));
      ch.anchor = ch.anchor.add(next.difference(slot.end));
      ch.slotCarry = null;
      await app.updateChannel(ch);
      final cutOff = await pull('truncate', next);
      _say('truncate cut in the stream: $cutOff off the TV');
      expect(cutOff.abs(), lessThan(const Duration(seconds: 4)));
      await service.stop();
      await household.setExportedProfiles({});
    });

    await tester.runAsync(() async {
      await household.app?.close();
      await dir.delete(recursive: true);
    });
  }, timeout: const Timeout(Duration(minutes: 25)));
}
