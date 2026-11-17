import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps focus on a host's dialog while [active] (install-switching,
/// share-accounts). These dialogs can open while the app is still starting:
/// a screen that arrives under one afterwards (the TV screen, after syncing)
/// takes focus with its autofocus, and the remote could no longer reach the
/// dialog. Focus goes back to the dialog on top.
class KeepFocusOnTop {
  KeepFocusOnTop({required this.active});

  /// Whether a dialog of the host is up.
  final bool Function() active;

  /// The last control focused on the top route.
  FocusNode? _onTop;

  void start() => FocusManager.instance.addListener(_check);

  void stop() => FocusManager.instance.removeListener(_check);

  void _check() {
    final node = FocusManager.instance.primaryFocus;
    final focused = node?.context;
    if (!active() || node == null || focused == null || !focused.mounted) return;
    if (ModalRoute.of(focused)?.isCurrent ?? true) {
      _onTop = node;
      return;
    }
    final back = _onCurrentRoute(_onTop) ? _onTop! : _topScope();
    if (back != null) {
      scheduleMicrotask(() {
        back.requestFocus();
        hideKeyboard();
      });
    }
  }

  static bool _onCurrentRoute(FocusNode? node) {
    final context = node?.context;
    return context != null && context.mounted && (ModalRoute.of(context)?.isCurrent ?? false);
  }

  /// When the dialog's autofocus and a screen's under it land in the same
  /// frame, the dialog never shows as focused, so [_onTop] is unset. Its
  /// focus scope still remembers the control it focused: go back to that.
  static FocusScopeNode? _topScope() {
    for (final node in FocusManager.instance.rootScope.descendants) {
      if (node is FocusScopeNode && node.focusedChild != null && _onCurrentRoute(node)) return node;
    }
    return null;
  }

  /// A text field focused under the dialog (a phone's sign-in) leaves its
  /// keyboard over the dialog: hidden.
  static void hideKeyboard() => unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
}
