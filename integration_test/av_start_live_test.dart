// Picture and sound start together on Android (video-size-surface-swap 4.4):
// a Jellyfin conversion joined mid-programme can start its video seconds
// after its audio. Each open of such a stream must start at the first
// picture, with the picture moving from then on (no gap between pictures
// over 0.5 s once playback runs), and the player must log the audio it
// dropped to get there.
//
// On the Android TV emulator, against the test-data.md server:
//   flutter test integration_test/av_start_live_test.dart -d emulator-5554 \
//     --dart-define=AV_URL=… --dart-define=AV_USER=… --dart-define=AV_PW=…
// AV_ITEM picks the item (default: the 1080p 10-bit HEVC episode whose
// conversion froze for 0.9–8 s before the fix); AV_STARTS the offsets in
// seconds, comma-separated. Each open asks the server as the tuner does: the
// device's Android profile, capped at 4 Mbps, joined at the offset.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/playback/android_device_profile.dart';
import 'package:nightingale_tv/playback/exo_tuner_player.dart';

const _url = String.fromEnvironment('AV_URL');
const _user = String.fromEnvironment('AV_USER');
const _pw = String.fromEnvironment('AV_PW');
const _item = String.fromEnvironment('AV_ITEM', defaultValue: '349f7c1a6f8a9774aa9c33d790579f7b');
const _starts = String.fromEnvironment('AV_STARTS', defaultValue: '61.37,187.52,333.29,487.53,662.18,843.91,1021.47,1203.66');

// ignore: avoid_print
void _say(String s) => print('${DateTime.now().toIso8601String()} AVTEST $s');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('conversions whose video starts late open without a frozen picture', (tester) async {
    if (!Platform.isAndroid || _url.isEmpty) {
      markTestSkipped('Android only, with AV_URL, AV_USER and AV_PW set.');
      return;
    }

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<T> io<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;

    final client = JellyfinClient(serverUrl: _url, deviceId: 'nightingale-av-start-test', deviceName: 'AV start test');
    await io(() => client.authenticateByName(_user, _pw, serverName: 'test'));
    final caps = await io(DeviceCapabilities.query) ?? DeviceCapabilities.fallback;
    final profile = androidDeviceProfile(caps, maxBitrate: 4000000);

    final player = ExoTunerPlayer();
    final lines = <String>[];
    final logs = player.logStream.listen(lines.add);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.expand(child: player.buildVideo()),
    ));

    final results = <String>[];
    var lateOpens = 0;
    var frozenOpens = 0;
    var n = 0;
    for (final s in _starts.split(',')) {
      final start = Duration(milliseconds: (double.parse(s.trim()) * 1000).round());
      lines.clear();
      final decision = await io(() => client.playbackDecision(_item, maxBitrate: 4000000, startAt: start, profile: profile));
      final template = decision.transcodeTemplate!;
      final url = await io(() => client.transcodeUri(template, playSessionId: 'avtest-${DateTime.now().millisecondsSinceEpoch}-${n++}', startAt: start));
      await io(() => player.open(url, headers: client.authHeaders));

      // Until playback runs (the position is known), at most 20 s.
      final opened = DateTime.now();
      while (await io(player.debugPosition) == null) {
        if (DateTime.now().difference(opened) > const Duration(seconds: 20)) break;
        await wait(const Duration(milliseconds: 100));
      }
      // From 1 s into playback: the 750 ms window then no longer holds the
      // wait between the first picture (shown while buffering) and the start.
      await wait(const Duration(seconds: 1));
      // Over the next 5 s, every 250 ms: the time since the last picture
      // and the position. A frozen picture is a gap over 0.5 s while the
      // position (the sound) still moves; a gap with the position stopped is
      // a stall (no data), which stops the sound too.
      var worst = Duration.zero;
      var frozen = false, stalled = false;
      final samples = <(Duration, double?)>[];
      final until = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(until)) {
        final gap = await io(() => player.debugFrameGap(const Duration(milliseconds: 750)));
        final pos = await io(player.debugPosition);
        samples.add((gap ?? Duration.zero, pos));
        if (gap != null && gap > worst) worst = gap;
        if (gap != null && gap > const Duration(milliseconds: 500) && samples.length >= 3) {
          final before = samples[samples.length - 3].$2;
          final moved = pos != null && before != null && pos - before >= 0.35;
          if (moved) {
            frozen = true;
          } else {
            stalled = true;
          }
        }
        await wait(const Duration(milliseconds: 250));
      }
      final dropped = lines
          .map((l) => RegExp(r'audio before the first picture dropped: (\d+) ms').firstMatch(l)?.group(1))
          .whereType<String>()
          .map(int.parse)
          .fold<int>(0, (a, b) => a + b);
      final firstFrames = lines.where((l) => l.contains('first frame')).length;
      if (dropped >= 300) lateOpens++;
      if (frozen) frozenOpens++;
      final result = 'start ${start.inMilliseconds / 1000}s: audio dropped $dropped ms, first frames $firstFrames, '
          'longest gap ${worst.inMilliseconds} ms${frozen ? ' FROZEN (sound moving)' : ''}${stalled ? ' stall (sound stopped too)' : ''}';
      results.add(result);
      _say(result);
      if (frozen || stalled) {
        _say('  timeline (gap ms @ pos s): ${samples.map((x) => '${x.$1.inMilliseconds}@${x.$2?.toStringAsFixed(2)}').join(' ')}');
      }
      for (final l in lines.where((l) => l.contains('dropped') || l.contains('first frame') || l.contains('decoder') || l.contains('rebuffer') || l.contains('error') || l.contains('buffered past'))) {
        _say('  $l');
      }
      await io(player.stop);
      await wait(const Duration(milliseconds: 500));
    }

    await logs.cancel();
    await io(player.dispose);
    _say('late-video opens $lateOpens, frozen opens $frozenOpens');
    expect(frozenOpens, 0, reason: results.join('\n'));
    expect(lateOpens, greaterThan(0),
        reason: 'No open started its video late, so nothing was verified:\n${results.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
