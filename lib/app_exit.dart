import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'platform/platform_info.dart';

/// Run (briefly) before the app quits, e.g. to stop a transcode job on the
/// server.
final exitHooks = <Future<void> Function()>{};

/// How long quitting may wait for [exitHooks].
const exitHookTimeout = Duration(seconds: 3);

/// Runs every [exitHooks] at once, giving up after [exitHookTimeout].
Future<void> runExitHooks() async {
  await Future.wait([for (final hook in exitHooks) hook()]).timeout(exitHookTimeout, onTimeout: () => const []);
}

/// Closes the app for good: the window on a PC, the activity on Android.
/// Replaceable in tests.
@visibleForTesting
Future<void> Function() closeApp = () async {
  if (PlatformInfo.isDesktop) {
    await windowManager.destroy();
  } else {
    await SystemNavigator.pop();
  }
};

/// Quits: runs [exitHooks], then [beforeClosing] (such as stopping
/// playback), then closes the app.
Future<void> quitApp({Future<void> Function()? beforeClosing}) async {
  await runExitHooks();
  await beforeClosing?.call();
  await closeApp();
}
