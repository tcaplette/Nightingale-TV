import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../platform/platform_info.dart';

/// What YouTube's player reports (youtube-playback D8).
sealed class YouTubeEvent {
  const YouTubeEvent();
}

/// The IFrame API is loaded and the player made.
class YouTubeReady extends YouTubeEvent {
  const YouTubeReady();
}

/// The player's state: -1 unstarted, 0 ended, 1 playing, 2 paused,
/// 3 buffering, 5 cued.
class YouTubeState extends YouTubeEvent {
  const YouTubeState(this.state, this.videoId);
  final int state;
  final String? videoId;

  static const unstarted = -1, ended = 0, playing = 1, paused = 2, buffering = 3, cued = 5;
}

/// The player refused a video: 2 bad id, 5 HTML5 error, 100 gone or private,
/// 101 and 150 not allowed in embedded players, 153 the player not
/// identified.
class YouTubeError extends YouTubeEvent {
  const YouTubeError(this.code, this.videoId);
  final int code;
  final String? videoId;
}

/// Where the video is, once a second.
class YouTubePosition extends YouTubeEvent {
  const YouTubePosition(this.position, this.duration, this.state, this.videoId);
  final Duration position;
  final Duration duration;
  final int state;
  final String? videoId;
}

/// The WebView's renderer stopped; the player is made again on the next load.
class YouTubeCrashed extends YouTubeEvent {
  const YouTubeCrashed();
}

/// YouTube's player script didn't load (no network, or blocked).
class YouTubeApiFailed extends YouTubeEvent {
  const YouTubeApiFailed();
}

/// The device has no working Android System WebView.
class YouTubeNoWebView extends YouTubeEvent {
  const YouTubeNoWebView();
}

/// The app's one YouTube player (youtube-playback D8): a WebView that lives
/// for the app's life, over the app's window at [frame], never taking key
/// focus. On Linux a WebKitGTK view laid over the Flutter view, on Android
/// the system WebView over it; both driven over `ntv/youtube_view`.
class YouTubePlayer {
  YouTubePlayer._();

  bool _attached = false;

  /// Hears the platform's events from the first call that talks to it: a
  /// player nobody uses (tests, the server mode) never needs the binding.
  void _attach() {
    if (_attached) return;
    _attached = true;
    _channel.setMethodCallHandler(_onCall);
  }

  static final YouTubePlayer instance = YouTubePlayer._();

  /// Linux and Android have the player; the web admin and server mode never.
  static bool get supported => !kIsWeb && (PlatformInfo.isAndroid || PlatformInfo.isLinux);

  /// The base URL the page loads with, so the player's `Referer` and
  /// `origin` are the app's id on every flavour (D8).
  static const baseUrl = 'https://com.coffeehauslabs.nightingale_tv/';
  static const origin = 'https://com.coffeehauslabs.nightingale_tv';

  static const _channel = MethodChannel('ntv/youtube_view');

  final _events = StreamController<YouTubeEvent>.broadcast();
  Stream<YouTubeEvent> get events => _events.stream;

  /// Links the player opens (its logo, a title) are handed to this.
  void Function(String url)? onOpenUrl;

  String? _page;
  String? _loadedSettings;
  bool _ready = false;
  bool get ready => _ready;

  /// The video most recently loaded or cued, and whether it was loaded
  /// (plays) rather than cued.
  String? _videoId;
  bool _playing = false;
  String? get videoId => _videoId;

  /// The player page with [captions] (on by default, in [captionLanguage])
  /// and [volume] (0–100), loaded once and again only when they change.
  Future<void> ensurePage({bool captions = false, String? captionLanguage, int volume = 100}) async {
    if (!supported) return;
    final settings = jsonEncode({
      'origin': origin,
      'ccLoad': captions,
      'ccLang': ?captionLanguage,
      'volume': volume,
    });
    if (_loadedSettings == settings) return;
    _attach();
    _page ??= await rootBundle.loadString('assets/youtube/player.html');
    _loadedSettings = settings;
    _ready = false;
    final html = _page!.replaceFirst('/*NTV_SETTINGS*/{}', settings);
    final answer = await _channel.invokeMethod<Object?>('load', {'html': html, 'baseUrl': baseUrl});
    if (answer == 'noWebView') {
      _loadedSettings = null;
      _events.add(const YouTubeNoWebView());
    }
  }

  /// The latest load, cue or stop asked for before the page was ready; run
  /// once it is.
  String? _pending;

