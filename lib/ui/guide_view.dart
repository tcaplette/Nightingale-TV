import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/channel_groups.dart';
import '../channels/schedule.dart';
import '../platform/platform_info.dart';
import '../playback/tuner.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'widgets/retro_frame.dart';
import 'widgets/channel_logo.dart';
import 'widgets/nightingale_mark.dart';
import 'widgets/new_tag.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// The program guide: info panel + live preview on top, channel grid below.
class GuideView extends StatefulWidget {
  const GuideView(
      {super.key, required this.onWatch, required this.onClose, required this.onMenu, this.onSleep, this.clock = DateTime.now});

  final ValueChanged<Channel> onWatch;
  final VoidCallback onClose;
  final VoidCallback onMenu;

  /// Opens the sleep timer picker; null without a sleep timer.
  final VoidCallback? onSleep;

  /// The time now (tests move it).
  final DateTime Function() clock;

  @override
  State<GuideView> createState() => _GuideViewState();
}

class _GuideViewState extends State<GuideView> with SingleTickerProviderStateMixin {
  static const _window = Duration(minutes: 90);
  static const _slot = Duration(minutes: 30);
  static const _rows = 6;
  static const _rowHeight = 87.0;
  static const _channelColumnWidth = 300.0;
  static const _gridWidth = 1920.0 - _channelColumnWidth;

  final _focus = FocusNode(debugLabel: 'guide');
  late DateTime _now;
  late DateTime _windowStart;

  /// Cursor: a channel row and a moment in time (the focused program is the
  /// one airing then, like a real guide keeping its column while you scroll).
  int _row = 0;
  int _firstRow = 0;
  late DateTime _cursorTime;

  /// The window end live channels' guide was last asked to cover.
  DateTime? _liveAskedUntil;

