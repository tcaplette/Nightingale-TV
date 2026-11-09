import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../server/server_set.dart';
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
            const SizedBox(height: 28),
            for (final (i, s) in ordered.indexed)
              _ServerRow(
                server: s,
                position: i,
                count: ordered.length,
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
    final buttons = [
      if (state == ServerState.needsSignIn)
        TvButton(
          label: tr.signInAgain,
          icon: Icons.login,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => LoginScreen(againKey: server.key))),
        ),
      if (count > 1) ...[
        TvButton(
            label: tr.moveUp,
            icon: Icons.arrow_upward,
            onPressed: position == 0 ? null : () => app.moveServer(server.key, -1)),
        TvButton(
            label: tr.moveDown,
            icon: Icons.arrow_downward,
            onPressed: position == count - 1 ? null : () => app.moveServer(server.key, 1)),
      ],
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
            Text(
              [
                ?server.serverUrl,
                if (server.userName case final user?) tr.signedInAs(user),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: g.body(22, color: g.textDim),
            ),
            Text(
              [
                tr.countEpisodes(episodes),
                tr.countMovies(movies),
                if (songs != 0) tr.countSongs(songs),
                limit == null ? tr.qualitySameAsProfile : tr.qualityValue(_mbps(limit)),
              ].join(' · '),
              style: g.body(22, color: g.textDim),
            ),
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
      message: tr.itsProgramsLeave,
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
