import 'package:flutter/material.dart';

/// Design tokens for a guide look. Every screen reads colors and type from
/// here, so new themes (Retro, Midnight Blue, Glass, ...) are just new
/// instances of this class.
@immutable
class GuideTheme extends ThemeExtension<GuideTheme> {
  const GuideTheme({
    required this.name,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.panel,
    required this.header,
    required this.channelColumn,
    required this.cell,
    required this.cellAlt,
    required this.cellBorder,
    required this.focus,
    required this.onFocus,
    required this.accent,
    required this.text,
    required this.textDim,
    required this.nowLine,
    required this.displayFont,
    required this.bodyFont,
    required this.radius,
  });

  final String name;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color panel;
  final Color header;
  final Color channelColumn;
  final Color cell;
  final Color cellAlt;
  final Color cellBorder;

  /// Highlight for the focused cell/button, and the text drawn on it.
  final Color focus;
  final Color onFocus;
  final Color accent;
  final Color text;
  final Color textDim;
  final Color nowLine;
  final String displayFont;
  final String bodyFont;
  final double radius;

  /// Late-90s cable guide: deep navy grid, white and yellow condensed type.
  static const cableGuide = GuideTheme(
    name: 'Cable Guide',
    backgroundTop: Color(0xFF0C1C52),
    backgroundBottom: Color(0xFF040A24),
    panel: Color(0xFF0F2263),
    header: Color(0xFF07123A),
    channelColumn: Color(0xFF0D1E5A),
    cell: Color(0xFF1A3A8F),
    cellAlt: Color(0xFF15317C),
    cellBorder: Color(0xFF2D55B8),
    focus: Color(0xFFFFD23F),
    onFocus: Color(0xFF0A1A4A),
    accent: Color(0xFFFFD23F),
    text: Color(0xFFFFFFFF),
    textDim: Color(0xFFAFC3FF),
    nowLine: Color(0xFFFF5A36),
    displayFont: 'BarlowCondensed',
    bodyFont: 'Barlow',
    radius: 6,
  );

  TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: 1.1,
      );

  TextStyle body(double size, {FontWeight weight = FontWeight.w500, Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: 1.3,
      );

  BoxDecoration get backdrop => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [backgroundTop, backgroundBottom],
        ),
      );

  ThemeData toThemeData() {
    final scheme = ColorScheme.dark(
      primary: focus,
      onPrimary: onFocus,
      secondary: accent,
      surface: panel,
      onSurface: text,
      error: nowLine,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: backgroundBottom,
      extensions: [this],
      focusColor: focus.withValues(alpha: 0.25),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: focus,
        selectionColor: focus.withValues(alpha: 0.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: header,
        labelStyle: body(24, color: textDim),
        floatingLabelStyle: body(22, color: accent),
        hintStyle: body(24, color: textDim.withValues(alpha: 0.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: cellBorder, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: focus, width: 4),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(cellBorder),
        thickness: const WidgetStatePropertyAll(8),
      ),
    );
  }

  @override
  GuideTheme copyWith() => this;

  @override
  GuideTheme lerp(covariant GuideTheme? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension GuideThemeContext on BuildContext {
  GuideTheme get guide => Theme.of(this).extension<GuideTheme>() ?? GuideTheme.cableGuide;
}
