import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/reporting/error_reports.dart';
import 'package:nightingale_tv/reporting/report_policy.dart';
import 'package:nightingale_tv/reporting/report_scrubber.dart';
import 'package:nightingale_tv/reporting/report_switch.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('ReportScrubber', () {
    final s = ReportScrubber(
      names: ['Living Room Plex', 'plexbox.lan', 'howard', 'Mom', 'Kids', "Howard's Shield"],
      folders: ['/home/howard', '/home/howard/.local/share/com.coffeehauslabs.nightingale_tv'],
    );

    test('Plex part URL loses the address and the token', () {
      final out = s.scrub('Failed to open http://192.168.1.20:32400/library/parts/12/file.mkv?X-Plex-Token=abc123def456ghi789jkl');
      expect(out, contains('<server>/library/parts/12/file.mkv'));
      expect(out, isNot(contains('192.168')));
      expect(out, isNot(contains('abc123def456ghi789jkl')));
      expect(out, isNot(contains('?')));
    });

    test('Plex transcode URL with session and token', () {
      const url = 'https://10-0-0-5.0123456789abcdef0123456789abcdef.plex.direct:32400/video/:/transcode/universal/start.m3u8'
          '?path=%2Flibrary%2Fmetadata%2F55&session=abcd&X-Plex-Token=Zx9yQ2pL7mN4vB8cK1dF&X-Plex-Client-Identifier=nightingale';
      final out = s.scrub('HLS failed: $url');
      expect(out, 'HLS failed: <server>/video/:/transcode/universal/start.m3u8');
    });

    test('Jellyfin stream URL with api_key', () {
      const url = 'http://jellyfin.local:8096/Videos/3f1a9c2d4b5e6f708192a3b4c5d6e7f8/stream.mkv'
          '?Static=true&api_key=0123456789abcdef0123456789abcdef&DeviceId=TmlnaHRpbmdhbGU3';
      final out = s.scrub('Open failed for $url.');
      expect(out, 'Open failed for <server>/Videos/<redacted>/stream.mkv.');
    });

    test('Emby URL, header and JSON token', () {
      final out = s.scrub('https://emby.example.com:8920/emby/Videos/123/master.m3u8?api_key=deadbeefdeadbeefdeadbeef00');
      expect(out, '<server>/emby/Videos/123/master.m3u8');
      final header = s.scrub(
          'X-Emby-Authorization: MediaBrowser Client="Nightingale TV", Device="Howard\'s Shield", DeviceId="x", Version="1.2.2", Token="a1b2c3"');
      expect(header, 'X-Emby-Authorization: <redacted>');
      expect(s.scrub('{"AccessToken":"9f8e7d6c5b4a","User":{"Name":"howard"}}'),
          '{"AccessToken":"<redacted>","User":{"Name":"<name>"}}');
    });

    test('relative URLs and key=value pairs lose their secrets', () {
      expect(s.scrub('GET /Items?api_key=abc&Recursive=true'), 'GET /Items?api_key=<redacted>&Recursive=true');
      expect(s.scrub('password: hunter2'), 'password: <redacted>');
      expect(s.scrub('X-Plex-Token: short1'), 'X-Plex-Token: <redacted>');
    });

    test('bare addresses', () {
      expect(s.scrub('Connection refused (OS Error), address = 192.168.1.20, port = 51234'),
          'Connection refused (OS Error), address = <server>, port = 51234');
      expect(s.scrub('to [fe80::1]:8096 failed'), 'to <server> failed');
    });

    test('household names as whole words, any case', () {
      expect(s.scrub('Signed in to Living Room Plex as Howard'), 'Signed in to <name> as <name>');
      expect(s.scrub('Profile mom started; Kids next'), 'Profile <name> started; <name> next');
      expect(s.scrub('Moment of truth'), 'Moment of truth', reason: 'only whole words');
      expect(s.scrub('host plexbox.lan unreachable'), 'host <name> unreachable');
    });

    test('file paths under home and app data', () {
      expect(s.scrub('Cannot open file, path = \'/home/howard/.local/share/com.coffeehauslabs.nightingale_tv/profiles/1.json\''),
          'Cannot open file, path = \'~/profiles/1.json\'');
      expect(s.scrub('/home/someone/Videos/a.mkv'), '~/Videos/a.mkv');
      expect(s.scrub('/data/user/0/com.coffeehauslabs.nightingale_tv/files/x.json'), '~/files/x.json');
      expect(s.scrub('file:///home/howard/x.log'), 'file://~/x.log');
    });

    test('stack frames and versions are left readable', () {
      const frame = '#0      Tuner._open (package:nightingale_tv/playback/tuner.dart:812:7)';
      expect(s.scrub(frame), frame);
      expect(s.scrub('nightingale-tv@1.2.2'), 'nightingale-tv@1.2.2');
    });

    test('a whole event: message, exception, frames, breadcrumbs, tags, contexts', () {
      final event = SentryEvent(
        message: SentryMessage('Failed http://192.168.1.20:32400/x?X-Plex-Token=abc123def456ghi789jkl for Mom'),
        exceptions: [
          SentryException(
            type: 'ServerException',
            value: 'Living Room Plex answered 500',
            stackTrace: SentryStackTrace(frames: [
              SentryStackFrame(absPath: 'file:///home/howard/src/a.dart', fileName: 'a.dart', function: 'f'),
            ]),
          ),
        ],
        breadcrumbs: [Breadcrumb(category: 'server', message: 'howard signed in', data: {'url': 'http://plexbox.lan:32400/?token=1'})],
        tags: {'note': 'Kids'},
        user: SentryUser(id: 'u1', ipAddress: '1.2.3.4'),
        serverName: 'howard-pc',
        contexts: Contexts(device: SentryDevice(name: "Howard's Shield", model: 'SHIELD Android TV')),
      );
      s.scrubEvent(event);
      final json = jsonEncode(event.toJson());
      for (final leak in ['192.168', 'abc123', 'Mom', 'Living Room', 'howard', 'Kids', 'plexbox', '1.2.3.4', 'Shield"']) {
        expect(json, isNot(contains(leak)), reason: leak);
      }
      expect(event.user, isNull);
      expect(event.contexts.device!.model, 'SHIELD Android TV');
    });
  });

  group('ReportPolicy', () {
    test('network, timeout and rejected sign-ins are expected', () {
      expect(ReportPolicy.isExpected(const SocketException('refused')), isTrue);
      expect(ReportPolicy.isExpected(TimeoutException('slow')), isTrue);
      expect(ReportPolicy.isExpected(http.ClientException('closed')), isTrue);
      expect(ReportPolicy.isExpected(ServerException('no answer')), isTrue);
      expect(ReportPolicy.isExpected(ServerException('wrong password', statusCode: 401)), isTrue);
      expect(ReportPolicy.isExpected(ServerException('forbidden', statusCode: 403)), isTrue);
    });

    test('code errors and server faults are not', () {
      expect(ReportPolicy.isExpected(StateError('bad')), isFalse);
      expect(ReportPolicy.isExpected(const FormatException('json')), isFalse);
      expect(ReportPolicy.isExpected(ServerException('server error', statusCode: 500)), isFalse);
    });

    SentryEvent eventAt(String function, {String type = 'StateError', String area = 'playback'}) => SentryEvent(
          tags: {'area': area},
          exceptions: [
            SentryException(
                type: type,
                value: 'x',
                stackTrace: SentryStackTrace(frames: [
                  SentryStackFrame(function: 'main', absPath: 'package:nightingale_tv/main.dart', fileName: 'main.dart'),
                  SentryStackFrame(function: function, absPath: 'package:nightingale_tv/playback/tuner.dart', fileName: 'tuner.dart'),
                  SentryStackFrame(function: 'List.[]', absPath: 'dart:core', fileName: 'list.dart'),
                ])),
          ],
        );

    test('fingerprint: type, area and the top frame in the app', () {
      expect(ReportPolicy.fingerprint(eventAt('Tuner._open')), 'StateError|playback|Tuner._open@tuner.dart');
      expect(ReportPolicy.fingerprint(eventAt('Tuner._open')), isNot(ReportPolicy.fingerprint(eventAt('Tuner._advance'))));
      expect(ReportPolicy.fingerprint(eventAt('Tuner._open', area: 'library')),
          isNot(ReportPolicy.fingerprint(eventAt('Tuner._open'))));
    });
  });

  group('ReportLimiter', () {
    test('one per error per 10 minutes', () {
      var now = DateTime(2026, 11, 9, 20);
      final l = ReportLimiter(now: () => now);
      expect(l.admit('a'), isNull);
      now = now.add(const Duration(minutes: 9, seconds: 59));
      expect(l.admit('a'), isNotNull);
      expect(l.admit('b'), isNull, reason: 'another error goes');
      now = now.add(const Duration(seconds: 1));
      expect(l.admit('a'), isNull);
    });

    test('a broken stream retried every program for an hour sends at most 6', () {
      var now = DateTime(2026, 11, 9, 20);
      final l = ReportLimiter(now: () => now);
      var sent = 0;
      for (var minute = 0; minute < 60; minute++) {
        if (l.admit('stream') == null) sent++;
        now = now.add(const Duration(minutes: 1));
      }
      expect(sent, 6);
    });

    test('at most 30 per run, test reports included', () {
      final l = ReportLimiter();
      for (var i = 0; i < 30; i++) {
        expect(l.admit('e$i'), isNull);
      }
      expect(l.admit('another'), isNotNull);
      expect(l.admit('test', test: true), isNotNull);
    });

    test('test reports skip the per-error limit', () {
      final l = ReportLimiter();
      expect(l.admit('t', test: true), isNull);
      expect(l.admit('t', test: true), isNull);
    });
  });

  group('ErrorReports.filter', () {
    late Directory dir;
    late AppStorage storage;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('reports');
      storage = await AppStorage.at(dir);
      ReportSwitch.instance.reset();
      await ReportSwitch.instance.load(storage);
      await ErrorReports.debugReset();
      ErrorReports.setNames(['Mom']);
    });
    tearDown(() async {
      await pumpEventQueue();
      await storage.flush();
      await ErrorReports.debugReset();
      ReportSwitch.instance.reset();
      await dir.delete(recursive: true);
    });

    SentryEvent event(Object thrown, {String? area}) => SentryEvent(
          throwable: thrown,
          tags: {'area': ?area},
          exceptions: [SentryException(type: '${thrown.runtimeType}', value: '$thrown for Mom', throwable: thrown)],
        );

    test('sends unexpected errors scrubbed, tags uncaught ones, and keeps the ID', () async {
      final e = event(StateError('boom'));
      final out = ErrorReports.filter(e, Hint());
      expect(out, isNotNull);
      expect(out!.tags!['area'], 'uncaught');
      expect(out.exceptions!.single.value, 'Bad state: boom for <name>');
      await pumpEventQueue();
      expect(ReportSwitch.instance.lastId, e.eventId.toString());
    });

    test('drops expected errors and repeats', () {
      expect(ErrorReports.filter(event(const SocketException('x'), area: 'library'), Hint()), isNull);
      expect(ErrorReports.filter(event(StateError('a'), area: 'playback'), Hint()), isNotNull);
      expect(ErrorReports.filter(event(StateError('a'), area: 'playback'), Hint()), isNull);
    });

    test('nothing goes while the switch is off', () async {
      await ReportSwitch.instance.setOn(false);
      expect(ErrorReports.filter(event(StateError('a')), Hint()), isNull);
    });

    test('breadcrumbs: own categories only, scrubbed', () {
      expect(ErrorReports.filterBreadcrumb(Breadcrumb(category: 'http', message: 'GET x'), Hint()), isNull);
      expect(ErrorReports.filterBreadcrumb(Breadcrumb(category: 'console', message: 'print'), Hint()), isNull);
      expect(ErrorReports.filterBreadcrumb(Breadcrumb(category: 'server', message: 'Mom signed in'), Hint())!.message,
          '<name> signed in');
    });

    test('Android 8 and later run the Android SDK; Android 7 and Linux the Dart one', () {
      addTearDown(PlatformInfo.debugReset);
      expect(ErrorReports.usesAndroidSdk, isFalse, reason: 'Linux');
      PlatformInfo.debugOverride = TargetPlatform.android;
      PlatformInfo.debugAndroidSdk = 24;
      expect(ErrorReports.usesAndroidSdk, isFalse);
      PlatformInfo.debugAndroidSdk = 26;
      expect(ErrorReports.usesAndroidSdk, isTrue);
    });

    test('a build without a DSN is not available', () {
      expect(ErrorReports.available, ErrorReports.dsn.isNotEmpty);
      ErrorReports.debugDsn = '';
      expect(ErrorReports.available, isFalse);
    });
  });

  group('ReportSwitch', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('switch');
      ReportSwitch.instance.reset();
    });
    tearDown(() async {
      ReportSwitch.instance.reset();
      await dir.delete(recursive: true);
    });

    test('on by default, saved beside the profiles with the last report', () async {
      final storage = await AppStorage.at(dir);
      await ReportSwitch.instance.load(storage);
      expect(ReportSwitch.instance.on, isTrue);
      await ReportSwitch.instance.setOn(false);
      await ReportSwitch.instance.sent('3fa9c2d1e4b5469788c0a1b2c3d4e5f6');
      await storage.flush();
      ReportSwitch.instance.reset();
      await ReportSwitch.instance.load(await AppStorage.at(dir));
      expect(ReportSwitch.instance.on, isFalse);
      expect(ReportSwitch.instance.shortLastId, '3fa9c2d1');
      expect(File('${dir.path}/${ReportSwitch.file}').existsSync(), isTrue);
    });
  });
}
