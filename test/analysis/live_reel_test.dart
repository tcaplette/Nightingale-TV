// Splits a real commercial reel on a Jellyfin server, through the loopback
// proxy and ffmpeg, the way the app does. Skipped unless pointed at a server:
//
//   JF_SESSION=~/.local/share/com.coffeehauslabs.nightingale_tv/profiles/<id>/session.json \
//   JF_REEL=<item id> flutter test test/analysis/live_reel_test.dart
//
// JF_SESSION is a saved sign-in (its token is read from the file, never
// passed on a command line). JF_WINDOW=<seconds> scans only that much.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/ffmpeg_runner.dart';
import 'package:nightingale_tv/commercials/analysis/reel_cutter.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';

void main() {
  final env = Platform.environment;
  final sessionFile = env['JF_SESSION'], reelId = env['JF_REEL'];

  test('a real reel splits into ads', () async {
    if (sessionFile == null || reelId == null) {
      markTestSkipped('Set JF_SESSION and JF_REEL to run against a server.');
      return;
    }
    final session = ServerSession.fromJson(
        jsonDecode(await File(sessionFile.replaceFirst('~', env['HOME']!)).readAsString()) as Map<String, Object?>);
    final client = JellyfinClient.fromSession(session, deviceName: 'nightingale-tv-test');
    final item = (await client.allItems({'Ids': reelId, 'Fields': 'Chapters,Etag'})).single;
    final runtime = Duration(microseconds: (item['RunTimeTicks'] as int) ~/ 10);
    final proxy = LoopbackStreamProxy(upstream: client.streamUri, headers: () => client.authHeaders);
    await proxy.start();
    proxy.allow(reelId);
    final window = int.tryParse(env['JF_WINDOW'] ?? '');
    final runner = FfmpegRunner();
    expect(await runner.available(), isTrue, reason: 'ffmpeg must be installed');
    final watch = Stopwatch()..start();
    final detections = await runner.scan(proxy.urlFor(reelId),
        length: window == null ? null : Duration(seconds: window), runtime: runtime);
    final cuts = ReelCutter.fromDetections(window == null ? runtime : Duration(seconds: window), detections);
    await proxy.close();
    client.close();

    final lengths = [for (final c in cuts.clips) c.length.inMilliseconds / 1000]..sort();
    final median = lengths[lengths.length ~/ 2];
    // ignore: avoid_print
    print('${item['Name']}: ${cuts.clips.length} clips in ${watch.elapsed.inSeconds} s, '
        'median ${median.toStringAsFixed(1)} s, shortest ${lengths.first}, longest ${lengths.last}, '
        '${(cuts.clips.fold(Duration.zero, (t, c) => t + c.length).inSeconds / runtime.inSeconds * 100).round()}% '
        'of the reel used');
    expect(cuts.clips, isNotEmpty);
    expect(median, inInclusiveRange(15, 75), reason: 'ads run about 30 seconds');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
