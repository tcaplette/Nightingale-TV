import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/caption_size.dart';

void main() {
  test('the four sizes, in canvas pixels', () {
    expect([for (final s in CaptionSize.values) s.px], [40, 54, 68, 84]);
    expect([for (final s in CaptionSize.values) s.label], ['Small', 'Medium', 'Large', 'Extra large']);
  });

  test('the ratio is against Medium', () {
    expect(CaptionSize.medium.ratio, 1);
    expect(CaptionSize.extraLarge.ratio, closeTo(84 / 54, 1e-9));
    expect(CaptionSize.small.ratio, closeTo(40 / 54, 1e-9));
  });

  test('each system caption scale maps to the nearest size', () {
    expect(CaptionSize.nearestToScale(0.25), CaptionSize.small);
    expect(CaptionSize.nearestToScale(0.5), CaptionSize.small);
    expect(CaptionSize.nearestToScale(1.0), CaptionSize.medium);
    expect(CaptionSize.nearestToScale(1.5), CaptionSize.extraLarge);
    expect(CaptionSize.nearestToScale(2.0), CaptionSize.extraLarge);
  });

  test('an unusable system scale is Medium', () {
    expect(CaptionSize.nearestToScale(null), CaptionSize.medium);
    expect(CaptionSize.nearestToScale(0), CaptionSize.medium);
    expect(CaptionSize.nearestToScale(-1), CaptionSize.medium);
    expect(CaptionSize.nearestToScale(double.nan), CaptionSize.medium);
    expect(CaptionSize.nearestToScale(double.infinity), CaptionSize.medium);
  });

  test('read back by name; anything else is null', () {
    expect(CaptionSize.fromName('extraLarge'), CaptionSize.extraLarge);
    expect(CaptionSize.fromName('huge'), isNull);
    expect(CaptionSize.fromName(54), isNull);
    expect(CaptionSize.fromName(null), isNull);
  });
}
