import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_version.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/reporting/error_reports.dart';
import 'package:nightingale_tv/reporting/picture_measure.dart';
import 'package:nightingale_tv/reporting/report_switch.dart';
import 'package:nightingale_tv/reporting/video_report.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Keeps what would have gone to GlitchTip.
class _Sent implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }

  /// Each event as sent: its JSON and its size in bytes.
  Future<List<({Map<String, Object?> json, int bytes})>> events() async => [
        for (final e in envelopes)
          for (final item in e.items)
            if (item.header.type == 'event')
              await () async {
                final data = await item.dataFactory();
                return (json: jsonDecode(utf8.decode(data)) as Map<String, Object?>, bytes: data.length);
              }(),
      ];
}

/// A small picture: four coloured quadrants and some fine detail.
Uint8List _picture(int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final fine = (x + y).isEven ? 40 : 0;
      out[i] = (x < w / 2 ? 200 : 30) + fine;
      out[i + 1] = (y < h / 2 ? 180 : 40) + fine;
      out[i + 2] = (x >= w / 2 && y >= h / 2 ? 210 : 20) + fine;
      out[i + 3] = 255;
    }
  }
  return out;
}

/// The device side, faked: every card decodes to [_picture].
class _FakePlatform extends VideoReportPlatform {
  _FakePlatform({this.log = 'I/flutter: Using the Impeller rendering backend (OpenGLES).'});

  static const w = 64, h = 36;
  final String? log;
  final released = <int>[];
  Uint8List image = _picture(w, h);

  @override
  Future<Map<Object?, Object?>> facts() async => {
        'build': {'device': 'goldfish_x86_64', 'manufacturer': 'Google'},
        'gl': {'renderer': 'Android Emulator OpenGL ES Translator'},
        'backend': 'OpenGLES',
        'producer': 'image_reader',
      };

  @override
  Future<String?> logcat() async => log;

  @override
  Future<Map<Object?, Object?>> capture() async =>
      {'rgba': _picture(w, h), 'width': w, 'height': h, 'surface_width': w, 'surface_height': h};

  @override
  Future<String?> fault() async => '';

  @override
  Future<Map<Object?, Object?>> stream(int playerId) async =>
      {'decoder': 'c2.goldfish.hevc.decoder', 'texture_size': '${w}x$h'};

  @override
  Future<Map<Object?, Object?>> decoder(String card) async =>
      card == 'hevc10' ? {'skipped': 'no hardware decoder'} : {'decoder': 'c2.goldfish.$card.decoder', 'max_instances': 16};

  @override
  Future<Map<Object?, Object?>> cpu(String card, String decoder) async =>
      {'rgba': _picture(w, h), 'width': w, 'height': h, 'image_format': '0x23', 'bit_depth': 8};

  @override
  Future<Map<Object?, Object?>> probe(String card, String decoder) async => {'buffer_format': '0x22'};

  @override
  Future<Map<Object?, Object?>> texture(String card, String decoder, {required bool gl}) async =>
      {'texture_id': gl ? 91 : 90, 'width': w, 'height': h, 'kind': gl ? 'surface_texture' : 'default'};

  @override
  Future<void> release(int textureId) async => released.add(textureId);

  @override
  Future<Uint8List?> renderTexture(int textureId, int width, int height) async => image;

  @override
  Future<Map<String, Object?>> expected() async {
    final card = measureRgba(_picture(w, h), w, h).toJson();
    return {
      'cards': {for (final c in videoTestCards) c: card},
    };
  }
}

/// The screen shows [screen] (a blurred copy of the picture).
class _BlurredScreen extends _FakePlatform {
  _BlurredScreen(this.screen);

  final Uint8List screen;

  @override
  Future<Map<Object?, Object?>> capture() async =>
      {'rgba': screen, 'width': 64, 'height': 36, 'surface_width': 64, 'surface_height': 36};
}

/// The first capture lands on a different shot (a cut), the next ones on
/// the picture.
class _CutOnce extends _FakePlatform {
  var captures = 0;

