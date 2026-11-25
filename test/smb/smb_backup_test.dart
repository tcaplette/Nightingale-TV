import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/server_set.dart';

import '../backup_fixtures.dart';
import '../fixtures.dart';

/// Mom's added shares: one with a password (`s2`) and a guest one (`s3`).
Map<String, Object?> _shares() => {
      'servers': [
        for (final (key, id, user, ref) in [('s2', 'smb-1', 'alice', 'smb-ref-1'), ('s3', 'smb-2', 'guest', 'guest')])
          {
            'key': key,
            'session': {
              'kind': 'smb',
              'serverUrl': 'smb://nas/$key',
              'serverName': '$key on nas',
              'serverId': id,
              'userId': user,
              'userName': user == 'guest' ? 'Guest' : user,
              'accessToken': ref,
              'deviceId': 'd',
            },
          }
      ],
      'order': ['main', 's2', 's3'],
      'nextKey': 4,
    };

void main() {
  late Directory dir;
  final households = <Household>[];
  final mom = momAndKids().first;

  setUp(() async => dir = await Directory.systemTemp.createTemp('smb_backup'));
  tearDown(() async {
    for (final h in households) {
      final app = h.app;
      h.leave();
      h.backups?.dispose();
      if (app != null) {
        await app.close();
        await app.storage.flush();
      }
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

  AppStorage storageOf(Directory root) => AppStorage.existing(Directory('${root.path}/profiles/${mom.id}'));

  Future<void> addShares(Directory root) async {
    final s = storageOf(root);
    await s.writeJson(ServerSet.file, _shares(), private: true);
    await s.writeJson('smb_shares.json', {
      'shares': {
        'smb-1': {
          'folders': [
            {'path': 'TV', 'type': 'tvShows'}
          ],
          'historyName': 'Family',
        },
        'smb-2': {
          'folders': [
            {'path': '', 'type': 'movies'}
          ],
          'keepLocal': true,
        },
      },
      'historyFile': 'abc123',
    });
    await s.writeJson('smb_history/0123456789abcdef0123.json', {
      'mine': {'m|heat|1995': [2, 1, 0, 1]},
      'others': {'m|heat|1995': [9, 1, 0, 1]},
    });
    await s.writeJson('smb_secrets.json', {'smb-ref-1': 'ENCRYPTED-PASSWORD-BLOB'}, private: true);
    await s.writeJson('smb_scan/0123456789abcdef0123.json', {'version': 1, 'items': [{'path': 'TV/secret folder/x.mkv'}]});
    await s.writeJson('smb_probe/0123456789abcdef0123.json', {'x': {}});
    await s.flush();
  }

  test("a backup holds shares' hints, folders, history names and own history, and nothing secret", () async {
    await writeHousehold(dir, momAndKids(), fakeLibrary());
    await addShares(dir);
    final h = await open(dir);
    final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    final part = BackupArchive.check(bytes).profiles[mom.id]!;
    final servers = [for (final s in part.servers!['servers'] as List) s as Map];
    expect(servers[0], {
      'key': 's2',
      'kind': 'smb',
      'serverUrl': 'smb://nas/s2',
      'serverName': 's2 on nas',
      'serverId': 'smb-1',
      'userId': 'alice',
      'userName': 'alice',
    });
    expect(servers[1]['guest'], isTrue);
    expect((part.smb!['shares'] as Map)['smb-1'], {
      'folders': [
        {'path': 'TV', 'type': 'tvShows'}
      ],
      'historyName': 'Family',
    });
    expect(part.smbHistory, {
      '0123456789abcdef0123.json': {
        'mine': {'m|heat|1995': [2, 1, 0, 1]}
      }
    });
    final text = utf8.decode(BackupArchive.gunzip(bytes));
    for (final secret in ['ENCRYPTED-PASSWORD-BLOB', 'smb-ref-1', 'secret folder', 'smb_secrets', 'smb_scan', 'smb_probe']) {
      expect(text, isNot(contains(secret)), reason: secret);
    }
  });

  test('on the same device the shares keep their passwords', () async {
    await writeHousehold(dir, momAndKids(), fakeLibrary());
    await addShares(dir);
    final h = await open(dir);
    final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    await BackupRestorer(h, signOut: (s) async {}).restore(bytes);
    await pumpEventQueue();
    expect(await storageOf(dir).readRaw('smb_secrets.json'), {'smb-ref-1': 'ENCRYPTED-PASSWORD-BLOB'});
    expect(await storageOf(dir).readRaw('smb_shares.json'), isA<Map<String, Object?>>());
    expect(await storageOf(dir).readRaw('smb_history/0123456789abcdef0123.json'), {
      'mine': {'m|heat|1995': [2, 1, 0, 1]}
    });
  });

  test('on a new device the shares come back needing their sign-in, folders mapped', () async {
    final oldTv = await Directory('${dir.path}/old').create();
    final newTv = await Directory('${dir.path}/new').create();
    await writeHousehold(oldTv, momAndKids(), fakeLibrary());
    await addShares(oldTv);
    final bytes = (await (await open(oldTv)).backups!.build(BackupReason.manual)).bytes;
    final h = await open(newTv);
    await BackupRestorer(h).restore(bytes);
    expect(await storageOf(newTv).readRaw('smb_secrets.json'), isNull);
    final servers = await storageOf(newTv).readRaw(ServerSet.file) as Map;
    final hints = [for (final s in servers['servers'] as List) (s as Map)['hint'] as Map];
    expect(hints.map((h) => h['serverId']), ['smb-1', 'smb-2']);
    expect(hints[1]['guest'], isTrue);
    expect(((await storageOf(newTv).readRaw('smb_shares.json')) as Map)['historyFile'], 'abc123');
  });
}