  /// A server Live TV source fetches guide data the window reaches past
  /// what it has (live-tv-sources "Guide scrolled ahead").
  /// Asks no further than the end of the range (guide-range).
  void _askLiveGuide(List<Channel> rows) {
    final windowEnd = _windowStart.add(_window);
    final until = windowEnd.isAfter(_rangeEnd) ? _rangeEnd : windowEnd;
    if (until == _liveAskedUntil) return;
    _liveAskedUntil = until;
    final live = [for (final c in rows) if (c.isLive) c];
    if (live.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = AppScope.read(context);
      for (final c in live) {
        app.needLiveGuideUntil(c, until);
      }
    });
  }
  Timer? _clock;

  /// How far ahead the guide goes: now plus the profile's Guide range,
  /// moving with the clock (guide-range D3).
  DateTime get _rangeEnd => _now.add(AppScope.read(context).settings.guideRange);

  /// The latest the window can start: its end stays at the half hour
  /// holding [_rangeEnd].
  DateTime get _maxWindowStart {
    final end = _rangeEnd;
    final floor = floorToHalfHour(end);
    final latest = (floor == end ? end : floor.add(_slot)).subtract(_window);
    final earliest = floorToHalfHour(_now);
    return latest.isBefore(earliest) ? earliest : latest;
  }

  /// The header button with the highlight: 0 is Menu (Up from the tab row
  /// gets there), then Sleep, if it's there, and Back. The pointer moves it
  /// too.
  int? _headerFocus;
  bool get _menuFocused => _headerFocus != null;

  /// The header's buttons, left to right.
  List<VoidCallback> get _headerButtons => [widget.onMenu, ?widget.onSleep, widget.onClose];

  /// The tab row has the keyboard highlight (Up from the first channel gets
  /// there), and the tab whose channels the grid shows.
  bool _tabsFocused = false;
  String _tab = GuideTabs.all;

  /// Height of the tab row; the info panel is that much shorter.
  static const _tabRowHeight = 56.0;

  /// Touch (Android): how far a drag has gone toward the next row, and a
  /// fling's travel (in canvas units) and the rows it has moved so far.
  double _dragged = 0;
  late final _fling = AnimationController.unbounded(vsync: this)..addListener(_onFling);
  int _flungRows = 0;
  int _flingCount = 0;

  @override
  void initState() {
    super.initState();
    _now = widget.clock();
    _windowStart = floorToHalfHour(_now);
    _cursorTime = _now;
    final app = AppScope.read(context);
    _tab = savedGuideTab(app);
    _focusTuned(_tabChannels(app.guideTabs()));
    _clock = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  /// The selected tab's channels (All's when it's gone meanwhile).
  List<Channel> _tabChannels(List<GuideTab> tabs) => shownGuideTab(tabs, _tab).channels;

  /// Focuses the tuned channel when [channels] has it, second from the top
  /// like a cable guide; else the first channel.
  void _focusTuned(List<Channel> channels) {
    final tuner = AppScope.tunerOf(context);
    final current = channels.indexWhere((c) => c.id == tuner.channel?.id);
    _firstRow = 0;
    _setRow(current < 0 ? 0 : current, channels.length);
    if (current >= 0) _firstRow = (_row - 1).clamp(0, (channels.length - _rows).clamp(0, channels.length));
  }

  /// Shows [tab]'s channels at once, and remembers it.
  void _selectTab(GuideTab tab) {
    if (tab.id == _tab) return;
    setState(() {
      _tab = tab.id;
      _focusTuned(tab.channels);
    });
    unawaited(AppScope.read(context).setGuideTab(tab.id));
  }

  /// Moves the tab selection [delta] places (the D-pad on the tab row).
  void _stepTab(List<GuideTab> tabs, int delta) {
    final i = tabs.indexWhere((t) => t.id == _tab);
    final j = (i < 0 ? 0 : i) + delta;
    if (j < 0 || j >= tabs.length) return;
    _selectTab(tabs[j]);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _fling.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tick() {
    setState(() {
      _now = widget.clock();
      if (_cursorTime.isBefore(_now)) _cursorTime = _now;
      // Roll the grid forward like a real guide once a half hour passes.
      final floor = floorToHalfHour(_now);
      if (_windowStart.isBefore(floor)) _windowStart = floor;
    });
  }

  void _setRow(int row, int count) {
    if (count == 0) return;
    _row = row.clamp(0, count - 1);
    if (_row < _firstRow) _firstRow = _row;
    if (_row >= _firstRow + _rows) _firstRow = _row - _rows + 1;
    _firstRow = _firstRow.clamp(0, (count - _rows).clamp(0, count));
  }

  /// Moves the cursor [delta] rows, as the mouse wheel and touch do.
  void _scrollRows(int delta, int count) => setState(() => _setRow(_row + delta, count));

  void _dragStart(DragStartDetails _) {
    _fling.stop();
    _dragged = 0;
  }

  /// Dragging up moves to later channels, a row per row height dragged.
  void _dragUpdate(DragUpdateDetails details, int count) {
    _dragged -= details.delta.dy;
    final rows = (_dragged / _rowHeight).truncate();
    if (rows == 0) return;
    _dragged -= rows * _rowHeight;
    _scrollRows(rows, count);
  }

  /// A fling keeps going and slows down, a whole row at a time.
  void _dragEnd(DragEndDetails details, int count) {
    // The velocity is in screen units; the rows are on the scaled canvas.
    final box = context.findRenderObject() as RenderBox?;
    final scale = box == null ? 1.0 : box.getTransformTo(null).getMaxScaleOnAxis();
    final velocity = -(details.primaryVelocity ?? 0) / scale;
    if (velocity.abs() < kMinFlingVelocity / scale) return;
    _flungRows = 0;
    _flingCount = count;
    _fling.value = 0;
    _fling.animateWith(FrictionSimulation(0.135, 0, velocity));
  }

  void _onFling() {
    final rows = (_fling.value / _rowHeight).truncate();
    if (rows == _flungRows) return;
    final step = rows - _flungRows;
    _flungRows = rows;
    _scrollRows(step, _flingCount);
  }

  ScheduledProgram? _focusedProgram(List<Channel> channels) {
    if (channels.isEmpty) return null;
    return AppScope.read(context).scheduleFor(channels[_row])?.guideProgramAt(_cursorTime);
  }

  void _moveTime(int direction, List<Channel> channels) {
    final p = _focusedProgram(channels);
    if (p == null) return;
    // The program airing at the end of the range is the last one.
    if (direction > 0 && !p.end.isBefore(_rangeEnd)) return;
    setState(() {
      if (direction > 0) {
        // Land a hair inside the next program.
        _cursorTime = p.end.add(const Duration(seconds: 1));
      } else {
        final previous = p.start.subtract(const Duration(seconds: 1));
        _cursorTime = previous.isBefore(_now) ? _now : previous;
      }
      // Scroll the window so the cursor stays visible.
      final maxStart = _maxWindowStart;
      while (!_cursorTime.isBefore(_windowStart.add(_window)) && _windowStart.isBefore(maxStart)) {
        _windowStart = _windowStart.add(_slot);
      }
      while (_cursorTime.isBefore(_windowStart) && _windowStart.isAfter(floorToHalfHour(_now))) {
        _windowStart = _windowStart.subtract(_slot);
      }
    });
  }

  void _select(List<Channel> channels) {
    if (channels.isEmpty) return;
    widget.onWatch(channels[_row]);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<Channel> channels, List<GuideTab> tabs) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    void row(int delta) => setState(() => _setRow(_row + delta, channels.length));
    // The remote's Guide button closes it again (Android).
    if (PlatformInfo.isAndroid && key == LogicalKeyboardKey.guide) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && widget.onSleep != null) {
      if (event is KeyDownEvent) widget.onSleep!();
      return KeyEventResult.handled;
    }
    final header = _headerFocus;
    if (header != null) {
      if (isSelectKey(key)) {
        if (event is KeyDownEvent) _headerButtons[header]();
      } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        final step = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
        setState(() => _headerFocus = (header + step).clamp(0, _headerButtons.length - 1));
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _headerFocus = null;
          _tabsFocused = true;
        });
      } else if (isBackKey(key)) {
        setState(() => _headerFocus = null);
      } else if (key == LogicalKeyboardKey.keyM || key == LogicalKeyboardKey.contextMenu) {
        widget.onMenu();
      }
      return KeyEventResult.handled;
    }
    if (_tabsFocused) {
      // Left and Right select straight away; Down goes back to the grid.
      if (key == LogicalKeyboardKey.arrowLeft) {
        _stepTab(tabs, -1);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _stepTab(tabs, 1);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _tabsFocused = false;
          _headerFocus = 0;
        });
      } else if (key == LogicalKeyboardKey.arrowDown || isSelectKey(key) || isBackKey(key)) {
        setState(() {
          _tabsFocused = false;
          _setRow(0, channels.length);
        });
      } else if (key == LogicalKeyboardKey.keyM || key == LogicalKeyboardKey.contextMenu) {
        widget.onMenu();
      } else if (PlatformInfo.isAndroid && key == LogicalKeyboardKey.guide) {
        widget.onClose();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_row == 0) {
        setState(() => _tabsFocused = true);
      } else {
        row(-1);
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      row(1);
    } else if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.channelUp) {
      row(-_rows);
    } else if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.channelDown) {
      row(_rows);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveTime(1, channels);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _moveTime(-1, channels);
    } else if (isSelectKey(key)) {
      _select(channels);
    } else if (isBackKey(key) || key == LogicalKeyboardKey.keyG) {
      widget.onClose();
    } else if (key == LogicalKeyboardKey.keyM || key == LogicalKeyboardKey.contextMenu) {
      widget.onMenu();
    } else if (key == LogicalKeyboardKey.home) {
      setState(() {
        _cursorTime = _now;
        _windowStart = floorToHalfHour(_now);
      });
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Width of the channel number column: the widest number of all channels
  /// plus a gap, so logos and names line up and don't move between tabs.
  static double _numberWidth(List<Channel> channels, GuideTheme g) {
    var widest = 0.0;
    for (final c in channels) {
      final painter = TextPainter(
        text: TextSpan(text: '${c.number}', style: _GuideRow.numberStyle(g)),
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest.ceilToDouble() + 12;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tabs = app.guideTabs();
    final channels = _tabChannels(tabs);
    _askLiveGuide(channels.sublist(
        _firstRow.clamp(0, channels.length), (_firstRow + _rows).clamp(0, channels.length)));
    final g = context.guide;
    final numberWidth = _numberWidth(app.channels, g);
    if (_row >= channels.length) _setRow(channels.length - 1, channels.length);
    final focusedChannel = channels.isEmpty ? null : channels[_row];
    final focusedProgram = _focusedProgram(channels);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) => _onKey(node, event, channels, tabs),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTap: widget.onMenu,
        // Touch: long-press is right-click.
        onLongPress: PlatformInfo.isAndroid ? widget.onMenu : null,
        child: DecoratedBox(
        decoration: g.backdrop,
        child: Column(
          children: [
            SizedBox(
              height: 440 - _tabRowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _InfoPanel(
                      channel: focusedChannel,
                      program: focusedProgram,
                      now: _now,
                      headerFocus: _headerFocus,
                      onMenu: widget.onMenu,
                      onSleep: widget.onSleep,
                      onBack: widget.onClose,
                      onHover: (i) => setState(() {
                        _headerFocus = i;
                        _tabsFocused = false;
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 36, 60, 24),
                    child: _Preview(onTap: widget.onClose),
                  ),
                ],
              ),
            ),
            GuideTabRow(
              tabs: tabs,
              selected: shownGuideTab(tabs, _tab).id,
              focused: _tabsFocused,
              height: _tabRowHeight,
              onSelect: (tab) {
                setState(() {
                  _headerFocus = null;
                  _tabsFocused = false;
                });
                _selectTab(tab);
              },
            ),
            _TimeHeader(
              windowStart: _windowStart,
              now: _now,
              channelColumnWidth: _channelColumnWidth,
              gridWidth: _gridWidth,
              window: _window,
              slot: _slot,
            ),
            Expanded(
              child: Listener(
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent) {
                    _scrollRows(signal.scrollDelta.dy > 0 ? 1 : -1, channels.length);
                  }
                },
                // Touch (Android): drag the channel list.
                child: GestureDetector(
                  // Count the drag from where the finger went down, so the
                  // rows keep up with it.
                  dragStartBehavior: DragStartBehavior.down,
                  onVerticalDragStart: PlatformInfo.isAndroid ? _dragStart : null,
                  onVerticalDragUpdate:
                      PlatformInfo.isAndroid ? (d) => _dragUpdate(d, channels.length) : null,
                  onVerticalDragEnd: PlatformInfo.isAndroid ? (d) => _dragEnd(d, channels.length) : null,
                  child: Stack(
                  children: [
                    Column(
                      children: [
                        for (
                          var i = _firstRow;
                          i < (_firstRow + _rows).clamp(0, channels.length);
                          i++
                        )
                          _GuideRow(
                            channel: channels[i],
                            schedule: app.scheduleFor(channels[i]),
                            // One highlight at a time: the Menu button, the tabs or the grid.
                            focused: i == _row && !_menuFocused && !_tabsFocused,
                            focusedProgram: i == _row && !_menuFocused && !_tabsFocused ? focusedProgram : null,
                            isTuned: AppScope.tunerOf(context).channel?.id == channels[i].id,
                            windowStart: _windowStart,
                            window: _window,
                            rangeEnd: _rangeEnd,
                            height: _rowHeight,
                            channelColumnWidth: _channelColumnWidth,
                            numberWidth: numberWidth,
                            gridWidth: _gridWidth,
                            now: _now,
                            onHoverProgram: (p) {
                              // Hover fires on every pointer move; only a
                              // new program moves the cursor.
                              if (i == _row &&
                                  !_menuFocused &&
                                  !_tabsFocused &&
                                  (p == null ? _cursorTime == _now : focusedProgram?.start == p.start)) {
                                return;
                              }
                              setState(() {
                                _headerFocus = null;
                                _tabsFocused = false;
                                _setRow(i, channels.length);
                                _cursorTime = p == null || p.start.isBefore(_now)
                                    ? _now
                                    : p.start.add(const Duration(seconds: 1));
                              });
                            },
                            onTap: () => widget.onWatch(channels[i]),
                          ),
                      ],
                    ),
                    _NowLine(
                      left:
                          _channelColumnWidth +
                          _gridWidth *
                              (_now.difference(_windowStart).inSeconds / _window.inSeconds),
                    ),
                  ],
                ),
                ),
              ),
            ),
            Container(
              height: 56,
              color: g.header,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr.channelsTabsTime, style: g.body(22, color: g.textDim)),
                  _HintLink(text: tr.escBackTo, onTap: widget.onClose),
                  Text('     ', style: g.body(22)),
                  _HintLink(text: tr.mMenu, onTap: widget.onMenu),
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

/// The tab the guide (or the portrait watch screen) opens on: the one
/// picked last, unless it's gone (hidden, deleted or empty).
String savedGuideTab(AppState app) {
  final saved = app.settings.guideTab;
  return app.guideTabs().where((t) => t.id == saved).firstOrNull?.id ?? GuideTabs.all;
}

/// The tab [tabId] shows: itself, or All when it's gone meanwhile.
GuideTab shownGuideTab(List<GuideTab> tabs, String tabId) =>
    tabs.where((t) => t.id == tabId).firstOrNull ?? tabs.where((t) => t.id == GuideTabs.all).firstOrNull ?? tabs.first;

/// A music channel's hour in the info panel: "Now playing: Artist – Song"
/// during it, else when it starts.
String musicHourLine(ScheduledProgram hour, DateTime now) {
  final on = hour.songs?.where((s) => s.isOnAt(now)).firstOrNull;
  if (on != null && hour.isOnAt(now)) return tr.nowPlaying(on.title);
  return tr.music;
}

/// The hour's songs from now (or from its start), as "Artist – Song".
String musicHourSongs(ScheduledProgram hour, DateTime now) {
  final songs = [for (final s in hour.songs ?? const <ScheduledProgram>[]) if (s.end.isAfter(now)) s];
  if (songs.isEmpty) return '';
  final upcoming = hour.isOnAt(now) ? songs.skip(1) : songs;
  return '${hour.isOnAt(now) ? 'Up next' : 'First up'}: ${[for (final s in upcoming.take(4)) s.title].join(' · ')}';
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.channel,
    required this.program,
    required this.now,
    required this.headerFocus,
    required this.onMenu,
    required this.onSleep,
    required this.onBack,
    required this.onHover,
  });

  final Channel? channel;
  final ScheduledProgram? program;
  final DateTime now;

  /// The highlighted header button: 0 Menu, then Sleep, if it's there, and
  /// Back.
  final int? headerFocus;
  final VoidCallback onMenu;
  final VoidCallback? onSleep;
  final VoidCallback onBack;
  final ValueChanged<int> onHover;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final ch = channel;
    final p = program;
    final back = onSleep == null ? 1 : 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 28, 48, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NightingaleMark(height: 28, color: g.accent),
              const SizedBox(width: 14),
              // The buttons keep their size whatever the font; the title and
              // the date share what's left, and shrink to fit it.
              Expanded(
                flex: 5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr.nightingaleTvGuide,
                    maxLines: 1,
                    style: g.display(30, weight: FontWeight.w800, color: g.accent),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                flex: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${formatDate(now)}   ${formatTime(now)}',
                    style: g.display(30, weight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              TvPointerButton(
                  label: tr.menu,
                  icon: Icons.settings,
                  highlighted: headerFocus == 0,
                  onHover: () => onHover(0),
                  onPressed: onMenu),
              if (onSleep != null) ...[
                const SizedBox(width: 16),
                TvPointerButton(
                    label: tr.sleep,
                    icon: Icons.bedtime,
                    highlighted: headerFocus == 1,
                    onHover: () => onHover(1),
                    onPressed: onSleep!),
              ],
              const SizedBox(width: 16),
              TvPointerButton(
                  label: tr.back,
                  icon: Icons.arrow_back,
                  highlighted: headerFocus == back,
                  onHover: () => onHover(back),
                  onPressed: onBack),
            ],
          ),
          const SizedBox(height: 10),
          if (ch != null)
            Row(
              children: [
                ChannelLogo(icon: ch.icon, size: 48, width: 84, fallbackText: ch.displayName),
                const SizedBox(width: 18),
                Text(
                  '${ch.number}  ${ch.displayName.toUpperCase()}',
                  style: g.display(30, weight: FontWeight.w600, color: g.textDim),
                ),
              ],
            ),
          const SizedBox(height: 4),
          if (p != null) ...[
            Row(
              children: [
                if (p.isPremiere) ...[const NewTag(size: 32), const SizedBox(width: 18)],
                Expanded(
                  child: Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.display(58, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (p.displayBlockTitle != null) p.displayBlockTitle!.toUpperCase(),
                p.isMusicHour ? musicHourLine(p, now) : p.subtitle,
                formatRange(p.start, p.end),
                if (p.endsEarly) endsEarlyLabel,
              ].join('    '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: g.body(28, weight: FontWeight.w600, color: g.accent),
            ),
            const SizedBox(height: 10),
            if (p.isOnAt(now)) ...[_ProgressBar(program: p, now: now), const SizedBox(height: 12)],
            Expanded(
              child: Text(
                p.isMusicHour ? musicHourSongs(p, now) : p.item?.overview ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: g.body(25, color: g.textDim),
              ),
            ),
          ] else
            Text(tr.nothingScheduled, style: g.display(48)),
        ],
      ),
    );
  }
}

