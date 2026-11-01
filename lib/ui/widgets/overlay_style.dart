import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../channels/retro.dart';
import '../../theme/tv_theme.dart';
import 'retro_frame.dart';

/// The overlay theme on the TV screen (retro-presentation D9). Anything
/// outside one, such as export's offscreen cards, stays Standard.
class OverlayThemeScope extends InheritedWidget {
  const OverlayThemeScope({super.key, required this.theme, this.accent, required super.child});

  /// The channel's theme, with its accent from [retro] and [icon].
  factory OverlayThemeScope.of({Key? key, required ResolvedRetro retro, ChannelIcon? icon, required Widget child}) =>
      OverlayThemeScope(
        key: key,
        theme: retro.overlay,
        accent: retro.accent == OverlayAccent.channel ? channelColor(icon) : null,
        child: child,
      );

  final OverlayThemeName theme;

  /// The channel's color, replacing the theme's accent.
  final Color? accent;

  @override
  bool updateShouldNotify(OverlayThemeScope oldWidget) => oldWidget.theme != theme || oldWidget.accent != accent;
}

/// An overlay theme as data: colors, fonts, panels and the channel number's
/// format. Layout, focus and timing live in the widgets and don't change.
class OverlayStyle {
  const OverlayStyle._(this.theme, this._g, this.accent);

