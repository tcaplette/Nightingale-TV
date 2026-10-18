import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';

/// Shown while the first library scan runs (or if it failed).
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final failed = app.syncError != null;
    return DecoratedBox(
      decoration: g.backdrop,
      child: Center(
        child: SizedBox(
          width: 1000,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(failed ? Icons.signal_wifi_bad : Icons.satellite_alt, size: 120, color: g.accent),
              const SizedBox(height: 32),
              Text(failed ? 'Couldn\'t load your library' : 'Setting up your channels',
                  style: g.display(60, weight: FontWeight.w800)),
              const SizedBox(height: 20),
              Text(failed ? app.syncError! : app.syncStatus,
                  textAlign: TextAlign.center, style: g.body(28, color: g.textDim)),
              const SizedBox(height: 48),
              if (failed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TvButton(label: 'Try again', icon: Icons.refresh, autofocus: true, onPressed: app.refreshLibrary),
                    const SizedBox(width: 24),
                    TvButton(label: 'Sign out', icon: Icons.logout, onPressed: app.signOut),
                  ],
                )
              else
                SizedBox(
                  width: 600,
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
