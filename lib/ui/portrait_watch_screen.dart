import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../channels/channel.dart';
import '../channels/channel_groups.dart';
import '../channels/schedule.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'guide_view.dart';
import 'tv_screen.dart';
import 'widgets/broadcast_cards.dart';
import 'widgets/channel_logo.dart';
import 'widgets/new_tag.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// The TV screen and the guide in one, for a phone or tablet held upright
/// (portrait-layout): the player on top, what's on, the channel group tabs
/// and a channel list. [TvScreen] owns it and its keys, Back and tuning.
class PortraitWatchScreen extends StatefulWidget {
  const PortraitWatchScreen({
    super.key,
    required this.picture,
    required this.onTune,
    required this.onMenu,
    required this.onFullScreen,
    this.onTouch,
    this.numberEntry,
    this.toast,
  });

  /// The TV screen's picture, drawn in the player.
  final Widget picture;
  final ValueChanged<Channel> onTune;
  final VoidCallback onMenu;
  final VoidCallback onFullScreen;

  /// Any tap or press on the screen (cancels the exit prompt).
  final VoidCallback? onTouch;

  /// The channel number being typed, or tuned to, for the player's corner.
  final String? numberEntry;
  final String? toast;

  /// A channel row's height, in canvas units.
  static const rowHeight = 150.0;

  /// The tab row's height: tabs a finger can hit.
  static const tabRowHeight = 92.0;

  /// How long the player's buttons stay up after a tap.
  static const controlsFor = Duration(seconds: 3);

  /// How far ahead a channel's schedule sheet goes.
  static const scheduleSpan = Duration(hours: 12);

  @override
  State<PortraitWatchScreen> createState() => PortraitWatchScreenState();
}

