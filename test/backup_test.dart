import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
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

    test('never holds the trial or the purchase (play-unlock), and a restore leaves them alone', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      final store = Directory('${dir.path}/store')..createSync();
      const trial = '{"start":1000,"lastSeen":2000,"marker":"trial-start"}';
      const unlock = '{"owned":true,"checked":3000,"marker":"cached-unlock"}';
      const notices = '{"welcome":true,"marker":"notices-seen"}';
      File('${store.path}/trial.json').writeAsStringSync(trial);
      File('${store.path}/unlock.json').writeAsStringSync(unlock);
      File('${store.path}/notices.json').writeAsStringSync(notices);

      final built = await build();
      final text = utf8.decode(gzip.decode(built.bytes));
      for (final marker in ['trial-start', 'cached-unlock', 'notices-seen', 'lastSeen']) {
        expect(text, isNot(contains(marker)));
      }

      // Another device's trial files don't come in with its backup, and this
      // device's stay as they were.
      final h = await openHousehold(dir);
      addTearDown(() {
        h.leave();
        h.backups?.dispose();
      });
      File('${store.path}/trial.json').writeAsStringSync('{"start":5,"lastSeen":6}');
      await BackupRestorer(h).restore(built.bytes);
      expect(File('${store.path}/trial.json').readAsStringSync(), '{"start":5,"lastSeen":6}');
      expect(File('${store.path}/unlock.json').readAsStringSync(), unlock);
      expect(File('${store.path}/notices.json').readAsStringSync(), notices);
      await Future<void>.delayed(const Duration(milliseconds: 50));
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

  group('still watching (idle-power)', () {
    Future<Map<String, Object?>> momSettings(BuiltBackup built) async =>
        {...BackupArchive.check(built.bytes).profiles[momAndKids().first.id]!.settings!, 'installId': 'x'};

    test('a backup carries the still-watching time', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      final storage = AppStorage.existing(Directory('${dir.path}/profiles/${momAndKids().first.id}'));
      final settings = await storage.readRaw('settings.json') as Map<String, Object?>;
      final playback = PlaybackSettings.fromJson(settings['playback'])
          .copyWith(stillWatchingAfter: () => const Duration(hours: 2));
      await storage.writeJson('settings.json', {...settings, 'playback': playback.toJson()});
      await storage.flush();
      final restored = AppSettings.fromJson(await momSettings(await build()));
      expect(restored.playback.stillWatchingAfter, const Duration(hours: 2));
    });

    test('Off is carried too', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      final storage = AppStorage.existing(Directory('${dir.path}/profiles/${momAndKids().first.id}'));
      final settings = await storage.readRaw('settings.json') as Map<String, Object?>;
      final playback = PlaybackSettings.fromJson(settings['playback']).copyWith(stillWatchingAfter: () => null);
      await storage.writeJson('settings.json', {...settings, 'playback': playback.toJson()});
      await storage.flush();
      final restored = AppSettings.fromJson(await momSettings(await build()));
      expect(restored.playback.stillWatchingAfter, isNull);
    });

    test('a backup from before the setting asks after 4 hours', () async {
      final bytes = edited((await household()).bytes, (j) {
        for (final id in [for (final p in momAndKids()) p.id]) {
          final settings = part(j, id)['settings'] as Map<String, Object?>?;
          final playback = settings?['playback'];
          if (playback is Map<String, Object?>) playback.remove('stillWatchingAfterMinutes');
        }
      });
      final archive = BackupArchive.check(bytes);
      for (final p in momAndKids()) {
        final settings = AppSettings.fromJson({...?archive.profiles[p.id]!.settings, 'installId': 'x'});
        expect(settings.playback.stillWatchingAfter, const Duration(hours: 4), reason: p.name);
      }
    });
  });

  group('the store (backup-simplify D1)', () {
    late BackupStore store;
    late Uint8List bytes;

    setUp(() async {
      store = BackupStore(Directory('${dir.path}/backups'));
      bytes = (await household(logos: 0)).bytes;
    });

    test('two fixed files: the automatic backup in cloud/, the undo point beside it', () async {
      expect(await store.latest(), isNull);
      expect(await store.undo(), isNull);
      await store.writeLatest(bytes);
      await store.writeUndo(bytes);
      expect(store.latestFile.path, endsWith('backups/cloud/latest.ntvbackup'));
      expect(store.undoFile.path, endsWith('backups/undo.ntvbackup'));
      expect((await store.latest())!.fingerprint, (await store.undo())!.fingerprint);
      // Writing again replaces, never adds.
      for (var i = 0; i < 5; i++) {
        await store.writeLatest(bytes);
        await store.writeUndo(bytes);
      }
      expect(_names(store.dir), {'cloud/latest.ntvbackup', 'undo.ntvbackup'});
    });

    test('the undo label names the action', () async {
      Future<String> label(String reason, [String? subject]) async {
        final b = await BackupArchive.build(dir, reason: reason, device: 'TV', subject: subject);
        return (await store.writeUndo(b.bytes)).undoLabel;
      }

      expect(await label(BackupReason.beforeRestore), 'Undo restore');
      expect(await label(BackupReason.beforeReset), 'Undo lineup reset');
      expect(await label(BackupReason.beforeDelete, 'Kids'), 'Undo deleting Kids');
      expect(await label(BackupReason.beforeDelete), 'Undo deleting a profile');
      expect(await label(BackupReason.beforeUpgrade), 'Undo update');
      expect(await label(BackupReason.beforeLineupCleanup), 'Undo lineup cleanup');
    });

    test('a damaged file reads as none, and a crash mid-write leaves no partial backup', () async {
      await store.cloudDir.create(recursive: true);
      await store.latestFile.writeAsBytes(bytes.sublist(0, 10));
      expect(await store.latest(), isNull);
      await store.writeLatest(bytes);
      expect(await store.latest(), isNotNull);
      // A failing write leaves the folder as it was, with no temp file.
      await Directory(store.undoFile.path).create();
      await expectLater(store.writeUndo(bytes), throwsA(isA<FileSystemException>()));
      expect(store.dir.listSync().where((f) => f.path.endsWith('.partial')), isEmpty);
    });
  });

  group('clearing out older backups (backup-simplify D10)', () {
    late BackupStore store;
    final now = DateTime.utc(2026, 11, 24, 12);

    setUp(() async {
      store = BackupStore(Directory('${dir.path}/backups'));
      await writeHousehold(dir, momAndKids(), fakeLibrary());
    });

    /// An old-style `<stamp>_<reason>.ntvbackup` made [ago] before [now].
    Future<File> old(String reason, Duration ago, {String device = 'Test TV'}) async {
      final at = now.subtract(ago);
      final b = await BackupArchive.build(dir, reason: reason, device: device, createdAt: at);
      String two(int n) => n.toString().padLeft(2, '0');
      final stamp = '${at.year}${two(at.month)}${two(at.day)}T${two(at.hour)}${two(at.minute)}${two(at.second)}'
          '${at.millisecond.toString().padLeft(3, '0')}Z';
      await store.dir.create(recursive: true);
      return File('${store.dir.path}/${stamp}_$reason.ntvbackup')..writeAsBytesSync(b.bytes);
    }

    test('14 daily, 9 safety and 3 made by you become latest and undo', () async {
      for (var i = 0; i < 14; i++) {
        await old(BackupReason.daily, Duration(days: i + 2));
      }
      for (var i = 0; i < 9; i++) {
        await old(i == 0 ? BackupReason.beforeReset : BackupReason.beforeDelete, Duration(days: i + 1));
      }
      for (var i = 0; i < 3; i++) {
        await old(BackupReason.manual, Duration(days: 3 + i, hours: 1), device: 'Mine $i');
      }
      // A newer file opened from elsewhere is never this setup's.
      await old('file', const Duration(hours: 1), device: 'Elsewhere');
      await old('from-official', const Duration(hours: 2), device: 'Elsewhere');
      await File('${store.dir.path}/.20261120T000000000Z_daily.ntvbackup.99999.partial').writeAsBytes([1, 2, 3]);

      await store.clearOldBackups(now: now);

      expect(_names(store.dir), {'cloud/latest.ntvbackup', 'undo.ntvbackup'});
      // The newest of this setup's own: yesterday's, not the newer opened files.
      expect((await store.latest())!.createdAt, now.subtract(const Duration(days: 1)));
      expect((await store.latest())!.archive.device, 'Test TV');
      final undo = (await store.undo())!;
      expect(undo.reason, BackupReason.beforeReset);
      expect(undo.undoLabel, 'Undo lineup reset');
      // Once only: nothing old is left to clear.
      await store.clearOldBackups(now: now);
      expect(_names(store.dir), {'cloud/latest.ntvbackup', 'undo.ntvbackup'});
    });

    test('a safety backup older than 7 days isn\'t kept; a newer latest stays', () async {
      await old(BackupReason.beforeReset, const Duration(days: 21));
      await old(BackupReason.daily, const Duration(days: 3));
      final newer = await BackupArchive.build(dir, reason: BackupReason.daily, device: 'Now', createdAt: now);
      await store.writeLatest(newer.bytes);
      await store.clearOldBackups(now: now);
      expect(_names(store.dir), {'cloud/latest.ntvbackup'});
      expect((await store.latest())!.archive.device, 'Now');
      expect(await store.undo(), isNull);
    });

    test('a folder with nothing old is left alone', () async {
      final b = await BackupArchive.build(dir, reason: BackupReason.daily, device: 'TV');
      await store.writeLatest(b.bytes);
      final before = store.latestFile.statSync().modified;
      await store.clearOldBackups(now: now);
      expect(store.latestFile.statSync().modified, before);
    });
  });

  group('the automatic backup and the undo point (backup-simplify D2, D4)', () {
    late Household h;
    late BackupScheduler backups;

    setUp(() async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      h = await openHousehold(dir);
      backups = h.backups!;
    });

    tearDown(() {
      h.leave();
      backups.dispose();
    });

    Future<void> editSettings(void Function(Map<String, Object?> s) edit) async {
      final storage = AppStorage.existing(Directory('${dir.path}/profiles/${momAndKids().first.id}'));
      final settings = {...await storage.readRaw('settings.json') as Map<String, Object?>};
      edit(settings);
      await storage.writeJson('settings.json', settings);
      await storage.flush();
    }

    test('watching doesn\'t rewrite it; a rename does; it stays the only file', () async {
      expect(await backups.automaticCheck(), isNotNull);
      final first = (await backups.store.latest())!;
      for (var i = 0; i < 10; i++) {
        await editSettings((s) => s
          ..['lastChannelId'] = 'ch$i'
          ..['guideTab'] = 'tab$i');
        expect(await backups.automaticCheck(), isNull, reason: 'channel change $i');
      }
      expect((await backups.store.latest())!.createdAt, first.createdAt);

      final storage = AppStorage.existing(Directory('${dir.path}/profiles/${momAndKids().first.id}'));
      final channels = (await storage.readRaw('channels.json') as List).cast<Map<String, Object?>>();
      channels.first['name'] = 'Renamed';
      await storage.writeJson('channels.json', channels);
      await storage.flush();
      final again = await backups.automaticCheck();
      expect(again, isNotNull);
      expect(jsonEncode(again!.archive.profiles[momAndKids().first.id]!.channels), contains('Renamed'));
      // It still holds where the profile was watching.
      expect(again.archive.profiles[momAndKids().first.id]!.settings!['lastChannelId'], 'ch9');
      expect(_names(backups.store.dir), {'cloud/latest.ntvbackup'});
    });

    test('a month of changes leaves two files at most', () async {
      for (var day = 0; day < 30; day++) {
        await editSettings((s) => s['marker'] = 'day $day');
        await backups.automaticCheck();
        if (day % 7 == 0) await backups.saveUndoPoint(BackupReason.beforeReset);
      }
      expect(_names(backups.store.dir), {'cloud/latest.ntvbackup', 'undo.ntvbackup'});
    });

    test('the undo point replaces the one before, and is skipped only for the same household and change', () async {
      await backups.saveUndoPoint(BackupReason.beforeDelete, subject: 'Kids');
      expect((await backups.store.undo())!.undoLabel, 'Undo deleting Kids');
      // The same household and change: nothing new saved.
      expect(await backups.saveUndoPoint(BackupReason.beforeDelete, subject: 'Kids'), isNull);
      // The same household for another change: saved again, so the button
      // names the change it undoes.
      expect(await backups.saveUndoPoint(BackupReason.beforeReset), isNotNull);
      expect((await backups.store.undo())!.undoLabel, 'Undo lineup reset');
      await editSettings((s) => s['marker'] = 'changed');
      await backups.saveUndoPoint(BackupReason.beforeDelete, subject: 'Mom');
      expect((await backups.store.undo())!.undoLabel, 'Undo deleting Mom');
      expect(_names(backups.store.dir), {'undo.ntvbackup'});
    });

    test('an undo point that can\'t be saved refuses a delete', () async {
      await Directory(backups.store.undoFile.path).create(recursive: true);
      final kids = h.profiles.firstWhere((p) => p.name == 'Kids');
      await expectLater(h.deleteProfile(kids),
          throwsA(isA<BackupException>().having((e) => e.message, 'message', startsWith('Couldn\'t save a backup first:'))));
      expect(h.profiles.map((p) => p.name), contains('Kids'));
    });

    test('the first check clears out older backups', () async {
      final b = await BackupArchive.build(dir, reason: BackupReason.daily, device: 'Old');
      await backups.store.dir.create(recursive: true);
      await File('${backups.store.dir.path}/20260101T000000000Z_daily.ntvbackup').writeAsBytes(b.bytes);
      await backups.automaticCheck();
      expect(_names(backups.store.dir), {'cloud/latest.ntvbackup'});
    });
  });

  group('picked Live TV files (backup-simplify D6)', () {
    final mom = momAndKids().first.id;

    /// Mom's M3U source with a picked [playlistMb] playlist and a picked
    /// [guideMb] guide, plus [extra] more playlists of the sizes given.
    Future<void> pickedFiles({double playlistMb = 3, double guideMb = 120, List<double> extra = const []}) async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      final storage = AppStorage.existing(Directory('${dir.path}/profiles/$mom'));
      final files = Directory('${storage.root.path}/live_files')..createSync(recursive: true);
      final sources = <Map<String, Object?>>[];
      void source(String id, double mb, {bool guide = false}) {
        File('${files.path}/$id-playlist.m3u').writeAsStringSync(_noise(mb, '#EXTINF:-1,$id\n'));
        if (guide) File('${files.path}/$id-guide.xml').writeAsStringSync(_guide(guideMb));
        sources.add({
          'id': id,
          'kind': 'm3u',
          'name': id,
          'playlistFile': '$id-playlist.m3u',
          if (guide) 'guideFile': '$id-guide.xml',
          'chosen': <String, Object?>{},
        });
      }

      source('src1', playlistMb, guide: true);
      for (var i = 0; i < extra.length; i++) {
        source('srcx$i', extra[i]);
      }
      await storage.writeJson('live_sources.json', {'sources': sources});
      await storage.flush();
    }

    test('the automatic build leaves out a 120 MB guide and stays under 20 MB with a 3 MB playlist', () async {
      await pickedFiles();
      final automatic = await BackupArchive.build(dir,
          reason: BackupReason.daily, device: 'TV', pickedFiles: PickedFiles.automatic);
      expect(automatic.bytes.length, lessThan(BackupArchive.automaticBudget));
      final saved = BackupArchive.check(automatic.bytes).profiles[mom]!;
      expect(saved.liveFiles.keys, ['src1-playlist.m3u']);
      expect(saved.leftOut, ['src1-guide.xml']);

      final all = await BackupArchive.build(dir, reason: BackupReason.manual, device: 'TV');
      final whole = BackupArchive.decode(all.bytes).profiles[mom]!;
      expect(whole.liveFiles.keys.toSet(), {'src1-playlist.m3u', 'src1-guide.xml'});
      expect(whole.leftOut, isEmpty);
      // The list of what was left out isn't part of the fingerprint.
      final withoutList = edited(automatic.bytes, (j) => part(j, mom).remove('leftOut'));
      expect(BackupArchive.decode(withoutList).fingerprint, automatic.fingerprint);
      final again = await BackupArchive.build(dir,
          reason: BackupReason.daily, device: 'TV', pickedFiles: PickedFiles.automatic);
      expect(again.fingerprint, automatic.fingerprint);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('over the budget, the largest playlists go first', () async {
      // Random text gzips poorly: 1 + 20 + 14 + 2 MB doesn't fit in 20 MB.
      await pickedFiles(playlistMb: 1, guideMb: 0.01, extra: [20, 14, 2]);
      final automatic = await BackupArchive.build(dir,
          reason: BackupReason.daily, device: 'TV', pickedFiles: PickedFiles.automatic);
      expect(automatic.bytes.length, lessThan(BackupArchive.automaticBudget));
      final saved = BackupArchive.decode(automatic.bytes).profiles[mom]!;
      expect(saved.leftOut, ['src1-guide.xml', 'srcx0-playlist.m3u']);
      expect(saved.liveFiles.keys.toSet(), {'src1-playlist.m3u', 'srcx1-playlist.m3u', 'srcx2-playlist.m3u'});
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a backup without leftOut (older versions) still reads', () async {
      await pickedFiles(guideMb: 0.01);
      final all = await BackupArchive.build(dir, reason: BackupReason.manual, device: 'TV');
      final json = unzip(all.bytes);
      expect(part(json, mom).containsKey('leftOut'), isFalse);
      expect(BackupArchive.check(all.bytes).profiles[mom]!.leftOut, isEmpty);
    });
  });
}

/// The files under [dir], as paths relative to it.
Set<String> _names(Directory dir) => {
      if (dir.existsSync())
        for (final f in dir.listSync(recursive: true))
          if (f is File) f.path.substring(dir.path.length + 1),
    };

/// About [mb] megabytes starting with [line], then random letters, which
/// gzip can't shrink much.
String _noise(double mb, String line) {
  final rng = Random(mb.hashCode);
  const letters = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final codes = Uint8List((mb * 1024 * 1024).round());
  for (var i = 0; i < codes.length; i++) {
    codes[i] = i % 64 == 63 ? 0x0a : letters.codeUnitAt(rng.nextInt(letters.length));
  }
  return line + String.fromCharCodes(codes);
}

/// About [mb] megabytes of XMLTV, which gzips as well as a real guide.
String _guide(double mb) {
  const programme = '<programme start="20261124120000 +0000" stop="20261124130000 +0000" channel="ch1">'
      '<title>The Evening News</title><desc>Today\'s stories.</desc></programme>\n';
  final count = (mb * 1024 * 1024 / programme.length).ceil();
  return '<tv>\n${programme * count}</tv>\n';
}
