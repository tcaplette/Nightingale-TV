// Bumper pools against a real Jellyfin server on the app's real player: a
// mid-roll opens and closes with bumpers, the show resumes on time, and an
// exported stream of the same channel plays the same clips at the same times:
//
//   JF_SERVER=https://... JF_USER=... JF_PW=... \
//     flutter test integration_test/bumper_pools_live_test.dart -d linux
//
// Needs a "Commercials" library of short clips. Takes about five minutes.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/logo_windows.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/channels/slot_layout.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';

final _env = Platform.environment;

// ignore: avoid_print
void _say(String s) => print('${DateTime.now().toIso8601String()} $s');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('a framed mid-roll plays on time, on the TV and in an exported stream', (tester) async {
    final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
    if (server == null || user == null || password == null) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW to run against a server.');
      return;
    }
    final player = MediaKitTunerPlayer();
    await tester.pumpWidget(MaterialApp(home: Video(controller: player.video, controls: NoVideoControls)));
    await tester.pump(const Duration(seconds: 1));
    late AppState app;
    late ChannelSchedule schedule;
    late Channel channel;
    late List<ScheduledProgram> planned;
    late DateTime resumes;
    late ExportService service;
    late HttpClient http;
    late StreamSubscription<List<int>> sub;
    final encoded = <String>[];
    var exported = 0;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('nightingale_tv_bumpers');
      final household = Household(await AppStorage.at(dir), runAnalysis: false);
      final fills = <String>[];
      SlotLayout.log = fills.add;
      await household.start();
      app = household.app!;
      final client = app.clientFor(ServerKind.jellyfin, server) as JellyfinClient;
      final info = await client.publicInfo();
      await app.completeSignIn(await client.authenticateByName(user, password, serverName: info.name), client);
      expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
      final ads = (await client.libraries()).firstWhere((l) => l.name == 'Commercials');
      final root = PoolRoot(itemId: ads.id, libraryId: ads.id, label: ads.name);
      final commercials = await app.createPool();
      final bumpers = await app.createPool();
      await app.setPoolRoots(commercials, [root]);
      await app.setPoolRoots(bumpers, [root]);
      for (var i = 0; i < 480 && (app.refreshing || app.catalog.clipsFor(bumpers.id).isEmpty); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await app.setPoolKind(bumpers, PoolKind.bumpers);
      expect(app.catalog.current.bumpers, isNotEmpty);
      expect(app.catalog.clipsFor(null), isNotEmpty);
      final guideChannel = app.channels.first;
      await app.setGlobalPlan(BreakPlan.automatic);
      final me = household.current!;
      household.leave();
      await Future<void>.delayed(const Duration(seconds: 2));
      await household.select(me);
      app = household.app!;

      // The next mid-roll, moved to 45 s from now.
      channel = app.channelById(guideChannel.id)!;
      schedule = app.scheduleFor(channel)! as ChannelSchedule;
      var now = DateTime.now();
      final upcoming = playbackSegmentsBetween(schedule, now, now.add(const Duration(minutes: 40)));
      final mid = upcoming.firstWhere((s) => s.role == BreakRole.mid && s.start.isAfter(now));
      final at = now.add(const Duration(seconds: 45));
      channel.anchor = channel.anchor.add(at.difference(mid.start));
      await app.updateChannel(channel);
      schedule = app.scheduleFor(channel)! as ChannelSchedule;

      final first = schedule.playbackAt(at);
      expect(first.role, BreakRole.mid);
      planned = [];
      for (var s = first; s.isBreak; s = schedule.playbackAt(s.end)) {
        planned.add(s);
      }
      resumes = planned.last.end;
      _say('planned ${[for (final s in planned) '${s.item!.id}/${s.duration.inSeconds}s']}, back at $resumes');
      final framed = fills.where((l) => l.contains(' mid target ') && l.endsWith('bumpers 1+1'));
      expect(framed, isNotEmpty, reason: 'mid-rolls open and close with bumpers');
      expect(fills.where((l) => l.contains(' tail target ') && !l.endsWith('bumpers 0+0')), isEmpty);

      // An exported stream of the same channel, from before the break.
      service = ExportService(household, ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {});
      service.streams.onEvent = (e) {
        final m = RegExp(r'encoder (\S+) for (\S+) from').firstMatch(e);
        if (m != null) {
          encoded.add(m.group(1)!);
          _say('export: ${m.group(1)} for ${m.group(2)}');
        }
      };
      await service.load();
      await service.setProfileExported(me.id, true);
      final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = free.port;
      await free.close();
      await service.setPort(me.id, port);
      await service.setEnabled(true);
      http = HttpClient();
      final response =
          await (await http.getUrl(Uri.parse('http://127.0.0.1:$port/stream/${channel.number}.ts'))).close();
      sub = response.listen((b) => exported += b.length);

    });

    // The TV, on the app's real player: frames keep its video output going.
    final tuner = Tuner(app, player: player);
    await tester.runAsync(() async => unawaited(tuner.tune(channel)));
    final watched = <(String, DateTime)>[];
    String? last;
    final until = resumes.add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(until)) {
      final id = tuner.segment?.item?.id;
      if (id != last && id != null) {
        last = id;
        watched.add((id, DateTime.now()));
        _say('tv: $id${tuner.segment!.isBreak ? ' (${tuner.segment!.role!.name})' : ''}');
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    await tester.runAsync(() async {
      await sub.cancel();
      http.close(force: true);

      expect(tuner.status, TunerStatus.playing);
      final ids = [for (final (id, _) in watched) id];
      final breakIds = [for (final s in planned) s.item!.id];
      final firstBreak = ids.indexOf(breakIds.first);
      expect(firstBreak, isNot(-1), reason: 'the opening bumper plays');
      expect(ids.sublist(firstBreak, firstBreak + breakIds.length), breakIds, reason: 'in the planned order');
      final back = watched[firstBreak + breakIds.length];
      expect(back.$1, schedule.playbackAt(resumes).item!.id);
      final late = back.$2.difference(resumes);
      _say('show back ${late.inMilliseconds} ms from schedule; exported ${exported ~/ 1000} kB');
      expect(late.abs(), lessThan(const Duration(seconds: 2)));
      expect(exported, greaterThan(0));
      for (final s in planned) {
        expect(encoded, contains(s.item!.sourceId), reason: 'the export plays the same clips');
      }
      final position = [for (final s in planned) encoded.indexOf(s.item!.sourceId)];
      expect(position, orderedEquals([...position]..sort()), reason: 'in the same order');
      _say('OK');
      tuner.dispose();
      await service.setEnabled(false);
    });
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 15)));
}
