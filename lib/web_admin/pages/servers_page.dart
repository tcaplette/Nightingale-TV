import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';
import 'server_page.dart' show signInDialog;
import '../../l10n/tr.dart';

/// A profile's servers (multi-server): the TV's Servers screen in the
/// browser. Each server's state and item counts, Add a server (the same
/// steps as signing in, Plex link code included), Sign in again, Remove,
/// the Play from order and a quality limit per server.
class ServersPage extends StatefulWidget {
  const ServersPage({super.key, required this.profileId});
  final String profileId;

  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  Map<String, Object?>? _data;
  String? _error;
  Timer? _poll;

  String get _base => 'profiles/${widget.profileId}/servers';

  @override
  void initState() {
    super.initState();
    _load();
    // States change as servers come and go.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = (await context.api.get(_base))! as Map<String, Object?>;
      if (mounted) setState(() => _data = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _change(Future<Object?> Function() call) async {
    final r = await attempt(context, call, profileId: widget.profileId, onConflict: _load);
    if (r is Map<String, Object?> && mounted) setState(() => _data = r);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final name = context.session.profileById(widget.profileId)?.name ?? '';
    if (d == null) {
      return PageBody(title: tr.servers, children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final servers = (d['servers'] as List).cast<Map<String, Object?>>();
    final order = [for (final s in servers) s['key'] as String];
    return PageBody(title: tr.servers2(name), children: [
      Section(children: [
        Text(tr.programsFromEvery),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(tr.addAServer),
            onPressed: () async {
              await signInDialog(context, widget.profileId, name, path: _base, title: tr.addAServerTo(name));
              await _load();
            },
          ),
        ),
      ]),
      for (final (i, s) in servers.indexed)
        _ServerCard(
          server: s,
          first: i == 0,
          last: i == servers.length - 1,
          onSignIn: () async {
            await signInDialog(context, widget.profileId, name,
                path: '$_base/${s['key']}/sign-in', title: tr.signInToAgain('${s['name']}'));
            await _load();
          },
          onMove: (delta) {
            final next = [...order];
            final key = next.removeAt(i);
            next.insert(i + delta, key);
            return _change(() => context.api.put('$_base/order', {'order': next}));
          },
          onLimit: (kbps) => _change(() => context.api.patch('$_base/${s['key']}', {'qualityLimitKbps': kbps})),
          onRemove: () async {
            final ok = await confirm(context,
                title: tr.remove3('${s['name']}'),
                message: tr.itsProgramsLeaveThe,
                action: tr.remove);
            if (!ok || !context.mounted) return;
            await _change(() => context.api.delete('$_base/${s['key']}'));
          },
        ),
    ]);
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard(
      {required this.server,
      required this.first,
      required this.last,
      required this.onSignIn,
      required this.onMove,
      required this.onLimit,
      required this.onRemove});

  final Map<String, Object?> server;
  final bool first, last;
  final VoidCallback onSignIn;
  final Future<void> Function(int delta) onMove;
  final Future<void> Function(int? kbps) onLimit;
  final VoidCallback onRemove;

  static const limits = <int?>[null, 20000, 12000, 8000, 4000, 2000];

  static String _label(int? kbps) => kbps == null ? tr.sameAsThe : tr.mbps(kbps ~/ 1000);

  @override
  Widget build(BuildContext context) {
    final main = server['main'] == true;
    final state = server['state'] as String;
    final limit = server['qualityLimitKbps'] as int?;
    final scheme = Theme.of(context).colorScheme;
    final kind = '${server['kind']}';
    return Section(title: '${server['name']}', children: [
      Text('${kind[0].toUpperCase()}${kind.substring(1)}${main ? ' · Main server' : ''} · ${server['stateLabel']}',
          style: TextStyle(color: state == 'ok' ? null : scheme.error, fontWeight: FontWeight.w600)),
      Text([
        if (server['url'] != null) server['url'],
        if (server['user'] != null) tr.signedInAs('${server['user']}'),
      ].join(' · ')),
      Text([
            tr.countEpisodes((server['episodes'] as num).toInt()),
            tr.countMovies((server['movies'] as num).toInt()),
            if (server['songs'] != 0) tr.countSongs((server['songs'] as num).toInt()),
          ].join(' · ')),
      if (main) Text(tr.signingOutOf),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (state == 'needsSignIn') FilledButton(onPressed: onSignIn, child: Text(tr.signInAgain)),
        if (!(first && last)) ...[
          OutlinedButton.icon(
              icon: const Icon(Icons.arrow_upward), label: Text(tr.moveUp), onPressed: first ? null : () => onMove(-1)),
          OutlinedButton.icon(
              icon: const Icon(Icons.arrow_downward), label: Text(tr.moveDown), onPressed: last ? null : () => onMove(1)),
        ],
        DropdownMenu<int?>(
          label: Text(tr.qualityLimit2),
          initialSelection: limit,
          onSelected: (v) => onLimit(v),
          dropdownMenuEntries: [for (final l in limits) DropdownMenuEntry(value: l, label: _label(l))],
        ),
        if (!main)
          TextButton.icon(
              icon: Icon(Icons.delete_outline, color: scheme.error),
              label: Text(tr.remove, style: TextStyle(color: scheme.error)),
              onPressed: onRemove),
      ]),
    ]);
  }
}
