import 'dart:async';

import 'package:flutter/foundation.dart';

import '../channels/channel.dart';
import '../platform/platform_info.dart';
import 'playback_diagnostics.dart';
import 'tuner.dart';

/// What the viewer picked in the sleep picker (sleep-timer spec).
@immutable
class SleepChoice {
  const SleepChoice._(this.minutes, this.atProgramEnd);

  /// [minutes] on the clock from when it's chosen.
  const SleepChoice.after(int this.minutes) : atProgramEnd = false;

  static const off = SleepChoice._(null, false);

  /// When the program on screen ends, before its post-roll.
  static const programEnd = SleepChoice._(null, true);

  /// The picker's rows, in order.
  static const all = [
    off,
    programEnd,
    SleepChoice.after(15),
    SleepChoice.after(30),
    SleepChoice.after(45),
    SleepChoice.after(60),
    SleepChoice.after(90),
    SleepChoice.after(120),
  ];

  final int? minutes;
  final bool atProgramEnd;

  bool get isOff => minutes == null && !atProgramEnd;

  @override
  bool operator ==(Object other) =>
      other is SleepChoice && other.minutes == minutes && other.atProgramEnd == atProgramEnd;

  @override
  int get hashCode => Object.hash(minutes, atProgramEnd);

  @override
  String toString() => isOff ? 'off' : (atProgramEnd ? 'end of program' : '$minutes min');
}

/// Idle (no timer), armed (counting), warning (its last minute), fading (the
/// sound going), asleep (stopped, the sleep screen up).
enum SleepPhase { idle, armed, warning, fading, asleep }

/// The sleep timer (sleep-timer spec, design D1): app-level state next to the
/// tuner, never saved. A minute timer fires on the wall clock; "end of this
/// program" follows the picture, so pausing, rewinding or changing channel
/// moves it. The last minute warns; then the sound fades, playback stops and
/// the device is let sleep.
class SleepTimer extends ChangeNotifier {
  /// [clock] and [keepScreenOn] are for tests.
  SleepTimer(this.tuner, {DateTime Function()? clock, Future<void> Function(bool on)? keepScreenOn})
      : _clock = clock ?? DateTime.now,
        _keepScreenOn = keepScreenOn ?? PlatformInfo.keepScreenOn;

  final Tuner tuner;
  final DateTime Function() _clock;
  final Future<void> Function(bool on) _keepScreenOn;

  /// The warning shows this long before the timer fires.
  static const warningLead = Duration(seconds: 60);

  /// The sound fades over this long, in [fadeSteps] steps.
  static const fadeLength = Duration(seconds: 10);
  static const fadeSteps = 20;

  /// "End of this program" with no known end: it fires anyway after this.
  static const longestWait = Duration(hours: 4);

  /// How long the sleep screen says "Sleeping" before going fully black.
  static const sleepMessageFor = Duration(seconds: 10);

  SleepChoice choice = SleepChoice.off;
  SleepPhase phase = SleepPhase.idle;

  /// When it fires; null while "end of this program" waits for a known end.
  DateTime? deadline;

  /// The channel playing when it went to sleep, tuned again on waking.
  Channel? sleptOn;

  /// Bumped when the app wakes from sleep: the TV screen tunes [sleptOn]
  /// (now, or when the viewer goes back to it).
  final woke = ValueNotifier<int>(0);

  final _messages = StreamController<String>.broadcast();

  /// Short messages for the screen: "Sleep in 30 min", "Sleep timer off".
  Stream<String> get messages => _messages.stream;

  Timer? _check;
  Timer? _fade;

  /// [minutesLeft] when listeners last heard, so the banner's line moves on.
  int? _heardMinutes;
  int _step = 0;

  /// "End of this program": since when there's been no known end, and the
  /// fixed deadline once one appeared (or the wait ran out).
  DateTime? _noEndSince;
  DateTime? _fallback;

  /// Stopping playback on the way to sleep.
  Future<void>? _sleeping;

  bool get armed => phase != SleepPhase.idle && phase != SleepPhase.asleep;

  /// Input is taken (and cancels or wakes) in these phases only.
  bool get takesInput => phase == SleepPhase.warning || phase == SleepPhase.fading || phase == SleepPhase.asleep;

  DateTime now() => _clock();

  /// Time left until it fires, while armed with a known deadline.
  Duration? get left {
    final d = deadline;
    if (d == null || !armed) return null;
    final rest = d.difference(_clock());
    return rest.isNegative ? Duration.zero : rest;
  }

