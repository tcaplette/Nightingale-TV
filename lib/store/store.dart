import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/app_storage.dart';
import '../platform/platform_info.dart';

/// The stand-in store's mode (play-unlock D7): `buy`, `pending`, `cancel`,
/// `error`, `offline` or `redeem`; empty for the real store. Release builds never set
/// it (tool/build_apk.sh and tool/build_bundle.sh refuse to).
const fakeStoreMode = String.fromEnvironment('NTV_FAKE_STORE');

/// What the store says about the unlock purchase.
@immutable
class StoreState {
  const StoreState({required this.available, this.owned = false, this.pending = false, this.price});

  /// No answer from the store (offline, Play services busy, or no store).
  const StoreState.unavailable() : this(available: false);

  factory StoreState.fromMap(Map<Object?, Object?> m) => StoreState(
        available: m['available'] == true,
        owned: m['owned'] == true,
        pending: m['pending'] == true,
        price: m['price'] as String?,
      );

  /// Whether the store answered. When it didn't, [owned] and [pending] say
  /// nothing, and the cached purchase decides.
  final bool available;
  final bool owned;
  final bool pending;

  /// Play's formatted price for this device's country, or null until Play
  /// has given one.
  final String? price;

  @override
  bool operator ==(Object other) =>
      other is StoreState &&
      other.available == available &&
      other.owned == owned &&
      other.pending == pending &&
      other.price == price;

  @override
  int get hashCode => Object.hash(available, owned, pending, price);

  @override
  String toString() => 'StoreState(available: $available, owned: $owned, pending: $pending, price: $price)';
}

/// How a purchase ended.
enum BuyOutcome { owned, pending, cancelled, error }

@immutable
class BuyResult {
  const BuyResult(this.outcome);

  final BuyOutcome outcome;

  @override
  String toString() => 'BuyResult($outcome)';
}

/// Where the unlock purchase is bought and restored (play-unlock D3).
abstract class Store {
  /// What's been bought, and the price.
  Future<StoreState> query();

  /// Opens the purchase and waits for how it ends.
  Future<BuyResult> buy();

  /// Purchases that change on their own, such as a pending one completing.
  Stream<StoreState> get changes;

  /// Takes the user to where a Play promo code is redeemed
  /// (play-promo-codes D1, D3). False when it couldn't be opened (typical on
  /// a TV), so the app says where to redeem instead. A redeemed code comes
  /// back as an ordinary purchase: through [changes] while the app runs, or
  /// from the next [query].
  Future<bool> redeem();

  void dispose();
}

/// Play's page for redeeming a promo code.
const playRedeemUrl = 'https://play.google.com/redeem';

/// Google Play, through the play flavor's StoreBridge.kt. The free flavor's
/// stub answers that there's no store.
class PlayStore implements Store {
  PlayStore({MethodChannel? channel, Future<bool> Function(String url)? openUrl})
      : _channel = channel ?? const MethodChannel('nightingale_tv/store'),
        _openUrl = openUrl ?? PlatformInfo.openUrl {
    _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;
  final Future<bool> Function(String url) _openUrl;
  final _changes = StreamController<StoreState>.broadcast();
  Completer<BuyResult>? _buying;

  @override
  Stream<StoreState> get changes => _changes.stream;

  @override
  Future<StoreState> query() async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>('query');
      return m == null ? const StoreState.unavailable() : StoreState.fromMap(m);
    } on Object catch (e) {
      debugPrint('Store unavailable: $e');
      return const StoreState.unavailable();
    }
  }

  @override
  Future<BuyResult> buy() async {
    if (_buying case final buying?) return buying.future;
    final buying = _buying = Completer<BuyResult>();
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>('buy');
      if (m?['launched'] != true) {
        _buying = null;
        return const BuyResult(BuyOutcome.error);
      }
    } on Object catch (e) {
      debugPrint('Purchase not started: $e');
      _buying = null;
      return const BuyResult(BuyOutcome.error);
    }
    return buying.future;
  }

  @override
  Future<bool> redeem() => _openUrl(playRedeemUrl);

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'purchaseChanged') return;
    final m = (call.arguments as Map<Object?, Object?>?) ?? const {};
    final outcome = switch (m['result']) {
      'owned' => BuyOutcome.owned,
      'pending' => BuyOutcome.pending,
      'cancelled' => BuyOutcome.cancelled,
      _ => BuyOutcome.error,
    };
    if (outcome == BuyOutcome.owned || outcome == BuyOutcome.pending) {
      _changes.add(StoreState(available: true, owned: m['owned'] == true, pending: m['pending'] == true));
    }
    final buying = _buying;
    _buying = null;
    if (buying != null && !buying.isCompleted) buying.complete(BuyResult(outcome));
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_changes.close());
  }
}

/// The stand-in store (play-unlock D7), for testing without Google Play:
/// price "$4.99", and Unlock does what [mode] says. What it "sold" is kept in
/// `store/fake_store.json`, so a restart finds it as Play would.
class FakeStore implements Store {
  FakeStore(this.mode, this._storage, {this.pendingFor = const Duration(seconds: 5)});

  static const price = r'$4.99';
  static const file = 'store/fake_store.json';

  /// buy, pending, cancel, error, offline or redeem.
  final String mode;
  final AppStorage _storage;

  /// How long `pending` waits before the purchase completes.
  final Duration pendingFor;

  final _changes = StreamController<StoreState>.broadcast();
  Timer? _pending;

  @override
  Stream<StoreState> get changes => _changes.stream;

  Future<bool> get _owned async => (await _storage.readJson(file) as Map?)?['owned'] == true;

  @override
  Future<StoreState> query() async {
    if (mode == 'offline') return const StoreState.unavailable();
    return StoreState(available: true, owned: await _owned, pending: _pending != null, price: price);
  }

  @override
  Future<BuyResult> buy() async {
    switch (mode) {
      case 'buy':
        await _storage.writeJson(file, {'owned': true});
        return const BuyResult(BuyOutcome.owned);
      case 'pending':
        _pending ??= Timer(pendingFor, () async {
          _pending = null;
          await _storage.writeJson(file, {'owned': true});
          if (!_changes.isClosed) _changes.add(const StoreState(available: true, owned: true, price: price));
        });
        return const BuyResult(BuyOutcome.pending);
      case 'cancel':
        return const BuyResult(BuyOutcome.cancelled);
      default:
        return const BuyResult(BuyOutcome.error);
    }
  }

  /// In mode `redeem`, a code "redeemed on another device": owned from now
  /// on, but nothing tells the app, so only the next query (Check my
  /// purchase again, a return to the foreground, a start) finds it. Never
  /// opens anything, so the app says where to redeem.
  @override
  Future<bool> redeem() async {
    if (mode == 'redeem') await _storage.writeJson(file, {'owned': true});
    return false;
  }

  @override
  void dispose() {
    _pending?.cancel();
    unawaited(_changes.close());
  }
}
