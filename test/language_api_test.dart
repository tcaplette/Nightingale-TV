import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/setup/accounts.dart';
import 'package:nightingale_tv/setup/setup_server.dart';
import 'package:nightingale_tv/setup/web_files.dart';

import 'setup_client.dart';

void main() {
  late Directory dir;
  late Household household;
  late Accounts accounts;
  late SetupServer setup;
  late Client admin;
  final iterations = Accounts.iterations;

  setUpAll(() => Accounts.iterations = 1000);
  tearDownAll(() => Accounts.iterations = iterations);

  setUp(() async {
    BackupArchive.useIsolate = false;
    dir = await Directory.systemTemp.createTemp('nightingale_tv_language_api');
    household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
    household.backups = BackupScheduler(household, BackupStore(Directory('${dir.path}/backups')));
    accounts = await Accounts.load(dir);
    setup = SetupServer(household, accounts, port: 0, web: WebFiles(Directory('${dir.path}/no_web')));
    await setup.start();
    await household.start();
    admin = Client(setup.boundPort!);
  });

  tearDown(() async {
    admin.close();
    await setup.stop();
    await household.closeAll();
    accounts.close();
    await dir.delete(recursive: true);
    BackupArchive.useIsolate = true;
  });

  Future<Answer> asking(String? language) => admin.call('GET', '/api/v1/profiles',
      header: true, headers: {'Accept-Language': ?language});

  test('two requests at once each get their own language', () async {
    final answers = await Future.wait([for (final l in ['de', 'it', 'de', 'it', 'fr']) asking(l)]);
    expect((answers[0].json as Map)['error'], 'Melde dich zuerst an.');
    expect((answers[1].json as Map)['error'], 'Accedi prima.');
    expect((answers[2].json as Map)['error'], 'Melde dich zuerst an.');
    expect((answers[3].json as Map)['error'], 'Accedi prima.');
    expect((answers[4].json as Map)['error'], 'Connectez-vous d\'abord.');
  });

  test('English when the request names no supported language', () async {
    expect(((await asking('ja')).json as Map)['error'], 'Sign in first.');
    expect(((await asking(null)).json as Map)['error'], 'Sign in first.');
  });

  group('a profile\'s language', () {
    Future<String> signedInProfile() async {
      final r = await admin.post('/api/v1/password', {'token': accounts.setupToken, 'name': 'sam', 'password': 'correct horse battery'});
      expect(r.status, 200, reason: '${r.json}');
      return household.profiles.single.id;
    }

    test('a supported value is saved', () async {
      final id = await signedInProfile();
      final r = await admin.edit('PUT', '/api/v1/profiles/$id', body: {'language': 'pt'}, revisionOf: '/api/v1/profiles');
      expect(r.status, 200);
      expect(household.profileById(id)!.language, 'pt');
    });

    test('an unsupported value is refused', () async {
      final id = await signedInProfile();
      final r = await admin.edit('PUT', '/api/v1/profiles/$id', body: {'language': 'tlh'}, revisionOf: '/api/v1/profiles');
      expect(r.status, 400);
      expect(household.profileById(id)!.language, isNull);
    });
  });
}
