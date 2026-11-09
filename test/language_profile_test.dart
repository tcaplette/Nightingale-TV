import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/profiles/profile.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';

void main() {
  test('a profile saved before this feature is Automatic and otherwise unchanged', () {
    final old = {'id': 'a', 'name': 'Mom', 'kind': 'adult', 'color': 3};
    final p = Profile.fromJson(old);
    expect(p.language, isNull);
    expect(p.color, 3);
    expect(p.toJson(), old, reason: 'Automatic adds nothing to the file');
  });

  test('a language is saved', () {
    final p = Profile(id: 'a', name: 'Mom', language: 'fr');
    expect(jsonDecode(jsonEncode(p.toJson()))['language'], 'fr');
    expect(Profile.fromJson(p.toJson()).language, 'fr');
  });

  test('an unsupported value loads as Automatic', () {
    expect(Profile.fromJson({'id': 'a', 'name': 'Mom', 'language': 'tlh'}).language, isNull);
  });

  test('a backup brings a profile\'s language back', () async {
    BackupArchive.useIsolate = false;
    addTearDown(() => BackupArchive.useIsolate = true);
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_language_backup');
    addTearDown(() => dir.delete(recursive: true));
    await writeHousehold(dir, [Profile(id: 'mom0000000000001', name: 'Mom', language: 'fr')], fakeLibrary());
    final h = await openHousehold(dir);
    final backup = (await h.backups!.backUp(BackupReason.manual))!;
    final bytes = await h.backups!.store.read(backup);
    await h.setLanguage(h.profiles.first, 'de');
    await BackupRestorer(h).restore(bytes);
    expect(h.profiles.first.language, 'fr');
    await h.closeAll();
  });
}
