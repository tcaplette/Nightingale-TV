import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme/tv_theme.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// Shown while the first library scan runs (or if it failed).
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final failed = app.syncError != null;
    final layout = ScreenLayout.of(context);
    final portrait = layout.isPortrait;
    final width = portrait ? min(1000.0, layout.canvas.width - 2 * layout.gutter) : 1000.0;
    final buttons = [
      TvButton(label: 'Try again', icon: Icons.refresh, autofocus: true, onPressed: app.refreshLibrary),
      TvButton(label: 'Sign out', icon: Icons.logout, onPressed: app.signOut),
    ];
    return DecoratedBox(
      decoration: g.backdrop,
      child: Center(
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(failed ? Icons.signal_wifi_bad : Icons.satellite_alt, size: 120, color: g.accent),
              const SizedBox(height: 32),
              Text(failed ? 'Couldn\'t load your library' : 'Setting up your channels',
                  textAlign: TextAlign.center, style: g.display(portrait ? 44 : 60, weight: FontWeight.w800)),
              const SizedBox(height: 20),
              Text(failed ? app.syncError! : app.syncStatus,
                  textAlign: TextAlign.center, style: g.body(28, color: g.textDim)),
              const SizedBox(height: 48),
              if (failed && portrait)
                Wrap(alignment: WrapAlignment.center, spacing: 24, runSpacing: 16, children: buttons)
              else if (failed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [buttons[0], const SizedBox(width: 24), buttons[1]],
                )
              else
                SizedBox(
                  width: min(600.0, width),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    color: g.accent,
                    backgroundColor: g.cell,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
