import 'dart:async';

import 'package:flutter/material.dart';

import '../format.dart';
import 'overlay_style.dart';

/// The time of day in the picture's top-right corner, like a broadcast clock
/// (on-screen-clock spec, design D7): always the wall clock, never the
/// timeshift view time, updated on the minute. Display only: no focus, no
/// input. It fades away while [visible] is false, and shows a moon before
/// the time while a sleep timer is set ([sleeping]).
class OnScreenClock extends StatefulWidget {
  const OnScreenClock({super.key, required this.visible, this.sleeping = false, this.clock = DateTime.now});

  final bool visible;
  final bool sleeping;
  final DateTime Function() clock;

  @override
  State<OnScreenClock> createState() => _OnScreenClockState();
}

class _OnScreenClockState extends State<OnScreenClock> {
  Timer? _tick;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Shows the time now, and comes back just past the next whole minute.
  void _update() {
    _now = widget.clock();
    final toNextMinute = Duration(
        microseconds: Duration.microsecondsPerMinute - _now.microsecondsSinceEpoch % Duration.microsecondsPerMinute);
    _tick = Timer(toNextMinute + const Duration(milliseconds: 5), () {
      if (!mounted) return;
      setState(_update);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    final style = g.display(34, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85)).copyWith(
      shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 2))],
    );
    return IgnorePointer(
      child: ExcludeFocus(
        child: AnimatedOpacity(
          opacity: widget.visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.sleeping) ...[
                Icon(Icons.bedtime, size: 26, color: style.color, shadows: style.shadows),
                const SizedBox(width: 10),
              ],
              Text(formatTime(_now), style: style),
            ],
          ),
        ),
      ),
    );
  }
}
