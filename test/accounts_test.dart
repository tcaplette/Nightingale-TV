import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/setup/accounts.dart';
import 'package:nightingale_tv/setup/server_db.dart';

void main() {
  late Directory dir;
  late Accounts accounts;
  var now = DateTime.utc(2026, 10, 24, 12);
  final iterations = Accounts.iterations;
  final log = <String>[];

  setUpAll(() => Accounts.iterations = 1000);
  tearDownAll(() => Accounts.iterations = iterations);

  Future<Accounts> load({bool reset = false}) =>
      Accounts.load(dir, reset: reset, clock: () => now, log: log.add);

  setUp(() async {
    now = DateTime.utc(2026, 10, 24, 12);
    log.clear();
    dir = await Directory.systemTemp.createTemp('nightingale_tv_accounts');
    accounts = await load();
  });

  tearDown(() async {
    accounts.close();
    await dir.delete(recursive: true);
  });

  /// "sam" (admin, signed in) and "kim" (user, profile "kim-profile").
  Future<String> household() async {
    final session = await accounts.createFirstAdmin(accounts.setupToken!, 'sam', 'correct horse');
    await accounts.addUser(name: 'kim', role: Role.user, password: 'kims password', profiles: {'kim-profile'});
    return session;
  }

  group('account database (2.1)', () {
    test('a new file gets the current version and no users', () {
      expect(File('${dir.path}/${ServerDb.fileName}').existsSync(), isTrue);
      expect(accounts.db.version, ServerDb.migrations.length);
      expect(accounts.hasUsers, isFalse);
      expect(accounts.db.db.select('PRAGMA journal_mode').first.values.first, 'wal');
      expect(accounts.db.db.select('PRAGMA foreign_keys').first.values.first, 1);
    });

    test('a failing migration leaves the old version and says which one failed', () async {
      accounts.close();
      final broken = [...ServerDb.migrations, 'CREATE TABLE extra(x); INSERT INTO nowhere VALUES (1);'];
      expect(
          () => ServerDb.open(dir, migrations: broken),
          throwsA(isA<ServerDbException>()
              .having((e) => e.message, 'message', contains('migration ${broken.length} failed'))));
      final db = ServerDb.open(dir);
      expect(db.version, ServerDb.migrations.length);
      expect(db.db.select("SELECT name FROM sqlite_master WHERE name = 'extra'"), isEmpty);
      db.close();
      accounts = await load();
    });
  });

  group('sign-in and sessions (2.2)', () {
    test('passwords are PBKDF2 hashes; sign-in takes the name in any case', () async {
      await household();
      final row = accounts.db.db.select("SELECT * FROM users WHERE name = 'kim'").first;
      expect(row['pw_hash'], isNot(contains('kims password')));
      expect(row['pw_iter'], 1000);
      final session = await accounts.signIn('KIM', 'kims password', '192.168.1.5');
      expect(accounts.accountFor(session)?.name, 'kim');
      expect(accounts.db.db.select('SELECT hash FROM sessions').map((r) => r['hash']), isNot(contains(session)));
    });

    test('a wrong name and a wrong password get the same answer', () async {
      await household();
      Future<String> refusal(String name, String pw) async {
        try {
          await accounts.signIn(name, pw, '192.168.1.${name.length}');
        } on AccountException catch (e) {
          return '${e.status} ${e.message}';
        }
        return 'signed in';
      }

      expect(await refusal('nobody', 'kims password'), await refusal('kim', 'wrong password'));
      expect(await refusal('nobody', 'x'), '403 ${Accounts.wrongText}');
    });

    test('guessing across names: one address is locked out after 5 failures', () async {
      await household();
      for (final name in ['a', 'b', 'c', 'd', 'e']) {
        await expectLater(accounts.signIn(name, 'wrong one', '10.0.0.9'), throwsA(isA<AccountException>()));
      }
      await expectLater(accounts.signIn('kim', 'kims password', '10.0.0.9'),
          throwsA(isA<AccountException>().having((e) => e.status, 'status', 429)));
      now = now.add(Accounts.lockWindow + const Duration(seconds: 1));
      expect(await accounts.signIn('kim', 'kims password', '10.0.0.9'), isNotEmpty);
    });

    test('guessing one name from many addresses locks that name out', () async {
      await household();
      for (var i = 0; i < 5; i++) {
        await expectLater(accounts.signIn('kim', 'wrong one', '10.0.0.$i'), throwsA(isA<AccountException>()));
      }
      await expectLater(accounts.signIn('kim', 'kims password', '10.0.0.99'),
          throwsA(isA<AccountException>().having((e) => e.message, 'message', Accounts.lockedText)));
      expect(await accounts.signIn('sam', 'correct horse', '10.0.0.99'), isNotEmpty);
    });

    test('sessions last 30 days', () async {
      final session = await household();
      now = now.add(const Duration(days: 29));
      expect(accounts.accountFor(session), isNotNull);
      now = now.add(const Duration(days: 2));
      expect(accounts.accountFor(session), isNull);
    });

    test('disabled: the next request is refused and the account can\'t sign in', () async {
      await household();
      final kim = await accounts.signIn('kim', 'kims password', '1.1.1.1');
      accounts.updateUser(accounts.byName('kim')!.id, disabled: true);
      expect(accounts.accountFor(kim), isNull);
      await expectLater(accounts.signIn('kim', 'kims password', '1.1.1.1'), throwsA(isA<AccountException>()));
    });

    test('password changed: that browser stays signed in, the others must sign in again', () async {
      await household();
      final one = await accounts.signIn('kim', 'kims password', '1.1.1.1');
      final two = await accounts.signIn('kim', 'kims password', '1.1.1.2');
      await expectLater(accounts.changeOwnPassword(one, 'not it', 'new password', '1.1.1.1'),
          throwsA(isA<AccountException>()));
      await accounts.changeOwnPassword(one, 'kims password', 'new password', '1.1.1.1');
      expect(accounts.accountFor(one)?.name, 'kim');
      expect(accounts.accountFor(two), isNull);
      expect(await accounts.signIn('kim', 'new password', '1.1.1.3'), isNotEmpty);
    });

    test('signing out ends the session', () async {
      final session = await household();
      await accounts.signOut(session);
      expect(accounts.accountFor(session), isNull);
    });
  });

  group('roles and managing users (2.2)', () {
    test('the last admin can\'t be made a user, disabled or removed', () async {
      await household();
      final sam = accounts.byName('sam')!;
      for (final change in [
        () => accounts.updateUser(sam.id, role: Role.user),
        () => accounts.updateUser(sam.id, disabled: true),
        () => accounts.removeUser(sam.id),
      ]) {
        expect(change, throwsA(isA<AccountException>().having((e) => e.message, 'message', Accounts.lastAdminText)));
      }
      expect(accounts.byName('sam')!.isAdmin, isTrue);
      accounts.updateUser(accounts.byName('kim')!.id, role: Role.admin);
      accounts.updateUser(sam.id, role: Role.user);
      expect(accounts.byName('sam')!.isAdmin, isFalse);
    });

    test('adding a household member: name rules, profiles, and removing', () async {
      await household();
      await expectLater(accounts.addUser(name: 'KIM', role: Role.user, password: 'whatever1'),
          throwsA(isA<AccountException>().having((e) => e.status, 'status', 409)));
      await expectLater(accounts.addUser(name: 'x' * 33, role: Role.user, password: 'whatever1'),
          throwsA(isA<AccountException>()));
      await expectLater(accounts.addUser(name: 'lee', role: Role.user, password: 'short'),
          throwsA(isA<AccountException>()));
      final kim = accounts.byName('kim')!;
      expect(kim.profiles, {'kim-profile'});
      expect(kim.mayUse('kim-profile'), isTrue);
      expect(kim.mayUse('dad'), isFalse);
      final session = await accounts.signIn('kim', 'kims password', '1.1.1.1');
      accounts.removeUser(kim.id);
      expect(accounts.byName('kim'), isNull);
      expect(accounts.accountFor(session), isNull);
    });

    test('an account added without a password can\'t sign in until one is set', () async {
      await household();
      final lee = await accounts.addUser(name: 'lee', role: Role.user);
      expect(lee.hasPassword, isFalse);
      expect(lee.toJson()['needsPassword'], isTrue);
      await expectLater(accounts.signIn('lee', '', '1.1.1.1'), throwsA(isA<AccountException>()));
      await accounts.setPassword(lee.id, 'lees password');
      expect(await accounts.signIn('lee', 'lees password', '1.1.1.1'), isNotEmpty);
    });
  });

  group('PIN unlocks (3.3)', () {
    test('unlocks last until the session is unused for an hour', () async {
      final session = await household();
      accounts.unlockProfile(session, 'ava');
      accounts.unlockGrownUp(session);
      now = now.add(const Duration(minutes: 50));
      expect(accounts.accountFor(session), isNotNull);
      now = now.add(const Duration(minutes: 50));
      expect(accounts.accountFor(session), isNotNull);
      expect(accounts.profileUnlocked(session, 'ava'), isTrue);
      expect(accounts.grownUpUnlocked(session), isTrue);
      now = now.add(const Duration(minutes: 61));
      accounts.accountFor(session);
      expect(accounts.profileUnlocked(session, 'ava'), isFalse);
      expect(accounts.grownUpUnlocked(session), isFalse);
    });
  });

  group('first run and reset (2.3)', () {
    test('the setup token makes the first admin once', () async {
      final token = accounts.setupToken!;
      expect(token.length, 32);
      await expectLater(accounts.createFirstAdmin('guess', 'sam', 'correct horse'),
          throwsA(isA<AccountException>().having((e) => e.message, 'message', Accounts.setupLinkText)));
      final session = await accounts.createFirstAdmin(token, 'sam', 'correct horse');
      expect(accounts.accountFor(session)?.isAdmin, isTrue);
      expect(accounts.setupToken, isNull);
      await expectLater(accounts.createFirstAdmin(token, 'eve', 'correct horse'), throwsA(isA<AccountException>()));
    });

    test('forgotten password: a reset ends sessions and sets a chosen admin\'s password', () async {
      final session = await household();
      final kim = await accounts.signIn('kim', 'kims password', '1.1.1.1');
      accounts.close();
      accounts = await load();
      expect(accounts.setupToken, isNull);
      accounts.close();
      accounts = await load(reset: true);
      expect(accounts.accountFor(session), isNull);
      expect(accounts.accountFor(kim), isNull);
      final token = accounts.setupToken!;
      await expectLater(accounts.resetAdminPassword(token, accounts.byName('kim')!.id, 'new password'),
          throwsA(isA<AccountException>()));
      final fresh = await accounts.resetAdminPassword(token, accounts.byName('sam')!.id, 'new password');
      expect(accounts.accountFor(fresh)?.name, 'sam');
      expect(accounts.setupToken, isNull);
      expect(await accounts.signIn('sam', 'new password', '1.1.1.1'), isNotEmpty);
      expect(await accounts.signIn('kim', 'kims password', '1.1.1.1'), isNotEmpty);
      expect(accounts.byName('kim')!.profiles, {'kim-profile'});
    });
  });

  group('upgrade from admin.json (2.4)', () {
    test('the old password becomes the account "admin"; admin.json is renamed', () async {
      accounts.close();
      await File('${dir.path}/${ServerDb.fileName}').delete();
      // As docker-server-core's AdminAuth wrote it.
      final salt = List<int>.generate(16, (i) => i * 7);
      final hash = Accounts.pbkdf2(utf8.encode('old password'), salt, 1000);
      await File('${dir.path}/admin.json').writeAsString(jsonEncode({
        'password': {'salt': base64.encode(salt), 'iterations': 1000, 'hash': base64.encode(hash)},
        'sessions': [
          {'hash': 'abc', 'expires': '2026-11-01T00:00:00.000Z'},
        ],
      }));
      accounts = await load();
      expect(log, ['The admin password is now the account "admin".']);
      expect(File('${dir.path}/admin.json').existsSync(), isFalse);
      expect(File('${dir.path}/admin.json.migrated').existsSync(), isTrue);
      expect(accounts.setupToken, isNull);
      expect(accounts.byName('admin')!.isAdmin, isTrue);
      expect(accounts.db.db.select('SELECT * FROM sessions'), isEmpty);
      expect(await accounts.signIn('admin', 'old password', '1.1.1.1'), isNotEmpty);
    });
  });

  group('assignments follow profiles (2.5)', () {
    test('profile deleted: the account has no profiles', () async {
      await household();
      accounts.keepProfiles(['dad']);
      expect(accounts.byName('kim')!.profiles, isEmpty);
    });
  });
}
