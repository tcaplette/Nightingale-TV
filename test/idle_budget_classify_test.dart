// The idle-budget measurer classes ffmpeg by its arguments (idle-cpu D3).
// These are the real command lines, so a change to them that the measurer
// would misread fails here.
@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/ffmpeg_runner.dart';
import 'package:nightingale_tv/export/encode_args.dart';
import 'package:nightingale_tv/export/export_settings.dart';

/// What `/proc/<pid>/cmdline` shows once `nice` has run ffmpeg in its place.
String _execd(List<String> niceArgs) => niceArgs.skipWhile((a) => a != 'ffmpeg').join(' ');

void main() {
  final input = Uri.parse('http://127.0.0.1:40000/s/abc');
  const q = ExportQuality.p720;

  final lines = <String, String>{
    'segment': _execd(EncodeArgs.segment(input: input, from: Duration.zero, frames: 300, quality: q, encoder: VideoEncoder.x264)),
    'silent segment':
        _execd(EncodeArgs.segment(input: input, from: Duration.zero, frames: 300, quality: q, encoder: VideoEncoder.vaapi, audio: false)),
    'segment with logo': _execd(EncodeArgs.segment(
        input: input,
        from: Duration.zero,
        frames: 300,
        quality: q,
        encoder: VideoEncoder.x264,
        logo: const SegmentLogo(png: '/tmp/logo.png', always: true))),
    'song': _execd(EncodeArgs.songSegment(
        input: input, card: '/tmp/card.png', from: Duration.zero, frames: 300, quality: q, encoder: VideoEncoder.x264)),
    'muxer': ['ffmpeg', ...EncodeArgs.muxer].join(' '),
    'card chunk': _execd(EncodeArgs.cardChunk(png: '/tmp/c.png', output: '/tmp/c.ts', quality: q, encoder: VideoEncoder.x264)),
    'encoder check': ['ffmpeg', ...EncodeArgs.probe(VideoEncoder.x264, q)].join(' '),
    'analysis': ['ffmpeg', ...FfmpegRunner.arguments(input)].join(' '),
    'analysis part': ['ffmpeg', ...FfmpegRunner.arguments(input, from: const Duration(minutes: 3), length: const Duration(minutes: 2), audio: false)].join(' '),
  };
  const expected = {
    'segment': 'stream',
    'silent segment': 'stream',
    'segment with logo': 'stream',
    'song': 'stream',
    'muxer': 'stream',
    'card chunk': 'card',
    'encoder check': 'card',
    'analysis': 'analysis',
    'analysis part': 'analysis',
  };

  test('each ffmpeg command line is classed as what it is', () async {
    final p = await Process.start('tool/idle_budget/measure.sh', ['--classify']);
    p.stdin.write(lines.values.map((l) => '$l\n').join());
    await p.stdin.close();
    final out = (await p.stdout.transform(const SystemEncoding().decoder).join()).trim().split('\n');
    expect(await p.exitCode, 0);
    expect(Map.fromIterables(lines.keys, out), expected);
  });
}
