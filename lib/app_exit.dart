import 'dart:async';

/// Run (briefly) before the app quits, e.g. to stop a transcode job on the
/// server.
final exitHooks = <Future<void> Function()>{};

/// How long quitting may wait for [exitHooks].
const exitHookTimeout = Duration(seconds: 3);

/// Runs every [exitHooks] at once, giving up after [exitHookTimeout].
Future<void> runExitHooks() async {
  await Future.wait([for (final hook in exitHooks) hook()]).timeout(exitHookTimeout, onTimeout: () => const []);
}
