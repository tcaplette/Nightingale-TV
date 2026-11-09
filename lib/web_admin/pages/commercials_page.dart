import 'package:flutter/material.dart';

import '../../commercials/break_plan.dart';
import '../../commercials/commercial_pool.dart';
import '../app.dart';
import '../widgets/break_plan_editor.dart';
import '../widgets/common.dart';
import '../widgets/folder_nodes.dart';
import '../../l10n/tr.dart';

/// Commercials: pools with the library folders they draw from, the main
/// break plan and channels' own plans, as on the TV.
class CommercialsPage extends StatelessWidget {
  const CommercialsPage({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final base = 'profiles/$profileId';
    return DataView<Map<String, Object?>>(
      load: () async => (await context.api.get('$base/commercials'))! as Map<String, Object?>,
      builder: (context, data, reload) {
        final plan = BreakPlan.fromJson((data['plan'] as Map).cast<String, Object?>());
        final pools = (data['pools'] as List).cast<Map<String, Object?>>();
        final channels = (data['channels'] as List).cast<Map<String, Object?>>();
        Future<void> run(Future<Object?> Function() call) async {
          final r = await attempt(context, call, profileId: profileId, onConflict: reload);
          if (r != null) await reload();
        }

        PoolKind kindOf(Map<String, Object?> pool) => PoolKind.values.asNameMap()[pool['kind']] ?? PoolKind.commercials;

        Future<void> setPlan(BreakPlan p) => run(() => context.api.put('$base/commercials/plan', {'plan': p.toJson()}));

        return PageBody(title: tr.commercials, children: [
          Section(title: tr.breaks, children: [
            Text(tr.clipsInAll('${data['clips']}')),
            RadioGroup<BreakMode>(
              groupValue: plan.mode,
              onChanged: (mode) async {
                if (mode != BreakMode.custom) return setPlan(plan.withMode(mode!));
                final roles = await editBreakPlan(context, title: tr.breaks, initial: plan.roles, pools: pools);
                if (roles != null) await setPlan(BreakPlan(mode: BreakMode.custom, roles: roles));
              },
              child: Column(children: [
                for (final mode in BreakMode.values)
                  RadioListTile<BreakMode>(
                      contentPadding: EdgeInsets.zero, value: mode, title: Text(mode == BreakMode.custom ? tr.custom2 : mode.label)),
              ]),
            ),
            if (plan.mode == BreakMode.custom)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final roles = await editBreakPlan(context, title: tr.breaks, initial: plan.roles, pools: pools);
                    if (roles != null) await setPlan(BreakPlan(mode: BreakMode.custom, roles: roles));
                  },
                  child: Text(tr.editCustomBreaks),
                ),
              ),
          ]),
          Section(
            title: tr.pools2,
            trailing: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(tr.newPool),
              onPressed: () => run(() => context.api.post('$base/pools')),
            ),
            children: [
              if (pools.isEmpty) Text(tr.aPoolIs),
              for (final p in pools) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p['name'] as String),
                  subtitle: Text([
                    kindOf(p).label,
                    tr.clips2('${(p['view'] as Map)['clips']}'),
                    for (final r in (p['roots'] as List).cast<Map>()) r['label'] as String,
                  ].join(' · ')),
                  trailing: PopupMenuButton<String>(
                    tooltip: tr.poolActions,
                    onSelected: (action) async {
                      final path = '$base/pools/${Uri.encodeComponent(p['id'] as String)}';
                      switch (action) {
                        case 'folders':
                          final roots = await pickFolders(context, profileId: profileId, pool: p);
                          if (roots != null && context.mounted) {
                            await run(() => context.api.put('$path/roots', {'roots': [for (final r in roots) r.toJson()]}));
                          }
                        case 'rename':
                          final name = await askText(context, title: tr.renamePool, label: tr.name, initial: p['name'] as String);
                          if (name != null && context.mounted) await run(() => context.api.put(path, {'name': name}));
                        case 'kind':
                          final kind = kindOf(p) == PoolKind.bumpers ? PoolKind.commercials : PoolKind.bumpers;
                          await run(() => context.api.put(path, {'kind': kind.name}));
                        case 'delete':
                          final ok = await confirm(context,
                              title: tr.delete3('${p['name']}'),
                              message: tr.plansThatDrew,
                              action: tr.delete);
                          if (ok && context.mounted) await run(() => context.api.delete(path));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'folders', child: Text(tr.chooseFolders2)),
                      PopupMenuItem(value: 'rename', child: Text(tr.rename)),
                      PopupMenuItem(
                        value: 'kind',
                        child: Text(kindOf(p) == PoolKind.bumpers ? tr.setTypeCommercials : tr.setTypeBumpers),
                      ),
                      PopupMenuItem(value: 'delete', child: Text(tr.delete)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Section(title: tr.channelsOwnPlans, children: [
            for (final c in channels)
              _ChannelPlanRow(
                channel: c,
                mainPlan: plan,
                pools: pools,
                onSet: (p) => run(() =>
                    context.api.put('$base/channels/${Uri.encodeComponent(c['id'] as String)}/plan', {'plan': p?.toJson()})),
              ),
          ]),
        ]);
      },
    );
  }
}

class _ChannelPlanRow extends StatelessWidget {
  const _ChannelPlanRow({required this.channel, required this.mainPlan, required this.pools, required this.onSet});

