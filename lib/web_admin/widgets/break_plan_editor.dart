import 'package:flutter/material.dart';

import '../../commercials/break_plan.dart';
import '../../ui/format.dart';

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

  static String _length(Duration d) {
    if (d == Duration.zero) return 'None';
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    return d.inSeconds % 60 == 0 ? '${d.inMinutes} min' : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _example(String name, int minutes) {
    final s = resolve(BreakPlan(mode: BreakMode.custom, roles: _roles), Duration(minutes: minutes));
    if (!s.hasBreaks) return '$name: no breaks';
    final mids = s.midCount == 0 ? '' : ', ${s.midCount} break${s.midCount == 1 ? '' : 's'} inside';
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
        initialValue: widget.pools.any((p) => p['id'] == current) ? current : null,
        decoration: const InputDecoration(labelText: 'Clips from'),
        items: [
          const DropdownMenuItem(value: null, child: Text('All pools')),
          for (final p in widget.pools)
            DropdownMenuItem(
              value: p['id'] as String,
              child: Text('${p['name']}  ·  ${(p['view'] as Map?)?['clips'] ?? 0} clips'),
            ),
        ],
        onChanged: enabled ? (id) => setState(() => _roles = _roles.withPool(role, id)) : null,
      ),
    );
  }

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
                  Text(_example('22-min sitcom', 22)),
                  Text(_example('44-min drama', 44)),
                  Text(_example('100-min movie', 100)),
                ]),
              ),
            ),
            _heading('Pre-roll', 'Before each program'),
            _choices('Length', CustomRoles.preRollChoices, _roles.preRoll, _length, (v) => _roles.copyWith(preRoll: v)),
            _pool(BreakRole.pre, _roles.preRoll > Duration.zero),
            _heading('Mid-roll', 'Breaks inside shows and movies, at act breaks when they can be found'),
            _choices<Duration?>('Every', CustomRoles.midIntervalChoices, _roles.midInterval,
                (v) => v == null ? 'Off' : '${v.inMinutes} min', (v) => _roles.copyWith(midInterval: () => v)),
            _choices('Length', CustomRoles.midLengthChoices, _roles.midLength, _length, (v) => _roles.copyWith(midLength: v)),
            _pool(BreakRole.mid, _roles.midInterval != null),
            _heading('Post-roll', 'After each program'),
            _choices('Length', CustomRoles.postRollChoices, _roles.postRoll, _length, (v) => _roles.copyWith(postRoll: v)),
            _pool(BreakRole.post, _roles.postRoll > Duration.zero),
            _heading('Tail', 'Pads each slot to the clock, so programs start on time'),
            _choices<Duration?>(
              'Pad',
              CustomRoles.tailGridChoices,
              _roles.tailGrid,
              (v) => switch (v?.inMinutes) {
                null => 'None',
                60 => 'To the hour',
                final m => 'To :$m',
              },
              (v) => _roles.copyWith(tailGrid: () => v),
            ),
            _pool(BreakRole.tail, _roles.tailGrid != null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_roles), child: const Text('Save')),
        ],
      );
}
