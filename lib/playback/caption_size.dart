/// The caption sizes (caption-size spec), in pixels on the 1920×1080 canvas.
/// Medium is the default, and the size image captions were authored at.
enum CaptionSize {
  small(40, 'Small'),
  medium(54, 'Medium'),
  large(68, 'Large'),
  extraLarge(84, 'Extra large');

  const CaptionSize(this.px, this.label);

  /// The font size on the canvas.
  final double px;

  final String label;

  /// This size against Medium: how much an image caption grows.
  double get ratio => px / medium.px;

  /// The name it's saved by, or null for anything else.
  static CaptionSize? fromName(Object? name) => values.where((s) => s.name == name).firstOrNull;

  /// The size nearest the system's caption font scale (1.0 is the system's
  /// normal size, so it's read against Medium); Medium when there's no
  /// usable scale.
  static CaptionSize nearestToScale(double? scale) {
    if (scale == null || !scale.isFinite || scale <= 0) return medium;
    var best = medium;
    for (final s in values) {
      if ((s.ratio - scale).abs() < (best.ratio - scale).abs()) best = s;
    }
    return best;
  }
}
