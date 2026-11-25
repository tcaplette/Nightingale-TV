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

/// The picture on screen when a report is taken, as the TV screen sees it.
class LivePicture {
  const LivePicture({
    required this.playerId,
    required this.hole,
    required this.devicePixelRatio,
    required this.effectsOn,
    required this.retro,
    this.playMethod,
    this.serverKind,
  });

  /// The ExoPlayer instance.
  final int playerId;

  /// The hole Flutter leaves for the video, in device pixels; null when it
  /// isn't on the screen.
  final ui.Rect? hole;
  final double devicePixelRatio;

  /// CRT effects change the picture on purpose (design D4).
  final bool effectsOn;

  /// The channel's retro look: shape, CRT style, values, shader tier.
  final Map<String, Object?> retro;
  final String? playMethod;
  final String? serverKind;
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

  /// Flutter's own surface, with its alpha.
  Future<Map<Object?, Object?>> capture() => _map(_platform, 'videoCapture');

  /// The video layer's picture.
  Future<Map<Object?, Object?>> captureVideo(int playerId) => _map(_player, 'videoCapture', {'id': playerId});

  /// The buffer the decoder makes for the stream playing, and the part of it
  /// that is the picture.
  Future<Map<Object?, Object?>> streamBuffer(int playerId) => _map(_player, 'videoBuffer', {'id': playerId});

  Future<Map<Object?, Object?>> stream(int playerId) => _map(_player, 'videoReport', {'id': playerId});

  Future<Map<Object?, Object?>> decoder(String card) => _map(_platform, 'selfTestDecoder', {'card': card});

  Future<Map<Object?, Object?>> cpu(String card, String decoder) =>
      _map(_platform, 'selfTestCpu', {'card': card, 'decoder': decoder});

  Future<Map<Object?, Object?>> probe(String card, String decoder) =>
      _map(_platform, 'selfTestProbe', {'card': card, 'decoder': decoder});

  /// The test cards' expected figures.
  Future<Map<String, Object?>> expected() async =>
      jsonDecode(await rootBundle.loadString('assets/video_test/card_expected.json')) as Map<String, Object?>;
}

/// The test cards, in the order the self-test runs them.
const videoTestCards = ['h264', 'hevc', 'hevc10', 'mpeg2'];

/// The run kinds of the self-test, as tagged.
const videoTestRuns = ['cpu_decode'];

/// Gathers a report (design D7–D10): the picture first, while it's on
/// screen, then the stream, layer and device, the self-test, and the log
/// last, so it holds the self-test's own lines.
class VideoReportBuilder {
  VideoReportBuilder(this.platform);

  final VideoReportPlatform platform;

  Future<VideoReport> build(VideoTrigger trigger, LivePicture live) async {
    final picture = await _picture(live);
    final stream = {
      ...await platform.stream(live.playerId),
      'play_method': live.playMethod ?? 'unknown',
      'server_kind': live.serverKind ?? 'unknown',
    };
    final layer = await _layer(live, stream);
    final device = {
      ...await platform.facts(),
      'device_pixel_ratio': live.devicePixelRatio,
    };
    final selfTest = await runSelfTest();
    final logcat = await platform.logcat();
    return VideoReport(
      trigger: trigger,
      device: device,
      stream: stream,
      layer: layer,
      picture: picture,
      selfTest: selfTest,
      logcat: logcat,
    );
  }

  /// The video layer's own picture, measured, and its edges
  /// (system-video-layer D8).
  Future<Map<String, Object?>> _picture(LivePicture live) async {
    final out = <String, Object?>{'retro': live.retro, 'effects_on': live.effectsOn};
    final shot = await platform.captureVideo(live.playerId);
    final rgba = shot['rgba'];
    if (rgba is! Uint8List) {
      return {...out, 'video': {'error': shot['error'] ?? 'no capture'}, 'edge': 'unknown'};
    }
    final w = (shot['width'] as num).toInt(), h = (shot['height'] as num).toInt();
    final strips = await edgeStripsInIsolate(rgba, w, h);
    return {
      ...out,
      'video': (await measureInIsolate(rgba, w, h)).toJson(),
      'size': '${w}x$h',
      'edge': strips.any ? 'padding' : 'clean',
      'edge_right': strips.right,
      'edge_bottom': strips.bottom,
    };
  }

