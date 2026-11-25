import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

/// The one measurement every picture in a video report gets (video-report,
/// design D2): the video layer's picture and each card's CPU decode. Ported line for line to Python in
/// tool/make_video_test_card.py, which makes the cards' expected values.
///
/// - [grid]: 16×9 mean sRGB colours, `rrggbb`, row by row from the top left.
/// - [detail]: the mean absolute luma difference between neighbouring pixels,
///   horizontally and vertically, on a 0–255 scale.
///
/// 144 coarse cells can't show what is being watched, so nothing more of a
/// picture ever leaves the device.
class PictureMeasure {
  const PictureMeasure(this.grid, this.detail);

  static const columns = 16, rows = 9;

  /// A cell or a card passes within this, per channel (as
  /// tool/video_color_check.py).
  static const tolerance = 14;

  /// A card's detail passes within this fraction of its expected figure.
  static const detailTolerance = 0.25;

  final List<String> grid;
  final double detail;

  factory PictureMeasure.fromJson(Map<Object?, Object?> json) => PictureMeasure(
      [for (final c in json['grid'] as List) '$c'], (json['detail'] as num).toDouble());

  Map<String, Object> toJson() => {'grid': grid, 'detail': (detail * 1000).round() / 1000};

  /// The worst per-channel difference of each cell from [other]'s.
  List<int> cellDifferences(PictureMeasure other) => [
        for (var i = 0; i < grid.length && i < other.grid.length; i++)
          () {
            final a = _channels(grid[i]), b = _channels(other.grid[i]);
            return [for (var c = 0; c < 3; c++) (a[c] - b[c]).abs()].reduce(max);
          }(),
      ];

