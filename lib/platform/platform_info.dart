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

  static bool get isLinux => _platform == TargetPlatform.linux;

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

  /// Counts Left and Right presses from the remote that got past any
  /// on-screen keyboard, which means it's closed. (The keyboard's own caret
  /// keys aren't counted.)
  static final dpadArrows = ValueNotifier<int>(0);

  /// Looks up the Android device name and kind once, before anything signs in.
  static Future<void> init() async {
    if (!isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'dpadArrow') dpadArrows.value++;
      // Android's memory-trim levels (crash-visibility D5).
      if (call.method == 'trimMemory' && call.arguments is String) onTrimMemory?.call(call.arguments as String);
    });
    try {
      final name = (await _channel.invokeMethod<String>('deviceName'))?.trim();
      if (name != null && name.isNotEmpty) _androidName = name;
      _television = await _channel.invokeMethod<bool>('isTelevision');
    } on PlatformException catch (e) {
      debugPrint('Device name unavailable: $e');
    } on MissingPluginException catch (e) {
      debugPrint('Device name unavailable: $e');
    }
    try {
      _androidSdk = await _channel.invokeMethod<int>('sdkInt');
    } on Object catch (e) {
      debugPrint('Android version unavailable: $e');
    }
    // Only for the diagnostics: never in the way of the above.
    try {
      final renderer = await _channel.invokeMethod<Object?>('renderer');
      _renderer = renderer is String ? renderer : null;
    } on Object catch (e) {
      debugPrint('Renderer unavailable: $e');
    }
  }

  /// Android's API level (24 is Android 7); null elsewhere or unknown.
  static int? get androidSdk => _androidSdk;
  static int? _androidSdk;

  /// Pretends to be this Android API level, in tests.
  @visibleForTesting
  static set debugAndroidSdk(int? value) => _androidSdk = value;

  /// The renderer Android asked for at start-up ("skia opengles
  /// (nvidia)", or "default"), for the diagnostics; null elsewhere.
  static String? get renderer => _renderer;
  static String? _renderer;

  /// Has a touch screen to tap links on: a phone or tablet, not a TV or a
  /// PC.
  static bool get hasTouch => isAndroid && !isTelevision;

  /// Opens [url] in the browser; false when there's none to open it.
  /// Phones and tablets: the system share sheet with [text] (share-accounts
  /// Send invite). False where there's none (TVs, Linux) or it failed.
  static Future<bool> shareText(String text, {required String title}) async {
    if (!isAndroid || isTelevision) return false;
    try {
      return await _channel.invokeMethod<bool>('shareText', {'text': text, 'title': title}) ?? false;
    } on Object catch (e) {
      debugPrint('Could not share: $e');
      return false;
    }
  }

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

  /// Android holds the screen on while the app is in front; the sleep timer
  /// lets it go while asleep and holds it again on waking. Nothing elsewhere:
  /// on Linux, mpv stops holding off the screensaver once playback stops.
  static Future<void> keepScreenOn(bool on) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<void>('keepScreenOn', on);
    } on Object catch (e) {
      debugPrint('Keep screen on: $e');
    }
  }

  /// The system's caption font scale (1.0 is normal); null where there's
  /// no such setting or it can't be read.
  static Future<double?> captionFontScale() async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<double>('captionFontScale');
    } on Object catch (e) {
      debugPrint('Caption font scale unavailable: $e');
      return null;
    }
  }

  /// The household's names for Android's own crash reports to leave out
  /// (error-reporting D4).
  static Future<void> setReportNames(List<String> names) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<void>('reportNames', names);
    } on Object catch (e) {
      debugPrint('Report names: $e');
    }
  }

  /// The error reporting check's forced error (`debug.nightingale_tv.force_error`,
  /// set with adb), or null.
  static Future<String?> forcedError() async {
    if (!isAndroid) return null;
    try {
      final value = await _channel.invokeMethod<String>('forcedError');
      return value == null || value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  /// Hears Android's memory-trim levels ("RUNNING_LOW"), set by error
  /// reporting.
  static void Function(String level)? onTrimMemory;

  /// Android's `ActivityManager.MemoryInfo` (availMem, totalMem, threshold,
  /// lowMemory); null elsewhere or when it can't be read.
  static Future<Map<Object?, Object?>?> memoryInfo() async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>('memoryInfo');
    } on Object {
      return null;
    }
  }

  /// Android 11+: why the app's previous process ended, if it ended at or
  /// after [since] (reason, description, pss, rss in bytes); null elsewhere
  /// or when Android doesn't say (crash-visibility D2).
  static Future<Map<Object?, Object?>?> exitReason(DateTime since) async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>('exitReason', since.millisecondsSinceEpoch);
    } on Object {
      return null;
    }
  }

  /// This launch's session id, which Android writes as its clean-exit mark
  /// when the activity finishes (crash-visibility D2).
  static Future<void> setSessionId(String id) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<void>('sessionId', id);
    } on Object catch (e) {
      debugPrint('Session id: $e');
    }
  }

  /// Forgets the looked-up name and the override, between tests.
  @visibleForTesting
  static void debugReset() {
    debugOverride = null;
    _androidName = null;
    _television = null;
    _renderer = null;
    _androidSdk = null;
  }
}
