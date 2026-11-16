import 'dart:async';

import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter/widgets.dart';

import '../data/app_storage.dart';
import '../platform/install_info.dart';
import '../platform/platform_info.dart';
import 'store.dart';
import 'trial.dart';

/// Where the install stands (play-unlock D3).
enum UnlockStatus {
  /// Not a locked install: the free flavor, an own build, Linux. Nothing
  /// about a trial or a purchase shows.
  notLocked,

  /// In the free trial.
  trial,

  /// The trial is over with nothing bought: the Unlock screen.
  expired,

  /// A purchase is waiting to complete. Nothing is locked meanwhile.
  pending,

  /// Bought.
  unlocked,
}

@immutable
class UnlockState {
  const UnlockState(this.status, {this.daysLeft = 0, this.price});

  static const notLocked = UnlockState(UnlockStatus.notLocked);

  final UnlockStatus status;

  /// Whole days left in the trial (trial only).
  final int daysLeft;

  /// Play's formatted price, once Play has given one.
  final String? price;

  /// Whether this install has a trial and a purchase at all.
  bool get locking => status != UnlockStatus.notLocked;

  /// Whether the Unlock screen replaces the home screen.
  bool get blocked => status == UnlockStatus.expired;

  /// Whether the menu offers Unlock Nightingale TV.
  bool get offersUnlock =>
      status == UnlockStatus.trial || status == UnlockStatus.pending || status == UnlockStatus.expired;

  @override
  bool operator ==(Object other) =>
      other is UnlockState && other.status == status && other.daysLeft == daysLeft && other.price == price;

  @override
  int get hashCode => Object.hash(status, daysLeft, price);

  @override
  String toString() => 'UnlockState($status, daysLeft: $daysLeft, price: $price)';
}

/// A one-time trial notice (play-unlock D6).
enum UnlockNotice { welcome, threeDaysLeft, lastDay }

/// The free trial and the unlock purchase (play-unlock D3, D5): the trial
/// clock, the store and the cached purchase, as one [UnlockState]. It is
/// checked on start, on return to the foreground and after a purchase, never
/// in between, so the trial ending never cuts off a program.
class Unlock extends ValueNotifier<UnlockState> {
  /// No store: not a locked install, so no store call is ever made.
  Unlock(this._storage, {this._store, DateTime Function()? now, int offsetDays = trialOffsetDays})
      : _now = now ?? DateTime.now,
        _trial = TrialClock(_storage, now: now, offsetDays: offsetDays),
        super(UnlockState.notLocked);

  /// The purchase seen from Play, kept for when Play can't be reached:
  /// `{"owned": true, "checked": <ms>}`. In no backup.
  static const cacheFile = 'store/unlock.json';

  /// The notices already shown: `{"welcome": true, ...}`.
  static const noticesFile = 'store/notices.json';

  /// How long a start that would show the Unlock screen waits for Play to
  /// say the purchase is there (a reinstall whose trial came back with
  /// Google backup), so a bought install never shows it.
  static const firstAnswerWait = Duration(seconds: 5);

  final AppStorage _storage;
  final Store? _store;
  final DateTime Function() _now;
  final TrialClock _trial;

  /// The trial as last checked: on start and on return to the foreground,
  /// never in between.
  TrialStatus _trialStatus = const TrialStatus(TrialClock.length);

  bool _cached = false;
  String? _price;
  bool _pending = false;
  StreamSubscription<StoreState>? _changes;
  AppLifecycleListener? _lifecycle;
  bool _started = false;

  /// The unlock for this install: the stand-in store when NTV_FAKE_STORE is
  /// set (any flavor, any build); Google Play in the play flavor when the
  /// install isn't an own build; otherwise never locked.
  static Future<Unlock> forThisInstall(AppStorage storage) async {
    if (fakeStoreMode.isNotEmpty) return Unlock(storage, store: FakeStore(fakeStoreMode, storage));
    if (await locksAsPlay(flavor: appFlavor, info: () => InstallSwitching.info())) {
      return Unlock(storage, store: PlayStore());
    }
    return Unlock(storage);
  }

  /// The play flavor on Android, and not an own build: a build signed with
  /// someone else's key is `.selfbuilt`, which isn't on Play.
  @visibleForTesting
  static Future<bool> locksAsPlay({required String? flavor, required Future<InstallInfo?> Function() info}) async {
    if (flavor != 'play' || !PlatformInfo.isAndroid) return false;
    final install = await info();
    return install != null && !install.ownBuild;
  }

