import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/export/encode_args.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/ts_splicer.dart';

const _video = 0x100, _audio = 0x101, _pat = 0;

/// One 188-byte packet: a PES start with [pts] (and [dts]) when given, a
/// PCR when given, else plain payload.
Uint8List packet(int pid, {int? pts, int? dts, int? pcr, int cc = 0, bool video = true}) {
  final b = Uint8List(188)..fillRange(0, 188, 0xFF);
  b[0] = 0x47;
  final start = pts != null;
  b[1] = (start ? 0x40 : 0) | (pid >> 8);
  b[2] = pid & 0xFF;
  var p = 4;
  if (pcr != null) {
    b[3] = 0x30 | cc; // adaptation + payload
    b[4] = 7;
    b[5] = 0x10;
    b[6] = (pcr >> 25) & 0xFF;
    b[7] = (pcr >> 17) & 0xFF;
    b[8] = (pcr >> 9) & 0xFF;
    b[9] = (pcr >> 1) & 0xFF;
    b[10] = ((pcr & 1) << 7) | 0x7E;
    b[11] = 0;
    p = 12;
  } else {
    b[3] = 0x10 | cc;
  }
  if (start) {
    b.setAll(p, [0, 0, 1, video ? 0xE0 : 0xC0, 0, 0, 0x80, dts != null ? 0xC0 : 0x80, dts != null ? 10 : 5]);
    _ts(b, p + 9, pts, dts != null ? 3 : 2);
    if (dts != null) _ts(b, p + 14, dts, 1);
  }
  return b;
}

void _ts(Uint8List b, int o, int v, int prefix) {
  v %= 1 << 33;
  b[o] = (prefix << 4) | (((v >> 30) & 7) << 1) | 1;
  b[o + 1] = (v >> 22) & 0xFF;
  b[o + 2] = (((v >> 15) & 0x7F) << 1) | 1;
  b[o + 3] = (v >> 7) & 0xFF;
  b[o + 4] = ((v & 0x7F) << 1) | 1;
}

int _readTs(Uint8List b, int o) =>
    ((b[o] >> 1) & 7) << 30 | b[o + 1] << 22 | (b[o + 2] >> 1) << 15 | b[o + 3] << 7 | b[o + 4] >> 1;

/// (pid, pts, cc) of each PES start in [out]; pcr of each PCR packet.
List<({int pid, int? pts, int? pcr, int cc})> parse(Uint8List out) => [
      for (var o = 0; o < out.length; o += 188)
        (
          pid: ((out[o + 1] & 0x1F) << 8) | out[o + 2],
          cc: out[o + 3] & 0xF,
          pcr: out[o + 3] & 0x20 != 0 && out[o + 5] & 0x10 != 0
              ? (out[o + 6] << 25 | out[o + 7] << 17 | out[o + 8] << 9 | out[o + 9] << 1 | out[o + 10] >> 7)
              : null,
          pts: out[o + 1] & 0x40 != 0 ? _readTs(out, (out[o + 3] & 0x20 != 0 ? 12 : 4) + o + 9) : null,
        ),
    ];

Uint8List cat(List<Uint8List> parts) => (BytesBuilder()..addAll(parts)).toBytes();

extension on BytesBuilder {
  void addAll(List<Uint8List> parts) {
    for (final p in parts) {
      add(p);
    }
  }
}

/// A segment of [frames] video frames from [firstPts], an audio frame
/// before the first video, tables and a PCR up front.
Uint8List segment({int firstPts = 126000, int frames = 3}) => cat([
      packet(_pat, cc: 5),
      packet(_video, pcr: firstPts - 3003, cc: 9),
      packet(_audio, pts: firstPts - 1920, video: false, cc: 2),
      for (var i = 0; i < frames; i++) packet(_video, pts: firstPts + i * 3003, dts: firstPts + i * 3003, cc: i),
    ]);

