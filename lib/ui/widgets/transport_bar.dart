import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../platform/platform_info.dart';
import '../../playback/tuner.dart';
import '../../sharing/party_transport.dart';
import '../../sharing/watch_party.dart';
import '../captions_picker.dart';
import '../format.dart';
import '../quality_picker.dart';
import 'overlay_style.dart';
import '../../l10n/tr.dart';

/// A phone or tablet: the canvas is scaled down, and fingers need room.
bool get _touchSized => PlatformInfo.isAndroid && !PlatformInfo.isTelevision;

/// What's highlighted in the [TransportBar], left to right after the seek
/// bar. The D-pad stops only on [dpadStops]; the pointer can highlight any.
enum TransportFocus {
  seekBar,
  restart,
  back10,
  pause,
  forward30,
  live,
  captions,
  quality;

  /// Where Left and Right stop on the bar's row (player-options D3).
  static const dpadStops = [restart, live, captions, quality];

  /// The D-pad stop Left ([forward] false) or Right moves to from here,
  /// stopping at the ends; [skipQuality] when Quality can't be pressed.
  TransportFocus step({required bool forward, bool skipQuality = false}) {
    final stops = [for (final s in dpadStops) if (!(skipQuality && s == quality)) s];
    if (forward) return stops.firstWhere((s) => s.index > index, orElse: () => stops.last);
    return stops.lastWhere((s) => s.index < index, orElse: () => stops.first);
  }
}

/// One of the player options (player-options): Captions, then Quality.
enum PlayerOption { captions, quality }

/// What one press of a skip key moves by (timeshift D4): back 10 s or forward
/// 30 s, or 60 s either way once the key has been held for over 2 s.
Duration transportStep({required bool forward, required Duration heldFor}) {
  final seconds = heldFor > const Duration(seconds: 2) ? 60 : (forward ? 30 : 10);
  return Duration(seconds: forward ? seconds : -seconds);
}

/// The transport bar (timeshift spec): the program's title, a seek bar marking
/// the program's start, the viewing position and the live point, and icons for
/// Restart, Back 10, Pause/Play, Forward 30 and Live, with the player options
/// at the row's right end and the time of day above the seek bar's right end.
/// [focused] is drawn; the TV screen handles the keys. [compact]: the portrait
/// player's version, over the picture, with no title, icons only and no
/// options (the portrait player has its own buttons).
class TransportBar extends StatefulWidget {
  const TransportBar(
      {super.key,
      required this.tuner,
      this.focused,
      this.onInteract,
      this.compact = false,
      this.party,
      this.onHover,
      this.onCaptions,
      this.onQuality});

  final Tuner tuner;

  /// In a watch party, the buttons act on the whole party.
  final WatchParty? party;
  final TransportFocus? focused;

  /// A button or the seek bar was used.
  final VoidCallback? onInteract;
  final bool compact;

  /// The pointer moved onto a button: the owner keeps the one highlight
  /// (pointer-focus), so the buttons then draw only [focused].
  final ValueChanged<TransportFocus>? onHover;

  /// The player options at the row's right end (player-options); not shown
  /// without them.
  final VoidCallback? onCaptions, onQuality;

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

