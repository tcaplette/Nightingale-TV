import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/platform_info.dart';

/// Lays the UI out on a fixed 1920×1080 canvas and scales it to the window,
/// so the guide looks identical on any TV resolution.
class TvCanvas extends StatelessWidget {
  const TvCanvas({super.key, required this.child});

  static const size = Size(1920, 1080);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Material supplies default text styles and what TextField needs;
    // transparent so screens paint their own backgrounds.
    Widget content = ClipRect(child: Material(type: MaterialType.transparency, child: child));
    var data = media.copyWith(size: size);
    if (PlatformInfo.isAndroid) {
      // The on-screen keyboard and system insets arrive in screen units;
      // screens lay out on the canvas. Screens sit above the keyboard, so a
      // focused field scrolls into view, and the keyboard counts as used up
      // (as a Scaffold does) so dialogs don't move up twice.
      final scale = canvasScale(media.size);
      final insets = media.viewInsets / scale;
      data = data.copyWith(
        viewInsets: insets.copyWith(bottom: 0),
        viewPadding: media.viewPadding / scale,
        padding: media.padding / scale,
      );
      content = Padding(padding: EdgeInsets.only(bottom: insets.bottom), child: content);
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(data: data, child: content),
          ),
        ),
      ),
    );
  }

  /// How much the canvas is scaled to fit a [screen] of this size.
  static double canvasScale(Size screen) {
    final scale = min(screen.width / size.width, screen.height / size.height);
    return scale > 0 ? scale : 1;
  }
}

/// Hides the mouse pointer after a few seconds without movement, like a TV.
class AutoHidePointer extends StatefulWidget {
  const AutoHidePointer({super.key, required this.child});

  final Widget child;

  @override
  State<AutoHidePointer> createState() => _AutoHidePointerState();
}

class _AutoHidePointerState extends State<AutoHidePointer> {
  static const _idle = Duration(seconds: 3);
  bool _visible = true;
  Timer? _timer;

  void _moved() {
    _timer?.cancel();
    _timer = Timer(_idle, () {
      if (mounted) setState(() => _visible = false);
    });
    if (!_visible) setState(() => _visible = true);
  }

  @override
  void initState() {
    super.initState();
    _moved();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// Using the keyboard hides the pointer right away.
  bool _onKey(KeyEvent event) {
    if (_visible && event is KeyDownEvent) {
      _timer?.cancel();
      setState(() => _visible = false);
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _visible ? MouseCursor.defer : SystemMouseCursors.none,
      onHover: (_) => _moved(),
      child: Listener(
        onPointerDown: (_) => _moved(),
        onPointerSignal: (_) => _moved(),
        child: widget.child,
      ),
    );
  }
}
