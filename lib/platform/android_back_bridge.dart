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
///
/// Some devices (Android TV remotes among them) deliver one press of Back
/// twice: as a key press, which goes to the screens as usual, and a moment
/// later as a pop. [handleKey] (a `HardwareKeyboard` handler) notes the key,
/// and [BackKeyWatcher] whether any screen took it, so the pop that follows
/// doesn't go back a second time: it's dropped, or (no screen took the key)
/// left to the Navigator.
class AndroidBackBridge with WidgetsBindingObserver {
  AndroidBackBridge({this._dispatch = dispatchKey, this._clock = DateTime.now});

  final bool Function(LogicalKeyboardKey, PhysicalKeyboardKey) _dispatch;
  final DateTime Function() _clock;

  /// How long after a press's key its pop may come.
  static const samePress = Duration(milliseconds: 500);

  /// A press that came as a key, whose pop may follow, and whether a screen
  /// took it.
  ({DateTime at, bool handled})? _awaitingPop;

  /// [BackKeyWatcher]'s place in the focus tree, above every screen.
  final watcherNode = FocusNode(debugLabel: 'back watcher', canRequestFocus: false, skipTraversal: true);

  static bool isBack(KeyEvent event) =>
      event.logicalKey == LogicalKeyboardKey.goBack || event.logicalKey == LogicalKeyboardKey.browserBack;

  @override
  Future<bool> didPopRoute() async {
    if (_awaitingPop case final key? when _clock().difference(key.at) < samePress) {
      _awaitingPop = null;
      // The same press, already delivered to the screens as a key: the
      // Navigator pops only if none took it (a dialog, say).
      return key.handled;
    }
    return _dispatch(LogicalKeyboardKey.goBack, PhysicalKeyboardKey.browserBack);
  }

  /// For `HardwareKeyboard.instance.addHandler`: notes a Back key, which
  /// then goes to the screens as usual.
  bool handleKey(KeyEvent event) {
    if (event is KeyDownEvent && isBack(event)) {
      // A screen may take it only if one has focus; the watcher says if
      // none did.
      final focus = FocusManager.instance.primaryFocus;
      final onScreen = focus != null && focus.ancestors.contains(watcherNode);
      _awaitingPop = (at: _clock(), handled: onScreen);
    }
    return false;
  }

  /// No screen took the Back key just noted ([BackKeyWatcher]).
  void unhandledKey() {
    if (_awaitingPop case final key?) _awaitingPop = (at: key.at, handled: false);
  }

  /// For `MaterialApp.onNavigationNotification` on Android: Flutter always
  /// takes Back, so Android never closes the app on its own when the screen
  /// stack is at its root (where the TV screen asks before exiting).
  static bool alwaysHandleBack(NavigationNotification notification) {
    SystemNavigator.setFrameworkHandlesBack(true);
    return true;
  }
}

/// Above every screen: hears a Back key only when no screen took it, and
/// tells [bridge].
class BackKeyWatcher extends StatelessWidget {
  const BackKeyWatcher({super.key, required this.bridge, required this.child});

  final AndroidBackBridge bridge;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: bridge.watcherNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && AndroidBackBridge.isBack(event)) bridge.unhandledKey();
          return KeyEventResult.ignored;
        },
        child: child,
      );
}
