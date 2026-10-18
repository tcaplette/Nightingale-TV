import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../app_scope.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../playback/tuner.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'widgets/channel_logo.dart';
import 'widgets/tv_focus.dart';

/// The program guide: info panel + live preview on top, channel grid below.
class GuideView extends StatefulWidget {
  const GuideView({super.key, required this.onWatch, required this.onClose, required this.onMenu});

  final ValueChanged<Channel> onWatch;
  final VoidCallback onClose;
  final VoidCallback onMenu;

  @override
  State<GuideView> createState() => _GuideViewState();
}

class _GuideViewState extends State<GuideView> {
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
  Timer? _clock;

  /// The Menu button at the top has the keyboard highlight (Up from the
  /// first channel gets there).
  bool _menuFocused = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _windowStart = floorToHalfHour(_now);
    _cursorTime = _now;
    final tuner = AppScope.tunerOf(context);
    final channels = AppScope.read(context).channels;
    final current = channels.indexWhere((c) => c.id == tuner.channel?.id);
    _setRow(current < 0 ? 0 : current, channels.length);
    // Open with the tuned channel second from the top, like a cable guide.
    _firstRow = (_row - 1).clamp(0, (channels.length - _rows).clamp(0, channels.length));
    _clock = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _tick() {
    setState(() {
      _now = DateTime.now();
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

  ScheduledProgram? _focusedProgram(List<Channel> channels) {
    if (channels.isEmpty) return null;
    return AppScope.read(context).scheduleFor(channels[_row])?.programAt(_cursorTime);
  }

  void _moveTime(int direction, List<Channel> channels) {
    final p = _focusedProgram(channels);
    if (p == null) return;
    setState(() {
      if (direction > 0) {
        // Land a hair inside the next program.
        _cursorTime = p.end.add(const Duration(seconds: 1));
      } else {
        final previous = p.start.subtract(const Duration(seconds: 1));
        _cursorTime = previous.isBefore(_now) ? _now : previous;
      }
      // Scroll the window so the cursor stays visible.
      while (!_cursorTime.isBefore(_windowStart.add(_window))) {
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

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<Channel> channels) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    void row(int delta) => setState(() => _setRow(_row + delta, channels.length));
    if (_menuFocused) {
      if (isSelectKey(key)) {
        widget.onMenu();
      } else if (key == LogicalKeyboardKey.arrowDown || isBackKey(key)) {
        setState(() => _menuFocused = false);
      } else if (key == LogicalKeyboardKey.keyM || key == LogicalKeyboardKey.contextMenu) {
        widget.onMenu();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_row == 0) {
        setState(() => _menuFocused = true);
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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final channels = app.channels;
    final g = context.guide;
    if (_row >= channels.length) _setRow(channels.length - 1, channels.length);
    final focusedChannel = channels.isEmpty ? null : channels[_row];
    final focusedProgram = _focusedProgram(channels);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) => _onKey(node, event, channels),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTap: widget.onMenu,
        child: DecoratedBox(
        decoration: g.backdrop,
        child: Column(
          children: [
            SizedBox(
              height: 440,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _InfoPanel(
                      channel: focusedChannel,
                      program: focusedProgram,
                      now: _now,
                      menuFocused: _menuFocused,
                      onMenu: widget.onMenu,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 36, 60, 24),
                    child: _Preview(onTap: widget.onClose),
                  ),
                ],
              ),
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
                    setState(
                      () => _setRow(_row + (signal.scrollDelta.dy > 0 ? 1 : -1), channels.length),
                    );
                  }
                },
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
                            // One highlight at a time: the Menu button or the grid.
                            focused: i == _row && !_menuFocused,
                            focusedProgram: i == _row && !_menuFocused ? focusedProgram : null,
                            isTuned: AppScope.tunerOf(context).channel?.id == channels[i].id,
                            windowStart: _windowStart,
                            window: _window,
                            height: _rowHeight,
                            channelColumnWidth: _channelColumnWidth,
                            gridWidth: _gridWidth,
                            now: _now,
                            onHoverProgram: (p) => setState(() {
                              _menuFocused = false;
                              _setRow(i, channels.length);
                              _cursorTime = p == null || p.start.isBefore(_now)
                                  ? _now
                                  : p.start.add(const Duration(seconds: 1));
                            }),
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
            Container(
              height: 56,
              color: g.header,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('▲▼ Channels     ◀▶ Time     OK Watch     ', style: g.body(22, color: g.textDim)),
                  _HintLink(text: 'ESC Back to TV', onTap: widget.onClose),
                  Text('     ', style: g.body(22)),
                  _HintLink(text: 'M Menu', onTap: widget.onMenu),
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

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.channel,
    required this.program,
    required this.now,
    required this.menuFocused,
    required this.onMenu,
  });

  final Channel? channel;
  final ScheduledProgram? program;
  final DateTime now;
  final bool menuFocused;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final ch = channel;
    final p = program;
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 36, 48, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'NIGHTINGALE TV GUIDE',
                style: g.display(30, weight: FontWeight.w800, color: g.accent),
              ),
              const Spacer(),
              Text(
                '${formatDate(now)}   ${formatTime(now)}',
                style: g.display(30, weight: FontWeight.w600),
              ),
              const SizedBox(width: 28),
              TvPointerButton(label: 'Menu', icon: Icons.settings, highlighted: menuFocused, onPressed: onMenu),
            ],
          ),
          const SizedBox(height: 22),
          if (ch != null)
            Row(
              children: [
                ChannelLogo(icon: ch.icon, size: 64, width: 110, fallbackText: ch.name),
                const SizedBox(width: 18),
                Text(
                  '${ch.number}  ${ch.name.toUpperCase()}',
                  style: g.display(30, weight: FontWeight.w600, color: g.textDim),
                ),
              ],
            ),
          const SizedBox(height: 12),
          if (p != null) ...[
            Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: g.display(62, weight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              [if (p.blockTitle != null) p.blockTitle!.toUpperCase(), p.subtitle, formatRange(p.start, p.end)]
                  .join('    '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: g.body(28, weight: FontWeight.w600, color: g.accent),
            ),
            const SizedBox(height: 10),
            if (p.isOnAt(now)) ...[_ProgressBar(program: p, now: now), const SizedBox(height: 12)],
            Expanded(
              child: Text(
                p.item?.overview ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: g.body(25, color: g.textDim),
              ),
            ),
          ] else
            Text('Nothing scheduled', style: g.display(48)),
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
          '${formatMinutes(program.end.difference(now))} left',
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
              Video(controller: tuner.video, controls: NoVideoControls, fill: Colors.black),
              ListenableBuilder(
                listenable: tuner,
                builder: (context, _) => tuner.status == TunerStatus.playing
                    ? const SizedBox.shrink()
                    : Center(
                        child: Text(switch (tuner.status) {
                          TunerStatus.error => 'NO SIGNAL',
                          TunerStatus.offAir => 'OFF AIR',
                          TunerStatus.ident => 'STATION BREAK',
                          TunerStatus.standby => 'PLEASE STAND BY',
                          _ => 'TUNING…',
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
                isToday ? 'TODAY' : formatDate(windowStart),
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
    required this.height,
    required this.channelColumnWidth,
    required this.gridWidth,
    required this.now,
    required this.onHoverProgram,
    required this.onTap,
  });

  final Channel channel;
  final ChannelSchedule? schedule;
  final bool focused;
  final ScheduledProgram? focusedProgram;
  final bool isTuned;
  final DateTime windowStart;
  final Duration window;
  final double height;
  final double channelColumnWidth;
  final double gridWidth;
  final DateTime now;
  final ValueChanged<ScheduledProgram?> onHoverProgram;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final windowEnd = windowStart.add(window);
    final programs =
        schedule?.programsBetween(windowStart, windowEnd) ?? const <ScheduledProgram>[];
    double x(DateTime t) =>
        gridWidth *
        (t.difference(windowStart).inMilliseconds / window.inMilliseconds).clamp(0.0, 1.0);
    // One labeled band across each programming block's time slot.
    final bands = <({String title, DateTime start, DateTime end})>[];
    for (final p in programs) {
      final title = p.blockTitle;
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
        children: [
          MouseRegion(
            onEnter: (_) => onHoverProgram(null),
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
                      width: 64,
                      child: Text(
                        '${channel.number}',
                        style: g.display(40, weight: FontWeight.w800, color: g.accent),
                      ),
                    ),
                    ChannelLogo(
                      icon: channel.icon,
                      size: 52,
                      width: 84,
                      fallbackText: channel.name,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        channel.name,
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
                      child: Text('No programming', style: g.display(28, color: g.textDim)),
                    ),
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
      onEnter: (_) => onHover(),
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
              Text(
                program.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: g.display(inBlock ? 26 : 30, weight: FontWeight.w700, color: fg),
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
