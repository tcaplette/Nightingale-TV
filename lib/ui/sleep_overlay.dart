import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../playback/sleep_timer.dart';
import '../playback/still_watching.dart';
import '../remote/key_dispatch.dart';
import '../theme/tv_theme.dart';

/// The sleep timer over every screen (sleep-timer spec, design D4, D5): its
/// toasts, the last-minute warning, and the sleep screen. In the warning, the
/// fade and asleep it takes all input, so that input does nothing else: a key
/// (Android Back included) or a pointer move, click or tap turns the timer
/// off, or wakes the app. Otherwise input goes to the screens as usual.
///
/// It also feeds "Are you still watching?" (idle-power): every key, pointer
/// move, click and touch restarts its count, and while its prompt shows it
/// takes all input the same way, so that input only closes the prompt.
class SleepOverlay extends StatefulWidget {
  const SleepOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SleepOverlay> createState() => _SleepOverlayState();
}

class _SleepOverlayState extends State<SleepOverlay> {
  SleepTimer? _timer;
  StillWatching? _still;
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
    final still = AppScope.stillWatchingOf(context);
    if (!identical(still, _still)) {
      _still?.removeListener(_changed);
      _still = still?..addListener(_changed);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    if (interceptKey == _onDispatched) interceptKey = null;
    _timer?.removeListener(_changed);
    _still?.removeListener(_changed);
    unawaited(_messages?.cancel());
    _toastTimer?.cancel();
    _pointerHold?.cancel();
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

  bool get _prompting => _still?.prompting ?? false;

  bool get _taking => (_timer?.takesInput ?? false) || _prompting;

  /// After a pointer closed the prompt or turned the timer off, the rest of
  /// that movement (an air mouse sends a stream of moves) is taken too,
  /// until the pointer has been still for [pointerSettle].
  Timer? _pointerHold;
  static const pointerSettle = Duration(milliseconds: 700);

  void _holdPointer() {
    _pointerHold?.cancel();
    _pointerHold = Timer(pointerSettle, () {
      _pointerHold = null;
      if (mounted) setState(() {});
    });
  }

  /// Pointer input on the layer over the screens.
  void _pointer(String by) {
    final wasHolding = _pointerHold != null;
    _holdPointer();
    if (_taking) {
      _input(by);
    } else if (!wasHolding) {
      setState(() {});
    }
  }

  /// A key held down when the prompt closed: its repeats and release are
  /// taken too, so they don't reach the screen.
  LogicalKeyboardKey? _swallowing;

  /// A real key, before the focused screen sees it.
  KeyEventResult _onKey(KeyEvent event) {
    // Flutter's own key-state syncs (a modifier held as the window gets
    // focus) aren't presses.
    if (event.synthesized) return KeyEventResult.ignored;
    if (_swallowing == event.logicalKey) {
      if (event is KeyUpEvent) _swallowing = null;
      return KeyEventResult.handled;
    }
    if (!_taking) {
      if (event is KeyDownEvent) _still?.input('key ${event.logicalKey.keyLabel}');
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (_prompting) _swallowing = event.logicalKey;
      _input('key ${event.logicalKey.keyLabel}');
    }
    return KeyEventResult.handled;
  }

  /// A key dispatched by the app itself (Android's Back as a pop, the phone
  /// remote).
  bool _onDispatched(KeyEvent event) {
    if (!_taking) {
      _still?.input('key ${event.logicalKey.keyLabel}');
      return false;
    }
    _input('key ${event.logicalKey.keyLabel}');
    return true;
  }

  /// Input that doesn't reach the screens: it closes the still-watching
  /// prompt, or turns the sleep timer off, or wakes the app.
  void _input(String by) {
    final still = _still;
    if (still != null && still.prompting) {
      still.input(by);
      return;
    }
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
    final still = _still;
    final prompting = still != null && still.prompting;
    return Stack(
      children: [
        // Pointer input reaching the screens still counts as someone there.
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _still?.input('pointer down'),
          onPointerHover: (e) => _still?.input('pointer move'),
          onPointerMove: (e) => _still?.input('pointer move'),
          onPointerSignal: (e) => _still?.input('pointer signal'),
          child: widget.child,
        ),
        if (prompting)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: StillWatchingPrompt(seconds: still.secondsLeft, onKeepWatching: () => _input('button')),
                ),
              ),
            ),
          ),
        if (_taking || _pointerHold != null)
          Positioned.fill(
            child: MouseRegion(
              cursor: asleep ? SystemMouseCursors.none : MouseCursor.defer,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _pointer('pointer down'),
                onPointerHover: (e) => _pointer('pointer move'),
                onPointerMove: (e) => _pointer('pointer move'),
                onPointerSignal: (e) => _pointer('pointer signal'),
                onPointerPanZoomStart: (e) => _pointer('pointer pan'),
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

/// "Are you still watching?" (idle-power): one Keep watching button, shown
/// focused, and the countdown to sleep. All input is taken while it shows
/// ([SleepOverlay]), so the button never takes the screen's focus.
class StillWatchingPrompt extends StatelessWidget {
  const StillWatchingPrompt({super.key, required this.seconds, required this.onKeepWatching});

  final int seconds;
  final VoidCallback onKeepWatching;

  static const question = 'Are you still watching?';
  static const keepWatching = 'Keep watching';

  static String countdown(int seconds) => 'Going to sleep in 0:${seconds.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: question,
      child: Container(
        padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
        decoration: BoxDecoration(
          color: g.panel.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: g.accent, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(question, style: g.display(48, weight: FontWeight.w800)),
            ),
            const SizedBox(height: 32),
            Semantics(
              button: true,
              focused: true,
              label: keepWatching,
              onTap: onKeepWatching,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  decoration: BoxDecoration(
                    color: g.focus,
                    borderRadius: BorderRadius.circular(g.radius * 2),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: g.focus.withValues(alpha: 0.45), blurRadius: 18)],
                  ),
                  child: Text(keepWatching, style: g.display(32, weight: FontWeight.w700, color: g.onFocus)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(countdown(seconds), textAlign: TextAlign.center, style: g.body(28, color: g.textDim)),
          ],
        ),
      ),
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