  Future<void> _run(String js, {bool command = false}) async {
    if (!supported) return;
    if (!_ready) {
      if (command) _pending = js;
      return;
    }
    await _channel.invokeMethod<void>('run', {'js': js});
  }

  static double _seconds(Duration d) => d.inMilliseconds / 1000;

  /// Plays [videoId] from [start]. Called only once the frame is laid out
  /// and more than half of it is on screen ([YouTubeFrame.mostlyVisible]).
  Future<void> load(String videoId, Duration start) {
    _videoId = videoId;
    _playing = true;
    return _run('ntvLoad(${jsonEncode(videoId)}, ${_seconds(start)})', command: true);
  }

  /// Readies [videoId] at [start] without playing it (a preloaded
  /// neighbour, D8): a cued video never plays on its own.
  Future<void> cue(String videoId, Duration start) {
    _videoId = videoId;
    _playing = false;
    return _run('ntvCue(${jsonEncode(videoId)}, ${_seconds(start)})', command: true);
  }

  /// Stops the video (hidden, Pause, background).
  Future<void> stop() {
    _playing = false;
    return _run('ntvStop()', command: true);
  }

  bool get playing => _playing;

  Future<void> seek(Duration to) => _run('ntvSeek(${_seconds(to)})');

  Future<void> setVolume(int volume) => _run('ntvVolume(${volume.clamp(0, 100)})');

  /// Throws the WebView away; the next [ensurePage] makes a new one.
  Future<void> recreate() async {
    _loadedSettings = null;
    _ready = false;
    _videoId = null;
    _playing = false;
    if (!supported) return;
    _attach();
    await _channel.invokeMethod<void>('recreate');
  }

  Rect? _frame;
  bool _shown = false;

  /// Places the player at [rect] (the Flutter view's logical pixels) and
  /// shows it, or hides it ([rect] null).
  Future<void> place(Rect? rect, {double devicePixelRatio = 1}) async {
    if (!supported) return;
    final shown = rect != null && !rect.isEmpty;
    if (shown == _shown && rect == _frame) return;
    _attach();
    _frame = rect;
    _shown = shown;
    // Android places the view in physical pixels; GTK in logical ones.
    final scale = PlatformInfo.isAndroid ? devicePixelRatio : 1.0;
    final r = rect ?? Rect.zero;
    await _channel.invokeMethod<void>('frame', {
      'x': (r.left * scale).round(),
      'y': (r.top * scale).round(),
      'w': (r.width * scale).round(),
      'h': (r.height * scale).round(),
      'visible': shown,
    });
  }

  bool get shown => _shown;

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'message':
        final event = _parse(call.arguments as String);
        if (event != null) _events.add(event);
      case 'crashed':
        _loadedSettings = null;
        _ready = false;
        _playing = false;
        _events.add(const YouTubeCrashed());
      case 'openUrl':
        final url = call.arguments as String;
        // The page itself and YouTube's frame never navigate away.
        if (url.startsWith(baseUrl) || url == 'about:blank') return null;
        onOpenUrl?.call(url);
    }
    return null;
  }

  YouTubeEvent? _parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
    final id = json['id'] as String?;
    switch (json['e']) {
      case 'ready':
        _ready = true;
        final pending = _pending;
        _pending = null;
        if (pending != null) unawaited(_run(pending));
        return const YouTubeReady();
      case 'state':
        return YouTubeState((json['s'] as num).toInt(), id);
      case 'error':
        return YouTubeError((json['c'] as num).toInt(), id);
      case 'pos':
        Duration d(Object? s) => Duration(milliseconds: (((s as num?) ?? 0) * 1000).round());
        return YouTubePosition(d(json['t']), d(json['d']), ((json['s'] as num?) ?? -1).toInt(), id);
      case 'apiFailed':
        return const YouTubeApiFailed();
    }
    return null;
  }
}

/// Everything of the app's shown where YouTube's picture could be
/// (youtube-playback D9): the banner, channel number, Up next, toasts, the
/// Paused chip, the sleep and still-watching prompts. The picture moves
/// into the largest 16:9 area they leave free; nothing is ever drawn over
/// it (the player lies over the app's window).
class YouTubeObstacles {
  YouTubeObstacles._();

  static final instance = YouTubeObstacles._();

  final _rects = <Object, Rect>{};

  /// Where each shown obstacle is, in the window's logical pixels.
  Iterable<Rect> get rects => _rects.values;

  void set(Object owner, Rect? rect) {
    if (rect == null || rect.isEmpty) {
      _rects.remove(owner);
    } else {
      _rects[owner] = rect;
    }
  }

