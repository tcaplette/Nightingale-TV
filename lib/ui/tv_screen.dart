import 'dart:async';
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_exit.dart';
import '../app_scope.dart';
import '../channels/break_notices.dart';
import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../library/library_index.dart';
import '../platform/orientation.dart';
import '../platform/platform_info.dart';
import '../playback/device_effects.dart';
import '../playback/playback_diagnostics.dart';
import '../playback/sleep_timer.dart';
import '../playback/tuner.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'guide_view.dart';
import 'menu_screen.dart';
import 'portrait_watch_screen.dart';
import 'captions_picker.dart';
import 'sleep_picker.dart';
import 'widgets/broadcast_cards.dart';
import 'widgets/channel_logo.dart';
import 'widgets/channel_logo_bug.dart';
import 'widgets/new_tag.dart';
import 'widgets/now_playing.dart';
import 'widgets/on_screen_clock.dart';
import 'widgets/overlay_style.dart';
import 'widgets/retro_frame.dart';
import 'widgets/screen_layout.dart';
import 'widgets/transport_bar.dart';
import 'widgets/tv_focus.dart';
import '../server/media_server.dart';
import '../l10n/tr.dart';

/// Main screen: full-screen TV with channel banner and number entry; the
/// guide opens on top of it.
class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  /// Android: shown after Back on the TV screen.
  static String get exitPrompt => tr.pressBackAgain;

  /// Shown once when curvature and glow turn off by themselves.
  static String get effectsFallback => tr.curvatureAndGlow;

  /// A media key on a live channel.
  static String get liveCantPause => tr.liveChannelsCant;

  /// Paused this long, the picture dims (timeshift D13).
  static const dimAfter = Duration(minutes: 10);

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  static const _bannerDuration = Duration(seconds: 5);
  static const _digitTimeout = Duration(milliseconds: 1600);
  static const _exitWindow = Duration(seconds: 3);

  final _focus = FocusNode(debugLabel: 'tv');
  bool _guideOpen = false;
  bool _banner = false;
  Timer? _bannerTimer;

  /// The on-screen button row (Guide, Menu, Sleep...) is up: it comes with
  /// the controls, not with a channel change (dpad-buttons D1). [_rowFocus]
  /// is the highlighted button, shared by the D-pad and the pointer.
  bool _buttons = false;
  int? _rowFocus;
  String _digits = '';
  Timer? _digitTimer;
  String? _toast;
  Timer? _toastTimer;

  /// Android: Back was pressed once; another within [_exitWindow] quits.
  Timer? _exitTimer;

  /// The transport bar is up (timeshift), and what the D-pad is on in it.
  bool _bar = false;
  TransportFocus _barFocus = TransportFocus.seekBar;

  /// When a skip key went down (holding it speeds up).
  DateTime _skipDown = DateTime.now();
  PointerDeviceKind? _tapKind;

  /// Paused for long: the picture is dimmed.
  bool _dimmed = false;
  Timer? _dimTimer;

  /// "12:34 behind" counting while behind.
  Timer? _shiftTick;
  bool _wasPaused = false;
  Tuner? _tuner;
  StreamSubscription<String>? _notices;

  /// The sleep timer; it woke the app while a settings screen was open, so
  /// the channel is tuned on the way back.
  SleepTimer? _sleep;
  bool _tuneOnReturn = false;

  /// The picture, kept the same widget in both layouts.
  final _pictureKey = GlobalKey(debugLabel: 'picture');
  final _watchKey = GlobalKey<PortraitWatchScreenState>();
  bool? _portrait;

  @override
  void initState() {
    super.initState();
    FullScreen.instance.addListener(_fullScreenChanged);
    DeviceEffects.instance.addListener(_effectsChanged);
    _effectsFellBack = DeviceEffects.instance.shaderTurnedOff;
    WidgetsBinding.instance.addPostFrameCallback((_) => _powerOn());
  }

  bool _effectsFellBack = false;

  void _effectsChanged() {
    if (_effectsFellBack || !DeviceEffects.instance.shaderTurnedOff || !mounted) return;
    _effectsFellBack = true;
    _showToast(TvScreen.effectsFallback);
  }

  /// [child] in the overlay theme of the channel on the air.
  Widget _themed(BuildContext context, Tuner tuner, Widget child) {
    final ch = tuner.channel;
    return OverlayThemeScope.of(
      retro: ch == null ? const ResolvedRetro() : AppScope.read(context).retroFor(ch),
      icon: ch?.icon,
      child: child,
    );
  }

  void _fullScreenChanged() {
    if (!mounted) return;
    // Into full screen: the banner shows what's on, with Exit full screen
    // beside Guide and Menu.
    if (FullScreen.instance.isOn) {
      _buttons = true;
      _showBanner();
    } else {
      // Exit full screen went from the row.
      setState(() {
        if (_rowFocus != null) _rowFocus = min(_rowFocus!, _rowButtons().length - 1);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sleep ??= AppScope.sleepOf(context)?..woke.addListener(_woke);
    final portrait = ScreenLayout.of(context).isPortrait;
    if (_portrait != null && _portrait != portrait) {
      // The focused control may have gone with the old layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
        if ((portrait || !_guideOpen) && !_focus.hasFocus) _focus.requestFocus();
      });
    }
    _portrait = portrait;
  }

  @override
  void dispose() {
    FullScreen.instance.removeListener(_fullScreenChanged);
    DeviceEffects.instance.removeListener(_effectsChanged);
    _bannerTimer?.cancel();
    _digitTimer?.cancel();
    _toastTimer?.cancel();
    _exitTimer?.cancel();
    _dimTimer?.cancel();
    _shiftTick?.cancel();
    _tuner?.removeListener(_tunerChanged);
    _sleep?.woke.removeListener(_woke);
    unawaited(_notices?.cancel());
    _focus.dispose();
    super.dispose();
  }

  /// Like turning on a TV: back to the last channel watched.
  void _powerOn() {
    PlaybackDiagnostics.mark('TV screen shown');
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    _tuner = tuner..addListener(_tunerChanged);
    _notices = tuner.notices.listen(_showToast);
    final channels = app.channels;
    if (channels.isEmpty) {
      setState(() => _guideOpen = true);
      return;
    }
    if (tuner.channel == null) {
      final last = channels.where((c) => c.id == app.settings.lastChannelId).firstOrNull;
      tuner.tune(last ?? channels.first);
    }
    _showChannel();
  }

  void _showBanner() {
    setState(() => _banner = true);
    _armBanner();
  }

  /// A channel change: the banner without the button row.
  void _showChannel() {
    _buttons = false;
    _rowFocus = null;
    _showBanner();
  }

  /// Woken from sleep: the channel slept on tunes again, now if the TV screen
  /// is showing, or when the viewer comes back to it.
  void _woke() {
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      _tuneOnReturn = true;
      return;
    }
    unawaited(_tuneAfterSleep());
  }

  Future<void> _tuneAfterSleep() async {
    _tuneOnReturn = false;
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    if (tuner.channel != null || app.channels.isEmpty) return;
    final id = _sleep?.sleptOn?.id ?? app.settings.lastChannelId;
    await tuner.tune(app.channels.where((c) => c.id == id).firstOrNull ?? app.channels.first);
    if (mounted && !_guideOpen) _showChannel();
  }

  /// The captions picker (the Captions button).
  Future<void> _openCaptions() async {
    _cancelExit();
    await showCaptionsPicker(context, AppScope.tunerOf(context));
    if (mounted && !_focus.hasFocus && (!_guideOpen || ScreenLayout.of(context).isPortrait)) _focus.requestFocus();
  }

  /// The sleep timer picker (S, the Sleep button).
  Future<void> _openSleep() async {
    final sleep = _sleep;
    if (sleep == null) return;
    _cancelExit();
    await showSleepPicker(context, sleep);
    if (mounted && !_focus.hasFocus && (!_guideOpen || ScreenLayout.of(context).isPortrait)) _focus.requestFocus();
  }

  /// The banner and the bar go after [_bannerDuration] with no input, but not
  /// with a seek pending.
  void _armBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer(_bannerDuration, () {
      if (!mounted) return;
      if (AppScope.tunerOf(context).seekTarget != null) {
        _armBanner();
      } else {
        setState(() {
          _banner = false;
          _bar = false;
          _buttons = false;
          _rowFocus = null;
        });
      }
    });
  }

  /// The banner and the button row, with the transport bar where there is
  /// one.
  void _showControls() {
    if (AppScope.tunerOf(context).canTimeshift && !_bar) {
      _bar = true;
      _barFocus = TransportFocus.seekBar;
    }
    _buttons = true;
    _showBanner();
  }

  void _closeBar() {
    _bannerTimer?.cancel();
    setState(() {
      _bar = false;
      _banner = false;
      _buttons = false;
      _rowFocus = null;
    });
  }

  /// Follows the tuner: the dim timer and the "behind" count, and the bar
  /// goes with the channel or the setting that allowed it.
  void _tunerChanged() {
    final tuner = _tuner;
    if (tuner == null || !mounted) return;
    if (tuner.paused != _wasPaused) {
      _wasPaused = tuner.paused;
      _wake();
    }
    if (tuner.shifted && _shiftTick == null) {
      _shiftTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!tuner.shifted) {
      _shiftTick?.cancel();
      _shiftTick = null;
    }
    if (_bar && !tuner.canTimeshift) setState(() => _bar = false);
  }

  /// A key or the pointer: the picture is back, and dims again later if
  /// still paused. True if it was dimmed.
  bool _wake() {
    final was = _dimmed;
    _dimTimer?.cancel();
    _dimTimer = null;
    if (was) setState(() => _dimmed = false);
    if (_tuner?.paused ?? false) {
      _dimTimer = Timer(TvScreen.dimAfter, () {
        if (mounted && (_tuner?.paused ?? false)) setState(() => _dimmed = true);
      });
    }
    return was;
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _surf(Future<void> Function() action) async {
    _digits = '';
    // A surf shows only the banner.
    _bar = false;
    await action();
    if (mounted) _showChannel();
  }

  void _typeDigit(int digit) {
    _digitTimer?.cancel();
    // Keep the last three digits typed, like a cable box.
    final typed = '$_digits$digit';
    setState(() => _digits = typed.length > 3 ? typed.substring(typed.length - 3) : typed);
    _digitTimer = Timer(_digitTimeout, _commitDigits);
  }

  Future<void> _commitDigits() async {
    _digitTimer?.cancel();
    final number = int.tryParse(_digits);
    setState(() => _digits = '');
    if (number == null) return;
    final ok = await AppScope.tunerOf(context).tuneNumber(number);
    if (!mounted) return;
    if (ok) {
      _bar = false;
      _showChannel();
    } else {
      _showToast(tr.thereIsNo(number));
    }
  }

  void _openGuide() => setState(() => _guideOpen = true);

  void _exitFullScreen() => unawaited(FullScreen.instance.exit());

  /// The portrait watch screen tunes without leaving.
  void _tuneFromList(Channel ch) {
    _cancelExit();
    final tuner = AppScope.tunerOf(context);
    _digits = '';
    if (tuner.channel?.id == ch.id) return;
    tuner.tune(ch);
    // The tuner takes the channel at once; the panel and highlight follow
    // before the picture does.
    setState(() {});
  }

  /// Android's Back on the TV screen: the first asks, the second quits.
  /// In full screen from portrait it leaves full screen instead.
  void _back() {
    if (_digits.isNotEmpty) {
      _digitTimer?.cancel();
      setState(() => _digits = '');
    } else if (FullScreen.instance.isOn && !ScreenLayout.of(context).isPortrait) {
      _exitFullScreen();
    } else if (_exitTimer?.isActive ?? false) {
      _exitTimer!.cancel();
      final tuner = AppScope.tunerOf(context);
      quitApp(beforeClosing: tuner.stop);
    } else {
      _showToast(TvScreen.exitPrompt);
      _exitTimer = Timer(_exitWindow, () {});
    }
  }

  /// Anything but a second Back cancels the exit prompt.
  void _cancelExit() {
    if (!(_exitTimer?.isActive ?? false)) return;
    _exitTimer!.cancel();
    if (_toast == TvScreen.exitPrompt) {
      _toastTimer?.cancel();
      setState(() => _toast = null);
    }
  }

  void _closeGuide() {
    setState(() => _guideOpen = false);
    _focus.requestFocus();
    _showChannel();
  }

  void _watch(Channel ch) {
    final tuner = AppScope.tunerOf(context);
    if (tuner.channel?.id != ch.id) tuner.tune(ch);
    _closeGuide();
  }

  Future<void> _openMenu() async {
    // A live stream holds a tuner or an IPTV connection: it's closed while
    // the full-screen settings are open, and tuned again after.
    final leftLive = AppScope.tunerOf(context).isLive ? AppScope.tunerOf(context).channel : null;
    if (leftLive != null) await AppScope.tunerOf(context).stop();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MenuScreen()));
    if (!mounted) return;
    // Channels may have been edited, hidden or renumbered.
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    if (leftLive != null && tuner.channel == null) {
      final back = app.channels.where((c) => c.id == leftLive.id).firstOrNull ?? app.channels.firstOrNull;
      if (back != null) await tuner.tune(back);
      if (!mounted) return;
    }
    if (_tuneOnReturn) {
      await _tuneAfterSleep();
      if (!mounted) return;
    }
    final current = tuner.channel;
    if (current != null && !app.channels.any((c) => c.id == current.id)) {
      if (app.channels.isNotEmpty) {
        await tuner.tune(app.channels.first);
      } else {
        await tuner.stop();
      }
    }
    if (!mounted) return;
    if (_guideOpen && !ScreenLayout.of(context).isPortrait) {
      setState(() {});
    } else {
      _focus.requestFocus();
    }
  }

  static int? _digitFor(LogicalKeyboardKey key) {
    const keys = [
      LogicalKeyboardKey.digit0, LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6, LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad0, LogicalKeyboardKey.numpad1, LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3, LogicalKeyboardKey.numpad4, LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6, LogicalKeyboardKey.numpad7, LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = keys.indexOf(key);
    if (i >= 0) return i;
    final n = numpad.indexOf(key);
    return n >= 0 ? n : null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final tuner = AppScope.tunerOf(context);
    final key = event.logicalKey;
    // A dimmed picture comes back, and the key does nothing else.
    if (_wake()) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.keyS) {
      if (event is KeyDownEvent) _openSleep();
      return KeyEventResult.handled;
    }
    // Before Android's Back, which leaves the row rather than the app.
    if (!ScreenLayout.of(context).isPortrait && _rowKey(key, event)) return KeyEventResult.handled;
    if (PlatformInfo.isAndroid) {
      // Back leaves the app, as Android expects (Escape from a keyboard
      // still opens the guide). Held down, it doesn't repeat into quitting.
      if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.browserBack) {
        if (event is KeyDownEvent) {
          if (_bar && !ScreenLayout.of(context).isPortrait) {
            _closeBar();
          } else {
            _back();
          }
        }
        return KeyEventResult.handled;
      }
      _cancelExit();
      if (ScreenLayout.of(context).isPortrait) {
        if (_mediaKey(key, event)) {
          _watchKey.currentState?.showControls();
          return KeyEventResult.handled;
        }
        return _onPortraitKey(key);
      }
      // The remote's own Guide and Last Channel buttons.
      if (key == LogicalKeyboardKey.guide) {
        _openGuide();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaLast) {
        _surf(tuner.lastChannel);
        return KeyEventResult.handled;
      }
    }
    final digit = _digitFor(key);
    if (digit != null) {
      _typeDigit(digit);
    } else if (_digits.isNotEmpty && isSelectKey(key)) {
      _commitDigits();
    } else if (_transportKey(key, event)) {
      // Done.
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.channelUp) {
      _surf(tuner.channelUp);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.channelDown) {
      _surf(tuner.channelDown);
    } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.keyL) {
      _surf(tuner.lastChannel);
    } else if (isSelectKey(key) ||
        key == LogicalKeyboardKey.keyG ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.goBack) {
      _openGuide();
    } else if (key == LogicalKeyboardKey.keyI ||
        key == LogicalKeyboardKey.info ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _buttons = true;
      _showBanner();
    } else if (key == LogicalKeyboardKey.keyC || key == LogicalKeyboardKey.closedCaptionToggle) {
      tuner.toggleCaptions().then(_showToast);
    } else if (key == LogicalKeyboardKey.keyM || key == LogicalKeyboardKey.contextMenu) {
      _openMenu();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// The on-screen button row, left to right.
  List<({String label, IconData icon, VoidCallback onPressed})> _rowButtons() => [
        (label: tr.guide2, icon: Icons.grid_view, onPressed: _openGuide),
        (label: tr.menu, icon: Icons.settings, onPressed: _openMenu),
        if (_sleep != null) (label: tr.sleep, icon: Icons.bedtime, onPressed: _openSleep),
        // After Sleep, so the D-pad paths to Menu and Sleep stay as they were.
        (label: captionsButtonLabel(AppScope.tunerOf(context)), icon: Icons.closed_caption, onPressed: _openCaptions),
        if (FullScreen.instance.isOn && !PlatformInfo.isTelevision)
          (label: tr.exitFullScreen, icon: Icons.fullscreen_exit, onPressed: _exitFullScreen),
      ];

  /// The D-pad on the on-screen button row (dpad-buttons D3). Up reaches it
  /// while it's up; on it, Left/Right move, Select presses, Down and Back
  /// leave. Tuning and media keys leave it and act as usual. True if [key]
  /// was handled here.
  bool _rowKey(LogicalKeyboardKey key, KeyEvent event) {
    if (!_buttons) return false;
    // Any key keeps the controls up.
    _armBanner();
    final at = _rowFocus;
    if (at == null) {
      // Up from the seek bar, or with only the banner and row up.
      if (key != LogicalKeyboardKey.arrowUp || (_bar && _barFocus != TransportFocus.seekBar)) return false;
      setState(() => _rowFocus = 0);
      return true;
    }
    final left = key == LogicalKeyboardKey.arrowLeft, right = key == LogicalKeyboardKey.arrowRight;
    if (left || right) {
      setState(() => _rowFocus = (at + (right ? 1 : -1)).clamp(0, _rowButtons().length - 1));
    } else if (isSelectKey(key)) {
      if (event is KeyDownEvent) _rowButtons()[at].onPressed();
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      setState(() {
        _rowFocus = null;
        if (_bar && key == LogicalKeyboardKey.arrowDown) _barFocus = TransportFocus.seekBar;
      });
    } else if (key == LogicalKeyboardKey.arrowUp) {
      // The top of the screen.
    } else {
      if (_leavesRow(key)) setState(() => _rowFocus = null);
      return false;
    }
    return true;
  }

  /// Tuning and media keys: they take the highlight off the row.
  static bool _leavesRow(LogicalKeyboardKey key) =>
      _digitFor(key) != null ||
      const [
        LogicalKeyboardKey.channelUp, LogicalKeyboardKey.channelDown,
        LogicalKeyboardKey.pageUp, LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.backspace, LogicalKeyboardKey.keyL, LogicalKeyboardKey.mediaLast,
        LogicalKeyboardKey.guide, LogicalKeyboardKey.keyG,
        LogicalKeyboardKey.mediaPlayPause, LogicalKeyboardKey.mediaPlay, LogicalKeyboardKey.mediaPause,
        LogicalKeyboardKey.mediaRewind, LogicalKeyboardKey.mediaFastForward, LogicalKeyboardKey.keyP,
      ].contains(key);

  /// Play/Pause, Play, Pause, Rewind, Fast-forward and the keyboard's P act
  /// at once. True if [key] was one of them and did something. With Pause and
  /// rewind off they do nothing.
  bool _mediaKey(LogicalKeyboardKey key, KeyEvent event) {
    final tuner = AppScope.tunerOf(context);
    final toggle = key == LogicalKeyboardKey.mediaPlayPause || key == LogicalKeyboardKey.keyP;
    final play = key == LogicalKeyboardKey.mediaPlay, pause = key == LogicalKeyboardKey.mediaPause;
    final rewind = key == LogicalKeyboardKey.mediaRewind, forward = key == LogicalKeyboardKey.mediaFastForward;
    if (!(toggle || play || pause || rewind || forward)) return false;
    if (!AppScope.read(context).settings.playback.pauseAndRewind) return false;
    if (tuner.channel?.isLive ?? false) {
      if (event is KeyDownEvent) _showToast(TvScreen.liveCantPause);
      return true;
    }
    if (rewind || forward) {
      _skip(forward, event);
    } else if (event is KeyDownEvent) {
      if (toggle) unawaited(tuner.togglePause());
      if (play) unawaited(tuner.resume());
      if (pause) unawaited(tuner.pause());
    }
    if (!ScreenLayout.of(context).isPortrait) _showControls();
    return true;
  }

  void _skip(bool forward, KeyEvent event) {
    final now = DateTime.now();
    if (event is KeyDownEvent) _skipDown = now;
    AppScope.tunerOf(context).skip(transportStep(forward: forward, heldFor: now.difference(_skipDown)));
  }

  /// The D-pad on the transport bar, and what opens it (timeshift D8). True
  /// if [key] was handled here.
  bool _transportKey(LogicalKeyboardKey key, KeyEvent event) {
    final tuner = AppScope.tunerOf(context);
    if (_mediaKey(key, event)) return true;
    if (!tuner.canTimeshift) return false;
    final left = key == LogicalKeyboardKey.arrowLeft, right = key == LogicalKeyboardKey.arrowRight;
    final select = isSelectKey(key), down = event is KeyDownEvent;
    if (!_bar) {
      if (left || right) {
        _showControls();
        return true;
      }
      // Select resumes while paused, and otherwise opens the guide.
      if (select && tuner.paused) {
        if (down) unawaited(tuner.resume());
        return true;
      }
      return false;
    }
    if (isBackKey(key)) {
      _closeBar();
      return true;
    }
    final up = key == LogicalKeyboardKey.arrowUp, below = key == LogicalKeyboardKey.arrowDown;
    if (!(left || right || select || up || below)) return false;
    if (_barFocus == TransportFocus.seekBar) {
      if (left || right) {
        _skip(right, event);
      } else if (select) {
        if (down) unawaited(tuner.togglePause());
      } else if (below) {
        setState(() => _barFocus = TransportFocus.restart);
      } else {
        // Up to the button row.
        setState(() {
          _buttons = true;
          _rowFocus = 0;
        });
      }
    } else if (left) {
      setState(() => _barFocus = TransportFocus.restart);
    } else if (right) {
      setState(() => _barFocus = TransportFocus.live);
    } else if (up) {
      setState(() => _barFocus = TransportFocus.seekBar);
    } else if (select && down) {
      unawaited(_barFocus == TransportFocus.restart ? tuner.restart() : tuner.goLive());
    }
    _showBanner();
    return true;
  }

  /// A tap on the picture. A touch shows the controls (or closes them), as
  /// video apps do, with the guide among them; a mouse click opens the guide.
  void _tapped() {
    _cancelExit();
    final touch = _tapKind == PointerDeviceKind.touch;
    if (!touch || !AppScope.read(context).settings.playback.pauseAndRewind) {
      _openGuide();
    } else if (_bar || (_banner && !AppScope.tunerOf(context).canTimeshift)) {
      _closeBar();
    } else {
      _showControls();
    }
  }

  /// The portrait watch screen: the channel keys and numbers tune as on the
  /// TV screen; the arrows and OK move through and pick from the list.
  KeyEventResult _onPortraitKey(LogicalKeyboardKey key) {
    final tuner = AppScope.tunerOf(context);
    final digit = _digitFor(key);
    if (digit != null) {
      _typeDigit(digit);
    } else if (_digits.isNotEmpty && isSelectKey(key)) {
      _commitDigits();
    } else if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.channelUp) {
      _surf(tuner.channelUp);
    } else if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.channelDown) {
      _surf(tuner.channelDown);
    } else if (key == LogicalKeyboardKey.mediaLast || key == LogicalKeyboardKey.keyL) {
      _surf(tuner.lastChannel);
    } else if (key == LogicalKeyboardKey.keyC || key == LogicalKeyboardKey.closedCaptionToggle) {
      tuner.toggleCaptions().then(_showToast);
    } else if (key == LogicalKeyboardKey.keyM || key == LogicalKeyboardKey.contextMenu) {
      _openMenu();
    } else if (key == LogicalKeyboardKey.escape) {
      // A keyboard's Escape is Back here: there's no guide to open.
      _back();
    } else if (FocusManager.instance.primaryFocus == _focus &&
        (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown || isSelectKey(key))) {
      // Nothing in the list has focus yet: start at the tuned channel.
      _watchKey.currentState?.focusTuned();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tuner = AppScope.tunerOf(context);
    if (ScreenLayout.of(context).isPortrait) {
      return Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: Listenable.merge([tuner, AppScope.read(context)]),
          builder: (context, _) => _themed(
            context,
            tuner,
            PortraitWatchScreen(
              key: _watchKey,
              picture: TvPicture(
                  key: _pictureKey,
                  dimmed: _dimmed,
                  // The player's channel number and Paused chip use its spot.
                  clockHidden: tuner.changingChannel || _digits.isNotEmpty || tuner.paused),
              numberEntry: tuner.changingChannel || _digits.isNotEmpty
                  ? (_digits.isNotEmpty ? '${_digits}_' : '${tuner.channel?.number ?? ''}')
                  : null,
              toast: _toast,
              onTune: _tuneFromList,
              onMenu: _openMenu,
              onCaptions: _openCaptions,
              onSleep: _sleep == null ? null : _openSleep,
              onFullScreen: () {
                _cancelExit();
                unawaited(FullScreen.instance.enter());
              },
              onTouch: () {
                _cancelExit();
                _wake();
              },
            ),
          ),
        ),
      );
    }
    if (_guideOpen) {
      return GuideView(
          onWatch: _watch, onClose: _closeGuide, onMenu: _openMenu, onSleep: _sleep == null ? null : _openSleep);
    }
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        // Moving the air mouse brings up the banner and the on-screen
        // Guide and Menu buttons, like waking a cable box.
        onHover: (_) {
          _wake();
          _showControls();
        },
        child: GestureDetector(
        onTapDown: (details) => _tapKind = details.kind,
        onTap: _tapped,
        onSecondaryTap: _openMenu,
        // Touch: long-press is right-click.
        onLongPress: PlatformInfo.isAndroid ? _openMenu : null,
        child: ColoredBox(
          color: Colors.black,
          child: ListenableBuilder(
            listenable: Listenable.merge([tuner, AppScope.read(context), ?_sleep]),
            builder: (context, _) => _themed(context, tuner, Stack(
              fit: StackFit.expand,
              children: [
                TvPicture(
                    key: _pictureKey,
                    bannerUp: _banner,
                    dimmed: _dimmed,
                    // The channel number and the Paused chip use its spot.
                    clockHidden: tuner.changingChannel || _digits.isNotEmpty || tuner.paused),
                if (tuner.changingChannel || _digits.isNotEmpty)
                  Positioned(
                    top: 60,
                    right: 90,
                    child: ChannelNumberOsd(
                        text: _digits.isNotEmpty ? '${_digits}_' : '${tuner.channel?.number ?? ''}'),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  // The transport bar takes its place.
                  bottom: _banner && !_bar && tuner.channel != null ? 0 : -260,
                  child: tuner.channel == null
                      ? const SizedBox.shrink()
                      : ChannelBanner(
                          channel: tuner.channel!,
                          program: tuner.program,
                          inBreak: tuner.inBreak,
                          next: tuner.program == null
                              ? null
                              : tuner.schedule?.next(tuner.program!),
                          backOnAir: tuner.program?.isOffAir ?? false ? _backOnAir(context, tuner)?.when : null,
                          viewTime: tuner.viewNow(),
                          behind: tuner.shifted ? tuner.behind : null,
                          sleep: sleepLine(_sleep),
                        ),
                ),
                if (_bar && tuner.canTimeshift)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: TransportBar(
                        tuner: tuner, focused: _rowFocus == null ? _barFocus : null, onInteract: _showBanner),
                  ),
                if (tuner.paused && !_bar && _digits.isEmpty && !tuner.changingChannel)
                  const Positioned(top: 60, right: 90, child: PausedChip()),
                if (_toast != null)
                  Positioned(top: 60, left: 0, right: 0, child: Center(child: TvToast(_toast!))),
                Positioned(
                  top: 48,
                  left: 60,
                  child: IgnorePointer(
                    ignoring: !_buttons,
                    child: AnimatedOpacity(
                      opacity: _buttons ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Row(
                        children: [
                          for (final (i, b) in _rowButtons().indexed) ...[
                            if (i > 0) const SizedBox(width: 16),
                            TvPointerButton(
                              label: b.label,
                              icon: b.icon,
                              highlighted: _rowFocus == i,
                              onHover: () => setState(() => _rowFocus = i),
                              onPressed: b.onPressed,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )),
          ),
        ),
      ),
      ),
    );
  }
}

/// The picture: the video, the song card, the status cards, the logo bug,
/// the Up next card, break notices and the on-screen clock, in the channel's
/// frame on the 1920×1080 canvas. The TV screen draws its banner and buttons over it; the portrait
/// watch screen shows it in its player. One [GlobalKey] keeps it (and the video)
/// the same widget when the layout changes.
class TvPicture extends StatelessWidget {
  const TvPicture({super.key, this.bannerUp = false, this.dimmed = false, this.clockHidden = false});

  /// The channel banner is up: the logo bug, Up next card, break notices
  /// and the clock make way.
  final bool bannerUp;

  /// The channel number or the Paused chip is in the clock's corner.
  final bool clockHidden;

  /// Paused for long (timeshift D13): the picture shows at 30%.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final tuner = AppScope.tunerOf(context);
    final sleep = AppScope.sleepOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([tuner, AppScope.read(context), ?sleep]),
      builder: (context, _) {
        final app = AppScope.read(context), on = tuner.channel;
        final retro = on == null ? const ResolvedRetro() : app.retroFor(on);
        return RetroFrame(
          retro: retro,
          icon: on?.icon,
          app: app,
          child: Stack(
        fit: StackFit.expand,
        children: [
          tuner.media.buildVideo(fit: RetroFrame.fitFor(retro.shape)),
          // A song has no picture of its own.
          if (tuner.channel case final ch? when tuner.status == TunerStatus.playing)
            if (tuner.segment?.item case final song? when song.kind == MediaKind.song)
              Positioned.fill(
                child: _CanvasCard(
                  child: NowPlayingCard(
                    channel: ch,
                    song: tuner.program!,
                    next: tuner.schedule?.next(tuner.program!),
                    art: albumArt(AppScope.read(context), song),
                    clock: tuner.viewNow,
                  ),
                ),
              ),
          if (tuner.isLive && tuner.status == TunerStatus.standby)
            _CanvasCard(child: StatusCard(icon: Icons.sensors, title: tr.pleaseStandBy, message: tuner.liveMessage))
          else if (tuner.status == TunerStatus.standby)
            _CanvasCard(
              child: StatusCard(
                icon: Icons.schedule,
                title: tr.pleaseStandBy,
                message: tuner.program == null
                    ? null
                    : tr.upNextAt(formatTime((tuner.segment ?? tuner.program!).end.add(tuner.behind))),
              ),
            ),
          if (tuner.channel case final ch? when tuner.status == TunerStatus.offAir && tuner.segment?.offline == true)
            _CanvasCard(child: offlineCardFor(AppScope.read(context), ch, backAt: tuner.segment!.end))
          else if (tuner.status == TunerStatus.offAir)
            _CanvasCard(
              child: StatusCard(
                icon: Icons.tv_off,
                title: tr.offTheAir,
                message: switch (_backOnAir(context, tuner)) {
                  final b? => tr.backOnThe(b.when, b.title),
                  null => tuner.error,
                },
              ),
            ),
          if (tuner.isLive && tuner.status == TunerStatus.error)
            _CanvasCard(
              child: StatusCard(
                icon: Icons.signal_cellular_connected_no_internet_0_bar,
                title: tr.noSignal,
                message: tuner.liveMessage ?? tuner.error,
              ),
            )
          else if (tuner.status == TunerStatus.error)
            _CanvasCard(
              child: StatusCard(
                icon: Icons.signal_cellular_connected_no_internet_0_bar,
                title: tr.noSignal,
                message: [
                  if (tuner.error != null) tuner.error!,
                  if (tuner.program != null)
                    tr.tryingAgainAt(formatTime((tuner.segment ?? tuner.program!).end)),
                ].join('\n'),
              ),
            ),
          if (tuner.channel case final ch? when tuner.status == TunerStatus.playing)
            ChannelLogoBug(
              icon: ch.icon,
              mode: AppScope.read(context).logoModeFor(ch),
              segment: tuner.segment,
              hidden: bannerUp,
              blackouts: [?_upNextWindowOf(context, tuner)],
              fallbackText: ch.displayName,
              clock: tuner.viewNow,
            ),
          if ((tuner.status == TunerStatus.playing ? tuner.schedule : null)
              case final schedule? when tuner.program != null && tuner.segment != null)
            Positioned(
              right: 90,
              bottom: 70,
              child: UpNextCard(
                program: tuner.program!,
                segment: tuner.segment!,
                next: schedule.next(tuner.program!),
                lastPart: schedule.isLastPart(tuner.program!, tuner.segment!),
                hidden: bannerUp,
                clock: tuner.viewNow,
              ),
            ),
          if (tuner.channel case final ch? when tuner.status == TunerStatus.playing)
            // The setting can change while the TV is under the Playback
            // screen.
            ListenableBuilder(
              listenable: AppScope.read(context),
              builder: (context, _) => switch (AppScope.read(context)) {
                final app when app.settings.playback.breakNotices => switch (tuner.schedule) {
                    final schedule? => Positioned(
                        left: 90,
                        bottom: 70,
                        child: BreakNoticeCard(
                          key: ValueKey(ch.id),
                          schedule: schedule,
                          hidden: bannerUp,
                          clock: tuner.pictureNow,
                          onShown: tuner.noteBreakNotice,
                        ),
                      ),
                    null => const SizedBox.shrink(),
                  },
                _ => const SizedBox.shrink(),
              },
            ),
          // Broadcast-style, in the title-safe corner (on-screen-clock spec).
          if (app.settings.playback.onScreenClock)
            Positioned(
              top: 60,
              right: 90,
              child: OnScreenClock(
                visible: on != null && tuner.status != TunerStatus.idle && !bannerUp && !clockHidden,
                sleeping: sleep?.armed ?? false,
              ),
            ),
          if (dimmed) const IgnorePointer(child: ColoredBox(color: Color(0xB3000000))),
        ],
      ),
        );
      },
    );
  }
}

/// A full-screen card, built for the 1920×1080 canvas, scaled to fit the frame
/// it's in without being cropped (design D5).
class _CanvasCard extends StatelessWidget {
  const _CanvasCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox.fromSize(
        size: ScreenLayout.tvCanvas,
        child: MediaQuery(data: MediaQuery.of(context).copyWith(size: ScreenLayout.tvCanvas), child: child),
      ),
    );
  }
}

