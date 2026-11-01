import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/platform/linux_wakelock.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Records toggles, each finishing when the test says (or at once).
class _Portal extends WakelockPlusPlatformInterface {
  final calls = <bool>[];
  Completer<void>? hold;

  @override
  Future<void> toggle({required bool enable}) async {
    calls.add(enable);
    await hold?.future;
  }

  @override
  Future<bool> get enabled async => calls.isNotEmpty && calls.last;
}

void main() {
  test('repeated enables reach the plugin once, so one disable releases the hold', () async {
    final portal = _Portal();
    final lock = SingleLinuxWakelock(portal);
    await lock.toggle(enable: true);
    await lock.toggle(enable: true);
    await lock.toggle(enable: true);
    expect(portal.calls, [true]);
    expect(await lock.enabled, isTrue);
    await lock.toggle(enable: false);
    await lock.toggle(enable: false);
    expect(portal.calls, [true, false]);
    expect(await lock.enabled, isFalse);
  });

  test('a disable waits for an enable still on its way', () async {
    final portal = _Portal()..hold = Completer<void>();
    final lock = SingleLinuxWakelock(portal);
    final on = lock.toggle(enable: true);
    final off = lock.toggle(enable: false);
    await pumpEventQueue();
    expect(portal.calls, [true], reason: 'the disable is queued behind the enable');
    portal.hold!.complete();
    await on;
    await off;
    expect(portal.calls, [true, false]);
  });
}
