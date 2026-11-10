import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../app_version.dart';
import '../data/app_storage.dart';
import '../platform/platform_info.dart';
import '../playback/playback_diagnostics.dart';
import 'error_reports.dart';
import 'picture_measure.dart';
import 'report_switch.dart';

/// Video reports (video-report): one GlitchTip event that holds what's
/// needed to find where a picture goes wrong on a device we don't have.
/// Android only. A report is armed (once per app version, or by the Error
/// reports screen's button) and taken once the channel's picture has been on
/// screen for 10 seconds (design D1).
class VideoReports extends ChangeNotifier {
  VideoReports._();

  static final instance = VideoReports._();

  /// Device-only: beside `error_reports.json`, not in profiles or backups.
  static const file = 'video_report.json';

  /// The button arms at most one report this often.
  static const buttonInterval = Duration(minutes: 1);

  /// Events are kept under this (design D10).
  static const maxEventBytes = 200 * 1024;

  /// What the SDK adds to the event itself (its contexts, breadcrumbs and
  /// envelope), kept free under [maxEventBytes].
  static const sdkMargin = 24 * 1024;

  /// The device side; tests replace it.
  VideoReportPlatform platform = VideoReportPlatform();

  /// Where the picture's clock is read from (design D1).
  final clock = PictureClock();

  AppStorage? _storage;
  VideoTrigger? _armed;
  bool _autoPending = false;
  String? _autoVersion;
  DateTime? _lastButton;
  bool _taking = false;
  DateTime Function() now = DateTime.now;

  final _sent = StreamController<String>.broadcast();

  /// The first 8 characters of each button report's ID, once sent, for the
  /// TV screen's toast. Automatic reports say nothing.
  Stream<String> get sentNotices => _sent.stream;

  /// The report armed now, if any.
  VideoTrigger? get armed => _armed;

  bool get taking => _taking;

  /// Reports can be taken here: Android, and a build that sends them (with
  /// the switch on), or a diagnostics build, which logs them (design D12).
  bool get canTake =>
      PlatformInfo.isAndroid && (ErrorReports.available ? ReportSwitch.instance.on : PlaybackDiagnostics.enabled);

  /// Loads the once-per-version record, and arms the automatic report when
  /// this version hasn't sent one.
  Future<void> load(AppStorage storage) async {
    _storage = storage;
    final saved = await storage.readJson(file);
    _autoVersion = saved is Map && saved['autoVersion'] is String ? saved['autoVersion'] as String : null;
    ReportSwitch.instance.removeListener(_switchChanged);
    ReportSwitch.instance.addListener(_switchChanged);
    armAutoIfDue();
  }

  /// The automatic report, once per app version (design D10).
  void armAutoIfDue() {
    if (!canTake || _autoVersion == appVersion || _armed != null) return;
    _armed = VideoTrigger.auto;
    _autoPending = true;
    clock.reset();
    notifyListeners();
  }

  /// The switch off disarms; on again, an automatic report not yet taken
  /// for this version is armed.
  void _switchChanged() {
    if (!ReportSwitch.instance.on || !canTake) {
      disarm();
    } else {
      armAutoIfDue();
    }
  }

  /// The button (design D11): one report armed at a time, at most one a
  /// minute, only where reports are sent.
  ButtonResult armButton() {
    if (!PlatformInfo.isAndroid || !ErrorReports.running) return ButtonResult.unavailable;
    if (_armed == VideoTrigger.button) return ButtonResult.alreadyArmed;
    final t = now();
    final last = _lastButton;
    if (last != null && t.difference(last) < buttonInterval) return ButtonResult.tooSoon;
    _lastButton = t;
    // An armed automatic report becomes this one (and still counts as this
    // version's automatic report when taken).
    _armed = VideoTrigger.button;
    clock.reset();
    notifyListeners();
    return ButtonResult.armed;
  }

  void disarm() {
    if (_armed == null) return;
    _armed = null;
    _autoPending = false;
    clock.reset();
    notifyListeners();
  }

  /// One look at the picture: true when an armed report is due now.
  bool tick({required bool showing}) {
    if (_armed == null || _taking) {
      clock.reset();
      return false;
    }
    return clock.update(showing, now());
  }

