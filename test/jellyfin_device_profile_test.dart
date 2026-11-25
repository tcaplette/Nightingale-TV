import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/playback/android_device_profile.dart';

/// The device profile is Jellyfin's API, not text for people: it reads the
/// same in every app language. A translated value there ("Extern", "外部")
/// makes Jellyfin answer PlaybackInfo with 400.
void main() {
  test('the device profile is the same in every language', () {
    final english = jsonEncode(JellyfinClient.deviceProfile(8000000));
    for (final language in supportedLanguages) {
      expect(runInLanguage(language, () => jsonEncode(JellyfinClient.deviceProfile(8000000))), english, reason: language);
    }
    final subtitles = JellyfinClient.deviceProfile(null)['SubtitleProfiles']! as List;
    expect({for (final p in subtitles) (p as Map)['Method']}, {'External'});
  });

  test('the Android device profile is the same in every language', () {
    const caps = DeviceCapabilities(video: [], audio: {'aac'});
    final english = jsonEncode(androidDeviceProfile(caps, maxBitrate: 8000000));
    for (final language in supportedLanguages) {
      expect(runInLanguage(language, () => jsonEncode(androidDeviceProfile(caps, maxBitrate: 8000000))), english, reason: language);
    }
    final subtitles = androidDeviceProfile(caps)['SubtitleProfiles']! as List;
    expect({for (final p in subtitles) (p as Map)['Method']}, {'Embed', 'External'});
  });
}
