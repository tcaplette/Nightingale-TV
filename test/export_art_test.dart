import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/export/broadcast_art.dart';
import 'package:nightingale_tv/export/offscreen_renderer.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'fixtures.dart';

/// Decodes [png] and checks it's [w]×[h] with something drawn on it.
void expectDrawn(Uint8List png, int w, int h) {
  final image = img.decodePng(png);
  expect(image, isNotNull);
  expect(image!.width, w);
  expect(image.height, h);
  final colors = <int>{};
  for (final p in image) {
    if (p.a > 0) colors.add(p.r.toInt() << 16 | p.g.toInt() << 8 | p.b.toInt());
    if (colors.length > 1) break;
  }
  expect(colors.length, greaterThan(1), reason: 'more than one color drawn');
}

void main() {
  late Directory dir;
  late AppState app;
  late BroadcastArt art;
  var jellyfinLogo = 200;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_art');
    app = await signedInApp(dir, fakeLibrary());
    final logo = img.Image(width: 300, height: 100)..clear(img.ColorRgb8(200, 30, 30));
    img.fillRect(logo, x1: 20, y1: 20, x2: 120, y2: 80, color: img.ColorRgb8(255, 255, 255));
    art = BroadcastArt(Directory('${dir.path}/cache'), httpClient: MockClient((r) async {
      if (jellyfinLogo != 200) return http.Response('', jellyfinLogo);
      return http.Response.bytes(img.encodePng(logo), 200, headers: {'content-type': 'image/png'});
    }));
  });

  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });

  Channel channelWith(ChannelIcon icon) => app.channels.first..icon = icon;

  testWidgets('every card kind draws at 1080p and 720p', (tester) async {
    await tester.runAsync(() async {
      final ch = app.channels.first;
      final cards = <BroadcastCard>[
        TuningCardSpec(ch),
        const BlackCard(),
        const OffAirCard(next: (when: '7:00 PM', title: 'Cartoons')),
        const OffAirCard(),
        StandByCard.upNext(DateTime(2026, 1, 1, 19, 30)),
        const StandByCard.rightBack(),
      ];
      for (final card in cards) {
        for (final height in [1080, 720]) {
          final file = await art.cardPng(card, app, height);
          final png = await file.readAsBytes();
          final image = img.decodePng(png)!;
          expect((image.width, image.height), (height * 16 ~/ 9, height), reason: card.key);
          if (card is! BlackCard) expectDrawn(png, image.width, image.height);
        }
      }
    });
  });

  testWidgets('cards are drawn once and keyed by what they show', (tester) async {
    await tester.runAsync(() async {
      final a = await art.cardPng(const StandByCard.rightBack(), app, 720);
      final modified = await a.lastModified();
      final again = await art.cardPng(const StandByCard.rightBack(), app, 720);
      expect(again.path, a.path);
      expect(await again.lastModified(), modified);
      final other = await art.cardPng(StandByCard.upNext(DateTime(2026, 1, 1, 20)), app, 720);
      expect(other.path, isNot(a.path));
      expect(const OffAirCard(next: (when: '7:00 PM', title: 'A')).key,
          isNot(const OffAirCard(next: (when: '8:00 PM', title: 'A')).key));
      final ch = app.channels.first;
      final before = TuningCardSpec(ch).key;
      ch.name = 'Renamed';
      expect(TuningCardSpec(ch).key, isNot(before));
    });
  });

  testWidgets('logos draw for every icon kind', (tester) async {
    await tester.runAsync(() async {
      Future<void> check(ChannelIcon icon) async {
        final png = await art.pngFor(app, channelWith(icon));
        final image = img.decodePng(png!)!;
        expect(image.width >= 400 || image.height >= 400, isTrue, reason: '${icon.kind}');
        expectDrawn(png, image.width, image.height);
      }

      await check(const ChannelIcon.builtin('tv'));
      await check(const ChannelIcon(kind: ChannelIconKind.badge, value: 'KTV', color: 0xFF2255CC));
      await check(const ChannelIcon(kind: ChannelIconKind.jellyfin, value: 'series-Alpha'));

      final svg = app.icons.fileFor('star.svg');
      await svg.writeAsString(
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">'
          '<rect width="100" height="50" fill="#123456"/><circle cx="25" cy="25" r="20" fill="#ff0"/></svg>');
      await check(const ChannelIcon(kind: ChannelIconKind.custom, value: 'star.svg'));

      final jpg = img.Image(width: 640, height: 320)..clear(img.ColorRgb8(10, 120, 40));
      img.fillCircle(jpg, x: 100, y: 100, radius: 50, color: img.ColorRgb8(250, 250, 250));
      await app.icons.fileFor('photo.jpg').writeAsBytes(img.encodeJpg(jpg));
      await check(const ChannelIcon(kind: ChannelIconKind.custom, value: 'photo.jpg'));
    });
  });

  testWidgets("a logo that can't be fetched falls back to a badge", (tester) async {
    await tester.runAsync(() async {
      jellyfinLogo = 404;
      addTearDown(() => jellyfinLogo = 200);
      final png = await art.pngFor(app, channelWith(const ChannelIcon(kind: ChannelIconKind.jellyfin, value: 'gone')));
      final image = img.decodePng(png!)!;
      expectDrawn(png, image.width, image.height);
    });
  });

  testWidgets('the renderer draws a widget at the requested size', (tester) async {
    await tester.runAsync(() async {
      final png = await OffscreenRenderer.renderPng(
        const ColoredBox(color: Colors.red, child: Center(child: SizedBox(width: 10, height: 10, child: ColoredBox(color: Colors.blue)))),
        logicalSize: const Size(200, 100),
        pixelRatio: 0.5,
      );
      expectDrawn(png, 100, 50);
    });
  });

  testWidgets("a song's Now Playing card draws once per song, with its album art", (tester) async {
    await tester.runAsync(() async {
      app.client = app.clientFor('https://jf.example');
      const song = MediaEntry(
          id: 's1', kind: MediaKind.song, title: 'Take On Me', runtime: Duration(minutes: 4), artist: 'a-ha', albumId: 'al1');
      final start = DateTime(2026, 10, 20, 19);
      final slot = ScheduledProgram(item: song, start: start, end: start.add(song.runtime));
      final ch = app.channels.first;
      final file = await art.nowPlayingPng(app, ch, slot, null, 720);
      expectDrawn(await file.readAsBytes(), 1280, 720);
      final again = await art.nowPlayingPng(app, ch, slot, null, 720);
      expect(again.path, file.path);
      expect(again.lastModifiedSync(), file.lastModifiedSync(), reason: 'drawn once');
      // No art at all still draws (the music-note tile).
      jellyfinLogo = 404;
      final other = ScheduledProgram(item: const MediaEntry(id: 's2', kind: MediaKind.song, title: 'B', runtime: Duration(minutes: 3)),
          start: start, end: start.add(const Duration(minutes: 3)));
      expectDrawn(await (await art.nowPlayingPng(app, ch, other, slot, 1080)).readAsBytes(), 1920, 1080);
      jellyfinLogo = 200;
    });
  });
}