  VoidCallback? _hover(TransportFocus f) => widget.onHover == null ? null : () => widget.onHover!(f);

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final tuner = widget.tuner;
    final transport = Transport(tuner, widget.party);
    final compact = widget.compact;
    final line = tuner.timeline;
    final atLive = !tuner.paused && line.to.difference(line.position) < const Duration(seconds: 1);
    final start = line.programStart;
    final buttons = Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TransportButton(
            label: tr.restart,
            icon: Icons.skip_previous,
            compact: compact,
            focused: widget.focused == TransportFocus.restart,
            onHover: _hover(TransportFocus.restart),
            onPressed: () => _used(() => unawaited(transport.restart()))),
        _TransportButton(
            label: tr.back10,
            icon: Icons.replay_10,
            compact: compact,
            focused: widget.focused == TransportFocus.back10,
            onHover: _hover(TransportFocus.back10),
            onPressed: () => _used(() => transport.skip(const Duration(seconds: -10)))),
        _TransportButton(
            label: tuner.paused ? tr.play : tr.pause,
            icon: tuner.paused ? Icons.play_arrow : Icons.pause,
            compact: compact,
            focused: widget.focused == TransportFocus.pause,
            onHover: _hover(TransportFocus.pause),
            onPressed: () => _used(() => unawaited(transport.togglePause()))),
        _TransportButton(
            label: tr.forward30,
            icon: Icons.forward_30,
            compact: compact,
            focused: widget.focused == TransportFocus.forward30,
            onHover: _hover(TransportFocus.forward30),
            onPressed: () => _used(() => transport.skip(const Duration(seconds: 30)))),
        _TransportButton(
            label: tr.live2,
            icon: Icons.circle,
            word: tr.live,
            iconColor: atLive ? const Color(0xFFE53935) : null,
            compact: compact,
            focused: widget.focused == TransportFocus.live,
            onHover: _hover(TransportFocus.live),
            onPressed: () => _used(() => unawaited(transport.goLive()))),
      ],
    );
    final size = compact ? 24.0 : 26.0;
    final elapsed = Text(start == null ? '' : formatClockSpan(line.position.difference(start)),
        style: g.body(size, color: g.textDim));
    // The now panel says "behind" in portrait, where this row is narrow.
    final left = atLive
        ? Text(tr.live, style: g.display(size, weight: FontWeight.w800, color: g.accent))
        : Text(
            compact
                ? '-${formatClockSpan(line.to.difference(line.position))}'
                : formatBehind(line.to.difference(line.position)),
            style: g.body(size, color: g.textDim));
    final seek = _SeekBar(
      line: line,
      focused: widget.focused == TransportFocus.seekBar,
      onSeek: (t) => _used(() => transport.seekTo(t)),
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
            // The time of day, above the seek bar's right end.
            Align(
              alignment: Alignment.centerRight,
              child: Text(formatTime(DateTime.now()), style: g.display(32, weight: FontWeight.w700)),
            ),
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
            // Title | transport | options: the transport centred where the
            // options leave room, the title in what's left.
            SizedBox(
              height: _TransportButton.rowHeight,
              child: CustomMultiChildLayout(
              delegate: _RowLayout(),
              children: [
                LayoutId(
                  id: _RowPart.title,
                  child: Text(tuner.program?.title ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(36, weight: FontWeight.w800)),
                ),
                LayoutId(id: _RowPart.transport, child: buttons),
                LayoutId(
                  id: _RowPart.options,
                  child: widget.onCaptions == null || widget.onQuality == null
                        ? const SizedBox.shrink()
                        : PlayerOptions(
                            tuner: tuner,
                            focused: switch (widget.focused) {
                              TransportFocus.captions => PlayerOption.captions,
                              TransportFocus.quality => PlayerOption.quality,
                              _ => null,
                            },
                            onHover: widget.onHover == null
                                ? null
                                : (o) => widget.onHover!(
                                    o == PlayerOption.captions ? TransportFocus.captions : TransportFocus.quality),
                            onCaptions: () => _used(widget.onCaptions!),
                            onQuality: () => _used(widget.onQuality!),
                          ),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RowPart { title, transport, options }

/// The bar's second row: the options at the right end, the transport centred
/// unless that would meet them (then just left of them), and the title in
/// the room left of the transport.
class _RowLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);
    final options = layoutChild(_RowPart.options, loose);
    final transport = layoutChild(_RowPart.transport, loose);
    final centred = (size.width - transport.width) / 2;
    final room = size.width - options.width - transport.width;
    final x = max(0.0, min(centred, room));
    final title = layoutChild(_RowPart.title, BoxConstraints.loose(Size(x, size.height)));
    double middle(Size s) => (size.height - s.height) / 2;
    positionChild(_RowPart.options, Offset(size.width - options.width, middle(options)));
    positionChild(_RowPart.transport, Offset(x, middle(transport)));
    positionChild(_RowPart.title, Offset(0, middle(title)));
  }

  @override
  bool shouldRelayout(_RowLayout oldDelegate) => false;
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
        label: tr.seekBar,
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
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.compact = false,
      this.focused = false,
      this.word,
      this.iconColor,
      this.onHover,
      this.enabled = true,
      this.iconSize});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;
  final bool focused;

  /// Shown after the icon: for what no icon says alone.
  final String? word;
  final Color? iconColor;

  /// The pointer moved onto it: the owner keeps the highlight, so only
  /// [focused] is drawn.
  final VoidCallback? onHover;

  /// False: drawn greyed, and the pointer and touch do nothing.
  final bool enabled;

  /// The icon's size beside a [word] (Live's dot is small by default).
  final double? iconSize;

  /// The height of a full-size button with its touch room.
  static double get rowHeight => _touchSized ? 126 : 68;

  @override
  State<_TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends State<_TransportButton> {

  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final on = widget.enabled && (widget.focused || (widget.onHover == null && _hover));
    final side = widget.compact ? 72.0 : (_touchSized ? 84.0 : 68.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 4 : 6),
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.label,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) {
            if (!widget.enabled) return;
            widget.onHover?.call();
            setState(() => _hover = true);
          },
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Disabled, it still takes the tap: a click on it isn't a click
            // on the picture (which opens the guide).
            onTap: widget.enabled ? widget.onPressed : () {},
            // On a phone's scaled canvas a 48 dp target is bigger than it looks.
            child: Padding(
              padding: EdgeInsets.all(!widget.compact && _touchSized ? 21 : 0),
              child: Opacity(
              opacity: widget.enabled ? 1 : 0.4,
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
                  Icon(widget.icon, size: widget.iconSize ?? (widget.word == null ? (widget.compact ? 42 : 48) : (widget.compact ? 16 : 20)), color: widget.iconColor ?? (on ? g.onAccent : Colors.white)),
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
      ),
    );
  }
}

