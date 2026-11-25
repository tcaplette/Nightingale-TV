import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data/app_storage.dart';
import 'platform/platform_info.dart';

/// Run (briefly) before the app quits, e.g. to stop a transcode job on the
/// server.
final exitHooks = <Future<void> Function()>{};

/// How long quitting may wait for [exitHooks].
const exitHookTimeout = Duration(seconds: 3);

/// Runs every [exitHooks] at once, giving up after [timeout].
Future<void> runExitHooks({Duration timeout = exitHookTimeout}) async {
  await Future.wait([for (final hook in exitHooks) hook()]).timeout(timeout, onTimeout: () => const []);
}

/// Server mode's wait for [exitHooks]: long enough for every export
/// stream's ffmpeg to be made to stop (2 s, then killed), inside
/// [serverStopDeadline].
const serverExitHookTimeout = Duration(seconds: 6);

/// Closes the app for good: the window on a PC, the activity on Android.
/// Replaceable in tests.
///
/// On a PC the process ends at once (libc `_exit`), and its window with
/// it. Destroying the window starts the engine's teardown, during which
/// mpv's still-running players can call into Dart after the VM shut down
/// ("GetFfiCallbackMetadata called after shutdown") or a destructor
/// crashes, aborting the process with a core dump. [quitApp] has run the
/// exit hooks and written every save by then.
@visibleForTesting
Future<void> Function() closeApp = () async {
  if (PlatformInfo.isDesktop) {
    _endProcess();
  } else {
    await SystemNavigator.pop();
  }
};

/// Ends the process now, without destructors or atexit handlers.
void _endProcess() =>
    DynamicLibrary.process().lookupFunction<Void Function(Int32), void Function(int)>('_exit')(0);

/// Quits: runs [exitHooks], then [beforeClosing] (such as stopping
/// playback), then closes the app.
Future<void> quitApp({Future<void> Function()? beforeClosing}) async {
  await runExitHooks();
  await beforeClosing?.call();
  // A PC's process ends at once ([closeApp]): saves still being written
  // first. Android closes as it always has.
  if (PlatformInfo.isDesktop) await AppStorage.flushAll().timeout(exitHookTimeout, onTimeout: () {});
  await closeApp();
}

/// How long server mode's shutdown may take before it exits anyway, inside
/// Docker's 10 s grace period.
const serverStopDeadline = Duration(seconds: 9);

/// Server mode (design D9): on SIGTERM or SIGINT, runs [exitHooks] (Live TV
/// export stops its streams and ffmpeg), then [closeAll] (every profile's
/// state, flushed), then exits 0. Past [deadline] it exits 1 whatever is
/// still running.
StreamSubscription<ProcessSignal> watchServerSignals(Future<void> Function() closeAll,
    {Stream<ProcessSignal>? signals,
    void Function(int code) exitWith = exit,
    Duration deadline = serverStopDeadline}) {
  var stopping = false;
  return (signals ?? _stopSignals()).listen((signal) async {
    if (stopping) return;
    stopping = true;
    debugPrint('Stopping ($signal).');
    final late = Timer(deadline, () {
      debugPrint('Stopping took longer than ${deadline.inSeconds} s; exiting anyway.');
      exitWith(1);
    });
    try {
      await runExitHooks(timeout: serverExitHookTimeout);
      await closeAll();
    } on Object catch (e) {
      debugPrint('Error while stopping: $e');
    }
    late.cancel();
    exitWith(0);
  });
}

/// SIGTERM (`docker stop`) and SIGINT (Ctrl+C), as one stream.
Stream<ProcessSignal> _stopSignals() {
  final subs = <StreamSubscription<ProcessSignal>>[];
  late final StreamController<ProcessSignal> out;
  out = StreamController(
    onListen: () => subs.addAll([for (final s in [ProcessSignal.sigterm, ProcessSignal.sigint]) s.watch().listen(out.add)]),
    onCancel: () => Future.wait([for (final s in subs) s.cancel()]),
  );
  return out.stream;
}
