import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';

/// ffmpeg's stderr from scanning 5 minutes of the test server's commercial
/// reel ("Favorite Commercials", from 10:00), with the app's filter
/// settings.
final _reel = File('test/fixtures/reel_window_600.txt').readAsStringSync();

double _s(Duration d) => d.inMicroseconds / 1e6;

void main() {
  test('reads black frames and silences from the real reel scan', () {
    final d = parseFfmpegDetections(_reel);
    expect([for (final b in d.blacks) _s(b.start)],
        [16.908575, 47.06373, 78.094761, 108.333333, 138.488488, 169.51952, 225.075075, 256.314648]);
    expect(_s(d.blacks[1].end), 48.231565);
    expect([for (final s in d.silences) _s(s.end)],
        [48.620771, 78.296083, 108.482312, 226.256375, 226.414, 256.608937, 286.867042]);
    expect(_s(d.silences.first.start), 47.391896);
  });

  test('black frames with silence nearby are strong cuts', () {
    final d = parseFfmpegDetections(_reel);
    expect([for (final b in d.blacks) d.isStrong(b)], [false, true, true, true, false, false, true, true]);
  });

  test('times of a windowed scan are shifted to positions in the video', () {
    final d = parseFfmpegDetections(_reel, offset: const Duration(minutes: 10));
    expect(_s(d.blacks.first.start), 616.908575);
    expect(_s(d.silences.first.start), 647.391896);
  });

  test('a silence still open at the end closes there', () {
    const stderr = '[silencedetect @ 0x1] silence_start: 12.5\n'
        '[blackdetect @ 0x2] black_start:12.4 black_end:13.0 black_duration:0.6\n';
    final d = parseFfmpegDetections(stderr, end: const Duration(seconds: 20));
    expect(d.silences, [const Span(Duration(milliseconds: 12500), Duration(seconds: 20))]);
    expect(parseFfmpegDetections(stderr).silences, isEmpty);
  });

  test('progress lines with carriage returns and noise are ignored', () {
    const stderr = 'frame=  100 fps=0.0 q=-0.0 size=N/A time=00:00:04.17\r'
        'frame=  200 time=00:00:08.34\r[silencedetect @ 0x1] silence_start: -0.002\n'
        '[silencedetect @ 0x1] silence_end: 0.6 | silence_duration: 0.6\n';
    final d = parseFfmpegDetections(stderr);
    expect(d.blacks, isEmpty);
    expect(d.silences, [const Span(Duration.zero, Duration(milliseconds: 600))]);
  });

  test('detections round-trip through JSON', () {
    final d = parseFfmpegDetections(_reel);
    final copy = Detections.fromJson(d.toJson());
    expect(copy.blacks.length, d.blacks.length);
    expect(copy.blacks[1].start, const Duration(milliseconds: 47063));
  });
}
