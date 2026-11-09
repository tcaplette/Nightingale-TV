import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app_exit.dart';
import '../app_scope.dart';
import '../backup/backup_archive.dart';
import '../platform/platform_info.dart';
import '../server/server_set.dart';
import '../theme/tv_theme.dart';
import 'backup_screen.dart';
import 'blocks_screen.dart';
import 'channel_editor_screen.dart';
import 'channel_groups_screen.dart';
import 'commercials_screen.dart';
import 'error_reports_screen.dart';
import 'format.dart';
import 'phone_remote_screen.dart';
import 'live_sources_screen.dart';
import 'live_tv_export_screen.dart';
import 'playback_screen.dart';
import 'retro_look_screen.dart';
import 'servers_screen.dart';
import 'profiles_screen.dart';
import 'sleep_picker.dart';
import 'widgets/adaptive.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';
import 'language_picker.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  /// A grown-up entered their PIN on a kid profile's menu.
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final household = HouseholdScope.of(context);
    final profile = household.current;
    final g = context.guide;
    final session = app.session;
    void back() => Navigator.of(context).pop();
    final portrait = ScreenLayout.of(context).isPortrait;
    // Upright on a touch screen nothing takes focus at first, so the page
    // opens at the top, on the summary (a keyboard still lands on Back to TV).
    final focusFirst = !portrait || FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    // Kid profiles: settings need a grown-up's PIN (once per visit).
    final locked = (profile?.isKid ?? false) && !_unlocked;
    VoidCallback guard(FutureOr<void> Function() action) => () async {
          if (locked) {
            if (!await grownUpCheck(context, title: tr.parentalControls) || !mounted) return;
            setState(() => _unlocked = true);
          }
          await action();
        };

    final buttons = <Widget>[
      TvButton(label: tr.backToTv, icon: Icons.tv, expand: true, autofocus: focusFirst, onPressed: back),
      if (AppScope.sleepOf(context) case final sleep?) ...[
        const SizedBox(height: 18),
        TvButton(
          label: tr.sleepTimer,
          icon: Icons.bedtime,
          expand: true,
          // A choice goes back to the TV.
          onPressed: () async {
            if (await showSleepPicker(context, sleep) && context.mounted) back();
          },
        ),
      ],
      if (profile != null) ...[
        const SizedBox(height: 18),
        TvButton(
          label: tr.languageTitle,
          icon: Icons.language,
          expand: true,
          onPressed: () => showLanguagePicker(context, profile),
        ),
      ],
      if (household.profiles.length > 1) ...[
        const SizedBox(height: 18),
        TvButton(
          label: tr.switchProfile,
          icon: Icons.switch_account,
          expand: true,
          onPressed: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            household.leave();
          },
        ),
      ],
      const SizedBox(height: 18),
      TvButton(
        label: tr.channelsIcons,
        icon: locked ? Icons.lock : Icons.format_list_numbered,
        expand: true,
        onPressed: guard(() => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChannelEditorScreen()))),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: tr.channelGroups,
        icon: locked ? Icons.lock : Icons.tab,
        expand: true,
        onPressed: guard(() => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChannelGroupsScreen()))),
      ),
      // Kid profiles have no live channels (live-tv-sources).
      if (!(profile?.isKid ?? false)) ...[
        const SizedBox(height: 18),
        TvButton(
          label: tr.liveTvSources,
          icon: Icons.settings_input_antenna,
          expand: true,
          onPressed: guard(() => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const LiveSourcesScreen()))),
        ),
      ],
      const SizedBox(height: 18),
      TvButton(
        label: tr.programmingBlocks,
        icon: locked ? Icons.lock : Icons.event_note,
        expand: true,
        onPressed: guard(() => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const BlocksScreen()))),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: tr.commercials,
        icon: locked ? Icons.lock : Icons.campaign,
        expand: true,
        onPressed: guard(() => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const CommercialsScreen()))),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: tr.playback,
        icon: locked ? Icons.lock : Icons.high_quality,
        expand: true,
        onPressed: guard(() => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const PlaybackScreen()))),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: tr.retroLook,
        icon: locked ? Icons.lock : Icons.filter_vintage,
        expand: true,
        onPressed: guard(() => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const RetroLookScreen()))),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: tr.profiles,
        icon: locked ? Icons.lock : Icons.people,
        expand: true,
        onPressed: guard(() => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()))),
      ),
      if (household.backups != null) ...[
        const SizedBox(height: 18),
        TvButton(
          label: tr.backupRestore,
          icon: locked ? Icons.lock : Icons.settings_backup_restore,
          expand: true,
          onPressed: guard(() => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const BackupScreen()))),
        ),
      ],
      if (household.export != null) ...[
        const SizedBox(height: 18),
        TvButton(
          label: tr.liveTvExport2,
          icon: locked ? Icons.lock : Icons.cast_connected,
          expand: true,
          onPressed: guard(() => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const LiveTvExportScreen()))),
        ),
      ],
      if (household.remote != null) ...[
        const SizedBox(height: 18),
        TvButton(
          label: tr.phoneRemote,
          icon: locked ? Icons.lock : Icons.phone_android,
          expand: true,
          onPressed: guard(() => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const PhoneRemoteScreen()))),
        ),
      ],
      // A privacy choice, not household setup: never behind the PIN.
      const SizedBox(height: 18),
      TvButton(
        label: tr.errorReports,
        icon: Icons.bug_report,
        expand: true,
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const ErrorReportsScreen())),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: tr.servers,
        icon: locked ? Icons.lock : Icons.dns,
        expand: true,
        onPressed: guard(() => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const ServersScreen()))),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: app.refreshing ? tr.refreshingLibrary : tr.refreshLibrary,
        icon: locked ? Icons.lock : Icons.sync,
        expand: true,
        onPressed: guard(() async {
          await app.refreshLibrary(background: true);
          if (!context.mounted) return;
          await AppScope.tunerOf(context).retune();
          if (!context.mounted) return;
          final (title, message) = refreshReport(app.syncError, app.lastRefresh, app.session?.serverName);
          await showMessage(context, title: title, message: message);
        }),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: tr.resetChannelLineup2,
        icon: locked ? Icons.lock : Icons.restart_alt,
        expand: true,
        onPressed: guard(() async {
          final ok = await confirm(context,
              title: tr.resetChannelLineup,
              message: tr.rebuildsTheDefault,
              action: tr.reset);
          if (!ok || !context.mounted) return;
          try {
            await app.resetChannels();
          } on BackupException catch (e) {
            // No backup could be saved first: nothing was reset.
            if (context.mounted) await showMessage(context, title: tr.nothingWasReset, message: e.message);
            return;
          }
          if (context.mounted) back();
        }),
      ),
      if (PlatformInfo.isDesktop) ...[
        const SizedBox(height: 18),
        TvButton(
          label: tr.fullScreenOn,
          icon: Icons.fullscreen,
          expand: true,
          onPressed: () async =>
              windowManager.setFullScreen(!await windowManager.isFullScreen()),
        ),
      ],
      const SizedBox(height: 18),
      TvButton(
        label: tr.signOut,
        icon: locked ? Icons.lock : Icons.logout,
        expand: true,
        danger: true,
        onPressed: guard(() async {
          final ok = await confirm(context,
              title: tr.signOut2,
              message: tr.yourChannelLineup,
              action: tr.signOut);
          if (!ok || !context.mounted) return;
          await AppScope.tunerOf(context).stop();
          if (!context.mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          await app.signOut();
        }),
      ),
      const SizedBox(height: 18),
      TvButton(
        label: tr.exitNightingaleTv,
        icon: locked ? Icons.lock : Icons.power_settings_new,
        expand: true,
        danger: true,
        onPressed: guard(() async {
          final tuner = AppScope.tunerOf(context);
          await quitApp(beforeClosing: tuner.stop);
        }),
      ),
    ];
    final counts = app.servers.multiple ? app.serverCounts() : const <String, ({int episodes, int movies, int songs})>{};
    final summary = <Widget>[
      if (profile != null) ...[
        Text(tr.watching, style: g.display(30, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 12),
        Row(
          children: [
            ProfileAvatar(profile: profile, size: 72),
            const SizedBox(width: 20),
            Flexible(
              child: Text(profile.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(48, weight: FontWeight.w700)),
            ),
            if (profile.isKid) ...[
              const SizedBox(width: 16),
              Text(profile.rating.label, style: g.body(26, color: g.textDim)),
            ],
          ],
        ),
        const SizedBox(height: 48),
      ],
      Text(tr.account, style: g.display(30, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 12),
      if (session != null) ...[
        Text(session.userName, style: g.display(48, weight: FontWeight.w700)),
        Text('${session.serverName} · ${session.serverUrl}', style: g.body(24, color: g.textDim)),
      ],
      const SizedBox(height: 48),
      Text(tr.libraryLabel, style: g.display(30, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 12),
      Text(
        [
          tr.countShows(app.library.series.length),
          tr.countEpisodes(app.library.episodes.length),
          tr.countMovies(app.library.movies.length),
          if (app.library.songs.isNotEmpty) tr.countSongs(app.library.songs.length),
          if (app.library.musicVideos.isNotEmpty) tr.countMusicVideos(app.library.musicVideos.length),
        ].join(' · '),
        style: g.body(28),
      ),
      // A line per server (multi-server).
      for (final s in app.servers.multiple ? app.servers.ordered : const <ProfileServer>[])
        Text(
          tr.perServerStats(s.name, [
            tr.countEpisodes(counts[s.key]?.episodes ?? 0),
            tr.countMovies(counts[s.key]?.movies ?? 0),
            if ((counts[s.key]?.songs ?? 0) != 0) tr.countSongs(counts[s.key]!.songs),
            if (s.state != ServerState.ok) s.state.label,
          ].join(' · ')),
          style: g.body(24, color: s.state == ServerState.ok ? g.textDim : g.nowLine),
        ),
      Text(
        app.refreshing
            ? app.syncStatus
            : app.syncError != null
                ? tr.lastRefreshFailed('${app.syncError}')
                : tr.updatedAt(formatDate(app.library.fetchedAt), formatTime(app.library.fetchedAt)),
        style: g.body(24, color: app.refreshing ? g.accent : app.syncError != null ? g.nowLine : g.textDim),
      ),
      const SizedBox(height: 48),
      Text(tr.channels2, style: g.display(30, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 12),
      Text(
        [
          tr.countOnTheAir(app.channels.length),
          if (app.allChannels.length > app.channels.length) tr.countHidden(app.allChannels.length - app.channels.length),
          if (app.blocks.isNotEmpty) tr.countProgrammingBlocks(app.blocks.length),
        ].join(' · '),
        style: g.body(28),
      ),
      const SizedBox(height: 48),
      Text(tr.commercials2, style: g.display(30, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 12),
      Text(
        [
          app.settings.commercialPlan.mode.label,
          if (app.settings.commercialPools.isEmpty)
            tr.noPoolsYet
          else
            tr.clips3(app.catalog.clipsFor(null).length),
        ].join(' · '),
        style: g.body(28),
      ),
    ];

    return TvPage(
      title: tr.menu,
      hints: tr.moveOkSelectEscBackTo,
      onBack: back,
      child: ScreenLayout.of(context).isPortrait
          // Upright: who's watching and what's set up, then the buttons
          // across the screen.
          ? FocusTraversalGroup(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: ScreenLayout.of(context).gutter, vertical: 24),
                children: [...summary, const SizedBox(height: 48), ...buttons],
              ),
            )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 60),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 760,
              child: FocusTraversalGroup(
                child: ListView(
                  children: buttons,
                ),
              ),
            ),
            const SizedBox(width: 100),
            // Longer languages can need more than one screen's height.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: summary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TV-friendly message with an OK button, for something that didn't work.
/// The title and message after Refresh library: what the scan found, or
/// why it failed.
(String, String) refreshReport(
    String? error, ({int shows, int episodes, int movies, int songs, int channels})? found, String? serverName) {
  if (error != null) return (tr.refreshFailed, error);
  if (found == null) return (tr.libraryRefreshed, tr.yourChannelsAre);
  final parts = [
    if (found.shows > 0) tr.newShows(found.shows),
    if (found.episodes > 0) tr.newEpisodes(found.episodes),
    if (found.movies > 0) tr.newMovies(found.movies),
    if (found.songs > 0) tr.newSongs(found.songs),
    if (found.channels > 0) tr.newChannels(found.channels),
  ];
  if (parts.isEmpty) {
    return (
      tr.nothingNew,
      serverName == null ? tr.yourServerHasNothingNew : tr.serverHasNothingNew(serverName),
    );
  }
  final list = parts.length == 1 ? parts.first : tr.and(parts.take(parts.length - 1).join(', '), parts.last);
  return (tr.libraryRefreshed, tr.foundNewPrograms(list));
}

Future<void> showMessage(BuildContext context, {required String title, required String message}) => showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        final g = context.guide;
        return Dialog(
          backgroundColor: g.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(g.radius * 2),
            side: BorderSide(color: g.cellBorder, width: 2),
          ),
          child: Padding(
            padding: EdgeInsets.all(dialogPadding(context)),
            child: SizedBox(
              width: dialogWidth(context, 820, padding: dialogPadding(context)),
              child: dialogBody(context, Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: g.display(48, weight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Text(message, style: g.body(28, color: g.nowLine)),
                  const SizedBox(height: 40),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TvButton(label: tr.ok, autofocus: true, onPressed: () => Navigator.pop(context)),
                  ),
                ],
              )),
            ),
          ),
        );
      },
    );

/// TV-friendly yes/no dialog. Defaults focus to Cancel so OK-mashing is safe.
Future<bool> confirm(BuildContext context,
    {required String title, required String message, required String action}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final g = context.guide;
      return Dialog(
        backgroundColor: g.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(g.radius * 2),
          side: BorderSide(color: g.cellBorder, width: 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(dialogPadding(context)),
          child: SizedBox(
            width: dialogWidth(context, 820, padding: dialogPadding(context)),
            child: dialogBody(context, Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: g.display(48, weight: FontWeight.w800)),
                const SizedBox(height: 16),
                Text(message, style: g.body(28, color: g.textDim)),
                const SizedBox(height: 40),
                ButtonRow(
                  children: [
                    TvButton(label: tr.cancel, autofocus: true, onPressed: () => Navigator.pop(context, false)),
                    TvButton(label: action, danger: true, onPressed: () => Navigator.pop(context, true)),
                  ],
                ),
              ],
            )),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