class PortraitWatchScreenState extends State<PortraitWatchScreen> {
  late String _tab;
  late DateTime _now;
  Timer? _clock;
  bool _controls = true;
  Timer? _controlsTimer;
  final _scroll = ScrollController();
  final _tunedRow = FocusNode(debugLabel: 'tuned channel');

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _tab = savedGuideTab(AppScope.read(context));
    // The guide's clock: what's on now and next stays current.
    _clock = Timer.periodic(const Duration(seconds: 5), (_) => setState(() => _now = DateTime.now()));
    // The player's buttons show at first, so they can be found.
    _controlsTimer = Timer(PortraitWatchScreen.controlsFor, _hideControls);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTuned());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _controlsTimer?.cancel();
    _scroll.dispose();
    _tunedRow.dispose();
    super.dispose();
  }

  void _hideControls() {
    if (mounted) setState(() => _controls = false);
  }

  void _showControls() {
    widget.onTouch?.call();
    _controlsTimer?.cancel();
    setState(() => _controls = true);
    _controlsTimer = Timer(PortraitWatchScreen.controlsFor, _hideControls);
  }

  List<Channel> _channels() => shownGuideTab(AppScope.read(context).guideTabs(), _tab).channels;

  /// Scrolls the tuned channel into view, a row below the top.
  void _scrollToTuned() {
    if (!mounted || !_scroll.hasClients) return;
    final tuned = AppScope.tunerOf(context).channel;
    final i = _channels().indexWhere((c) => c.id == tuned?.id);
    final target = i <= 0 ? 0.0 : (i - 1) * PortraitWatchScreen.rowHeight;
    _scroll.jumpTo(min(target, _scroll.position.maxScrollExtent));
  }

  /// Gives the tuned channel's row keyboard focus (or the first row's).
  void focusTuned() {
    _scrollToTuned();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_tunedRow.context != null) {
        _tunedRow.requestFocus();
      } else {
        FocusScope.of(context).nextFocus();
      }
    });
  }

  void _selectTab(GuideTab tab) {
    widget.onTouch?.call();
    if (tab.id == _tab) return;
    setState(() => _tab = tab.id);
    unawaited(AppScope.read(context).setGuideTab(tab.id));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTuned());
  }

  Future<void> _showSchedule(Channel ch) async {
    widget.onTouch?.call();
    final watch = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.guide.panel,
      barrierColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(context.guide.radius * 3))),
      builder: (_) => ChannelScheduleSheet(channel: ch, from: DateTime.now()),
    );
    if (watch == true && mounted) widget.onTune(ch);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tuner = AppScope.tunerOf(context);
    final g = context.guide;
    final layout = ScreenLayout.of(context);
    final padding = MediaQuery.paddingOf(context);
    final tabs = app.guideTabs();
    final tab = shownGuideTab(tabs, _tab);
    final channels = tab.channels;
    final tuned = tuner.channel;
    return DecoratedBox(
      decoration: g.backdrop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(color: Colors.black, child: SizedBox(height: padding.top)),
          _player(g),
          if (tuned != null) PortraitNowPanel(channel: tuned, now: _now, inBreak: tuner.inBreak, gutter: layout.gutter),
          GuideTabRow(
            tabs: tabs,
            selected: tab.id,
            focused: false,
            height: PortraitWatchScreen.tabRowHeight,
            sidePadding: layout.gutter,
            fontSize: 26,
            onSelect: _selectTab,
          ),
          Expanded(
            child: Stack(
              children: [
                if (channels.isEmpty)
                  Center(child: Text('No channels', style: g.display(36, color: g.textDim)))
                else
                  FocusTraversalGroup(
                    child: ListView.builder(
                      controller: _scroll,
                      itemExtent: PortraitWatchScreen.rowHeight,
                      padding: EdgeInsets.only(bottom: padding.bottom),
                      itemCount: channels.length,
                      itemBuilder: (context, i) {
                        final ch = channels[i];
                        final isTuned = ch.id == tuned?.id;
                        return _ChannelRow(
                          key: ValueKey(ch.id),
                          channel: ch,
                          schedule: app.scheduleFor(ch),
                          now: _now,
                          tuned: isTuned,
                          gutter: layout.gutter,
                          focusNode: isTuned ? _tunedRow : null,
                          onTap: () {
                            widget.onTouch?.call();
                            widget.onTune(ch);
                          },
                          onLongPress: () => _showSchedule(ch),
                        );
                      },
                    ),
                  ),
                if (widget.toast case final toast?)
                  Positioned(
                    top: 16,
                    left: layout.gutter,
                    right: layout.gutter,
                    child: IgnorePointer(child: Center(child: TvToast(toast))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The live picture at 16:9, with the TV screen's overlays; a tap shows
  /// Full screen and Menu, a long-press opens the menu.
  Widget _player(GuideTheme g) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showControls,
        onLongPress: () {
          widget.onTouch?.call();
          widget.onMenu();
        },
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                child: SizedBox.fromSize(
                  size: ScreenLayout.tvCanvas,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.picture,
                      if (widget.numberEntry case final text?)
                        Positioned(top: 60, right: 90, child: ChannelNumberOsd(text: text)),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: !_controls,
                child: AnimatedOpacity(
                  opacity: _controls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _PlayerButton(label: 'Menu', icon: Icons.settings, onPressed: () {
                          widget.onTouch?.call();
                          widget.onMenu();
                        }),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: _PlayerButton(
                            label: 'Full screen', icon: Icons.fullscreen, onPressed: widget.onFullScreen),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A finger-sized button over the player.
class _PlayerButton extends StatelessWidget {
  const _PlayerButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: g.panel.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: g.cellBorder, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: g.text),
              const SizedBox(width: 10),
              Text(label, style: g.display(26, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the guide shows for [schedule] at [now], and after it.
({ScheduledProgram now, ScheduledProgram next})? _nowNext(ProgramSchedule? schedule, DateTime now) {
  if (schedule == null) return null;
  final p = schedule.guideProgramAt(now);
  return (now: p, next: schedule.guideProgramAt(p.end));
}

double _progress(ScheduledProgram p, DateTime now) =>
    (p.offsetAt(now).inSeconds / p.duration.inSeconds.clamp(1, 1 << 30)).clamp(0.0, 1.0);

/// The tuned channel: its number, logo and name, what's on and what's next.
class PortraitNowPanel extends StatelessWidget {
  const PortraitNowPanel({super.key, required this.channel, required this.now, required this.inBreak, required this.gutter});

  final Channel channel;
  final DateTime now;
  final bool inBreak;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final on = _nowNext(AppScope.read(context).scheduleFor(channel), now);
    final p = on?.now;
    final next = on?.next;
    return Container(
      color: g.panel,
      padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(color: g.accent, borderRadius: BorderRadius.circular(g.radius)),
                child: Text('${channel.number}', style: g.display(34, weight: FontWeight.w800, color: g.onFocus)),
              ),
              const SizedBox(width: 16),
              ChannelLogo(icon: channel.icon, size: 48, width: 84, fallbackText: channel.name),
              const SizedBox(width: 16),
              Expanded(
                child: Text(channel.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.display(26, weight: FontWeight.w700, color: g.accent)),
              ),
              if (channel.isLive) ...[const SizedBox(width: 12), const LiveTag(size: 24)],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (p?.isPremiere ?? false) ...[const NewTag(size: 26), const SizedBox(width: 12)],
              Expanded(
                child: Text(p?.title ?? 'Tuning…',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(40, weight: FontWeight.w800)),
              ),
            ],
          ),
          if (p != null) ...[
            Text(
              inBreak
                  ? commercialBreakLabel
                  : [
                      if (p.blockTitle != null) p.blockTitle!.toUpperCase(),
                      p.isMusicHour ? musicHourLine(p, now) : p.subtitle,
                    ].join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: inBreak ? g.body(24, weight: FontWeight.w600, color: g.accent) : g.body(24, color: g.textDim),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(formatRange(p.start, p.end), style: g.body(22, color: g.textDim)),
                if (p.isOnAt(now) && !p.isOffAir) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _progress(p, now),
                      minHeight: 8,
                      color: g.accent,
                      backgroundColor: g.cell,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 8),
              Text('Next: ${formatTime(next.start)} ${next.title}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(22, color: g.textDim)),
            ],
          ],
        ],
      ),
    );
  }
}

/// One channel in the list: what's on now with its progress, and next.
class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    super.key,
    required this.channel,
    required this.schedule,
    required this.now,
    required this.tuned,
    required this.gutter,
    required this.onTap,
    required this.onLongPress,
    this.focusNode,
  });

  final Channel channel;
  final ProgramSchedule? schedule;
  final DateTime now;
  final bool tuned;
  final double gutter;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final on = _nowNext(schedule, now);
    final p = on?.now;
    return GestureDetector(
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: TvFocusable(
        focusNode: focusNode,
        onPressed: onTap,
        builder: (context, focused) {
          final fg = focused ? g.onFocus : g.text;
          final dim = focused ? g.onFocus : g.textDim;
          return Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: EdgeInsets.fromLTRB(gutter - (tuned ? 8 : 0), 14, gutter, 14),
            decoration: BoxDecoration(
              color: focused ? g.focus : (tuned ? g.cellBorder : g.channelColumn),
              border: tuned ? Border(left: BorderSide(color: g.accent, width: 8)) : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text('${channel.number}',
                      maxLines: 1,
                      style: g.display(34, weight: FontWeight.w800, color: focused ? g.onFocus : g.accent)),
                ),
                ChannelLogo(icon: channel.icon, size: 52, width: 84, fallbackText: channel.name),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(channel.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: g.display(22, weight: FontWeight.w600, color: dim)),
                          ),
                          if (tuned) Icon(Icons.volume_up, size: 26, color: focused ? g.onFocus : g.accent),
                        ],
                      ),
                      Row(
                        children: [
                          if (p?.isPremiere ?? false) ...[const NewTag(size: 18), const SizedBox(width: 8)],
                          Expanded(
                            child: Text(
                              p == null ? 'No programming' : (p.isMusicHour ? musicHourLine(p, now) : p.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: g.display(28, weight: FontWeight.w700, color: fg),
                            ),
                          ),
                        ],
                      ),
                      if (p != null && p.isOnAt(now) && !p.isOffAir)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: LinearProgressIndicator(
                            value: _progress(p, now),
                            minHeight: 5,
                            color: focused ? g.onFocus : g.accent,
                            backgroundColor: g.cell,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      if (on?.next case final next?)
                        Text('${formatTime(next.start)}  ${next.title}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(22, color: dim)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A channel's next 12 hours, with a Watch button (long-press on a row).
/// Pops true for Watch.
class ChannelScheduleSheet extends StatelessWidget {
  const ChannelScheduleSheet({super.key, required this.channel, required this.from});

  final Channel channel;
  final DateTime from;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final layout = ScreenLayout.of(context);
    final schedule = AppScope.read(context).scheduleFor(channel);
    final programs = schedule?.guideProgramsBetween(from, from.add(PortraitWatchScreen.scheduleSpan)) ?? const [];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: layout.canvas.height * 0.75),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(layout.gutter, 28, layout.gutter, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ChannelLogo(icon: channel.icon, size: 48, width: 84, fallbackText: channel.name),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('${channel.number}  ${channel.name.toUpperCase()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: g.display(30, weight: FontWeight.w800, color: g.accent)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TvButton(
                label: 'Watch',
                icon: Icons.play_arrow,
                expand: true,
                autofocus: true,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: programs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('No programming', style: g.display(28, color: g.textDim)),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final p in programs)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 150,
                                    child: Text(p.isOnAt(from) ? 'Now' : formatTime(p.start),
                                        style: g.display(26, weight: FontWeight.w700, color: g.accent)),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (p.isPremiere) ...[const NewTag(size: 18), const SizedBox(width: 8)],
                                            Expanded(
                                              child: Text(p.title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: g.display(28, weight: FontWeight.w700)),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          [
                                            if (p.blockTitle != null) p.blockTitle!.toUpperCase(),
                                            p.isMusicHour ? 'Music' : p.subtitle,
                                          ].join('  ·  '),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: g.body(22, color: g.textDim),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
