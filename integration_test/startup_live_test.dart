// Time to the first moving picture on the real server, by kind of stream,
// with the app's own player (MediaKitTunerPlayer) and Jellyfin client, on
// whatever link this machine has now. Each item is joined JOIN_S seconds in,
// the way a channel change joins a show, as:
//
//   direct      the static file, keyframe join (what the app does now)
//   remux       Jellyfin copies the streams into MPEG-TS from the join point
//   ts@1500     progressive MPEG-TS transcode at 1.5 Mbps (the app's transcode)
//   ts@420      the same at 420 kbps
//   …+probe     the same, with mpv probing at most 0.5 s of the stream
//               (it knows the codecs: Jellyfin sends H.264 and AAC)
//
// Every open goes through the app's playback proxy (warm connections), as
// the tuner's do; direct play is measured uncached, then again after a
// background fill of the file's head and index ("direct cached").
// NIGHTINGALE_TV_NO_PROXY=1 opens the real URLs instead.
//
// One open at a time; each transcode job is stopped once measured. Prints a
// TUNE line per open (see TuneTimeline). Measures only; asserts nothing.
//
//   JF_SERVER=… JF_USER=… JF_PW=… JF_ITEMS=id1,id2 \
//     flutter test integration_test/startup_live_test.dart -d linux
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/playback/playback_proxy.dart';
import 'package:nightingale_tv/playback/tune_timeline.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';

