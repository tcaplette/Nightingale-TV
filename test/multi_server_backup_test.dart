import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_set.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';
import 'multi_server_fakes.dart';

/// Mom's added Plex server (key `s2`), signed in here with [serverId].
Map<String, Object?> _plex({String serverId = 'plex-1', String token = 'plex-secret'}) => {
      'servers': [
        {
          'key': 's2',
          'session': {
            'serverUrl': 'http://plex.example:32400',
            'serverName': 'Basement Plex',
            'serverId': serverId,
            'userId': '77',
            'userName': 'dad',
            'accessToken': token,
            'accountToken': 'plex-account-secret',
            'deviceId': 'd',
            'kind': 'plex',
          },
          'qualityLimit': 2000000,
        }
      ],
      'order': ['s2', 'main'],
      'nextKey': 3,
    };

void main() {
  late Directory dir;
  final households = <Household>[];
  final mom = momAndKids().first;

  setUp(() async => dir = await Directory.systemTemp.createTemp('multi_backup'));
  tearDown(() async {
    for (final h in households) {
      h.leave();
      h.backups?.dispose();
    }
    households.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dir.delete(recursive: true);
  });

  Future<Household> open(Directory root) async {
    final h = await openHousehold(root);
    households.add(h);
    return h;
  }

  AppStorage storageOf(Directory root, String id) => AppStorage.existing(Directory('${root.path}/profiles/$id'));

  Future<void> addPlex(Directory root, {String serverId = 'plex-1'}) async {
    final s = storageOf(root, mom.id);
    await s.writeJson(ServerSet.file, _plex(serverId: serverId), private: true);
    await s.writeJson('library_parts/s2.json', fakeLibrary().toJson());
    await s.flush();
  }

  test('a backup names every server with its key, limit and the Play from order, and holds no token', () async {
    await writeHousehold(dir, momAndKids(), fakeLibrary());
    await addPlex(dir);
    final h = await open(dir);
    final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    final part = BackupArchive.check(bytes).profiles[mom.id]!;
    expect(part.servers!['order'], ['s2', 'main']);
    final plex = (part.servers!['servers'] as List).single as Map;
    expect(plex, {
      'key': 's2',
      'kind': 'plex',
      'serverUrl': 'http://plex.example:32400',
      'serverName': 'Basement Plex',
      'serverId': 'plex-1',
      'userId': '77',
      'userName': 'dad',
      'qualityLimit': 2000000,
    });
    final text = utf8.decode(BackupArchive.gunzip(bytes));
    for (final secret in ['plex-secret', 'plex-account-secret', tokenFor(mom.id)]) {
      expect(text, isNot(contains(secret)));
    }
    expect(text, isNot(contains('library_parts')));
  });

  test('on the same device an added server signed in to the same server stays signed in', () async {
    await writeHousehold(dir, momAndKids(), fakeLibrary());
    await addPlex(dir);
    final h = await open(dir);
    final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    final signedOut = <String>[];
    await BackupRestorer(h, signOut: (s) async => signedOut.add(s.accessToken)).restore(bytes);
    await pumpEventQueue();
    expect(signedOut, isEmpty);
    final saved = await storageOf(dir, mom.id).readRaw(ServerSet.file) as Map;
    final plex = (saved['servers'] as List).single as Map;
    expect((plex['session'] as Map)['accessToken'], 'plex-secret');
    expect(await storageOf(dir, mom.id).readRaw('library_parts/s2.json'), isNotNull);
    await h.select(h.profileById(mom.id)!);
    expect(h.app!.servers.byKey('s2')!.state, ServerState.ok);
    expect(h.app!.servers.order, ['s2', 'main']);
  });

  test('on the same device, another server under that key now needs sign-in, and is signed out', () async {
    await writeHousehold(dir, momAndKids(), fakeLibrary());
    await addPlex(dir);
    final h = await open(dir);
    final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    await addPlex(dir, serverId: 'plex-other');
    final signedOut = <String>[];
    await BackupRestorer(h, signOut: (s) async => signedOut.add(s.serverId ?? '')).restore(bytes);
    await pumpEventQueue();
    expect(signedOut, ['plex-other']);
    await h.select(h.profileById(mom.id)!);
    final plex = h.app!.servers.byKey('s2')!;
    expect(plex.state, ServerState.needsSignIn);
    expect((plex.name, plex.serverId, plex.userName, plex.kind), ('Basement Plex', 'plex-1', 'dad', ServerKind.plex));
    expect(plex.qualityLimit, 2000000);
  });

  group('on a new device', () {
    late Directory oldTv, newTv;
    late List<int> bytes;

    setUp(() async {
      oldTv = await Directory('${dir.path}/old').create();
      newTv = await Directory('${dir.path}/new').create();
      await writeHousehold(oldTv, momAndKids(), fakeLibrary());
      await addPlex(oldTv);
      final h = await open(oldTv);
      bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    });

    ServerSession main(String serverId) => ServerSession(
        serverUrl: 'http://127.0.0.1:9',
        serverName: 'Home',
        userId: 'u-mom',
        userName: 'mom',
        accessToken: 'new',
        deviceId: 'd',
        serverId: serverId);

    test('the added server comes back as Needs sign-in, keeping its key, order and limit', () async {
      final h = await open(newTv);
      await BackupRestorer(h).restore(bytes);
      await h.select(h.profileById(mom.id)!);
      final app = h.app!;
      expect(app.servers.multiple, isFalse, reason: 'nothing before the main server signs in');
      await app.completeSignIn(main('s1'), FakeServer('Home', items: fakeItems(), url: 'http://127.0.0.1:9').client);
      final plex = app.servers.byKey('s2')!;
      expect(plex.state, ServerState.needsSignIn);
      expect(app.servers.order, ['s2', 'main']);
      expect(plex.qualityLimit, 2000000);
      expect(app.servers.nextKey, 3);
    });

    test('a different main server drops the added servers with the lineup', () async {
      final h = await open(newTv);
      await BackupRestorer(h).restore(bytes);
      await h.select(h.profileById(mom.id)!);
      final app = h.app!;
      await app.completeSignIn(main('another-server'), FakeServer('Home', items: fakeItems(), url: 'http://127.0.0.1:9').client);
      expect(app.servers.multiple, isFalse);
      expect(await storageOf(newTv, mom.id).readRaw(ServerSet.file), isNull);
    });
  });

  test('a backup from before added servers restores as the main server only', () async {
    await writeHousehold(dir, momAndKids(), fakeLibrary());
    final h = await open(dir);
    final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    expect(BackupArchive.check(bytes).profiles[mom.id]!.servers, isNull);
    await BackupRestorer(h, signOut: (s) async {}).restore(bytes);
    expect(await storageOf(dir, mom.id).readRaw(ServerSet.file), isNull);
  });
}
