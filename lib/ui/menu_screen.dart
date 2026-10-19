import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app_exit.dart';
import '../app_scope.dart';
import '../theme/tv_theme.dart';
import 'blocks_screen.dart';
import 'channel_editor_screen.dart';
import 'commercials_screen.dart';
import 'format.dart';
import 'phone_remote_screen.dart';
import 'live_tv_export_screen.dart';
import 'playback_screen.dart';
import 'profiles_screen.dart';
import 'widgets/tv_focus.dart';

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

    // Kid profiles: settings need a grown-up's PIN (once per visit).
    final locked = (profile?.isKid ?? false) && !_unlocked;
    VoidCallback guard(FutureOr<void> Function() action) => () async {
          if (locked) {
            if (!await grownUpCheck(context, title: 'Parental controls') || !mounted) return;
            setState(() => _unlocked = true);
          }
          await action();
        };

    return TvPage(
      title: 'Menu',
      hints: '▲▼ Move    OK Select    ESC Back to TV',
      onBack: back,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 60),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 760,
              child: FocusTraversalGroup(
                child: ListView(
                  children: [
                    TvButton(label: 'Back to TV', icon: Icons.tv, expand: true, autofocus: true, onPressed: back),
                    if (household.profiles.length > 1) ...[
                      const SizedBox(height: 18),
                      TvButton(
                        label: 'Switch profile',
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
                      label: 'Channels & icons',
                      icon: locked ? Icons.lock : Icons.format_list_numbered,
                      expand: true,
                      onPressed: guard(() => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const ChannelEditorScreen()))),
                    ),
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Programming blocks',
                      icon: locked ? Icons.lock : Icons.event_note,
                      expand: true,
                      onPressed: guard(() => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const BlocksScreen()))),
                    ),
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Commercials',
                      icon: locked ? Icons.lock : Icons.campaign,
                      expand: true,
                      onPressed: guard(() => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const CommercialsScreen()))),
                    ),
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Playback',
                      icon: locked ? Icons.lock : Icons.high_quality,
                      expand: true,
                      onPressed: guard(() => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const PlaybackScreen()))),
                    ),
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Profiles',
                      icon: locked ? Icons.lock : Icons.people,
                      expand: true,
                      onPressed: guard(() => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()))),
                    ),
                    if (household.export != null) ...[
                      const SizedBox(height: 18),
                      TvButton(
                        label: 'Live TV export',
                        icon: locked ? Icons.lock : Icons.cast_connected,
                        expand: true,
                        onPressed: guard(() => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const LiveTvExportScreen()))),
                      ),
                    ],
                    if (household.remote != null) ...[
                      const SizedBox(height: 18),
                      TvButton(
                        label: 'Phone remote',
                        icon: locked ? Icons.lock : Icons.phone_android,
                        expand: true,
                        onPressed: guard(() => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const PhoneRemoteScreen()))),
                      ),
                    ],
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Refresh library',
                      icon: locked ? Icons.lock : Icons.sync,
                      expand: true,
                      onPressed: guard(() async {
                        await app.refreshLibrary(background: true);
                        if (context.mounted) await AppScope.tunerOf(context).retune();
                      }),
                    ),
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Reset channel lineup',
                      icon: locked ? Icons.lock : Icons.restart_alt,
                      expand: true,
                      onPressed: guard(() async {
                        final ok = await confirm(context,
                            title: 'Reset channel lineup?',
                            message: 'Rebuilds the default channels from your library. '
                                'Names, icons and numbers you changed will be lost.',
                            action: 'Reset');
                        if (!ok || !context.mounted) return;
                        await app.resetChannels();
                        if (context.mounted) back();
                      }),
                    ),
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Full screen on/off (F11)',
                      icon: Icons.fullscreen,
                      expand: true,
                      onPressed: () async =>
                          windowManager.setFullScreen(!await windowManager.isFullScreen()),
                    ),
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Sign out',
                      icon: locked ? Icons.lock : Icons.logout,
                      expand: true,
                      danger: true,
                      onPressed: guard(() async {
                        final ok = await confirm(context,
                            title: 'Sign out?',
                            message: 'Your channel lineup is cleared. Custom icons are kept.',
                            action: 'Sign out');
                        if (!ok || !context.mounted) return;
                        await AppScope.tunerOf(context).stop();
                        if (!context.mounted) return;
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        await app.signOut();
                      }),
                    ),
                    const SizedBox(height: 18),
                    TvButton(
                      label: 'Exit Nightingale TV',
                      icon: locked ? Icons.lock : Icons.power_settings_new,
                      expand: true,
                      danger: true,
                      onPressed: guard(() async {
                        await runExitHooks();
                        if (!context.mounted) return;
                        await AppScope.tunerOf(context).stop();
                        await windowManager.destroy();
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 100),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile != null) ...[
                    Text('WATCHING', style: g.display(30, weight: FontWeight.w800, color: g.accent)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ProfileAvatar(profile: profile, size: 72),
                        const SizedBox(width: 20),
                        Text(profile.name, style: g.display(48, weight: FontWeight.w700)),
                        if (profile.isKid) ...[
                          const SizedBox(width: 16),
                          Text(profile.rating.label, style: g.body(26, color: g.textDim)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                  Text('ACCOUNT', style: g.display(30, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 12),
                  if (session != null) ...[
                    Text(session.userName, style: g.display(48, weight: FontWeight.w700)),
                    Text('${session.serverName} · ${session.serverUrl}', style: g.body(24, color: g.textDim)),
                  ],
                  const SizedBox(height: 48),
                  Text('LIBRARY', style: g.display(30, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 12),
                  Text(
                    '${app.library.series.length} shows · ${app.library.episodes.length} episodes · '
                    '${app.library.movies.length} movies',
                    style: g.body(28),
                  ),
                  Text(
                    app.syncError != null
                        ? 'Last refresh failed: ${app.syncError}'
                        : 'Updated ${formatDate(app.library.fetchedAt)} at ${formatTime(app.library.fetchedAt)}',
                    style: g.body(24, color: app.syncError != null ? g.nowLine : g.textDim),
                  ),
                  const SizedBox(height: 48),
                  Text('CHANNELS', style: g.display(30, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 12),
                  Text(
                    '${app.channels.length} on the air'
                    '${app.allChannels.length > app.channels.length ? ' · ${app.allChannels.length - app.channels.length} hidden' : ''}'
                    '${app.blocks.isEmpty ? '' : ' · ${app.blocks.length} programming block${app.blocks.length == 1 ? '' : 's'}'}',
                    style: g.body(28),
                  ),
                  const SizedBox(height: 48),
                  Text('COMMERCIALS', style: g.display(30, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 12),
                  Text(
                    [
                      app.settings.commercialPlan.mode.label,
                      if (app.settings.commercialPools.isEmpty)
                        'no pools yet'
                      else
                        '${app.catalog.clipsFor(null).length} clip${app.catalog.clipsFor(null).length == 1 ? '' : 's'}',
                    ].join(' · '),
                    style: g.body(28),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.all(56),
          child: SizedBox(
            width: 820,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: g.display(48, weight: FontWeight.w800)),
                const SizedBox(height: 16),
                Text(message, style: g.body(28, color: g.textDim)),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TvButton(label: 'Cancel', autofocus: true, onPressed: () => Navigator.pop(context, false)),
                    const SizedBox(width: 20),
                    TvButton(label: action, danger: true, onPressed: () => Navigator.pop(context, true)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
