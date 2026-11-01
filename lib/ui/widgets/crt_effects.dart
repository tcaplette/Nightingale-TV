import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../channels/retro.dart';
import '../../playback/device_effects.dart';
import '../../playback/playback_diagnostics.dart';

/// The spacing of [lines] scanlines down a picture [height] device pixels
/// tall: a whole number of pixels so they stay crisp, doubling below 2
/// pixels per line to avoid moiré (design D6).
int scanlinePeriod(double height, int lines) {
  var period = height / lines;
  while (period < 2) {
    period *= 2;
  }
  return period.round();
}

/// The color matrix for [v], with a small gain to offset what its scanlines
/// and mask take away; null when it changes nothing.
List<double>? crtColorMatrix(CrtValues v) {
  final gain = 1 +
      switch (v.scanlines) {
        CrtLevel.off => 0.0,
        CrtLevel.low => 0.05,
        CrtLevel.medium => 0.12,
        CrtLevel.high => 0.22,
      } +
      switch (v.mask) {
        CrtLevel.off => 0.0,
        CrtLevel.low => 0.02,
        CrtLevel.medium => 0.04,
        CrtLevel.high => 0.07,
      };
  if (gain == 1 && v.color == CrtColor.natural) return null;
  final (saturation, red, blue, lift) = switch (v.color) {
    CrtColor.natural => (1.0, 1.0, 1.0, 0.0),
    CrtColor.warm => (1.0, 1.06, 0.9, 0.0),
    CrtColor.faded => (0.7, 1.0, 1.0, 8.0),
    CrtColor.vivid => (1.3, 1.0, 1.0, 0.0),
  };
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final s = saturation, t = 1 - s;
  return [
    (t * lr + s) * red * gain, t * lg * red * gain, t * lb * red * gain, 0, lift,
    t * lr * gain, (t * lg + s) * gain, t * lb * gain, 0, lift,
    t * lr * blue * gain, t * lg * blue * gain, (t * lb + s) * blue * gain, 0, lift,
    0, 0, 0, 1, 0,
  ];
}

/// Scanlines, mask, vignette and tube corners, recorded at [size] device
/// pixels.
ui.Picture paintCrtOverlay(Size size, CrtValues v) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  double by(CrtLevel level, double low, double medium, double high) => switch (level) {
        CrtLevel.off => 0,
        CrtLevel.low => low,
        CrtLevel.medium => medium,
        CrtLevel.high => high,
      };
  final lines = by(v.scanlines, 0.18, 0.32, 0.5);
  if (lines > 0) {
    final period = scanlinePeriod(size.height, v.lines);
    final dark = (period / 2).ceil();
    final paint = Paint()..color = Colors.black.withValues(alpha: lines);
    for (var y = period - dark; y < size.height; y += period) {
      canvas.drawRect(Rect.fromLTWH(0, y.toDouble(), size.width, dark.toDouble()), paint);
    }
  }
  final mask = by(v.mask, 0.06, 0.1, 0.16);
  if (mask > 0) {
    // An aperture grille: each column darkens, keeping a trace of one primary.
    final paints = [
      for (final color in const [Color(0xFF400000), Color(0xFF004000), Color(0xFF000040)])
        Paint()..color = color.withValues(alpha: mask),
    ];
    for (var x = 0; x < size.width; x++) {
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), 0, 1, size.height), paints[x % 3]);
    }
  }
  final vignette = by(v.vignette, 0.3, 0.5, 0.7);
  if (vignette > 0) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          size.longestSide * 0.62,
          [Colors.transparent, Colors.black.withValues(alpha: vignette)],
          const [0.55, 1],
        ),
    );
  }
  final corners = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.shortestSide * 0.035)));
  canvas.drawPath(corners, Paint()..color = Colors.black);
  return recorder.endRecording();
}

/// The shader tier's `shaders/crt.frag` on this device (design D6, D11).
class CrtShader {
  CrtShader._();

  static final instance = CrtShader._();

  /// Whether curvature and glow can be drawn here: null until found out.
  final available = ValueNotifier<bool?>(null);

  ui.FragmentProgram? _program;
  bool _flip = false;
  Future<void>? _loading;

