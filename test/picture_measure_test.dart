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

  testWidgets('a smeared, colour-washed card fails, with detail far below expected', (tester) async {
    final card = await _card(tester);
    final smeared = smearPicture(card.rgba, card.width, card.height);
    final m = measureRgba(smeared, card.width, card.height);
    final check = checkCard(m, _expected('h264'));
    expect(check.pass, isFalse);
    expect(check.detailRatio, lessThan(0.2), reason: 'the blur takes the fine detail');
    expect(check.cellsOff, greaterThan(72), reason: 'the wash moves most cells');
    // The wash follows the screen: blue top left, yellow bottom right.
    final tl = m.grid.first, br = m.grid.last;
    expect(int.parse(tl.substring(4, 6), radix: 16), greaterThan(int.parse(tl.substring(0, 2), radix: 16)));
    expect(int.parse(br.substring(0, 2), radix: 16), greaterThan(int.parse(br.substring(4, 6), radix: 16)));
    expect(m.renderEmpty, isFalse);
  });

  testWidgets('the colour matrix: the card as BT.601 shows it fits bt601, the smear neither', (tester) async {
    final card = await _card(tester);
    final want = _expected('h264');
    expect(matrixFit(measureRgba(card.rgba, card.width, card.height), want), 'bt709');
    // What the Android emulator's GPU drew (its video report, 2026-11-09).
    final bt601 = asBt601(want);
    expect(bt601.grid.first, anyOf('cb0a20', 'cb0921'), reason: 'the red corner');
    expect(matrixFit(bt601, want), 'bt601');
    expect(checkCard(bt601, want).pass, isFalse, reason: 'a wrong matrix is still a failed run');
    expect(matrixFit(measureRgba(smearPicture(card.rgba, card.width, card.height), card.width, card.height), want),
        'neither');
  });

  test('coarse detail: the same at any scale, far lower for a blur', () {
    // Mid-scale texture, as real pictures have: 8-px checks, here at
    // 1920×1080 and at 960×540 (a smaller texture shown on the same screen).
    Uint8List checks(int w, int h, int size) {
      final out = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final v = ((x ~/ size) + (y ~/ size)).isEven ? 200 : 60;
          final i = (y * w + x) * 4;
          out[i] = out[i + 1] = out[i + 2] = v;
          out[i + 3] = 255;
        }
      }
      return out;
    }

    final full = coarseDetail(checks(1920, 1080, 8), 1920, 1080);
    expect(coarseDetail(checks(960, 540, 4), 960, 540) / full, closeTo(1, 0.05));
    final smeared = smearPicture(checks(1920, 1080, 8), 1920, 1080);
    expect(coarseDetail(smeared, 1920, 1080) / full, lessThan(PictureMeasure.screenDetailShare));
  });

  test('an all-black image reads render_empty', () {
    final black = Uint8List(64 * 36 * 4);
    for (var i = 3; i < black.length; i += 4) {
      black[i] = 255;
    }
    final m = measureRgba(black, 64, 36);
    expect(m.renderEmpty, isTrue);
    expect(m.detail, 0);
    expect(m.grid.toSet(), {'000000'});
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

  test('screen share: overlays on a few cells still match', () {
    final texture = PictureMeasure(List.filled(144, '808080'), 10);
    final withBug = PictureMeasure([...List.filled(140, '828282'), ...List.filled(4, 'ffffff')], 10);
    expect(screenShare(withBug, texture), greaterThanOrEqualTo(PictureMeasure.screenShare));
    final washed = PictureMeasure(List.filled(144, '3050e0'), 10);
    expect(screenShare(washed, texture), lessThan(PictureMeasure.screenShare));
  });

  test('measuring in an isolate gives the same figures', () async {
    final img = Uint8List.fromList([for (var i = 0; i < 32 * 18; i++) ...[i % 251, (i * 7) % 256, (i * 13) % 256, 255]]);
    final here = measureRgba(img, 32, 18);
    final there = await measureInIsolate(img, 32, 18);
    expect(there.grid, here.grid);
    expect(there.detail, here.detail);
  });
}
