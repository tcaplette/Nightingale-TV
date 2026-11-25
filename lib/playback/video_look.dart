import 'package:flutter/foundation.dart';

/// The CRT effects that change the video itself (retro-presentation D6): the
/// colour matrix (4×5, as [ColorFilter.matrix] takes it), curvature and glow
/// as the shader takes them. On Android's video layer the player applies them
/// (system-video-layer D5).
@immutable
class VideoLook {
  const VideoLook({this.matrix, this.curvature = 0, this.glow = 0, this.overlay = VideoOverlay.none});

  static const none = VideoLook();

  final List<double>? matrix;
  final double curvature;
  final double glow;

  /// With glow only: what the glow is worked out over, as the interface draws
  /// it over everything else ([VideoOverlay.none] without: the interface draws
  /// it over the video too).
  final VideoOverlay overlay;

  /// Whether it changes the video at all.
  bool get any => matrix != null || curvature > 0 || glow > 0;

  @override
  bool operator ==(Object other) =>
      other is VideoLook &&
      curvature == other.curvature &&
      glow == other.glow &&
      overlay == other.overlay &&
      listEquals(matrix, other.matrix);

  @override
  int get hashCode => Object.hash(curvature, glow, overlay, matrix == null ? null : Object.hashAll(matrix!));
}

/// Scanlines, mask and vignette: how dark each is (0 is off), and how many
/// scanlines. With any overlay, the tube's corners are rounded.
@immutable
class VideoOverlay {
  const VideoOverlay({this.on = true, this.scanlines = 0, this.lines = 480, this.mask = 0, this.vignette = 0});

  static const none = VideoOverlay(on: false);

  final bool on;
  final double scanlines;
  final int lines;
  final double mask;
  final double vignette;

  @override
  bool operator ==(Object other) =>
      other is VideoOverlay &&
      on == other.on &&
      scanlines == other.scanlines &&
      lines == other.lines &&
      mask == other.mask &&
      vignette == other.vignette;

  @override
  int get hashCode => Object.hash(on, scanlines, lines, mask, vignette);
}

/// The spacing of [lines] scanlines down a picture [height] device pixels
/// tall: a whole number of pixels so they stay crisp, doubling below 2
/// pixels per line to avoid moiré (retro-presentation D6).
int scanlinePeriod(double height, int lines) {
  var period = height / lines;
  while (period < 2) {
    period *= 2;
  }
  return period.round();
}

/// How many of a scanline's [period] pixels are dark, at its end.
int scanlineDark(int period) => (period / 2).ceil();

/// The radius of the tube's corners, over the frame's shorter side.
const tubeCorner = 0.035;

/// The vignette's circle over the frame's longer side, and where in it the
/// darkening starts.
const vignetteRadius = 0.62, vignetteStart = 0.55;
