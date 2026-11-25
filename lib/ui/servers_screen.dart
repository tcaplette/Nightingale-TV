import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../server/media_server.dart';
import '../server/server_set.dart';
import '../server/smb/smb_history.dart';
import '../server/smb/smb_server.dart';
import '../server/youtube/youtube_server.dart';
import 'channel_groups_screen.dart' show askName;
import 'convert_screens.dart';
import 'guide_color_screen.dart';
import 'smb_screens.dart';
import 'youtube_screens.dart';
import '../theme/tv_theme.dart';
import 'login_screen.dart';
import 'menu_screen.dart' show confirm;
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// Menu → Servers (multi-server): the profile's servers, in Play from
/// order, with their state; add one, sign in again, remove, reorder and
/// set a quality limit. Every control is a button, so D-pad, air mouse and
/// touch all work the same.
class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final layout = ScreenLayout.of(context);
    final ordered = app.servers.ordered;
    final playFrom = [for (final s in ordered) if (s.kind != ServerKind.youtube) s];
    final counts = app.serverCounts();
    return TvPage(
      title: tr.servers,
      hints: tr.moveOkSelectEsc,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: layout.pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            Text(
              tr.programsFromEvery,
              style: g.body(24, color: g.textDim),
            ),
            const SizedBox(height: 12),
            Text(
              tr.serverKindsHelp,
              key: const ValueKey('server-kinds-help'),
              style: g.body(24, color: g.textDim),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: TvButton(
                label: tr.addAServer,
                icon: Icons.add,
                autofocus: true,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen(adding: true))),
              ),
            ),
            const SizedBox(height: 16),
            // Converting share files on another Nightingale TV (smb-conversion).
            if (app.servers.all.any((s) => s.kind == ServerKind.smb))
              Align(
                alignment: Alignment.centerLeft,
                child: TvButton(
                  label: tr.convertHelpers,
                  icon: Icons.devices,
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const ConvertHelpersScreen())),
                ),
              ),
            const SizedBox(height: 28),
            GuideColorsToggle(app: app),
            for (final s in ordered)
              _ServerRow(
                server: s,
                // Play from order is the media servers'; YouTube has no place
                // in it (youtube-subscriptions D1).
                position: playFrom.indexOf(s),
                count: s.kind == ServerKind.youtube ? 0 : playFrom.length,
                episodes: counts[s.key]?.episodes ?? 0,
                movies: counts[s.key]?.movies ?? 0,
                songs: counts[s.key]?.songs ?? 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow(
      {required this.server,
      required this.position,
      required this.count,
      required this.episodes,
      required this.movies,
      required this.songs});

  final ProfileServer server;
  final int position, count, episodes, movies, songs;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    final g = context.guide;
    final portrait = ScreenLayout.of(context).isPortrait;
    final state = server.state;
    final limit = server.qualityLimitKbps;
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    final smb = server.client is SmbServer ? server.client! as SmbServer : null;
    // YouTube (youtube-subscriptions D5, D10, D11): its channels and Google
    // client; it has no Play from place or quality limit.
    final youtube = server.kind == ServerKind.youtube;
    final ytServer = server.client is YouTubeServer ? server.client! as YouTubeServer : null;
    final quotaUntil = ytServer?.quotaBlockedUntil;
    final ytChannels = youtube ? app.youTubeChannels.where((c) => c.youtube!.serverKey == server.key).length : 0;
    void googleClient() => open(LoginScreen(againKey: server.key, googleClient: true));
    final buttons = [
      if (state == ServerState.needsSignIn)
        TvButton(
          label: tr.signInAgain,
          icon: Icons.login,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => LoginScreen(againKey: server.key))),
        ),
      if (youtube) ...[
        if (ytServer != null && state != ServerState.needsSignIn)
          TvButton(
              label: tr.channels5, icon: Icons.checklist, onPressed: () => open(YouTubeChannelsScreen(serverKey: server.key))),
        if (server.session != null) TvButton(label: tr.googleClient, icon: Icons.key, onPressed: googleClient),
        if (quotaUntil != null) TvButton(label: tr.useMyOwnClient, icon: Icons.key, onPressed: googleClient),
      ],
      if (count > 1 && !youtube) ...[
        TvButton(
            label: tr.moveUp,
            icon: Icons.arrow_upward,
            onPressed: position == 0 ? null : () => app.moveServer(server.key, -1)),
        TvButton(
            label: tr.moveDown,
            icon: Icons.arrow_downward,
            onPressed: position == count - 1 ? null : () => app.moveServer(server.key, 1)),
      ],
      if (smb != null) ...[
        TvButton(
          label: tr.rename,
          icon: Icons.edit,
          onPressed: () async {
            final name = await askName(context, title: tr.smbRenameTitle(server.name), initial: server.name, action: tr.rename);
            if (name != null) await app.renameServer(server.key, name);
          },
        ),
        TvButton(label: tr.smbFolders, icon: Icons.folder, onPressed: () => open(SmbFoldersScreen(serverKey: server.key))),
        TvButton(
            label: tr.smbCantPlay(smb.cantPlay.length),
            icon: Icons.block,
            onPressed: () => open(SmbCantPlayScreen(serverKey: server.key))),
      ],
      if (app.guideColorsOn)
        TvButton(label: tr.guideColor, icon: Icons.palette, onPressed: () => open(GuideColorScreen(sourceKey: server.key))),
      if (!youtube)
        TvButton(
          label: tr.qualityLimit2,
          icon: Icons.high_quality,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => _QualityLimitScreen(serverKey: server.key))),
        ),
      if (!server.isMain) TvButton(label: tr.remove, icon: Icons.delete, danger: true, onPressed: () => _remove(context)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Container(
        padding: EdgeInsets.all(portrait ? 24 : 28),
        decoration: BoxDecoration(
          color: g.panel,
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: g.cellBorder, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${count > 1 ? '${position + 1}. ' : ''}${server.name}', style: g.display(40, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              [server.kind.label, if (server.isMain) tr.mainServer, state.label].join(' · '),
              style: g.body(26,
                  weight: FontWeight.w600, color: state == ServerState.ok ? g.accent : g.nowLine),
            ),
            // A very long address may be cut; who's signed in never is.
            if (server.serverUrl case final url? when !youtube)
              Text(url, maxLines: 2, overflow: TextOverflow.ellipsis, style: g.body(22, color: g.textDim)),
            if (server.userName case final user?) Text(tr.signedInAs(user), style: g.body(22, color: g.textDim)),
            if (youtube) ...[
              Text(
                [
                  tr.youTubeChannelCount(ytChannels),
                  '${tr.googleClient}: ${server.session?.clientId != null ? tr.googleClientOwn : tr.googleClientShared}',
                ].join(' · '),
                style: g.body(22, color: g.textDim),
              ),
              if (state == ServerState.needsSignIn) Text(tr.signInToYouTubeAgain, style: g.body(22, color: g.nowLine)),
              if (quotaUntil != null)
                Text(tr.youTubeDailyLimit(formatClock(context, quotaUntil)),
                    key: const ValueKey('youtube-daily-limit'), style: g.body(22, color: g.nowLine)),
            ] else
            Text(
              [
                tr.countEpisodes(episodes),
                tr.countMovies(movies),
                if (songs != 0) tr.countSongs(songs),
                limit == null ? tr.qualitySameAsProfile : tr.qualityValue(_mbps(limit)),
              ].join(' · '),
              style: g.body(22, color: g.textDim),
            ),
            if (smb != null) ...[
              if (smb.smb1) Text(tr.smbOld, style: g.body(22, color: g.nowLine)),
              ValueListenableBuilder(
                valueListenable: smb.filesLeft,
                builder: (context, left, _) =>
                    left == 0 ? const SizedBox.shrink() : Text(tr.smbFilesLeft(left), style: g.body(22, color: g.accent)),
              ),
              ValueListenableBuilder(
                valueListenable: smb.historyPlace,
                builder: (context, place, _) => Text(
                  switch (smb.config.keepLocal ? HistoryPlace.device : place ?? HistoryPlace.share) {
                    HistoryPlace.share => tr.smbHistoryOnShare(smb.historyName),
                    HistoryPlace.device => tr.smbHistoryOnDevice,
                    HistoryPlace.readOnly => tr.smbHistoryReadOnly,
                  },
                  style: g.body(22, color: g.textDim),
                ),
              ),
            ],
            if (server.isMain)
              Text(tr.signingOutOf, style: g.body(22, color: g.textDim)),
            const SizedBox(height: 18),
            Wrap(spacing: 16, runSpacing: 14, children: buttons),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final ok = await confirm(
      context,
      title: tr.remove3(server.name),
      // A YouTube sign-in's channels go with it (youtube-subscriptions).
      message: server.session?.kind == ServerKind.youtube ? tr.youTubeRemoveBody : tr.itsProgramsLeave,
      action: tr.remove,
    );
    if (!ok || !context.mounted) return;
    await AppScope.read(context).removeServer(server.key);
  }
}