void main() {
  test('the first segment starts at 0 and moves the clock past its last frame', () {
    final s = TsSplicer()..begin();
    final out = cat([s.add(segment()), s.end()]);
    final pes = parse(out).where((p) => p.pts != null).toList();
    expect(pes.firstWhere((p) => p.pid == _video).pts, 0);
    expect(pes.firstWhere((p) => p.pid == _audio).pts, (-1920) % (1 << 33));
    expect(s.clock, 3 * 3003);
    expect(s.sawAudio, isTrue);
  });

  test('the next segment continues the clock, PCR and continuity counters', () {
    final s = TsSplicer();
    final first = s.segment(segment());
    final second = s.segment(segment(firstPts: 999999));
    final a = parse(first), b = parse(second);
    expect(b.firstWhere((p) => p.pid == _video && p.pts != null).pts, 3 * 3003);
    expect(b.firstWhere((p) => p.pcr != null).pcr, 3 * 3003 - 3003);
    expect(s.clock, 6 * 3003);
    for (final pid in [_pat, _video, _audio]) {
      final ccs = [for (final p in [...a, ...b]) if (p.pid == pid) p.cc];
      for (var i = 1; i < ccs.length; i++) {
        expect(ccs[i], (ccs[i - 1] + 1) & 0xF, reason: 'pid $pid');
      }
    }
  });

  test('timestamps near the 33-bit wrap come out continuous', () {
    final s = TsSplicer()..clock = (1 << 33) - 3003;
    final out = s.segment(segment(firstPts: (1 << 33) - 3003));
    final video = [for (final p in parse(out)) if (p.pid == _video && p.pts != null) p.pts!];
    expect(video, [(1 << 33) - 3003, 0, 3003]);
    expect(s.clock, (1 << 33) - 3003 + 3 * 3003);
  });

  test('bytes cut anywhere give the same output', () {
    final whole = TsSplicer().segment(segment(frames: 20));
    final s = TsSplicer()..begin();
    final data = segment(frames: 20);
    final out = BytesBuilder();
    for (var i = 0; i < data.length; i += 77) {
      out.add(s.add(Uint8List.sublistView(data, i, (i + 77).clamp(0, data.length))));
    }
    out.add(s.end());
    expect(out.toBytes(), whole);
  });

  test('a segment with no video still goes out, shifted to the clock', () {
    final s = TsSplicer()..clock = 90000;
    final out = s.segment(cat([packet(_audio, pts: 500, video: false)]));
    expect(parse(out).single.pts, 90500);
    expect(s.clock, 90000);
    expect(s.sawAudio, isTrue);
  });

  test('a segment with no audio is noticed', () {
    final s = TsSplicer()..segment(cat([for (var i = 0; i < 3; i++) packet(_video, pts: i * 3003)]));
    expect(s.sawAudio, isFalse);
  });

  group('with ffmpeg', () {
    late Directory dir;
    var ffmpeg = false;

    setUpAll(() async {
      try {
        ffmpeg = (await Process.run('ffmpeg', ['-version'])).exitCode == 0;
      } on ProcessException {
        ffmpeg = false;
      }
    });

    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_splice'));
    tearDown(() => dir.delete(recursive: true));

    Future<Uint8List> run(List<String> niceArgs) async {
      final r = await Process.run('nice', niceArgs, stdoutEncoding: null);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      return Uint8List.fromList(r.stdout as List<int>);
    }

    test('spliced encoder output is one continuous stream', () async {
      if (!ffmpeg) return markTestSkipped('ffmpeg is not installed');
      final src = '${dir.path}/src.mp4';
      final make = await Process.run('ffmpeg', [
        '-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', 'testsrc2=s=640x480:r=24', '-f', 'lavfi',
        '-i', 'sine=f=440:r=44100', '-t', '12', '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', src,
      ]);
      expect(make.exitCode, 0, reason: '${make.stderr}');
      Future<Uint8List> part(Duration from, int frames, {bool audio = true}) => run(EncodeArgs.segment(
          input: Uri.file(src), from: from, frames: frames, quality: ExportQuality.p720, encoder: VideoEncoder.x264,
          audio: audio));
      final png = '${dir.path}/card.png';
      expect((await Process.run('ffmpeg', ['-loglevel', 'error', '-f', 'lavfi', '-i', 'color=c=navy:s=320x180', '-frames:v', '1', png])).exitCode, 0);
      final chunkFile = '${dir.path}/chunk.ts';
      await run(EncodeArgs.cardChunk(png: png, output: chunkFile, quality: ExportQuality.p720, encoder: VideoEncoder.x264));
      final chunk = await File(chunkFile).readAsBytes();

      final s = TsSplicer();
      final stream = BytesBuilder()
        ..add(s.segment(chunk))
        ..add(s.segment(await part(const Duration(seconds: 2), 90)))
        ..add(s.segment(chunk))
        ..add(s.segment(chunk))
        ..add(s.segment(await part(const Duration(seconds: 6), 60, audio: false)));
      expect(s.clockSeconds, closeTo((30 + 90 + 30 + 30 + 60) * 1001 / 30000, 0.001));
      final file = File('${dir.path}/out.ts')..writeAsBytesSync(stream.toBytes());

      final probe = await Process.run('ffprobe', [
        '-v', 'error', '-show_entries', 'packet=stream_index,pts_time,flags', '-of', 'json', file.path,
      ]);
      final packets = ((jsonDecode('${probe.stdout}') as Map)['packets'] as List).cast<Map<String, Object?>>();
      final video = [
        for (final p in packets)
          if (p['stream_index'] == 0) double.parse(p['pts_time']! as String),
      ]..sort();
      expect(video, hasLength(240));
      for (var i = 1; i < video.length; i++) {
        expect(video[i] - video[i - 1], closeTo(1001 / 30000, 0.002), reason: 'frame $i at ${video[i]}');
      }
      expect(packets.where((p) => '${p['flags']}'.contains('C')), isEmpty, reason: 'no corrupt packets');
      // In stream order: each AAC frame (1024 samples) starts no earlier
      // than the one before it ends, so no audio ever overlaps.
      final audio = [
        for (final p in packets)
          if (p['stream_index'] == 1) double.parse(p['pts_time']! as String),
      ];
      const aacFrame = 1024 / 48000;
      for (var i = 1; i < audio.length; i++) {
        expect(audio[i] - audio[i - 1], greaterThanOrEqualTo(aacFrame - 0.0005),
            reason: 'audio overlaps at ${audio[i]}');
        expect(audio[i] - audio[i - 1], lessThan(0.06), reason: 'no audio gap at ${audio[i]}');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
