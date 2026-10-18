import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Remote buttons and the keys they stand for. Each one is what the same
/// button on a keyboard or air mouse sends, so every screen already knows
/// what to do with it.
const remoteKeys = <String, (LogicalKeyboardKey, PhysicalKeyboardKey)>{
  'up': (LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
  'down': (LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
  'left': (LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
  'right': (LogicalKeyboardKey.arrowRight, PhysicalKeyboardKey.arrowRight),
  'ok': (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
  'back': (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
  'guide': (LogicalKeyboardKey.keyG, PhysicalKeyboardKey.keyG),
  'menu': (LogicalKeyboardKey.keyM, PhysicalKeyboardKey.keyM),
  'info': (LogicalKeyboardKey.keyI, PhysicalKeyboardKey.keyI),
  'chup': (LogicalKeyboardKey.pageUp, PhysicalKeyboardKey.pageUp),
  'chdown': (LogicalKeyboardKey.pageDown, PhysicalKeyboardKey.pageDown),
  'last': (LogicalKeyboardKey.keyL, PhysicalKeyboardKey.keyL),
  'cc': (LogicalKeyboardKey.keyC, PhysicalKeyboardKey.keyC),
  '0': (LogicalKeyboardKey.digit0, PhysicalKeyboardKey.digit0),
  '1': (LogicalKeyboardKey.digit1, PhysicalKeyboardKey.digit1),
  '2': (LogicalKeyboardKey.digit2, PhysicalKeyboardKey.digit2),
  '3': (LogicalKeyboardKey.digit3, PhysicalKeyboardKey.digit3),
  '4': (LogicalKeyboardKey.digit4, PhysicalKeyboardKey.digit4),
  '5': (LogicalKeyboardKey.digit5, PhysicalKeyboardKey.digit5),
  '6': (LogicalKeyboardKey.digit6, PhysicalKeyboardKey.digit6),
  '7': (LogicalKeyboardKey.digit7, PhysicalKeyboardKey.digit7),
  '8': (LogicalKeyboardKey.digit8, PhysicalKeyboardKey.digit8),
  '9': (LogicalKeyboardKey.digit9, PhysicalKeyboardKey.digit9),
};

/// Delivers [key] to the focused widget and up through its ancestors, the
/// way Flutter delivers a real key press (shortcuts such as arrow-key focus
/// moves and OK-to-activate included). True if something handled it.
bool dispatchKey(LogicalKeyboardKey key, PhysicalKeyboardKey physical) {
  final event = KeyDownEvent(
    physicalKey: physical,
    logicalKey: key,
    character: key.keyLabel.length == 1 ? key.keyLabel : null,
    timeStamp: Duration(microseconds: DateTime.now().microsecondsSinceEpoch),
  );
  for (FocusNode? node = FocusManager.instance.primaryFocus; node != null; node = node.parent) {
    final result = node.onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
    if (result == KeyEventResult.handled) return true;
    if (result == KeyEventResult.skipRemainingHandlers) return false;
  }
  return false;
}
