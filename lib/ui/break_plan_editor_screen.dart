import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../commercials/break_plan.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'menu_screen.dart' show confirm;
import 'widgets/tv_focus.dart';

/// The settings of a Custom break plan, role by role: for the main plan or
/// one channel's own. Pops with the new settings on Save.
class BreakPlanEditorScreen extends StatefulWidget {
  const BreakPlanEditorScreen({super.key, required this.initial, required this.title});

  final CustomRoles initial;

  /// e.g. "Break settings" or "Breaks on Cartoon Classics".
  final String title;

  @override
  State<BreakPlanEditorScreen> createState() => _BreakPlanEditorScreenState();
}

class _BreakPlanEditorScreenState extends State<BreakPlanEditorScreen> {
  late CustomRoles _roles = widget.initial;

  /// The rows, top to bottom. ▲▼ move between them, landing on each row's
  /// chosen option (Flutter's own ▲▼ go by position, and would skip rows
  /// from a button at the far end of one).
  static const _rows = ['pre', 'every', 'length', 'post', 'tail', 'actions'];
  final _selected = <String, FocusNode>{};
  final _nodes = <String, FocusNode>{};
  FocusNode _node(String key) => _nodes.putIfAbsent(key, () => FocusNode(debugLabel: key));

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _rowKey(String row, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final i = _rows.indexOf(row);
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown when i + 1 < _rows.length => _rows[i + 1],
      LogicalKeyboardKey.arrowUp when i > 0 => _rows[i - 1],
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _selected[target]?.requestFocus();
    return KeyEventResult.handled;
  }

  bool get _changed => _roles != widget.initial;

  void _set(CustomRoles r) => setState(() => _roles = r);

  Future<void> _leave() async {
    if (_changed) {
      final discard = await confirm(
        context,
        title: 'Leave without saving?',
        message: 'Your changes to the break settings are lost.',
        action: 'Leave',
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickPool(BreakRole role) async {
    final picked = await Navigator.of(context).push<_PoolChoice>(
      MaterialPageRoute(
        builder: (_) => _PoolChooserScreen(role: role, selected: _roles.poolFor(role)),
      ),
    );
    if (picked != null) _set(_roles.withPool(role, picked.id));
  }

  static String _length(Duration d) {
    if (d == Duration.zero) return 'None';
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    return d.inSeconds % 60 == 0
        ? '${d.inMinutes} min'
        : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    String poolName(String? id) => id == null ? 'All pools' : app.poolById(id)?.name ?? 'All pools';

    /// A row of choices; with [pool], ending in the button that picks the
    /// role's pool (▶ from the choices reaches it).
    Widget choices<T>(
      String row,
      List<T> values,
      T current,
      String Function(T) label,
      CustomRoles Function(T) apply, {
      bool autofocus = false,
      BreakRole? pool,
      bool poolEnabled = true,
      String? rowLabel,
    }) {
      final chosen = values.contains(current) ? values.indexOf(current) : 0;
      _selected[row] = _node('$row:$chosen');
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) => _rowKey(row, event),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (rowLabel != null)
              SizedBox(
                width: 120,
                child: Text(rowLabel, style: g.display(28, weight: FontWeight.w600, color: g.textDim)),
              ),
            for (final (i, v) in values.indexed)
              TvToggle(
                label: label(v),
                radio: true,
                focusNode: _node('$row:$i'),
                autofocus: autofocus && i == chosen,
                on: i == chosen,
                onPressed: () => _set(apply(v)),
              ),
            if (pool != null) ...[
              const SizedBox(width: 28),
              TvButton(
                label: 'Clips from: ${poolName(_roles.poolFor(pool))}',
                icon: Icons.video_library,
                onPressed: poolEnabled ? () => _pickPool(pool) : null,
              ),
            ],
          ],
        ),
      );
    }

    _selected['actions'] = _node('actions:save');