  @visibleForTesting
  void clear() => _rects.clear();

  /// The largest 16:9 rectangle in [area] that none of [obstacles] overlaps:
  /// above, below or beside each of them (every way round them is tried).
  /// Centred in the room it has. Null when there's no room.
  static Rect? fit(Rect area, Iterable<Rect> obstacles) {
    final hits = [
      for (final o in obstacles)
        if (o.overlaps(area)) o.intersect(area)
    ];
    if (hits.length > 6) hits.removeRange(6, hits.length);
    Rect? best;
    var bestArea = 0.0;
    void tryRoom(Rect room) {
      if (room.width <= 0 || room.height <= 0) return;
      final w = room.width / room.height > 16 / 9 ? room.height * 16 / 9 : room.width;
      final h = w * 9 / 16;
      if (w * h <= bestArea) return;
      bestArea = w * h;
      best = Rect.fromCenter(center: room.center, width: w, height: h);
    }

    final count = hits.length;
    var combos = 1;
    for (var i = 0; i < count; i++) {
      combos *= 4;
    }
    for (var c = 0; c < combos; c++) {
      var room = area;
      var code = c;
      for (final o in hits) {
        final side = code % 4;
        code ~/= 4;
        room = switch (side) {
          0 => Rect.fromLTRB(room.left, room.top, room.right, room.bottom < o.top ? room.bottom : o.top),
          1 => Rect.fromLTRB(room.left, room.top > o.bottom ? room.top : o.bottom, room.right, room.bottom),
          2 => Rect.fromLTRB(room.left, room.top, room.right < o.left ? room.right : o.left, room.bottom),
          _ => Rect.fromLTRB(room.left > o.right ? room.left : o.right, room.top, room.right, room.bottom),
        };
        if (room.width <= 0 || room.height <= 0) break;
      }
      tryRoom(room);
    }
    return best;
  }
}

/// Reports where [child] is to [YouTubeObstacles] while it's shown, so the
/// YouTube picture keeps clear of it: after every frame, asking for one
/// more when it moved (so the picture follows at once), and gone with it.
class YouTubeObstacle extends StatefulWidget {
  const YouTubeObstacle({super.key, required this.child});

  final Widget child;

  @override
  State<YouTubeObstacle> createState() => _YouTubeObstacleState();
}

