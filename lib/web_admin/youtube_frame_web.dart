import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import 'youtube_frame.dart';

@JS('document.createElement')
external _Element _create(String tag);

@JS('document.head.appendChild')
external void _appendToHead(_Element e);

@JS('document.visibilityState')
external String get _visibilityState;

@JS('document.addEventListener')
external void _addDocumentListener(String type, JSFunction listener);

@JS('document.removeEventListener')
external void _removeDocumentListener(String type, JSFunction listener);

@JS('window.location.origin')
external String get _origin;

@JS('YT')
external JSObject? get _yt;

extension type _Element(JSObject _) implements JSObject {
  external set id(String v);
  external set src(String v);
  external _Style get style;
  external void appendChild(_Element child);
  external bool get isConnected;
}

extension type _Style(JSObject _) implements JSObject {
  external set cssText(String v);
}

@JS('YT.Player')
extension type _Player._(JSObject _) implements JSObject {
  external factory _Player(_Element element, JSObject options);
  external void loadVideoById(JSObject options);
  external void pauseVideo();
  external void stopVideo();
  external void destroy();
}

/// The IFrame Player API, loaded once from youtube.com.
Future<void>? _api;

Future<void> _loadApi() => _api ??= () {
      if (_yt?.has('Player') == true) return Future<void>.value();
      final ready = Completer<void>();
      globalContext['onYouTubeIframeAPIReady'] = (() {
        if (!ready.isCompleted) ready.complete();
      }).toJS;
      final script = _create('script')..src = 'https://www.youtube.com/iframe_api';
      _appendToHead(script);
      return ready.future;
    }();

int _views = 0;

YouTubeFrame createFrame() => _WebFrame();

class _WebFrame extends YouTubeFrame {
  _WebFrame() {
    _viewType = 'ntv-youtube-${_views++}';
    _box = _create('div')..style.cssText = 'width:100%;height:100%;background:#000';
    final slot = _create('div')..style.cssText = 'width:100%;height:100%';
    _box.appendChild(slot);
    _slot = slot;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _box);
    _visibility = (() => _hidden.add(hidden)).toJS;
    _addDocumentListener('visibilitychange', _visibility);
    _keydown = ((JSObject e) {
      if ((e['key'] as JSString?)?.toDart == 'Escape') _escapes.add(null);
    }).toJS;
    _addDocumentListener('keydown', _keydown);
  }

  late final String _viewType;
  late final _Element _box;
  late final _Element _slot;
  late final JSFunction _visibility;
  late final JSFunction _keydown;
  final _escapes = StreamController<void>.broadcast();
  final _events = StreamController<YouTubeFrameEvent>.broadcast();
  final _hidden = StreamController<bool>.broadcast();
  _Player? _player;
  Future<_Player>? _making;
  String? _videoId;
  bool _disposed = false;

  @override
  Widget view() => HtmlElementView(viewType: _viewType);

  @override
  Stream<YouTubeFrameEvent> get events => _events.stream;

  @override
  Stream<bool> get hiddenChanges => _hidden.stream;

  @override
  Stream<void> get escapes => _escapes.stream;

  @override
  bool get hidden => _visibilityState == 'hidden';

  /// The player, made in the frame once it's in the page.
  Future<_Player> _playerFor(String videoId, Duration start) => _making ??= () async {
        await _loadApi();
        for (var i = 0; i < 200 && !_box.isConnected; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        final vars = JSObject()
          ..['autoplay'] = 1.toJS
          ..['playsinline'] = 1.toJS
          ..['enablejsapi'] = 1.toJS
          ..['rel'] = 0.toJS
          ..['start'] = start.inSeconds.toJS
          ..['origin'] = _origin.toJS;
        final handlers = JSObject()
          ..['onStateChange'] = ((JSObject e) {
            final state = (e['data'] as JSNumber?)?.toDartInt;
            final id = _videoId;
            if (id == null) return;
            if (state == 0) _events.add(YouTubeFrameEnded(id));
            if (state == 1) _events.add(YouTubeFramePlaying(id));
          }).toJS
          ..['onError'] = ((JSObject e) {
            _events.add(YouTubeFrameError((e['data'] as JSNumber?)?.toDartInt ?? 0, _videoId));
          }).toJS;
        final options = JSObject()
          ..['width'] = '100%'.toJS
          ..['height'] = '100%'.toJS
          ..['videoId'] = videoId.toJS
          ..['playerVars'] = vars
          ..['events'] = handlers;
        return _player = _Player(_slot, options);
      }();

  @override
  Future<void> load(String videoId, Duration start) async {
    if (_disposed) return;
    final first = _making == null;
    _videoId = videoId;
    final player = await _playerFor(videoId, start);
    if (first || _disposed) return;
    player.loadVideoById(JSObject()
      ..['videoId'] = videoId.toJS
      ..['startSeconds'] = start.inSeconds.toJS);
  }

  @override
  void pause() => _player?.pauseVideo();

  @override
  void dispose() {
    _disposed = true;
    _removeDocumentListener('visibilitychange', _visibility);
    _removeDocumentListener('keydown', _keydown);
    try {
      _player?.stopVideo();
      _player?.destroy();
    } on Object {
      // Already gone with the page.
    }
    _player = null;
    unawaited(_events.close());
    unawaited(_hidden.close());
    unawaited(_escapes.close());
  }
}