final _env = Platform.environment;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first picture by kind of stream, on the real server', (tester) async {
    final server = _env['JF_SERVER'], user = _env['JF_USER'], password = _env['JF_PW'];
    final items = (_env['JF_ITEMS'] ?? '').split(',').where((s) => s.isNotEmpty).toList();
    if (server == null || user == null || password == null || items.isEmpty) {
      markTestSkipped('Set JF_SERVER, JF_USER, JF_PW and JF_ITEMS to run against a server.');
      return;
    }
    final join = Duration(seconds: int.tryParse(_env['JOIN_S'] ?? '') ?? 600);
    MediaKit.ensureInitialized();
    final deviceId = 'nightingaletv-latency-${Random().nextInt(1 << 30)}';
    final client = (await tester.runAsync(() async {
      final anon = JellyfinClient(serverUrl: server, deviceId: deviceId, deviceName: 'latency test');
      final session = await anon.authenticateByName(user, password, serverName: 'test');
      return JellyfinClient.fromSession(session, deviceName: 'latency test');
    }))!;

    /// A PlaybackInfo with this test's own profile: [protocol] http or hls,
    /// stream copy allowed or not.
    Future<Uri> transcodeUrl(String item, {required int? kbps, required bool copy, String protocol = 'http'}) async {
      final response = await http.post(client.uri('/Items/$item/PlaybackInfo'),
          headers: {...client.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'UserId': client.userId,
            'MediaSourceId': item,
            'MaxStreamingBitrate': ?(kbps == null ? null : kbps * 1000),
            'StartTimeTicks': join.inMicroseconds * 10,
            'AutoOpenLiveStream': false,
            'EnableDirectPlay': false,
            'EnableDirectStream': copy,
            'EnableTranscoding': true,
            'AllowVideoStreamCopy': copy,
            'AllowAudioStreamCopy': copy,
            'DeviceProfile': {
              'Name': 'latency test',
              'MaxStreamingBitrate': ?(kbps == null ? null : kbps * 1000),
              'DirectPlayProfiles': const [],
              'TranscodingProfiles': [
                {
                  'Container': 'ts',
                  'Type': 'Video',
                  'VideoCodec': copy ? 'h264,hevc,mpeg2video,vc1,av1' : 'h264',
                  'AudioCodec': copy ? 'aac,ac3,eac3,mp3' : 'aac',
                  'Protocol': protocol,
                  'Context': 'Streaming',
                  'MaxAudioChannels': '6',
                  'BreakOnNonKeyFrames': copy,
                },
              ],
            },
          }));
      final json = jsonDecode(response.body) as Map<String, Object?>;
      final source = (json['MediaSources'] as List).cast<Map<String, Object?>>().first;
      final url = source['TranscodingUrl'] as String?;
      if (url == null) throw StateError('no TranscodingUrl for $item: ${response.body.substring(0, 300)}');
      return client.transcodeTemplate(url);
    }

    final cacheDir = Directory.systemTemp.createTempSync('nightingale_tv_live_index');
    final proxy = PlaybackProxy.disabled ? null : PlaybackProxy(cacheDir: cacheDir);
    await tester.runAsync(() async {
      await proxy?.start();
      await proxy?.warm(client.uri('/System/Ping'), client.authHeaders);
    });

    final player = MediaKitTunerPlayer(verboseLog: true);
    await tester.pumpWidget(MaterialApp(home: Video(controller: player.video, controls: NoVideoControls)));

    final native = player.player.platform as NativePlayer;
    Future<void> measure(String item, String kind, Future<(Uri, Duration?, String?)> Function() prepare,
        {bool shortProbe = false}) async {
      await tester.runAsync(() async {
        await native.setProperty('demuxer-lavf-analyzeduration', shortProbe ? '0.5' : '0');
        await native.setProperty('demuxer-lavf-probesize', shortProbe ? '65536' : '0');
      });
      final clock = Stopwatch()..start();
      final t = TuneTimeline('test', item.substring(0, 8), Duration.zero)..kind = kind;
      final subs = <StreamSubscription<Object?>>[];
      String? session;
      try {
        final (real, start, playSession) = (await tester.runAsync(prepare))!;
        session = playSession;
        t.waited('playback-info', clock.elapsed);
        var url = real;
        var headers = client.authHeaders;
        t.proxy = proxy != null;
        if (proxy != null) {
          subs.add(proxy.events.listen((e) {
            if (e.kind == 'upstream') t.upstreamRequest(e.data['warm'] == true);
            if (e.kind == 'cache') t.cache('${e.data['what']}');
          }));
          url = (await tester.runAsync(() => proxy.open(real, client.authHeaders,
              cache: kind.startsWith('direct') ? (source: item, etag: null, size: null) : null, joins: true)))!;
          headers = const {};
        }
        final landing = start ?? Duration.zero;
        Duration? last;
        subs
          ..add(player.logStream.listen((l) => t.mpvLine(l, clock.elapsed)))
          ..add(player.positionStream.listen((p) {
            if (t.done || (p - landing).abs() > const Duration(seconds: 30)) return;
            final before = last;
            last = p;
            if (before != null && p > before && p - before < const Duration(seconds: 1)) t.finish('picture', clock.elapsed);
          }));
        t.openCalled = clock.elapsed;
        await tester.runAsync(() => player.open(url, headers: headers, start: start, exact: false));
        while (!t.done && clock.elapsed < const Duration(seconds: 60)) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
        }
        t.finish('timeout', clock.elapsed);
      } on Object catch (e) {
        t.finish('failed: $e', clock.elapsed);
      } finally {
        for (final s in subs) {
          await s.cancel();
        }
        await tester.runAsync(() async {
          await player.stop();
          if (session != null) await client.stopTranscode(session).catchError((_) {});
          // Let the server end the job before the next one starts.
          await Future<void>.delayed(const Duration(seconds: 2));
        });
      }
      // ignore: avoid_print
      print('TUNE\t${t.summary()}');
    }

    String newSession() => List.generate(32, (_) => Random().nextInt(16).toRadixString(16)).join();
    Future<(Uri, Duration?, String?)> transcode(String item, {int? kbps, bool copy = false, String protocol = 'http'}) async {
      final template = await transcodeUrl(item, kbps: kbps, copy: copy, protocol: protocol);
      final session = newSession();
      return (await client.transcodeUri(template, playSessionId: session, startAt: join), null, session);
    }

    for (final item in items) {
      if (_env['ONLY_PROBE'] == '1') {
        await measure(item, 'ts@1500', () => transcode(item, kbps: 1500));
        await measure(item, 'ts@1500+probe', () => transcode(item, kbps: 1500), shortProbe: true);
        await measure(item, 'ts@420+probe', () => transcode(item, kbps: 420), shortProbe: true);
      }
      if (_env['ONLY_PROBE'] == '1') continue;
      await measure(item, 'direct', () async => (client.streamUri(item), join, null));
      if (proxy != null) {
        // The uncached open taught the cache what mpv read; the fill finishes
        // whatever it didn't ("cached" when there's nothing left).
        await tester.runAsync(() async {
          final summary = await proxy.fill((source: item, etag: null, size: null), client.streamUri(item),
              client.authHeaders);
          // ignore: avoid_print
          print('CACHE\t$summary');
        });
        await measure(item, 'direct cached', () async => (client.streamUri(item), join, null));
      }
      await measure(item, 'remux', () => transcode(item, copy: true));
      await measure(item, 'ts@1500', () => transcode(item, kbps: 1500));
      await measure(item, 'ts@420', () => transcode(item, kbps: 420));
      await measure(item, 'ts@1500+probe', () => transcode(item, kbps: 1500), shortProbe: true);
      await measure(item, 'ts@420+probe', () => transcode(item, kbps: 420), shortProbe: true);
    }
    await tester.runAsync(() async {
      await player.dispose();
      await proxy?.close();
      await client.logout().catchError((_) {});
      cacheDir.deleteSync(recursive: true);
    });
  }, timeout: const Timeout(Duration(minutes: 15)));
}
