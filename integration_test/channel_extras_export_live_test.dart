// Channel extras in Live TV export against a real Jellyfin server: the
// channel logo burned into a real stream (after a break, gone in the break),
// encode speed with the logo on and off, M3U group-title and XMLTV <new/>:
//
//   JF_SERVER=https://... JF_USER=... JF_PW=... \
//     flutter test integration_test/channel_extras_export_live_test.dart
//
// Needs a "Commercials" library of short clips. Takes about five minutes.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/logo_windows.dart';
import 'package:nightingale_tv/channels/premieres.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/encode_args.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/profiles/household.dart';

final _env = Platform.environment;

// ignore: avoid_print
void _say(String s) => print('${DateTime.now().toIso8601String()} $s');

void main() {
  testWidgets('the logo, groups and premieres in exported streams and guides', (tester) async {
    final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
    if (server == null || user == null || password == null) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW to run against a server.');
      return;
    }
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('nightingale_tv_extras_export');
      final household = Household(await AppStorage.at(dir), runAnalysis: false);
      late AppState app;
      late ExportService service;
      try {
        await household.start();
        app = household.app!;
        final client = app.clientFor(ServerKind.jellyfin, server) as JellyfinClient;
        final info = await client.publicInfo();
        await app.completeSignIn(await client.authenticateByName(user, password, serverName: info.name), client);
        expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
        final ads = (await client.libraries()).firstWhere((l) => l.name == 'Commercials');
        final pool = await app.createPool();
        await app.setPoolRoots(pool, [PoolRoot(itemId: ads.id, libraryId: ads.id, label: ads.name)]);
        for (var i = 0; i < 240 && (app.refreshing || app.library.commercials.isEmpty); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        await app.setGlobalPlan(BreakPlan.automatic);
        // Open the profile again, as a launch does, so every slot has breaks.
        final me = household.current!;
        household.leave();
        await Future<void>.delayed(const Duration(seconds: 2));
        await household.select(me);
        app = household.app!;
        expect(app.channels.where((c) => !c.isMusic).every(app.breaksFor), isTrue);
        final premiereAt = DateTime.now().add(const Duration(minutes: 3));
        await app.setPremiereSettings(PremiereSettings(startMinute: premiereAt.hour * 60 + premiereAt.minute));

        final profile = household.current!;
        service = ExportService(household, ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {});
        final events = <String>[];
        service.streams.onEvent = (e) {
          events.add(e);
          if (e.contains('logo') || e.contains('started')) _say('export: $e');
        };
        await service.load();
        await service.setProfileExported(profile.id, true);
        final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = free.port;
        await free.close();
        await service.setPort(profile.id, port);
        await service.setEnabled(true);
        final http = HttpClient();
        Future<String> get(String path) async =>
            utf8.decodeStream(await (await http.getUrl(Uri.parse('http://127.0.0.1:$port$path'))).close());

        // ---- M3U group-title ----------------------------------------------------
        final grouped = app.channels.first;
        final group = await app.createGroup('Saturday');
        await app.setInGroup(group, grouped, true);
        final m3u = await get('/lineup.m3u');
        String entry(Channel c) => m3u.split('\n').firstWhere((l) => l.contains('tvg-chno="${c.number}"'));
        expect(entry(grouped), contains('group-title="Saturday"'));
        final movies = app.channels.where((c) => c.source.includeMovies && !c.source.includeEpisodes);
        for (final c in movies) {
          expect(entry(c), contains('group-title="Movies"'));
        }
        _say('M3U: ${{for (final c in app.channels) RegExp(r'group-title="([^"]*)"').firstMatch(entry(c))!.group(1)}}');

        // ---- XMLTV <new/> ---------------------------------------------------------
        final guide = await get('/xmltv.xml');
        expect(guide, contains('<new/>'));
        expect(guide, contains('<category>${PremierePlan.title}</category>'));
        final newOnes = RegExp('<new/>').allMatches(guide).length;
        _say('XMLTV: $newOnes premieres marked <new/>; music programmes: '
            '${app.library.songs.isEmpty ? 'no music on the server' : guide.contains('<category>Music</category>')}');

        // ---- The logo in a stream --------------------------------------------------
        // A channel whose program comes back from a break 45 s from now (its
        // schedule moved there, rather than waiting for a break).
        final channel = app.channels.first;
        var schedule = app.scheduleFor(channel)!;
        final upcoming = playbackSegmentsBetween(schedule, DateTime.now(), DateTime.now().add(const Duration(minutes: 40)));
        final returns = [for (var i = 1; i < upcoming.length; i++) if (upcoming[i - 1].isBreak && !upcoming[i].isBreak) upcoming[i]].first;
        final backAt = DateTime.now().add(const Duration(seconds: 45));
        channel.anchor = channel.anchor.add(backAt.difference(returns.start));
        // A solid magenta badge, easy to find in the corner.
        await app.updateChannel(channel, icon: const ChannelIcon(kind: ChannelIconKind.badge, value: 'I', color: 0xFFFF00FF));
        schedule = app.scheduleFor(channel)!;
        final brk = schedule.playbackAt(backAt.subtract(const Duration(seconds: 1)));
        expect(brk.isBreak, isTrue);
        final target = (channel: channel, brk: brk, part: schedule.playbackAt(backAt));
        _say('stream ${target.channel.number} ${target.channel.name}: break until ${target.part.start}');
        final startAt = target.part.start.subtract(const Duration(seconds: 30));
        if (DateTime.now().isBefore(startAt)) await Future<void>.delayed(startAt.difference(DateTime.now()));

        Future<File> capture(Channel c, DateTime until, String name) async {
          final response = await (await http.getUrl(Uri.parse('http://127.0.0.1:$port/stream/${c.number}.ts'))).close();
          final file = File('${dir.path}/$name.ts');
          final out = file.openWrite();
          final sub = response.listen(out.add);
          await Future<void>.delayed(until.difference(DateTime.now()));
          await sub.cancel();
          await out.close();
          return file;
        }

        final ts = await capture(target.channel, target.part.start.add(const Duration(seconds: 80)), 'logo');
        final keep = _env['SNAP_DIR'];
        if (keep != null) await ts.copy('$keep/extras-export-logo.ts');
        // Each frame's average colour in a patch inside the badge (1080p).
        final r = await Process.run(
            'ffmpeg',
            ['-hide_banner', '-loglevel', 'error', '-i', ts.path, '-vf', 'crop=12:12:1753:980,scale=1:1:flags=area',
              '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
            stdoutEncoding: null);
        final bytes = r.stdout as Uint8List;
        final magenta = [for (var i = 0; i + 2 < bytes.length; i += 3) bytes[i] > 170 && bytes[i + 2] > 170 && bytes[i + 1] < 120];
        final runs = <(int, int)>[];
        for (var i = 0; i < magenta.length; i++) {
          if (!magenta[i]) continue;
          if (runs.isNotEmpty && runs.last.$2 == i - 1) {
            runs.last = (runs.last.$1, i);
          } else {
            runs.add((i, i));
          }
        }
        double secs(int frames) => EncodeArgs.framesLength(frames).inMilliseconds / 1000;
        _say('logo runs (frame, seconds): ${[for (final (a, b) in runs) '$a: ${secs(b - a + 1)} s'].join(', ')} '
            'of ${magenta.length} frames');
        final long = runs.where((r) => secs(r.$2 - r.$1 + 1) > 15).toList();
        expect(long, hasLength(1), reason: 'one window of about 20 s after the break');
        // 20 s from the program's start: less when the stream joins it a moment
        // behind the schedule (the window is the schedule's), and the fades.
        expect(secs(long.single.$2 - long.single.$1 + 1), inInclusiveRange(17.0, 20.5));
        // No logo in the break before it (as much of the break as was captured).
        final breakFrames = EncodeArgs.framesIn(target.part.start.difference(target.brk.start)) - 30;
        final before = magenta.sublist((long.single.$1 - breakFrames).clamp(0, magenta.length), long.single.$1);
        expect(before.where((m) => m).length, lessThan(5), reason: 'no logo in the break');
        // Frames for the record: in the break, and in the window.
        if (keep != null) {
          for (final (name, frame) in [('in-break', long.single.$1 - 90), ('logo', long.single.$1 + 150)]) {
            await Process.run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', ts.path,
              '-vf', 'select=eq(n\\,$frame)', '-frames:v', '1', '$keep/extras-export-$name.png']);
          }
        }

        // ---- Encode speed with the logo on and off ----------------------------------
        // The same 20 s of a real program, encoded unpaced (streams run in
        // real time), with and without the logo.
        final program = app.library.episodes.firstWhere((e) => e.runtime > const Duration(minutes: 10));
        final sample = File('${dir.path}/sample.mkv');
        final head = await http.getUrl(app.client!.streamUri(program.sourceId));
        app.client!.authHeaders.forEach(head.headers.set);
        head.headers.set('Range', 'bytes=0-${(program.size ?? 400 << 20) ~/ 6}');
        await (await head.close()).pipe(sample.openWrite());
        final logoPng = (await service.art.logoFile(app, target.channel))!.path;
        final encoder = service.encoderInUse ?? VideoEncoder.x264;
        Future<double> fps(SegmentLogo? logo) async {
          final args = EncodeArgs.segment(
              input: Uri.file(sample.path), from: const Duration(seconds: 5), frames: 600,
              quality: ExportQuality.p1080, encoder: encoder, logo: logo);
          final watch = Stopwatch()..start();
          final p = await Process.start('nice', args);
          await Future.wait([p.stdout.drain<void>(), p.stderr.drain<void>()]);
          expect(await p.exitCode, 0);
          return 600 / (watch.elapsedMilliseconds / 1000);
        }

        final off = await fps(null);
        final always = await fps(SegmentLogo(png: logoPng, windows: const [(start: Duration.zero, end: Duration(seconds: 20))], always: true));
        final fades = await fps(SegmentLogo(png: logoPng, windows: const [
          (start: Duration.zero, end: Duration(seconds: 20)),
        ]));
        _say('encode speed (${encoder.codec}, 1080p, ${program.seriesName}): logo off ${off.toStringAsFixed(1)} fps, '
            'always ${always.toStringAsFixed(1)} fps, now and then ${fades.toStringAsFixed(1)} fps '
            '(real time is 29.97)');
        expect(always, greaterThan(29.97), reason: 'the logo keeps encoding faster than real time');
        expect(fades, greaterThan(29.97));
      } finally {
        await service.stop();
        await app.signOut();
        household.leave();
        await household.setExportedProfiles({});
        await dir.delete(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 15)));
}
