import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../remote/key_dispatch.dart';

/// Android's system Back (the remote's button, the phone's button or the
/// back gesture) arrives as a "pop route", not a key press, on Android 13+.
/// This turns it into a Back key press through the focused screen, so every
/// screen does what the Back key does on the PC: closing the guide,
/// cancelling channel-number entry, leaving a text field, a PIN dialog or a
/// sub-screen. Only if no screen takes it does the Navigator pop.
///
/// It must see the pop before `WidgetsApp` does, so it's registered before
/// `runApp` (observers are asked in the order they were added).
class AndroidBackBridge with WidgetsBindingObserver {
  AndroidBackBridge({this._dispatch = dispatchKey});

  final bool Function(LogicalKeyboardKey, PhysicalKeyboardKey) _dispatch;

  @override
  Future<bool> didPopRoute() async => _dispatch(LogicalKeyboardKey.goBack, PhysicalKeyboardKey.browserBack);

  /// For `MaterialApp.onNavigationNotification` on Android: Flutter always
  /// takes Back, so Android never closes the app on its own when the screen
  /// stack is at its root (where the TV screen asks before exiting).
  static bool alwaysHandleBack(NavigationNotification notification) {
    SystemNavigator.setFrameworkHandlesBack(true);
    return true;
  }
}
