import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../platform/platform_info.dart';

/// Which layout the screens draw, and on what canvas (portrait-layout).
///
/// - `tv`: today's 1920×1080 canvas, on TVs, desktops, and phones and
///   tablets whose window is at least as wide as it's tall (or in full
///   screen).
/// - `portrait`: a narrow canvas for phones and tablets held upright,
///   scaled so the shared buttons stay touch-sized.
@immutable
class ScreenLayout {
  const ScreenLayout._(this.isPortrait, this.canvas);

  /// Today's layout on the 1920×1080 canvas.
  static const tv = ScreenLayout._(false, tvCanvas);

  const ScreenLayout.portrait(Size canvas) : this._(true, canvas);

  static const tvCanvas = Size(1920, 1080);

  /// The narrowest a portrait canvas is drawn: a 76-unit button is 48 dp.
  static const minPortraitScale = 0.64;

  /// A portrait canvas is never wider than this, so tablets don't get a
  /// phone layout blown up.
  static const maxPortraitWidth = 1080.0;

  final bool isPortrait;

  /// The canvas the screens lay out on, in canvas units.
  final Size canvas;

  bool get isTv => !isPortrait;

  /// Margin at the sides of a page's content.
  double get gutter => isPortrait ? 32 : 80;

  /// A page body's padding: [tv] in the TV layout; upright, the gutter at
  /// the sides.
  EdgeInsets pagePadding(EdgeInsets tv) => isPortrait ? EdgeInsets.fromLTRB(gutter, 24, gutter, 32) : tv;

  /// The layout for a [window] (in logical pixels): portrait only on an
  /// Android phone or tablet whose window is taller than wide, with
  /// [fullScreen] off.
  static ScreenLayout forWindow(Size window, {required bool fullScreen}) {
    final portrait = PlatformInfo.isAndroid &&
        !PlatformInfo.isTelevision &&
        !fullScreen &&
        window.height > window.width;
    return portrait ? ScreenLayout.portrait(window / portraitScale(window)) : tv;
  }

  /// How much a portrait canvas is scaled up to fill a [window].
  static double portraitScale(Size window) => max(window.width / maxPortraitWidth, minPortraitScale);

  /// The layout of the canvas [context] is on; the TV layout outside one.
  static ScreenLayout of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenLayoutScope>()?.layout ?? tv;

  /// On a phone or tablet in the TV layout, the keyboard leaves too little
  /// of the canvas for the field being edited: content pinned around the
  /// lists gives way until it closes. (Upright the canvas has room, and a TV
  /// keeps its layout.)
  static bool keyboardTakesRoom(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScreenLayoutScope>();
    return scope != null && scope.keyboardUp && scope.layout.isTv && PlatformInfo.hasTouch;
  }

  @override
  bool operator ==(Object other) => other is ScreenLayout && other.isPortrait == isPortrait && other.canvas == canvas;

  @override
  int get hashCode => Object.hash(isPortrait, canvas);
}

/// Provides the [ScreenLayout] below the canvas.
class ScreenLayoutScope extends InheritedWidget {
  const ScreenLayoutScope({super.key, required this.layout, this.keyboardUp = false, required super.child});

  final ScreenLayout layout;

  /// The on-screen keyboard is taking room from the canvas.
  final bool keyboardUp;

  @override
  bool updateShouldNotify(ScreenLayoutScope oldWidget) =>
      layout != oldWidget.layout || keyboardUp != oldWidget.keyboardUp;
}
