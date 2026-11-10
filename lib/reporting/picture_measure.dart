import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

/// The one measurement every picture in a video report gets (video-report,
/// design D2): the texture render, the screen capture, each self-test render
/// and the CPU decode. Ported line for line to Python in
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

  /// The screen matches the texture when this share of cells match
  /// (overlays such as the logo bug and the clock cover a few).
  static const screenShare = 0.8;

  /// ...and keeps at least this share of the texture's detail, both seen
  /// at [coarseWidth]×[coarseHeight] (a blurred screen can keep its colours).
  static const screenDetailShare = 0.6;

  /// The common scale screen and texture detail are compared at, so a
  /// texture scaled to the screen isn't taken for a blur.
  static const coarseWidth = 480, coarseHeight = 270;

  final List<String> grid;
  final double detail;

  factory PictureMeasure.fromJson(Map<Object?, Object?> json) => PictureMeasure(
      [for (final c in json['grid'] as List) '$c'], (json['detail'] as num).toDouble());

  Map<String, Object> toJson() => {'grid': grid, 'detail': (detail * 1000).round() / 1000};

  /// All black, with no detail: an engine that can't snapshot the texture,
  /// not a broken buffer (design D3).
  bool get renderEmpty => detail < 0.05 && grid.every((c) => _channels(c).every((v) => v <= 2));

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

/// [expected] as a GPU shows it when it converts the card's BT.709 video
/// with the BT.601 matrix instead (the Android emulator does): each cell's
/// colour encoded as BT.709 limited range and decoded as BT.601.
PictureMeasure asBt601(PictureMeasure expected) {
  String cell(String hex) {
    final c = PictureMeasure._channels(hex).map((v) => v / 255).toList();
    final y = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    final cb = (c[2] - y) / 1.8556, cr = (c[0] - y) / 1.5748;
    final r = y + 1.402 * cr, b = y + 1.772 * cb;
    final g = (y - 0.299 * r - 0.114 * b) / 0.587;
    return [r, g, b].map((v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')).join();
  }

  return PictureMeasure([for (final h in expected.grid) cell(h)], expected.detail);
}

/// Which colour matrix a texture run's colours fit (design D5): `bt709`
/// (right), `bt601` (the GPU ignores the video's colour standard), or
/// `neither` (the buffer itself is read wrongly).
String matrixFit(PictureMeasure measured, PictureMeasure expected) {
  bool fits(PictureMeasure e) {
    final d = measured.cellDifferences(e);
    return d.length == e.grid.length && d.every((v) => v <= PictureMeasure.tolerance);
  }

  if (fits(expected)) return 'bt709';
  if (fits(asBt601(expected))) return 'bt601';
  return 'neither';
}

/// The screen's video area against the texture (design D4): the share of
/// cells within [PictureMeasure.tolerance].
double screenShare(PictureMeasure screen, PictureMeasure texture) {
  final diffs = screen.cellDifferences(texture);
  if (diffs.isEmpty) return 0;
  return diffs.where((d) => d <= PictureMeasure.tolerance).length / diffs.length;
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

/// The detail figure of the sub-rectangle of [rgba] after box-averaging it
/// down to at most [PictureMeasure.coarseWidth]×[PictureMeasure.coarseHeight]
/// (design D4).
double coarseDetail(Uint8List rgba, int width, int height, {int left = 0, int top = 0, int? w, int? h}) {
  final rw = w ?? width - left, rh = h ?? height - top;
  final ow = min(PictureMeasure.coarseWidth, rw), oh = min(PictureMeasure.coarseHeight, rh);
  final small = Float64List(ow * oh);
  for (var oy = 0; oy < oh; oy++) {
    final y0 = top + oy * rh ~/ oh, y1 = top + max(oy * rh ~/ oh + 1, (oy + 1) * rh ~/ oh);
    for (var ox = 0; ox < ow; ox++) {
      final x0 = left + ox * rw ~/ ow, x1 = left + max(ox * rw ~/ ow + 1, (ox + 1) * rw ~/ ow);
      var sum = 0, n = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * width + x) * 4;
          sum += _luma(rgba[i], rgba[i + 1], rgba[i + 2]);
          n++;
        }
      }
      small[oy * ow + ox] = sum / n;
    }
  }
  var diffs = 0.0;
  for (var y = 0; y < oh; y++) {
    for (var x = 0; x < ow; x++) {
      final v = small[y * ow + x];
      if (x > 0) diffs += (v - small[y * ow + x - 1]).abs();
      if (y > 0) diffs += (v - small[(y - 1) * ow + x]).abs();
    }
  }
  final pairs = (ow - 1) * oh + ow * (oh - 1);
  return pairs > 0 ? diffs / pairs : 0;
}

