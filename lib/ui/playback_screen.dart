import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';

/// "Transcode only if needed" and the maximum streaming bitrate. Off by
/// default: everything direct-plays.
class PlaybackScreen extends StatelessWidget {
  const PlaybackScreen({super.key});

  static const toggleLabel = 'Transcode only if needed (experimental)';

  static const toggleHelp = "Off: Nightingale TV always plays your original files at full quality, and your "
      "Jellyfin server does no extra work. On: your Jellyfin server converts a show or movie only when it's above "
      "the maximum bitrate, or when the original file won't play. Converting uses your server's processor or "
      "graphics card. Commercials always play the original files.";

  static const bitrateHelp = 'Pick a lower bitrate if shows buffer or stutter over Wi-Fi or a remote connection. '
      'Original never converts because of bitrate.';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final playback = app.settings.playback;
    final on = playback.transcodeIfNeeded;
    final selected = playback.preset;

    return TvPage(
      title: 'Playback',
      hints: '▲▼ Move    OK Select    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(100, 40, 100, 40),
          children: [
            Text('CONVERTING', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TvToggle(
                label: toggleLabel,
                on: on,
                autofocus: true,
                onPressed: () => app.setPlayback(playback.copyWith(transcodeIfNeeded: !on)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: 1100, child: Text(toggleHelp, style: g.body(24, color: g.textDim))),
            const SizedBox(height: 40),
            Text('MAXIMUM STREAMING BITRATE',
                style: g.display(26, weight: FontWeight.w800, color: on ? g.accent : g.textDim)),
            const SizedBox(height: 14),
            for (final preset in PlaybackSettings.presets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TvToggle(
                    label: preset.label,
                    radio: true,
                    on: preset == selected,
                    // Shown but not selectable while converting is off.
                    onPressed: on ? () => app.setPlayback(playback.copyWith(bitrate: preset)) : null,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(width: 1100, child: Text(bitrateHelp, style: g.body(24, color: g.textDim))),
          ],
        ),
      ),
    );
  }
}
