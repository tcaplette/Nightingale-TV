import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/broadcast_art.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/plex/plex_account.dart';
import 'package:nightingale_tv/server/server_log.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/setup/accounts.dart';
import 'package:nightingale_tv/setup/server_db.dart';
import 'package:nightingale_tv/setup/setup_server.dart';
import 'package:nightingale_tv/setup/web_files.dart';

import '../integration_test/fake_jellyfin.dart';
import 'fixtures.dart';
import 'setup_client.dart';
import 'login_screen_test.dart' show FakePlexAccount, server;

void main() {
  late Directory dir;
  late Household household;
  late Accounts auth;
  late SetupServer setup;
  late Client client;
  final iterations = Accounts.iterations;
  final log = <String>[];

  setUpAll(() => Accounts.iterations = 1000);
  tearDownAll(() => Accounts.iterations = iterations);

  setUp(() async {
    BackupArchive.useIsolate = false;
    log.clear();
    ServerLog.output = log.add;
    dir = await Directory.systemTemp.createTemp('nightingale_tv_setup');
    household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
    household.backups = BackupScheduler(household, BackupStore(Directory('${dir.path}/backups')));
    auth = await Accounts.load(dir);
  });

  tearDown(() async {
    client.close();
    await setup.stop();
    await household.export?.stop();
    for (final p in household.profiles) {
      final app = household.appFor(p.id);
      for (var i = 0; app != null && i < 200 && app.phase == AppPhase.starting; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    await household.closeAll();
    auth.close();
    await dir.delete(recursive: true);
    BackupArchive.useIsolate = true;
    ServerLog.reset();
  });

  /// Starts the page (and the household, unless [startHousehold] is false).
  Future<void> open(
      {bool startHousehold = true, String? lanHost, SignInFlow Function(AppState)? flow, Directory? web}) async {
    setup = SetupServer(household, auth,
        port: 0, lanHost: lanHost, signInFlow: flow, web: WebFiles(web ?? Directory('${dir.path}/no_web')));
    await setup.start();
    client = Client(setup.boundPort!);
    if (startHousehold) await household.start();
  }

  /// Export with one profile, [id], exported on a free port (never 5004–5009,
  /// which other tests use).
  Future<ExportService> exportWith(String id, {bool discovery = true}) async {
    final port = await freePort();
    await household.root.writeJson('export.json',
        ExportSettings.off.withExported(id, true, portFree: (p) => p == port).toJson());
    final export = household.export = ExportService(household,
        ssdp: () => SsdpResponder()
          ..sendOverride = (d, _, _) {
            if (!discovery) throw const SocketException('UDP 1900 is taken');
          },
        art: BroadcastArt(Directory('${dir.path}/cache')));
    await export.load();
    return export;
  }

  /// Makes the first admin, "sam", with the setup token.
  Future<void> setPassword([String password = 'correct horse']) async {
    final r = await client.post('/api/v1/password', {'token': auth.setupToken, 'name': 'sam', 'password': password});
    expect(r.status, 200, reason: '${r.json}');
  }

  group('address and health (4.1)', () {
    test('a public address is refused with 403', () async {
      await open();
      setup.allowed = (_) => false;
      expect((await client.get('/')).status, 403);
      expect((await client.get('/health')).status, 403);
    });

    test('health is 503 until the household has started, then 200', () async {
      await open(startHousehold: false);
      final before = await client.get('/health');
      expect(before.status, 503);
      await household.start();
      final after = await client.get('/health');
      expect(after.status, 200);
      expect(after.json, {'status': 'ok'});
    });

    test('a taken port fails to start', () async {
      final taken = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      addTearDown(taken.close);
      final other = SetupServer(household, auth, port: taken.port);
      await expectLater(other.start(), throwsA(isA<SocketException>()));
      await open();
    });
  });

  group('web admin files (1.3)', () {
    late Directory web;

    Future<void> openWithBundle() async {
      web = Directory('${dir.path}/web')..createSync();
      File('${web.path}/index.html').writeAsStringSync('<!DOCTYPE html><script src="flutter_bootstrap.js"></script>');
      File('${web.path}/flutter_bootstrap.js').writeAsStringSync('// boot');
      Directory('${web.path}/canvaskit').createSync();
      File('${web.path}/canvaskit/canvaskit.wasm').writeAsBytesSync([0, 97, 115, 109]);
      await open(web: web);
    }

    test('page paths get index.html; files are served with their types', () async {
      await openWithBundle();
      for (final path in ['/', '/setup?token=abc', '/profiles/p1/channels', '/profiles/p1/channels/live:src1:2.1']) {
        final page = await client.get(path);
        expect(page.status, 200, reason: path);
        expect(utf8.decode(page.bytes), contains('flutter_bootstrap.js'), reason: path);
        expect(page.headers.contentType?.mimeType, 'text/html', reason: path);
      }
      final wasm = await client.get('/canvaskit/canvaskit.wasm');
      expect(wasm.headers.value('content-type'), 'application/wasm');
      expect(wasm.bytes, [0, 97, 115, 109]);
      expect((await client.get('/canvaskit/missing.js')).status, 404);
      File('${dir.path}/secret.txt').writeAsStringSync('secret');
      for (final path in ['/../secret.txt', '/%2e%2e/secret.txt', '/canvaskit/%2e%2e%2f%2e%2e%2fsecret.txt']) {
        expect(utf8.decode((await client.get(path)).bytes), isNot(contains('secret')), reason: path);
      }
    });

    test('/api/... never falls back to index.html', () async {
      await openWithBundle();
      for (final path in ['/api/v1/nothing', '/api/v2/status', '/api']) {
        final r = await client.get(path);
        expect(r.status, anyOf(401, 404), reason: path);
        expect(utf8.decode(r.bytes), isNot(contains('flutter_bootstrap')), reason: path);
      }
    });

    test('a matching ETag is answered 304; index.html and the bootstrap are no-cache without one', () async {
      await openWithBundle();
      final first = await client.get('/canvaskit/canvaskit.wasm');
      final etag = first.headers.value(HttpHeaders.etagHeader);
      expect(etag, isNotNull);
      final again = await client.call('GET', '/canvaskit/canvaskit.wasm', headers: {'If-None-Match': etag!});
      expect(again.status, 304);
      expect(again.bytes, isEmpty);
      final changed = await client.call('GET', '/canvaskit/canvaskit.wasm', headers: {'If-None-Match': '"old"'});
      expect(changed.status, 200);
      for (final path in ['/', '/flutter_bootstrap.js']) {
        final r = await client.get(path);
        expect(r.headers.value('cache-control'), 'no-cache', reason: path);
        expect(r.headers.value(HttpHeaders.etagHeader), isNull, reason: path);
      }
    });

    test('every page response has the CSP, nosniff and no-referrer headers', () async {
      await openWithBundle();
      for (final path in ['/', '/setup?token=abc', '/flutter_bootstrap.js', '/canvaskit/canvaskit.wasm', '/x/y']) {
        final r = await client.get(path);
        expect(r.headers.value('content-security-policy'), WebFiles.contentSecurityPolicy, reason: path);
        expect(r.headers.value('content-security-policy'), contains("connect-src 'self' blob:;"));
        expect(r.headers.value('x-content-type-options'), 'nosniff', reason: path);
        expect(r.headers.value('referrer-policy'), 'no-referrer', reason: path);
      }
    });

    test("without a bundle, pages say it isn't in this build and the API still works", () async {
      await open();
      final page = await client.get('/setup?token=abc');
      expect(page.status, 200);
      expect(utf8.decode(page.bytes), contains(WebFiles.missingText));
      expect(page.headers.value('content-security-policy'), WebFiles.contentSecurityPolicy);
      expect((await client.get('/api/v1/auth')).status, 200);
    });
  });

  group('admin sign-in (4.2)', () {
    test('first start: only health without the token; the setup link has it', () async {
      await open();
      setup.logSetupLink('192.168.1.20');
      expect(log.single, endsWith('Open http://192.168.1.20:${setup.port}/setup?token=${auth.setupToken} to set up Nightingale TV.'));
      expect((await client.get('/api/v1/auth')).json, {'password': false, 'signedIn': false});
      expect((await client.get('/api/v1/status')).status, 401);
      final wrong = await client.post('/api/v1/password', {'token': 'guess', 'password': 'correct horse'});
      expect(wrong.status, 403);
      expect((wrong.json! as Map)['error'], "Open the setup link from the server's log.");
    });

    test('setting the password signs in; the token stops working; later visits ask for it', () async {
      await open();
      final token = auth.setupToken!;
      final short = await client.post('/api/v1/password', {'token': token, 'password': 'short'});
      expect((short.json! as Map)['error'], 'Use at least 8 characters.');
      await setPassword();
      final set = client.cookie!;
      expect((await client.get('/api/v1/status')).status, 200);
      final again = await client.post('/api/v1/password', {'token': token, 'password': 'another one'});
      expect(again.status, 403, reason: 'the token stopped working');
      // A later visit, without the cookie.
      client.cookie = null;
      expect((await client.get('/api/v1/auth')).json, {'password': true, 'signedIn': false});
      expect((await client.get('/api/v1/status')).status, 401);
      expect((await client.post('/api/v1/session', {'name': 'sam', 'password': 'correct horse'})).status, 200);
      expect((await client.get('/api/v1/status')).status, 200);
      expect(client.cookie, isNot(set));
      // The cookie is HttpOnly and SameSite=Strict, for 30 days.
      final r = await client.post('/api/v1/session', {'name': 'SAM', 'password': 'correct horse'});
      final setCookie = r.headers[HttpHeaders.setCookieHeader]!.single;
      expect(setCookie, allOf(contains('HttpOnly'), contains('SameSite=Strict'), contains('Max-Age=2592000')));
      // Stored only as a salted PBKDF2 hash.
      final saved = auth.db.db.select("SELECT * FROM users WHERE name = 'sam'").single;
      expect(saved['role'], 'admin');
      expect(saved['pw_hash'], isNot(contains('correct horse')));
      expect(saved['pw_iter'], greaterThanOrEqualTo(1000));
      // Signing out ends the session.
      await client.call('DELETE', '/api/v1/session');
      expect((await client.get('/api/v1/status')).status, 401);
    });

    test('the real hash is PBKDF2-HMAC-SHA256 with 150,000 rounds', () {
      expect(iterations, 150000);
      String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      // RFC 7914 / RFC 6070-style vectors for SHA-256.
      expect(hex(Accounts.pbkdf2(utf8.encode('password'), utf8.encode('salt'), 1)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(hex(Accounts.pbkdf2(utf8.encode('password'), utf8.encode('salt'), 4096)),
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });

    test('6 wrong passwords in a minute: the 6th and the right one are refused for a minute', () async {
      var now = DateTime(2026, 10, 22, 20);
      auth.close();
      auth = await Accounts.load(dir, clock: () => now);
      await open();
      await setPassword();
      client.cookie = null;
      for (var i = 0; i < 5; i++) {
        expect((await client.post('/api/v1/session', {'name': 'sam', 'password': 'wrong $i'})).status, 403);
      }
      final sixth = await client.post('/api/v1/session', {'name': 'sam', 'password': 'wrong 6'});
      expect(sixth.status, 429);
      final right = await client.post('/api/v1/session', {'name': 'sam', 'password': 'correct horse'});
      expect(right.status, 429, reason: 'refused even with the right password');
      now = now.add(const Duration(seconds: 61));
      expect((await client.post('/api/v1/session', {'name': 'sam', 'password': 'correct horse'})).status, 200);
    });

    test('NTV_RESET_PASSWORD: sessions stop working and a new setup link is made', () async {
      await open();
      await setPassword();
      final session = client.cookie!;
      expect(auth.accountFor(session), isNotNull);
      auth.close();
      final reset = auth = await Accounts.load(dir, reset: true);
      expect(reset.hasUsers, isTrue);
      expect(reset.accountFor(session), isNull);
      expect(reset.setupToken, isNotNull);
      expect(reset.setupToken!.length, 32, reason: '128 bits');
    });

    test('a change without the custom header is refused and nothing changes', () async {
      await open();
      await setPassword();
      final before = household.profiles.length;
      final r = await client.call('POST', '/api/v1/profiles', body: {'name': 'Sneaky'}, header: false);
      expect(r.status, 403);
      final upload = await client.call('POST', '/api/v1/restore', bytes: [1, 2, 3], header: false);
      expect(upload.status, 403);
      expect(household.profiles.length, before);
    });

    test("a backup never carries the account database, and a restore keeps the server's passwords", () async {
      await open();
      await setPassword();
      final saved = auth.db.db.select('SELECT * FROM users').single;
      final hash = saved['pw_hash'] as String;
      final salt = saved['pw_salt'] as String;
      final download = await client.get('/api/v1/backup');
      expect(download.status, 200);
      final text = utf8.decode(BackupArchive.gunzip(download.bytes));
      expect(text, isNot(contains(hash)));
      expect(text, isNot(contains(salt)));
      expect(text, isNot(contains(ServerDb.fileName)));
      await BackupRestorer(household).restore(download.bytes);
      expect(auth.db.db.select('SELECT pw_hash FROM users').single['pw_hash'], hash);
    });
  });

  group('status (4.3)', () {
    test('bridge network: NTV_LAN_HOST in the URLs, and the discovery message', () async {
      await open(lanHost: '192.168.1.20');
      await setPassword();
      final mom = household.profiles.single..name = 'Mom';
      await household.saveProfile(mom);
      final export = await exportWith(mom.id, discovery: false);
      final port = export.settings.profiles[mom.id]!.port;
      final status = (await client.get('/api/v1/status')).json! as Map<String, Object?>;
      final p = (status['profiles']! as List).single as Map<String, Object?>;
      expect(p['name'], 'Mom');
      expect(p['url'], 'http://192.168.1.20:$port');
      expect(p['m3u'], 'http://192.168.1.20:$port/lineup.m3u');
      expect(p['xmltv'], 'http://192.168.1.20:$port/xmltv.xml');
      expect(p['signedIn'], isFalse);
      expect(p['problem'], 'Sign in to this profile here to export its channels.');
      expect(status['discovery'], isFalse);
      expect(status['discoveryMessage'],
          'Discovery is off, so add the tuner by address. Run the container with host networking to turn it on.');
      expect(status['streams'], 0);
      expect(status['canStartFresh'], isTrue);
    });

    test('without NTV_LAN_HOST, URLs use the host the browser used', () async {
      await open();
      await setPassword();
      final export = await exportWith(household.profiles.single.id);
      final port = export.settings.profiles[household.profiles.single.id]!.port;
      final status = (await client.get('/api/v1/status')).json! as Map<String, Object?>;
      expect(((status['profiles']! as List).single as Map)['url'], 'http://127.0.0.1:$port');
    });
  });

  group('restore (4.4)', () {
    /// A backup from a Linux PC with "Mom" exported on [port], signed in.
    Future<List<int>> pcBackup(int port) async {
      final pc = await Directory.systemTemp.createTemp('nightingale_tv_pc');
      addTearDown(() => pc.delete(recursive: true));
      final h = Household(await AppStorage.at(pc), runAnalysis: false);
      await h.start();
      h.leave();
      final mom = h.profiles.single..name = 'Mom';
      await h.saveProfile(mom);
      await (await signedInApp((await h.storageFor(mom)).root, fakeLibrary(), serverId: 'srv')).close();
      final settings = ExportSettings.off.copyWith(enabled: true).withExported(mom.id, true, portFree: (p) => p == port);
      await h.root.writeJson('export.json', settings.toJson());
      await h.flushAll();
      final built = await BackupArchive.build(pc, reason: BackupReason.manual, device: 'living-room-pc');
      return built.bytes;
    }

    test('moving from the TV: the summary, then the same tuner on the same port', () async {
      await open();
      await setPassword();
      await exportWith(household.profiles.single.id);
      final port = await freePort();
      final bytes = await pcBackup(port);
      final deviceId = (ExportSettings.fromJson(BackupArchive.check(bytes).export).profiles.values.single).deviceId;

      final up = await client.call('POST', '/api/v1/restore', bytes: bytes);
      expect(up.status, 200, reason: '${up.json}');
      final summary = up.json! as Map<String, Object?>;
      expect(summary['device'], 'living-room-pc');
      expect(summary['profiles'], ['Mom']);
      expect(summary['channels'], greaterThan(0));
      expect(summary['needSignIn'], ['Mom']);
      expect(household.profiles.single.name, isNot('Mom'), reason: 'nothing restored before Restore');

      final done = await client.post('/api/v1/restore/${summary['id']}/confirm');
      expect(done.status, 200, reason: '${done.json}');
      expect(household.profiles.single.name, 'Mom');
      final export = household.export!;
      final mom = household.profiles.single;
      expect(export.settings.profiles[mom.id]!.port, port);
      expect(export.settings.profiles[mom.id]!.deviceId, deviceId);
      expect(export.serverOf(mom.id)?.port, port);
      final p = ((done.json! as Map)['profiles'] as List).single as Map<String, Object?>;
      expect(p['signedIn'], isFalse);
      expect((p['hint']! as Map)['user'], 'tester');
      expect(log.any((l) => l.contains('Restored the backup from') && l.contains('living-room-pc')), isTrue);
    });

    test("a file that isn't a backup says why, and nothing changes", () async {
      await open();
      await setPassword();
      final before = household.profiles.single.id;
      final r = await client.call('POST', '/api/v1/restore', bytes: utf8.encode('hello, not a backup'));
      expect(r.status, 400);
      expect((r.json! as Map)['error'], BackupArchive.damaged);
      expect(household.profiles.single.id, before);
      expect((await client.post('/api/v1/restore/0/confirm')).status, 404);
    });

    test('an upload over 32 MB is refused', () async {
      await open();
      await setPassword();
      // Turned down on its stated length, without keeping it.
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, setup.boundPort!);
      socket.write('POST /api/v1/restore HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Nightingale-TV: 1\r\n'
          'Cookie: ${SetupServer.sessionCookie}=${client.cookie}\r\nContent-Length: ${SetupServer.maxUpload + 1}\r\n\r\n');
      socket.add(Uint8List(SetupServer.maxUpload + 1));
      await socket.flush();
      final answer = utf8.decode(await socket.first.timeout(const Duration(seconds: 10)));
      expect(answer, startsWith('HTTP/1.1 413'));
      expect(answer, contains(BackupArchive.tooBig));
      socket.destroy();
    });
  });

  group('start fresh and sign-in (4.5)', () {
    test('Start fresh names the profile, signs in to Jellyfin, generates channels and exports them', () async {
      final jellyfin = await FakeJellyfin.start(fakeItems());
      addTearDown(jellyfin.close);
      await open();
      await setPassword();
      final export = await exportWith(household.profiles.single.id);

      final made = await client.post('/api/v1/profiles', {'name': 'Home'});
      expect(made.status, 200, reason: '${made.json}');
      final id = (made.json! as Map)['id'] as String;
      expect(household.profiles.single.name, 'Home', reason: "the new install's empty profile");

      var step = (await client.post('/api/v1/profiles/$id/sign-in', {'action': 'start'})).json! as Map;
      expect(step['stage'], 'server');
      step = (await client.post('/api/v1/profiles/$id/sign-in', {'action': 'connect', 'address': jellyfin.url})).json! as Map;
      expect(step['stage'], 'method');
      step = (await client.post('/api/v1/profiles/$id/sign-in', {'action': 'choosePassword'})).json! as Map;
      expect(step['stage'], 'password');

      step = (await client.post('/api/v1/profiles/$id/sign-in', {'action': 'password', 'user': 'howard', 'password': 'wrong one'})).json! as Map;
      expect(step['error'], 'Wrong username or password, or the session expired.');
      expect(step['finished'], isFalse);

      step = (await client.post('/api/v1/profiles/$id/sign-in',
          {'action': 'password', 'user': 'howard', 'password': FakeJellyfin.password})).json! as Map;
      expect(step['finished'], isTrue, reason: '$step');
      await pumpEventQueue();
      final app = household.appFor(id)!;
      expect(app.phase, AppPhase.ready);
      expect(app.channels, isNotEmpty, reason: 'generated as on the TV');
      expect(export.settings.isExported(id), isTrue);
      final port = export.serverOf(id)!.port!;
      final lineup = await HttpClient().getUrl(Uri.parse('http://127.0.0.1:$port/lineup.json')).then((r) => r.close());
      final channels = jsonDecode(await utf8.decodeStream(lineup)) as List;
      expect(channels, hasLength(app.channels.where((c) => !c.hidden).length));

      final status = (await client.get('/api/v1/status')).json! as Map;
      final p = (status['profiles'] as List).single as Map;
      expect((p['signedIn'], p['user'], p['problem']), (true, 'howard', null));
      expect(status['canStartFresh'], isFalse);
      final everything = [...log, jsonEncode(status)].join('\n');
      expect(everything, isNot(contains(FakeJellyfin.accessToken)));
      expect(everything, isNot(contains(FakeJellyfin.password)));
      expect(everything, isNot(contains('correct horse')));
    });

    test('a restored Jellyfin profile has its server and user name filled in', () async {
      final jellyfin = await FakeJellyfin.start(fakeItems());
      addTearDown(jellyfin.close);
      await open();
      await setPassword();
      final p = household.profiles.single;
      final storage = await household.storageFor(p);
      await storage.writeJson(BackupArchive.signInHintFile,
          {'kind': 'jellyfin', 'serverUrl': jellyfin.url, 'serverName': 'Fake', 'userName': 'mom', 'serverId': FakeJellyfin.serverId});
      final step = (await client.post('/api/v1/profiles/${p.id}/sign-in', {'action': 'start'})).json! as Map;
      expect(step['stage'], 'password', reason: 'only the password is asked');
      expect(step['hint'], {'server': jellyfin.url, 'user': 'mom', 'plex': false});
    });

    test("a restored Plex profile: the code, then the hint's server and Home user without a list", () async {
      final account = FakePlexAccount(
        users: const [
          PlexHomeUser(id: '1', uuid: 'dad', title: 'Dad', admin: true),
          PlexHomeUser(id: '2', uuid: 'kids', title: 'Kids'),
        ],
        serverList: [server('Basement', 'm1'), server('Attic', 'm2')],
      );
      final finished = <String?>[];
      await open(
          flow: (app) => SignInFlow(app,
              plexAccount: account,
              pickPlexConnection: (s) async => s.connections.first,
              completeSignIn: (session, _) async => finished.add(session.serverId)));
      await setPassword();
      final p = household.profiles.single;
      await (await household.storageFor(p)).writeJson(BackupArchive.signInHintFile,
          {'kind': 'plex', 'serverUrl': 'http://m2.local:32400', 'serverId': 'm2', 'userId': '2', 'userName': 'Kids'});
      var step = (await client.post('/api/v1/profiles/${p.id}/sign-in', {'action': 'start'})).json! as Map;
      expect(step['stage'], 'plexCode');
      expect(step['plexCode'], 'K7Q1');
      await Future<void>.delayed(SignInFlow.plexPoll + const Duration(milliseconds: 300));
      step = (await client.get('/api/v1/profiles/${p.id}/sign-in')).json! as Map;
      expect(step['finished'], isTrue);
      expect(finished, ['m2']);
      expect(account.switched, ['kids']);
    });

    test("a profile with a PIN: a user gives it once before signing in; an admin isn't asked", () async {
      await open();
      await setPassword();
      final p = household.profiles.single..setPin('1234');
      await household.saveProfile(p);
      expect((await client.post('/api/v1/profiles/${p.id}/sign-in', {'action': 'start'})).status, 200);
      await auth.addUser(name: 'kim', role: Role.user, password: 'kims password', profiles: {p.id});
      final kim = Client(setup.boundPort!);
      addTearDown(kim.close);
      expect((await kim.post('/api/v1/session', {'name': 'kim', 'password': 'kims password'})).status, 200);
      final locked = await kim.post('/api/v1/profiles/${p.id}/sign-in', {'action': 'start'});
      expect(locked.status, 403);
      expect(locked.json, {'error': SetupServer.pinText, 'needs': 'pin'});
      expect((await kim.post('/api/v1/profiles/${p.id}/unlock', {'pin': '0000'})).status, 403);
      expect((await kim.post('/api/v1/profiles/${p.id}/unlock', {'pin': '1234'})).status, 200);
      expect((await kim.post('/api/v1/profiles/${p.id}/sign-in', {'action': 'start'})).status, 200);
    });
  });

  group('export choices and backup (4.6)', () {
    test("changing a port moves the lineup and keeps its DeviceID; a taken port is an error", () async {
      await open();
      await setPassword();
      final mom = household.profiles.single;
      final export = await exportWith(mom.id);
      final deviceId = export.settings.profiles[mom.id]!.deviceId;
      final to = await freePort();
      final r = await client.edit('PUT', '/api/v1/profiles/${mom.id}/export', body: {'port': to}, revisionOf: '/api/v1/profiles');
      expect(r.status, 200, reason: '${r.json}');
      expect(export.serverOf(mom.id)!.port, to);
      expect(export.settings.profiles[mom.id]!.deviceId, deviceId);

      final kid = household.newProfile()..name = 'Dad';
      kid.setPin('4321');
      await household.saveProfile(kid);
      // Admins are grown-ups by role: no PIN asked.
      final noPin = await client.edit('PUT', '/api/v1/profiles/${kid.id}/export',
          body: {'exported': true}, revisionOf: '/api/v1/profiles');
      expect(noPin.status, 200);
      final stale = await client.call('PUT', '/api/v1/profiles/${kid.id}/export',
          body: {'port': to}, headers: {'If-Match': '"h1"'});
      expect(stale.status, 409);
      final clash = await client.edit('PUT', '/api/v1/profiles/${kid.id}/export', body: {'port': to}, revisionOf: '/api/v1/profiles');
      expect(clash.status, 409);
      expect((clash.json! as Map)['error'], 'Another profile already uses port $to.');
    });

    test('a downloaded backup is named by date and restores in the Linux app', () async {
      await open();
      await setPassword();
      final mom = household.profiles.single..name = 'Mom';
      await household.saveProfile(mom);
      await (await signedInApp((await household.storageFor(mom)).root, fakeLibrary(), serverId: 'srv')).close();
      final download = await client.get('/api/v1/backup');
      expect(download.status, 200);
      final disposition = download.headers.value('content-disposition')!;
      expect(disposition, matches(RegExp(r'filename="nightingale-tv-\d{4}-\d\d-\d\d-\d{4}\.ntvbackup"')));

      // The Linux app (not server mode) restores it.
      final pc = await Directory.systemTemp.createTemp('nightingale_tv_pc_restore');
      addTearDown(() => pc.delete(recursive: true));
      final linux = Household(await AppStorage.at(pc), runAnalysis: false);
      await linux.start();
      await BackupRestorer(linux).restore(download.bytes);
      expect(linux.profiles.single.name, 'Mom');
      final channels = await (await linux.storageFor(linux.profiles.single)).readRaw('channels.json');
      expect(channels, isA<List>().having((l) => l.length, 'channels', greaterThan(0)));
      linux.leave();
      await linux.closeAll();
    });
  });
}
