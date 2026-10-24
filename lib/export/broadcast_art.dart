import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../library/library_index.dart';
import '../theme/tv_theme.dart';
import '../ui/format.dart';
import '../ui/widgets/broadcast_cards.dart';
import '../ui/widgets/channel_logo.dart';
import '../ui/widgets/now_playing.dart';
import '../ui/widgets/tv_canvas.dart';
import 'lineup_server.dart';
import 'offscreen_renderer.dart';
import '../server/media_server.dart';

/// A full-screen card an exported stream shows (design D6).
sealed class BroadcastCard {
  const BroadcastCard();

  /// What makes two cards look different (the cache key).
  String get key;
}

/// Stream start: black, the channel number and name in the corner.
class TuningCardSpec extends BroadcastCard {
  const TuningCardSpec(this.channel);
  final Channel channel;
  @override
  String get key => 'tuning|${channel.number}|${channel.name}';
}

/// Between segments while a source is late.
class BlackCard extends BroadcastCard {
  const BlackCard();
  @override
  String get key => 'black';
}

/// A block-only channel between its blocks.
class OffAirCard extends BroadcastCard {
  const OffAirCard({this.next});

  /// The next block and when it starts, as the TV says it.
  final ({String when, String title})? next;

  /// The card for [schedule] at [now].
  factory OffAirCard.at(ProgramSchedule schedule, DateTime now) {
    final next = schedule.nextBlockAiring(now);
    if (next == null) return const OffAirCard();
    final when = next.start.difference(now) < const Duration(hours: 20)
        ? formatTime(next.start)
        : '${formatDate(next.start)} ${formatTime(next.start)}';
    return OffAirCard(next: (when: when, title: next.title));
  }

  String? get message => next == null ? null : 'Back on the air ${next!.when} with ${next!.title}';
  @override
  String get key => 'offair|$message';
}

/// PLEASE STAND BY: "Up next at …" when a file ends early, "We'll be right
/// back" when a segment can't play.
class StandByCard extends BroadcastCard {
  StandByCard.upNext(DateTime at) : text = 'Up next at ${formatTime(at)}';
  const StandByCard.rightBack() : text = "We'll be right back";

  final String text;
  @override
  String get key => 'standby|$text';
}