  static List<int> _channels(String hex) =>
      [for (var i = 0; i < 6; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
}

/// A self-test run checked against its card (design D5).
class CardCheck {
  const CardCheck({required this.pass, required this.worstCell, required this.cellsOff, required this.detailRatio});

  final bool pass;

  /// The largest per-channel difference of any cell.
  final int worstCell;

  /// Cells more than [PictureMeasure.tolerance] off.
  final int cellsOff;

  /// Measured detail over expected.
  final double detailRatio;

  Map<String, Object> toJson() => {
        'pass': pass,
        'worst_cell': worstCell,
        'cells_off': cellsOff,
        'detail_ratio': (detailRatio * 1000).round() / 1000,
      };
}

/// Passes when every cell is within [PictureMeasure.tolerance] of the
/// card's and the detail is within [PictureMeasure.detailTolerance].
CardCheck checkCard(PictureMeasure measured, PictureMeasure expected) {
  final diffs = measured.cellDifferences(expected);
  final worst = diffs.isEmpty ? 255 : diffs.reduce(max);
  final off = diffs.where((d) => d > PictureMeasure.tolerance).length;
  final ratio = expected.detail > 0 ? measured.detail / expected.detail : 0.0;
  final pass = diffs.length == expected.grid.length &&
      off == 0 &&
      (ratio - 1).abs() <= PictureMeasure.detailTolerance;
  return CardCheck(pass: pass, worstCell: worst, cellsOff: off, detailRatio: ratio);
}

/// Integer luma, 0–255, as the Python port computes it.
int _luma(int r, int g, int b) => (77 * r + 150 * g + 29 * b + 128) >> 8;

/// [rgba] ([width]×[height], 4 bytes a pixel) measured over the
/// sub-rectangle at [left], [top] of [w]×[h] (the whole image by default).
PictureMeasure measureRgba(Uint8List rgba, int width, int height, {int left = 0, int top = 0, int? w, int? h}) {
  final rw = w ?? width - left, rh = h ?? height - top;
  if (rw <= 0 || rh <= 0 || left < 0 || top < 0 || left + rw > width || top + rh > height) {
    throw RangeError('sub-rectangle $left,$top ${rw}x$rh outside ${width}x$height');
  }
  const cols = PictureMeasure.columns, rows = PictureMeasure.rows;
  final sums = List.filled(cols * rows * 3, 0);
  final counts = List.filled(cols * rows, 0);
  // Which cell column each x falls in.
  final colOf = Int32List(rw);
  for (var c = 0; c < cols; c++) {
    for (var x = c * rw ~/ cols; x < (c + 1) * rw ~/ cols; x++) {
      colOf[x] = c;
    }
  }
  var diffs = 0;
  var above = Int32List(rw);
  var line = Int32List(rw);
  var row = 0;
  for (var y = 0; y < rh; y++) {
    while ((row + 1) * rh ~/ rows <= y) {
      row++;
    }
    var i = ((top + y) * width + left) * 4;
    var prev = -1;
    for (var x = 0; x < rw; x++, i += 4) {
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final cell = row * cols + colOf[x];
      sums[cell * 3] += r;
      sums[cell * 3 + 1] += g;
      sums[cell * 3 + 2] += b;
      counts[cell]++;
      final l = _luma(r, g, b);
      line[x] = l;
      if (prev >= 0) diffs += (l - prev).abs();
      if (y > 0) diffs += (l - above[x]).abs();
      prev = l;
    }
    final t = above;
    above = line;
    line = t;
  }
  String hex(int v) => v.toRadixString(16).padLeft(2, '0');
  final grid = [
    for (var cell = 0; cell < cols * rows; cell++)
      if (counts[cell] == 0)
        '000000'
      else
        [for (var c = 0; c < 3; c++) hex((sums[cell * 3 + c] + counts[cell] ~/ 2) ~/ counts[cell])].join(),
  ];
  final pairs = (rw - 1) * rh + rw * (rh - 1);
  return PictureMeasure(grid, pairs > 0 ? diffs / pairs : 0);
}

/// [measureRgba] off the UI thread.
Future<PictureMeasure> measureInIsolate(Uint8List rgba, int width, int height,
        {int left = 0, int top = 0, int? w, int? h}) =>
    Isolate.run(() => measureRgba(rgba, width, height, left: left, top: top, w: w, h: h));

/// What empty video memory (YUV 0, 0, 0) shows as, by the matrix it's read
/// with: BT.601 and BT.709, both limited range.
const emptyMemoryColours = [(0, 135, 0), (0, 77, 0)];

/// The flat strips of empty video memory at the right and the bottom of a
/// picture (system-video-layer D8), in pixels; 0 for none.
class EdgeStrips {
  const EdgeStrips(this.right, this.bottom);

  final int right, bottom;

  /// Too thin to be anything but scaling (1–3 pixels).
  static const least = 4;

  /// A strip over this share of the picture is the picture's own.
  static const most = 0.15;

  /// Within this of the colour, per channel.
  static const tolerance = 8;

  bool get any => right >= least || bottom >= least;
}

/// [rgba]'s [EdgeStrips]: from each edge inwards, the whole columns or rows in
/// one colour of [emptyMemoryColours].
EdgeStrips edgeStrips(Uint8List rgba, int width, int height) {
  int strip(int across, int along, int Function(int a, int b) at) {
    var found = 0;
    for (final (r, g, b) in emptyMemoryColours) {
      var n = 0;
      for (; n < across; n++) {
        var off = 0;
        for (var k = 0; k < along; k++) {
          final i = at(n, k) * 4;
          if ((rgba[i] - r).abs() > EdgeStrips.tolerance ||
              (rgba[i + 1] - g).abs() > EdgeStrips.tolerance ||
              (rgba[i + 2] - b).abs() > EdgeStrips.tolerance) {
            off++;
          }
        }
        if (off > along ~/ 100) break;
      }
      if (n > found) found = n;
    }
    return found > across * EdgeStrips.most ? 0 : found;
  }

  return EdgeStrips(
    strip(width, height, (a, b) => b * width + (width - 1 - a)),
    strip(height, width, (a, b) => (height - 1 - a) * width + b),
  );
}

/// [edgeStrips] off the UI thread.
Future<EdgeStrips> edgeStripsInIsolate(Uint8List rgba, int width, int height) =>
    Isolate.run(() => edgeStrips(rgba, width, height));

/// Where [rgba] is clear (Flutter's hole for the video), as the smallest
/// rectangle holding it all, left/top/right/bottom in pixels; null when
/// nothing is.
({int left, int top, int right, int bottom})? clearArea(Uint8List rgba, int width, int height) {
  var left = width, top = height, right = 0, bottom = 0;
  for (var y = 0; y < height; y++) {
    var i = y * width * 4 + 3;
    for (var x = 0; x < width; x++, i += 4) {
      if (rgba[i] >= 250) continue;
      if (x < left) left = x;
      if (x >= right) right = x + 1;
      if (y < top) top = y;
      bottom = y + 1;
    }
  }
  return right == 0 ? null : (left: left, top: top, right: right, bottom: bottom);
}

/// [clearArea] off the UI thread.
Future<({int left, int top, int right, int bottom})?> clearAreaInIsolate(Uint8List rgba, int width, int height) =>
    Isolate.run(() => clearArea(rgba, width, height));
