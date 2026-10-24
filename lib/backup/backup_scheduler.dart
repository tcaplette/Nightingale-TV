import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../platform/platform_info.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/household.dart';
import 'backup_archive.dart';
import 'backup_store.dart';

/// Makes the household's backups (D9): a daily one when something changed,
/// and a safety backup right before anything that replaces a lot at once.
class BackupScheduler extends ChangeNotifier {
  BackupScheduler(this.household, this.store);

  final Household household;
  final BackupStore store;

  /// Server mode: the accounts section every backup carries (see
  /// [BackupArchive.server]).
  Map<String, Object?> Function()? serverSection;

  /// The first daily check, after the launch's picture…
  @visibleForTesting
  static Duration firstCheck = const Duration(seconds: 15);

  /// …at the latest this long after start-up, whatever the TV is doing.
  @visibleForTesting
  static Duration firstCheckFallback = const Duration(minutes: 2);

  /// …then every day while the app runs.
  @visibleForTesting
  static Duration interval = const Duration(hours: 24);

  Timer? _first;
  Timer? _daily;
  bool _armed = false;

  /// Starts the daily checks, once the household has started: after the
  /// launch's picture when a profile is tuning, else after [firstCheck].
  void start() {
    if (_armed) return;
    _armed = true;
    void go() {
      if (_daily != null || !_armed) return;
      _first?.cancel();
      _daily = Timer.periodic(interval, (_) => unawaited(dailyCheck()));
      unawaited(dailyCheck());
    }

    final app = household.app;
    if (app != null && app.phase != AppPhase.signedOut) {
      // The launch gate opens AppState.launchSettleDelay after the
      // picture; the check comes the rest of firstCheck after that.
      final rest = firstCheck - AppState.launchSettleDelay;
      app.afterLaunch(() => _first = Timer(rest.isNegative ? Duration.zero : rest, go));
      _first = Timer(firstCheckFallback, go);
    } else {
      _first = Timer(firstCheck, go);
    }
  }

  @override
  void dispose() {
    _armed = false;
    _first?.cancel();
    _daily?.cancel();
    super.dispose();
  }

  /// Why the last automatic backup failed, if it did.
  String? lastError;

  /// Saves a daily backup if the household changed since the newest one.
  Future<StoredBackup?> dailyCheck() async {
    try {
      return await backUp(BackupReason.daily, onlyIfChanged: true);
    } on Object catch (e) {
      lastError = '$e';
      debugPrint('Daily backup failed: $e');
      return null;
    }
  }

  /// Saves a safety backup before a big change; skipped when the household
  /// matches the newest backup. Throws [BackupException] when it can't be
  /// saved, so the change can be refused.
  Future<StoredBackup?> safetyBackup(String reason, {String? subject}) async {
    assert(BackupReason.isSafety(reason));
    try {
      return await backUp(reason, subject: subject, onlyIfChanged: true);
    } on Object catch (e) {
      throw BackupException('Couldn\'t save a backup first: ${_plain(e)}');
    }
  }

  static String _plain(Object e) => switch (e) {
        FileSystemException(:final osError?) => '${osError.message}.',
        FileSystemException(:final message) => '$message.',
        _ => '$e',
      };

  /// Builds a backup of the household now ([BackupReason.manual] for Back
  /// up now). With [onlyIfChanged], nothing is saved when the newest backup
  /// holds the same.
  Future<StoredBackup?> backUp(String reason, {String? subject, bool onlyIfChanged = false}) async {
    // Nothing set up yet (a first run, or Welcome back on screen).
    if (await household.hasNothingToKeep()) return null;
    final built = await build(reason, subject: subject);
    if (onlyIfChanged) {
      final newest = await store.newest();
      if (newest != null && newest.fingerprint == built.fingerprint) {
        PlaybackDiagnostics.note('BACKUP', '$reason: unchanged, nothing saved');
        return null;
      }
    }
    final stored = await store.save(built.bytes, kind: reason);
    PlaybackDiagnostics.note('BACKUP', '$reason: saved ${stored.name}');
    notifyListeners();
    return stored;
  }

  /// A backup of the household as it is now, not saved anywhere (for the
  /// transfer page's download, and the checks above).
  Future<BuiltBackup> build(String reason, {String? subject}) async {
    final watch = Stopwatch()..start();
    await household.flushAll();
    final built = await BackupArchive.build(household.root.root,
        reason: reason, device: PlatformInfo.deviceName, subject: subject, server: serverSection?.call());
    PlaybackDiagnostics.note('BACKUP', 'built $reason backup: ${built.bytes.length} bytes in ${watch.elapsedMilliseconds} ms');
    return built;
  }

  /// Something the screen changed in the store (a file opened, a delete).
  void changed() => notifyListeners();
}
