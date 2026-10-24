import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which OS the app is running on, and what it's called there. Every
/// Android-only behavior in the app is gated through here.
///
/// Based on `dart:io`'s [Platform] (the real host), never on
/// `defaultTargetPlatform`, which reports Android inside `flutter test` and
/// would switch Linux tests to Android behavior.
abstract final class PlatformInfo {
  static const _channel = MethodChannel('nightingale_tv/platform');

  /// Pretends to run on this platform, so tests on Linux can exercise the
  /// Android branches. Null (the default) means the real host.
  @visibleForTesting
  static TargetPlatform? debugOverride;

  static String? _androidName;

  static TargetPlatform get _platform =>
      debugOverride ??
      (Platform.isAndroid
          ? TargetPlatform.android
          : Platform.isLinux
              ? TargetPlatform.linux
              : Platform.isMacOS
                  ? TargetPlatform.macOS
                  : Platform.isWindows
                      ? TargetPlatform.windows
                      : Platform.isIOS
                          ? TargetPlatform.iOS
                          : TargetPlatform.fuchsia);

  static bool get isAndroid => _platform == TargetPlatform.android;

  /// A PC: window handling, F11, programs such as ffmpeg, Live TV export.
  static bool get isDesktop => switch (_platform) {
        TargetPlatform.linux || TargetPlatform.windows || TargetPlatform.macOS => true,
        _ => false,
      };

  /// The name Jellyfin shows for this device: the name set in Android's
  /// settings (or its maker and model), or the PC's host name.
  static String get deviceName => isAndroid ? (_androidName ?? 'Android') : Platform.localHostname;

  /// An Android TV (Google TV, Fire TV…): run with a remote and an air
  /// mouse, never touch.
  static bool get isTelevision => isAndroid && (_television ?? false);
  static bool? _television;

  /// Pretends to be (or not be) a TV, with [debugOverride] set to Android.
  @visibleForTesting
  static set debugTelevision(bool? value) => _television = value;

  /// Looks up the Android device name and kind once, before anything signs in.
  static Future<void> init() async {
    if (!isAndroid) return;
    try {
      final name = (await _channel.invokeMethod<String>('deviceName'))?.trim();
      if (name != null && name.isNotEmpty) _androidName = name;
      _television = await _channel.invokeMethod<bool>('isTelevision');
    } on PlatformException catch (e) {
      debugPrint('Device name unavailable: $e');
    } on MissingPluginException catch (e) {
      debugPrint('Device name unavailable: $e');
    }
  }

  /// Has a touch screen to tap links on: a phone or tablet, not a TV or a
  /// PC.
  static bool get hasTouch => isAndroid && !isTelevision;

  /// Opens [url] in the browser; false when there's none to open it.
  static Future<bool> openUrl(String url) async {
    try {
      if (isAndroid) return await _channel.invokeMethod<bool>('openUrl', url) ?? false;
      final result = await Process.run('xdg-open', [url]);
      return result.exitCode == 0;
    } on Object catch (e) {
      debugPrint('Could not open $url: $e');
      return false;
    }
  }

  /// Forgets the looked-up name and the override, between tests.
  @visibleForTesting
  static void debugReset() {
    debugOverride = null;
    _androidName = null;
    _television = null;
  }
}