  /// Finds out, once.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    if (!ui.ImageFilter.isShaderFilterSupported) {
      available.value = false;
      return;
    }
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/crt.frag');
      final flip = await _probeFlip(program);
      if (flip != null) {
        _program = program;
        _flip = flip;
      }
      PlaybackDiagnostics.note('RETRO', 'shader tier ${flip == null ? 'unavailable (probe)' : 'ready flip=$flip'}');
      available.value = flip != null;
    } on Object catch (e) {
      PlaybackDiagnostics.note('RETRO', 'shader tier unavailable: $e');
      available.value = false;
    }
  }

  /// Whether the filter sees its input upside down: a red-over-blue picture
  /// through the plain filter, read back (backends differ, D11). Null when
  /// it reads neither.
  static Future<bool?> _probeFlip(ui.FragmentProgram program) async {
    const size = 16;
    final shader = program.fragmentShader()
      ..setFloat(2, 0)
      ..setFloat(3, 0)
      ..setFloat(4, 0)
      ..setFloat(5, size / 2)
      ..setFloat(6, size / 2)
      ..setFloat(7, size / 2)
      ..setFloat(8, size / 2);
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(const Rect.fromLTWH(0, 0, 16, 8), Paint()..color = const Color(0xFFFF0000))
      ..drawRect(const Rect.fromLTWH(0, 8, 16, 8), Paint()..color = const Color(0xFF0000FF));
    final builder = ui.SceneBuilder()
      ..addPicture(Offset.zero, recorder.endRecording())
      ..pushBackdropFilter(ui.ImageFilter.shader(shader))
      ..pop();
    final scene = builder.build();
    final image = await scene.toImage(size, size);
    scene.dispose();
    final bytes = await image.toByteData();
    image.dispose();
    if (bytes == null) return null;
    final at = (2 * size + 8) * 4;
    final red = bytes.getUint8(at), blue = bytes.getUint8(at + 2);
    if (red > 200 && blue < 50) return false;
    if (red < 50 && blue > 200) return true;
    return null;
  }

  /// The filter for [v]'s curvature and glow on a frame at [frame] on a
  /// screen [screenHeight] tall, in device pixels, once [available].
  ui.ImageFilter? filterFor(CrtValues v, Rect frame, double screenHeight) {
    final program = _program;
    if (program == null) return null;
    final shader = program.fragmentShader()
      ..setFloat(2, switch (v.curvature) {
        CrtLevel.off => 0,
        CrtLevel.low => 0.025,
        CrtLevel.medium => 0.05,
        CrtLevel.high => 0.09,
      })
      ..setFloat(3, switch (v.glow) {
        CrtLevel.off => 0,
        CrtLevel.low => 0.3,
        CrtLevel.medium => 0.6,
        CrtLevel.high => 1,
      })
      ..setFloat(4, _flip ? 1 : 0)
      ..setFloat(5, frame.center.dx)
      // Where the input is upside down, so are the shader's coordinates.
      ..setFloat(6, _flip ? screenHeight - frame.center.dy : frame.center.dy)
      ..setFloat(7, frame.width / 2)
      ..setFloat(8, frame.height / 2);
    return ui.ImageFilter.shader(shader);
  }
}

/// What's drawn on this device of [v]: all of it off with the device switch,
/// and curvature and glow off where they can't be drawn or couldn't keep up.
CrtValues effectiveCrt(CrtValues v, {required bool switchOn, required bool shaderAvailable}) {
  if (!switchOn) return const CrtValues();
  if (shaderAvailable) return v;
  return v.copyWith(curvature: CrtLevel.off, glow: CrtLevel.off);
}

/// [child] under the CRT effect of [values]. A channel on no effect costs
/// nothing here: no layer, image or shader.
class CrtLayers extends StatefulWidget {
  const CrtLayers({super.key, required this.values, required this.child});

  final CrtValues values;
  final Widget child;

  @override
  State<CrtLayers> createState() => _CrtLayersState();
}

class _CrtLayersState extends State<CrtLayers> {
  final _changes = Listenable.merge([DeviceEffects.instance, CrtShader.instance.available]);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CrtLayers old) {
    super.didUpdateWidget(old);
    _load();
  }

  void _load() {
    if (widget.values.usesShader) unawaited(CrtShader.instance.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _changes,
      child: widget.child,
      builder: (context, child) {
        final device = DeviceEffects.instance;
        final v = effectiveCrt(widget.values,
            switchOn: device.on,
            shaderAvailable: CrtShader.instance.available.value == true && !device.shaderTurnedOff);
        final matrix = crtColorMatrix(v);
        final overlay = v.scanlines != CrtLevel.off || v.mask != CrtLevel.off || v.vignette != CrtLevel.off;
        return Stack(
          fit: StackFit.expand,
          children: [
            _ColorFilterBox(matrix: matrix, child: child!),
            if (overlay) _CrtOverlay(values: v),
            if (v.usesShader) _CrtShaderLayer(values: v),
          ],
        );
      },
    );
  }
}

/// [child] through a color matrix, with no layer at all when there's none,
/// and the same place in the tree either way.
class _ColorFilterBox extends SingleChildRenderObjectWidget {
  const _ColorFilterBox({required this.matrix, required super.child});

  final List<double>? matrix;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderColorFilterBox(matrix);

  @override
  void updateRenderObject(BuildContext context, _RenderColorFilterBox renderObject) {
    renderObject.matrix = matrix;
  }
}

class _RenderColorFilterBox extends RenderProxyBox {
  _RenderColorFilterBox(this._matrix);

  List<double>? _matrix;

  set matrix(List<double>? value) {
    if (listEquals(value, _matrix)) return;
    final composited = (value == null) != (_matrix == null);
    _matrix = value;
    if (composited) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _matrix != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final matrix = _matrix;
    if (matrix == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushColorFilter(offset, ColorFilter.matrix(matrix), super.paint,
        oldLayer: layer as ColorFilterLayer?);
  }
}

/// The overlay tier: [paintCrtOverlay] as one image at the size this takes
/// up on the screen, repainted only when that or [values] changes.
class _CrtOverlay extends StatefulWidget {
  const _CrtOverlay({required this.values});

