import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';

import 'fixtures.dart';

/// Moving installs from before the rename (Retro TV → Nightingale TV).
void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_rename'));
  tearDown(() => dir.delete(recursive: true));

  test('device IDs get the new prefix, keeping the same random part', () {
    expect(AppSettings.fresh().installId, startsWith('nightingaletv-'));
    expect(AppSettings.migrateDeviceId('retrotv-0a1b'), 'nightingaletv-0a1b');
    expect(AppSettings.migrateDeviceId('nightingaletv-0a1b'), 'nightingaletv-0a1b');
    expect(AppSettings.fromJson({'installId': 'retrotv-0a1b'}).installId, 'nightingaletv-0a1b');
  });

  group('the data folder', () {
    late Directory legacy;
    late Directory current;

    setUp(() async {
      legacy = Directory('${dir.path}/com.coffeehauslabs.retro_tv');
      current = Directory('${dir.path}/com.coffeehauslabs.nightingale_tv');
      await Directory('${legacy.path}/profiles/p1').create(recursive: true);
      await File('${legacy.path}/profiles.json').writeAsString('[]');
    });

    test('moves to the new name', () async {
      await AppStorage.adoptLegacyData(legacy, current);
      expect(legacy.existsSync(), isFalse);
      expect(File('${current.path}/profiles.json').existsSync(), isTrue);
      expect(Directory('${current.path}/profiles/p1').existsSync(), isTrue);
    });

    test('moves even if an empty new folder was already made', () async {
      await current.create();
      await AppStorage.adoptLegacyData(legacy, current);
      expect(File('${current.path}/profiles.json').existsSync(), isTrue);
    });

    test('never overwrites data already in the new folder', () async {
      await current.create();
      await File('${current.path}/profiles.json').writeAsString('["new"]');
      await AppStorage.adoptLegacyData(legacy, current);
      expect(File('${current.path}/profiles.json').readAsStringSync(), '["new"]');
      expect(legacy.existsSync(), isTrue);
    });
  });

  group('an existing sign-in', () {
    late HttpServer jellyfin;

    /// A server that accepts the new device ID, or (with [accept] false)
    /// rejects it.
    Future<void> startServer({required bool accept, String? serverId}) async {
      jellyfin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      jellyfin.listen((request) async {
        if (request.uri.path == '/System/Info/Public' && serverId != null) {
          request.response.write('{"ServerName":"Home","Version":"10.11.11","Id":"$serverId"}');
          await request.response.close();
          return;
        }
        final auth = request.headers.value('authorization') ?? '';
        final ok = request.uri.path == '/Users/Me' && accept && auth.contains('DeviceId="nightingaletv-0a1b"');
        request.response.statusCode = ok ? 200 : 401;
        request.response.write(ok ? '{"Id":"u1"}' : '');
        await request.response.close();
      });
    }

    tearDown(() => jellyfin.close(force: true));

    // Nothing tunes here; the upgrade waits that long for a launch's picture.
    setUp(() {
      final wait = AppState.launchIdleWait;
      AppState.launchIdleWait = const Duration(milliseconds: 50);
      addTearDown(() => AppState.launchIdleWait = wait);
    });

    Future<AppState> appWithOldSession() async {
      final app = await signedInApp(dir, fakeLibrary());
      await app.storage.writeJson('session.json', {
        'serverUrl': 'http://127.0.0.1:${jellyfin.port}',
        'userId': 'u1',
        'userName': 'tester',
        'accessToken': 'token',
        'deviceId': 'retrotv-0a1b',
      });
      final again = AppState(app.storage);
      await again.start();
      return again;
    }

    Future<String> savedDeviceId(AppState app) async {
      // The switch happens in the background after start-up.
      for (var i = 0; i < 40; i++) {
        final json = await app.storage.readJson('session.json') as Map<String, Object?>;
        if (json['deviceId'] != 'retrotv-0a1b') return json['deviceId'] as String;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return 'retrotv-0a1b';
    }

    test('switches to the new device ID once the server accepts it', () async {
      await startServer(accept: true);
      final app = await appWithOldSession();
      expect(await savedDeviceId(app), 'nightingaletv-0a1b');
      expect(app.session!.deviceId, 'nightingaletv-0a1b');
      expect(app.client!.deviceId, 'nightingaletv-0a1b');
      expect(app.session!.accessToken, 'token', reason: 'still the same sign-in');
    });

    test('records the server id, together with the new device ID', () async {
      await startServer(accept: true, serverId: 'srv-1');
      final app = await appWithOldSession();
      expect(await savedDeviceId(app), 'nightingaletv-0a1b');
      for (var i = 0; i < 40 && app.session!.serverId == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      // Both background updates land, whichever finishes first.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final json = await app.storage.readJson('session.json') as Map<String, Object?>;
      expect(json['serverId'], 'srv-1');
      expect(json['deviceId'], 'nightingaletv-0a1b');
      expect(app.session!.serverId, 'srv-1');
    });

    test('keeps the old one if the server refuses, so nobody is signed out', () async {
      await startServer(accept: false);
      final app = await appWithOldSession();
      expect(await savedDeviceId(app), 'retrotv-0a1b');
      expect(app.session!.deviceId, 'retrotv-0a1b');
      expect(app.phase, AppPhase.ready);
    });
  });
}
