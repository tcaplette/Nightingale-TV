import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/server_colors.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';

void main() {
  const g = GuideTheme.cableGuide;

  test('every colour, both shades, keeps 4.5:1 with white, dimmed and accent text', () {
    for (final c in ServerColor.palette) {
      for (final shade in [c.cell, c.alternate]) {
        for (final text in [g.text, g.textDim, g.accent]) {
          expect(ServerColor.contrast(text, shade), greaterThanOrEqualTo(4.5), reason: '${c.name} $text');
        }
      }
    }
  });

  test("none is the highlight, the now line or the guide's own blue", () {
    for (final c in ServerColor.palette) {
      for (final taken in [g.focus, g.nowLine, g.cell, g.cellAlt]) {
        // Told apart by colour, not only by lightness.
        final d = [(c.cell.r - taken.r), (c.cell.g - taken.g), (c.cell.b - taken.b)].fold<double>(0, (n, x) => n + x * x);
        expect(d, greaterThan(0.04), reason: '${c.name} against $taken');
      }
    }
    expect(ServerColor.palette.map((c) => c.name).toSet().length, 9);
  });

  test('defaults by kind, the next unused one for a second of a kind, and saved choices', () {
    final c = ServerColor.assign([
      (key: 'main', kind: ServerKind.jellyfin),
      (key: 's2', kind: ServerKind.plex),
      (key: 's3', kind: ServerKind.smb),
      (key: 's4', kind: ServerKind.smb),
      (key: 'live:a', kind: null),
      (key: 's5', kind: ServerKind.emby),
    ], const {});
    expect({for (final e in c.entries) e.key: e.value.name},
        {'main': 'purple', 's2': 'amber', 's3': 'teal', 's4': 'green', 'live:a': 'slate', 's5': 'magenta'});
    final saved = ServerColor.assign([(key: 'main', kind: ServerKind.jellyfin), (key: 's2', kind: ServerKind.plex)], {'s2': 'wine'});
    expect(saved['s2']!.name, 'wine');
    expect(saved['main']!.name, 'purple');
  });
}
