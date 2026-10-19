import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/export/broadcast_art.dart';
import 'package:nightingale_tv/export/card_chunks.dart';
import 'package:nightingale_tv/export/channel_stream.dart';
import 'package:nightingale_tv/export/encode_args.dart';
import 'package:nightingale_tv/export/export_settings.dart';

import 'fixtures.dart';

/// The real pipeline: cards drawn and encoded, encoders on a local file,
/// the splicer, and ffmpeg's real-time muxer, for about 45 seconds.
void main() {
  testWidgets('a real stream is continuous from the first byte', (tester) async {
    await tester.runAsync(() async {
      final ok = await () async {
        try {
          return (await Process.run('ffmpeg', ['-version'])).exitCode == 0;
        } on ProcessException {
          return false;
        }
      }();
      if (!ok) {
        markTestSkipped('ffmpeg is not installed');
        return;
      }
      final dir = await Directory.systemTemp.createTemp('nightingale_tv_e2e');
      late AppState app;
      try {
        app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 10, 'Beta': 10}, episodeLength: const Duration(seconds: 32)));
        final src = '${dir.path}/episode.mp4';
        final make = await Process.run('ffmpeg', [
          '-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', 'testsrc2=s=320x240:r=24', '-f', 'lavfi',
          '-i', 'sine=f=440:r=44100', '-t', '35', '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', src,
        ]);
        expect(make.exitCode, 0, reason: '${make.stderr}');
        final channel = app.channels.first;
        final chunks = CardChunks(BroadcastArt(Directory('${dir.path}/cache')));
        final opened = <String>[];
        final stream = ChannelStream(StreamContext(
          channel: channel,
          schedule: () => app.scheduleFor(channel),
          card: (c) => chunks.chunkFor(c, app, ExportQuality.p720, VideoEncoder.x264),
          openSource: (id) async {
            opened.add(id);
            return Uri.file(src);
          },
          closeSource: (_) {},
          quality: ExportQuality.p720,
          encoder: VideoEncoder.x264,
        ));
        final requested = DateTime.now();
        await stream.start();
        final out = File('${dir.path}/out.ts').openWrite();
        DateTime? firstByte;
        final sub = stream.output.listen((b) {
          firstByte ??= DateTime.now();
          out.add(b);
        });
        await Future<void>.delayed(const Duration(seconds: 45));
        await stream.stop();
        await sub.cancel();
        await out.close();

        expect(firstByte, isNotNull);
        expect(firstByte!.difference(requested), lessThan(const Duration(seconds: 3)));
        expect(opened.length, greaterThanOrEqualTo(2), reason: 'crossed a program boundary');

        final probe = await Process.run('ffprobe', [
          '-v', 'error', '-show_entries', 'packet=stream_index,pts_time,flags', '-of', 'json', '${dir.path}/out.ts',
        ]);
        final packets = ((jsonDecode('${probe.stdout}') as Map)['packets'] as List).cast<Map<String, Object?>>();
        List<double> times(int stream) => [
              for (final p in packets)
                if (p['stream_index'] == stream && p['pts_time'] != null) double.parse(p['pts_time']! as String),
            ]..sort();
        final video = times(0), audio = times(1);
        expect(video.length, greaterThan(38 * 30), reason: 'about 40 s of video');
        for (var i = 1; i < video.length; i++) {
          expect(video[i] - video[i - 1], lessThan(0.05), reason: 'video gap at ${video[i]}');
        }
        for (var i = 1; i < audio.length; i++) {
          expect(audio[i] - audio[i - 1], lessThan(0.08), reason: 'audio gap at ${audio[i]}');
        }
        expect(packets.where((p) => '${p['flags']}'.contains('C')), isEmpty);
        // In stream order, no AAC frame starts before the one before it ends.
        final inOrder = [
          for (final p in packets)
            if (p['stream_index'] == 1 && p['pts_time'] != null) double.parse(p['pts_time']! as String),
        ];
        final overlaps = [
          for (var i = 1; i < inOrder.length; i++)
            if (inOrder[i] - inOrder[i - 1] < 1024 / 48000 - 0.0005) inOrder[i],
        ];
        expect(overlaps, isEmpty, reason: 'audio overlaps at $overlaps');
        // Both tracks start together (each is checked for gaps above; the
        // ends are cut wherever the muxer was interleaving at stop).
        expect((video.first - audio.first).abs(), lessThan(0.1), reason: 'A/V start together');
      } finally {
        await app.close();
        await dir.delete(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
