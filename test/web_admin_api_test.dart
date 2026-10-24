import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/server/server_log.dart';
import 'package:nightingale_tv/setup/accounts.dart';
import 'package:nightingale_tv/setup/api/routes.dart';
import 'package:nightingale_tv/setup/setup_server.dart';
import 'package:nightingale_tv/setup/web_files.dart';

import 'setup_client.dart';

/// The web admin's API beyond docker-server-core (docker-web-admin groups
/// 2–4): accounts over HTTP, access rules, PINs, revisions and borrowed
/// profile states.
void main() {
  late Directory dir;
  late Household household;
  late Accounts accounts;
  late SetupServer setup;
  late Client admin;
  final clients = <Client>[];
  final iterations = Accounts.iterations;
  final log = <String>[];

  setUpAll(() => Accounts.iterations = 1000);
  tearDownAll(() => Accounts.iterations = iterations);

  setUp(() async {
    BackupArchive.useIsolate = false;
    log.clear();
    ServerLog.output = log.add;
    dir = await Directory.systemTemp.createTemp('nightingale_tv_web_admin');
    household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
    household.backups = BackupScheduler(household, BackupStore(Directory('${dir.path}/backups')));
    accounts = await Accounts.load(dir);
    setup = SetupServer(household, accounts, port: 0, web: WebFiles(Directory('${dir.path}/no_web')));
    await setup.start();
    await household.start();
    admin = Client(setup.boundPort!);
    clients.add(admin);
  });

  tearDown(() async {
    for (final c in clients) {
      c.close();
    }
    clients.clear();
    await setup.stop();
    for (final p in household.profiles) {
      final app = household.appFor(p.id);
      for (var i = 0; app != null && i < 200 && app.phase == AppPhase.starting; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    await household.closeAll();
    accounts.close();
    await dir.delete(recursive: true);
    BackupArchive.useIsolate = true;
    ServerLog.reset();
  });

  Client newClient() => Client(setup.boundPort!)..let(clients.add);

  /// "sam", the first admin, signed in on [admin].
  Future<void> firstAdmin() async {
    final r = await admin.post('/api/v1/password', {'token': accounts.setupToken, 'name': 'sam', 'password': 'correct horse'});
    expect(r.status, 200, reason: '${r.json}');
  }

  /// Mom (PIN 2222), Dad (PIN 1111), Kim (PIN 3333) and the kid Ava, with
  /// "sam" signed in.
  Future<Map<String, Profile>> family() async {
    await firstAdmin();
    final mom = household.profiles.single
      ..name = 'Mom'
      ..setPin('2222');
    await household.saveProfile(mom);
    final dad = household.newProfile()
      ..name = 'Dad'
      ..setPin('1111');
    await household.saveProfile(dad);
    final kim = household.newProfile()
      ..name = 'Kim'
      ..setPin('3333');
    await household.saveProfile(kim);
    final ava = household.newProfile()
      ..name = 'Ava'
      ..kind = ProfileKind.kid;
    await household.saveProfile(ava);
    return {'mom': mom, 'dad': dad, 'kim': kim, 'ava': ava};
  }

  /// A user account [name] with [profiles], signed in on a new client.
  Future<Client> user(String name, Set<String> profiles) async {
    await accounts.addUser(name: name, role: Role.user, password: '$name password', profiles: profiles);
    final c = newClient();
    final r = await c.post('/api/v1/session', {'name': name, 'password': '$name password'});
    expect(r.status, 200, reason: '${r.json}');
    return c;
  }

  group('start fresh after a restart', () {
    test("a server restarted before it was set up still uses the install's empty profile", () async {
      await firstAdmin();
      final empty = household.profiles.single.id;
      await household.closeAll();
      household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
      household.backups = BackupScheduler(household, BackupStore(Directory('${dir.path}/backups')));
      await setup.stop();
      setup = SetupServer(household, accounts, port: 0, web: WebFiles(Directory('${dir.path}/no_web')));
      await setup.start();
      await household.start();
      admin.close();
      admin = Client(setup.boundPort!);
      clients.add(admin);
      await admin.post('/api/v1/session', {'name': 'sam', 'password': 'correct horse'});
      final r = await admin.post('/api/v1/profiles', {'name': 'Home'});
      expect(r.status, 200, reason: '${r.json}');
      expect(household.profiles.map((p) => (p.id, p.name)), [(empty, 'Home')]);
    });
  });

  group('first run and reset over HTTP (2.3)', () {
    test('first start: without the token only health and sign-in answer', () async {
      expect((await admin.get('/health')).status, 200);
      expect((await admin.get('/api/v1/auth')).json, {'password': false, 'signedIn': false});
      for (final path in ['/api/v1/status', '/api/v1/profiles', '/api/v1/me', '/api/v1/users']) {
        expect((await admin.get(path)).status, 401, reason: path);
      }
      final withToken = await admin.get('/api/v1/auth?token=${accounts.setupToken}');
      expect((withToken.json! as Map)['setup'], 'first');
      final page = await admin.get('/setup?token=${accounts.setupToken}');
      expect(page.status, 200);
    });

    test('setting up: "sam" is an admin and signed in, and the token stops working', () async {
      final token = accounts.setupToken!;
      final r = await admin.post('/api/v1/password', {'token': token, 'name': 'sam', 'password': 'correct horse'});
      expect(r.status, 200);
      final me = (await admin.get('/api/v1/me')).json! as Map;
      expect(me['name'], 'sam');
      expect(me['role'], 'admin');
      final again = await newClient().post('/api/v1/password', {'token': token, 'name': 'eve', 'password': 'evil password'});
      expect(again.status, 403);
      expect((again.json! as Map)['error'], Accounts.setupLinkText);
      expect(accounts.users().map((a) => a.name), ['sam']);
    });

    test('forgotten password: a reset link sets a chosen admin\'s password and keeps everyone else', () async {
      final f = await family();
      final kim = await user('kim', {f['kim']!.id});
      accounts.close();
      accounts = await Accounts.load(dir, reset: true);
      await setup.stop();
      setup = SetupServer(household, accounts, port: 0, web: WebFiles(Directory('${dir.path}/no_web')));
      await setup.start();
      final browser = newClient();
      expect((await Client(setup.boundPort!).get('/api/v1/me')).status, 401);
      final auth = (await browser.get('/api/v1/auth?token=${accounts.setupToken}')).json! as Map;
      expect(auth['setup'], 'reset');
      final sam = (auth['admins']! as List).single as Map;
      expect(sam['name'], 'sam');
      final noToken = (await browser.get('/api/v1/auth')).json! as Map;
      expect(noToken.containsKey('admins'), isFalse);
      final r = await browser.post('/api/v1/password', {'token': accounts.setupToken, 'user': sam['id'], 'password': 'new password'});
      expect(r.status, 200, reason: '${r.json}');
      expect(((await browser.get('/api/v1/me')).json! as Map)['name'], 'sam');
      kim.cookie = null;
      expect((await Client(setup.boundPort!).post('/api/v1/session', {'name': 'kim', 'password': 'kim password'})).status, 200);
      expect(accounts.byName('kim')!.profiles, {f['kim']!.id});
    });
  });

  group('roles and access (3.2)', () {
    test("another member's profile: 403 and nothing about it", () async {
      final f = await family();
      final kim = await user('kim', {f['kim']!.id});
      final dad = f['dad']!.id;
      final r = await kim.get('/api/v1/profiles/$dad');
      expect(r.status, 403);
      expect(r.json, {'error': SetupServer.notYoursText});
      final list = (await kim.get('/api/v1/profiles')).json! as List;
      expect(list.map((p) => (p as Map)['name']), ['Kim']);
      final status = (await kim.get('/api/v1/status')).json! as Map;
      expect((status['profiles']! as List).map((p) => (p as Map)['name']), ['Kim']);
    });

    test('export, users, backups and restore are admin-only', () async {
      final f = await family();
      final kim = await user('kim', {f['kim']!.id});
      for (final (method, path) in [
        ('GET', '/api/v1/users'),
        ('POST', '/api/v1/users'),
        ('GET', '/api/v1/backup'),
        ('POST', '/api/v1/restore'),
        ('POST', '/api/v1/profiles'),
        ('PUT', '/api/v1/profiles/${f['kim']!.id}/export'),
        ('DELETE', '/api/v1/profiles/${f['kim']!.id}'),
      ]) {
        final r = await kim.call(method, path, body: const {}, headers: {'If-Match': '"h1"'});
        expect(r.status, 403, reason: '$method $path');
      }
      expect(household.profiles, hasLength(4));
    });

    test('a user restoring a backup is refused and nothing changes', () async {
      final f = await family();
      final kim = await user('kim', {f['kim']!.id});
      final backup = await admin.get('/api/v1/backup');
      final r = await kim.call('POST', '/api/v1/restore', bytes: backup.bytes);
      expect(r.status, 403);
    });

    test('profile deleted: the account has no profiles left', () async {
      final f = await family();
      final kim = await user('kim', {f['kim']!.id});
      final r = await admin.edit('DELETE', '/api/v1/profiles/${f['kim']!.id}', revisionOf: '/api/v1/profiles');
      expect(r.status, 200, reason: '${r.json}');
      expect(accounts.byName('kim')!.profiles, isEmpty);
      expect((await kim.get('/api/v1/profiles')).json, isEmpty);
    });

    test('disabled: the next request is 401', () async {
      final f = await family();
      final kim = await user('kim', {f['kim']!.id});
      final kimId = accounts.byName('kim')!.id;
      final r = await admin.edit('PUT', '/api/v1/users/$kimId', body: {'disabled': true}, revisionOf: '/api/v1/users');
      expect(r.status, 200, reason: '${r.json}');
      expect((await kim.get('/api/v1/profiles')).status, 401);
      expect((await newClient().post('/api/v1/session', {'name': 'kim', 'password': 'kim password'})).status, 403);
    });
  });

  group('kid profiles and PINs (3.3)', () {
    test("kid profile settings: a user needs a grown-up's PIN, once; Mom's works", () async {
      final f = await family();
      final ava = f['ava']!.id;
      final c = await user('lee', {ava});
      final rename = {'name': 'Ava B'};
      final refused = await c.edit('PUT', '/api/v1/profiles/$ava', body: rename);
      expect(refused.status, 403);
      expect(refused.json, {'error': SetupServer.grownUpText, 'needs': 'grownUp'});
      expect((await c.post('/api/v1/profiles/$ava/unlock', {'grownUp': '9999'})).status, 403);
      final unlocked = await c.post('/api/v1/profiles/$ava/unlock', {'grownUp': '2222'});
      expect((unlocked.json! as Map)['grownUp'], isTrue);
      final saved = await c.edit('PUT', '/api/v1/profiles/$ava', body: rename);
      expect(saved.status, 200, reason: '${saved.json}');
      expect(household.profileById(ava)!.name, 'Ava B');
    });

    test("a user can't change Ava's rating, kind or PIN; an admin can, with no PIN asked", () async {
      final f = await family();
      final ava = f['ava']!.id;
      final c = await user('lee', {ava});
      await c.post('/api/v1/profiles/$ava/unlock', {'grownUp': '2222'});
      for (final change in [
        {'rating': KidRating.older.name},
        {'kind': 'adult'},
        {'pin': '1234'},
      ]) {
        final r = await c.edit('PUT', '/api/v1/profiles/$ava', body: change);
        expect(r.status, 403, reason: '$change');
      }
      expect(household.profileById(ava)!.rating, KidRating.kids);
      final r = await admin.edit('PUT', '/api/v1/profiles/$ava', body: {'rating': KidRating.older.name});
      expect(r.status, 200, reason: '${r.json}');
      expect(household.profileById(ava)!.rating, KidRating.older);
    });

    test('a user renames their own profile after its PIN', () async {
      final f = await family();
      final kim = f['kim']!.id;
      final c = await user('kim', {kim});
      expect((await c.edit('PUT', '/api/v1/profiles/$kim', body: {'name': 'Kimmy'}, revisionOf: '/api/v1/profiles')).status,
          403);
      await c.post('/api/v1/profiles/$kim/unlock', {'pin': '3333'});
      final r = await c.edit('PUT', '/api/v1/profiles/$kim', body: {'name': 'Kimmy', 'color': 3});
      expect(r.status, 200, reason: '${r.json}');
      expect((r.json! as Map).containsKey('pinHash'), isFalse);
      expect(household.profileById(kim)!.name, 'Kimmy');
      expect(household.profileById(kim)!.color, 3);
    });

    test('wrong PINs count toward the lockout', () async {
      final f = await family();
      final c = await user('kim', {f['kim']!.id});
      for (var i = 0; i < 5; i++) {
        expect((await c.post('/api/v1/profiles/${f['kim']!.id}/unlock', {'pin': '000$i'})).status, 403);
      }
      expect((await c.post('/api/v1/profiles/${f['kim']!.id}/unlock', {'pin': '3333'})).status, 429);
    });

    test('profile and settings lists say what is locked', () async {
      final f = await family();
      final c = await user('lee', {f['ava']!.id, f['kim']!.id});
      final list = {for (final p in (await c.get('/api/v1/profiles')).json! as List) (p as Map)['name']: p};
      expect(list['Kim']!['locked'], isTrue);
      expect(list['Ava']!['locked'], isFalse);
      expect(list['Ava']!['needsGrownUp'], isTrue);
      final adminList = (await admin.get('/api/v1/profiles')).json! as List;
      expect(adminList.every((p) => (p as Map)['locked'] == false && p['needsGrownUp'] == false), isTrue);
    });
  });

  group('every route (3.4)', () {
    /// Every file under [dir] but the account database, with its contents.
    Map<String, String> disk() => {
          for (final f in dir.listSync(recursive: true).whereType<File>())
            if (!f.path.contains('nightingale.db'))
              f.path: String.fromCharCodes(f.readAsBytesSync()),
        };

    test('each route refuses a user with no profiles and a user assigned only to another profile', () async {
      final f = await family();
      final dad = f['dad']!.id;
      final none = await user('nobody', {});
      final other = await user('kim', {f['kim']!.id});
      final anonymous = newClient();
      final samId = accounts.byName('sam')!.id;
      final before = disk();
      var checked = 0;
      for (final route in setup.routes.all) {
        final path = '/api/v1/${route.pattern.replaceAll('{id}', dad).replaceAll('{uid}', samId).replaceAllMapped(
              RegExp(r'\{[a-z]+\}'),
              (_) => 'x',
            )}';
        if (route.access == Access.public) continue;
        final noSession = await anonymous.call(route.method, path, body: const {}, headers: {'If-Match': '"h1"'});
        expect(noSession.status, 401, reason: 'no session: $route');
        // Routes any account may call, none of them about another profile.
        if (route.access == Access.signedIn && !route.pattern.contains('{id}')) continue;
        for (final (name, c) in [('no profiles', none), ('another profile', other)]) {
          final r = await c.call(route.method, path, body: const {}, headers: {'If-Match': '"h1"'});
          expect(r.status, 403, reason: '$name: $route');
        }
        checked++;
      }
      expect(checked, greaterThan(5));
      expect(disk(), before, reason: 'nothing changed on disk');
    });

    test('every route about a profile checks it', () {
      for (final route in setup.routes.all) {
        if (route.pattern.contains('{id}')) {
          expect(route.access, isNot(Access.public), reason: '$route');
          if (route.access == Access.signedIn) expect(route.pattern, 'profiles/{id}/unlock');
        }
      }
    });
  });

  group('revisions (4.1)', () {
    test('two browsers: the first save is kept, the second is refused with 409 and the latest', () async {
      final f = await family();
      final kim = f['kim']!.id;
      final other = newClient()..cookie = admin.cookie;
      final etag = await admin.etag('/api/v1/profiles/$kim');
      final first = await admin.call('PUT', '/api/v1/profiles/$kim', body: {'name': 'First'}, headers: {'If-Match': etag});
      expect(first.status, 200);
      expect(first.headers.value(HttpHeaders.etagHeader), isNot(etag));
      final second = await other.call('PUT', '/api/v1/profiles/$kim', body: {'name': 'Second'}, headers: {'If-Match': etag});
      expect(second.status, 409);
      expect((second.json! as Map)['error'], SetupServer.conflictText);
      expect(((second.json! as Map)['current'] as Map)['name'], 'First');
      expect(second.headers.value(HttpHeaders.etagHeader), first.headers.value(HttpHeaders.etagHeader));
      expect(household.profileById(kim)!.name, 'First');
    });

    test('a missing If-Match changes nothing (428)', () async {
      final f = await family();
      final r = await admin.call('PUT', '/api/v1/profiles/${f['kim']!.id}', body: {'name': 'Blind'});
      expect(r.status, 428);
      expect(household.profileById(f['kim']!.id)!.name, 'Kim');
    });
  });

  group('borrowed states (4.2)', () {
    test('a profile that isn\'t exported is loaded for requests and let go 10 minutes after the last', () async {
      final f = await family();
      var now = DateTime(2026, 10, 24, 12);
      setup.clock = () => now;
      final kim = f['kim']!.id;
      final r = await admin.post('/api/v1/profiles/$kim/sign-in', {'action': 'start'});
      expect(r.status, 200);
      await admin.post('/api/v1/profiles/$kim/sign-in', {'action': 'cancel'});
      expect(setup.isBorrowed(kim), isTrue);
      now = now.add(const Duration(minutes: 9));
      await setup.releaseIdle();
      expect(setup.isBorrowed(kim), isTrue);
      now = now.add(const Duration(minutes: 2));
      await setup.releaseIdle();
      expect(setup.isBorrowed(kim), isFalse);
    });
  });

  group('me and users (4.3)', () {
    test('adding a household member: Kim signs in and sees only the profile "Kim"', () async {
      final f = await family();
      final r = await admin.post('/api/v1/users',
          {'name': 'kim', 'role': 'user', 'password': 'kims password', 'profiles': [f['kim']!.id]});
      expect(r.status, 200, reason: '${r.json}');
      expect((r.json! as Map).containsKey('pw_hash'), isFalse);
      final kim = newClient();
      expect((await kim.post('/api/v1/session', {'name': 'kim', 'password': 'kims password'})).status, 200);
      expect(((await kim.get('/api/v1/profiles')).json! as List).map((p) => (p as Map)['name']), ['Kim']);
      final users = (await admin.get('/api/v1/users')).json! as List;
      expect(users.map((u) => (u as Map)['name']), ['kim', 'sam']);
    });

    test('password changed: that browser stays signed in, the others sign in again', () async {
      final f = await family();
      final one = await user('kim', {f['kim']!.id});
      final two = newClient();
      await two.post('/api/v1/session', {'name': 'kim', 'password': 'kim password'});
      final wrong = await one.call('PUT', '/api/v1/me/password', body: {'current': 'nope', 'password': 'new password'});
      expect(wrong.status, 403);
      final r = await one.call('PUT', '/api/v1/me/password', body: {'current': 'kim password', 'password': 'new password'});
      expect(r.status, 200, reason: '${r.json}');
      expect((await one.get('/api/v1/me')).status, 200);
      expect((await two.get('/api/v1/me')).status, 401);
    });

    test("the last admin can't make themselves a user", () async {
      await firstAdmin();
      final samId = accounts.byName('sam')!.id;
      final r = await admin.edit('PUT', '/api/v1/users/$samId', body: {'role': 'user'});
      expect(r.status, 409);
      expect((r.json! as Map)['error'], Accounts.lastAdminText);
      expect(accounts.byName('sam')!.isAdmin, isTrue);
    });
  });

  group('accounts in backups (5.1–5.3, 2.5)', () {
    test('looking inside a server backup: both accounts with roles and profiles, no hash, salt or session', () async {
      final f = await family();
      final kim = await user('kim', {f['kim']!.id});
      final download = await admin.get('/api/v1/backup');
      expect(download.status, 200);
      final text = utf8.decode(BackupArchive.gunzip(download.bytes));
      final json = jsonDecode(text) as Map<String, Object?>;
      final users = ((json['server']! as Map)['users']! as List).cast<Map<String, Object?>>();
      expect(users, [
        {'name': 'kim', 'role': 'user', 'disabled': false, 'profiles': [f['kim']!.id]},
        {'name': 'sam', 'role': 'admin', 'disabled': false, 'profiles': <String>[]},
      ]);
      for (final row in accounts.db.db.select('SELECT pw_hash, pw_salt, id FROM users')) {
        expect(text, isNot(contains(row['pw_hash'] as String)));
        expect(text, isNot(contains(row['pw_salt'] as String)));
        expect(text, isNot(contains(row['id'] as String)));
      }
      for (final row in accounts.db.db.select('SELECT hash FROM sessions')) {
        expect(text, isNot(contains(row['hash'] as String)));
      }
      expect(text, isNot(contains(kim.cookie!)));
      for (final name in BackupArchive.neverBackedUp) {
        expect(text, isNot(contains(name)));
      }
    });

    test('adding a user counts as a change for the daily backup', () async {
      await family();
      final first = await household.backups!.build(BackupReason.daily);
      await accounts.addUser(name: 'kim', role: Role.user, password: 'kims password');
      final second = await household.backups!.build(BackupReason.daily);
      expect(second.fingerprint, isNot(first.fingerprint));
    });

    test('moving to a new server: the restoring admin stays one; the others are added needing a password', () async {
      final f = await family();
      await user('kim', {f['kim']!.id});
      final backup = (await admin.get('/api/v1/backup')).bytes;

      final dir2 = await Directory.systemTemp.createTemp('nightingale_tv_web_admin_2');
      final household2 = Household(await AppStorage.at(dir2), runAnalysis: false, serverMode: true);
      household2.backups = BackupScheduler(household2, BackupStore(Directory('${dir2.path}/backups')));
      final accounts2 = await Accounts.load(dir2);
      final setup2 = SetupServer(household2, accounts2, port: 0, web: WebFiles(Directory('${dir2.path}/no_web')));
      await setup2.start();
      await household2.start();
      final lee = Client(setup2.boundPort!);
      addTearDown(() async {
        lee.close();
        await setup2.stop();
        await household2.closeAll();
        accounts2.close();
        await dir2.delete(recursive: true);
      });
      await lee.post('/api/v1/password', {'token': accounts2.setupToken, 'name': 'lee', 'password': 'lees password'});
      final upload = await lee.call('POST', '/api/v1/restore', bytes: backup);
      expect(upload.status, 200, reason: '${upload.json}');
      final restored = await lee.post('/api/v1/restore/${(upload.json! as Map)['id']}/confirm');
      expect(restored.status, 200, reason: '${restored.json}');

      final users = {for (final u in (await lee.get('/api/v1/users')).json! as List) (u as Map)['name']: u};
      expect(users.keys, containsAll(['lee', 'sam', 'kim']));
      expect((users['lee']!['role'], users['lee']!['needsPassword']), ('admin', false));
      expect((users['sam']!['role'], users['sam']!['needsPassword']), ('admin', true));
      expect((users['kim']!['role'], users['kim']!['needsPassword']), ('user', true));
      expect(users['kim']!['profiles'], [f['kim']!.id]);
      final kim = Client(setup2.boundPort!);
      addTearDown(kim.close);
      expect((await kim.post('/api/v1/session', {'name': 'kim', 'password': 'kim password'})).status, 403);
      final set = await lee.edit('PUT', '/api/v1/users/${users['kim']!['id']}/password',
          body: {'password': 'new kim pass'}, revisionOf: '/api/v1/users');
      expect(set.status, 200, reason: '${set.json}');
      expect((await kim.post('/api/v1/session', {'name': 'kim', 'password': 'new kim pass'})).status, 200);
      expect(((await kim.get('/api/v1/profiles')).json! as List).map((p) => (p as Map)['name']), ['Kim']);
    });

    test('a TV backup restored on the server leaves the accounts, dropping profiles that are gone', () async {
      final f = await family();
      await user('kim', {f['kim']!.id});
      // A TV's backup: no accounts, and no "Kim".
      final tv = await Directory.systemTemp.createTemp('nightingale_tv_pc');
      addTearDown(() => tv.delete(recursive: true));
      final h = Household(await AppStorage.at(tv), runAnalysis: false);
      await h.start();
      h.leave();
      await h.saveProfile(h.profiles.single..name = 'Living room');
      final built = await BackupArchive.build(tv, reason: BackupReason.manual, device: 'pc');
      await h.closeAll();
      expect(BackupArchive.decode(built.bytes).server, isNull);
      final upload = await admin.call('POST', '/api/v1/restore', bytes: built.bytes);
      final r = await admin.post('/api/v1/restore/${(upload.json! as Map)['id']}/confirm');
      expect(r.status, 200, reason: '${r.json}');
      expect(accounts.users().map((a) => a.name), ['kim', 'sam']);
      expect(accounts.byName('kim')!.profiles, isEmpty);
      expect(accounts.byName('sam')!.isAdmin, isTrue);
    });

    test('the TV app ignores the accounts: a server backup restores on Linux as before', () async {
      final f = await family();
      await user('kim', {f['kim']!.id});
      final backup = (await admin.get('/api/v1/backup')).bytes;
      final pc = await Directory.systemTemp.createTemp('nightingale_tv_pc');
      addTearDown(() => pc.delete(recursive: true));
      final h = Household(await AppStorage.at(pc), runAnalysis: false);
      await h.start();
      await BackupRestorer(h).restore(backup);
      expect(h.profiles.map((p) => p.name), ['Mom', 'Dad', 'Kim', 'Ava']);
      expect(File('${pc.path}/nightingale.db').existsSync(), isFalse);
      final again = await BackupArchive.build(pc, reason: BackupReason.manual, device: 'pc');
      expect(BackupArchive.decode(again.bytes).server, isNull, reason: 'the TV never writes accounts');
      await h.closeAll();
    });
  });
}

extension<T> on T {
  void let(void Function(T) f) => f(this);
}
