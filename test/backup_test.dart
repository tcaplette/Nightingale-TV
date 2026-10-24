import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/profile.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_backup'));
  tearDown(() => dir.delete(recursive: true));

  Future<BuiltBackup> build({String reason = BackupReason.manual}) =>
      BackupArchive.build(dir, reason: reason, device: 'Test TV');

  /// A household with [profiles] (Mom and Kids by default), built.
  Future<BuiltBackup> household({List<Profile>? profiles, int logos = 2}) async {
    await writeHousehold(dir, profiles ?? momAndKids(), fakeLibrary(), logos: logos);
    return build();
  }

  Map<String, Object?> unzip(List<int> bytes) => jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, Object?>;

  /// [bytes] with its JSON changed by [edit], gzipped again.
  List<int> edited(List<int> bytes, void Function(Map<String, Object?> json) edit) {
    final json = unzip(bytes);
    edit(json);
    return gzip.encode(utf8.encode(jsonEncode(json)));
  }

  Map<String, Object?> part(Map<String, Object?> json, String id) =>
      (json['profiles'] as Map<String, Object?>)[id] as Map<String, Object?>;

  String checkError(List<int> bytes) {
    try {
      BackupArchive.check(bytes);
    } on BackupException catch (e) {
      return e.message;
    }
    fail('The backup was accepted.');
  }

  group('building', () {
    test('round-trips: what is read back is what was saved', () async {
      final built = await household();
      final archive = BackupArchive.check(built.bytes);
      expect(archive.reason, BackupReason.manual);
      expect(archive.device, 'Test TV');
      expect(archive.fingerprint, built.fingerprint);
      final mom = momAndKids().first.id;
      final saved = await AppStorage.existing(Directory('${dir.path}/profiles/$mom')).readRaw('channels.json');
      expect(jsonEncode(archive.profiles[mom]!.channels), jsonEncode(saved));
      expect(archive.profiles[mom]!.blocks, hasLength(1));
      expect(archive.logos.keys.toSet(), {logoNameFor(1), logoNameFor(2)});
      expect(archive.profiles[mom]!.signIn, {
        'serverUrl': 'http://127.0.0.1:9',
        'serverName': 'Home',
        'serverId': 's1',
        'userId': 'u-$mom',
        'userName': 'mom',
      });
      // Encoding it again gives the same content.
      expect(BackupArchive.decode(archive.encode()).fingerprint, built.fingerprint);
    });

    test('the fingerprint ignores when, why and where; a renamed channel changes it', () async {
      final first = await household();
      final again = await BackupArchive.build(dir,
          reason: BackupReason.daily, device: 'Other TV', createdAt: DateTime.now().add(const Duration(days: 1)));
      expect(again.fingerprint, first.fingerprint);

      final mom = momAndKids().first.id;
      final storage = AppStorage.existing(Directory('${dir.path}/profiles/$mom'));
      final channels = (await storage.readRaw('channels.json') as List).cast<Map<String, Object?>>();
      channels.first['name'] = 'Renamed';
      await storage.writeJson('channels.json', channels);
      await storage.flush();
      expect((await build()).fingerprint, isNot(first.fingerprint));
    });

    test('no access token or install id appears anywhere in the backup', () async {
      final built = await household();
      final text = utf8.decode(gzip.decode(built.bytes));
      for (final p in momAndKids()) {
        final storage = AppStorage.existing(Directory('${dir.path}/profiles/${p.id}'));
        final settings = await storage.readRaw('settings.json') as Map<String, Object?>;
        final installId = settings['installId'] as String;
        expect(text, isNot(contains(tokenFor(p.id))));
        expect(text, isNot(contains(installId)));
        expect(text, isNot(contains('accessToken')));
        expect(text, isNot(contains('installId')));
      }
    });

    test('profiles on different servers: each hint names its kind, and no Plex token is kept', () async {
      final [mom, kids] = momAndKids();
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      await writeProfile(dir, mom, fakeLibrary(), serverId: 'machine-1', kind: 'plex');
      await writeProfile(dir, kids, fakeLibrary(), serverId: 'emby-1', kind: 'emby');
      final built = await build();
      final text = utf8.decode(gzip.decode(built.bytes));
      final json = unzip(built.bytes);
      expect(part(json, mom.id)['signIn'], containsPair('kind', 'plex'));
      expect(part(json, mom.id)['signIn'], containsPair('serverId', 'machine-1'));
      expect(part(json, kids.id)['signIn'], containsPair('kind', 'emby'));
      expect(part(json, kids.id)['signIn'], containsPair('serverId', 'emby-1'));
      for (final p in [mom, kids]) {
        expect(text, isNot(contains(tokenFor(p.id))));
        expect(text, isNot(contains(accountTokenFor(p.id))));
      }
      expect(text, isNot(contains('accountToken')));
    });

    test('a Jellyfin hint has no kind, as before server kinds existed', () async {
      final built = await household();
      expect(part(unzip(built.bytes), momAndKids().first.id)['signIn'], isNot(contains('kind')));
    });

    test('leaves out the library index, analysis results and caches', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      await Directory('${dir.path}/analysis').create();
      await File('${dir.path}/analysis/s1.json').writeAsString('{"marker":"analysis-results"}');
      final built = await build();
      final text = utf8.decode(gzip.decode(built.bytes));
      expect(text, isNot(contains('analysis-results')));
      // The library index's own fields.
      expect(text, isNot(contains('fetchedAt')));
      expect(text, isNot(contains('episodesBySeries')));
      final json = unzip(built.bytes);
      for (final p in momAndKids()) {
        expect(part(json, p.id).keys.toSet(), {'settings', 'channels', 'blocks', 'signIn'});
      }
    });

    test('the summary counts profiles, channels, blocks and logos', () async {
      final built = await household(logos: 3);
      var channels = 0;
      for (final p in momAndKids()) {
        final list = await AppStorage.existing(Directory('${dir.path}/profiles/${p.id}')).readRaw('channels.json');
        channels += (list as List).length;
      }
      expect(built.summary.profiles, ['Mom', 'Kids']);
      expect(built.summary.channels, channels);
      expect(built.summary.blocks, 2);
      expect(built.summary.logos, 3);
      expect(built.summary.line, '2 profiles · $channels channels · 2 blocks');
      expect((unzip(built.bytes)['summary'] as Map)['channels'], channels);
    });
  });

  group('checking', () {
    late List<int> good;
    setUp(() async => good = (await household()).bytes);

    test('a truncated file is damaged', () {
      expect(checkError(good.sublist(0, good.length ~/ 2)), BackupArchive.damaged);
    });

    test('a file that isn\'t gzip, or isn\'t JSON, is damaged', () {
      expect(checkError(utf8.encode('not a backup')), BackupArchive.damaged);
      expect(checkError(gzip.encode(utf8.encode('{not json'))), BackupArchive.damaged);
    });

    test('another format is damaged; a newer version is turned down by name', () {
      expect(checkError(edited(good, (j) => j['format'] = 'something-else')), BackupArchive.damaged);
      expect(checkError(edited(good, (j) => j['version'] = BackupArchive.currentVersion + 1)), BackupArchive.newer);
      expect(BackupArchive.newer, 'This backup was made by a newer version of Nightingale TV.');
    });

    test('a gzip bomb over the cap is turned down', () {
      // 65 MB of zeros gzips to well under a megabyte.
      final bomb = gzip.encode(List<int>.filled(65 * 1024 * 1024, 0x20));
      expect(bomb.length, lessThan(1024 * 1024));
      expect(checkError(bomb), BackupArchive.tooBig);
    });

    test('a broken channel names whose channels', () {
      final bytes = edited(good, (j) {
        final channels = part(j, momAndKids().first.id)['channels'] as List;
        (channels.first as Map<String, Object?>).remove('playlist');
      });
      expect(checkError(bytes), 'This backup is damaged: Mom\'s channels can\'t be read.');
    });

    test('kid profiles with a grown-up missing a PIN are turned down', () {
      final bytes = edited(good, (j) {
        final profiles = (j['household'] as Map)['profiles'] as List;
        (profiles.first as Map<String, Object?>)
          ..remove('pinHash')
          ..remove('pinSalt');
      });
      expect(checkError(bytes), allOf(startsWith('This backup can\'t be restored.'), contains('Set a PIN on Mom')));
    });

    test('logo names other than the store\'s own are turned down', () {
      for (final name in ['../profiles.json', 'a/b.png', 'ABCDEF0123456789.png', '0123.png']) {
        final bytes = edited(good, (j) => (j['logos'] as Map<String, Object?>)[name] = base64.encode(fakeLogo()));
        expect(checkError(bytes), 'This backup is damaged: one of its channel logos can\'t be read.', reason: name);
      }
    });

    test('a corrupt PNG is turned down', () {
      final bytes = edited(good, (j) => (j['logos'] as Map<String, Object?>)[logoNameFor(1)] = base64.encode([1, 2, 3]));
      expect(checkError(bytes), 'This backup is damaged: one of its channel logos can\'t be read.');
    });

    test('settings from before a format change load upgraded', () async {
      // Saved before break plans: an on/off switch and whole libraries.
      final bytes = edited(good, (j) {
        part(j, momAndKids().first.id)['settings'] = {
          'commercialsEnabled': true,
          'commercialLibraryIds': ['ads'],
        };
      });
      final archive = BackupArchive.check(bytes);
      final settings = AppSettings.fromJson({...archive.profiles[momAndKids().first.id]!.settings!, 'installId': 'x'});
      expect(settings.migrated, isTrue);
      expect(settings.commercialPlan.isOff, isFalse);
      expect(settings.commercialPools.single.id, AppSettings.legacyPoolId);
    });
  });

  group('the store', () {
    late BackupStore store;
    late List<int> bytes;

    setUp(() async {
      store = BackupStore(Directory('${dir.path}/backups'));
      bytes = (await household(logos: 0)).bytes;
    });

    Future<StoredBackup> save(String kind, int day) =>
        store.save(Uint8List.fromList(bytes), kind: kind, at: DateTime.utc(2026, 1, 1).add(Duration(days: day)));

    test('files are named by time and kind, listed newest first', () async {
      await save(BackupReason.daily, 1);
      await save(BackupReason.manual, 3);
      await save(BackupReason.beforeReset, 2);
      final list = await store.list();
      expect([for (final b in list) b.kind], [BackupReason.manual, BackupReason.beforeReset, BackupReason.daily]);
      expect(list.first.name, '20260104T000000000Z_manual.ntvbackup');
      expect([for (final b in list) b.kindLabel], ['Made by you', 'Before reset', 'Automatic']);
    });

    test('pruning keeps 14 dailies and 10 safety backups, and every user-made one', () async {
      for (var i = 0; i < 20; i++) {
        await save(BackupReason.daily, i);
        await save(i.isEven ? BackupReason.beforeReset : BackupReason.beforeDelete, i);
      }
      await save(BackupReason.manual, 0);
      await save(BackupReason.file, 0);
      final list = await store.list();
      expect(list.where((b) => b.kind == BackupReason.daily), hasLength(14));
      expect(list.where((b) => b.isSafety), hasLength(10));
      expect(list.where((b) => b.kind == BackupReason.manual), hasLength(1));
      expect(list.where((b) => b.kind == BackupReason.file), hasLength(1));
      // The newest of each are the ones kept.
      expect(list.where((b) => b.kind == BackupReason.daily).last.savedAt, DateTime.utc(2026, 1, 7));
    });

    test('a fifteenth daily removes only the oldest daily', () async {
      for (var i = 0; i < 14; i++) {
        await save(BackupReason.daily, i + 10);
      }
      await save(BackupReason.beforeRestore, 0);
      await save(BackupReason.manual, 1);
      final before = {for (final b in await store.list()) b.name};
      await save(BackupReason.daily, 30);
      final after = {for (final b in await store.list()) b.name};
      expect(before.difference(after), {'20260111T000000000Z_daily.ntvbackup'});
      expect(after.difference(before), {'20260131T000000000Z_daily.ntvbackup'});
    });

    test('the cloud copy is always the newest backup', () async {
      Future<void> expectCloudIsNewest() async {
        final newest = await store.newest();
        expect(await store.cloudCopy.readAsBytes(), await newest!.file.readAsBytes());
      }

      await save(BackupReason.daily, 1);
      await expectCloudIsNewest();
      final other = (await BackupArchive.build(dir, reason: BackupReason.manual, device: 'Other')).bytes;
      final manual = await store.save(other, kind: BackupReason.manual, at: DateTime.utc(2026, 2, 1));
      await expectCloudIsNewest();
      expect(await store.cloudCopy.readAsBytes(), other);
      await store.delete(manual);
      await expectCloudIsNewest();
      await store.delete((await store.newest())!);
      expect(await store.cloudCopy.exists(), isFalse);
    });

    test('the list goes by when each backup was made; opened files aren\'t this setup\'s', () async {
      // Made now (save() only sets when it's saved).
      final daily = await save(BackupReason.daily, 5);
      // A file made long ago, opened today.
      final old = (await BackupArchive.build(dir,
              reason: BackupReason.manual, device: 'Old TV', createdAt: DateTime.utc(2025, 6, 1)))
          .bytes;
      await store.save(old, kind: BackupReason.file, at: DateTime.utc(2026, 1, 9));
      final newer = (await BackupArchive.build(dir,
              reason: BackupReason.manual, device: 'Test TV', createdAt: DateTime.utc(2026, 1, 10)))
          .bytes;
      await store.save(newer, kind: BackupReason.file, at: DateTime.utc(2026, 1, 10));
      final list = await store.list();
      expect([for (final b in list) b.createdAt], [daily.createdAt, DateTime.utc(2026, 1, 10), DateTime.utc(2025, 6, 1)]);
      expect([for (final b in list) b.kind], [BackupReason.daily, BackupReason.file, BackupReason.file]);
      // A file from another device made after it: listed first, but the
      // cloud copy and "Last backup" stay with this setup's daily.
      final elsewhere = (await BackupArchive.build(dir,
              reason: BackupReason.manual, device: 'Other TV', createdAt: DateTime.now().add(const Duration(hours: 1))))
          .bytes;
      await store.save(elsewhere, kind: BackupReason.file);
      final again = await store.list();
      expect(again.first.archive.device, 'Other TV');
      expect(BackupStore.newestOwn(again)!.name, daily.name);
      expect(await store.cloudCopy.readAsBytes(), await daily.file.readAsBytes());
    });

    test('a cloud copy alone (as Android restores it) is listed as a backup', () async {
      await save(BackupReason.daily, 1);
      final copy = await store.cloudCopy.readAsBytes();
      await store.dir.delete(recursive: true);
      await store.cloudDir.create(recursive: true);
      await store.cloudCopy.writeAsBytes(copy);
      final list = await store.list();
      expect(list, hasLength(1));
      expect(list.single.kind, BackupReason.manual);
      expect(await list.single.file.readAsBytes(), copy);
      // Listed once, not again on the next look.
      expect(await store.list(), hasLength(1));
    });

    test('a crash mid-write leaves no partial .ntvbackup', () async {
      await save(BackupReason.daily, 1);
      // A write cut short leaves only its temp file, which isn't listed.
      await File('${store.dir.path}/.20260105T000000000Z_daily.ntvbackup.123.partial')
          .writeAsBytes(bytes.sublist(0, 10));
      final names = [for (final f in store.dir.listSync()) f.uri.pathSegments.last];
      expect(names.where((n) => n.endsWith('.ntvbackup')), hasLength(1));
      expect(await store.list(), hasLength(1));
      // A damaged file in the folder isn't listed either.
      await File('${store.dir.path}/20260106T000000000Z_daily.ntvbackup').writeAsBytes(bytes.sublist(0, 10));
      expect(await store.list(), hasLength(1));
      // And a failing write leaves nothing behind.
      await store.dir.delete(recursive: true);
      await File(store.dir.path).writeAsString('in the way');
      await expectLater(save(BackupReason.daily, 2), throwsA(isA<FileSystemException>()));
    });
  });
}
