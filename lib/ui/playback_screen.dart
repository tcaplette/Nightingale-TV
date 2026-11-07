import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../platform/platform_info.dart';
import '../server/media_server.dart';
import '../theme/tv_theme.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// "Transcode only if needed", the maximum streaming bitrate, volume
/// leveling, break notices, the on-screen clock, pause and rewind and watch
/// status reports. Off by default: everything direct-plays, audio untouched,
/// no clock; break notices, pause and rewind and watch status reports are on.
class PlaybackScreen extends StatelessWidget {
  const PlaybackScreen({super.key});

  static const toggleLabel = 'Transcode only if needed (experimental)';

  static const toggleHelp = "Off: Nightingale TV always plays your original files at full quality, and your "
      "server does no extra work. On: your server converts a show or movie only when it's above "
      "the maximum bitrate, or when the original file won't play. Converting uses your server's processor or "
      "graphics card. Commercials always play the original files.";

  static const relayNotice = 'Connected through Plex Relay; quality is limited.';

  static const bitrateHelp = 'Pick a lower bitrate if shows buffer or stutter over Wi-Fi or a remote connection. '
      'Original never converts because of bitrate.';

  static const levelingLabel = 'Volume leveling';

  static const levelingHelp = 'Evens out the volume as you watch: loud commercials and programs are turned down '
      'and quiet ones turned up, so you don\'t have to reach for the remote.';

  /// Added to [levelingHelp] on Android, where leveling turns passthrough off.
  static const levelingAndroidHelp = 'While it\'s on, surround audio (Dolby, DTS) is decoded by this device '
      'instead of being passed through to a receiver.';

  static const noticesLabel = 'Break notices';

  static const noticesHelp = 'Show a countdown before commercials start and before the program comes back.';

  static const clockLabel = 'On-screen clock';

  static const clockHelp = 'Shows the time in the corner of the picture.';

  static const rewindLabel = 'Pause and rewind';

  static const rewindHelp = 'Pause, skip and restart what\'s on. Off: every channel stays on the clock, '
      'like always-on TV.';

  static const reportsHelp = "Off: what you watch here never changes play counts, watched marks or resume "
      "points on your server, and doesn't show on its dashboard.";

  /// Added to [reportsHelp] for Plex and Emby, which end a live stream
  /// without its reports (play-reporting D4).
  static const reportsLiveHelp = 'Live TV still shows on the dashboard.';

  static String reportsHelpText(Iterable<ServerKind> kinds) =>
      kinds.any((k) => k != ServerKind.jellyfin) ? '$reportsHelp $reportsLiveHelp' : reportsHelp;

  /// "Update watch status on {server name}": the profile's server by name;
  /// with several, all of them.
  static String reportsLabel(List<String> servers) => 'Update watch status on ${switch (servers) {
        [] => 'your server',
        [final one] => one,
        _ => 'your servers',
      }}';

  static String levelingHelpText() =>
      PlatformInfo.isAndroid ? '$levelingHelp $levelingAndroidHelp' : levelingHelp;

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
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 40, 100, 40)),
          children: [
            if (app.plexRelay) ...[
              Text(relayNotice, style: g.body(26, color: g.nowLine)),
              const SizedBox(height: 28),
            ],
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
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Text(toggleHelp, style: g.body(24, color: g.textDim))),
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
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Text(bitrateHelp, style: g.body(24, color: g.textDim))),
            const SizedBox(height: 40),
            Text('AUDIO', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TvToggle(
                label: levelingLabel,
                on: playback.volumeLeveling,
                onPressed: () => app.setPlayback(playback.copyWith(volumeLeveling: !playback.volumeLeveling)),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Text(levelingHelpText(), style: g.body(24, color: g.textDim))),
            const SizedBox(height: 40),
            Text('COMMERCIALS', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TvToggle(
                label: noticesLabel,
                on: playback.breakNotices,
                onPressed: () => app.setPlayback(playback.copyWith(breakNotices: !playback.breakNotices)),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Text(noticesHelp, style: g.body(24, color: g.textDim))),
            const SizedBox(height: 40),
            Text('CLOCK', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TvToggle(
                label: clockLabel,
                on: playback.onScreenClock,
                onPressed: () => app.setPlayback(playback.copyWith(onScreenClock: !playback.onScreenClock)),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Text(clockHelp, style: g.body(24, color: g.textDim))),
            const SizedBox(height: 40),
            Text('WATCHING', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TvToggle(
                label: rewindLabel,
                on: playback.pauseAndRewind,
                onPressed: () => app.setPlayback(playback.copyWith(pauseAndRewind: !playback.pauseAndRewind)),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Text(rewindHelp, style: g.body(24, color: g.textDim))),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: TvToggle(
                label: reportsLabel([for (final server in app.servers.ordered) server.name]),
                on: playback.reportPlayback,
                onPressed: () => app.setPlayback(playback.copyWith(reportPlayback: !playback.reportPlayback)),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Text(reportsHelpText([for (final server in app.servers.ordered) server.kind]),
                    style: g.body(24, color: g.textDim))),
          ],
        ),
      ),
    );
  }
}