  /// Where the layer is, against the hole Flutter leaves for it, and what the
  /// decoder gives it (system-video-layer D8).
  Future<Map<String, Object?>> _layer(LivePicture live, Map<Object?, Object?> stream) async {
    final layer = stream['layer'];
    final buffer = await platform.streamBuffer(live.playerId);
    final out = <String, Object?>{
      'layer': layer ?? 'unknown',
      'hole_asked': _rect(live.hole),
      'buffer': buffer,
      'padded': padded(buffer, stream['decoder_output']),
      'hdr': stream['hdr'] ?? 'unknown',
      'effects': stream['effects'] ?? 'unknown',
    };
    final shot = await platform.capture();
    final rgba = shot['rgba'];
    if (rgba is! Uint8List) return {...out, 'hole': {'error': shot['error'] ?? 'no capture'}, 'layer_match': 'unknown'};
    final w = (shot['width'] as num).toInt(), h = (shot['height'] as num).toInt();
    final sw = (shot['surface_width'] as num?)?.toDouble() ?? w.toDouble();
    final sh = (shot['surface_height'] as num?)?.toDouble() ?? h.toDouble();
    final clear = await clearAreaInIsolate(rgba, w, h);
    // The capture's pixels → the surface's.
    final hole = clear == null
        ? null
        : ui.Rect.fromLTRB(clear.left * sw / w, clear.top * sh / h, clear.right * sw / w, clear.bottom * sh / h);
    return {...out, 'hole': _rect(hole) ?? 'none', 'layer_match': layerMatch(layer, hole, ui.Size(sw, sh))};
  }

  static List<int>? _rect(ui.Rect? r) =>
      r == null ? null : [r.left.round(), r.top.round(), r.right.round(), r.bottom.round()];

  /// Whether [layer] (left, top, right, bottom), clipped to the [screen],
  /// covers the [hole], within 2 pixels. No hole at all is a `no`: something
  /// over the video hides it.
  static String layerMatch(Object? layer, ui.Rect? hole, ui.Size screen) {
    if (layer is! List || layer.length != 4 || layer.any((v) => v is! num)) return 'unknown';
    if (hole == null) return 'no';
    final [l, t, r, b] = [for (final v in layer) (v as num).toDouble()];
    final shown = ui.Rect.fromLTRB(l, t, r, b).intersect(ui.Offset.zero & screen);
    return shown.inflate(2).expandToInclude(hole) == shown.inflate(2) ? 'yes' : 'no';
  }

  /// Whether the decoder's buffer is larger than its picture: as its own
  /// buffer says, or the output format it reported.
  static String padded(Map<Object?, Object?> buffer, Object? output) {
    final bw = buffer['buffer_width'], bh = buffer['buffer_height'];
    final crop = '${buffer['crop']}'.split(',').map(int.tryParse).toList();
    String? said;
    if (bw is num && bh is num && crop.length == 4 && !crop.contains(null)) {
      if (bw > crop[2]! - crop[0]! || bh > crop[3]! - crop[1]!) return 'yes';
      said = 'no';
    }
    if (output is Map) {
      int? at(String k) => int.tryParse('${output[k]}');
      final w = at('width'), h = at('height');
      final l = at('crop-left'), t = at('crop-top'), r = at('crop-right'), b = at('crop-bottom');
      if (w != null && h != null && l != null && t != null && r != null && b != null) {
        if (w > r - l + 1 || h > b - t + 1) return 'yes';
        // A decoder can report the picture's size and allocate more, so only
        // its buffer says no.
      }
    }
    return said ?? 'unknown';
  }

  /// The test cards (design D5): per card, the CPU decode and the buffer
  /// probe, one at a time.
  Future<Map<String, Object?>> runSelfTest() async {
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
      cards[card] = runs;
    }
    return {
      'cards': cards,
      for (final kind in videoTestRuns) kind: summarize(cards, kind),
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
    required this.layer,
    required this.picture,
    required this.selfTest,
    required this.logcat,
  });

  final VideoTrigger trigger;
  final Map<Object?, Object?> device, stream, layer, picture, selfTest;

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
      'backend': s(device['backend']),
      for (final kind in videoTestRuns) kind: s(selfTest[kind]),
      'padded': s(layer['padded']),
      'edge': s(picture['edge']),
      'layer_match': s(layer['layer_match']),
    };
  }

  Map<String, Map<String, Object?>> get contexts => {
        'video_device': _json(device),
        'video_stream': _json(stream),
        'video_layer': _json(layer),
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
