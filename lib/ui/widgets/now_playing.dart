import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../channels/channel.dart';
import '../../channels/schedule.dart';
import '../../theme/tv_theme.dart';
import 'channel_logo.dart';
import 'nightingale_mark.dart';
import '../../l10n/tr.dart';

/// How far the art and text sit from their place at [t]: a few pixels,
/// changing each minute, so nothing stays put on the screen for hours (the
/// burn-in protection TV screensavers use).
Offset nowPlayingDrift(DateTime t) {
  final minute = t.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
  return Offset(18 * sin(minute * 0.7), 12 * cos(minute * 1.3));
}

/// "3:07" for a song's elapsed time or length.
String songClock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// The full-screen Now Playing card while a song plays (music-channels):
/// the album art, the song, artist, album and year, a progress bar, the
/// channel's logo and the next song. It also is the picture of a song in
/// Live TV export.
class NowPlayingCard extends StatefulWidget {
  const NowPlayingCard({
    super.key,
    required this.channel,
    required this.song,
    this.next,
    this.art = const [],
    this.app,
    this.clock = DateTime.now,
    this.live = true,
    this.decodedArt,
    this.logo,
  });

  final Channel channel;

  /// The song's slot (from [ChannelSchedule.programAt]).
  final ScheduledProgram song;
  final ScheduledProgram? next;

  /// The album's image, then the song's own: the first that loads is
  /// shown, else a music-note tile.
  final List<ImageProvider> art;

  /// For the channel logo (offscreen rendering has no scope).
  final AppState? app;
  final DateTime Function() clock;

  /// Moves the progress bar and the drift with the clock; off for a still
  /// picture (export).
  final bool live;

  /// Offscreen rendering paints in one frame: the art and the logo, already
  /// decoded, instead of [art] and the channel's icon.
  final ui.Image? decodedArt;
  final Widget? logo;

  @override
  State<NowPlayingCard> createState() => _NowPlayingCardState();
}

class _NowPlayingCardState extends State<NowPlayingCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.live) _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final now = widget.clock();
    final item = widget.song.item;
    final drift = widget.live ? nowPlayingDrift(now) : Offset.zero;
    final next = widget.next?.item;
    return DecoratedBox(
      decoration: g.backdrop,
      child: Transform.translate(
        offset: drift,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(200, 160, 200, 160),
          child: Row(
            children: [
              _Art(providers: widget.art, decoded: widget.decodedArt, size: 620),
              const SizedBox(width: 90),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        widget.logo ??
                            ChannelLogo(
                                icon: widget.channel.icon,
                                size: 64,
                                width: 110,
                                fallbackText: widget.channel.displayName,
                                app: widget.app,
                                alignment: Alignment.centerLeft),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(tr.nowPlayingOn(widget.channel.displayName.toUpperCase()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: g.display(28, weight: FontWeight.w800, color: g.accent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(item?.title ?? '',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: g.display(76, weight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(item?.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: g.display(48, weight: FontWeight.w700, color: g.accent)),
                    const SizedBox(height: 8),
                    Text([?item?.album, ?item?.year?.toString()].join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(34, color: g.textDim)),
                    const SizedBox(height: 44),
                    if (widget.live) ...[
                      LinearProgressIndicator(
                        value: widget.song.offsetAt(now).inMilliseconds /
                            widget.song.duration.inMilliseconds.clamp(1, 1 << 40),
                        minHeight: 10,
                        color: g.accent,
                        backgroundColor: g.cell,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(songClock(widget.song.offsetAt(now)), style: g.body(26, color: g.textDim)),
                          const Spacer(),
                          Text(songClock(widget.song.duration), style: g.body(26, color: g.textDim)),
                        ],
                      ),
                      const SizedBox(height: 36),
                    ],
                    if (next != null)
                      Text(tr.upNext(next.guideTitle),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(30, color: g.textDim)),
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

/// The first of [providers] that loads, else a music-note tile.
class _Art extends StatelessWidget {
  const _Art({required this.providers, required this.size, this.decoded});

  final List<ImageProvider> providers;
  final ui.Image? decoded;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.guide.radius * 2),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 40, offset: Offset(0, 12))],
        ),
        clipBehavior: Clip.antiAlias,
        child: decoded != null ? RawImage(image: decoded, fit: BoxFit.cover) : _image(context, 0),
      );

  Widget _image(BuildContext context, int i) {
    if (i >= providers.length) return const MusicNoteTile();
    return Image(
      image: providers[i],
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, _, _) => _image(context, i + 1),
    );
  }
}

/// Stands in for missing album art: the Nightingale bird, since it sings.
class MusicNoteTile extends StatelessWidget {
  const MusicNoteTile({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [g.cellBorder, g.panel],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Center(child: NightingaleMark(height: box.maxHeight * 0.4, color: g.accent)),
      ),
    );
  }
}
