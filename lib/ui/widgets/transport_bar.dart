import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/platform_info.dart';
import '../../playback/tuner.dart';
import '../format.dart';
import 'overlay_style.dart';

/// A phone or tablet: the canvas is scaled down, and fingers need room.
bool get _touchSized => PlatformInfo.isAndroid && !PlatformInfo.isTelevision;

/// What the D-pad is on in the [TransportBar].
enum TransportFocus { seekBar, restart, live }

/// What one press of a skip key moves by (timeshift D4): back 10 s or forward
/// 30 s, or 60 s either way once the key has been held for over 2 s.
Duration transportStep({required bool forward, required Duration heldFor}) {
  final seconds = heldFor > const Duration(seconds: 2) ? 60 : (forward ? 30 : 10);
  return Duration(seconds: forward ? seconds : -seconds);
}

/// The transport bar (timeshift spec): the program's title, a seek bar marking
/// the program's start, the viewing position and the live point, and icons for
/// Restart, Back 10, Pause/Play, Forward 30 and Live. [focused] is drawn; the TV screen
/// handles the keys. [compact]: the portrait player's version, over the picture,
/// with no title and icons only.
class TransportBar extends StatefulWidget {
  const TransportBar({super.key, required this.tuner, this.focused, this.onInteract, this.compact = false});

  final Tuner tuner;
  final TransportFocus? focused;

  /// A button or the seek bar was used.
  final VoidCallback? onInteract;
  final bool compact;

  @override
  State<TransportBar> createState() => _TransportBarState();
}