/// A key hint in the bottom bar that can also be clicked.
class _HintLink extends StatefulWidget {
  const _HintLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  State<_HintLink> createState() => _HintLinkState();
}

class _HintLinkState extends State<_HintLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(widget.text,
            style: g.body(22, weight: FontWeight.w700, color: _hover ? g.accent : g.text)),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.program, required this.now});

  final ScheduledProgram program;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final fraction = program.offsetAt(now).inSeconds / program.duration.inSeconds.clamp(1, 1 << 30);
    return Row(
      children: [
        SizedBox(
          width: 420,
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            color: g.accent,
            backgroundColor: g.cell,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          tr.left(formatMinutes(program.end.difference(now))),
          style: g.body(22, color: g.textDim),
        ),
      ],
    );
  }
}

/// Live picture of the tuned channel, like the corner window on cable guides.
class _Preview extends StatelessWidget {
  const _Preview({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tuner = AppScope.tunerOf(context);
    final g = context.guide;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 674,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: g.cellBorder, width: 3),
          borderRadius: BorderRadius.circular(g.radius),
          boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 24)],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The shape and surround, without effects (design D7).
              ListenableBuilder(
                listenable: Listenable.merge([tuner, AppScope.read(context)]),
                builder: (context, _) {
                  final app = AppScope.read(context), ch = tuner.channel;
                  final retro = ch == null ? const ResolvedRetro() : app.retroFor(ch);
                  return RetroFrame(
                    retro: retro,
                    icon: ch?.icon,
                    app: app,
                    effects: false,
                    child: tuner.media.buildVideo(fit: RetroFrame.fitFor(retro.shape)),
                  );
                },
              ),
              ListenableBuilder(
                listenable: tuner,
                builder: (context, _) => tuner.status == TunerStatus.playing
                    ? const SizedBox.shrink()
                    : Center(
                        child: Text(switch (tuner.status) {
                          TunerStatus.error => tr.noSignal,
                          TunerStatus.offAir => tr.offAir2,
                          TunerStatus.standby => tr.pleaseStandBy,
                          _ => tr.tuning,
                        }, style: g.display(40, weight: FontWeight.w800, color: g.textDim)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The guide's tabs (channel-groups): Left/Right on the D-pad, hover and
/// click with a mouse, tap and sideways drag on touch. The selected tab is
/// kept in view.
class GuideTabRow extends StatefulWidget {
  const GuideTabRow({
    super.key,
    required this.tabs,
    required this.selected,
    required this.focused,
    required this.height,
    required this.onSelect,
    this.sidePadding = 60,
    this.fontSize = 22,
  });

  final List<GuideTab> tabs;
  final String selected;

  /// The row has the keyboard highlight.
  final bool focused;
  final double height;
  final ValueChanged<GuideTab> onSelect;
  final double sidePadding;
  final double fontSize;

  @override
  State<GuideTabRow> createState() => _GuideTabRowState();
}

class _GuideTabRowState extends State<GuideTabRow> {
  final _keys = <String, GlobalKey>{};
  String? _hovered;

  @override
  void didUpdateWidget(GuideTabRow old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _keys[widget.selected]?.currentContext;
        if (context != null && context.mounted) {
          Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 200));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      height: widget.height,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      color: g.channelColumn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: widget.sidePadding, vertical: 8),
        child: Row(
          children: [
            for (final tab in widget.tabs)
              Padding(
                key: _keys.putIfAbsent(tab.id, GlobalKey.new),
                padding: const EdgeInsets.only(right: 12),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hovered = tab.id),
                  onExit: (_) => setState(() => _hovered = _hovered == tab.id ? null : _hovered),
                  child: GestureDetector(
                    onTap: () => widget.onSelect(tab),
                    child: _tab(g, tab),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tab(GuideTheme g, GuideTab tab) {
    final selected = tab.id == widget.selected;
    final focused = selected && widget.focused;
    final hovered = _hovered == tab.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: focused ? g.focus : (selected ? g.accent : (hovered ? g.cellBorder : g.cell)),
        borderRadius: BorderRadius.circular(g.radius * 2),
        border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
      ),
      child: Text(
        tab.name.toUpperCase(),
        style: g.display(widget.fontSize, weight: FontWeight.w800, color: selected || focused ? g.onFocus : g.text),
      ),
    );
  }
}

class _TimeHeader extends StatelessWidget {
  const _TimeHeader({
    required this.windowStart,
    required this.now,
    required this.channelColumnWidth,
    required this.gridWidth,
    required this.window,
    required this.slot,
  });

  final DateTime windowStart;
  final DateTime now;
  final double channelColumnWidth;
  final double gridWidth;
  final Duration window;
  final Duration slot;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final slots = window.inMinutes ~/ slot.inMinutes;
    final isToday = windowStart.day == now.day;
    return Container(
      height: 60,
      color: g.header,
      child: Row(
        children: [
          SizedBox(
            width: channelColumnWidth,
            child: Center(
              child: Text(
                isToday ? tr.today2 : formatDate(windowStart),
                style: g.display(28, weight: FontWeight.w800, color: g.accent),
              ),
            ),
          ),
          for (var i = 0; i < slots; i++)
            Container(
              width: gridWidth / slots,
              padding: const EdgeInsets.only(left: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: g.cellBorder, width: 2)),
              ),
              child: Text(
                formatTime(windowStart.add(slot * i)),
                style: g.display(28, weight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.channel,
    required this.schedule,
    required this.focused,
    required this.focusedProgram,
    required this.isTuned,
    required this.windowStart,
    required this.window,
    required this.rangeEnd,
    required this.height,
    required this.channelColumnWidth,
    required this.numberWidth,
    required this.gridWidth,
    required this.now,
    required this.onHoverProgram,
    required this.onTap,
  });

  static TextStyle numberStyle(GuideTheme g) => g.display(40, weight: FontWeight.w800, color: g.accent);

  final Channel channel;
  final ProgramSchedule? schedule;
  final bool focused;
  final ScheduledProgram? focusedProgram;
  final bool isTuned;
  final DateTime windowStart;
  final Duration window;

  /// Programs starting at or after it aren't shown (guide-range).
  final DateTime rangeEnd;
  final double height;
  final double channelColumnWidth;
  final double numberWidth;
  final double gridWidth;
  final DateTime now;
  final ValueChanged<ScheduledProgram?> onHoverProgram;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final windowEnd = windowStart.add(window);
    final all = schedule?.guideProgramsBetween(windowStart, windowEnd) ?? const <ScheduledProgram>[];
    final programs = [for (final p in all) if (p.start.isBefore(rangeEnd)) p];
    // Past the last program shown, the grid looks empty.
    final shownEnd = programs.length < all.length && programs.isNotEmpty ? programs.last.end : null;
    double x(DateTime t) =>
        gridWidth *
        (t.difference(windowStart).inMilliseconds / window.inMilliseconds).clamp(0.0, 1.0);
    // One labeled band across each programming block's time slot.
    final bands = <({String title, DateTime start, DateTime end})>[];
    for (final p in programs) {
      final title = p.displayBlockTitle;
      if (title == null) continue;
      if (bands.isNotEmpty && bands.last.title == title && bands.last.end == p.start) {
        bands.last = (title: title, start: bands.last.start, end: p.end);
      } else {
        bands.add((title: title, start: p.start, end: p.end));
      }
    }

    return SizedBox(
      height: height,
      child: Row(
        // The channel cell fills the row, like the programme cells.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            onHover: (_) => onHoverProgram(null),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: channelColumnWidth,
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: focused ? g.cellBorder : g.channelColumn,
                child: Row(
                  children: [
                    SizedBox(
                      width: numberWidth,
                      child: Text('${channel.number}', maxLines: 1, softWrap: false, style: numberStyle(g)),
                    ),
                    ChannelLogo(
                      icon: channel.icon,
                      size: 52,
                      width: 84,
                      fallbackText: channel.displayName,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        channel.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: g.display(24, weight: FontWeight.w600, color: g.text),
                      ),
                    ),
                    if (isTuned) Icon(Icons.volume_up, size: 24, color: g.accent),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: gridWidth,
            child: Stack(
              children: [
                if (programs.isEmpty)
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 3, left: 3),
                      color: g.cellAlt,
                      padding: const EdgeInsets.only(left: 20),
                      alignment: Alignment.centerLeft,
                      child: Text(tr.noProgramming, style: g.display(28, color: g.textDim)),
                    ),
                  ),
                if (shownEnd != null && shownEnd.isBefore(windowEnd))
                  Positioned(
                    left: x(shownEnd),
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(margin: const EdgeInsets.only(bottom: 3, left: 3), color: g.cellAlt),
                  ),
                for (final (i, p) in programs.indexed)
                  Positioned(
                    left: x(p.start),
                    width: (x(p.end) - x(p.start)).clamp(0.0, gridWidth),
                    top: 0,
                    bottom: 0,
                    child: _ProgramCell(
                      program: p,
                      focused: focusedProgram != null && focusedProgram!.start == p.start,
                      alternate: i.isOdd,
                      continuesLeft: p.start.isBefore(windowStart),
                      continuesRight: p.end.isAfter(windowEnd),
                      inBlock: p.blockTitle != null,
                      onHover: () => onHoverProgram(p),
                      onTap: onTap,
                    ),
                  ),
                for (final band in bands)
                  Positioned(
                    left: x(band.start),
                    width: (x(band.end) - x(band.start)).clamp(0.0, gridWidth),
                    top: 0,
                    height: _ProgramCell.bandHeight,
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.only(left: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: g.accent,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          band.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: g.display(17, weight: FontWeight.w800, color: g.onFocus),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramCell extends StatelessWidget {
  const _ProgramCell({
    required this.program,
    required this.focused,
    required this.alternate,
    required this.continuesLeft,
    required this.continuesRight,
    required this.inBlock,
    required this.onHover,
    required this.onTap,
  });

  /// Height of the programming block label above a block's cells.
  static const bandHeight = 22.0;

  final ScheduledProgram program;
  final bool focused;
  final bool alternate;
  final bool continuesLeft;
  final bool continuesRight;
  final bool inBlock;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final fg = focused ? g.onFocus : g.text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // Hover, not enter: rows scrolling under a still pointer don't move
      // the cursor.
      onHover: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: 3, left: 3, top: inBlock ? bandHeight : 0),
          decoration: BoxDecoration(
            color: focused ? g.focus : (alternate ? g.cellAlt : g.cell),
            border: focused ? Border.all(color: Colors.white, width: 3) : null,
          ),
          alignment: Alignment.centerLeft,
          child: LayoutBuilder(
            builder: (context, box) {
              // Very short programs get a bare cell; short ones lose the arrows.
              if (box.maxWidth < 36) return const SizedBox.expand();
              final roomy = box.maxWidth >= 120;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: roomy ? 14 : 6),
                child: _cellContent(g, fg, roomy),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cellContent(GuideTheme g, Color fg, bool roomy) {
    return Row(
      children: [
        if (continuesLeft && roomy) Icon(Icons.arrow_left, size: 30, color: fg),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (program.isPremiere && roomy) ...[const NewTag(size: 16), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      program.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: g.display(inBlock ? 26 : 30, weight: FontWeight.w700, color: fg),
                    ),
                  ),
                ],
              ),
              Text(
                program.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: g.body(inBlock ? 17 : 20, color: focused ? g.onFocus : g.textDim),
              ),
            ],
          ),
        ),
        if (continuesRight && roomy) Icon(Icons.arrow_right, size: 30, color: fg),
      ],
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({required this.left});

  final double left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left - 2,
      top: 0,
      bottom: 0,
      width: 4,
      child: IgnorePointer(child: ColoredBox(color: context.guide.nowLine.withValues(alpha: 0.9))),
    );
  }
}
