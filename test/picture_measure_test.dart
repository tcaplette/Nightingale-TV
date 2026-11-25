import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/reporting/picture_measure.dart';

/// The decoded h264 card that tool/make_video_test_card.py wrote, as RGBA.
Future<({Uint8List rgba, int width, int height})> _card(WidgetTester tester) async {
  final result = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(File('test/fixtures/video_test/card_h264.png').readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (rgba: bytes!.buffer.asUint8List(), width: image.width, height: image.height);
  });
  return result!;
}

Map<String, Object?> _json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

PictureMeasure _expected(String card) =>
    PictureMeasure.fromJson((_json('assets/video_test/card_expected.json')['cards'] as Map)[card] as Map);

void main() {
  testWidgets('the Dart and Python measurements agree on the same card', (tester) async {
    final card = await _card(tester);
    expect((card.width, card.height), (1920, 1080));
    final dart = measureRgba(card.rgba, card.width, card.height);
    final python = PictureMeasure.fromJson(_json('test/fixtures/video_test/card_h264.json'));
    expect(dart.grid, python.grid, reason: 'every cell the same, to the level');
    expect(dart.detail, closeTo(python.detail, 0.0011));
  });

  testWidgets('the decoded card passes against card_expected.json', (tester) async {
    final card = await _card(tester);
    final check = checkCard(measureRgba(card.rgba, card.width, card.height), _expected('h264'));
    expect(check.pass, isTrue);
    expect(check.worstCell, 0);
    expect(check.detailRatio, closeTo(1, 0.001));
    // The other cards are the same picture, within the tolerance.
    for (final other in ['hevc', 'hevc10']) {
      expect(checkCard(measureRgba(card.rgba, card.width, card.height), _expected(other)).pass, isTrue, reason: other);
    }
  });

  testWidgets('a blurred card fails, with detail far below expected', (tester) async {
    final card = await _card(tester);
    // Each 8×8 block its own mean.
    final blurred = Uint8List.fromList(card.rgba);
    for (var y = 0; y < 1080; y++) {
      for (var x = 0; x < 1920; x++) {
        final i = (y * 1920 + x) * 4, from = ((y ~/ 8 * 8) * 1920 + x ~/ 8 * 8) * 4;
        blurred.setRange(i, i + 3, card.rgba, from);
      }
    }
    final check = checkCard(measureRgba(blurred, 1920, 1080), _expected('h264'));
    expect(check.pass, isFalse);
    expect(check.detailRatio, lessThan(0.75));
  });

  test('the MPEG-2 card has its own figures', () {
    final m = _expected('mpeg2');
    expect(m.grid, hasLength(144));
    // The same card, smaller: the same colours but for the encoder.
    final off = m.cellDifferences(_expected('h264')).where((d) => d > 20).length;
    expect(off, lessThan(20));
  });

  group('edges', () {
    Uint8List scene(int w, int h, List<int> Function(int x, int y) colour) {
      final out = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4, c = colour(x, y);
          out[i] = c[0];
          out[i + 1] = c[1];
          out[i + 2] = c[2];
          out[i + 3] = 255;
        }
      }
      return out;
    }

    List<int> busy(int x, int y) => [(x * 7 + y * 3) % 256, (x * 5) % 200, (y * 11) % 256];
    const bt601 = [0, 135, 0], bt709 = [0, 77, 0];

    test('a picture with none', () {
      final e = edgeStrips(scene(720, 480, busy), 720, 480);
      expect((e.right, e.bottom, e.any), (0, 0, false));
    });

    test('the Shield reports: the last 48 of 768 columns are #008700', () {
      final e = edgeStrips(scene(768, 480, (x, y) => x >= 720 ? bt601 : busy(x, y)), 768, 480);
      expect(e.right, 48);
      expect(e.bottom, 0);
      expect(e.any, isTrue);
    });

    test('empty memory read with BT.709', () {
      final e = edgeStrips(scene(768, 480, (x, y) => x >= 720 ? bt709 : busy(x, y)), 768, 480);
      expect((e.right, e.any), (48, true));
    });

    test('an 8-pixel strip at the bottom', () {
      final e = edgeStrips(scene(320, 1088, (x, y) => y >= 1080 ? bt601 : busy(x, y)), 320, 1088);
      expect((e.right, e.bottom, e.any), (0, 8, true));
    });

    test('a scaled edge of a pixel or two is not a strip', () {
      expect(edgeStrips(scene(320, 180, (x, y) => x >= 318 ? bt601 : busy(x, y)), 320, 180).any, isFalse);
    });

    test('dark and green scenes are not padding', () {
      expect(edgeStrips(scene(320, 180, (x, y) => [0, 0, 0]), 320, 180).any, isFalse, reason: 'black');
      expect(edgeStrips(scene(320, 180, (x, y) => [20, 18, 16]), 320, 180).any, isFalse, reason: 'dark');
      expect(edgeStrips(scene(320, 180, (x, y) => bt601), 320, 180).any, isFalse, reason: 'all of that green');
      expect(edgeStrips(scene(320, 180, (x, y) => x >= 160 ? bt601 : busy(x, y)), 320, 180).any, isFalse,
          reason: 'half of it');
      expect(edgeStrips(scene(320, 180, (x, y) => x >= 300 ? [10, 120 + y % 40, 8] : busy(x, y)), 320, 180).any, isFalse,
          reason: 'grass');
    });
  });

  test('the clear area of a capture, with things over it', () {
    final img = Uint8List(64 * 36 * 4);
    for (var i = 3; i < img.length; i += 4) {
      img[i] = 255;
    }
    expect(clearArea(img, 64, 36), isNull, reason: 'all opaque');
    for (var y = 4; y < 30; y++) {
      for (var x = 10; x < 50; x++) {
        // The logo, opaque, and scanlines, half.
        img[(y * 64 + x) * 4 + 3] = x > 40 && y > 24 ? 255 : (y.isEven ? 80 : 0);
      }
    }
    expect(clearArea(img, 64, 36), (left: 10, top: 4, right: 50, bottom: 30));
  });

  test('sub-rectangles: only the area asked for is measured', () {
    // Left half red, right half blue.
    const w = 64, h = 18;
    final img = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        img[i] = x < 32 ? 255 : 0;
        img[i + 2] = x < 32 ? 0 : 255;
        img[i + 3] = 255;
      }
    }
    expect(measureRgba(img, w, h, left: 32, w: 32).grid.toSet(), {'0000ff'});
    expect(measureRgba(img, w, h, w: 32).grid.toSet(), {'ff0000'});
    expect(() => measureRgba(img, w, h, left: 40, w: 32), throwsRangeError);
  });

  test('measuring in an isolate gives the same figures', () async {
    final img = Uint8List.fromList([for (var i = 0; i < 32 * 18; i++) ...[i % 251, (i * 7) % 256, (i * 13) % 256, 255]]);
    final here = measureRgba(img, 32, 18);
    final there = await measureInIsolate(img, 32, 18);
    expect(there.grid, here.grid);
    expect(there.detail, here.detail);
  });
}
