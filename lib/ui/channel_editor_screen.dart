import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../channels/schedule.dart';
import '../live/live_tv_manager.dart';
import '../channels/channel.dart';
import '../commercials/break_plan.dart';
import '../theme/tv_theme.dart';
import 'break_plan_editor_screen.dart';
import 'icon_picker_screen.dart';
import 'widgets/channel_logo.dart';
import 'widgets/adaptive.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// Rename, renumber, re-icon, reorder or hide channels.
class ChannelEditorScreen extends StatefulWidget {
  const ChannelEditorScreen({super.key});

  @override
  State<ChannelEditorScreen> createState() => _ChannelEditorScreenState();
}

class _ChannelEditorScreenState extends State<ChannelEditorScreen> {
  String? _selectedId;
  final _name = TextEditingController();

  /// Each row's focus, so a tapped row holds it too: the list comes back to
  /// it, and the side-by-side layout keeps it selected after turning.
  final _rows = <String, FocusNode>{};
  FocusNode _row(String id) => _rows.putIfAbsent(id, () => FocusNode(debugLabel: 'channel $id'));

  @override
  void dispose() {
    _name.dispose();
    for (final node in _rows.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(Channel ch) {
    if (_selectedId == ch.id) return;
    setState(() {
      _selectedId = ch.id;
      _name.text = ch.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final channels = app.allChannels;
    if (_selectedId == null && channels.isNotEmpty) {
      _selectedId = channels.first.id;
      _name.text = channels.first.name;
    }
    final selected = channels.where((c) => c.id == _selectedId).firstOrNull;
    final layout = ScreenLayout.of(context);
    final portrait = layout.isPortrait;

    final logoModes = [
      for (final mode in LogoMode.values)
        TvToggle(
          label: mode.label,
          radio: true,
          on: app.settings.logoMode == mode,
          onPressed: () => app.setMainLogoMode(mode),
        ),
    ];
    const logoHelp = 'The channel logo in the corner of the picture, on the TV and in Live TV export.';
    final rows = [
      for (final (i, ch) in channels.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Builder(
            builder: (rowContext) => TvFocusable(
              autofocus: i == 0,
              focusNode: _row(ch.id),
              onPressed: () {
                _select(ch);
                _row(ch.id).requestFocus();
                // Upright, the channel's settings are a page of their own.
                ListDetail.open(rowContext);
              },
              onFocusChanged: (f) {
                if (f) _select(ch);
              },
              builder: (context, focused) {
                final isSelected = ch.id == _selectedId && !portrait;
                final fg = g.text;
                // Outline rather than fill: a solid yellow row would
                // hide yellow channel icons.
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: 84,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: focused || isSelected ? g.cellBorder : g.cell,
                    borderRadius: BorderRadius.circular(g.radius),
                    border: Border.all(color: focused ? g.focus : Colors.transparent, width: 4),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          '${ch.number}',
                          style: g.display(38, weight: FontWeight.w800, color: g.accent),
                        ),
                      ),
                      ChannelLogo(icon: ch.icon, size: 56, width: 90, fallbackText: ch.name),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          ch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: g.display(30, weight: FontWeight.w600, color: fg),
                        ),
                      ),
                      if (ch.favorite) Icon(Icons.star, color: fg, size: 28),
                      if (ch.hidden) Icon(Icons.visibility_off, color: fg, size: 28),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
    ];

    final list = FocusTraversalGroup(
      child: ListView(
        padding: portrait
            ? EdgeInsets.fromLTRB(layout.gutter, 24, layout.gutter, 32)
            : const EdgeInsets.fromLTRB(80, 32, 24, 32),
        children: [
          // Upright, the main logo setting scrolls with the list, wrapping.
          if (portrait) ...[
            Text('CHANNEL LOGO', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 16, children: logoModes),
            const SizedBox(height: 12),
            Text(logoHelp, style: g.body(22, color: g.textDim)),
            const SizedBox(height: 28),
          ],
          ...rows,
        ],
      ),
    );

    return TvPage(
      title: 'Channels & icons',
      hints: '▲▼ Channels    ▶ Edit    OK Select    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!portrait)
            FocusTraversalGroup(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(80, 24, 100, 0),
                child: Row(
                  children: [
                    Text('CHANNEL LOGO', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
                    const SizedBox(width: 24),
                    for (final toggle in logoModes) ...[toggle, const SizedBox(width: 16)],
                    Expanded(
                      child: Text(logoHelp, maxLines: 2, overflow: TextOverflow.ellipsis, style: g.body(22, color: g.textDim)),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListDetail(
              list: list,
              hasSelection: selected != null,
              detailTitle: selected?.name ?? '',
              // What's selected when the page builds (it may build before
              // this screen does).
              detail: (context) {
                final ch = AppScope.read(context).allChannels.where((c) => c.id == _selectedId).firstOrNull;
                return ch == null
                    ? Center(child: Text('No channels yet', style: g.display(40)))
                    : FocusTraversalGroup(child: _details(context, ch));
              },
              tv: (context, list, detail) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 720, child: list),
                  Expanded(child: detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, Channel ch) {
    final app = AppScope.read(context);
    final g = context.guide;
    final schedule = app.scheduleFor(ch);
    final loop = schedule is ChannelSchedule ? schedule.loop?.loopLength : null;
    final blockCount = app.blocks.where((b) => b.channelId == ch.id).length;
    // A live channel (live-tv-sources): its source's stream, with no
    // playlist, order, breaks, blocks or premieres to set.
    final live = ch.isLive ? app.live.lookup(ch) : null;

    final portrait = ScreenLayout.of(context).isPortrait;

    return ListView(
      padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(40, 32, 100, 32)),
      children: [
        Row(
          children: [
            ChannelLogo(icon: ch.icon, size: portrait ? 96 : 150, width: portrait ? 150 : 240, fallbackText: ch.name),
            SizedBox(width: portrait ? 24 : 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHANNEL ${ch.number}',
                    style: g.display(30, weight: FontWeight.w800, color: g.accent),
                  ),
                  Text(
                    ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.display(portrait ? 40 : 56, weight: FontWeight.w800),
                  ),
                  Text(
                    ch.isLive
                        ? [
                            'Live',
                            if (live != null) live.source.name,
                            if (live?.info.number case final n?) 'channel $n there',
                          ].join(' · ')
                        : [
                      if (ch.blockOnly) 'Programming blocks only' else '${ch.playlist.length} programs',
                      if (loop != null) 'repeats every ${_loopText(loop)}',
                      if (blockCount > 0) '$blockCount programming block${blockCount == 1 ? '' : 's'}',
                    ].join(' · '),
                    style: g.body(24, color: g.textDim),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            Expanded(
              child: TvTextField(controller: _name, label: 'Channel name', onSubmitted: (_) => _saveName(ch)),
            ),
            const SizedBox(width: 16),
            TvButton(label: 'Rename', icon: Icons.check, onPressed: () => _saveName(ch)),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            TvButton(
              label: 'Change icon',
              icon: Icons.image,
              onPressed: () async {
                final icon = await Navigator.of(context)
                    .push<ChannelIcon>(MaterialPageRoute(builder: (_) => IconPickerScreen(channel: ch)));
                if (icon != null) await app.updateChannel(ch, icon: icon);
              },
            ),
            if (live != null)
              TvButton(
                label: "Source's logo",
                icon: Icons.settings_input_antenna,
                onPressed: () => app.updateChannel(ch, icon: LiveTvManager.defaultIcon(live.info)),
              ),
            TvButton(
              label: 'Number −',
              icon: Icons.remove,
              onPressed: ch.number > 1 ? () => app.updateChannel(ch, number: ch.number - 1) : null,
            ),
            TvButton(
              label: 'Number +',
              icon: Icons.add,
              onPressed: () => app.updateChannel(ch, number: ch.number + 1),
            ),
          ],
        ),
        if (!ch.blockOnly && !ch.isLive) const SizedBox(height: 16),
        if (!ch.blockOnly && !ch.isLive)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // Music channels only shuffle, never the same artist twice in a row.
              for (final order in PlaybackOrder.values)
                if (!ch.isMusic || order == PlaybackOrder.random)
                TvButton(
                  label: order.label,
                  icon: ch.order == order ? Icons.radio_button_checked : Icons.radio_button_off,
                  onPressed: () async {
                    await app.updateChannel(ch, order: order);
                    if (context.mounted) await _retuneIfWatching(context, ch);
                  },
                ),
            ],
          ),
        if (!ch.isLive) ...[
        const SizedBox(height: 28),
        Text('COMMERCIALS', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            TvToggle(
              label: 'Main setting (${app.settings.commercialPlan.mode.label})',
              radio: true,
              on: ch.commercialPlan == null,
              onPressed: () => _setPlan(context, ch, null),
            ),
            TvToggle(
              label: 'Off',
              radio: true,
              on: ch.commercialPlan?.mode == BreakMode.off,
              onPressed: () => _setPlan(context, ch, BreakPlan.off),
            ),
            TvToggle(
              label: 'Automatic',
              radio: true,
              on: ch.commercialPlan?.mode == BreakMode.automatic,
              onPressed: () => _setPlan(context, ch, BreakPlan.automatic),
            ),
            TvToggle(
              label: 'Custom…',
              radio: true,
              on: ch.commercialPlan?.mode == BreakMode.custom,
              onPressed: () async {
                // Starts from the channel's own settings, else the main ones.
                final start = (ch.commercialPlan ?? app.settings.commercialPlan).roles;
                final roles = await Navigator.of(context).push<CustomRoles>(MaterialPageRoute(
                    builder: (_) => BreakPlanEditorScreen(initial: start, title: 'Breaks on ${ch.name}')));
                if (roles != null && context.mounted) {
                  await _setPlan(context, ch, BreakPlan(mode: BreakMode.custom, roles: roles));
                }
              },
            ),
          ],
        ),
        ],
        const SizedBox(height: 28),
        Text('CHANNEL LOGO', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            TvToggle(
              label: 'Main setting (${app.settings.logoMode.label})',
              radio: true,
              on: ch.logoMode == null,
              onPressed: () => app.setChannelLogoMode(ch, null),
            ),
            for (final mode in LogoMode.values)
              TvToggle(
                label: mode.label,
                radio: true,
                on: ch.logoMode == mode,
                onPressed: () => app.setChannelLogoMode(ch, mode),
              ),
          ],
        ),
        if (!ch.blockOnly && !ch.isMusic && !ch.isLive) ...[
          const SizedBox(height: 16),
          TvToggle(
            label: 'New episode premieres',
            on: ch.premieres,
            onPressed: () async {
              final tuner = AppScope.tunerOf(context);
              await app.setChannelPremieres(ch, !ch.premieres);
              // A show's premieres may have moved on or off the tuned channel.
              if (tuner.channel != null) await tuner.reschedule();
            },
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            TvButton(
              label: ch.favorite ? 'Unfavorite' : 'Favorite',
              icon: ch.favorite ? Icons.star : Icons.star_border,
              onPressed: () => app.updateChannel(ch, favorite: !ch.favorite),
            ),
            TvButton(
              label: ch.hidden ? 'Show in guide' : 'Hide from guide',
              icon: ch.hidden ? Icons.visibility : Icons.visibility_off,
              onPressed: () => app.updateChannel(ch, hidden: !ch.hidden),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveName(Channel ch) async {
    await AppScope.read(context).updateChannel(ch, name: _name.text);
  }

  Future<void> _retuneIfWatching(BuildContext context, Channel ch) async {
    final tuner = AppScope.tunerOf(context);
    if (tuner.channel?.id == ch.id) await tuner.retune();
  }

  /// A new break plan keeps the program on air: what's playing plays on.
  Future<void> _setPlan(BuildContext context, Channel ch, BreakPlan? plan) async {
    final tuner = AppScope.tunerOf(context);
    await AppScope.read(context).setChannelPlan(ch, plan);
    if (tuner.channel?.id == ch.id) await tuner.reschedule();
  }

  static String _loopText(Duration d) {
    if (d.inHours >= 48) return '${(d.inHours / 24).toStringAsFixed(1)} days';
    if (d.inHours >= 1) return '${d.inHours} hr ${d.inMinutes % 60} min';
    return '${d.inMinutes} min';
  }
}
