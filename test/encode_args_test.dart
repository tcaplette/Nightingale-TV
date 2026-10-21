import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/export/encode_args.dart';
import 'package:nightingale_tv/export/export_settings.dart';

void main() {
  final url = Uri.parse('http://127.0.0.1:1/s/item');
  const png = '/cache/logo-abc.png';
  const nowAndThen = SegmentLogo(png: png, windows: [
    (start: Duration.zero, end: Duration(seconds: 20)),
    (start: Duration(minutes: 3), end: Duration(minutes: 3, seconds: 20)),
  ]);
  const always = SegmentLogo(png: png, windows: [(start: Duration.zero, end: Duration(seconds: 10))], always: true);

  List<String> segment(VideoEncoder e, {SegmentLogo? logo, bool audio = true}) => EncodeArgs.segment(
      input: url, from: const Duration(seconds: 12), frames: 300, quality: ExportQuality.p1080, encoder: e, audio: audio, logo: logo);

  String graphOf(List<String> args) => args[args.indexOf('-filter_complex') + 1];

  for (final e in VideoEncoder.values) {
    group(e.codec, () {
      test('Off (or no window): no logo input, the same command as before', () {
        final plain = segment(e);
        expect(segment(e, logo: const SegmentLogo(png: png)), plain);
        expect(plain.join(' '), isNot(contains(png)));
        expect(plain, contains('-vf'));
        expect(plain, isNot(contains('-filter_complex')));
      });

      test('Now and then: the logo is input 1, faded in and out for each window', () {
        final args = segment(e, logo: nowAndThen);
        final line = args.join(' ');
        expect(line, contains('-loop 1 -framerate 30000/1001 -i $png'));
        expect(args.indexOf(png), greaterThan(args.indexOf('$url')));
        final graph = graphOf(args);
        expect(graph, startsWith('[0:v]scale=1920:1080'));
        expect(graph, contains('[1:v]scale=202:81:force_original_aspect_ratio=decrease,format=rgba,colorchannelmixer=aa=0.7[logo]'));
        expect(graph, contains('[logo]split=2[l0][l1]'));
        expect(graph, contains('[l0]fade=t=in:st=0.000:d=0.500:alpha=1,fade=t=out:st=19.500:d=0.500:alpha=1[f0]'));
        expect(graph, contains('[l1]fade=t=in:st=180.000:d=0.500:alpha=1,fade=t=out:st=199.500:d=0.500:alpha=1[f1]'));
        expect(graph, contains("[base][f0]overlay=x=main_w-overlay_w-96:y=main_h-54-(81+overlay_h)/2:shortest=1:enable='between(t,0.000,20.000)'[o0]"));
        expect(graph, contains("[o0][f1]overlay="));
        // The overlay comes before the upload or pixel format.
        final upload = e == VideoEncoder.vaapi ? 'format=nv12,hwupload[v]' : 'format=yuv420p[v]';
        expect(graph, endsWith(upload));
        expect(line, contains('-map [v] -map 0:a:0?'));
        expect(args, isNot(contains('-vf')));
        expect(line.contains('-vaapi_device'), e == VideoEncoder.vaapi);
      });

      test('Always: one overlay, no fades', () {
        final graph = graphOf(segment(e, logo: always));
        expect(graph, isNot(contains('fade')));
        expect(graph, isNot(contains('enable=')));
        expect(graph, contains('[base][logo]overlay=x=main_w-overlay_w-96:y=main_h-54-(81+overlay_h)/2:shortest=1,'));
      });

      test('silence and a logo: inputs are numbered in order', () {
        final args = segment(e, logo: nowAndThen, audio: false);
        final line = args.join(' ');
        expect(line, contains('-i $url -f lavfi -i anullsrc=r=48000:cl=stereo -loop 1 -framerate 30000/1001 -i $png'));
        expect(graphOf(args), contains('[2:v]scale=202:81'));
        expect(line, contains('-map [v] -map 1:a:0'));
        // Without a logo, silence is still input 1.
        expect(segment(e, audio: false).join(' '), contains('-map 0:v:0 -map 1:a:0'));
      });
    });
  }

  for (final e in VideoEncoder.values) {
    test('a song (${e.codec}): the looped Now Playing card, with the audio from the song', () {
      final args = EncodeArgs.songSegment(
          input: url, card: '/cache/song-1.png', from: const Duration(seconds: 61), frames: 300, quality: ExportQuality.p720, encoder: e);
      final line = args.join(' ');
      expect(line, contains('-loop 1 -framerate 30000/1001 -i /cache/song-1.png -ss 61.000 -i $url'));
      expect(line, contains('-map 0:v:0 -map 1:a:0?'));
      expect(line, contains('scale=1280:720'));
      expect(line, contains('trim=end_frame=300'));
      expect(line, contains('-c:v ${e.codec}'));
      expect(line, contains('-c:a aac -ac 2 -ar 48000'));
      expect(line.contains('hwupload'), e == VideoEncoder.vaapi);
      expect(args.take(3), ['-n', '10', 'ffmpeg']);
      expect(args.last, 'pipe:1');
    });
  }

  test('720p: the box is 54 px tall, 64 px from the right, 36 px from the bottom', () {
    final args = EncodeArgs.segment(
        input: url, from: Duration.zero, frames: 300, quality: ExportQuality.p720, encoder: VideoEncoder.x264, logo: always);
    final graph = graphOf(args);
    expect(graph, contains('scale=135:54:force_original_aspect_ratio=decrease'));
    expect(graph, contains('x=main_w-overlay_w-64:y=main_h-36-(54+overlay_h)/2'));
  });

  group('with ffmpeg', () {
    late Directory dir;
    setUpAll(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_logo_encode'));
    tearDownAll(() => dir.delete(recursive: true));

    Future<void> ffmpeg(List<String> args) async {
      final r = await Process.run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args]);
      if (r.exitCode != 0) throw StateError('ffmpeg ${args.join(' ')}: ${r.stderr}');
    }

    /// Each frame's average colour in a 20×20 patch inside the logo box.
    Future<List<List<int>>> patches(String ts) async {
      final r = await Process.run(
          'ffmpeg',
          ['-hide_banner', '-loglevel', 'error', '-i', ts,
            '-vf', 'crop=20:20:1180:645,scale=1:1:flags=area', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
          stdoutEncoding: null);
      final bytes = r.stdout as Uint8List;
      return [for (var i = 0; i + 2 < bytes.length; i += 3) [bytes[i], bytes[i + 1], bytes[i + 2]]];
    }

    test('a 40 s segment with a window at 15–35 s: the corner changes only inside it', () async {
      final source = '${dir.path}/grey.mp4';
      final logo = '${dir.path}/red.png';
      await ffmpeg(['-f', 'lavfi', '-i', 'color=c=0x808080:s=640x360:r=30', '-f', 'lavfi', '-i', 'sine=f=440:r=48000',
        '-t', '45', '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', source]);
      await ffmpeg(['-f', 'lavfi', '-i', 'color=c=red:s=128x128', '-frames:v', '1', logo]);
      final args = EncodeArgs.segment(
        input: Uri.file(source),
        from: Duration.zero,
        frames: EncodeArgs.framesIn(const Duration(seconds: 40)),
        quality: ExportQuality.p720,
        encoder: VideoEncoder.x264,
        logo: SegmentLogo(png: logo, windows: const [(start: Duration(seconds: 15), end: Duration(seconds: 35))]),
      );
      final out = '${dir.path}/out.ts';
      final p = await Process.start('nice', args);
      final sink = File(out).openWrite();
      await Future.wait([p.stdout.pipe(sink), p.stderr.drain<void>()]);
      expect(await p.exitCode, 0);
      final frames = await patches(out);
      expect(frames, hasLength(EncodeArgs.framesIn(const Duration(seconds: 40))));
      bool grey(List<int> c) => (c[0] - 128).abs() < 12 && (c[1] - 128).abs() < 12;
      bool red(List<int> c) => c[0] > 160 && c[1] < 110;
      for (final (i, c) in frames.indexed) {
        final t = EncodeArgs.framesLength(i);
        final inside = t >= const Duration(seconds: 15) && t < const Duration(seconds: 35);
        final fading = (t - const Duration(seconds: 15)).abs() < const Duration(milliseconds: 600) ||
            (t - const Duration(seconds: 35)).abs() < const Duration(milliseconds: 600);
        if (fading) continue;
        expect(inside ? red(c) : grey(c), isTrue, reason: 'frame $i (${t.inMilliseconds} ms): $c');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
