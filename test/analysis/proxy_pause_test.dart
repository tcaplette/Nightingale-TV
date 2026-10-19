// A real ffmpeg scan through the proxy survives a 10-second pause (a
// transcode's startup budget, while a capped channel tunes) and finishes
// once the budget lifts. Skipped without ffmpeg.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/ffmpeg_runner.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';

void main() {
  test('a 10 s pause during a scan only delays it', () async {
    final runner = FfmpegRunner();
    if (!await runner.available()) {
      markTestSkipped('ffmpeg is not installed.');
      return;
    }
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_pause');
    // 20 s of picture and sound, with a black stretch to find.
    final video = File('${dir.path}/reel.ts');
    final made = await Process.run('ffmpeg', [
      '-v', 'error', '-f', 'lavfi', '-i', 'testsrc=size=320x240:rate=25:duration=20',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=20',
      '-vf', "drawbox=enable='between(t,8,9)':color=black:t=fill", '-c:v', 'mpeg2video', '-b:v', '400k',
      '-c:a', 'mp2', '-shortest', video.path,
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    final bytes = await video.readAsBytes();

    final jellyfin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    jellyfin.listen((r) async {
      r.response.headers.contentLength = bytes.length;
      r.response.add(bytes);
      await r.response.close();
    });
    final proxy = LoopbackStreamProxy(
      upstream: (id) => Uri.parse('http://127.0.0.1:${jellyfin.port}/Videos/$id/stream?static=true'),
      headers: () => const {},
    )..budget = Budget.limited(bytes.length ~/ 10);
    await proxy.start();
    await proxy.allow('reel');

    final watch = Stopwatch()..start();
    final scan = runner.scan(proxy.urlFor('reel'), runtime: const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(seconds: 1));
    await proxy.setBudget(const Budget.paused());
    await Future<void>.delayed(const Duration(seconds: 10));
    await proxy.setBudget(const Budget.unlimited());
    final found = await scan.timeout(const Duration(seconds: 30));
    expect(watch.elapsed, greaterThan(const Duration(seconds: 11)), reason: 'it really waited');
    expect(found.blacks.where((b) => b.start.inSeconds == 8), isNotEmpty, reason: 'and still read the whole file');

    await proxy.close();
    await jellyfin.close(force: true);
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
