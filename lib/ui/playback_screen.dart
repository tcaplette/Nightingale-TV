import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../platform/platform_info.dart';
import '../playback/caption_size.dart';
import '../server/media_server.dart';
import '../theme/tv_theme.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// "Transcode only if needed", the maximum streaming bitrate, volume
/// leveling, break notices, the on-screen clock, pause and rewind and watch
/// status reports, and when to ask if anyone is still watching. Off by default: everything direct-plays, audio untouched,
/// no clock; break notices, pause and rewind and watch status reports are on.
class PlaybackScreen extends StatelessWidget {
  const PlaybackScreen({super.key});

  static String get toggleLabel => tr.transcodeOnlyIf;

  static String get toggleHelp => tr.offNightingaleTv;

  static String get relayNotice => tr.connectedThroughPlex;

  static String get bitrateHelp => tr.pickALower;

  static String get levelingLabel => tr.volumeLeveling;

  static String get levelingHelp => tr.evensOutThe;

  /// Added to [levelingHelp] on Android, where leveling turns passthrough off.
  static String get levelingAndroidHelp => tr.whileItsOn;

  static String get captionSizeHelp => tr.theSizeOf;

  static String get noticesLabel => tr.breakNotices;

  static String get noticesHelp => tr.showACountdown;

  static String get clockLabel => tr.onScreenClock;

  static String get clockHelp => tr.showsTheTime;

  static String get rewindLabel => tr.pauseAndRewind;

  static String get rewindHelp => tr.pauseSkipAnd;

  static String get reportsHelp => tr.offWhatYou;

  /// Added to [reportsHelp] for Plex and Emby, which end a live stream
  /// without its reports (play-reporting D4).
  static String get reportsLiveHelp => tr.liveTvStill;

  static String get stillWatchingLabel => tr.askIfIm;

  static String get stillWatchingHelp => tr.afterThisLong;

  static String reportsHelpText(Iterable<ServerKind> kinds) =>
      kinds.any((k) => k != ServerKind.jellyfin) ? '$reportsHelp $reportsLiveHelp' : reportsHelp;

  /// "Update watch status on {server name}": the profile's server by name;
  /// with several, all of them.
  static String reportsLabel(List<String> servers) => switch (servers) {
        [] => tr.updateWatchStatusOnYourServer,
        [final one] => tr.updateWatchStatusOn(one),
        _ => tr.updateWatchStatusOnYourServers,
      };

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
      title: tr.playback,
      hints: tr.moveOkSelectEscBack,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 40, 100, 40)),
          children: [
            if (app.plexRelay) ...[
              Text(relayNotice, style: g.body(26, color: g.nowLine)),
              const SizedBox(height: 28),
            ],
            Text(tr.converting, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
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
            Text(tr.maximumStreamingBitrate,
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
            Text(tr.audio, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
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
            Text(tr.captions2, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 14),
            ValueListenableBuilder<CaptionSize>(
              valueListenable: app.captionSize,
              builder: (context, inForce, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final size in CaptionSize.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TvToggle(
                        label: size.label,
                        radio: true,
                        on: size == inForce,
                        onPressed: () => app.setPlayback(playback.copyWith(captionSize: () => size)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Text(captionSizeHelp, style: g.body(24, color: g.textDim))),
            const SizedBox(height: 40),
            Text(tr.commercials2, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
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
            Text(tr.clock, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
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
            Text(tr.watching, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
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
            const SizedBox(height: 28),
            Text(stillWatchingLabel, style: g.display(28, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            for (final choice in PlaybackSettings.stillWatchingChoices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TvToggle(
                    label: choice.label,
                    radio: true,
                    on: choice.after == playback.stillWatchingAfter,
                    onPressed: () => app.setPlayback(playback.copyWith(stillWatchingAfter: () => choice.after)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Text(stillWatchingHelp, style: g.body(24, color: g.textDim))),
          ],
        ),
      ),
    );
  }
}
