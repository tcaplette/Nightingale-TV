import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../theme/tv_theme.dart';
import '../format.dart';
import 'overlay_style.dart';
import '../../l10n/tr.dart';

/// The full-screen cards a channel shows instead of a picture: on the TV,
/// and drawn into Live TV export streams.

/// The channel number shown in the corner while a channel change tunes.
class ChannelNumberOsd extends StatelessWidget {
  const ChannelNumberOsd({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    return Text(
      g.number(text),
      style: g.display(110, weight: FontWeight.w800, color: g.accent).copyWith(shadows: g.osdShadows),
    );
  }
}

/// OFF THE AIR, PLEASE STAND BY, NO SIGNAL.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    return DecoratedBox(
      decoration: g.backdrop,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 140, color: g.accent),
            const SizedBox(height: 24),
            Text(title, style: g.display(80, weight: FontWeight.w800)),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 1100,
                child: Text(message!, textAlign: TextAlign.center, style: g.body(28, color: g.textDim)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What an exported stream shows while it tunes: black, with the channel
/// number in the corner where the TV shows it, and the channel's name.
class TuningCard extends StatelessWidget {
  const TuningCard({super.key, required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned(
            top: 60,
            right: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ChannelNumberOsd(text: '${channel.number}'),
                Text(channel.displayName.toUpperCase(),
                    style: g.display(40, weight: FontWeight.w700, color: g.accent).copyWith(
                      shadows: const [Shadow(color: Colors.black, blurRadius: 12, offset: Offset(3, 3))],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A channel's offline card, during a slot's tail (slot-duration): its
/// chosen [image] filling the screen without stretching, or by default its
/// [logo] on the guide's background with its name and when the next slot
/// starts ([backAt]).
class OfflineCard extends StatelessWidget {
  const OfflineCard({super.key, required this.channel, this.image, this.logo, this.backAt});

  final Channel channel;

  /// The chosen image, already fitted (contain).
  final Widget? image;

  /// The channel's logo, for the default card.
  final Widget? logo;
  final DateTime? backAt;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image != null) return ColoredBox(color: Colors.black, child: SizedBox.expand(child: image));
    final g = context.guide;
    return DecoratedBox(
      decoration: g.backdrop,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo != null) SizedBox(width: 520, height: 300, child: Center(child: logo)),
            const SizedBox(height: 32),
            Text(channel.displayName, textAlign: TextAlign.center, style: g.display(72, weight: FontWeight.w800)),
            if (backAt != null) ...[
              const SizedBox(height: 16),
              Text(tr.backAt(formatTime(backAt!)), style: g.body(32, color: g.textDim)),
            ],
          ],
        ),
      ),
    );
  }
}
