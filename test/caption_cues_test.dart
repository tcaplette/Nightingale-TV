import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/caption_size.dart';
import 'package:nightingale_tv/playback/caption_style.dart';
import 'package:nightingale_tv/playback/exo_tuner_player.dart';

final png = Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));

ExoImageCue cue(double left, double top, double width, double height) =>
    ExoImageCue(png: png, left: left, top: top, width: width, height: height, aspect: 1);

void main() {
  const picture = Size(1920, 1080);

  group('placeImageCues', () {
    for (final size in CaptionSize.values) {
      test('${size.label}: grows about the bottom centre', () {
        final authored = cue(0.3, 0.8, 0.4, 0.1);
        final r = placeImageCues([authored], picture, size.ratio).single;
        expect(r.width, closeTo(768 * size.ratio, 1e-6));
        expect(r.height, closeTo(108 * size.ratio, 1e-6));
        expect(r.center.dx, closeTo(960, 1e-6));
        expect(r.bottom, closeTo(972, 1e-6));
      });
    }

    test('kept inside the picture at the edges', () {
      final top = placeImageCues([cue(0, 0, 0.3, 0.1)], picture, CaptionSize.extraLarge.ratio).single;
      expect(top.left, 0);
      expect(top.top, 0);
      final right = placeImageCues([cue(0.7, 0.5, 0.3, 0.1)], picture, CaptionSize.extraLarge.ratio).single;
      expect(right.right, closeTo(1920, 1e-6));
    });

    test('a cue too wide to grow fully fills the picture, its shape kept', () {
      final r = placeImageCues([cue(0.05, 0.8, 0.9, 0.1)], picture, CaptionSize.extraLarge.ratio).single;
      expect(r.width, closeTo(1920, 1e-6));
      expect(r.height / r.width, closeTo(108 / (0.9 * 1920), 1e-6));
    });

    test('lines in separate cues stay apart', () {
      final rects = placeImageCues([cue(0.3, 0.74, 0.4, 0.08), cue(0.3, 0.83, 0.4, 0.08)], picture, CaptionSize.extraLarge.ratio);
      expect(rects[0].overlaps(rects[1]), isFalse);
      expect(rects[1].bottom, closeTo(0.91 * 1080, 1e-6), reason: 'the lowest stays put');
    });

    test('cues that overlapped as authored are left where they grow', () {
      final rects = placeImageCues([cue(0.3, 0.7, 0.4, 0.2), cue(0.3, 0.75, 0.4, 0.2)], picture, 1);
      expect(rects[0].top, closeTo(0.7 * 1080, 1e-6));
    });
  });

  testWidgets('image cues are drawn at each size, on a change too', (tester) async {
    final cues = ValueNotifier(ExoCues(const [], [cue(0.3, 0.8, 0.4, 0.1)]));
    final size = ValueNotifier(CaptionSize.medium);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: const Size(800, 600), child: ExoImageCues(cues, size, const Size(800, 600))),
      ),
    ));
    for (final s in CaptionSize.values) {
      size.value = s;
      await tester.pump();
      final rect = tester.getRect(find.byType(Image));
      expect(rect.width, closeTo(320 * s.ratio, 1e-6), reason: s.label);
      expect(rect.bottom, closeTo(540, 1e-6), reason: s.label);
    }
  });

  group('captionTextStyle', () {
    test('only the size varies', () {
      final large = captionTextStyle(CaptionSize.large);
      expect(large.fontSize, 68);
      expect(captionTextStyle(CaptionSize.small).copyWith(fontSize: 68), large);
      expect(large.height, 1.4);
      expect(large.color, const Color(0xffffffff));
      expect(large.backgroundColor, const Color(0xaa000000));
    });

    test('shrinks with a smaller box, never grows', () {
      expect(captionBoxScale(const Size(1920, 1080)), 1);
      expect(captionBoxScale(const Size(960, 540)), closeTo(0.5, 1e-9));
      expect(captionBoxScale(const Size(3840, 2160)), 1);
    });
  });
}