  final Map<String, Object?> channel;
  final BreakPlan mainPlan;
  final List<Map<String, Object?>> pools;
  final Future<void> Function(BreakPlan? plan) onSet;

  @override
  Widget build(BuildContext context) {
    final own = channel['plan'] == null ? null : BreakPlan.fromJson((channel['plan'] as Map).cast<String, Object?>());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text('${channel['number']}  ${channel['name']}'),
          DropdownButton<String>(
            value: own == null ? 'main' : own.mode.name,
            items: [
              DropdownMenuItem(value: 'main', child: Text(tr.mainSetting(mainPlan.mode.label))),
              for (final m in BreakMode.values)
                DropdownMenuItem(value: m.name, child: Text(m == BreakMode.custom ? tr.custom2 : m.label)),
            ],
            onChanged: (v) async {
              if (v == 'main') return onSet(null);
              final mode = BreakMode.values.byName(v!);
              if (mode != BreakMode.custom) return onSet(BreakPlan(mode: mode));
              final roles = await editBreakPlan(context,
                  title: tr.breaksOn('${channel['name']}'), initial: (own ?? mainPlan).roles, pools: pools);
              if (roles != null) await onSet(BreakPlan(mode: BreakMode.custom, roles: roles));
            },
          ),
        ],
      ),
    );
  }
}

/// Picks the folders a pool draws from, as the TV's folder picker does:
/// whole libraries, or folders, shows, seasons, collections and single
/// videos in them.
/// Returns the roots picked, or null when cancelled.
Future<List<PoolRoot>?> pickFolders(BuildContext context,
        {required String profileId, required Map<String, Object?> pool}) =>
    showDialog<List<PoolRoot>>(
      context: context,
      builder: (_) => _FolderPicker(profileId: profileId, pool: pool),
    );

class _FolderPicker extends StatefulWidget {
  const _FolderPicker({required this.profileId, required this.pool});
  final String profileId;
  final Map<String, Object?> pool;

  @override
  State<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<_FolderPicker> {
  late final Map<String, PoolRoot> _picked = {
    for (final r in (widget.pool['roots'] as List).cast<Map<String, Object?>>()) r['itemId'] as String: PoolRoot.fromJson(r),
  };

  /// The library being browsed, and the folders opened in it.
  Map<String, Object?>? _library;
  final _path = <Map<String, Object?>>[];
  final _trees = <String, Future<List<Map<String, Object?>>>>{};

  String get _base => 'profiles/${widget.profileId}/library/browse';

  Future<List<Map<String, Object?>>> _tree(String library) => _trees.putIfAbsent(
      library, () async => ((await context.api.get(_base, {'library': library}))! as List).cast<Map<String, Object?>>());

  void _toggle(String id, PoolRoot Function() root) => setState(() {
        if (_picked.remove(id) == null) _picked[id] = root();
      });

  String _label(List<Map<String, Object?>> path) =>
      [_library!['name'] as String, for (final n in path) n['name'] as String].join(' › ');

  @override
  Widget build(BuildContext context) {
    final library = _library;
    return AlertDialog(
      title: Text(tr.foldersFor('${widget.pool['name']}')),
      content: SizedBox(
        width: 520,
        height: 520,
        child: library == null
            ? DataView<List<Object?>>(
                load: () async => (await context.api.get(_base))! as List<Object?>,
                builder: (context, libraries, _) => ListView(children: [
                  for (final l in libraries.cast<Map<String, Object?>>())
                    ListTile(
                      leading: Checkbox(
                        value: _picked.containsKey(l['id']),
                        onChanged: (_) => _toggle(l['id'] as String,
                            () => PoolRoot(itemId: l['id'] as String, libraryId: l['id'] as String, label: l['name'] as String)),
                      ),
                      title: Text(l['name'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() => _library = l),
                    ),
                ]),
              )
            : FutureBuilder<List<Map<String, Object?>>>(
                future: _tree(library['id'] as String),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('${snapshot.error}');
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final nodes = _path.isEmpty
                      ? shownNodes(snapshot.data!, programsOnly: false)
                      : shownChildren(_path.last, programsOnly: false);
                  return ListView(children: [
                    ListTile(
                      leading: const Icon(Icons.arrow_upward),
                      title: Text(_label(_path)),
                      onTap: () => setState(() => _path.isEmpty ? _library = null : _path.removeLast()),
                    ),
                    if (nodes.isEmpty) ListTile(title: Text(tr.nothingInside2)),
                    for (final n in nodes)
                      () {
                        void toggle() => _toggle(
                            n['id'] as String,
                            () => PoolRoot(
                                itemId: n['id'] as String,
                                libraryId: library['id'] as String,
                                label: _label([..._path, n])));
                        final opens = opensNode(n, programsOnly: false);
                        return ListTile(
                          leading: Checkbox(
                            value: _picked.containsKey(n['id']),
                            onChanged: (_) => toggle(),
                            semanticLabel: n['name'] as String,
                          ),
                          title: Text(n['name'] as String),
                          subtitle: Text(nodeDetail(n, programsOnly: false)),
                          trailing: opens ? const Icon(Icons.chevron_right) : null,
                          // A video (or an empty folder) ticks from its name.
                          onTap: opens ? () => setState(() => _path.add(n)) : toggle,
                        );
                      }(),
                  ]);
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_picked.values.toList()), child: Text(tr.done)),
      ],
    );
  }
}
