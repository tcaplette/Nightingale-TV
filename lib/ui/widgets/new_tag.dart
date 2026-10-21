import 'package:flutter/material.dart';

import '../../theme/tv_theme.dart';

/// The "NEW" tag on a premiering episode (episode-premieres), in guide
/// cells, the info panel, the channel banner and the Up next card.
class NewTag extends StatelessWidget {
  const NewTag({super.key, this.size = 20});

  /// The label's font size; the tag scales with it.
  final double size;

  static const label = 'NEW';

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
