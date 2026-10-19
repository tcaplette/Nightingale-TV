import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../channels/schedule.dart';
import '../../library/library_index.dart';
import '../../theme/tv_theme.dart';
import '../format.dart';
import 'channel_logo.dart';

/// The full-screen cards a channel shows instead of a picture: on the TV,
/// and drawn into Live TV export streams.

/// The channel number shown in the corner while a channel change tunes.
class ChannelNumberOsd extends StatelessWidget {
  const ChannelNumberOsd({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Text(
      text,
      style: g.display(110, weight: FontWeight.w800, color: g.accent).copyWith(
        shadows: const [Shadow(color: Colors.black, blurRadius: 12, offset: Offset(3, 3))],
      ),
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
    final g = context.guide;
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

/// The station ID at the end of a commercial break.
class StationId extends StatelessWidget {
  const StationId({super.key, required this.channel, required this.next, this.logo});

  final Channel channel;
  final ScheduledProgram? next;

  /// Drawn instead of the channel's [ChannelLogo] (offscreen, where the
  /// logo is decoded ahead of time).
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final n = next;
    return DecoratedBox(
      decoration: g.backdrop,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            logo ?? ChannelLogo(icon: channel.icon, size: 260, width: 420, fallbackText: channel.name),
            const SizedBox(height: 36),
            Text('${channel.number}  ${channel.name.toUpperCase()}',
                style: g.display(64, weight: FontWeight.w800, color: g.accent)),
            if (n != null && !n.isOffAir) ...[
              const SizedBox(height: 20),
              Text('Up next: ${n.title} at ${formatTime(n.start)}', style: g.body(34, color: g.textDim)),
              if (n.item?.kind == MediaKind.episode)
                Text(n.subtitle, style: g.body(28, color: g.textDim)),
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
                Text(channel.name.toUpperCase(),
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
