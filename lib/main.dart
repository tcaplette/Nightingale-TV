import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app_exit.dart';
import 'app_scope.dart';
import 'app_state.dart';
import 'data/app_storage.dart';
import 'export/broadcast_art.dart';
import 'export/export_service.dart';
import 'playback/tuner.dart';
import 'profiles/household.dart';
import 'remote/remote_control.dart';
import 'theme/tv_theme.dart';
import 'ui/login_screen.dart';
import 'ui/profiles_screen.dart';
import 'ui/sync_screen.dart';
import 'ui/tv_screen.dart';
import 'ui/widgets/tv_canvas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  // NIGHTINGALE_TV_WINDOWED=1 runs in a window (handy for development).
  final windowed = Platform.environment['NIGHTINGALE_TV_WINDOWED'] == '1';
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Nightingale TV',
      size: Size(1280, 720),
      minimumSize: Size(640, 360),
      center: true,
      backgroundColor: Colors.black,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
      if (!windowed) await windowManager.setFullScreen(true);
    },
  );

  // Closing the window first stops anything the app started on the server.
  windowManager.addListener(_CloseHandler());
  await windowManager.setPreventClose(true);

  final household = Household(await AppStorage.open());
  household.remote = RemoteControl(household, wake: () async {
    // A phone button should reach the TV even if another window has focus.
    if (!await windowManager.isFocused()) {
      await windowManager.show();
      await windowManager.focus();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  });
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      windowManager.isFullScreen().then((full) => windowManager.setFullScreen(!full));
      return true;
    }
    return false;
  });

  runApp(NightingaleTvApp(household: household));
  await household.start();
  await household.remote!.load();
  // Live TV export: its cards and logos are a cache, not settings.
  final cache = await getApplicationCacheDirectory();
  final export = household.export =
      ExportService(household, art: BroadcastArt(Directory('${cache.path}/live_tv_export')));
  exitHooks.add(export.stop);
  await export.load();
}

/// Runs [exitHooks] before the window closes.
class _CloseHandler with WindowListener {
  @override
  void onWindowClose() => unawaited(() async {
        await runExitHooks();
        await windowManager.destroy();
      }());
}

class NightingaleTvApp extends StatelessWidget {
  const NightingaleTvApp({super.key, required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
    return HouseholdScope(
      household: household,
      child: ListenableBuilder(
        listenable: household,
        builder: (context, _) {
          final app = household.app;
          if (app == null) {
            return _shell(household.started ? const ProfilePickerScreen() : const ColoredBox(color: Colors.black));
          }
          // A new session (and screen stack) per profile.
          return ProfileSession(key: ObjectKey(app), app: app, child: _shell(const _Root()));
        },
      ),
    );
  }

  static Widget _shell(Widget home) => MaterialApp(
        title: 'Nightingale TV',
        debugShowCheckedModeBanner: false,
        theme: GuideTheme.cableGuide.toThemeData(),
        builder: (context, child) => TvCanvas(child: AutoHidePointer(child: child!)),
        home: home,
      );
}

/// Owns the [Tuner] for one profile's [AppState] while it's watching.
class ProfileSession extends StatefulWidget {
  const ProfileSession({super.key, required this.app, required this.child});

  final AppState app;
  final Widget child;

  @override
  State<ProfileSession> createState() => _ProfileSessionState();
}

class _ProfileSessionState extends State<ProfileSession> {
  late final Tuner _tuner = Tuner(widget.app);
  late final RemoteControl? _remote = HouseholdScope.read(context).remote;

  @override
  void initState() {
    super.initState();
    _remote?.tuner = _tuner;
    exitHooks.add(_tuner.stopTranscodeForExit);
  }

  @override
  void dispose() {
    exitHooks.remove(_tuner.stopTranscodeForExit);
    if (_remote?.tuner == _tuner) _remote?.tuner = null;
    final tuner = _tuner;
    tuner.stop().whenComplete(tuner.dispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(app: widget.app, tuner: _tuner, child: widget.child);
}

/// Picks the screen for the app's current phase.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return switch (app.phase) {
      AppPhase.starting => const ColoredBox(color: Colors.black),
      AppPhase.signedOut => LoginScreen(key: const ValueKey('login'), message: app.syncError),
      AppPhase.syncing => const SyncScreen(),
      AppPhase.ready => const TvScreen(),
    };
  }
}