/// When an off-air channel's next block starts: "SAT DEC 5 7:00 AM", or
/// just the time if it's within the day.
({String when, String title})? _backOnAir(BuildContext context, Tuner tuner) {
  final ch = tuner.channel;
  if (ch == null) return null;
  final now = tuner.viewNow();
  final next = tuner.schedule?.nextBlockAiring(now);
  if (next == null) return null;
  final when = next.start.difference(now) < const Duration(hours: 20)
      ? formatTime(next.start)
      : '${formatDate(next.start)} ${formatTime(next.start)}';
  return (when: when, title: next.title);
}

/// [ch]'s offline card on the TV: its chosen image, or its logo and name.
Widget offlineCardFor(AppState app, Channel ch, {DateTime? backAt}) {
  final name = ch.slotRule?.offlineImage;
  final file = name == null ? null : app.icons.fileFor(name);
  return OfflineCard(
    channel: ch,
    image: file == null
        ? null
        : name!.endsWith('.svg')
            ? SvgPicture.file(file, fit: BoxFit.contain)
            : Image.file(file, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
    logo: ChannelLogo(icon: ch.icon, size: 300, width: 520, fallbackText: ch.displayName, app: app),
    backAt: backAt,
  );
}

/// [song]'s art from Jellyfin: its album's image, then its own.
List<ImageProvider> albumArt(AppState app, MediaEntry song) {
  return [
    for (final id in [?song.albumId, song.id])
      // The server the id is on (multi-server).
      if (app.clientOf(id) case final client?)
        NetworkImage(client.imageUri(id, ImageKind.primary, maxHeight: 640).toString(), headers: client.authHeaders),
  ];
}

/// When the Up next card is up during what [tuner] plays, if it comes up.
({DateTime from, DateTime to})? _upNextWindowOf(BuildContext context, Tuner tuner) {
  final ch = tuner.channel, program = tuner.program, segment = tuner.segment;
  if (ch == null || program == null || segment == null) return null;
  final schedule = tuner.schedule;
  if (schedule == null) return null;
  return upNextWindow(program, segment, schedule.next(program), lastPart: schedule.isLastPart(program, segment));
}

/// What the banner says during a break.
String get commercialBreakLabel => tr.commercialBreak;

/// A live channel's own number at its source ("2.1"), when it isn't its
/// lineup number.
String? liveNumber(Channel ch) => switch (ch.live?.sourceNumber) {
      final n? when n != '${ch.number}' => n,
      _ => null,
    };

/// The bottom banner: the channel, what's on, and what's next.
class ChannelBanner extends StatelessWidget {
  const ChannelBanner(
      {super.key,
      required this.channel,
      required this.program,
      required this.next,
      this.inBreak = false,
      this.backOnAir,
      this.viewTime,
      this.behind,
      this.sleep});

  final Channel channel;
  final ScheduledProgram? program;

  /// A commercial break in [program] is on.
  final bool inBreak;
  final ScheduledProgram? next;

  /// When the channel comes back, shown instead of "Next" while it's off
  /// the air.
  final String? backOnAir;

  /// The schedule's time for what's on screen (timeshift); the clock if null.
  final DateTime? viewTime;

  /// How far behind the schedule the viewer is, if they are.
  final Duration? behind;

  /// The sleep timer's line, while one is set (design D3).
  final String? sleep;

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final clock = DateTime.now();
    final now = viewTime ?? clock;
    final p = program;
    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(90, 28, 90, 40),
      decoration: g.banner,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: g.numberTile,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(g.number('${channel.number}'), style: g.display(84, weight: FontWeight.w800, color: g.numberOnTile)),
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    [
                      [channel.displayName, ?liveNumber(channel)].join('  '),
                      if (p?.displayBlockTitle != null) p!.displayBlockTitle!,
                    ].join('   ·   ').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.display(28, weight: FontWeight.w700, color: g.accent)),
                Row(
                  children: [
                    if (channel.isLive) ...[const LiveTag(size: 32), const SizedBox(width: 18)],
                    if (p?.isPremiere ?? false) ...[const NewTag(size: 32), const SizedBox(width: 18)],
                    Expanded(
                      child: Text(p?.title ?? tr.tuning2,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(60, weight: FontWeight.w800)),
                    ),
                  ],
                ),
                if (p != null)
                  Text(
                      [
                        inBreak ? commercialBreakLabel : p.subtitle,
                        formatRange(p.start, p.end),
                        if (p.endsEarly) endsEarlyLabel,
                      ].join('   ·   '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: inBreak ? g.body(26, weight: FontWeight.w600, color: g.accent) : g.body(26, color: g.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 32),
          if (p != null)
            SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Behind and the sleep line share a line when both show.
                  if (behind != null || sleep != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (behind case final b?)
                            Text(formatBehind(b), style: g.display(26, weight: FontWeight.w700, color: g.accent)),
                          if (behind != null && sleep != null) const SizedBox(width: 20),
                          if (sleep case final line?) ...[
                            Icon(Icons.bedtime, size: 26, color: g.accent),
                            const SizedBox(width: 8),
                            Text(line, style: g.display(26, weight: FontWeight.w700, color: g.accent)),
                          ],
                        ],
                      ),
                    ),
                  Text(formatTime(clock), style: g.display(44, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (!p.isOffAir) ...[
                    LinearProgressIndicator(
                      value: p.offsetAt(now).inSeconds / p.duration.inSeconds.clamp(1, 1 << 30),
                      minHeight: 8,
                      color: g.accent,
                      backgroundColor: g.progressTrack,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    p.isOffAir
                        ? (backOnAir == null ? tr.offTheAir2 : tr.backOn(backOnAir!))
                        : next == null
                            ? tr.left(formatMinutes(p.end.difference(now)))
                            : tr.next2(formatTime(next!.start), next!.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.body(24, color: g.textDim),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// When the "Up next" card is up during [segment] of [program]: from a
/// minute before the show ends, for 15 seconds, in the part it ends in
/// ([lastPart]: its last one, or the one a programming block cuts off).
/// Null when there's nothing to announce.
({DateTime from, DateTime to})? upNextWindow(
    ScheduledProgram program, ScheduledProgram segment, ScheduledProgram? next, {required bool lastPart}) {
  final item = program.item;
  if (item == null || next == null || next.isOffAir || segment.isBreak || segment.item?.id != item.id) return null;
  if (item.runtime < UpNextCard.minRuntime || item.isMusic || !lastPart) return null;
  final from = segment.end.subtract(UpNextCard.lead);
  return (from: from, to: from.add(UpNextCard.showFor));
}

/// The "Up next" card that slides in near the end of a show, like a cable
/// network's end-credits promo. When the next program starts a programming
/// block, it announces the block.
class UpNextCard extends StatefulWidget {
  const UpNextCard(
      {super.key,
      required this.program,
      required this.segment,
      required this.next,
      required this.lastPart,
      required this.hidden,
      this.clock = DateTime.now});

  /// When it comes up: this long before the show ends…
  static const lead = Duration(seconds: 60);

  /// …for this long.
  static const showFor = Duration(seconds: 15);

  /// Too short a program to interrupt (cartoon shorts, music videos).
  static const minRuntime = Duration(minutes: 5);

  final ScheduledProgram program;

  /// What's playing: the program, a part of it, or a break.
  final ScheduledProgram segment;
  final ScheduledProgram? next;

  /// [segment] is the last of the show to air.
  final bool lastPart;

  /// The channel banner is up, and already says what's next.
  final bool hidden;
  final DateTime Function() clock;

  @override
  State<UpNextCard> createState() => _UpNextCardState();
}

class _UpNextCardState extends State<UpNextCard> {
  late final Timer _tick;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _check();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void didUpdateWidget(UpNextCard old) {
    super.didUpdateWidget(old);
    _check();
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _check() {
    final w = upNextWindow(widget.program, widget.segment, widget.next, lastPart: widget.lastPart);
    final now = widget.clock();
    final visible = w != null && !widget.hidden && !now.isBefore(w.from) && now.isBefore(w.to);
    if (visible != _visible && mounted) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final n = widget.next;
    final block = n?.blockTitle != null && n!.blockTitle != widget.program.blockTitle ? n.displayBlockTitle : null;
    return IgnorePointer(
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(1.3, 0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: n == null
              ? const SizedBox.shrink()
              : Container(
                  width: 560,
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                  decoration: g.panel,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.upNext2(formatTime(n.start)),
                          style: g.display(24, weight: FontWeight.w800, color: g.accent)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (n.isPremiere) ...[const NewTag(size: 24), const SizedBox(width: 14)],
                          Expanded(
                            child: Text(block ?? n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: g.display(40, weight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      Text(
                        block != null ? tr.startingWith(n.title) : n.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: g.body(24, color: g.textDim),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// The break notice on at [now], as its headline and second line (D4).
({String headline, String? detail}) breakNoticeText(BreakNotice notice, DateTime now) {
  final left = (notice.at.difference(now).inMicroseconds / Duration.microsecondsPerSecond).ceil().clamp(1, 1 << 30);
  switch (notice.kind) {
    case BreakNoticeKind.breakStarts:
      return (headline: tr.inLabel(commercialBreakLabel, left), detail: null);
    case BreakNoticeKind.resumes:
      final r = notice.resumes;
      return (
        headline: tr.programmingResumesIn(left),
        detail: r == null
            ? null
            : notice.continues
                ? tr.backTo(r.title)
                : tr.upNext(notice.opensBlock ?? r.title),
      );
  }
}

/// The corner card that counts down to a commercial break, and to the
/// program coming back after one (break-notices spec), worked out from
/// [schedule] and the clock. Display only: it never takes focus or a tap.
class BreakNoticeCard extends StatefulWidget {
  const BreakNoticeCard(
      {super.key, required this.schedule, required this.hidden, this.clock = DateTime.now, this.onShown});

  /// How long before a break it counts down…
  static const breakLead = breakNoticeLead;

  /// …and before the program comes back.
  static const resumeLead = resumeNoticeLead;

  final ProgramSchedule schedule;

  /// The channel banner is up, and already says "Commercial break".
  final bool hidden;
  final DateTime Function() clock;

  /// A notice came up, counting down to a cut (diagnostics).
  final void Function(BreakNoticeKind kind, DateTime at)? onShown;

  @override
  State<BreakNoticeCard> createState() => _BreakNoticeCardState();
}

class _BreakNoticeCardState extends State<BreakNoticeCard> {
  Timer? _timer;
  BreakNotice? _notice;

  /// What it says now; kept as it slides out.
  ({String headline, String? detail})? _text;

  /// What screen readers announce: the text it came up with.
  String? _announced;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(BreakNoticeCard old) {
    super.didUpdateWidget(old);
    if (old.hidden != widget.hidden || old.schedule != widget.schedule) _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Shows the notice on now, and wakes up when its number next changes,
  /// or at the next whole second (sooner if a notice starts before then).
  void _check() {
    _timer?.cancel();
    final now = widget.clock();
    final notice = widget.hidden ? null : breakNoticeAt(widget.schedule, now);
    final text = notice == null ? _text : breakNoticeText(notice, now);
    final shown = _notice;
    final appears = notice != null && (shown == null || shown.at != notice.at || shown.kind != notice.kind);
    if (appears) widget.onShown?.call(notice.kind, notice.at);
    if (mounted && (notice != _notice || text != _text)) {
      setState(() {
        _notice = notice;
        _text = text;
        if (appears) _announced = [text!.headline, ?text.detail].join('. ');
      });
    }
    const second = Duration(seconds: 1);
    Duration wait;
    if (notice != null) {
      final rest = notice.at.difference(now).inMicroseconds % second.inMicroseconds;
      wait = Duration(microseconds: rest == 0 ? second.inMicroseconds : rest);
    } else {
      wait = Duration(microseconds: second.inMicroseconds - now.microsecondsSinceEpoch % second.inMicroseconds);
      final soon = widget.hidden ? null : breakNoticeAt(widget.schedule, now.add(second));
      if (soon != null) {
        final lead = soon.kind == BreakNoticeKind.breakStarts ? BreakNoticeCard.breakLead : BreakNoticeCard.resumeLead;
        final from = soon.at.subtract(lead).difference(now);
        if (from > Duration.zero && from < wait) wait = from;
      }
    }
    // Just past the change, so the number has moved on.
    _timer = Timer(wait + const Duration(milliseconds: 1), _check);
  }

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final visible = _notice != null;
    final text = _text;
    return IgnorePointer(
      child: ExcludeFocus(
        child: Semantics(
          liveRegion: visible,
          label: visible ? _announced : null,
          child: ExcludeSemantics(
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(-1.3, 0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: text == null
                    ? const SizedBox.shrink()
                    : Container(
                        width: 560,
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                        decoration: g.panel,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text.headline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: g.display(40, weight: FontWeight.w800)),
                            if (text.detail case final detail?)
                              Text(detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: g.body(24, color: g.textDim)),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short message over the picture ("There is no channel 99").
class TvToast extends StatelessWidget {
  const TvToast(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
      decoration: BoxDecoration(
        color: g.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(g.radius * 2),
        border: Border.all(color: g.accent, width: 2),
      ),
      child: Text(message, style: g.display(36, weight: FontWeight.w600)),
    );
  }
}