class _YouTubeObstacleState extends State<YouTubeObstacle> {
  Rect? _reported;
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  void _follow() {
    if (_waiting) return;
    _waiting = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _waiting = false;
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final rect = box != null && box.attached && box.hasSize
          ? MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size)
          : null;
      if (rect != _reported) {
        _reported = rect;
        YouTubeObstacles.instance.set(this, rect);
        SchedulerBinding.instance.scheduleFrame();
      }
      _follow();
    });
  }

  @override
  void dispose() {
    YouTubeObstacles.instance.set(this, null);
    SchedulerBinding.instance.scheduleFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Where YouTube's picture goes: an empty box the player is laid over, in
/// the largest 16:9 part of it that the app's overlays leave free, while
/// it's [active], its screen is the one in front and more than half of it
/// is visible (D9). Nothing of the app's is ever drawn over the player.
class YouTubeFrame extends StatefulWidget {
  const YouTubeFrame({super.key, required this.active, this.onVisible, this.minSize = Size.zero, this.grow = false});

  /// This frame owns the player now (the shown channel is a YouTube one).
  final bool active;

  /// Told whether the player is shown here with more than half its frame on
  /// screen, so a video may start (D9's autoplay rule).
  final ValueChanged<bool>? onVisible;

  /// Smaller than this (overlays leave too little room), the player isn't
  /// shown and stops. YouTube's own minimum, 200×200, always holds.
  final Size minSize;

  /// A box smaller than YouTube's minimum (the guide's preview on a TV): the
  /// player grows to it, centred on the box, rather than not showing.
  final bool grow;

  /// YouTube's smallest player, as 16:9.
  static const smallest = Size(356, 200);

  /// The frame that last placed the player; another frame placing it takes
  /// it over.
  static _YouTubeFrameState? _owner;

  @override
  State<YouTubeFrame> createState() => _YouTubeFrameState();
}

class _YouTubeFrameState extends State<YouTubeFrame> with WidgetsBindingObserver {
  bool _visible = false;
  bool _ticking = false;

  /// Where the player is, in this box's own coordinates: on Android the app
  /// draws on a surface above the window the WebView is in, so it leaves a
  /// clear hole there, as for the video layer.
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(YouTubeFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _schedule();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Another frame (the guide's preview) may have the player already.
    final owned = YouTubeFrame._owner == this || YouTubeFrame._owner == null;
    if (YouTubeFrame._owner == this) {
      YouTubeFrame._owner = null;
      unawaited(YouTubePlayer.instance.place(null));
    }
    if (_visible && owned) widget.onVisible?.call(false);
    super.dispose();
  }

  /// Follows the box every frame while active (it moves with the overlays'
  /// animation), and once more when it stops being active.
  void _schedule() {
    if (_ticking) return;
    _ticking = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _ticking = false;
      if (!mounted) return;
      _place();
      // Follows the frames that happen (an overlay moving asks for them);
      // a still picture costs no frames.
      if (widget.active) _schedule();
    });
  }

  void _place() {
    final box = context.findRenderObject() as RenderBox?;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    // Under Menu, Settings, a dialog or any other screen: not shown (D9).
    final inFront = ModalRoute.of(context)?.isCurrent ?? true;
    Rect? rect;
    var mostly = false;
    if (widget.active && foreground && inFront && box != null && box.hasSize && box.attached) {
      final area = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
      final view = View.of(context);
      final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
      var free = YouTubeObstacles.fit(area.intersect(screen), YouTubeObstacles.instance.rects);
      // Android lays the page out at least 640 CSS pixels wide (player.html), so
      // YouTube's player is never under its minimum there.
      if (widget.grow &&
          !PlatformInfo.isAndroid &&
          free != null &&
          (free.width < YouTubeFrame.smallest.width || free.height < 200)) {
        free = Rect.fromCenter(
            center: free.center, width: YouTubeFrame.smallest.width, height: YouTubeFrame.smallest.height);
      }
      final floor = PlatformInfo.isAndroid ? 100.0 : 200.0;
      final min = Size(widget.minSize.width < floor ? floor : widget.minSize.width,
          widget.minSize.height < floor ? floor : widget.minSize.height);
      if (free != null && free.width >= min.width - 0.5 && free.height >= min.height - 0.5) {
        rect = free;
        final whole = area.width * area.height;
        final seen = free.intersect(screen);
        mostly = whole > 0 && !seen.isEmpty && seen.width * seen.height / (free.width * free.height) > 0.5;
      }
    }
    if (mostly != _visible) {
      _visible = mostly;
      widget.onVisible?.call(mostly);
    }
    Rect? hole;
    if (rect != null && box != null && box.attached) {
      final topLeft = box.globalToLocal(rect.topLeft), bottomRight = box.globalToLocal(rect.bottomRight);
      hole = Rect.fromPoints(topLeft, bottomRight);
    }
    if (hole != _hole) setState(() => _hole = hole);
    // A frame that moved: one more frame, so the player follows at once.
    if (rect != YouTubePlayer.instance._frame || (rect == null) == YouTubePlayer.instance.shown) {
      SchedulerBinding.instance.scheduleFrame();
    }
    if (rect != null) {
      YouTubeFrame._owner = this;
      unawaited(YouTubePlayer.instance.place(rect, devicePixelRatio: View.of(context).devicePixelRatio));
    } else if (YouTubeFrame._owner == this || YouTubeFrame._owner == null) {
      YouTubeFrame._owner = null;
      unawaited(YouTubePlayer.instance.place(null));
    }
  }

  @override
  Widget build(BuildContext context) => _YouTubeHole(hole: PlatformInfo.isAndroid ? _hole : null);
}

/// Black, with a clear [hole] where Android's WebView shows through (as the
/// video layer's VideoHole). Everything under it on the canvas is cleared
/// with it, so it's never inside a layer of its own.
class _YouTubeHole extends LeafRenderObjectWidget {
  const _YouTubeHole({required this.hole});

  final Rect? hole;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderYouTubeHole(hole);

  @override
  void updateRenderObject(BuildContext context, _RenderYouTubeHole renderObject) => renderObject.hole = hole;
}

class _RenderYouTubeHole extends RenderBox {
  _RenderYouTubeHole(this._hole);

  Rect? _hole;
  set hole(Rect? v) {
    if (v == _hole) return;
    _hole = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  /// A picture of its own, so the clear is never cached in an image.
  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.setWillChangeHint();
    final box = offset & size;
    context.canvas.drawRect(box, Paint()..color = const Color(0xFF000000));
    final hole = _hole;
    if (hole != null) context.canvas.drawRect(hole.shift(offset), Paint()..blendMode = BlendMode.clear);
  }
}