/// Draws the cards and channel logos Live TV export uses, and keeps them:
/// card PNGs on disk (they're encoded once each, D3), logos in memory.
class BroadcastArt implements LogoSource {
  BroadcastArt(this.cacheDir, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final Directory cacheDir;
  final http.Client _http;

  /// Logos by the channel icon's JSON.
  final _logos = <String, Uint8List>{};
  static const _logoCacheSize = 200;

  static const logoSize = 512.0;

  /// [card]'s PNG at [height] (1080 or 720), drawn once.
  Future<File> cardPng(BroadcastCard card, AppState app, int height) async {
    final name = md5.convert(utf8.encode('${card.key}|$height')).toString();
    final file = File('${cacheDir.path}/card-$name.png');
    if (await file.exists()) return file;
    await cacheDir.create(recursive: true);
    final widget = _cardWidget(card);
    final png = await OffscreenRenderer.renderPng(widget,
        logicalSize: TvCanvas.size, pixelRatio: height / TvCanvas.size.height);
    final tmp = File('${file.path}.$pid.tmp');
    await tmp.writeAsBytes(png, flush: true);
    await tmp.rename(file.path);
    return file;
  }

  /// The Now Playing card for [song] (a slot on music [channel]; [next]
  /// is the song after it) as [height]p PNG: the picture of a song in an
  /// exported stream (channel-streaming). Drawn once per song.
  Future<File> nowPlayingPng(AppState app, Channel channel, ScheduledProgram song, ScheduledProgram? next, int height) async {
    final item = song.item!;
    final key = '${channel.number}|${channel.name}|${jsonEncode(channel.icon.toJson())}|${item.id}|${next?.item?.id}|$height';
    final file = File('${cacheDir.path}/song-${md5.convert(utf8.encode(key))}.png');
    if (await file.exists()) return file;
    await cacheDir.create(recursive: true);
    final art = await _albumArt(app, item);
    final logoPng = await pngFor(app, channel);
    final logo = logoPng == null ? null : await OffscreenRenderer.decode(logoPng);
    try {
      final png = await OffscreenRenderer.renderPng(
        NowPlayingCard(
          channel: channel,
          song: song,
          next: next,
          live: false,
          decodedArt: art,
          logo: logo == null
              ? null
              : SizedBox(width: 110, height: 64, child: RawImage(image: logo, fit: BoxFit.contain, alignment: Alignment.centerLeft)),
          app: app,
        ),
        logicalSize: TvCanvas.size,
        pixelRatio: height / TvCanvas.size.height,
      );
      final tmp = File('${file.path}.$pid.tmp');
      await tmp.writeAsBytes(png, flush: true);
      await tmp.rename(file.path);
      return file;
    } finally {
      art?.dispose();
      logo?.dispose();
    }
  }

  /// [song]'s album image, else its own, decoded; null when neither loads.
  Future<ui.Image?> _albumArt(AppState app, MediaEntry song) async {
    final client = app.client;
    if (client == null) return null;
    for (final id in [?song.albumId, song.id]) {
      try {
        final uri = client.imageUri(id, ImageKind.primary, maxHeight: 640);
        final r = await _http
            .get(uri.replace(queryParameters: {...uri.queryParameters, 'format': 'Jpg'}), headers: client.authHeaders)
            .timeout(const Duration(seconds: 15));
        if (r.statusCode == HttpStatus.ok) return await OffscreenRenderer.decode(r.bodyBytes);
      } on Object catch (e) {
        debugPrint('No art for ${song.id} from $id: $e');
      }
    }
    return null;
  }

  Widget _cardWidget(BroadcastCard card) => switch (card) {
        TuningCardSpec(:final channel) => TuningCard(channel: channel),
        BlackCard() => const ColoredBox(color: Colors.black),
        OffAirCard() => StatusCard(icon: Icons.tv_off, title: 'OFF THE AIR', message: card.message),
        StandByCard() => StatusCard(icon: Icons.schedule, title: 'PLEASE STAND BY', message: card.text),
      };

  @override
  Future<Uint8List?> pngFor(AppState app, Channel channel) async {
    final key = jsonEncode(channel.icon.toJson());
    final cached = _logos.remove(key);
    if (cached != null) return _logos[key] = cached;
    Uint8List? png;
    try {
      png = await _drawLogo(app, channel);
    } on Object catch (e) {
      debugPrint('Couldn\'t draw the logo of channel ${channel.number}: $e');
    }
    png ??= await _badge(_initials(channel.name), BadgeShape.roundedSquare, GuideTheme.cableGuide.accent);
    if (_logos.length >= _logoCacheSize) _logos.remove(_logos.keys.first);
    return _logos[key] = png;
  }

  /// [channel]'s logo ([pngFor]) as a file, for the encoders to lay over
  /// the picture (channel-streaming).
  Future<File?> logoFile(AppState app, Channel channel) async {
    final png = await pngFor(app, channel);
    if (png == null) return null;
    final file = File('${cacheDir.path}/logo-${md5.convert(png)}.png');
    if (await file.exists()) return file;
    await cacheDir.create(recursive: true);
    final tmp = File('${file.path}.$pid.tmp');
    await tmp.writeAsBytes(png, flush: true);
    await tmp.rename(file.path);
    return file;
  }

  Future<Uint8List?> _drawLogo(AppState app, Channel channel) async {
    final icon = channel.icon;
    switch (icon.kind) {
      case ChannelIconKind.builtin || ChannelIconKind.badge:
        return OffscreenRenderer.renderPng(
          ChannelLogo(icon: icon, size: logoSize, fallbackText: channel.name, app: app),
          logicalSize: const Size.square(logoSize),
        );
      case ChannelIconKind.custom:
        final file = app.icons.fileFor(icon.value);
        if (!await file.exists()) return null;
        if (file.path.toLowerCase().endsWith('.svg')) return _svg(file);
        return _asPng(await file.readAsBytes());
      case ChannelIconKind.jellyfin:
        final client = app.client;
        if (client == null) return null;
        final uri = client.imageUri(icon.value, ImageKind.logo, maxHeight: 400);
        final r = await _http
            .get(uri.replace(queryParameters: {...uri.queryParameters, 'format': 'Png'}), headers: client.authHeaders)
            .timeout(const Duration(seconds: 15));
        return r.statusCode == HttpStatus.ok ? _asPng(r.bodyBytes) : null;
      case ChannelIconKind.remote:
        // Only live channels have these, and they're never exported.
        return null;
    }
  }

  static Future<Uint8List> _badge(String text, BadgeShape shape, Color color) => OffscreenRenderer.renderPng(
        StationBadge(text: text, shape: shape, color: color, size: logoSize),
        logicalSize: const Size.square(logoSize),
      );

  /// An SVG upload, drawn to fit a [logoSize] square.
  static Future<Uint8List> _svg(File file) async {
    final info = await vg.loadPicture(SvgFileLoader(file), null);
    try {
      final scale = logoSize / (info.size.longestSide == 0 ? logoSize : info.size.longestSide);
      final w = (info.size.width * scale).ceil().clamp(1, 4096), h = (info.size.height * scale).ceil().clamp(1, 4096);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..scale(scale)
        ..drawPicture(info.picture);
      final image = await recorder.endRecording().toImage(w, h);
      try {
        return await OffscreenRenderer.pngOf(image);
      } finally {
        image.dispose();
      }
    } finally {
      info.picture.dispose();
    }
  }

  /// A raster logo as PNG, scaled so its longer side is [logoSize]: every
  /// logo comes out the same size, whatever the source.
  static Future<Uint8List> _asPng(Uint8List bytes) async {
    final source = await OffscreenRenderer.decode(bytes);
    try {
      final scale = logoSize / (source.width > source.height ? source.width : source.height);
      final w = (source.width * scale).round().clamp(1, 4096), h = (source.height * scale).round().clamp(1, 4096);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final image = await recorder.endRecording().toImage(w, h);
      try {
        return await OffscreenRenderer.pngOf(image);
      } finally {
        image.dispose();
      }
    } finally {
      source.dispose();
    }
  }

  static String _initials(String name) {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'TV';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 4));
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }
}