  /// Whole minutes left, rounded up ("Sleep in 23 min"), at least 1.
  int? get minutesLeft {
    final rest = left;
    if (rest == null) return null;
    return ((rest.inMicroseconds + Duration.microsecondsPerMinute - 1) ~/ Duration.microsecondsPerMinute)
        .clamp(1, 1 << 30);
  }

  /// Whole seconds left in the warning ("Going to sleep in 42").
  int get secondsLeft {
    final rest = left ?? Duration.zero;
    return ((rest.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/ Duration.microsecondsPerSecond)
        .clamp(0, 1 << 30);
  }

  /// When the program on screen ends, on the wall clock: the end of its last
  /// show part at the tuner's view time, moved by how far behind the viewer
  /// is. In a post-roll (the show already over) it's the next program's.
  /// [choosing]: for the picker, a program ending within [warningLead] means
  /// the next one (and so on, past very short programs), so the last
  /// minute's warning always fits. Null when nothing with a known end is on.
  DateTime? programEnd({bool choosing = false}) => _programEnd(choosing: choosing).end;

  /// [programEnd], and the schedule time of the last end passed over to get
  /// there (null when none was).
  ({DateTime? end, DateTime? skipped}) _programEnd({bool choosing = false}) {
    final schedule = tuner.schedule;
    final channel = tuner.channel;
    if (channel == null || schedule == null) return (end: null, skipped: null);
    final now = tuner.viewNow();
    var view = now;
    // Chosen as the program ended: it's still the next one.
    if (_skipBefore case final skip? when _skipChannel == channel.id && skip.isAfter(view)) view = skip;
    DateTime? endAt(DateTime t) {
      final end = schedule.programEndAt(t);
      if (end == null || end.isAfter(t)) return end;
      return schedule.programEndAt(schedule.programAt(t).end);
    }

    var end = endAt(view);
    DateTime? skipped;
    for (var i = 0; choosing && i < 200 && end != null && end.difference(now) < warningLead; i++) {
      skipped = end;
      // Past the program's slot, which may hold a post-roll after its end.
      end = endAt(schedule.programAt(end.subtract(const Duration(microseconds: 1))).end);
    }
    return (end: end?.add(tuner.behind), skipped: skipped);
  }

  /// "End of this program" was chosen as one ended: the schedule time before
  /// which the program on screen doesn't count, on [_skipChannel].
  DateTime? _skipBefore;
  String? _skipChannel;

  /// Sets the timer to [c] (off turns it off), from the picker.
  void choose(SleepChoice c) {
    _stopTimers();
    final wasFading = phase == SleepPhase.fading;
    choice = c;
    _noEndSince = null;
    _fallback = null;
    _skipBefore = null;
    if (c.isOff) {
      phase = SleepPhase.idle;
      deadline = null;
      _note('off');
      _say('Sleep timer off');
    } else {
      phase = SleepPhase.armed;
      final minutes = c.minutes;
      if (minutes != null) {
        deadline = _clock().add(Duration(minutes: minutes));
      } else {
        final (:end, :skipped) = _programEnd(choosing: true);
        if (skipped != null) {
          _skipBefore = skipped;
          _skipChannel = tuner.channel?.id;
        }
        deadline = end;
      }
      _note('set $c, deadline ${_at(deadline)}');
      _say(minutes != null ? 'Sleep in $minutes min' : 'Sleep at end of program');
      _tick();
    }
    if (wasFading) unawaited(tuner.media.setVolume(1));
    notifyListeners();
  }

  /// Turns the timer off: input in the warning or the fade ([by]: what), or
  /// Android putting the app out of sight ('hidden', with no toast). Full
  /// volume comes back at once. Asleep, only hiding ends the sleep (without
  /// tuning); input there [wake]s.
  void cancel({required String by}) {
    if (phase == SleepPhase.idle) return;
    final hidden = by == 'hidden';
    if (phase == SleepPhase.asleep) {
      if (!hidden) return;
      phase = SleepPhase.idle;
      tuner.app.asleep = false;
      _note('cancel by $by while asleep');
      unawaited(_keepScreenOn(true));
      notifyListeners();
      return;
    }
    final wasFading = phase == SleepPhase.fading;
    _stopTimers();
    choice = SleepChoice.off;
    deadline = null;
    phase = SleepPhase.idle;
    if (wasFading) unawaited(tuner.media.setVolume(1));
    _note('cancel by $by');
    if (!hidden) _say('Sleep timer off');
    notifyListeners();
  }

  /// Input on the sleep screen: the screen is held on again, the timer is
  /// off, and [woke] tells the TV screen to tune [sleptOn].
  Future<void> wake({required String by}) async {
    if (phase != SleepPhase.asleep) return;
    phase = SleepPhase.idle;
    tuner.app.asleep = false;
    _note('wake by $by');
    notifyListeners();
    await _sleeping;
    await _keepScreenOn(true);
    woke.value++;
  }

  /// Checks the deadline, and comes back in a second (or at the next whole
  /// second of the countdown in the warning).
  void _tick() {
    _check?.cancel();
    final now = _clock();
    if (phase == SleepPhase.armed && choice.atProgramEnd) _follow(now);
    final d = deadline;
    if (d != null) {
      if (phase == SleepPhase.armed && !now.isBefore(d.subtract(warningLead))) {
        phase = SleepPhase.warning;
        _note('warning, deadline ${_at(d)}');
        notifyListeners();
      }
      if (phase == SleepPhase.warning) {
        if (!now.isBefore(d)) {
          _startFade();
          return;
        }
        // The countdown's number changes on the deadline's whole seconds.
        notifyListeners();
        final rest = d.difference(now).inMicroseconds % Duration.microsecondsPerSecond;
        _check = Timer(Duration(microseconds: rest == 0 ? Duration.microsecondsPerSecond : rest + 1000), _tick);
        return;
      }
    }
    if (minutesLeft != _heardMinutes) {
      _heardMinutes = minutesLeft;
      notifyListeners();
    }
    _check = Timer(const Duration(seconds: 1), _tick);
  }

  /// "End of this program": the deadline follows the picture.
  void _follow(DateTime now) {
    final before = deadline;
    final end = programEnd();
    if (_fallback != null) {
      deadline = _fallback;
    } else if (end != null) {
      if (_noEndSince != null) {
        // A program with an end appeared after a wait: a minute from now.
        _fallback = now.add(warningLead);
        _note('a program with an end is on after a wait; deadline ${_at(_fallback)}');
      }
      deadline = _fallback ?? end;
    } else {
      _noEndSince ??= now;
      deadline = null;
      if (now.difference(_noEndSince!) >= longestWait) {
        _fallback = now.add(warningLead);
        deadline = _fallback;
        _note('no program with an end in ${longestWait.inHours} h; deadline ${_at(_fallback)}');
      }
    }
    final moved = before == null || deadline == null
        ? before != deadline
        : before.difference(deadline!).abs() >= const Duration(seconds: 1);
    if (moved) {
      _note('deadline moved to ${_at(deadline)}');
      notifyListeners();
    }
  }

  void _startFade() {
    _check?.cancel();
    phase = SleepPhase.fading;
    _step = 0;
    _note('fade start');
    notifyListeners();
    _fade = Timer.periodic(fadeLength ~/ fadeSteps, (_) {
      _step++;
      unawaited(tuner.media.setVolume(1 - _step / fadeSteps));
      if (_step >= fadeSteps) _sleep();
    });
  }

  /// The fade is over: playback stops, the volume is back for the next tune,
  /// the sleep screen covers the app and the device may sleep.
  void _sleep() {
    _stopTimers();
    sleptOn = tuner.channel ?? sleptOn;
    choice = SleepChoice.off;
    deadline = null;
    phase = SleepPhase.asleep;
    tuner.app.asleep = true;
    notifyListeners();
    _sleeping = () async {
      await tuner.stop();
      await tuner.media.setVolume(1);
      _note('stop, channel ${sleptOn?.number ?? '-'}');
      await _keepScreenOn(false);
    }();
  }

  void _stopTimers() {
    _check?.cancel();
    _check = null;
    _fade?.cancel();
    _fade = null;
  }

  void _say(String message) {
    if (!_messages.isClosed) _messages.add(message);
  }

  static String _at(DateTime? t) => t?.toIso8601String() ?? 'none (waiting for a known end)';

  /// The diagnostics' SLEEP lines (design D10).
  void _note(String message) => PlaybackDiagnostics.note('SLEEP', message);

  @override
  void dispose() {
    _stopTimers();
    woke.dispose();
    unawaited(_messages.close());
    super.dispose();
  }
}
