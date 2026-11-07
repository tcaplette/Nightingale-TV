import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/orientation.dart';
import '../../platform/platform_info.dart';
import 'screen_layout.dart';

/// Lays the UI out on a fixed 1920×1080 canvas and scales it to the window,
/// so the guide looks identical on any TV resolution. On a phone or tablet
/// held upright the canvas is the window's shape instead, scaled for touch
/// (portrait-layout); the [ScreenLayout] below says which.
class TvCanvas extends StatefulWidget {
  const TvCanvas({super.key, required this.child});

  static const size = ScreenLayout.tvCanvas;

  final Widget child;

  @override
  State<TvCanvas> createState() => _TvCanvasState();

  /// How much the canvas is scaled to fit a [screen] of this size.
  static double canvasScale(Size screen, {bool portrait = false}) {
    if (portrait) return ScreenLayout.portraitScale(screen);
    final scale = min(screen.width / size.width, screen.height / size.height);
    return scale > 0 ? scale : 1;
  }
}

class _TvCanvasState extends State<TvCanvas> {
  /// The layout the system bars were last set for (Android).
  bool? _barsFor;

  @override
  void initState() {
    super.initState();
    FullScreen.instance.addListener(_changed);
  }

  @override
  void dispose() {
    FullScreen.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  /// The bars show while browsing upright, and hide in the TV layout, as
  /// today (only when the layout changes, so a swipe can bring them back).
  void _setSystemBars(bool portrait) {
    if (!PlatformInfo.isAndroid || _barsFor == portrait) return;
    _barsFor = portrait;
    if (portrait) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = ScreenLayout.forWindow(media.size, fullScreen: FullScreen.instance.isOn);
    _setSystemBars(layout.isPortrait);
    final size = layout.canvas;
    // Material supplies default text styles and what TextField needs;
    // transparent so screens paint their own backgrounds.
    Widget content = ClipRect(child: Material(type: MaterialType.transparency, child: widget.child));
    // Upright, dialogs keep to the page's margins. (A Theme in both
    // layouts: the screens below must keep their place when the layout
    // changes, or they'd be built anew.)
    final theme = Theme.of(context);
    content = Theme(
      data: layout.isPortrait
          ? theme.copyWith(
              dialogTheme: theme.dialogTheme
                  .copyWith(insetPadding: EdgeInsets.symmetric(horizontal: layout.gutter, vertical: 24)))
          : theme,
      child: content,
    );
    var data = media.copyWith(size: size);
    var keyboardUp = false;
    if (PlatformInfo.isAndroid) {
      // The on-screen keyboard and system insets arrive in screen units;
      // screens lay out on the canvas. Screens sit above the keyboard, so a
      // focused field scrolls into view, and the keyboard counts as used up
      // (as a Scaffold does) so dialogs don't move up twice.
      final scale = TvCanvas.canvasScale(media.size, portrait: layout.isPortrait);
      final insets = media.viewInsets / scale;
      data = data.copyWith(
        viewInsets: insets.copyWith(bottom: 0),
        viewPadding: media.viewPadding / scale,
        padding: media.padding / scale,
      );
      keyboardUp = insets.bottom > 0;
      content = Padding(padding: EdgeInsets.only(bottom: insets.bottom), child: content);
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(data: data, child: ScreenLayoutScope(layout: layout, keyboardUp: keyboardUp, child: content)),
          ),
        ),
      ),
    );
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