  /// Takes the armed report from [live] (the picture on screen now), runs
  /// the self-test and sends it. Nothing when none is armed.
  Future<String?> take(LivePicture live) async {
    final trigger = _armed;
    if (trigger == null || _taking) return null;
    _taking = true;
    _armed = null;
    clock.reset();
    notifyListeners();
    try {
      final report = await VideoReportBuilder(platform).build(trigger, live);
      if (_autoPending) {
        _autoPending = false;
        _autoVersion = appVersion;
        await _storage?.writeJson(file, {'autoVersion': appVersion});
      }
      report.log();
      final id = await report.send();
      if (id != null && trigger == VideoTrigger.button) _sent.add(ReportSwitch.shortId(id));
      return id;
    } on Object catch (e, stack) {
      debugPrint('Video report failed: $e\n$stack');
      PlaybackDiagnostics.note('VIDEOREPORT', 'failed $e');
      return null;
    } finally {
      _taking = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void debugReset() {
    ReportSwitch.instance.removeListener(_switchChanged);
    _storage = null;
    _armed = null;
    _autoPending = false;
    _autoVersion = null;
    _lastButton = null;
    _taking = false;
    now = DateTime.now;
    platform = VideoReportPlatform();
    clock.reset();
  }
}

enum VideoTrigger { auto, button }

enum ButtonResult { armed, alreadyArmed, tooSoon, unavailable }

/// Whether the channel's picture is on screen (design D1): the TV screen is
/// the [current] page in its full-screen layout with no guide over it, and
/// a video segment is [playing] with its [picture], not a song, not paused
/// or dimmed. A status card means the tuner isn't [playing].
bool pictureOnScreen({
  required bool current,
  required bool guideOpen,
  required bool portrait,
  required bool playing,
  required bool song,
  required bool paused,
  required bool dimmed,
  required bool picture,
}) =>
    current && !guideOpen && !portrait && playing && !song && !paused && !dimmed && picture;

/// 10 continuous seconds of picture (design D1): any break restarts it.
class PictureClock {
  static const needed = Duration(seconds: 10);

  DateTime? _since;

  /// Whether the picture has now been on screen for [needed] without a
  /// break, [showing] being whether it is now.
  bool update(bool showing, DateTime now) {
    if (!showing) {
      _since = null;
      return false;
    }
    final since = _since ??= now;
    return now.difference(since) >= needed;
  }

  void reset() => _since = null;
}

/// The debug fault (design D13), from `debug.nightingale_tv.video_fault`.
enum VideoFault {
  none,

  /// Texture renders the report measures look like the Shield photo.
  smearTexture,

  /// The full-screen video looks like it on screen.
  smearScreen;

  /// [value] as set, honoured only in a [debuggable] build.
  static VideoFault parse(String? value, {required bool debuggable}) {
    if (!debuggable) return none;
    return switch (value?.trim()) {
      'smear-texture' => smearTexture,
      'smear-screen' => smearScreen,
      _ => none,
    };
  }

  /// The fault in force for this run (Android reads the property; Kotlin
  /// returns nothing in a release build).
  static final current = ValueNotifier<VideoFault>(none);

  static Future<void> load(VideoReportPlatform platform) async {
    if (!PlatformInfo.isAndroid) return;
    // Kotlin answers only in a debuggable build; a release build ignores
    // it here too.
    current.value = parse(await platform.fault(), debuggable: !kReleaseMode);
  }
}

/// The picture on screen when a report is taken, as the TV screen sees it.
class LivePicture {
  const LivePicture({
    required this.playerId,
    required this.textureRect,
    required this.devicePixelRatio,
    required this.effectsOn,
    required this.retro,
    this.playMethod,
    this.serverKind,
  });

  /// The ExoPlayer instance (its texture's ID).
  final int playerId;

  /// The video's visible rectangle on screen, in logical pixels, and the
  /// share of the texture it shows ([TextureView.texturePart]).
  final TextureView? textureRect;
  final double devicePixelRatio;

  /// CRT effects change the picture on purpose (design D4).
  final bool effectsOn;

  /// The channel's retro look: shape, CRT style, values, shader tier.
  final Map<String, Object?> retro;
  final String? playMethod;
  final String? serverKind;
}

/// Where the video is on screen: the part of the screen it covers, in
/// logical pixels, and which part of the texture shows there (fractions,
/// left/top/right/bottom).
class TextureView {
  const TextureView(this.screen, this.texturePart);

  final ui.Rect screen;
  final ui.Rect texturePart;
}

/// The device side of a report (`nightingale_tv/platform` and
/// `nightingale_tv/player`).
class VideoReportPlatform {
  static const _platform = MethodChannel('nightingale_tv/platform');
  static const _player = MethodChannel('nightingale_tv/player');

  Future<Map<Object?, Object?>> _map(MethodChannel channel, String method, [Object? args]) async {
    try {
      return await channel.invokeMethod<Map<Object?, Object?>>(method, args) ?? const {'error': 'no answer'};
    } on Object catch (e) {
      return {'error': '$e'};
    }
  }

  Future<Map<Object?, Object?>> facts() => _map(_platform, 'videoFacts');

  Future<String?> logcat() async {
    try {
      return await _platform.invokeMethod<String>('videoLogcat');
    } on Object {
      return null;
    }
  }

  Future<Map<Object?, Object?>> capture() => _map(_platform, 'videoCapture');

  Future<String?> fault() async {
    try {
      return await _platform.invokeMethod<String>('videoFault');
    } on Object {
      return null;
    }
  }

  Future<Map<Object?, Object?>> stream(int playerId) => _map(_player, 'videoReport', {'id': playerId});

  Future<Map<Object?, Object?>> decoder(String card) => _map(_platform, 'selfTestDecoder', {'card': card});

  Future<Map<Object?, Object?>> cpu(String card, String decoder) =>
      _map(_platform, 'selfTestCpu', {'card': card, 'decoder': decoder});

  Future<Map<Object?, Object?>> probe(String card, String decoder) =>
      _map(_platform, 'selfTestProbe', {'card': card, 'decoder': decoder});

  Future<Map<Object?, Object?>> texture(String card, String decoder, {required bool gl}) =>
      _map(_platform, 'selfTestTexture', {'card': card, 'decoder': decoder, 'gl': gl});

  Future<void> release(int textureId) async {
    try {
      await _platform.invokeMethod<void>('selfTestRelease', {'id': textureId});
    } on Object {
      // Kotlin releases it itself after a while.
    }
  }

  /// [textureId] drawn on its own, through the engine's own texture import
  /// and sampling (design D3), as RGBA; null when it can't be.
  Future<Uint8List?> renderTexture(int textureId, int width, int height) async {
    final builder = ui.SceneBuilder()
      ..addTexture(textureId, width: width.toDouble(), height: height.toDouble(), filterQuality: ui.FilterQuality.low);
    final scene = builder.build();
    try {
      final image = await scene.toImage(width, height);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      scene.dispose();
    }
  }

  /// The test cards' expected figures.
  Future<Map<String, Object?>> expected() async =>
      jsonDecode(await rootBundle.loadString('assets/video_test/card_expected.json')) as Map<String, Object?>;
}

/// The test cards, in the order the self-test runs them.
const videoTestCards = ['h264', 'hevc', 'hevc10'];

/// The run kinds of the self-test, as tagged.
const videoTestRuns = ['cpu_decode', 'image_reader', 'surface_texture'];

/// Gathers a report (design D7–D10): the picture first, while it's on
/// screen, then the device, stream and decoder, the self-test, and the log
/// last, so it holds the self-test's own lines.
class VideoReportBuilder {
  VideoReportBuilder(this.platform);

  final VideoReportPlatform platform;

  Future<VideoReport> build(VideoTrigger trigger, LivePicture live) async {
    final fault = VideoFault.current.value;
    final picture = await _picture(live, fault);
    final stream = {
      ...await platform.stream(live.playerId),
      'play_method': live.playMethod ?? 'unknown',
      'server_kind': live.serverKind ?? 'unknown',
    };
    final device = {
      ...await platform.facts(),
      'device_pixel_ratio': live.devicePixelRatio,
      if (fault != VideoFault.none) 'fault': fault.name,
    };
    final selfTest = await runSelfTest(fault);
    final logcat = await platform.logcat();
    return VideoReport(
      trigger: trigger,
      device: device,
      stream: stream,
      picture: picture,
      selfTest: selfTest,
      logcat: logcat,
    );
  }

  /// The texture rendered on its own and the screen's video area, measured
  /// and compared (design D3, D4).
  Future<Map<String, Object?>> _picture(LivePicture live, VideoFault fault) async {
    final stream = await platform.stream(live.playerId);
    final size = _size(stream['texture_size']) ?? (1920, 1080);
    // Capped at 1920×1080, its shape kept.
    final scale = min(1.0, min(1920 / size.$1, 1080 / size.$2));
    final tw = max(1, (size.$1 * scale).round()), th = max(1, (size.$2 * scale).round());
    var out = <String, Object?>{};
    // The screen and the texture are taken together, as the video moves;
    // a pair that differs is taken again (a cut or a fade between the two),
    // up to [_pictureTries] times, and the last pair is kept.
    for (var attempt = 1; attempt <= _pictureTries; attempt++) {
      if (attempt > 1) await Future<void>.delayed(const Duration(milliseconds: 400));
      out = await _picturePair(live, fault, tw, th);
      out['tries'] = attempt;
      if (out['screen_match'] != 'no') break;
    }
    return {
      'retro': live.retro,
      'effects_on': live.effectsOn,
      'texture_size': '${size.$1}x${size.$2}',
      'render_size': '${tw}x$th',
      ...out,
    };
  }

  static const _pictureTries = 3;

  /// One capture of the screen and render of the texture, taken at once.
  Future<Map<String, Object?>> _picturePair(LivePicture live, VideoFault fault, int tw, int th) async {
    final out = <String, Object?>{};
    final rendering = () async {
      try {
        return await platform.renderTexture(live.playerId, tw, th);
      } on Object catch (e) {
        out['texture'] = {'error': '$e'};
        return null;
      }
    }();
    final shot = await platform.capture();
    var textureRgba = await rendering;

    PictureMeasure? texture;
    if (textureRgba != null && fault == VideoFault.smearTexture) textureRgba = smearPicture(textureRgba, tw, th);
    if (textureRgba != null) {
      texture = await measureInIsolate(textureRgba, tw, th);
      out['texture'] = texture.toJson();
      out['render_empty'] = texture.renderEmpty;
    } else {
      out['texture'] ??= {'error': 'no image'};
    }

    final view = live.textureRect;
    final rgba = shot['rgba'];
    String match = 'unknown';
    if (rgba is! Uint8List || view == null) {
      out['screen'] = {'error': shot['error'] ?? (view == null ? 'video not on screen' : 'no capture')};
    } else {
      final w = (shot['width'] as num).toInt(), h = (shot['height'] as num).toInt();
      final sw = (shot['surface_width'] as num?)?.toDouble() ?? w.toDouble();
      final sh = (shot['surface_height'] as num?)?.toDouble() ?? h.toDouble();
      final k = live.devicePixelRatio;
      // Logical pixels → the surface's pixels → the capture's.
      final r = view.screen;
      final left = (r.left * k * w / sw).ceil().clamp(0, w), top = (r.top * k * h / sh).ceil().clamp(0, h);
      final right = (r.right * k * w / sw).floor().clamp(0, w), bottom = (r.bottom * k * h / sh).floor().clamp(0, h);
      if (right - left < PictureMeasure.columns || bottom - top < PictureMeasure.rows) {
        out['screen'] = {'error': 'video area too small'};
      } else {
        final screen = await measureInIsolate(rgba, w, h, left: left, top: top, w: right - left, h: bottom - top);
        out['screen'] = {...screen.toJson(), 'area': '$left,$top,$right,$bottom'};
        final textureImage = textureRgba;
        if (live.effectsOn) {
          match = 'effects';
        } else if (texture != null && textureImage != null && !texture.renderEmpty) {
          // The same part of the texture as the screen shows.
          final p = view.texturePart;
          final pl = (p.left * tw).round().clamp(0, tw - 1), pt = (p.top * th).round().clamp(0, th - 1);
          final pr = (p.right * tw).round().clamp(pl + 1, tw), pb = (p.bottom * th).round().clamp(pt + 1, th);
          final same = await measureInIsolate(textureImage, tw, th, left: pl, top: pt, w: pr - pl, h: pb - pt);
          final share = screenShare(screen, same);
          out['screen_share'] = (share * 1000).round() / 1000;
          // A blur keeps the colours: the detail is compared too, at one
          // common scale.
          final screenFine = await coarseDetailInIsolate(rgba, w, h, left: left, top: top, w: right - left, h: bottom - top);
          final textureFine = await coarseDetailInIsolate(textureImage, tw, th, left: pl, top: pt, w: pr - pl, h: pb - pt);
          final detail = textureFine > 0 ? screenFine / textureFine : (screenFine > 0 ? 1.0 : 0.0);
          out['screen_detail_ratio'] = (detail * 1000).round() / 1000;
          match = share >= PictureMeasure.screenShare && detail >= PictureMeasure.screenDetailShare ? 'yes' : 'no';
        }
      }
    }
    out['screen_match'] = match;
    return out;
  }

  static (int, int)? _size(Object? s) {
    final m = RegExp(r'^(\d+)x(\d+)$').firstMatch('$s');
    return m == null ? null : (int.parse(m[1]!), int.parse(m[2]!));
  }

  /// The test cards through the real video path (design D5): per card, the
  /// CPU decode, the buffer probe, and the texture renders, one at a time.
  Future<Map<String, Object?>> runSelfTest(VideoFault fault) async {
    final expected = (await platform.expected())['cards'] as Map;
    final cards = <String, Object?>{};
    for (final card in videoTestCards) {
      final want = PictureMeasure.fromJson(expected[card] as Map);
      final d = await platform.decoder(card);
      final skip = d['skipped'] ?? d['error'];
      final runs = <String, Object?>{'decoder': d['decoder'], 'max_instances': d['max_instances']};
      if (skip != null || d['decoder'] is! String) {
        for (final kind in videoTestRuns) {
          runs[kind] = {'result': 'skipped', 'reason': '${skip ?? 'no decoder'}'};
        }
        runs['probe'] = {'skipped': '${skip ?? 'no decoder'}'};
        cards[card] = runs;
        continue;
      }
      final decoder = d['decoder'] as String;
      runs['cpu_decode'] = await _cpu(card, decoder, want);
      runs['probe'] = _plain(await platform.probe(card, decoder));
      runs['image_reader'] = await _texture(card, decoder, want, gl: false, smear: fault == VideoFault.smearTexture);
      runs['surface_texture'] = await _texture(card, decoder, want, gl: true, smear: false);
      cards[card] = runs;
    }
    return {
      'cards': cards,
      for (final kind in videoTestRuns) kind: summarize(cards, kind),
      'gpu_matrix': gpuMatrix(cards),
    };
  }

  /// A run kind's tag: `fail` if any card failed it, `pass` if any passed,
  /// else `skipped`.
  static String summarize(Map<String, Object?> cards, String kind) {
    final results = [
      for (final c in cards.values)
        if (c is Map && c[kind] is Map) (c[kind] as Map)['result'],
    ];
    if (results.contains('fail')) return 'fail';
    if (results.contains('pass')) return 'pass';
    return 'skipped';
  }

  /// The colour matrix the GPU's texture runs fit: one name when every run
  /// that went agrees, `mixed` when they don't, `skipped` when none went.
  static String gpuMatrix(Map<String, Object?> cards) {
    final fits = {
      for (final c in cards.values)
        if (c is Map)
          for (final kind in ['image_reader', 'surface_texture'])
            if (c[kind] case final Map run when run['matrix'] is String) run['matrix'] as String,
    };
    return fits.isEmpty ? 'skipped' : (fits.length == 1 ? fits.single : 'mixed');
  }

  Future<Map<String, Object?>> _cpu(String card, String decoder, PictureMeasure want) async {
    final r = await platform.cpu(card, decoder);
    final rgba = r['rgba'];
    if (rgba is! Uint8List) return {'result': 'skipped', 'reason': '${r['skipped'] ?? r['error'] ?? 'no frame'}'};
    final w = (r['width'] as num).toInt(), h = (r['height'] as num).toInt();
    final m = await measureInIsolate(rgba, w, h);
    final check = checkCard(m, want);
    return {
      'result': check.pass ? 'pass' : 'fail',
      ...check.toJson(),
      ...m.toJson(),
      'size': '${w}x$h',
      'image_format': r['image_format'],
      'bit_depth': r['bit_depth'],
    };
  }

  Future<Map<String, Object?>> _texture(String card, String decoder, PictureMeasure want,
      {required bool gl, required bool smear}) async {
    final t = await platform.texture(card, decoder, gl: gl);
    final id = t['texture_id'];
    if (id is! int) return {'result': 'skipped', 'reason': '${t['skipped'] ?? t['error'] ?? 'no texture'}'};
    try {
      final w = (t['width'] as num).toInt(), h = (t['height'] as num).toInt();
      var rgba = await platform.renderTexture(id, w, h);
      if (rgba == null) return {'result': 'skipped', 'reason': 'no image'};
      if (smear) rgba = smearPicture(rgba, w, h);
      final m = await measureInIsolate(rgba, w, h);
      if (m.renderEmpty) return {'result': 'skipped', 'reason': 'render_empty', ...m.toJson()};
      final check = checkCard(m, want);
      return {
        'result': check.pass ? 'pass' : 'fail',
        'matrix': matrixFit(m, want),
        ...check.toJson(),
        ...m.toJson(),
        'kind': t['kind'],
      };
    } on Object catch (e) {
      return {'result': 'skipped', 'reason': 'error: $e'};
    } finally {
      await platform.release(id);
    }
  }

  /// A platform answer as plain JSON-able values.
  static Map<String, Object?> _plain(Map<Object?, Object?> m) => {for (final e in m.entries) '${e.key}': e.value};
}

/// One gathered report: its sections, the event made from them, and the
/// diagnostics log's VIDEOREPORT lines.
class VideoReport {
  VideoReport({
    required this.trigger,
    required this.device,
    required this.stream,
    required this.picture,
    required this.selfTest,
    required this.logcat,
  });

  final VideoTrigger trigger;
  final Map<Object?, Object?> device, stream, picture, selfTest;

  /// The app's own log lines, or null when they couldn't be read.
  final String? logcat;

  static Map<String, Object?> _json(Map<Object?, Object?> m) => jsonDecode(jsonEncode(_jsonable(m))) as Map<String, Object?>;

  static Object? _jsonable(Object? v) => switch (v) {
        final Map<Object?, Object?> m => {for (final e in m.entries) '${e.key}': _jsonable(e.value)},
        // Pixels never go: only their measurements.
        final Uint8List b => '<${b.length} bytes>',
        final List<Object?> l => [for (final x in l) _jsonable(x)],
        final String s => s,
        final num n => n.isFinite ? n : '$n',
        final bool b => b,
        null => null,
        _ => '$v',
      };

  /// design D10's tags.
  Map<String, String> get tags {
    String s(Object? v) => v == null ? 'unknown' : '$v';
    final build = device['build'], gl = device['gl'];
    return {
      'area': 'video_report',
      'trigger': trigger.name,
      // GlitchTip keeps `device` for its own (the SDK's device model).
      'build_device': s(build is Map ? build['device'] : null),
      'gpu': s(gl is Map ? gl['renderer'] : null),
      'decoder': s(stream['decoder']),
      'producer': s(device['producer']),
      'backend': s(device['backend']),
      for (final kind in videoTestRuns) kind: s(selfTest[kind]),
      'gpu_matrix': s(selfTest['gpu_matrix']),
      'screen_match': s(picture['screen_match']),
    };
  }

  Map<String, Map<String, Object?>> get contexts => {
        'video_device': _json(device),
        'video_stream': _json(stream),
        'video_picture': _json(picture),
        'video_self_test': _json(selfTest),
      };

  /// The log, with its oldest lines left out until the event fits under
  /// [VideoReports.maxEventBytes] (design D10).
  String fittedLogcat() {
    final log = logcat;
    if (log == null) return 'logcat: unavailable';
    final rest = utf8.encode(jsonEncode({'tags': tags, 'contexts': contexts})).length;
    final budget = VideoReports.maxEventBytes - VideoReports.sdkMargin - rest;
    var lines = log.split('\n');
    // JSON escaping grows a log a little: counted as encoded.
    while (lines.isNotEmpty && utf8.encode(jsonEncode(lines.join('\n'))).length > budget) {
      lines = lines.sublist(max(1, lines.length ~/ 10));
    }
    return lines.join('\n');
  }

  /// Sent as one event (design D10), when this build sends reports; its
  /// ID, or null when nothing was sent.
  Future<String?> send() async {
    if (!ErrorReports.running) return null;
    final logcat = fittedLogcat();
    final id = await Sentry.captureMessage('Video report', level: SentryLevel.info, withScope: (scope) async {
      for (final t in tags.entries) {
        await scope.setTag(t.key, t.value);
      }
      for (final c in contexts.entries) {
        await scope.setContexts(c.key, c.value);
      }
      // ignore: deprecated_member_use
      await scope.setExtra('logcat', logcat);
    });
    if (id == const SentryId.empty()) return null;
    return id.toString();
  }

  /// A diagnostics build's VIDEOREPORT lines, one per section (design D12),
  /// scrubbed as the event is.
  void log() {
    if (!PlaybackDiagnostics.enabled) return;
    final s = ErrorReports.scrubber;
    PlaybackDiagnostics.note('VIDEOREPORT', 'tags ${s.scrub(jsonEncode(tags))}');
    for (final c in contexts.entries) {
      PlaybackDiagnostics.note('VIDEOREPORT', '${c.key} ${s.scrub(jsonEncode(c.value))}');
    }
    PlaybackDiagnostics.note('VIDEOREPORT', 'logcat ${s.scrub(jsonEncode(fittedLogcat()))}');
  }
}
