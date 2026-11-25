// The whole app on Android's system video layer (system-video-layer): full
// screen, channel changes between sizes, the guide, the menu, Home and back,
// over a fake Jellyfin that plays the long files tool/video_layer_host.py
// makes. No server is needed.
//
//   flutter build apk --debug --flavor free --target-platform android-x64 \
//     -t integration_test/video_layer_app_test.dart
//   tool/video_layer_host.py --app --apk … --out …
//
// The host takes a screenshot at "VLT SNAP name", records the screen at
// "VLT REC name seconds", and does "VLT HOST home|launch".
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/exo_tuner_player.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:path_provider/path_provider.dart';

import '../test/fixtures.dart';
import 'harness.dart';

// ignore: avoid_print
void _say(String s) => print('VLT $s');

/// What each show's episodes play.
const _files = {
  'Cheers': 'long_h264_720x480.mp4',
  'Taxi': 'long_h264_1920x1080.mp4',
  'Wings': 'long_h264_1280x534.mp4',
  'Frasier': 'long_h264_1280x534.mp4',
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('the picture stays where the interface puts it', (tester) async {
    if (!Platform.isAndroid) {
      markTestSkipped('Android only.');
      return;
    }
    final dir = Directory('${(await tester.runAsync(getApplicationSupportDirectory))!.path}/video_layer');
    const shows = {'Cheers': 40, 'Taxi': 30, 'Wings': 30, 'Frasier': 30};
    final genres = {
      'Cheers': ['Comedy'],
      'Taxi': ['Comedy'],
      'Wings': ['Drama'],
      'Frasier': ['Drama'],
    };
    final h = await UiHarness.start(
      tester,
      fakeLibrary(shows: shows, genres: genres),
      server: fakeItems(shows: shows, genres: genres),
      videos: (id) => File('${dir.path}/${_files[id.split('-').first] ?? _files['Taxi']}'),
    );
    final player = h.tuner.media as ExoTunerPlayer;
    final logs = player.logStream.listen((l) => _say('LOG $l'));

    Future<bool> picture({int seconds = 20}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(end)) {
        if (h.tuner.status == TunerStatus.playing && player.playing && player.hasPicture.value) return true;
        await h.wait(const Duration(milliseconds: 100));
      }
      return false;
    }

    Future<void> snap(String name) async {
      _say('SNAP $name ${player.holes.current?.shownOnScreen} ${player.videoSize.value}');
      await h.wait(const Duration(milliseconds: 3500));
    }

    Future<void> rec(String name, int seconds) async {
      _say('REC $name $seconds');
      await h.wait(const Duration(milliseconds: 1500));
    }

    // Not every channel in the generated line-up is one of the three shows':
    // the size says what plays.
    expect(await picture(), isTrue, reason: 'no picture: ${h.tuner.status} ${h.tuner.error}');
    await h.wait(const Duration(seconds: 2));
    // The notice about the other Nightingale TV, where it's installed too.
    if (find.text('Not now').evaluate().isNotEmpty) {
      await snap('dialog');
      await h.tap('Not now');
    }
    await h.wait(const Duration(seconds: 7));
    await snap('full');

    if (h.tester.view.physicalSize.height > h.tester.view.physicalSize.width) {
      // A phone: upright, turned sideways, and back; then half the window.
      await snap('portrait');
      await rec('turn', 12);
      _say('HOST rotate 1');
      await h.wait(const Duration(seconds: 4));
      await snap('sideways');
      _say('HOST rotate 0');
      await h.wait(const Duration(seconds: 4));
      await snap('upright');
      // Touch goes to the interface: a tap on the picture shows its controls.
      _say('HOST tap ${h.tester.view.physicalSize.width ~/ 2} ${(player.holes.current!.shownOnScreen!.center.dy).round()}');
      await h.wait(const Duration(milliseconds: 1200));
      await snap('touched');
      await rec('phone_home', 16);
      _say('HOST home');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
      _say('HOST launch');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      expect(await picture(), isTrue);
      await h.wait(const Duration(seconds: 3));
      await snap('phone_after_home');
      await logs.cancel();
      _say('DONE ok');
      await h.dispose();
      return;
    }

    // Channels, up and down: between sizes.
    await rec('channels', 14);
    for (var i = 0; i < 3; i++) {
      await h.press(LogicalKeyboardKey.pageUp, after: const Duration(milliseconds: 2500));
      _say('ON ${h.tuner.channel?.name} ${player.videoSize.value}');
      expect(await picture(), isTrue);
    }
    await h.wait(const Duration(seconds: 7));
    await snap('channel');

    // The guide and back.
    await rec('guide', 8);
    await h.press(LogicalKeyboardKey.keyG, after: const Duration(milliseconds: 2500));
    expect(find.byType(GuideView), findsOneWidget);
    await h.press(LogicalKeyboardKey.escape, after: const Duration(milliseconds: 2500));
    expect(find.byType(GuideView), findsNothing);
    await h.wait(const Duration(seconds: 3));
    await h.press(LogicalKeyboardKey.keyG, after: const Duration(milliseconds: 2500));
    await snap('in_guide');
    await h.press(LogicalKeyboardKey.escape, after: const Duration(milliseconds: 2500));
    await h.wait(const Duration(seconds: 6));
    await snap('after_guide');

    // The menu over the picture and back.
    await rec('menu', 8);
    await h.press(LogicalKeyboardKey.keyM, after: const Duration(milliseconds: 2500));
    expect(find.byType(MenuScreen), findsOneWidget);
    await h.press(LogicalKeyboardKey.escape, after: const Duration(milliseconds: 2500));
    expect(find.byType(MenuScreen), findsNothing);
    await h.wait(const Duration(seconds: 6));
    await snap('after_menu');

    // Every shape and an effect, then held, dimmed and played on.
    for (final (name, look) in [
      ('fill', const RetroSettings(shape: PictureShape.fill43, surround: Surround.charcoal)),
      ('fit', const RetroSettings(shape: PictureShape.fit43, surround: Surround.channel)),
      ('arcade', const RetroSettings(shape: PictureShape.fill43, crt: CrtStyle.arcade)),
      ('plain', const RetroSettings()),
    ]) {
      await tester.runAsync(() => h.app.setMainRetro(look));
      await h.wait(const Duration(seconds: 2));
      await snap('look_$name');
    }
    await h.press(LogicalKeyboardKey.mediaPlayPause, after: const Duration(seconds: 2));
    expect(h.tuner.paused, isTrue);
    await snap('paused');
    // A look changed while held shows on the held picture.
    await tester.runAsync(() => h.app.setMainRetro(const RetroSettings(crt: CrtStyle.arcade)));
    await h.wait(const Duration(seconds: 2));
    await snap('paused_arcade');
    await tester.runAsync(() => h.app.setMainRetro(const RetroSettings()));
    await h.press(LogicalKeyboardKey.mediaPlayPause, after: const Duration(seconds: 2));
    expect(h.tuner.paused, isFalse);
    await h.press(LogicalKeyboardKey.mediaRewind, after: const Duration(seconds: 3));
    _say('BEHIND ${h.tuner.behind}');
    expect(await picture(), isTrue);
    await snap('timeshift');

    // Home and back. No frames are drawn in the background, so no pump.
    await rec('home', 16);
    _say('HOST home');
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
    _say('PICTURE AWAY ${player.hasPicture.value}');
    _say('HOST launch');
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    expect(await picture(), isTrue, reason: 'no picture after Home and back');
    await h.wait(const Duration(seconds: 8));
    await snap('after_home');

    await logs.cancel();
    _say('DONE ok');
    await h.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
