import 'package:flutter/material.dart';

import '../../commercials/break_plan.dart';
import '../../commercials/commercial_pool.dart';
import '../../ui/format.dart';
import '../../l10n/tr.dart';

/// The Custom break settings, with the same choices and wording as the
/// TV's break plan editor. [pools] are the profile's pools (with their
/// clip counts under "view"). Returns the roles saved, or null.
Future<CustomRoles?> editBreakPlan(BuildContext context,
        {required String title, required CustomRoles initial, required List<Map<String, Object?>> pools}) =>
    showDialog<CustomRoles>(
      context: context,
      builder: (_) => _BreakPlanEditor(title: title, initial: initial, pools: pools),
    );

class _BreakPlanEditor extends StatefulWidget {
  const _BreakPlanEditor({required this.title, required this.initial, required this.pools});

  final String title;
  final CustomRoles initial;
  final List<Map<String, Object?>> pools;

  @override
  State<_BreakPlanEditor> createState() => _BreakPlanEditorState();
}

class _BreakPlanEditorState extends State<_BreakPlanEditor> {
  late CustomRoles _roles = widget.initial;

  bool _isBumpers(Map<String, Object?> pool) => pool['kind'] == PoolKind.bumpers.name;
  late final _commercialPools = [for (final p in widget.pools) if (!_isBumpers(p)) p];
  late final _bumperPools = [for (final p in widget.pools) if (_isBumpers(p)) p];

  static String _length(Duration d) {
    if (d == Duration.zero) return tr.none;
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    return d.inSeconds % 60 == 0 ? tr.min(d.inMinutes) : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _example(String name, int minutes) {
    final s = resolve(BreakPlan(mode: BreakMode.custom, roles: _roles), Duration(minutes: minutes));
    if (!s.hasBreaks) return tr.noBreaks(name);
    final mids = s.midCount == 0 ? '' : tr.breaksInside(s.midCount);
    return '$name: ${formatMinutes(s.slotLength)}$mids';
  }

  Widget _choices<T>(String label, List<T> values, T selected, String Function(T) name, CustomRoles Function(T) set) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final v in values)
              ChoiceChip(label: Text(name(v)), selected: v == selected, onSelected: (_) => setState(() => _roles = set(v))),
          ]),
        ]),
      );

  Widget _pool(BreakRole role, bool enabled) {
    final current = _roles.poolFor(role);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<String?>(
        initialValue: _commercialPools.any((p) => p['id'] == current) ? current : null,
        decoration: InputDecoration(labelText: tr.clipsFrom2),
        items: [
          DropdownMenuItem(value: null, child: Text(tr.allPools)),
          for (final p in _commercialPools)
            DropdownMenuItem(
              value: p['id'] as String,
              child: Text(tr.clips4('${p['name']}', '${(p['view'] as Map?)?['clips'] ?? 0}')),
            ),
        ],
        onChanged: enabled ? (id) => setState(() => _roles = _roles.withPool(role, id)) : null,
      ),
    );
  }

  static const _noBumpers = ':none', _allBumpers = ':all';

  Widget _bumpers() => DropdownButtonFormField<String>(
        initialValue: _roles.noBumpers
            ? _noBumpers
            : _bumperPools.any((p) => p['id'] == _roles.bumperPool)
                ? _roles.bumperPool
                : _allBumpers,
        decoration: InputDecoration(labelText: tr.clipsFrom2),
        items: [
          DropdownMenuItem(value: _noBumpers, child: Text(tr.none)),
          DropdownMenuItem(value: _allBumpers, child: Text(tr.allBumperPools)),
          for (final p in _bumperPools)
            DropdownMenuItem(
              value: p['id'] as String,
              child: Text(tr.clips4('${p['name']}', '${(p['view'] as Map?)?['clips'] ?? 0}')),
            ),
        ],
        onChanged: (v) => setState(() => _roles = switch (v) {
              _noBumpers => _roles.withBumpers(null, none: true),
              _allBumpers || null => _roles.withBumpers(null),
              final id => _roles.withBumpers(id),
            }),
      );

  Widget _heading(String title, String detail) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        scrollable: true,
        content: SizedBox(
          width: 560,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_example(tr.n22MinSitcom, 22)),
                  Text(_example(tr.n44MinDrama, 44)),
                  Text(_example(tr.n100MinMovie, 100)),
                ]),
              ),
            ),
            _heading(tr.preRoll, tr.beforeEachProgram),
            _choices(tr.length, CustomRoles.preRollChoices, _roles.preRoll, _length, (v) => _roles.copyWith(preRoll: v)),
            _pool(BreakRole.pre, _roles.preRoll > Duration.zero),
            _heading(tr.midRoll, tr.breaksInsideShows),
            _choices<Duration?>(tr.every, CustomRoles.midIntervalChoices, _roles.midInterval,
                (v) => v == null ? tr.off : tr.min(v.inMinutes), (v) => _roles.copyWith(midInterval: () => v)),
            _choices(tr.length, CustomRoles.midLengthChoices, _roles.midLength, _length, (v) => _roles.copyWith(midLength: v)),
            _pool(BreakRole.mid, _roles.midInterval != null),
            _heading(tr.postRoll, tr.afterEachProgram),
            _choices(tr.length, CustomRoles.postRollChoices, _roles.postRoll, _length, (v) => _roles.copyWith(postRoll: v)),
            _pool(BreakRole.post, _roles.postRoll > Duration.zero),
            _heading(tr.tail, tr.padsEachSlot),
            _choices<Duration>(
              tr.pad,
              CustomRoles.tailGridChoices,
              _roles.tailGrid,
              (v) => v.inMinutes == 60 ? tr.toTheHour : tr.toTheHalf,
              (v) => _roles.copyWith(tailGrid: v),
            ),
            _pool(BreakRole.tail, true),
            _heading(tr.bumpers, tr.openAndClose),
            _bumpers(),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(_roles), child: Text(tr.save)),
        ],
      );
}
