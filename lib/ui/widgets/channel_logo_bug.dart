import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../channels/channel.dart';
import '../../channels/logo_windows.dart';
import '../../channels/schedule.dart';
import 'channel_logo.dart';
import 'overlay_style.dart';

/// The channel's logo in the corner of the picture (channel-logo spec): the
/// channel's own icon, at 70% opacity, inside the title-safe area, during
/// [segment]'s logo windows. Display only: it never takes a tap or focus.
class ChannelLogoBug extends StatefulWidget {
  const ChannelLogoBug({
    super.key,
    required this.icon,
    required this.mode,
    required this.segment,
    this.hidden = false,
    this.blackouts = const [],
    this.fallbackText,
    this.clock = DateTime.now,
    this.app,
  });

  /// The box and its position in a [frame] (see [logoBox]).
  static ({double right, double bottom, double height, double maxWidth}) boxIn(Size frame) =>
      logoBox(frame.width, frame.height);

  final ChannelIcon icon;
  final LogoMode mode;

  /// What's playing (from [ChannelSchedule.playbackAt]); null while
  /// nothing is (tuning, off the air, a card).
  final ScheduledProgram? segment;

  /// Something covers the corner now (the banner)…
  final bool hidden;

  /// …or will then (the Up next card).
  final List<({DateTime from, DateTime to})> blackouts;
  final String? fallbackText;
  final DateTime Function() clock;
  final AppState? app;

  @override
  State<ChannelLogoBug> createState() => _ChannelLogoBugState();
}

class _ChannelLogoBugState extends State<ChannelLogoBug> {
  static const _mono = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  Timer? _timer;
  bool _inWindow = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(ChannelLogoBug old) {
    super.didUpdateWidget(old);
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Shows the logo inside a window (fading out so it's gone at the
  /// window's end, as in exported streams) and outside [blackouts], and
  /// wakes up at the next edge.
  void _check() {
    _timer?.cancel();
    final segment = widget.segment;
    final now = widget.clock();
    var inWindow = false;
    final edges = <DateTime>[];
    if (segment != null && segment.end.isAfter(now)) {
      for (final w in logoWindows(widget.mode, [segment], now, segment.end)) {
        final fadeOut = w.end.subtract(logoFade);
        if (!now.isBefore(w.start) && now.isBefore(fadeOut)) inWindow = true;
        edges.addAll([w.start, fadeOut]);
      }
    }
    for (final b in widget.blackouts) {
      if (!now.isBefore(b.from) && now.isBefore(b.to)) inWindow = false;
      edges.addAll([b.from, b.to]);
    }
    if (inWindow != _inWindow && mounted) setState(() => _inWindow = inWindow);
    final next = edges.where((t) => t.isAfter(now)).fold<DateTime?>(null, (a, t) => a == null || t.isBefore(a) ? t : a);
    if (next != null) _timer = Timer(next.difference(now) + const Duration(milliseconds: 1), _check);
  }

  @override
  Widget build(BuildContext context) {
    final box = ChannelLogoBug.boxIn(MediaQuery.sizeOf(context));
    final visible = _inWindow && !widget.hidden;
    final style = OverlayStyle.of(context);
    Widget logo = ChannelLogo(
      icon: widget.icon,
      size: box.height,
      width: box.maxWidth,
      fallbackText: widget.fallbackText,
      app: widget.app,
      alignment: Alignment.centerRight,
    );
    if (style.logoPlate case final plate?) logo = DecoratedBox(decoration: plate, child: logo);
    if (style.monoLogo) logo = ColorFiltered(colorFilter: const ColorFilter.matrix(_mono), child: logo);
    return Positioned(
      right: box.right,
      bottom: box.bottom,
      child: IgnorePointer(
        child: ExcludeFocus(
          child: AnimatedOpacity(
            opacity: visible ? logoOpacity : 0,
            duration: logoFade,
            child: logo,
          ),
        ),
      ),
    );
  }
}
