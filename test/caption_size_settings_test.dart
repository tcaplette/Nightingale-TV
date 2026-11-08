import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/caption_size.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaybackSettings.captionSize', () {
    const large = PlaybackSettings(captionSize: CaptionSize.large);

    test('round trip', () {
      expect(PlaybackSettings.fromJson(large.toJson()).captionSize, CaptionSize.large);
      expect(large.toJson()['captionSize'], 'large');
    });

    test('kept on every way a saved bitrate is read', () {
      expect(PlaybackSettings.fromJson({'bitrate': 8000, 'captionSize': 'small'}).captionSize, CaptionSize.small);
      expect(PlaybackSettings.fromJson({'maxBitrateMbps': 8, 'captionSize': 'small'}).captionSize, CaptionSize.small);
      expect(PlaybackSettings.fromJson({'bitrate': 'original', 'captionSize': 'small'}).captionSize, CaptionSize.small);
      expect(PlaybackSettings.fromJson({'captionSize': 'small'}).captionSize, CaptionSize.small);
    });

    test('missing or unknown is no size chosen', () {
      expect(PlaybackSettings.fromJson({'bitrate': 8000}).captionSize, isNull);
      expect(PlaybackSettings.fromJson({'captionSize': 'huge'}).captionSize, isNull);
      expect(PlaybackSettings.fromJson({'captionSize': 54}).captionSize, isNull);
      expect(PlaybackSettings.off.toJson().containsKey('captionSize'), isFalse);
    });

    test('in ==, hashCode, toString and copyWith; can go back to none', () {
      expect(large, isNot(PlaybackSettings.off));
      expect(large, const PlaybackSettings(captionSize: CaptionSize.large));
      expect(large.hashCode, const PlaybackSettings(captionSize: CaptionSize.large).hashCode);
      expect('$large', contains('large'));
      expect(PlaybackSettings.off.copyWith(captionSize: () => CaptionSize.large), large);
      expect(large.copyWith(captionSize: () => null), PlaybackSettings.off);
      expect(large.copyWith(captions: true).captionSize, CaptionSize.large);
    });

    test('changes no playback decision', () {
      expect(large.decidesLike(PlaybackSettings.off), isTrue);
    });
  });

  group('the size in force', () {
    late Directory dir;
    late AppState app;
    const channel = MethodChannel('nightingale_tv/platform');
    Object? system;

    void systemScale() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'captionFontScale') return null;
          if (system is Exception) throw system!;
          return system;
        });

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_caption_size');
      app = await signedInApp(dir, fakeLibrary());
      PlatformInfo.debugOverride = TargetPlatform.android;
      system = 1.0;
      systemScale();
    });

    tearDown(() async {
      PlatformInfo.debugReset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await app.close();
      await app.storage.flush();
      await dir.delete(recursive: true);
    });

    test('with none saved it follows the system, read again on resume', () async {
      system = 2.0;
      await app.readSystemCaptionSize();
      expect(app.captionSize.value, CaptionSize.extraLarge);
      system = 0.5;
      await app.readSystemCaptionSize();
      expect(app.captionSize.value, CaptionSize.small);
      expect(app.settings.playback.captionSize, isNull, reason: 'following the system saves nothing');
    });

    test('a size chosen in the app wins, and stays when the system changes', () async {
      system = 2.0;
      await app.readSystemCaptionSize();
      await app.setPlayback(app.settings.playback.copyWith(captionSize: () => CaptionSize.small));
      expect(app.captionSize.value, CaptionSize.small);
      system = 1.5;
      await app.readSystemCaptionSize();
      expect(app.captionSize.value, CaptionSize.small);
    });

    test('a failed read is Medium', () async {
      system = PlatformException(code: 'nope');
      await app.readSystemCaptionSize();
      expect(app.captionSize.value, CaptionSize.medium);
    });

    test('no value from the system is Medium', () async {
      system = null;
      await app.readSystemCaptionSize();
      expect(app.captionSize.value, CaptionSize.medium);
    });

    test('off Android there is no system size to read', () async {
      PlatformInfo.debugOverride = TargetPlatform.linux;
      system = 2.0;
      await app.readSystemCaptionSize();
      expect(app.captionSize.value, CaptionSize.medium);
    });
  });
}
