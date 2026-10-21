// The Linux leveling chain (volumeLevelingChain) run through ffmpeg on the
// spec's test signal, checked against the spec's limits (volume-leveling,
// "Leveling evens out loudness" and "Leveling adds no start-up delay").
// Skipped when ffmpeg isn't installed.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';

/// The spec's sections: pink noise at these loudnesses (LUFS), in order.
const _sections = [(seconds: 20, lufs: -36.0), (seconds: 20, lufs: -12.0), (seconds: 5, lufs: -54.0), (seconds: 20, lufs: -24.0)];

/// Stereo pink noise (two independent channels), 48 kHz, [seconds] long.
String _noise(int seconds) => 'anoisesrc=d=$seconds:c=pink:r=48000:a=0.5:seed=7[l];'
    'anoisesrc=d=$seconds:c=pink:r=48000:a=0.5:seed=11[r];[l][r]amerge=inputs=2';

/// Short-term loudness (LUFS) every 100 ms, by time, and the sample peak
/// (dBFS), from ebur128's log.
typedef Measurement = ({Map<double, double> shortTerm, double samplePeak, double integrated});

Future<Measurement> _measure(String source, String? chain) async {
  final graph = [?chain, 'ebur128=framelog=info:peak=sample'].join(',');
  final r = await Process.run('ffmpeg', [
    '-hide_banner', '-nostats', '-f', 'lavfi', '-i', source, '-af', graph, '-f', 'null', '-',
  ]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  final log = r.stderr as String;
  final shortTerm = <double, double>{};
  for (final m in RegExp(r't:\s*([\d.]+)\s+TARGET.*?S:\s*(-?[\d.]+|-inf)').allMatches(log)) {
    shortTerm[double.parse(m.group(1)!)] = double.tryParse(m.group(2)!) ?? double.negativeInfinity;
  }
  final summary = log.substring(log.lastIndexOf('Summary:'));
  double field(String pattern) => double.parse(RegExp(pattern).firstMatch(summary)!.group(1)!);
  return (
    shortTerm: shortTerm,
    samplePeak: field(r'Sample peak:\s*Peak:\s*(-?[\d.]+)'),
    integrated: field(r'Integrated loudness:\s*I:\s*(-?[\d.]+)'),
  );
}

/// The mean short-term loudness from [from] to [to] seconds.
double _mean(Map<double, double> s, double from, double to) {
  final values = [for (final e in s.entries) if (e.key > from && e.key <= to + 1e-6) e.value];
  return values.reduce((a, b) => a + b) / values.length;
}

double _max(Map<double, double> s, double from, double to) =>
    [for (final e in s.entries) if (e.key > from && e.key <= to + 1e-6) e.value].reduce((a, b) => a > b ? a : b);

/// The short-term loudness nearest to [t].
double _at(Map<double, double> s, double t) =>
    s.entries.reduce((a, b) => (a.key - t).abs() <= (b.key - t).abs() ? a : b).value;

/// Milliseconds from starting ffmpeg in real time to its first output bytes,
/// with [chain] (or none): the best of three runs.
Future<int> _firstOutputMs(String? chain) async {
  var best = 1 << 30;
  for (var run = 0; run < 3; run++) {
    final watch = Stopwatch()..start();
    final p = await Process.start('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-re', '-f', 'lavfi', '-i', _noise(3),
      '-af', chain ?? 'anull', '-flush_packets', '1', '-f', 's16le', '-',
    ]);
    final first = Completer<int>();
    final sub = p.stdout.listen((_) {
      if (!first.isCompleted) first.complete(watch.elapsedMilliseconds);
    });
    unawaited(p.stderr.drain<void>());
    final ms = await first.future.timeout(const Duration(seconds: 20));
    p.kill();
    await p.exitCode;
    await sub.cancel();
    if (ms < best) best = ms;
  }
  return best;
}

void main() {
  late bool ffmpeg;
  setUpAll(() async {
    try {
      ffmpeg = (await Process.run('ffmpeg', ['-version'])).exitCode == 0;
    } on ProcessException {
      ffmpeg = false;
    }
  });

  test('the chain evens out the spec\'s test signal within its limits', () async {
    if (!ffmpeg) return markTestSkipped('ffmpeg is not installed');
    final total = _sections.fold(0, (t, s) => t + s.seconds);
    // The noise's own loudness, so each section can be set to its level.
    final base = (await _measure(_noise(10), null)).integrated;
    var from = 0;
    final gains = StringBuffer();
    for (final s in _sections) {
      gains.write("if(lt(t,${from + s.seconds}),${s.lufs - base}dB,");
      from += s.seconds;
    }
    final signal = "${_noise(total)},volume='${gains}0dB${')' * _sections.length}':eval=frame";

    final input = await _measure(signal, null);
    final output = await _measure(signal, volumeLevelingChain);

    // The input is the test signal the spec describes.
    expect(_mean(input.shortTerm, 10, 20), closeTo(-36, 0.5));
    expect(_mean(input.shortTerm, 30, 40), closeTo(-12, 0.5));
    expect(_mean(input.shortTerm, 55, 65), closeTo(-24, 0.5));

    final quiet = _mean(output.shortTerm, 10, 20);
    final loud = _mean(output.shortTerm, 30, 40);
    final medium = _mean(output.shortTerm, 55, 65);
    final spread = [quiet, loud, medium].reduce((a, b) => a > b ? a : b) -
        [quiet, loud, medium].reduce((a, b) => a < b ? a : b);
    final onset = _max(output.shortTerm, 20, 23) - loud;
    final raised = _at(output.shortTerm, 45) - _at(input.shortTerm, 45);
    final latency = await _firstOutputMs(volumeLevelingChain) - await _firstOutputMs(null);
    // ignore: avoid_print
    print('leveled: quiet ${quiet.toStringAsFixed(1)}, loud ${loud.toStringAsFixed(1)}, '
        'medium ${medium.toStringAsFixed(1)} LUFS; spread ${spread.toStringAsFixed(1)} LU, '
        'onset +${onset.toStringAsFixed(1)} LU, near-silence +${raised.toStringAsFixed(1)} dB, '
        'peak ${output.samplePeak.toStringAsFixed(2)} dBFS, first output +$latency ms');

    expect(spread, lessThanOrEqualTo(8), reason: 'steady loudness within 8 LU');
    expect(onset, lessThanOrEqualTo(3), reason: 'the loud section starts no more than 3 LU above where it settles');
    expect(raised, lessThanOrEqualTo(12), reason: 'near-silence raised by no more than 12 dB');
    expect(output.samplePeak, lessThanOrEqualTo(-0.5), reason: 'peaks at most 0.5 dB over -1 dBFS');
    expect(latency, lessThanOrEqualTo(50), reason: 'no look-ahead beyond the limiter\'s');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
