// The picture on Android's system video layer (system-video-layer D9): files
// made by tool/make_video_layer_clips.sh, served by the test from the app's
// own storage, each played and described (decoder buffer, crop, layer, hole).
// No server is needed.
//
//   flutter build apk --debug --flavor free --target-platform android-x64 \
//     -t integration_test/video_layer_test.dart
// Boot the emulator, install the APK, then run tool/video_layer_host.py, which
// copies the files in, starts the test, takes the screenshots it asks for
// ("VLT SNAP name") and compares them with the files' own pictures.
// `adb shell setprop debug.nightingale_tv.software_video 1` picks Android's
// software decoders, whose buffers are padded.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/playback/exo_tuner_player.dart';
import 'package:nightingale_tv/playback/video_look.dart';
import 'package:path_provider/path_provider.dart';

import 'fake_jellyfin.dart';

// ignore: avoid_print
void _say(String s) => print('VLT $s');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('every file shows its whole picture', (tester) async {
    if (!Platform.isAndroid) {
      markTestSkipped('Android only.');
      return;
    }
    Future<T> io<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;
    Future<void> wait(int ms) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    final dir = Directory('${(await io(getApplicationSupportDirectory)).path}/video_layer');
    final clips = [
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.mp4') || f.path.endsWith('.ts')) f.uri.pathSegments.last,
    ]..sort();
    expect(clips, isNotEmpty, reason: 'tool/video_layer_host.py copies the files in');
    final server = await io(() => HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    server.listen((request) => serveFile(request, File('${dir.path}/${request.uri.pathSegments.last}')));

    // As the app does: no system bars over the picture.
    await io(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    final player = ExoTunerPlayer();
    final lines = <String>[];
    final logs = player.logStream.listen((l) {
      lines.add(l);
      _say('LOG $l');
    });
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(fit: StackFit.expand, children: [player.buildVideo(), player.buildCaptions()]),
    ));

    final wrong = <String>[];
    for (final clip in clips) {
      final name = clip.split('.').first;
      lines.clear();
      _say('OPEN $name');
      await io(() => player.open(Uri.parse('http://127.0.0.1:${server.port}/$clip'), headers: const {}));
      final opened = DateTime.now();
      while (!lines.any((l) => l.contains('first frame'))) {
        if (DateTime.now().difference(opened) > const Duration(seconds: 15)) break;
        await wait(50);
      }
      if (!lines.any((l) => l.contains('first frame'))) {
        // A format this device has no decoder for isn't the layer's fault.
        if (lines.any((l) => l.contains('no decoder for'))) {
          _say('SKIP $name: no decoder');
        } else {
          wrong.add('$name: no picture');
        }
        continue;
      }
      await wait(1500);
      final report = await io(() => const MethodChannel('nightingale_tv/player')
          .invokeMethod<Map<Object?, Object?>>('videoReport', {'id': player.id}));
      final out = (report?['decoder_output'] as Map?) ?? const {};
      _say('REPORT $name ${jsonEncode({
            'decoder': report?['decoder'],
            'buffer': '${out['width']}x${out['height']}',
            'crop': '${out['crop-left']},${out['crop-top']},${out['crop-right']},${out['crop-bottom']}',
            'stride': out['stride'],
            'layer': report?['layer'],
            'hole': '${player.holes.current?.shownOnScreen}',
            'size': '${player.videoSize.value}',
            'color': '${out['color-standard']}/${out['color-transfer']}/${out['color-range']}',
          })}');
      _say('SNAP $name');
      await wait(3500);
    }
    Uri url(String clip) => Uri.parse('http://127.0.0.1:${server.port}/$clip');
    Future<int?> until(String line, {int ms = 10000}) async {
      final from = DateTime.now();
      while (DateTime.now().difference(from).inMilliseconds < ms) {
        if (lines.any((l) => l.contains(line))) return DateTime.now().difference(from).inMilliseconds;
        await wait(15);
      }
      return null;
    }

    // The effects on the video (D5): on from the open, changed live, off, and
    // on again mid-play with the sound unbroken.
    const noRed = VideoLook(matrix: [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
    const noBlue = VideoLook(matrix: [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]);
    for (final clip in clips.where((c) => c.startsWith('h264_1920') || c.startsWith('mpeg2') || c.startsWith('av1_pq'))) {
      final name = clip.split('.').first;
      _say('EFFECTS $name');
      player.setVideoLook(noRed);
      lines.clear();
      await io(() => player.open(url(clip), headers: const {}));
      if (await until('first frame') == null) {
        _say('SKIP $name: no picture');
        continue;
      }
      await wait(1500);
      _say('SNAP fx_open_$name');
      await wait(3500);
      lines.clear();
      player.setVideoLook(noBlue);
      await wait(700);
      if (lines.any((l) => l.contains('decoder'))) wrong.add('$name: a live change made a new decoder');
      _say('SNAP fx_live_$name');
      await wait(3500);
      for (final (what, look) in [('off', VideoLook.none), ('on', noRed)]) {
        lines.clear();
        final positions = <(int, int)>[];
        final buffering = <bool>[];
        final p = player.positionStream.listen(
            (d) => positions.add((DateTime.now().millisecondsSinceEpoch, d.inMilliseconds)));
        final b = player.bufferingStream.listen(buffering.add);
        player.setVideoLook(look);
        final took = await until('first frame');
        await wait(2500);
        await p.cancel();
        await b.cancel();
        var worst = 0, drift = 0;
        for (var i = 1; i < positions.length; i++) {
          final wall = positions[i].$1 - positions[i - 1].$1, at = positions[i].$2 - positions[i - 1].$2;
          if (wall > worst) worst = wall;
          if ((wall - at).abs() > drift) drift = (wall - at).abs();
        }
        _say('SWITCH $name $what picture after $took ms, ticks ${positions.length} worst gap $worst ms '
            'drift $drift ms buffering $buffering');
        if (took == null || took > 1000) wrong.add('$name $what: picture after $took ms');
        if (buffering.contains(true) || drift > 150) wrong.add('$name $what: the sound broke ($buffering, $drift ms)');
        _say('SNAP fx_${what}_$name');
        await wait(3500);
      }
      player.setVideoLook(VideoLook.none);
      await wait(1500);
    }

    // A hand-over between sizes: one first frame, no black.
    if (clips.contains('h264_720x480.mp4') && clips.contains('h264_1920x1080.mp4')) {
      _say('REC handover 12');
      await wait(1500);
      lines.clear();
      await io(() => player.open(url('h264_720x480.mp4'), headers: const {}, end: const Duration(seconds: 4)));
      await io(() => player.enqueue(url('h264_1920x1080.mp4'), headers: const {}, start: const Duration(seconds: 2)));
      await wait(8000);
      final frames = lines.where((l) => l.contains('first frame')).length;
      _say('HANDOVER first frames $frames size ${player.videoSize.value}');
      if (frames != 2) wrong.add('hand-over: $frames first frames');
      await wait(4000);
    }

    await io(player.dispose);
    await logs.cancel();
    await io(() => server.close(force: true));
    _say('DONE ${wrong.isEmpty ? 'ok' : wrong.join('; ')}');
    expect(wrong, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
