import 'dart:async';

import '../data/app_storage.dart';

/// `--dart-define=NTV_TRIAL_OFFSET_DAYS=<n>` moves the trial start n days
/// earlier, for testing (play-unlock D7). Release builds never set it.
const trialOffsetDays = int.fromEnvironment('NTV_TRIAL_OFFSET_DAYS');

/// Where the free trial stands.
class TrialStatus {
  const TrialStatus(this.remaining);

  /// Time left; zero or less once the trial is over.
  final Duration remaining;

  bool get expired => remaining <= Duration.zero;

  /// Whole days left, rounded up: a fresh trial reads 14, its last day 1.
  int get daysLeft => expired ? 0 : (remaining.inMicroseconds / Duration.microsecondsPerDay).ceil();
}

/// The free trial's clock (play-unlock D4): `store/trial.json` holds
/// `{"start", "lastSeen"}` in ms. Elapsed time is `max(now, lastSeen) −
/// start`, and lastSeen only moves forward, so setting the device clock back
/// stops the trial's clock instead of adding time.
///
/// The file is in no Nightingale TV backup (backups name the files they
/// hold), and the play flavor's Android backup rules include it.
class TrialClock {
  TrialClock(this._storage, {DateTime Function()? now, this.offsetDays = trialOffsetDays})
      : _now = now ?? DateTime.now;

  static const file = 'store/trial.json';
  static const length = Duration(days: 14);

  final AppStorage _storage;
  final DateTime Function() _now;

  /// Days the start is moved back by (NTV_TRIAL_OFFSET_DAYS).
  final int offsetDays;

  int? _start;
  int _lastSeen = 0;

  /// Reads the file, starting the trial now if there's none, and moves
  /// lastSeen forward.
  Future<TrialStatus> load() async {
    final saved = await _storage.readJson(file);
    if (saved is Map && saved['start'] is int) {
      _start = saved['start'] as int;
      _lastSeen = saved['lastSeen'] is int ? saved['lastSeen'] as int : _start!;
    } else {
      _start = _lastSeen = _now().millisecondsSinceEpoch;
    }
    return check();
  }

  /// Where the trial stands now, from what [load] read. Synchronous, so
  /// coming back to the foreground knows at once (the file is written in the
  /// background).
  TrialStatus check() {
    final start = _start;
    if (start == null) return const TrialStatus(length);
    final now = _now().millisecondsSinceEpoch;
    if (now > _lastSeen) _lastSeen = now;
    _save();
    final elapsed = Duration(milliseconds: _lastSeen - start) + Duration(days: offsetDays);
    return TrialStatus(length - elapsed);
  }

  void _save() => unawaited(_storage.writeJson(file, {'start': _start, 'lastSeen': _lastSeen}));
}
