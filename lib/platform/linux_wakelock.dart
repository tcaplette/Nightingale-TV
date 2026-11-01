import 'package:flutter/foundation.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'platform_info.dart';

/// media_kit holds off the screensaver while a player plays, through
/// wakelock_plus. On Linux that plugin asks the desktop portal for a new
/// inhibit on every enable and keeps only the last one, so each play after
/// the first leaves one that its disable never closes, and the screensaver
/// stays held off after playback stops (the sleep timer's sleep, or the
/// Menu). This keeps it to one: enabling while enabled, or disabling while
/// disabled, does nothing, and calls reach the plugin one at a time.
class SingleLinuxWakelock extends WakelockPlusPlatformInterface {
  SingleLinuxWakelock(this._inner);

  final WakelockPlusPlatformInterface _inner;
  bool _on = false;
  Future<void> _last = Future.value();

  /// Wraps the plugin's own instance (Linux only; in main, after the plugins
  /// have registered).
  static void install() {
    if (!PlatformInfo.isDesktop || defaultTargetPlatform != TargetPlatform.linux) return;
    final current = WakelockPlusPlatformInterface.instance;
    if (current is! SingleLinuxWakelock) WakelockPlusPlatformInterface.instance = SingleLinuxWakelock(current);
  }

  @override
  Future<void> toggle({required bool enable}) {
    if (enable == _on) return _last;
    _on = enable;
    return _last = _last.catchError((Object _) {}).then((_) => _inner.toggle(enable: enable));
  }

  @override
  Future<bool> get enabled async => _on;
}