  final CrtValues values;

  @override
  State<_CrtOverlay> createState() => _CrtOverlayState();
}

class _CrtOverlayState extends State<_CrtOverlay> {
  ui.Image? _image;
  Size? _size;
  CrtValues? _values;
  var _generation = 0;

  /// A page transition moves and scales this without building it, so a size
  /// taken during one is checked again.
  late final _recheck = Timer.periodic(const Duration(milliseconds: 500), (_) => _measure(Duration.zero));

  @override
  void initState() {
    super.initState();
    _recheck;
  }

  @override
  void dispose() {
    _recheck.cancel();
    _generation++;
    _image?.dispose();
    super.dispose();
  }

  /// The real device pixels: the app's canvas is scaled, so this can't come
  /// from the layout size and the pixel ratio (D11).
  void _measure(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & Size.zero;
    final end = box.localToGlobal(box.size.bottomRight(Offset.zero));
    final ratio = View.of(context).devicePixelRatio;
    final size = Size(((end.dx - rect.left) * ratio).roundToDouble(), ((end.dy - rect.top) * ratio).roundToDouble());
    if (size.isEmpty || (size == _size && widget.values == _values)) return;
    _size = size;
    _values = widget.values;
    final generation = ++_generation;
    unawaited(() async {
      final picture = paintCrtOverlay(size, widget.values);
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      picture.dispose();
      if (!mounted || generation != _generation) {
        image.dispose();
        return;
      }
      final old = _image;
      setState(() => _image = image);
      old?.dispose();
    }());
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: RawImage(image: _image, fit: BoxFit.fill, filterQuality: FilterQuality.none),
        ),
      ),
    );
  }
}

/// Watches frame times while the shader tier is on (D8, D11): a second is
/// over budget when its median raster time is, and [seconds] of those in a
/// row mean the device can't keep up. The median keeps isolated spikes from
/// counting.
class FrameBudgetWatcher {
  FrameBudgetWatcher({required this.budget, this.seconds = 10});

  final Duration budget;
  final int seconds;

  final _times = <int>[];
  int _streak = 0;

  void addFrame(Duration raster) => _times.add(raster.inMicroseconds);

  /// Ends a second; true once the device has been over for [seconds] of them.
  bool endSecond() {
    if (_times.isEmpty) {
      _streak = 0;
      return false;
    }
    _times.sort();
    final median = _times[_times.length ~/ 2];
    _times.clear();
    _streak = median > budget.inMicroseconds ? _streak + 1 : 0;
    return _streak >= seconds;
  }
}

/// The shader tier: curvature and glow on everything below it in the frame.
class _CrtShaderLayer extends StatefulWidget {
  const _CrtShaderLayer({required this.values});

  /// A diagnostics build's forced slow frames (task 8.4).
  static const _forceSlow = bool.fromEnvironment('NIGHTINGALE_TV_FORCE_SLOW_FRAMES');

  final CrtValues values;

  @override
  State<_CrtShaderLayer> createState() => _CrtShaderLayerState();
}

class _CrtShaderLayerState extends State<_CrtShaderLayer> {
  FrameBudgetWatcher? _watcher;
  Timer? _sample, _second;
  ui.ImageFilter? _filter;
  Rect? _frame;
  CrtValues? _values;

  /// The filter needs where this is on the screen, in real device pixels.
  void _measure(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final view = View.of(context);
    final ratio = view.devicePixelRatio;
    final frame = Rect.fromPoints(box.localToGlobal(Offset.zero) * ratio,
        box.localToGlobal(box.size.bottomRight(Offset.zero)) * ratio);
    if (frame.isEmpty) return;
    if (frame == _frame && widget.values == _values) return;
    _frame = frame;
    _values = widget.values;
    setState(() => _filter = CrtShader.instance.filterFor(widget.values, frame, view.physicalSize.height));
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // Some embedders re-draw for video frames without reporting timings, so
    // this asks for a few frames that do report (D11).
    // Also checks where it is: a page transition moves this without building it.
    _sample = Timer.periodic(const Duration(milliseconds: 250), (_) {
      SchedulerBinding.instance.scheduleFrame();
      _measure(Duration.zero);
    });
    _second = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_watcher?.endSecond() ?? false) {
        PlaybackDiagnostics.note('RETRO', 'shader tier turned off: over frame budget');
        DeviceEffects.instance.turnOffShader();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rate = View.of(context).display.refreshRate;
    _watcher ??= FrameBudgetWatcher(
      budget: _CrtShaderLayer._forceSlow
          ? Duration.zero
          : Duration(microseconds: (Duration.microsecondsPerSecond / (rate > 0 ? rate : 60)).round()),
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _watcher?.addFrame(t.rasterDuration);
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _sample?.cancel();
    _second?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final filter = _filter;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: filter == null
            ? const SizedBox.expand()
            : ClipRect(child: BackdropFilter(filter: filter, child: const SizedBox.expand())),
      ),
    );
  }
}
