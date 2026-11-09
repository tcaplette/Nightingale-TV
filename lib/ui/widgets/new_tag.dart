import 'package:flutter/material.dart';

import '../../theme/tv_theme.dart';
import '../../l10n/tr.dart';

/// The "NEW" tag on a premiering episode (episode-premieres), in guide
/// cells, the info panel, the channel banner and the Up next card.
class NewTag extends StatelessWidget {
  const NewTag({super.key, this.size = 20});

  /// The label's font size; the tag scales with it.
  final double size;

  static String get label => tr.newLabel;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.45, vertical: size * 0.1),
      decoration: BoxDecoration(color: g.nowLine, borderRadius: BorderRadius.circular(size * 0.25)),
      child: Text(label, style: g.display(size, weight: FontWeight.w900, color: Colors.white)),
    );
  }
}

/// The "LIVE" tag on a live channel's programme (live-playback), in the
/// channel banner and the info panel.
class LiveTag extends StatelessWidget {
  const LiveTag({super.key, this.size = 20});

  final double size;

  static String get label => tr.live;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.45, vertical: size * 0.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: g.nowLine, width: size * 0.12),
      ),
      child: Text(label, style: g.display(size, weight: FontWeight.w900, color: g.nowLine)),
    );
  }
}
