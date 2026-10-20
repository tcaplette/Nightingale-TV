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
import 'channels/channel.dart';
import 'channels/slot_layout.dart';
import 'data/app_storage.dart';
import 'export/broadcast_art.dart';
import 'export/export_service.dart';
import 'platform/android_back_bridge.dart';
import 'platform/platform_info.dart';
import 'playback/playback_diagnostics.dart';
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
  PlaybackDiagnostics.mark('main');
  if (PlaybackDiagnostics.enabled) SlotLayout.log = (line) => PlaybackDiagnostics.note('BREAKFILL', line);
  WidgetsFlutterBinding.ensureInitialized();
  // mpv plays everywhere but Android, which has ExoPlayer and no libmpv
  // (by the real OS, as TunerPlayer.create chooses).
  if (!Platform.isAndroid) MediaKit.ensureInitialized();
  await PlatformInfo.init();
  if (PlatformInfo.isDesktop) {
    await _setUpWindow();
  } else if (PlatformInfo.isAndroid) {
    // Like a TV: the whole screen, sideways on phones.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    // TVs have a remote and maybe an air mouse, never touch: focus always
    // shows, and pointing at a button focuses it (Flutter's automatic mode
    // would treat an Android device as touch until a key is pressed).
    if (PlatformInfo.isTelevision) FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    // Before runApp, so it sees Back before the Navigator does.
    WidgetsBinding.instance.addObserver(AndroidBackBridge());
  }

  PlaybackDiagnostics.mark('platform ready');
  final household = Household(await AppStorage.open());
  PlaybackDiagnostics.mark('storage open');
  final remote = household.remote = RemoteControl(household, wake: PlatformInfo.isDesktop ? _wakeWindow : null);
  if (PlatformInfo.isDesktop) {
    HardwareKeyboard.instance.addHandler((event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
        windowManager.isFullScreen().then((full) => windowManager.setFullScreen(!full));
        return true;
      }
      return false;
    });
  } else if (PlatformInfo.isAndroid) {
    // Android may keep the process after the app closes; the remote's port
    // mustn't stay open.
    exitHooks.add(remote.stop);
    watchRemoteLifecycle(remote);
  }

  runApp(NightingaleTvApp(household: household));
  await household.start();
  PlaybackDiagnostics.mark('profile started');
  await remote.load();
  await startExport(household);
  PlaybackDiagnostics.mark('remote and export loaded');
}

/// Sets up Live TV export, which needs ffmpeg and an always-on PC: on
/// desktop only. On Android there's no export service at all, whatever an
/// `export.json` says.
@visibleForTesting
Future<void> startExport(Household household, {Future<Directory> Function() cacheDir = getApplicationCacheDirectory}) async {
  if (!PlatformInfo.isDesktop) return;
  // Live TV export: its cards and logos are a cache, not settings.
  final cache = await cacheDir();
  final export = household.export =
      ExportService(household, art: BroadcastArt(Directory('${cache.path}/live_tv_export')));
  exitHooks.add(export.stop);
  await export.load();
}

/// Android: the phone remote's port is closed while the app is in the
/// background, and opens again (if it's on) when the app is back in front.
/// Null elsewhere.
@visibleForTesting
AppLifecycleListener? watchRemoteLifecycle(RemoteControl remote) =>
    PlatformInfo.isAndroid ? AppLifecycleListener(onHide: remote.stop, onShow: remote.resume) : null;

/// Full screen (or a window), and closing it through [quitApp].
Future<void> _setUpWindow() async {
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
}

/// A phone button should reach the TV even if another window has focus.
Future<void> _wakeWindow() async {
  if (!await windowManager.isFocused()) {
    await windowManager.show();
    await windowManager.focus();
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

/// Runs [exitHooks] before the window closes.
class _CloseHandler with WindowListener {
  @override
  void onWindowClose() => unawaited(quitApp());
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
        onNavigationNotification: PlatformInfo.isAndroid ? AndroidBackBridge.alwaysHandleBack : null,
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

  /// Android: stops playback in the background and tunes back in on return.
  AppLifecycleListener? _lifecycle;
  Future<void>? _hiding;
  Channel? _hiddenChannel;

  @override
  void initState() {
    super.initState();
    _remote?.tuner = _tuner;
    exitHooks.add(_tuner.stopTranscodeForExit);
    // Viewings left behind are reported after the next picture; quitting
    // sends them at once.
    exitHooks.add(_tuner.flushReports);
    if (PlatformInfo.isAndroid) _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
  }

  /// Out of sight (Home, another app, screen off): nothing plays, transcodes
  /// or reports, since Android may end the process at any time from here.
  void _onHide() {
    _hiddenChannel ??= _tuner.channel;
    _hiding = () async {
      await _tuner.stopTranscodeForExit();
      await _tuner.stop();
    }();
  }

  /// Back in front: the same channel, at what's airing now.
  Future<void> _onShow() async {
    await _hiding;
    final channel = _hiddenChannel;
    _hiddenChannel = null;
    if (channel != null && mounted && _tuner.channel == null) await _tuner.tune(channel);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    exitHooks.remove(_tuner.stopTranscodeForExit);
    exitHooks.remove(_tuner.flushReports);
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
