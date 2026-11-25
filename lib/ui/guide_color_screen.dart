import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../l10n/tr.dart';
import '../theme/tv_theme.dart';
import 'guide_view.dart' show ColorSwatchDot;
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// A server's (or M3U source's) guide colour, from the fixed set; a colour
/// in use names the source using it (guide-server-colors).
class GuideColorScreen extends StatelessWidget {
  const GuideColorScreen({super.key, required this.sourceKey});

  final String sourceKey;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    return TvPage(
      title: tr.guideColorTitle(app.sourceName(sourceKey) ?? ''),
      hints: tr.moveOkSelectEscBack,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            Text(tr.guideColorHelp, style: g.body(24, color: g.textDim)),
            const SizedBox(height: 20),
            GuideColorList(
              sourceKey: sourceKey,
              onChosen: (name) async {
                await app.setServerColor(sourceKey, name);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The fixed set of guide colours, one row each: a swatch and a radio
/// toggle, the colour [sourceKey] has now selected and focused, and a
/// colour another source uses named with it. Used by Guide colour and by
/// Add a server's colour step.
class GuideColorList extends StatelessWidget {
  const GuideColorList({super.key, required this.sourceKey, required this.onChosen, this.enabled = true});

  final String sourceKey;
  final ValueChanged<String> onChosen;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final colors = app.serverColors;
    final mine = colors[sourceKey];
    final usedBy = {
      for (final e in colors.entries)
        if (e.key != sourceKey) e.value.name: app.sourceName(e.key) ?? '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in ServerColor.palette)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                ColorSwatchDot(color: c.cell, size: 40),
                const SizedBox(width: 18),
                Expanded(
                  child: TvToggle(
                    key: ValueKey('color-${c.name}'),
                    radio: true,
                    on: mine?.name == c.name,
                    autofocus: mine?.name == c.name,
                    label: usedBy[c.name] == null ? c.label : tr.guideColorUsedBy(c.label, usedBy[c.name]!),
                    onPressed: enabled ? () => onChosen(c.name) : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The Server colours in the guide toggle and its help, for Servers; only
/// with two or more sources.
class GuideColorsToggle extends StatelessWidget {
  const GuideColorsToggle({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    if (app.colorSources.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TvToggle(
            label: tr.serverColorsSetting,
            on: app.settings.guideServerColors,
            onPressed: () => app.setGuideServerColors(!app.settings.guideServerColors),
          ),
        ),
        const SizedBox(height: 6),
        Text(tr.serverColorsHelp, style: g.body(22, color: g.textDim)),
      ]),
    );
  }
}