String _mbps(int kbps) => tr.mbps(kbps % 1000 == 0 ? kbps ~/ 1000 : (kbps / 1000).toStringAsFixed(1));

/// A server's quality limit: the profile's cap, or lower for a slow
/// (remote) server.
class _QualityLimitScreen extends StatelessWidget {
  const _QualityLimitScreen({required this.serverKey});

  final String serverKey;

  static const choices = <int?>[null, 20000, 12000, 8000, 4000, 2000];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final server = app.servers.byKey(serverKey);
    if (server == null) return const SizedBox.shrink();
    final current = server.qualityLimitKbps;
    return TvPage(
      title: tr.qualityLimit(server.name),
      hints: tr.moveOkSelectEscBack,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 40, 100, 40)),
          children: [
            Text(
              tr.streamsFromThis,
              style: g.body(24, color: g.textDim),
            ),
            if (server.kind == ServerKind.smb) ...[
              const SizedBox(height: 12),
              Text(tr.smbQualityNote, style: g.body(24, color: g.textDim)),
            ],
            const SizedBox(height: 24),
            for (final kbps in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TvToggle(
                    label: kbps == null ? tr.sameAsThe : _mbps(kbps),
                    radio: true,
                    on: kbps == current,
                    autofocus: kbps == current,
                    onPressed: () async {
                      await app.setServerQualityLimit(serverKey, kbps);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
