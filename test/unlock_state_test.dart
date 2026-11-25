import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/platform/install_info.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/store/store.dart';
import 'package:nightingale_tv/store/trial.dart';
import 'package:nightingale_tv/store/unlock.dart';

/// A store that answers what the test sets, and counts its calls.
class _TestStore implements Store {
  StoreState answer = const StoreState(available: true, price: r'$4.99');
  BuyResult buyResult = const BuyResult(BuyOutcome.owned);
  int queries = 0;
  int buys = 0;
  final _changes = StreamController<StoreState>.broadcast();

  /// Holds the next query's answer until completed.
  Completer<void>? hold;

  @override
  Stream<StoreState> get changes => _changes.stream;

  void change(StoreState s) => _changes.add(s);

  @override
  Future<StoreState> query() async {
    queries++;
    if (hold case final h?) await h.future;
    return answer;
  }

  @override
  Future<BuyResult> buy() async {
    buys++;
    return buyResult;
  }

  @override
  Future<bool> redeem() async => false;

  @override
  void dispose() => unawaited(_changes.close());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppStorage storage;
  late DateTime now;
  late _TestStore store;
  final unlocks = <Unlock>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_unlock');
    storage = await AppStorage.at(dir);
    now = DateTime.utc(2026, 11, 1, 12);
    store = _TestStore();
  });

  tearDown(() async {
    for (final u in unlocks) {
      u.dispose();
    }
    unlocks.clear();
    await storage.flush();
    PlatformInfo.debugOverride = null;
    await dir.delete(recursive: true);
  });

  Unlock make({Store? withStore, int offsetDays = 0, bool noStore = false}) {
    final u = Unlock(storage, store: noStore ? null : (withStore ?? store), now: () => now, offsetDays: offsetDays);
    unlocks.add(u);
    return u;
  }

  /// The store's answer, and the files it writes, all in.
  Future<void> settle() async {
    await pumpEventQueue();
    await storage.flush();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await storage.flush();
  }

  /// A new start of the app: what the last one wrote, read again.
  Future<Unlock> restart({int offsetDays = 0}) async {
    await storage.flush();
    final u = make(offsetDays: offsetDays);
    await u.start(watchLifecycle: false);
    await settle();
    return u;
  }

  group('the trial', () {
    test('first start: the trial starts with 14 days left', () async {
      final u = await restart();
      expect(u.value.status, UnlockStatus.trial);
      expect(u.value.daysLeft, 14);
      expect(u.value.price, r'$4.99');
      await storage.flush();
      final saved = await storage.readJson(TrialClock.file) as Map;
      expect(saved['start'], now.millisecondsSinceEpoch);
    });

    test('days left round up: 13 days and an hour in, 1 day left', () async {
      await restart();
      now = now.add(const Duration(days: 13, hours: 1));
      expect((await restart()).value.daysLeft, 1);
      now = now.add(const Duration(hours: 1));
      expect((await restart()).value.daysLeft, 1);
    });

    test('14 days in is day 15: expired', () async {
      await restart();
      now = now.add(const Duration(days: 14));
      final u = await restart();
      expect(u.value.status, UnlockStatus.expired);
      expect(u.value.blocked, isTrue);
    });

    test('setting the clock back adds no time', () async {
      await restart();
      now = now.add(const Duration(days: 10));
      expect((await restart()).value.daysLeft, 4);
      now = now.subtract(const Duration(days: 30));
      expect((await restart()).value.daysLeft, 4);
      // The clock stood still while it was behind; time counts again from
      // when it's past the last seen time.
      now = now.add(const Duration(days: 31));
      expect((await restart()).value.daysLeft, 3);
    });

    test('NTV_TRIAL_OFFSET_DAYS moves the start back', () async {
      await restart();
      expect((await restart(offsetDays: 11)).value.daysLeft, 3);
      expect((await restart(offsetDays: 13)).value.daysLeft, 1);
      expect((await restart(offsetDays: 15)).value.status, UnlockStatus.expired);
      // The file itself is unchanged: without the offset it is day 1 again.
      expect((await restart()).value.daysLeft, 14);
    });

    test('coming back to the foreground re-checks the trial', () async {
      final u = await restart();
      now = now.add(const Duration(days: 15));
      expect(u.value.status, UnlockStatus.trial);
      await u.refresh();
      expect(u.value.status, UnlockStatus.expired);
    });
  });

  group('the purchase', () {
    test('owned: unlocked and cached, and a restart stays unlocked', () async {
      store.answer = const StoreState(available: true, owned: true, price: r'$4.99');
      expect((await restart()).value.status, UnlockStatus.unlocked);
      await storage.flush();
      expect((await storage.readJson(Unlock.cacheFile) as Map)['owned'], isTrue);
    });

    test('the cache is honoured when Play can\'t be reached, even with the trial over', () async {
      store.answer = const StoreState(available: true, owned: true);
      await restart();
      now = now.add(const Duration(days: 40));
      store.answer = const StoreState.unavailable();
      expect((await restart()).value.status, UnlockStatus.unlocked);
    });

    test('offline with no purchase follows the trial', () async {
      store.answer = const StoreState.unavailable();
      final u = await restart();
      expect(u.value.status, UnlockStatus.trial);
      expect(u.value.price, isNull);
    });

    test('a refund clears the cache: the trial again, expired when it\'s over', () async {
      store.answer = const StoreState(available: true, owned: true);
      await restart();
      now = now.add(const Duration(days: 20));
      store.answer = const StoreState(available: true);
      final u = await restart();
      expect(u.value.status, UnlockStatus.expired);
      await storage.flush();
      expect(await storage.readJson(Unlock.cacheFile), isNull);
      // Offline afterwards, it stays locked.
      store.answer = const StoreState.unavailable();
      expect((await restart()).value.status, UnlockStatus.expired);
    });

    test('pending: not locked after the trial, unlocked when it completes', () async {
      await restart();
      now = now.add(const Duration(days: 20));
      store.answer = const StoreState(available: true, pending: true);
      final u = await restart();
      expect(u.value.status, UnlockStatus.pending);
      expect(u.value.blocked, isFalse);
      store.change(const StoreState(available: true, owned: true));
      await settle();
      expect(u.value.status, UnlockStatus.unlocked);
    });

    test('buying unlocks at once', () async {
      final u = await restart();
      // Play reports the purchase from then on.
      store.answer = const StoreState(available: true, owned: true);
      final result = await u.buy();
      expect(result.outcome, BuyOutcome.owned);
      expect(u.value.status, UnlockStatus.unlocked);
      expect(store.buys, 1);
      await settle();
      expect(u.value.status, UnlockStatus.unlocked);
    });

    test('a refund answer right after a purchase clears the cache cleanly', () async {
      final u = await restart();
      await u.buy();
      // The cache write and the delete queue on the one file.
      await settle();
      expect(u.value.status, UnlockStatus.trial);
      expect(await storage.readJson(Unlock.cacheFile), isNull);
    });

    test('a cancelled or failed purchase changes nothing', () async {
      await restart();
      now = now.add(const Duration(days: 15));
      final u = await restart();
      for (final outcome in [BuyOutcome.cancelled, BuyOutcome.error]) {
        store.buyResult = BuyResult(outcome);
        expect((await u.buy()).outcome, outcome);
        await pumpEventQueue();
        expect(u.value.status, UnlockStatus.expired);
      }
    });

    test('a pending purchase from the Unlock screen opens it', () async {
      await restart();
      now = now.add(const Duration(days: 15));
      final u = await restart();
      store.buyResult = const BuyResult(BuyOutcome.pending);
      store.answer = const StoreState(available: true, pending: true);
      await u.buy();
      expect(u.value.status, UnlockStatus.pending);
    });

    test('a start that would be blocked waits for Play\'s answer', () async {
      await restart();
      now = now.add(const Duration(days: 15));
      await storage.flush();
      store.answer = const StoreState(available: true, owned: true);
      final hold = store.hold = Completer<void>();
      final u = make();
      var started = false;
      unawaited(u.start(watchLifecycle: false).then((_) => started = true));
      await pumpEventQueue();
      expect(started, isFalse);
      hold.complete();
      await settle();
      expect(started, isTrue);
      expect(u.value.status, UnlockStatus.unlocked);
    });
  });

  group('Google Play', () {
    const channel = MethodChannel('nightingale_tv/store');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() => messenger.setMockMethodCallHandler(
        channel, (call) async => call.method == 'query' ? {'available': true, 'owned': false} : null));
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    /// Play calling the app, as StoreBridge.kt does.
    Future<void> fromPlay(String method, Map<String, Object?> args) async {
      final reply = Completer<void>();
      await messenger.handlePlatformMessage(
          channel.name, channel.codec.encodeMethodCall(MethodCall(method, args)), (_) => reply.complete());
      await reply.future;
    }

    test('a purchase Play reports with no purchase open (a redeemed code) unlocks at once and is cached', () async {
      final u = make(withStore: PlayStore(), offsetDays: 15);
      await u.start(watchLifecycle: false);
      await settle();
      expect(u.value.status, UnlockStatus.expired);
      await fromPlay('purchaseChanged', {'result': 'owned', 'owned': true, 'pending': false});
      await settle();
      expect(u.value.status, UnlockStatus.unlocked);
      expect((await storage.readJson(Unlock.cacheFile) as Map)['owned'], isTrue);
    });

    test('redeem opens Play\'s redeem page and says whether it opened', () async {
      final opened = <String>[];
      for (final answer in [true, false]) {
        final u = make(withStore: PlayStore(openUrl: (url) async {
          opened.add(url);
          return answer;
        }));
        await u.start(watchLifecycle: false);
        final before = u.value;
        expect(await u.redeem(), answer);
        expect(u.value, before);
      }
      expect(opened, ['https://play.google.com/redeem', 'https://play.google.com/redeem']);
    });
  });

  group('which installs are locked', () {
    test('no store (free flavor, own build, Linux): never locked and nothing asked', () async {
      final u = make(noStore: true);
      await u.start(watchLifecycle: false);
      now = now.add(const Duration(days: 100));
      await u.refresh();
      expect(u.value, UnlockState.notLocked);
      expect(u.value.locking, isFalse);
      expect((await u.buy()).outcome, BuyOutcome.error);
      expect(await u.takeNotice(), isNull);
      expect(store.queries, 0);
      await storage.flush();
      expect(await storage.readJson(TrialClock.file), isNull);
    });

    test('only the play flavor of an install that isn\'t an own build, on Android', () async {
      var asked = 0;
      Future<InstallInfo?> info(bool own) async {
        asked++;
        return InstallInfo(ownBuild: own);
      }

      PlatformInfo.debugOverride = TargetPlatform.android;
      expect(await Unlock.locksAsPlay(flavor: 'free', info: () => info(false)), isFalse);
      expect(await Unlock.locksAsPlay(flavor: null, info: () => info(false)), isFalse);
      // The free flavor never even asks what install it is.
      expect(asked, 0);
      expect(await Unlock.locksAsPlay(flavor: 'play', info: () => info(true)), isFalse);
      expect(await Unlock.locksAsPlay(flavor: 'play', info: () async => null), isFalse);
      expect(await Unlock.locksAsPlay(flavor: 'play', info: () => info(false)), isTrue);
      PlatformInfo.debugOverride = TargetPlatform.linux;
      expect(await Unlock.locksAsPlay(flavor: 'play', info: () => info(false)), isFalse);
    });
  });

  group('notices', () {
    test('the welcome once, then 3 days left once, then the last day once', () async {
      var u = await restart();
      expect(await u.takeNotice(), UnlockNotice.welcome);
      expect(await u.takeNotice(), isNull);
      u = await restart();
      expect(await u.takeNotice(), isNull);
      u = await restart(offsetDays: 11);
      expect(await u.takeNotice(), UnlockNotice.threeDaysLeft);
      u = await restart(offsetDays: 11);
      expect(await u.takeNotice(), isNull);
      u = await restart(offsetDays: 13);
      expect(await u.takeNotice(), UnlockNotice.lastDay);
      u = await restart(offsetDays: 13);
      expect(await u.takeNotice(), isNull);
    });

    test('reaching the last day first skips the 3-days-left reminder', () async {
      var u = await restart();
      await u.takeNotice();
      u = await restart(offsetDays: 13);
      expect(await u.takeNotice(), UnlockNotice.lastDay);
      u = await restart(offsetDays: 12);
      expect(await u.takeNotice(), isNull);
    });

    test('none once unlocked', () async {
      store.answer = const StoreState(available: true, owned: true);
      final u = await restart();
      expect(await u.takeNotice(), isNull);
    });
  });

  group('the stand-in store', () {
    test('buy is remembered across restarts, offline keeps the cache', () async {
      final fake = FakeStore('buy', storage);
      final u = make(withStore: fake);
      await u.start(watchLifecycle: false);
      await pumpEventQueue();
      expect(u.value.price, FakeStore.price);
      await u.buy();
      expect(u.value.status, UnlockStatus.unlocked);
      await storage.flush();
      expect(await FakeStore('buy', storage).query(), const StoreState(available: true, owned: true, price: FakeStore.price));
      expect(await FakeStore('offline', storage).query(), const StoreState.unavailable());
    });

    test('pending completes after its wait', () async {
      final fake = FakeStore('pending', storage, pendingFor: const Duration(milliseconds: 20));
      final u = make(withStore: fake);
      await u.start(watchLifecycle: false);
      await u.buy();
      expect(u.value.status, UnlockStatus.pending);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await settle();
      expect(u.value.status, UnlockStatus.unlocked);
    });

    test('redeem records the unlock without telling the app: expired until the next check', () async {
      final fake = FakeStore('redeem', storage);
      final u = make(withStore: fake, offsetDays: 15);
      await u.start(watchLifecycle: false);
      await settle();
      expect(u.value.status, UnlockStatus.expired);
      expect(await u.redeem(), isFalse, reason: 'opens nothing, so the app says where to redeem');
      await settle();
      expect(u.value.status, UnlockStatus.expired);
      await u.refresh();
      await settle();
      expect(u.value.status, UnlockStatus.unlocked);
      expect((await storage.readJson(Unlock.cacheFile) as Map)['owned'], isTrue);
    });

    test('other modes redeem nothing', () async {
      for (final mode in ['buy', 'pending', 'cancel', 'error', 'offline']) {
        final fake = FakeStore(mode, storage);
        expect(await fake.redeem(), isFalse, reason: mode);
        await storage.flush();
        expect(await storage.readJson(FakeStore.file), isNull, reason: mode);
        fake.dispose();
      }
    });

    test('cancel and error leave it as it was', () async {
      for (final mode in ['cancel', 'error', 'offline']) {
        final u = make(withStore: FakeStore(mode, storage));
        await u.start(watchLifecycle: false);
        final before = u.value.status;
        await u.buy();
        await pumpEventQueue();
        expect(u.value.status, before, reason: mode);
      }
    });
  });
}
