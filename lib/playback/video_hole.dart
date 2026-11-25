import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Where Android's video layer shows through (system-video-layer D3): clear
/// where the picture goes, black around it. Everything under it on the canvas
/// is cleared with it, so it must not be inside a layer of its own (an
/// opacity, a colour filter): that would be cleared instead, and show black.
class VideoHole extends LeafRenderObjectWidget {
  const VideoHole({super.key, required this.video, required this.fit, required this.open, required this.holes});

  /// The video's display size, once known.
  final Size? video;

  /// Contain, or cover (the 4:3 shape that fills its frame).
  final BoxFit fit;

  /// Whether there's a picture to show; black until then.
  final bool open;

  /// The player's holes, newest last, which this one joins while it's built.
  final VideoHoles holes;

  @override
  RenderVideoHole createRenderObject(BuildContext context) =>
      RenderVideoHole(video, fit, open, holes, View.of(context).devicePixelRatio);

  @override
  void updateRenderObject(BuildContext context, RenderVideoHole renderObject) {
    renderObject
      ..video = video
      ..fit = fit
      ..open = open
      ..devicePixelRatio = View.of(context).devicePixelRatio;
  }
}

class RenderVideoHole extends RenderBox {
  RenderVideoHole(this._video, this._fit, this._open, this._holes, this.devicePixelRatio);

  final VideoHoles _holes;
  double devicePixelRatio;

  Size? _video;
  set video(Size? v) {
    if (v == _video) return;
    _video = v;
    markNeedsPaint();
  }

  BoxFit _fit;
  set fit(BoxFit v) {
    if (v == _fit) return;
    _fit = v;
    markNeedsPaint();
  }

  bool _open;
  bool get open => _open;
  set open(bool v) {
    if (v == _open) return;
    _open = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  /// A picture of its own, so Skia never caches the clear in an image, where
  /// it would clear only that image.
  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _holes._add(this);
  }

  @override
  void detach() {
    _holes._remove(this);
    super.detach();
  }

  /// The whole picture, in this box: larger than it when it's cropped.
  Rect? get picture {
    final video = _video;
    if (video == null || video.isEmpty || !hasSize || size.isEmpty) return null;
    final x = size.width / video.width, y = size.height / video.height;
    return Alignment.center.inscribe(video * (_fit == BoxFit.cover ? max(x, y) : min(x, y)), Offset.zero & size);
  }

  /// [rect] of this box, on the screen in device pixels.
  Rect _onScreen(Rect rect) {
    final r = MatrixUtils.transformRect(getTransformTo(null), rect);
    return Rect.fromLTRB(r.left * devicePixelRatio, r.top * devicePixelRatio, r.right * devicePixelRatio,
        r.bottom * devicePixelRatio);
  }

  /// The whole picture on the screen, in device pixels; null when there's
  /// none or it isn't on the screen.
  Rect? get pictureOnScreen {
    final p = picture;
    if (p == null || !attached) return null;
    final r = _onScreen(p);
    return r.width >= 1 && r.height >= 1 && r.isFinite ? r : null;
  }

  /// This box on the screen, in device pixels: the picture's frame.
  Rect? get boxOnScreen => attached && hasSize ? _onScreen(Offset.zero & size) : null;

  /// The part of the picture inside this box, in device pixels.
  Rect? get shownOnScreen {
    final p = picture;
    return p == null || !attached ? null : _onScreen(p.intersect(Offset.zero & size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.setWillChangeHint();
    final box = offset & size;
    context.canvas.drawRect(box, Paint()..color = Colors.black);
    final p = picture;
    if (!_open || p == null) return;
    context.canvas.drawRect(p.shift(offset).intersect(box), Paint()..blendMode = BlendMode.clear);
  }
}

/// A player's holes: where its video layer goes is the newest one that is on
/// the screen. [onPlace] hears of it and of its picture's place when they
/// changed, in device pixels, and says whether it took it (it's told again
/// after the next frame otherwise); with none on the screen the layer stays
/// where it is, covered.
///
/// It hears after the frame that changed them, but the layer moves at once and
/// that frame has still to be drawn. Moved into a smaller place (the guide's
/// preview), the layer would leave the old frame's hole black, so it waits
/// until the frame is drawn: two frames later, as Flutter starts no third
/// frame with one still waiting to be drawn.
class VideoHoles {
  VideoHoles(this.onPlace);

  final bool Function(RenderVideoHole hole, Rect picture) onPlace;

  final _holes = <RenderVideoHole>[];
  Rect? _placed, _box;

  /// The place waited for, and the frames still to go.
  Rect? _waitingFor;
  int _wait = 0;
  bool _following = false;

  /// The newest hole on the screen.
  RenderVideoHole? get current {
    for (final hole in _holes.reversed) {
      if (hole.pictureOnScreen != null) return hole;
    }
    return null;
  }

  void _add(RenderVideoHole hole) {
    _holes.add(hole);
    if (_following) return;
    _following = true;
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
  }

  void _remove(RenderVideoHole hole) => _holes.remove(hole);

  /// Again after every frame while there's a hole: a scroll or a page moving
  /// it doesn't paint it.
  void _afterFrame(Duration _) {
    _following = _holes.isNotEmpty;
    if (!_following) return;
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
    final hole = current;
    final at = hole?.pictureOnScreen, box = hole?.boxOnScreen;
    if (hole == null || at == null || box == null || (at == _placed && box == _box)) return;
    if (at != _waitingFor) {
      _waitingFor = at;
      final old = _box;
      _wait = old != null && old != box && _holds(old, box) ? 2 : 0;
    } else if (_wait > 0) {
      _wait--;
    }
    if (_wait > 0) {
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    if (!onPlace(hole, at)) return;
    _placed = at;
    _box = box;
    _waitingFor = null;
  }

  static bool _holds(Rect outer, Rect inner) =>
      inner.left >= outer.left - 1 &&
      inner.top >= outer.top - 1 &&
      inner.right <= outer.right + 1 &&
      inner.bottom <= outer.bottom + 1;

  /// Says the place again after the next frame, which is asked for: there's
  /// now a layer to place.
  void placeAgain() {
    _placed = null;
    WidgetsBinding.instance.scheduleFrame();
  }
}
