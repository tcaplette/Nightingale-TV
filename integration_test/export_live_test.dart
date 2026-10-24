// Live TV export against a real Jellyfin server: the whole stack (export
// service, lineup server, encoder probe, proxy, encoders, splicer, muxer)
// streaming a real channel over HTTP for two minutes:
//
//   JF_SERVER=https://... JF_USER=... JF_PW=... \
//     flutter test integration_test/export_live_test.dart
//
// or from a Plex or Emby profile, on the local test servers (tool/test_servers):
//
//   MEDIA_SERVER=plex [PLEX_TOKEN=... once the server is claimed] flutter test integration_test/export_live_test.dart -d linux
//   MEDIA_SERVER=emby EMBY_USER=... EMBY_PASSWORD=... flutter test ...
//
// Prints how long the stream took to start and how sources opened, and
// checks the captured stream with ffprobe.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/profiles/household.dart';

final _env = Platform.environment;

void main() {
  testWidgets('a real channel streams continuously over HTTP', (tester) async {
    final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
    final plex = _env['MEDIA_SERVER'] == 'plex';
    final emby = _env['MEDIA_SERVER'] == 'emby';
    if (!plex && !emby && (server == null || user == null || password == null)) {
      markTestSkipped('Set JF_SERVER, JF_USER and JF_PW to run against a server.');
      return;
    }
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('nightingale_tv_export_live');
      final household = Household(await AppStorage.at(dir), runAnalysis: false);
      late AppState app;
      late ExportService service;
      try {
        await household.start();
        app = household.app!;
        if (plex) {
          // The local test server, as it answers this machine without a token.
          const url = 'http://127.0.0.1:32400';
          final probe = app.clientFor(ServerKind.plex, url);
          final info = await probe.publicInfo();
          probe.close();
          final session = ServerSession(
            kind: ServerKind.plex,
            serverUrl: url,
            serverName: info.name,
            serverId: info.id,
            userId: 'local',
            userName: 'local',
            // A claimed server wants the account's token (PLEX_TOKEN).
            accessToken: _env['PLEX_TOKEN'] ?? '',
            deviceId: app.settings.installId,
          );
          await app.completeSignIn(session, app.clientForSession(session));
        } else if (emby) {
          // The local Emby test server (EMBY_USER, EMBY_PASSWORD).
          final client = app.clientFor(ServerKind.emby, 'http://127.0.0.1:8096') as JellyfinClient;
          final info = await client.publicInfo();
          await app.completeSignIn(
              await client.authenticateByName(_env['EMBY_USER']!, _env['EMBY_PASSWORD']!, serverName: info.name), client);
        } else {
          final client = app.clientFor(ServerKind.jellyfin, server!) as JellyfinClient;
          final info = await client.publicInfo();
          await app.completeSignIn(await client.authenticateByName(user!, password!, serverName: info.name), client);
        }
        expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
        final profile = household.current!;

        // Nothing on the real network but the HTTP port.
        service = ExportService(household, ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {});
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
        final m3u = await get('/lineup.m3u');
        final guide = await get('/xmltv.xml');
        final channel = app.channels.first;
        expect(m3u, contains('/stream/${channel.number}.ts'));
        expect(guide, contains('<programme '));
        // ignore: avoid_print
        print('Export live: ${app.channels.length} channels, guide ${guide.length ~/ 1024} KB, '
            'streaming channel ${channel.number} (${channel.name}).');

        final requested = DateTime.now();
        final response = await (await http.getUrl(Uri.parse('http://127.0.0.1:$port/stream/${channel.number}.ts'))).close();
        expect(response.statusCode, 200);
        expect(response.headers.contentType?.mimeType, 'video/mp2t');
        final out = File('${dir.path}/live.ts').openWrite();
        DateTime? first;
        var bytes = 0;
        final sub = response.listen((b) {
          first ??= DateTime.now();
          bytes += b.length;
          out.add(b);
        });

        // A second viewer joins later and starts with the tables and a keyframe.
        await Future<void>.delayed(const Duration(seconds: 60));
        final second = await (await http.getUrl(Uri.parse('http://127.0.0.1:$port/stream/${channel.number}.ts'))).close();
        final head = await second.take(1).first;
        expect(head[0], 0x47);
        expect(((head[1] & 0x1F) << 8) | head[2], 0, reason: 'starts with the PAT');
        expect(service.streams.running.single.viewers, greaterThanOrEqualTo(1));

        await Future<void>.delayed(const Duration(seconds: 60));
        await sub.cancel();
        await out.close();
        // ignore: avoid_print
        print('Export live: first byte after ${first!.difference(requested).inMilliseconds} ms, '
            '${bytes ~/ 1024} KB in two minutes, encoder ${service.encoderInUse?.codec}.');
        expect(first!.difference(requested), lessThan(const Duration(seconds: 2)));

        final probe = await Process.run('ffprobe', [
          '-v', 'error', '-show_entries', 'packet=stream_index,pts_time,flags', '-of', 'json', '${dir.path}/live.ts',
        ]);
        final packets = ((jsonDecode('${probe.stdout}') as Map)['packets'] as List).cast<Map<String, Object?>>();
        List<double> times(int s) => [
              for (final p in packets)
                if (p['stream_index'] == s && p['pts_time'] != null) double.parse(p['pts_time']! as String),
            ]..sort();
        final video = times(0), audio = times(1);
        final gaps = [
          for (var i = 1; i < video.length; i++)
            if (video[i] - video[i - 1] > 0.05) (at: video[i - 1], gap: video[i] - video[i - 1]),
        ];
        // ignore: avoid_print
        print('Export live: ${video.length} video frames (${(video.last - video.first).toStringAsFixed(1)} s), '
            '${audio.length} audio packets, video gaps: $gaps');
        expect(video.length, greaterThan(110 * 29));
        expect(gaps, isEmpty);
        expect(packets.where((p) => '${p['flags']}'.contains('C')), isEmpty);
      } finally {
        await service.stop();
        await app.signOut();
        household.leave();
        await household.setExportedProfiles({});
        await dir.delete(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