/// [coarseDetail] off the UI thread.
Future<double> coarseDetailInIsolate(Uint8List rgba, int width, int height, {int left = 0, int top = 0, int? w, int? h}) =>
    Isolate.run(() => coarseDetail(rgba, width, height, left: left, top: top, w: w, h: h));

/// [measureRgba] off the UI thread.
Future<PictureMeasure> measureInIsolate(Uint8List rgba, int width, int height,
        {int left = 0, int top = 0, int? w, int? h}) =>
    Isolate.run(() => measureRgba(rgba, width, height, left: left, top: top, w: w, h: h));

/// The Shield photo's signature (design D13), for the debug fault and the
/// tests: the luma shrunk to 32×18 and stretched back bilinearly, under a
/// smooth four-corner wash (blue, red, green, yellow) that follows screen
/// position, not the picture.
Uint8List smearPicture(Uint8List rgba, int width, int height) {
  const sw = 32, sh = 18;
  final small = Float64List(sw * sh);
  for (var sy = 0; sy < sh; sy++) {
    final y0 = sy * height ~/ sh, y1 = max(y0 + 1, (sy + 1) * height ~/ sh);
    for (var sx = 0; sx < sw; sx++) {
      final x0 = sx * width ~/ sw, x1 = max(x0 + 1, (sx + 1) * width ~/ sw);
      var sum = 0, n = 0;
      for (var y = y0; y < y1 && y < height; y++) {
        for (var x = x0; x < x1 && x < width; x++) {
          final i = (y * width + x) * 4;
          sum += _luma(rgba[i], rgba[i + 1], rgba[i + 2]);
          n++;
        }
      }
      small[sy * sw + sx] = n == 0 ? 0 : sum / n;
    }
  }
  const corners = [
    [40.0, 80.0, 230.0], // top left: blue
    [230.0, 50.0, 50.0], // top right: red
    [50.0, 210.0, 70.0], // bottom left: green
    [235.0, 220.0, 40.0], // bottom right: yellow
  ];
  final out = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    final fy = ((y + 0.5) * sh / height - 0.5).clamp(0.0, sh - 1.0);
    final y0 = fy.floor(), y1 = min(y0 + 1, sh - 1), ty = fy - y0;
    final v = height > 1 ? y / (height - 1) : 0.0;
    for (var x = 0; x < width; x++) {
      final fx = ((x + 0.5) * sw / width - 0.5).clamp(0.0, sw - 1.0);
      final x0 = fx.floor(), x1 = min(x0 + 1, sw - 1), tx = fx - x0;
      final l = (small[y0 * sw + x0] * (1 - tx) + small[y0 * sw + x1] * tx) * (1 - ty) +
          (small[y1 * sw + x0] * (1 - tx) + small[y1 * sw + x1] * tx) * ty;
      final u = width > 1 ? x / (width - 1) : 0.0;
      final i = (y * width + x) * 4;
      for (var c = 0; c < 3; c++) {
        final wash = (corners[0][c] * (1 - u) + corners[1][c] * u) * (1 - v) +
            (corners[2][c] * (1 - u) + corners[3][c] * u) * v;
        out[i + c] = (l + (wash - 128) * 0.6).round().clamp(0, 255);
      }
      out[i + 3] = 255;
    }
  }
  return out;
}
