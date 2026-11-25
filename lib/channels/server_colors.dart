import 'dart:math';
import 'dart:ui' show Color;

import '../l10n/tr.dart';
import '../server/media_server.dart';

/// One guide colour (guide-server-colors): a program's background, and the
/// shade every other row of a channel takes.
class ServerColor {
  const ServerColor(this.name, this.cell, this.alternate);

  final String name;
  final Color cell;
  final Color alternate;

  String get label => switch (name) {
        'purple' => tr.colorPurple,
        'green' => tr.colorGreen,
        'amber' => tr.colorAmber,
        'teal' => tr.colorTeal,
        'magenta' => tr.colorMagenta,
        'olive' => tr.colorOlive,
        'slate' => tr.colorSlate,
        'cocoa' => tr.colorCocoa,
        _ => tr.colorWine,
      };

  /// Dark enough that the guide's white, dimmed and accent text have at
  /// least 4.5:1 contrast on both shades; no yellow, orange-red or the
  /// guide's own blue.
  static const palette = [
    ServerColor('purple', Color(0xFF4A2A80), Color(0xFF40246F)),
    ServerColor('green', Color(0xFF1E5A34), Color(0xFF194E2D)),
    ServerColor('amber', Color(0xFF6A440E), Color(0xFF5C3B0C)),
    ServerColor('teal', Color(0xFF0E5A5A), Color(0xFF0B4D4D)),
    ServerColor('magenta', Color(0xFF6E1E5A), Color(0xFF5F1A4E)),
    ServerColor('olive', Color(0xFF4C5113), Color(0xFF424610)),
    ServerColor('slate', Color(0xFF3A4654), Color(0xFF323C48)),
    ServerColor('cocoa', Color(0xFF5A3A2C), Color(0xFF4E3226)),
    ServerColor('wine', Color(0xFF6E1C2C), Color(0xFF601826)),
  ];

  static ServerColor? byName(String? name) => palette.where((c) => c.name == name).firstOrNull;

  /// The colour each kind starts with.
  static String defaultFor(ServerKind? kind) => switch (kind) {
        ServerKind.jellyfin => 'purple',
        ServerKind.emby => 'green',
        ServerKind.plex => 'amber',
        ServerKind.smb => 'teal',
        ServerKind.youtube => 'wine',
        // M3U sources.
        null => 'slate',
      };

  /// WCAG contrast of [a] on [b].
  static double contrast(Color a, Color b) {
    double lum(Color c) {
      double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    final x = lum(a), y = lum(b);
    return (max(x, y) + 0.05) / (min(x, y) + 0.05);
  }

  /// Every source's colour, by key: its saved choice, else its kind's,
  /// else the next one no source has, in [sources]' order (then they
  /// repeat).
  static Map<String, ServerColor> assign(List<({String key, ServerKind? kind})> sources, Map<String, String> saved) {
    final out = <String, ServerColor>{};
    for (final s in sources) {
      if (byName(saved[s.key]) case final c?) out[s.key] = c;
    }
    final used = {for (final c in out.values) c.name};
    for (final s in sources) {
      if (out.containsKey(s.key)) continue;
      var name = defaultFor(s.kind);
      if (used.contains(name)) {
        name = palette.map((c) => c.name).where((n) => !used.contains(n)).firstOrNull ??
            palette[out.length % palette.length].name;
      }
      out[s.key] = byName(name)!;
      used.add(name);
    }
    return out;
  }
}