  @override
  Future<Map<Object?, Object?>> capture() async {
    captures++;
    if (captures > 1) return super.capture();
    final other = Uint8List(64 * 36 * 4)..fillRange(0, 64 * 36 * 4, 230);
    return {'rgba': other, 'width': 64, 'height': 36, 'surface_width': 64, 'surface_height': 36};
  }
}

const _live = LivePicture(
  playerId: 5,
  textureRect: TextureView(Rect.fromLTRB(0, 0, 64, 36), Rect.fromLTRB(0, 0, 1, 1)),
  devicePixelRatio: 1,
  effectsOn: false,
  retro: {'shape': 'original', 'crt': 'off'},
  playMethod: 'direct',
  serverKind: 'jellyfin',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Directory? started;
  late Directory dir;
  late AppStorage storage;
  late _Sent sent;
  late DateTime now;
  final reports = VideoReports.instance;

  Future<void> start({bool dsn = true, Map<String, Object?>? saved}) async {
    dir = started = await Directory.systemTemp.createTemp('video_report');
    storage = await AppStorage.at(dir);
    if (saved != null) await storage.writeJson(VideoReports.file, saved);
    PlatformInfo.debugOverride = TargetPlatform.android;
    // The Dart SDK alone, as on Android 7: no native plugin in a test.
    PlatformInfo.debugAndroidSdk = 24;
    await ErrorReports.debugReset();
    ReportSwitch.instance.reset();
    reports.debugReset();
    sent = _Sent();
    ErrorReports.debugDsn = dsn ? 'https://public@reports.invalid/2' : '';
    ErrorReports.debugTransport = sent;
    ErrorReports.debugInstallHandlers = false;
    await ErrorReports.startApp(storage);
    now = DateTime(2026, 11, 9, 20);
    reports
      ..now = (() => now)
      ..platform = _FakePlatform();
    await reports.load(storage);
  }

  tearDown(() async {
    reports.debugReset();
    await ErrorReports.debugReset();
    ReportSwitch.instance.reset();
    PlatformInfo.debugOverride = null;
    PlatformInfo.debugAndroidSdk = null;
    VideoFault.current.value = VideoFault.none;
    if (started != null) {
      await storage.flush();
      await started!.delete(recursive: true);
      started = null;
    }
  });

  /// [seconds] one-second looks at the picture, [showing] each time; true
  /// when the report came due.
  bool watch(int seconds, {bool showing = true}) {
    var due = false;
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      due = reports.tick(showing: showing) || due;
    }
    return due;
  }

  group('the picture clock', () {
    test('10 continuous seconds; a guide, a pause, a song or a status card restarts it', () async {
      await start();
      expect(reports.armed, VideoTrigger.auto, reason: 'a new version arms its automatic report');
      expect(reports.tick(showing: true), isFalse, reason: 'the clock starts');
      // Each of these is a break: the TV screen reports "not showing".
      for (final breakIn in ['guide open', 'paused', 'song card', 'status card']) {
        expect(watch(6), isFalse, reason: 'before $breakIn');
        expect(watch(1, showing: false), isFalse, reason: breakIn);
      }
      expect(watch(9), isFalse, reason: 'only 9 s since the last break');
      expect(watch(2), isTrue, reason: '10 s without a break');
    });

    test('what counts as the picture on screen', () {
      bool on({
        bool current = true,
        bool guideOpen = false,
        bool portrait = false,
        bool playing = true,
        bool song = false,
        bool paused = false,
        bool dimmed = false,
        bool picture = true,
      }) =>
          pictureOnScreen(
              current: current,
              guideOpen: guideOpen,
              portrait: portrait,
              playing: playing,
              song: song,
              paused: paused,
              dimmed: dimmed,
              picture: picture);
      expect(on(), isTrue);
      expect(on(current: false), isFalse, reason: 'a menu over the TV screen');
      expect(on(guideOpen: true), isFalse);
      expect(on(portrait: true), isFalse, reason: 'not full screen');
      expect(on(playing: false), isFalse, reason: 'a status card');
      expect(on(song: true), isFalse);
      expect(on(paused: true), isFalse);
      expect(on(dimmed: true), isFalse);
      expect(on(picture: false), isFalse, reason: 'no video yet');
    });
  });

  test('once per version: taken, recorded, and not armed again', () async {
    await start(saved: {'autoVersion': '0.9.0'});
    expect(reports.armed, VideoTrigger.auto);
    watch(11);
    final id = await reports.take(_live);
    expect(id, isNotNull);
    await storage.flush();
    expect(jsonDecode(File('${dir.path}/${VideoReports.file}').readAsStringSync()), {'autoVersion': appVersion});
    final events = await sent.events();
    expect(events.single.json['tags'], containsPair('trigger', 'auto'));

    // The next start of the same version.
    reports.debugReset();
    reports.platform = _FakePlatform();
    await reports.load(await AppStorage.at(dir));
    expect(reports.armed, isNull);
  });

  test('the button: one armed at a time, at most one a minute; the toast gets its ID', () async {
    await start(saved: {'autoVersion': appVersion});
    expect(reports.armed, isNull);
    final toasts = <String>[];
    final sub = reports.sentNotices.listen(toasts.add);
    expect(reports.armButton(), ButtonResult.armed);
    expect(reports.armButton(), ButtonResult.alreadyArmed);
    watch(11);
    final id = await reports.take(_live);
    await Future<void>.delayed(Duration.zero);
    expect(toasts, [ReportSwitch.shortId(id!)]);
    expect(ReportSwitch.instance.shortLastId, ReportSwitch.shortId(id), reason: 'the last report ID');
    now = now.add(const Duration(seconds: 30));
    expect(reports.armButton(), ButtonResult.tooSoon);
    now = now.add(const Duration(seconds: 31));
    expect(reports.armButton(), ButtonResult.armed);
    await sub.cancel();
  });

  test('a button press takes over an armed automatic report', () async {
    await start();
    expect(reports.armed, VideoTrigger.auto);
    expect(reports.armButton(), ButtonResult.armed);
    expect(reports.armed, VideoTrigger.button);
    await reports.take(_live);
    expect((await sent.events()).single.json['tags'], containsPair('trigger', 'button'));
    await storage.flush();
    expect(jsonDecode(File('${dir.path}/${VideoReports.file}').readAsStringSync()), {'autoVersion': appVersion},
        reason: 'it counts as this version\'s automatic report');
  });

  test('the switch off disarms, and nothing is armed or sent while off', () async {
    await start();
    expect(reports.armed, VideoTrigger.auto);
    await ErrorReports.setOn(false);
    expect(reports.armed, isNull);
    expect(reports.armButton(), ButtonResult.unavailable);
    expect(watch(20), isFalse);
    expect(await reports.take(_live), isNull);
    expect(sent.envelopes, isEmpty);
    await ErrorReports.setOn(true);
    expect(reports.armed, VideoTrigger.auto, reason: 'this version\'s report is still due');
  });

  test('a build without a DSN takes no report (outside a diagnostics build)', () async {
    await start(dsn: false);
    expect(reports.canTake, isFalse);
    expect(reports.armed, isNull);
    expect(reports.armButton(), ButtonResult.unavailable);
  });

  test('the event: tags, contexts and the log, scrubbed', () async {
    await start();
    ErrorReports.setNames(['Living Room Jellyfin', 'howard']);
    final platform = _FakePlatform(log: [
      '11-09 20:00:00.000  1234  1250 I flutter : Using the Impeller rendering backend (OpenGLES).',
      '11-09 20:00:01.000  1234  1251 E ExoPlayerImplInternal: Source error for http://192.168.1.20:8096/Videos/abc/stream.mkv?api_key=0123456789abcdef0123456789abcdef&Static=true',
      '11-09 20:00:02.000  1234  1251 I flutter : signed in to Living Room Jellyfin as howard, X-Emby-Token: s3cr3tTok3nValue',
    ].join('\n'));
    reports.platform = platform;
    watch(11);
    await reports.take(_live);
    final event = (await sent.events()).single.json;
    expect(event['message'], anyOf('Video report', containsPair('formatted', 'Video report')));
    expect(event['level'], 'info');
    expect(event['tags'], {
      'area': 'video_report',
      'trigger': 'auto',
      'build_device': 'goldfish_x86_64',
      'gpu': 'Android Emulator OpenGL ES Translator',
      'decoder': 'c2.goldfish.hevc.decoder',
      'producer': 'image_reader',
      'backend': 'OpenGLES',
      'cpu_decode': 'pass',
      'image_reader': 'pass',
      'surface_texture': 'pass',
      'gpu_matrix': 'bt709',
      'screen_match': 'yes',
      'form_factor': anything,
      'renderer': anything,
      'official_build': anything,
    });
    final contexts = event['contexts'] as Map<String, Object?>;
    for (final c in ['video_device', 'video_stream', 'video_picture', 'video_self_test']) {
      expect(contexts, contains(c));
    }
    final selfTest = contexts['video_self_test'] as Map;
    expect(((selfTest['cards'] as Map)['hevc10'] as Map)['cpu_decode'], {'result': 'skipped', 'reason': 'no hardware decoder'});
    expect(platform.released, [90, 91, 90, 91], reason: 'every texture run is released');
    final picture = contexts['video_picture'] as Map;
    expect((picture['texture'] as Map)['grid'], hasLength(144));
    expect((picture['screen'] as Map)['grid'], hasLength(144));
    expect(jsonEncode(contexts), isNot(contains('rgba')), reason: 'no pixels, only measurements');
    final logcat = (event['extra'] as Map)['logcat'] as String;
    expect(logcat, contains('Using the Impeller rendering backend (OpenGLES)'));
    for (final secret in ['192.168.1.20', '0123456789abcdef0123456789abcdef', 's3cr3tTok3nValue', 'Living Room Jellyfin', 'howard']) {
      expect(jsonEncode(event), isNot(contains(secret)), reason: secret);
    }
    expect(logcat, contains('<server>/Videos/abc/stream.mkv'));
  });

  test('the size cap trims the oldest log lines first', () async {
    await start();
    final lines = [for (var i = 0; i < 6000; i++) '11-09 20:00:00.000  1234  1250 I tag     : line $i ${'x' * 60}'];
    reports.platform = _FakePlatform(log: lines.join('\n'));
    watch(11);
    await reports.take(_live);
    final event = (await sent.events()).single;
    expect(event.bytes, lessThan(VideoReports.maxEventBytes));
    final logcat = (event.json['extra'] as Map)['logcat'] as String;
    expect(logcat, endsWith('line 5999 ${'x' * 60}'), reason: 'the newest lines stay');
    expect(logcat, isNot(contains('line 0 ')), reason: 'the oldest go');
  });

  test('an unreadable log is said, and the rest is sent', () async {
    await start();
    reports.platform = _FakePlatform(log: null);
    watch(11);
    await reports.take(_live);
    final event = (await sent.events()).single.json;
    expect((event['extra'] as Map)['logcat'], 'logcat: unavailable');
    expect(event['contexts'], contains('video_self_test'));
  });

  test('a broken import, a working decoder: image_reader fails, cpu_decode passes', () async {
    await start();
    VideoFault.current.value = VideoFault.smearTexture;
    reports.platform = _FakePlatform()..image = _picture(64, 36);
    watch(11);
    await reports.take(_live);
    final tags = (await sent.events()).single.json['tags'] as Map;
    expect(tags['image_reader'], 'fail');
    expect(tags['cpu_decode'], 'pass');
    expect(tags['surface_texture'], 'pass', reason: 'the fault is on the default kind only');
    expect(tags['screen_match'], 'no', reason: 'the smeared texture no longer matches the screen');
  });

  test('a black texture render reads render_empty and the rest still goes', () async {
    await start();
    reports.platform = _FakePlatform()..image = Uint8List(64 * 36 * 4);
    watch(11);
    await reports.take(_live);
    final event = (await sent.events()).single.json;
    final picture = (event['contexts'] as Map)['video_picture'] as Map;
    expect(picture['render_empty'], isTrue);
    expect(picture['screen_match'], 'unknown');
    expect((event['tags'] as Map)['image_reader'], 'skipped');
    expect((event['tags'] as Map)['cpu_decode'], 'pass');
  });

  test('a blurred screen with its colours kept: screen_match is no', () async {
    await start();
    final sharp = _picture(64, 36);
    // The same picture blurred on screen: each 8×6 block its own mean.
    final blurred = Uint8List.fromList(sharp);
    for (var by = 0; by < 36; by += 6) {
      for (var bx = 0; bx < 64; bx += 8) {
        for (var c = 0; c < 3; c++) {
          var sum = 0;
          for (var y = by; y < by + 6; y++) {
            for (var x = bx; x < bx + 8; x++) {
              sum += sharp[(y * 64 + x) * 4 + c];
            }
          }
          for (var y = by; y < by + 6; y++) {
            for (var x = bx; x < bx + 8; x++) {
              blurred[(y * 64 + x) * 4 + c] = (sum / 48).round();
            }
          }
        }
      }
    }
    reports.platform = _BlurredScreen(blurred);
    watch(11);
    await reports.take(_live);
    final event = (await sent.events()).single.json;
    final picture = (event['contexts'] as Map)['video_picture'] as Map;
    expect(picture['screen_share'], greaterThanOrEqualTo(PictureMeasure.screenShare), reason: 'the colours still match');
    expect(picture['screen_detail_ratio'], lessThan(PictureMeasure.screenDetailShare));
    expect((event['tags'] as Map)['screen_match'], 'no');
    expect(picture['tries'], 3, reason: 'a differing pair is taken again before it counts');
  });

  test('a pair taken during a cut is taken again', () async {
    await start();
    final platform = _CutOnce();
    reports.platform = platform;
    watch(11);
    await reports.take(_live);
    final picture = ((await sent.events()).single.json['contexts'] as Map)['video_picture'] as Map;
    expect(picture['tries'], 2);
    expect(picture['screen_match'], 'yes');
  });

  test('CRT effects on: screen_match is effects', () async {
    await start();
    watch(11);
    await reports.take(const LivePicture(
      playerId: 5,
      textureRect: TextureView(Rect.fromLTRB(0, 0, 64, 36), Rect.fromLTRB(0, 0, 1, 1)),
      devicePixelRatio: 1,
      effectsOn: true,
      retro: {'crt': 'consumer'},
    ));
    expect(((await sent.events()).single.json['tags'] as Map)['screen_match'], 'effects');
  });

  test('after a video report, the run can still send its 30 error events', () async {
    await start();
    watch(11);
    await reports.take(_live);
    expect(ErrorReports.limiter.sent, 0, reason: 'the video report used none of the budget');
    for (var i = 0; i < 31; i++) {
      await Sentry.captureException(StateError('error $i'),
          stackTrace: StackTrace.current, withScope: (scope) => scope.setTag('area', 'playback-$i'));
    }
    final events = await sent.events();
    expect(events.where((e) => (e.json['tags'] as Map)['area'] != 'video_report'), hasLength(30));
  });

  test('a release build ignores the fault property', () {
    expect(VideoFault.parse('smear-texture', debuggable: false), VideoFault.none);
    expect(VideoFault.parse('smear-screen', debuggable: false), VideoFault.none);
    expect(VideoFault.parse('smear-texture', debuggable: true), VideoFault.smearTexture);
    expect(VideoFault.parse('smear-screen', debuggable: true), VideoFault.smearScreen);
    expect(VideoFault.parse('', debuggable: true), VideoFault.none);
  });
}
