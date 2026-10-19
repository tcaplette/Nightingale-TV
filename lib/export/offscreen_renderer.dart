import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/tv_theme.dart';

/// Draws a widget into a PNG without putting it on screen: the TV's cards
/// and logos for Live TV export streams and guides.
///
/// The widget must paint everything on its first frame (no images still
/// loading): decode images first and pass them in as [RawImage]s.
abstract final class OffscreenRenderer {
  /// [child] laid out on a [logicalSize] canvas (the TV's 1920×1080 for
  /// cards), drawn at [pixelRatio] (720 / 1080 for a 720p card), with the
  /// TV's theme and fonts.
  static Future<ui.Image> render(Widget child, {required Size logicalSize, double pixelRatio = 1}) async {
    final view = ui.PlatformDispatcher.instance.implicitView ?? ui.PlatformDispatcher.instance.views.first;
    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logicalSize),
        physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
        devicePixelRatio: pixelRatio,
      ),
      child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final build = BuildOwner(focusManager: FocusManager());
    try {
      final root = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: MediaQuery(
          data: MediaQueryData(size: logicalSize, devicePixelRatio: pixelRatio),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Theme(
              data: GuideTheme.cableGuide.toThemeData(),
              child: Material(type: MaterialType.transparency, child: SizedBox.fromSize(size: logicalSize, child: child)),
            ),
          ),
        ),
      ).attachToRenderTree(build);
      build
        ..buildScope(root)
        ..finalizeTree();
      pipeline
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
      return await boundary.toImage(pixelRatio: pixelRatio);
    } finally {
      build.finalizeTree();
      renderView.child = null;
    }
  }

  /// [render], as PNG bytes.
  static Future<Uint8List> renderPng(Widget child, {required Size logicalSize, double pixelRatio = 1}) async {
    final image = await render(child, logicalSize: logicalSize, pixelRatio: pixelRatio);
    try {
      return await pngOf(image);
    } finally {
      image.dispose();
    }
  }

  static Future<Uint8List> pngOf(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Decodes [bytes] (any format Flutter reads) for a [RawImage].
  static Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