/// The player options (player-options D1): Captions, a closed-caption icon
/// filled while on and crossed out while off, then Quality, its icon and the
/// cap in effect ("Auto", greyed and inert, on a YouTube channel). In the
/// transport bar's row, or above the channel banner without the bar.
/// [focused] is drawn; with [onHover] the owner keeps the highlight.
class PlayerOptions extends StatelessWidget {
  const PlayerOptions(
      {super.key, required this.tuner, this.focused, this.onHover, required this.onCaptions, required this.onQuality});

  final Tuner tuner;
  final PlayerOption? focused;
  final ValueChanged<PlayerOption>? onHover;
  final VoidCallback onCaptions, onQuality;

  @override
  Widget build(BuildContext context) {
    final word = qualityButtonValue(tuner);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TransportButton(
          key: const ValueKey('option-captions'),
          label: captionsButtonLabel(tuner),
          icon: tuner.captions ? Icons.closed_caption : Icons.closed_caption_disabled,
          focused: focused == PlayerOption.captions,
          onHover: onHover == null ? null : () => onHover!(PlayerOption.captions),
          onPressed: onCaptions,
        ),
        _TransportButton(
          key: const ValueKey('option-quality'),
          label: tr.playerQualityValue(word),
          icon: Icons.high_quality,
          iconSize: 40,
          word: word,
          enabled: qualityAvailable(tuner),
          focused: focused == PlayerOption.quality,
          onHover: onHover == null ? null : () => onHover!(PlayerOption.quality),
          onPressed: onQuality,
        ),
      ],
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
            Text(tr.paused, style: g.display(32, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
