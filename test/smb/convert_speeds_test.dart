import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/convert/convert_speeds.dart';
import 'package:nightingale_tv/server/smb/smb_probe.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('speeds'));
  tearDown(() => dir.delete(recursive: true));

  test('kinds of picture', () {
    expect(ConvertSpeeds.classOf(const ProbeVideo(codec: 'hevc', bitDepth: 10, height: 2160, fps: 23.976, hdr: true)), 'hevc|10|2160|30|hdr');
    expect(ConvertSpeeds.classOf(const ProbeVideo(codec: 'vc1', height: 480, fps: 29.97)), 'vc1|8|sd|30');
    expect(ConvertSpeeds.classOf(const ProbeVideo(codec: 'h264', height: 720, fps: 59.94)), 'h264|8|720|60');
  });

  test('untried, fast enough, too slow; kept for the device', () async {
    final s = ConvertSpeeds(File('${dir.path}/convert_speed.json'));
    expect(await s.fastEnough('k'), isNull);
    await s.record('k', 2.4);
    await s.record('slow', 0.4);
    final again = ConvertSpeeds(File('${dir.path}/convert_speed.json'));
    expect(await again.fastEnough('k'), isTrue);
    expect(await again.fastEnough('slow'), isFalse);
  });

  test('two stalls within 5 minutes make a kind too slow; farther apart they don\'t', () async {
    final s = ConvertSpeeds(File('${dir.path}/convert_speed.json'));
    await s.record('k', 2);
    final t = DateTime(2026);
    expect(await s.stalled('k', now: t), isFalse);
    expect(await s.stalled('k', now: t.add(const Duration(minutes: 6))), isFalse);
    expect(await s.fastEnough('k'), isTrue);
    expect(await s.stalled('k', now: t.add(const Duration(minutes: 8))), isTrue);
    expect(await s.fastEnough('k'), isFalse);
  });
}
