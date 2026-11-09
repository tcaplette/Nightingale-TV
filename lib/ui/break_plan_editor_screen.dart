import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../commercials/break_plan.dart';
import '../commercials/commercial_pool.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'menu_screen.dart' show confirm;
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

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
  static const _rows = ['pre', 'every', 'length', 'post', 'tail', 'bumpers', 'actions'];
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
        title: tr.leaveWithoutSaving,
        message: tr.yourChangesTo,
        action: tr.leave,
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickPool(BreakRole role) async {
    final picked = await Navigator.of(context).push<_PoolChoice>(
      MaterialPageRoute(
        builder: (_) => _PoolChooserScreen(
          title: tr.clips2(role.label),
          allLabel: tr.allPools,
          kind: PoolKind.commercials,
          selected: _roles.poolFor(role),
        ),
      ),
    );
    if (picked != null) _set(_roles.withPool(role, picked.id));
  }

  Future<void> _pickBumperPool() async {
    final picked = await Navigator.of(context).push<_PoolChoice>(
      MaterialPageRoute(
        builder: (_) => _PoolChooserScreen(
          title: tr.bumpers,
          allLabel: tr.allBumperPools,
          kind: PoolKind.bumpers,
          selected: _roles.bumperPool,
        ),
      ),
    );
    if (picked != null) _set(_roles.withBumpers(picked.id));
  }

  static String _length(Duration d) {
    if (d == Duration.zero) return tr.none;
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    return d.inSeconds % 60 == 0
        ? tr.min(d.inMinutes)
        : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final portrait = ScreenLayout.of(context).isPortrait;
    String poolName(String? id) => id == null ? tr.allPools : app.poolById(id)?.name ?? tr.allPools;

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
                // Upright, a narrower label column.
                width: portrait ? 100 : 120,
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
              if (!portrait) const SizedBox(width: 28),
              TvButton(
                label: tr.clipsFrom(poolName(_roles.poolFor(pool))),
                icon: Icons.video_library,
                onPressed: poolEnabled ? () => _pickPool(pool) : null,
              ),
            ],
          ],
        ),
      );
    }

    /// None, all bumper pools, or one picked through the chooser.
    Widget bumpers() {
      final poolName = _roles.bumperPool == null ? null : app.poolById(_roles.bumperPool!)?.name;
      final chosen = _roles.noBumpers ? 0 : (poolName == null ? 1 : 2);
      _selected['bumpers'] = _node('bumpers:$chosen');
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) => _rowKey('bumpers', event),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            TvToggle(
              label: tr.none,
              radio: true,
              focusNode: _node('bumpers:0'),
              on: chosen == 0,
              onPressed: () => _set(_roles.withBumpers(null, none: true)),
            ),
            TvToggle(
              label: tr.allBumperPools,
              radio: true,
              focusNode: _node('bumpers:1'),
              on: chosen == 1,
              onPressed: () => _set(_roles.withBumpers(null)),
            ),
            TvToggle(
              label: poolName == null ? tr.onePool : '$poolName…',
              radio: true,
              focusNode: _node('bumpers:2'),
              on: chosen == 2,
              onPressed: _pickBumperPool,
            ),
          ],
        ),
      );
    }

    _selected['actions'] = _node('actions:save');

    return TvPage(
      title: widget.title,
      hints: tr.moveOkSelectEsc,
      onBack: _leave,
      // Full width, so each setting's choices fit on one line and ◀▶ reach
      // them all.
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 24, 100, 40)),
          children: [
            _Examples(roles: _roles),
            _section(g, tr.preRoll2, tr.beforeEachProgram),
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
            _section(g, tr.midRoll2, tr.breaksInsideShows),
            choices<Duration?>(
              'every',
              CustomRoles.midIntervalChoices,
              _roles.midInterval,
              (v) => v == null ? tr.off : tr.min(v.inMinutes),
              (v) => _roles.copyWith(midInterval: () => v),
              rowLabel: tr.every,
            ),
            const SizedBox(height: 12),
            choices(
              'length',
              CustomRoles.midLengthChoices,
              _roles.midLength,
              _length,
              (v) => _roles.copyWith(midLength: v),
              rowLabel: tr.length,
              pool: BreakRole.mid,
              poolEnabled: _roles.midInterval != null,
            ),
            _section(g, tr.postRoll2, tr.afterEachProgram),
            choices(
              'post',
              CustomRoles.postRollChoices,
              _roles.postRoll,
              _length,
              (v) => _roles.copyWith(postRoll: v),
              pool: BreakRole.post,
              poolEnabled: _roles.postRoll > Duration.zero,
            ),
            _section(g, tr.tail2, tr.padsEachSlot),
            choices<Duration>(
              'tail',
              CustomRoles.tailGridChoices,
              _roles.tailGrid,
              (v) => v.inMinutes == 60 ? tr.toTheHour : tr.toTheHalf,
              (v) => _roles.copyWith(tailGrid: v),
              pool: BreakRole.tail,
            ),
            _section(g, tr.bumpers2, tr.openAndClose),
            bumpers(),
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
                    label: tr.save,
                    icon: Icons.check,
                    focusNode: _node('actions:save'),
                    onPressed: () => Navigator.of(context).pop(_roles),
                  ),
                  TvButton(label: tr.cancel, onPressed: _leave),
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
      if (!s.hasBreaks) return tr.noBreaks(name);
      final mids = s.midCount == 0 ? '' : tr.breaksInside(s.midCount);
      return '$name: ${formatMinutes(s.slotLength)}$mids';
    }

    final examples = [example(tr.n22MinSitcom, 22), example(tr.n44MinDrama, 44), example(tr.n100MinMovie, 100)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(g.radius * 2),
        border: Border.all(color: g.cellBorder, width: 2),
      ),
      // Upright, one example to a line.
      child: ScreenLayout.of(context).isPortrait
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final e in examples) Text(e, style: g.body(24))],
            )
          : Text(
        examples.join('     ·     '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: g.body(24),
      ),
    );
  }
}

class _PoolChoice {
  const _PoolChoice(this.id);

  /// Null: all the pools of that type.
  final String? id;
}

class _PoolChooserScreen extends StatelessWidget {
  const _PoolChooserScreen({required this.title, required this.allLabel, required this.kind, required this.selected});

  final String title;
  final String allLabel;

  /// The type of pool listed.
  final PoolKind kind;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pools = [for (final p in app.settings.commercialPools) if (p.kind == kind) p];
    final all = kind == PoolKind.bumpers ? app.catalog.current.bumpers : app.catalog.clipsFor(null);
    final options = <(String?, String, int)>[
      (null, allLabel, all.length),
      for (final p in pools) (p.id, p.name, app.catalog.clipsFor(p.id).length),
    ];
    return TvPage(
      title: title,
      hints: tr.moveOkChoose,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(120, 32, 120, 32)),
          children: [
            for (final (id, name, clips) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TvButton(
                  label: tr.clips(name, clips),
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