  /// Reads the trial and the cached purchase, then asks the store. Only a
  /// start that would be blocked waits for the store's answer (up to
  /// [firstAnswerWait]); otherwise it arrives in the background.
  Future<void> start({bool watchLifecycle = true}) async {
    final store = _store;
    if (store == null || _started) return;
    _started = true;
    _trialStatus = await _trial.load();
    _cached = (await _storage.readJson(cacheFile) as Map?)?['owned'] == true;
    _publishLocal();
    _changes = store.changes.listen(_apply);
    if (watchLifecycle) _lifecycle = AppLifecycleListener(onShow: () => unawaited(refresh()));
    final asked = _ask();
    if (value.blocked) {
      await asked.timeout(firstAnswerWait, onTimeout: () {});
    } else {
      unawaited(asked);
    }
  }

  /// Checks the trial at once and asks the store again (return to the
  /// foreground, Check my purchase again).
  Future<void> refresh() async {
    if (_store == null || !_started) return;
    _trialStatus = _trial.check();
    _publishLocal();
    await _ask();
  }

  /// Opens the purchase. An owned or pending result applies at once, without
  /// a restart; the store is then asked again.
  Future<BuyResult> buy() async {
    final store = _store;
    if (store == null) return const BuyResult(BuyOutcome.error);
    final result = await store.buy();
    switch (result.outcome) {
      case BuyOutcome.owned:
        await _setOwned();
      case BuyOutcome.pending:
        _pending = true;
        _publishLocal();
      case BuyOutcome.cancelled || BuyOutcome.error:
        break;
    }
    unawaited(_ask());
    return result;
  }

  Future<void> _ask() async {
    final store = _store;
    if (store == null) return;
    await _apply(await store.query());
  }

  Future<void> _apply(StoreState s) async {
    if (s.price != null) _price = s.price;
    if (!s.available) {
      // No answer: the cached purchase decides.
      _publishLocal();
      return;
    }
    _pending = s.pending;
    if (s.owned) {
      await _setOwned();
      return;
    }
    // Play says it isn't owned (never bought, or refunded): the trial again.
    final wasCached = _cached;
    _cached = false;
    _publishLocal();
    if (wasCached) await _storage.delete(cacheFile);
  }

  /// Unlocked at once; the cache is written after.
  Future<void> _setOwned() async {
    _cached = true;
    _pending = false;
    _publishLocal();
    await _storage.writeJson(cacheFile, {'owned': true, 'checked': _now().millisecondsSinceEpoch});
  }

  void _publishLocal() {
    if (_store == null) return;
    if (_cached) {
      value = UnlockState(UnlockStatus.unlocked, price: _price);
    } else if (_pending) {
      value = UnlockState(UnlockStatus.pending, price: _price);
    } else {
      final trial = _trialStatus;
      value = trial.expired
          ? UnlockState(UnlockStatus.expired, price: _price)
          : UnlockState(UnlockStatus.trial, daysLeft: trial.daysLeft, price: _price);
    }
  }

  /// The notice due now, if any, remembered as shown before it returns, so
  /// each shows once: the welcome first, then the 3-days-left reminder and
  /// the last-day one. One per call.
  Future<UnlockNotice?> takeNotice() async {
    if (value.status != UnlockStatus.trial) return null;
    final seen = Map<String, Object?>.from(await _storage.readJson(noticesFile) as Map? ?? const {});
    final days = value.daysLeft;
    UnlockNotice? due;
    if (seen['welcome'] != true) {
      due = UnlockNotice.welcome;
      seen['welcome'] = true;
    } else if (days == 1 && seen['lastDay'] != true) {
      due = UnlockNotice.lastDay;
      // Past 3 days left, that reminder is moot.
      seen['lastDay'] = seen['threeDaysLeft'] = true;
    } else if (days <= 3 && days > 1 && seen['threeDaysLeft'] != true) {
      due = UnlockNotice.threeDaysLeft;
      seen['threeDaysLeft'] = true;
    }
    if (due != null) await _storage.writeJson(noticesFile, seen);
    return due;
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    unawaited(_changes?.cancel());
    _store?.dispose();
    super.dispose();
  }
}
