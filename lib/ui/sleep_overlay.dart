import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../playback/sleep_timer.dart';
import '../remote/key_dispatch.dart';
import '../theme/tv_theme.dart';

/// The sleep timer over every screen (sleep-timer spec, design D4, D5): its
/// toasts, the last-minute warning, and the sleep screen. In the warning, the
/// fade and asleep it takes all input, so that input does nothing else: a key
/// (Android Back included) or a pointer move, click or tap turns the timer
/// off, or wakes the app. Otherwise input goes to the screens as usual.
class SleepOverlay extends StatefulWidget {
  const SleepOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SleepOverlay> createState() => _SleepOverlayState();
}

class _SleepOverlayState extends State<SleepOverlay> {
  SleepTimer? _timer;
  StreamSubscription<String>? _messages;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
    interceptKey = _onDispatched;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timer = AppScope.sleepOf(context);
    if (identical(timer, _timer)) return;
    _timer?.removeListener(_changed);
    unawaited(_messages?.cancel());
    _timer = timer?..addListener(_changed);
    _messages = timer?.messages.listen(_showToast);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    if (interceptKey == _onDispatched) interceptKey = null;
    _timer?.removeListener(_changed);
    unawaited(_messages?.cancel());
    _toastTimer?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  bool get _taking => _timer?.takesInput ?? false;

  /// A real key, before the focused screen sees it.
  KeyEventResult _onKey(KeyEvent event) {
    // Flutter's own key-state syncs (a modifier held as the window gets
    // focus) aren't presses.
    if (!_taking || event.synthesized) return KeyEventResult.ignored;
    if (event is KeyDownEvent) _input('key ${event.logicalKey.keyLabel}');
    return KeyEventResult.handled;
  }

  /// A key dispatched by the app itself (Android's Back as a pop, the phone
  /// remote).
  bool _onDispatched(KeyEvent event) {
    if (!_taking) return false;
    _input('key ${event.logicalKey.keyLabel}');
    return true;
  }

  void _input(String by) {
    final timer = _timer;
    if (timer == null) return;
    if (timer.phase == SleepPhase.asleep) {
      unawaited(timer.wake(by: by));
    } else {
      timer.cancel(by: by);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = _timer;
    final phase = timer?.phase ?? SleepPhase.idle;
    final asleep = phase == SleepPhase.asleep;
    final warning = phase == SleepPhase.warning || phase == SleepPhase.fading;
    // Below the status bar on a phone.
    final top = 60 + MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        widget.child,
        if (_taking)
          Positioned.fill(
            child: MouseRegion(
              cursor: asleep ? SystemMouseCursors.none : MouseCursor.defer,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _input('pointer down'),
                onPointerHover: (e) => _input('pointer move'),
                onPointerMove: (e) => _input('pointer move'),
                onPointerSignal: (e) => _input('pointer signal'),
                onPointerPanZoomStart: (e) => _input('pointer pan'),
                child: asleep ? const SleepScreen() : const SizedBox.expand(),
              ),
            ),
          ),
        if (warning && timer != null)
          Positioned(
            left: 0,
            right: 0,
            top: top,
            // Clear of the edges on a phone's narrow canvas.
            child: IgnorePointer(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    // Fading: no count left to show.
                    child: Center(
                        child: SleepWarning(seconds: phase == SleepPhase.fading ? null : timer.secondsLeft)))),
          )
        else if (_toast != null && !asleep)
          Positioned(
            left: 0,
            right: 0,
            top: top,
            child: IgnorePointer(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32), child: Center(child: SleepToast(_toast!)))),
          ),
      ],
    );
  }
}

/// The last-minute card at the top centre: "Going to sleep in 42".
class SleepWarning extends StatefulWidget {
  const SleepWarning({super.key, required this.seconds});

  /// Seconds left; null while the sound fades.
  final int? seconds;

  static const hint = 'Press any button to keep watching';

  @override
  State<SleepWarning> createState() => _SleepWarningState();
}

class _SleepWarningState extends State<SleepWarning> {
  /// Screen readers hear it once, as it comes up.
  bool _announce = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _announce = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Semantics(
      liveRegion: _announce,
      label: 'Going to sleep in 1 minute. ${SleepWarning.hint}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(44, 24, 44, 28),
          decoration: BoxDecoration(
            color: g.panel.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: g.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bedtime, size: 40, color: g.accent),
                    const SizedBox(width: 18),
                    Text(widget.seconds == null ? 'Going to sleep' : 'Going to sleep in ${widget.seconds}', style: g.display(44, weight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(SleepWarning.hint, textAlign: TextAlign.center, style: g.body(26, color: g.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Sleep in 30 min", "Sleep timer off", where the TV screen's own toasts
/// show, on every screen.
class SleepToast extends StatelessWidget {
  const SleepToast(this.message, {super.key});

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
      child: Text(message, textAlign: TextAlign.center, style: g.display(36, weight: FontWeight.w600)),
    );
  }
}

/// Asleep: black, saying "Sleeping · Press any button to watch" dimly for
/// [SleepTimer.sleepMessageFor], then nothing lit at all.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  static const message = 'Sleeping · Press any button to watch';

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  late final Timer _dark;
  bool _message = true;

  @override
  void initState() {
    super.initState();
    _dark = Timer(SleepTimer.sleepMessageFor, () {
      if (mounted) setState(() => _message = false);
    });
  }

  @override
  void dispose() {
    _dark.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: _message
            ? Text(SleepScreen.message,
                textAlign: TextAlign.center,
                style: g.display(40, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.3)))
            : const SizedBox.shrink(),
      ),
    );
  }
}