  /// The style of the theme in force around [context].
  factory OverlayStyle.of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OverlayThemeScope>();
    return OverlayStyle.named(scope?.theme ?? OverlayThemeName.standard, context.guide, accent: scope?.accent);
  }

  factory OverlayStyle.named(OverlayThemeName theme, GuideTheme g, {Color? accent}) => OverlayStyle._(
        theme,
        g,
        accent ??
            switch (theme) {
              OverlayThemeName.standard => g.accent,
              OverlayThemeName.vcr => const Color(0xFFFFFFFF),
              OverlayThemeName.cableBox => _cableYellow,
              OverlayThemeName.stationIdent => _identGold,
            },
      );

  static const vcrFont = 'VT323';
  static const _cableBlue = Color(0xFF0A2A8C);
  static const _cableYellow = Color(0xFFFFE14D);
  static const _identGold = Color(0xFFFFC62B);
  static const _identDeep = Color(0xFF2A0E6B);
  static const _identHot = Color(0xFFB0186E);
  static const _vcrBlue = Color(0xFF1414C8);
  static const _shadow = [
    // A hard outline, so it reads on any picture.
    Shadow(color: Colors.black, offset: Offset(2, 2)),
    Shadow(color: Colors.black, offset: Offset(-2, 2)),
    Shadow(color: Colors.black, offset: Offset(2, -2)),
    Shadow(color: Colors.black, offset: Offset(-2, -2)),
    Shadow(color: Colors.black, blurRadius: 6),
  ];

  final OverlayThemeName theme;
  final GuideTheme _g;

  /// The accent: the theme's, or the channel's color.
  final Color accent;

  bool get _standard => theme == OverlayThemeName.standard;
  bool get _vcr => theme == OverlayThemeName.vcr;

  Color get text => _standard ? _g.text : Colors.white;

  Color get textDim => switch (theme) {
        OverlayThemeName.standard => _g.textDim,
        OverlayThemeName.vcr => const Color(0xFFE6E6E6),
        OverlayThemeName.cableBox => const Color(0xFFCFDAFF),
        OverlayThemeName.stationIdent => const Color(0xFFE9DDF7),
      };

  /// What's written on the accent color.
  Color get onAccent => switch (theme) {
        OverlayThemeName.standard => _g.onFocus,
        _ => accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
      };

  Color get progressTrack => _standard ? _g.cell : Colors.white.withValues(alpha: 0.25);

  TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color? color}) {
    if (_vcr) return _vcrText(size, color);
    return _g.display(size, weight: weight, color: color ?? text);
  }

  TextStyle body(double size, {FontWeight weight = FontWeight.w500, Color? color}) {
    if (_vcr) return _vcrText(size, color);
    return _g.body(size, weight: weight, color: color ?? text);
  }

  /// VT323 runs small and thin, so it's drawn larger, with a hard shadow
  /// since VCR text has no panel behind it. The app's font covers what the
  /// pixel font doesn't.
  TextStyle _vcrText(double size, Color? color) => TextStyle(
        fontFamily: vcrFont,
        fontFamilyFallback: const ['Barlow'],
        fontSize: size * 1.15,
        height: 1.05,
        color: color ?? text,
        shadows: _shadow,
      );

  /// A corner card's panel.
  BoxDecoration get panel => switch (theme) {
        OverlayThemeName.standard => BoxDecoration(
            color: _g.panel.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(_g.radius * 2),
            border: Border(left: BorderSide(color: accent, width: 8)),
          ),
        OverlayThemeName.vcr => const BoxDecoration(),
        OverlayThemeName.cableBox => BoxDecoration(
            color: _cableBlue,
            border: Border(left: BorderSide(color: accent, width: 8)),
          ),
        OverlayThemeName.stationIdent => BoxDecoration(
            gradient: const LinearGradient(colors: [_identDeep, _identHot]),
            border: Border(bottom: BorderSide(color: accent, width: 6)),
          ),
      };

  /// The channel banner's background.
  BoxDecoration get banner => switch (theme) {
        OverlayThemeName.standard => BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_g.backgroundTop.withValues(alpha: 0.0), _g.backgroundBottom.withValues(alpha: 0.95)],
              stops: const [0, 0.35],
            ),
          ),
        OverlayThemeName.vcr => const BoxDecoration(),
        OverlayThemeName.cableBox => BoxDecoration(
            color: _cableBlue,
            border: Border(top: BorderSide(color: accent, width: 6)),
          ),
        OverlayThemeName.stationIdent => BoxDecoration(
            gradient: LinearGradient(
              colors: [_identDeep, _identHot.withValues(alpha: 0.92), _identHot.withValues(alpha: 0.35)],
              stops: const [0, 0.65, 1],
            ),
            border: Border(top: BorderSide(color: accent, width: 6)),
          ),
      };

  /// The tile behind the channel's number in the banner.
  BoxDecoration get numberTile => _vcr
      ? const BoxDecoration()
      : BoxDecoration(color: accent, borderRadius: BorderRadius.circular(_standard ? _g.radius * 2 : 0));

  Color get numberOnTile => _vcr ? accent : onAccent;

  /// A full-screen status card's background.
  Decoration get backdrop => switch (theme) {
        OverlayThemeName.standard => _g.backdrop,
        OverlayThemeName.vcr => const BoxDecoration(color: _vcrBlue),
        OverlayThemeName.cableBox => const BoxDecoration(color: _cableBlue),
        OverlayThemeName.stationIdent => const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_identDeep, _identHot],
            ),
          ),
      };

  /// The channel number in this theme's format; anything but a whole number
  /// (digits being typed) stays as it is.
  String number(String n) {
    if (int.tryParse(n) == null) return n;
    return switch (theme) {
      OverlayThemeName.vcr => 'CH ${n.padLeft(2, '0')}',
      OverlayThemeName.cableBox => n.padLeft(3, '0'),
      _ => n,
    };
  }

  /// The channel-number shadows on the picture.
  List<Shadow> get osdShadows => _vcr ? _shadow : const [Shadow(color: Colors.black, blurRadius: 12, offset: Offset(3, 3))];

  /// What goes behind the logo bug, inside its box.
  BoxDecoration? get logoPlate => switch (theme) {
        OverlayThemeName.cableBox => const BoxDecoration(color: _cableBlue),
        OverlayThemeName.stationIdent => const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, _identDeep]),
          ),
        _ => null,
      };

  /// The VCR's logo bug is mono, like the rest of its display.
  bool get monoLogo => _vcr;
}
