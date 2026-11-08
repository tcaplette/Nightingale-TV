import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'playback_diagnostics.dart';
import 'sleep_timer.dart';
import 'tuner.dart';

/// Not counting (nothing plays, a sleep timer is set, or it's Off),
/// counting the time since the last input, or asking "Are you still
/// watching?".
enum StillWatchingPhase { off, watching, prompting }

/// "Are you still watching?" (idle-power, design D5): the time since the
/// last input while a channel plays. At the profile's still-watching time
/// it asks; with no answer in [promptFor] the app goes to sleep through
/// [SleepTimer.sleepNow]. Made next to the [SleepTimer]; never in server
/// mode.
class StillWatching extends ChangeNotifier {
  /// [clock], [after] and [timer] are for tests; [after] reads the
  /// profile's setting by default.
  StillWatching(this.tuner, this.sleep,
      {DateTime Function()? clock, Duration? Function()? after, Timer Function(Duration, void Function())? timer})
      : _clock = clock ?? DateTime.now,
        _startTimer = timer ?? Timer.new,
        _after = after ?? (() => _override ?? tuner.app.settings.playback.stillWatchingAfter) {
    _lastInput = _clock();
    _tunes = tuner.tunes;
    _sleepPhase = sleep.phase;
    tuner.addListener(_changed);
    sleep.addListener(_changed);
    _changed();
  }

  final Tuner tuner;
  final SleepTimer sleep;
  final DateTime Function() _clock;
  final Duration? Function() _after;
  final Timer Function(Duration, void Function()) _startTimer;

  /// How long the prompt waits for an answer.
  static const promptFor = Duration(seconds: 60);

  /// Diagnostics builds only (idle-cpu 4.4): a shorter still-watching time,
  /// in minutes, from `NIGHTINGALE_TV_STILL_WATCHING_MINUTES` (a dart-define
  /// or the environment). Every other build uses the profile's setting.
  @visibleForTesting
  static Duration? get debugOverride => _override;

  static Duration? get _override {
    if (!PlaybackDiagnostics.enabled) return null;
    const built = String.fromEnvironment('NIGHTINGALE_TV_STILL_WATCHING_MINUTES');
    final raw = built.isNotEmpty ? built : Platform.environment['NIGHTINGALE_TV_STILL_WATCHING_MINUTES'];
    final minutes = int.tryParse(raw ?? '');
    return minutes == null || minutes <= 0 ? null : Duration(minutes: minutes);
  }

  StillWatchingPhase phase = StillWatchingPhase.off;
  late DateTime _lastInput;
  late int _tunes;
  late SleepPhase _sleepPhase;
  DateTime? _promptedAt;
  Timer? _timer;

  DateTime get lastInput => _lastInput;

  bool get prompting => phase == StillWatchingPhase.prompting;

  /// Whole seconds left on the prompt ("Going to sleep in 0:42").
  int get secondsLeft {
    final at = _promptedAt;
    if (at == null) return promptFor.inSeconds;
    final rest = at.add(promptFor).difference(_clock());
    if (rest.isNegative) return 0;
    return (rest.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/ Duration.microsecondsPerSecond;
  }

  /// A key, pointer move, click, touch or phone-remote command ([by]):
  /// the count starts again, and an open prompt closes.
  void input(String by) {
    _lastInput = _clock();
    if (prompting) {
      _note('kept watching by $by');
      phase = StillWatchingPhase.watching;
      _promptedAt = null;
      _schedule();
      notifyListeners();
    }
  }

  /// Whether the count runs: a channel on (paused in timeshift too), no
  /// sleep timer set and not asleep or fading, and a time chosen.
  bool get _counts => tuner.channel != null && sleep.phase == SleepPhase.idle && _after() != null;

  void _changed() {
    final tuned = tuner.tunes != _tunes;
    _tunes = tuner.tunes;
    // Back from a sleep, a fade or a timer: counted from now.
    final sleepChanged = sleep.phase != _sleepPhase;
    _sleepPhase = sleep.phase;
    if (tuned || sleepChanged) _lastInput = _clock();
    final counts = _counts;
    if (!counts) {
      if (phase != StillWatchingPhase.off) {
        phase = StillWatchingPhase.off;
        _promptedAt = null;
        _timer?.cancel();
        _timer = null;
        notifyListeners();
      }
      return;
    }
    if (phase == StillWatchingPhase.off) {
      phase = StillWatchingPhase.watching;
      _lastInput = _clock();
      _schedule();
      notifyListeners();
    } else if ((tuned || sleepChanged) && phase == StillWatchingPhase.watching) {
      _schedule();
    }
  }

  /// One timer, at the earliest the prompt could be due; input only moves
  /// [_lastInput], and the timer looks again when it fires.
  void _schedule() {
    _timer?.cancel();
    if (phase == StillWatchingPhase.watching) {
      final after = _after();
      if (after == null) return;
      final due = _lastInput.add(after).difference(_clock());
      _timer = _startTimer(due.isNegative ? Duration.zero : due, _due);
    } else if (phase == StillWatchingPhase.prompting) {
      // The countdown's number changes each second.
      _timer = _startTimer(const Duration(seconds: 1), _tick);
    }
  }

  void _due() {
    if (phase != StillWatchingPhase.watching || !_counts) return;
    final after = _after()!;
    if (_clock().difference(_lastInput) < after) {
      _schedule();
      return;
    }
    phase = StillWatchingPhase.prompting;
    _promptedAt = _clock();
    _note('prompt after ${after.inMinutes} min with no input');
    _schedule();
    notifyListeners();
  }

  void _tick() {
    if (!prompting) return;
    if (secondsLeft > 0) {
      _schedule();
      notifyListeners();
      return;
    }
    _note('no answer: sleep');
    phase = StillWatchingPhase.off;
    _promptedAt = null;
    _timer = null;
    notifyListeners();
    sleep.sleepNow(by: 'still watching');
  }

  void _note(String message) => PlaybackDiagnostics.note('STILL', message);

  @override
  void dispose() {
    _timer?.cancel();
    tuner.removeListener(_changed);
    sleep.removeListener(_changed);
    super.dispose();
  }
}