    return TvPage(
      title: widget.title,
      hints: '▲▼◀▶ Move    OK Select    ESC Back',
      onBack: _leave,
      // Full width, so each setting's choices fit on one line and ◀▶ reach
      // them all.
      child: FocusTraversalGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(100, 24, 100, 40),
          children: [
            _Examples(roles: _roles),
            _section(g, 'PRE-ROLL', 'Before each program'),
            choices(
              'pre',
              CustomRoles.preRollChoices,
              _roles.preRoll,
              _length,
              (v) => _roles.copyWith(preRoll: v),
              autofocus: true,
              pool: BreakRole.pre,
              poolEnabled: _roles.preRoll > Duration.zero,
            ),
            _section(g, 'MID-ROLL', 'Breaks inside shows and movies, at act breaks when they can be found'),
            choices<Duration?>(
              'every',
              CustomRoles.midIntervalChoices,
              _roles.midInterval,
              (v) => v == null ? 'Off' : '${v.inMinutes} min',
              (v) => _roles.copyWith(midInterval: () => v),
              rowLabel: 'Every',
            ),
            const SizedBox(height: 12),
            choices(
              'length',
              CustomRoles.midLengthChoices,
              _roles.midLength,
              _length,
              (v) => _roles.copyWith(midLength: v),
              rowLabel: 'Length',
              pool: BreakRole.mid,
              poolEnabled: _roles.midInterval != null,
            ),
            _section(g, 'POST-ROLL', 'After each program'),
            choices(
              'post',
              CustomRoles.postRollChoices,
              _roles.postRoll,
              _length,
              (v) => _roles.copyWith(postRoll: v),
              pool: BreakRole.post,
              poolEnabled: _roles.postRoll > Duration.zero,
            ),
            _section(g, 'TAIL', 'Pads each slot to the clock, so programs start on time'),
            choices<Duration?>(
              'tail',
              CustomRoles.tailGridChoices,
              _roles.tailGrid,
              (v) => switch (v?.inMinutes) {
                null => 'None',
                60 => 'To the hour',
                final m => 'To :$m',
              },
              (v) => _roles.copyWith(tailGrid: () => v),
              pool: BreakRole.tail,
              poolEnabled: _roles.tailGrid != null,
            ),
            const SizedBox(height: 40),
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (_, event) => _rowKey('actions', event),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  TvButton(
                    label: 'Save',
                    icon: Icons.check,
                    focusNode: _node('actions:save'),
                    onPressed: () => Navigator.of(context).pop(_roles),
                  ),
                  TvButton(label: 'Cancel', onPressed: _leave),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _section(GuideTheme g, String title, String detail) => Padding(
    padding: const EdgeInsets.only(top: 32, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: g.display(26, weight: FontWeight.w800, color: g.accent),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(detail, style: g.body(22, color: g.textDim)),
        ),
      ],
    ),
  );
}

/// How the settings work out for a sitcom, a drama and a movie.
class _Examples extends StatelessWidget {
  const _Examples({required this.roles});

  final CustomRoles roles;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final plan = BreakPlan(mode: BreakMode.custom, roles: roles);
    String example(String name, int minutes) {
      final s = resolve(plan, Duration(minutes: minutes));
      if (!s.hasBreaks) return '$name: no breaks';
      final mids = s.midCount == 0 ? '' : ', ${s.midCount} break${s.midCount == 1 ? '' : 's'} inside';
      return '$name: ${formatMinutes(s.slotLength)}$mids';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(g.radius * 2),
        border: Border.all(color: g.cellBorder, width: 2),
      ),
      child: Text(
        [example('22-min sitcom', 22), example('44-min drama', 44), example('100-min movie', 100)].join('     ·     '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: g.body(24),
      ),
    );
  }
}

class _PoolChoice {
  const _PoolChoice(this.id);

  /// Null: all pools.
  final String? id;
}

class _PoolChooserScreen extends StatelessWidget {
  const _PoolChooserScreen({required this.role, required this.selected});

  final BreakRole role;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pools = app.settings.commercialPools;
    final options = <(String?, String, int)>[
      (null, 'All pools', app.catalog.clipsFor(null).length),
      for (final p in pools) (p.id, p.name, app.catalog.clipsFor(p.id).length),
    ];
    return TvPage(
      title: '${role.label} clips',
      hints: '▲▼ Move    OK Choose    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(120, 32, 120, 32),
          children: [
            for (final (id, name, clips) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TvButton(
                  label: '$name  ·  $clips clip${clips == 1 ? '' : 's'}',
                  icon: id == selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  autofocus: id == selected,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(_PoolChoice(id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
