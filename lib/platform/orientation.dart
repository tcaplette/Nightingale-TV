import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_info.dart';

/// Full screen from the portrait watch screen (portrait-layout): the user
/// asked for the TV screen in landscape. While it's on, the canvas uses the
/// TV layout whatever the window's shape, and Back on the TV screen leaves
/// it.
///
/// On a phone or tablet it asks Android to turn the app sideways (and back
/// upright afterwards); Android tells it when the phone was turned back
/// upright to leave. On TVs and desktops it never touches the channel.
class FullScreen extends ChangeNotifier {
  FullScreen._();

  static final instance = FullScreen._();

  static const _channel = MethodChannel('nightingale_tv/orientation');

  bool _on = false;
  bool _listening = false;

  /// Whether full screen is on.
  bool get isOn => _on;

  static bool get _native => PlatformInfo.isAndroid && !PlatformInfo.isTelevision;

  /// Turns the app to landscape and shows the TV screen.
  Future<void> enter() async {
    if (_on) return;
    _on = true;
    notifyListeners();
    await _invoke('enterFullScreen');
  }

  /// Back to the portrait watch screen, upright until the phone is.
  Future<void> exit() async {
    if (!_on) return;
    _on = false;
    notifyListeners();
    await _invoke('exitFullScreen');
  }

  Future<void> _invoke(String method) async {
    if (!_native) return;
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler(_onCall);
    }
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (e) {
      debugPrint('Orientation unavailable: $e');
    } on MissingPluginException catch (e) {
      debugPrint('Orientation unavailable: $e');
    }
  }

  /// The phone was turned back upright in full screen (with auto-rotate on);
  /// Android has already let go of landscape.
  Future<void> _onCall(MethodCall call) async {
    if (call.method == 'fullScreenEnded' && _on) {
      _on = false;
      notifyListeners();
    }
  }

  /// Off, between tests.
  @visibleForTesting
  void debugReset() {
    _on = false;
    notifyListeners();
  }

  /// As if Android said the phone was turned back upright.
  @visibleForTesting
  Future<void> debugEndedByRotation() => _onCall(const MethodCall('fullScreenEnded'));
}