class _TransportBarState extends State<TransportBar> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // The position and the live point move with the clock.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _used(void Function() action) {
    action();
    widget.onInteract?.call();
  }

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final tuner = widget.tuner;
    final compact = widget.compact;
    final line = tuner.timeline;
    final atLive = !tuner.paused && line.to.difference(line.position) < const Duration(seconds: 1);
    final start = line.programStart;
    final buttons = Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TransportButton(
            label: 'Restart',
            icon: Icons.skip_previous,
            compact: compact,
            focused: widget.focused == TransportFocus.restart,
            onPressed: () => _used(() => unawaited(tuner.restart()))),
        _TransportButton(
            label: 'Back 10',
            icon: Icons.replay_10,
            compact: compact,
            onPressed: () => _used(() => tuner.skip(const Duration(seconds: -10)))),
        _TransportButton(
            label: tuner.paused ? 'Play' : 'Pause',
            icon: tuner.paused ? Icons.play_arrow : Icons.pause,
            compact: compact,
            onPressed: () => _used(() => unawaited(tuner.togglePause()))),
        _TransportButton(
            label: 'Forward 30',
            icon: Icons.forward_30,
            compact: compact,
            onPressed: () => _used(() => tuner.skip(const Duration(seconds: 30)))),
        _TransportButton(
            label: 'Live',
            icon: Icons.circle,
            word: 'LIVE',
            iconColor: atLive ? const Color(0xFFE53935) : null,
            compact: compact,
            focused: widget.focused == TransportFocus.live,
            onPressed: () => _used(() => unawaited(tuner.goLive()))),
      ],
    );
    final size = compact ? 24.0 : 26.0;
    final elapsed = Text(start == null ? '' : formatClockSpan(line.position.difference(start)),
        style: g.body(size, color: g.textDim));
    // The now panel says "behind" in portrait, where this row is narrow.
    final left = atLive
        ? Text('LIVE', style: g.display(size, weight: FontWeight.w800, color: g.accent))
        : Text(
            compact
                ? '-${formatClockSpan(line.to.difference(line.position))}'
                : formatBehind(line.to.difference(line.position)),
            style: g.body(size, color: g.textDim));
    final seek = _SeekBar(
      line: line,
      focused: widget.focused == TransportFocus.seekBar,
      onSeek: (t) => _used(() => tuner.seekTo(t)),
    );
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xB3000000)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            buttons,
            const SizedBox(height: 8),
            // The Full screen button is beside it.
            Padding(
              padding: const EdgeInsets.only(right: 270),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [seek, Row(children: [elapsed, const Spacer(), left])],
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // A tap on the bar isn't a tap on the picture.
      onTap: widget.onInteract,
      child: Container(
        padding: const EdgeInsets.fromLTRB(90, 90, 90, 36),
        // One overlay on a scrim, as video apps have it: the picture stays in
        // view around it.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xD9000000)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                elapsed,
                const SizedBox(width: 20),
                Expanded(child: seek),
                const SizedBox(width: 20),
                left,
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(tuner.program?.title ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(36, weight: FontWeight.w800)),
                ),
                buttons,
                Expanded(
                  child: Text(formatTime(DateTime.now()),
                      textAlign: TextAlign.right, style: g.display(32, weight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The track from the earliest reachable time to the live point, with a mark
/// at the program's start. Tap or drag to seek.
class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.line, required this.focused, required this.onSeek});

  final ({DateTime from, DateTime to, DateTime position, DateTime? programStart}) line;
  final bool focused;
  final ValueChanged<DateTime> onSeek;

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final span = line.to.difference(line.from).inMilliseconds.clamp(1, 1 << 40);
    double fraction(DateTime t) => (t.difference(line.from).inMilliseconds / span).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      void seekAt(double x) =>
          onSeek(line.from.add(Duration(milliseconds: ((x / width).clamp(0.0, 1.0) * span).round())));
      final at = fraction(line.position) * width;
      final thumb = focused ? 32.0 : 24.0;
      return Semantics(
        label: 'Seek bar',
        slider: true,
        child: GestureDetector(
          key: const ValueKey('transport-seek'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => seekAt(d.localPosition.dx),
          onHorizontalDragStart: (d) => seekAt(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
          child: SizedBox(
            height: _touchSized ? 100 : 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: focused ? 12 : 8,
                  decoration: BoxDecoration(color: g.progressTrack, borderRadius: BorderRadius.circular(6)),
                ),
                Container(
                  width: at,
                  height: focused ? 12 : 8,
                  decoration: BoxDecoration(color: g.accent, borderRadius: BorderRadius.circular(6)),
                ),
                if (line.programStart case final start?)
                  Positioned(
                    left: fraction(start) * width - 2,
                    child: Container(key: const ValueKey('transport-program-start'), width: 4, height: 28, color: g.textDim),
                  ),
                Positioned(
                  key: const ValueKey('transport-position'),
                  left: at - thumb / 2,
                  child: Container(
                    width: thumb,
                    height: thumb,
                    decoration: BoxDecoration(
                      color: g.accent,
                      shape: BoxShape.circle,
                      border: focused ? Border.all(color: Colors.white, width: 4) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _TransportButton extends StatefulWidget {
  const _TransportButton(
      {required this.label,
      required this.icon,
      required this.onPressed,
      this.compact = false,
      this.focused = false,
      this.word,
      this.iconColor});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;
  final bool focused;

  /// Shown after the icon: for what no icon says alone.
  final String? word;
  final Color? iconColor;

  @override
  State<_TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends State<_TransportButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final on = _hover || widget.focused;
    final side = widget.compact ? 72.0 : (_touchSized ? 84.0 : 68.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 4 : 6),
      child: Semantics(
        button: true,
        label: widget.label,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            // On a phone's scaled canvas a 48 dp target is bigger than it looks.
            child: Padding(
              padding: EdgeInsets.all(!widget.compact && _touchSized ? 21 : 0),
              child: Container(
              height: side,
              constraints: BoxConstraints(minWidth: side),
              padding: EdgeInsets.symmetric(horizontal: widget.word == null ? 0 : (widget.compact ? 10 : 18)),
              decoration: BoxDecoration(
                color: on ? g.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(side / 2),
                border: on ? Border.all(color: Colors.white, width: 3) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: widget.word == null ? (widget.compact ? 42 : 48) : (widget.compact ? 16 : 20), color: widget.iconColor ?? (on ? g.onAccent : Colors.white)),
                  if (widget.word case final word?) ...[
                    SizedBox(width: widget.compact ? 4 : 8),
                    Text(word, style: g.display(widget.compact ? 24 : 30, weight: FontWeight.w800, color: on ? g.onAccent : Colors.white)),
                  ],
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chip that stays while paused with the bar closed.
class PausedChip extends StatelessWidget {
  const PausedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: g.panel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause, size: 36, color: g.accent),
            const SizedBox(width: 10),
            Text('PAUSED', style: g.display(32, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
