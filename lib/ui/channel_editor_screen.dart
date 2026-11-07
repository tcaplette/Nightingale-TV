import 'dart:async';

import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import '../app_scope.dart';
import '../app_state.dart';
import '../channels/schedule.dart';
import '../live/live_tv_manager.dart';
import '../channels/channel.dart';
import '../commercials/break_plan.dart';
import '../commercials/commercial_pool.dart';
import '../icons/custom_icons.dart';
import '../theme/tv_theme.dart';
import 'break_plan_editor_screen.dart';
import 'icon_picker_screen.dart';
import 'menu_screen.dart' show confirm, showMessage;
import 'retro_look_screen.dart';
import 'source_picker_screen.dart';
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
  final _offlineNode = FocusNode(debugLabel: 'offline image');

  /// The channel's settings: the keyboard scrolls them to the name box, and
  /// a rename scrolls back to the heading showing the result.
  final _detailScroll = ScrollController();

  /// Each row's focus, so a tapped row holds it too: the list comes back to
  /// it, and the side-by-side layout keeps it selected after turning.
  final _rows = <String, FocusNode>{};
  FocusNode _row(String id) => _rows.putIfAbsent(id, () => FocusNode(debugLabel: 'channel $id'));

  @override
  void dispose() {
    _name.dispose();
    _offlineNode.dispose();
    _detailScroll.dispose();
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
    // How far ahead the guide goes (guide-range).
    final guideRanges = [
      for (final hours in GuideRange.choices)
        TvToggle(
          label: '$hours hours',
          radio: true,
          on: app.settings.guideRangeHours == hours,
          onPressed: () => app.setGuideRange(hours),
        ),
    ];
    const rangeHelp = 'How far ahead the guide shows, from now.';
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
            Text('GUIDE RANGE', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 16, children: guideRanges),
            const SizedBox(height: 12),
            Text(rangeHelp, style: g.body(22, color: g.textDim)),
            const SizedBox(height: 28),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TvButton(label: 'New channel', icon: Icons.add, onPressed: () => _newChannel(context)),
            ),
          ),
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
            // Gives way to the field being edited, its state kept.
            Offstage(
              offstage: ScreenLayout.keyboardTakesRoom(context),
              child: ExcludeFocus(
                excluding: ScreenLayout.keyboardTakesRoom(context),
                child: FocusTraversalGroup(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(80, 24, 100, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // One label width, so both rows' toggles line up.
                            SizedBox(
                              width: 250,
                              child: Text('CHANNEL LOGO', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
                            ),
                            for (final toggle in logoModes) ...[toggle, const SizedBox(width: 16)],
                            Expanded(
                              child: Text(logoHelp, maxLines: 2, overflow: TextOverflow.ellipsis, style: g.body(22, color: g.textDim)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 250,
                              child: Text('GUIDE RANGE', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
                            ),
                            for (final toggle in guideRanges) ...[toggle, const SizedBox(width: 16)],
                            Expanded(
                              child: Text(rangeHelp, maxLines: 2, overflow: TextOverflow.ellipsis, style: g.body(22, color: g.textDim)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
      controller: _detailScroll,
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
        // Always there on a channel that plays programs: a button leaving
        // mustn't move what follows, which would lose its focus.
        if (ch.playsPrograms) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (ch.isCustom)
                TvButton(label: 'Edit content', icon: Icons.video_library, onPressed: () => _editContent(context, ch)),
              if (app.canReshuffle(ch))
                TvButton(
                  label: 'Reshuffle',
                  icon: Icons.shuffle,
                  onPressed: () async {
                    final tuner = AppScope.tunerOf(context);
                    await app.reshuffleChannel(ch);
                    if (tuner.channel?.id == ch.id) await tuner.reschedule();
                  },
                ),
              if (ch.isCustom)
                TvButton(label: 'Remove channel', icon: Icons.delete, onPressed: () => _remove(context, ch)),
            ],
          ),
        ],
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
        if (ch.playsPrograms) ..._slotControls(context, ch),
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
        ChannelRetroSection(channel: ch),
      ],
    );
  }

  /// SLOT LENGTH and, with one set, TAIL, the filler pool and the offline
  /// image (slot-duration).
  List<Widget> _slotControls(BuildContext context, Channel ch) {
    final app = AppScope.read(context);
    final g = context.guide;
    final rule = ch.slotRule;
    final poolName = app.settings.commercialPools.where((p) => p.id == rule?.poolId).firstOrNull?.name ?? 'All pools';
    return [
      const SizedBox(height: 28),
      Text('SLOT LENGTH', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          TvToggle(label: 'Off', radio: true, on: rule == null, onPressed: () => _setRule(context, ch, null)),
          for (final length in SlotRule.lengths)
            TvToggle(
              label: '${length.inMinutes} min',
              radio: true,
              on: rule?.length == length,
              onPressed: () => _setRule(
                  context, ch, rule?.copyWith(length: length) ?? SlotRule(length: length)),
            ),
        ],
      ),
      if (rule != null) ...[
        const SizedBox(height: 20),
        Text('TAIL', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final tail in TailMode.values)
              TvToggle(
                label: tail.label,
                radio: true,
                on: rule.tail == tail,
                onPressed: () => _setRule(context, ch, rule.copyWith(tail: tail)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            if (rule.tail != TailMode.offline)
              TvButton(
                label: 'Filler pool: $poolName',
                icon: Icons.playlist_play,
                onPressed: () => _nextPool(context, ch, rule),
              ),
            TvButton(
              label: rule.offlineImage == null ? 'Offline image…' : 'Change offline image…',
              icon: Icons.image,
              focusNode: _offlineNode,
              onPressed: () => _pickOfflineImage(context, ch, rule),
            ),
            if (rule.offlineImage != null)
              TvButton(
                label: 'Default card',
                onPressed: () async {
                  await _setRule(context, ch, rule.copyWith(offlineImage: () => null));
                  _focusAfterBuild(_offlineNode);
                },
              ),
          ],
        ),
      ],
    ];
  }

  /// Focuses [node] after this change's frame: what had focus is gone.
  void _focusAfterBuild(FocusNode node) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) node.requestFocus();
      });

  /// A new slot rule keeps the program on air: what's playing plays on.
  Future<void> _setRule(BuildContext context, Channel ch, SlotRule? rule) async {
    final tuner = AppScope.tunerOf(context);
    await AppScope.read(context).setSlotRule(ch, rule);
    if (tuner.channel?.id == ch.id) await tuner.reschedule();
  }

  /// Each press moves to the next pool, then back to all of them.
  Future<void> _nextPool(BuildContext context, Channel ch, SlotRule rule) {
    final ids = <String?>[
      null,
      for (final p in AppScope.read(context).settings.commercialPools)
        if (p.kind == PoolKind.commercials) p.id,
    ];
    final next = ids[(ids.indexOf(rule.poolId) + 1) % ids.length];
    return _setRule(context, ch, rule.copyWith(poolId: () => next));
  }

  Future<void> _pickOfflineImage(BuildContext context, Channel ch, SlotRule rule) async {
    try {
      final name = await pickFullScreenImage(context);
      if (name == null || !context.mounted) return;
      await _setRule(context, ch, rule.copyWith(offlineImage: () => name));
    } on CustomIconException catch (e) {
      if (context.mounted) await showMessage(context, title: 'Offline image', message: e.message);
    }
  }

  /// New channel: added only on Done with something to play.
  Future<void> _newChannel(BuildContext context) async {
    final created = await Navigator.of(context).push<Channel>(MaterialPageRoute(
      builder: (route) => SourcePickerScreen(
        title: 'New channel',
        initial: const ChannelSource(includeEpisodes: false),
        name: AppState.customChannelName,
        order: PlaybackOrder.random,
        onDone: (source, name, order) async {
          final navigator = Navigator.of(route);
          try {
            final ch = await AppScope.read(context).createCustomChannel(name, source, order: order);
            navigator.pop(ch);
            return null;
          } on StateError catch (e) {
            return e.message;
          }
        },
      ),
    ));
    if (created == null || !mounted) return;
    setState(() {
      _selectedId = created.id;
      _name.text = created.name;
    });
    _focusAfterBuild(_row(created.id));
  }

  Future<void> _editContent(BuildContext context, Channel ch) async {
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (route) => SourcePickerScreen(
        title: 'Content of ${ch.name}',
        initial: ch.source,
        onDone: (source, _, _) async {
          final navigator = Navigator.of(route);
          try {
            await app.setChannelSource(ch, source);
            if (tuner.channel?.id == ch.id) await tuner.reschedule();
            navigator.pop();
            return null;
          } on StateError catch (e) {
            return e.message;
          }
        },
      ),
    ));
  }

  Future<void> _remove(BuildContext context, Channel ch) async {
    final ok = await confirm(context,
        title: 'Remove "${ch.name}"?',
        message: 'The channel goes away, with its programming blocks and its places in channel groups.',
        action: 'Remove');
    if (!ok || !context.mounted) return;
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    final navigator = Navigator.of(context);
    final portrait = ScreenLayout.of(context).isPortrait;
    // Whoever's watching it moves on first.
    if (tuner.channel?.id == ch.id) await tuner.channelUp();
    await app.deleteUserChannel(ch);
    if (!mounted) return;
    setState(() => _selectedId = null);
    if (portrait) navigator.pop();
    if (app.allChannels.firstOrNull case final first?) _focusAfterBuild(_row(first.id));
  }

  Future<void> _saveName(Channel ch) async {
    if (PlatformInfo.hasTouch) {
      for (final position in _detailScroll.positions) {
        unawaited(position.animateTo(0, duration: const Duration(milliseconds: 150), curve: Curves.easeOut));
      }
    }
    // A blank name isn't saved: the box goes back to the one that stands.
    if (_name.text.trim().isEmpty) {
      _name.text = ch.name;
      return;
    }
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
