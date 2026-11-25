import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../platform/platform_info.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/household.dart';
import 'backup_archive.dart';
import 'backup_store.dart';
import '../l10n/tr.dart';
import '../reporting/error_reports.dart';

/// Keeps the household's two backups (backup-simplify D2, D4): the
/// automatic backup, rewritten when the household changed, and the undo
/// point, saved right before anything that replaces a lot at once.
class BackupScheduler extends ChangeNotifier {
  BackupScheduler(this.household, this.store);

  final Household household;
  final BackupStore store;

  /// Server mode: the accounts section every backup carries (see
  /// [BackupArchive.server]).
  Map<String, Object?> Function()? serverSection;

  /// The first check, after the launch's picture…
  @visibleForTesting
  static Duration firstCheck = const Duration(seconds: 15);

  /// …at the latest this long after start-up, whatever the TV is doing.
  @visibleForTesting
  static Duration firstCheckFallback = const Duration(minutes: 2);

  /// …then this often while the app runs.
  @visibleForTesting
  static Duration interval = const Duration(hours: 6);

  /// Going to the background checks at most this often.
  @visibleForTesting
  static Duration backgroundGap = const Duration(minutes: 1);

  /// The time, for [backgroundGap] (a fake clock in tests).
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  Timer? _first;
  Timer? _periodic;
  bool _armed = false;
  bool _cleared = false;
  DateTime? _lastBackground;
  Future<StoredBackup?>? _running;

  /// Starts the checks, once the household has started: after the launch's
  /// picture when a profile is tuning, else after [firstCheck].
  void start() {
    if (_armed) return;
    _armed = true;
    void go() {
      if (_periodic != null || !_armed) return;
      _first?.cancel();
      _periodic = Timer.periodic(interval, (_) => unawaited(automaticCheck()));
      unawaited(automaticCheck());
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

  /// The app went to the background (paused or hidden): a check, at most
  /// once every [backgroundGap]. Nothing is on screen to slow down.
  void wentToBackground() {
    if (!_armed) return;
    final at = now();
    if (_lastBackground case final last? when at.difference(last) < backgroundGap) return;
    _lastBackground = at;
    unawaited(automaticCheck());
  }

  @override
  void dispose() {
    _armed = false;
    _first?.cancel();
    _periodic?.cancel();
    super.dispose();
  }

  /// Why the last automatic backup failed, if it did.
  String? lastError;

  /// Rewrites the automatic backup if the household changed since it was
  /// written. The first one also clears out older versions' backups (D10).
  /// One check at a time; asking during one waits for it.
  Future<StoredBackup?> automaticCheck() => _running ??= _automaticCheck().whenComplete(() => _running = null);

  Future<StoredBackup?> _automaticCheck() async {
    try {
      if (!_cleared) {
        _cleared = true;
        await store.clearOldBackups();
      }
      // Nothing set up yet (a first run, or Welcome back on screen): the
      // backup Android brought back stays.
      if (await household.hasNothingToKeep()) return null;
      final built = await build(BackupReason.daily, pickedFiles: PickedFiles.automatic);
      final latest = await store.latest();
      if (latest != null && latest.fingerprint == built.fingerprint) {
        PlaybackDiagnostics.note('BACKUP', 'automatic: unchanged, nothing saved');
        return null;
      }
      final stored = await store.writeLatest(built.bytes);
      lastError = null;
      PlaybackDiagnostics.note('BACKUP', 'automatic: saved ${built.bytes.length} bytes');
      notifyListeners();
      return stored;
    } on Object catch (e, stack) {
      lastError = '$e';
      debugPrint('Automatic backup failed: $e');
      ErrorReports.capture(e, stack, area: 'backup');
      return null;
    }
  }

  /// Saves the undo point before a big change ([reason] is a "before-"
  /// one, [subject] the profile a delete is for), with every picked file.
  /// Skipped when there's nothing to keep, or when the undo point there
  /// holds the same household for the same change. The same household for
  /// another change is saved again, so the button names this one. Throws [BackupException] when it can't be saved,
  /// so the change can be refused.
  Future<StoredBackup?> saveUndoPoint(String reason, {String? subject}) async {
    assert(BackupReason.isSafety(reason));
    try {
      if (await household.hasNothingToKeep()) return null;
      final built = await build(reason, subject: subject);
      final undo = await store.undo();
      if (undo != null &&
          undo.fingerprint == built.fingerprint &&
          undo.reason == reason &&
          undo.archive.subject == subject) {
        PlaybackDiagnostics.note('BACKUP', '$reason: same as the undo point, nothing saved');
        return null;
      }
      final stored = await store.writeUndo(built.bytes);
      PlaybackDiagnostics.note('BACKUP', '$reason: undo point saved');
      notifyListeners();
      return stored;
    } on Object catch (e, stack) {
      ErrorReports.capture(e, stack, area: 'backup');
      throw BackupException(tr.couldntSaveA(_plain(e)));
    }
  }

  static String _plain(Object e) => switch (e) {
        FileSystemException(:final osError?) => '${osError.message}.',
        FileSystemException(:final message) => '$message.',
        _ => '$e',
      };

  /// A backup of the household as it is now, not saved anywhere: Save to a
  /// file, downloads, the hand-over, and the checks above.
  Future<BuiltBackup> build(String reason, {String? subject, PickedFiles pickedFiles = PickedFiles.all}) async {
    final watch = Stopwatch()..start();
    await household.flushAll();
    final built = await BackupArchive.build(household.root.root,
        reason: reason,
        device: PlatformInfo.deviceName,
        subject: subject,
        server: serverSection?.call(),
        pickedFiles: pickedFiles);
    PlaybackDiagnostics.note('BACKUP', 'built $reason backup: ${built.bytes.length} bytes in ${watch.elapsedMilliseconds} ms');
    return built;
  }
}
