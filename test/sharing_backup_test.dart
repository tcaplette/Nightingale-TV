import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/sharing/share_session_store.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';
import 'sharing_test.dart' show sessionJson;

/// Backups never hold share sign-ins, and a restore keeps this device's
/// (share-accounts; backup-restore "Backups never hold sign-in tokens or
/// device ids").
void main() {
  late Directory dir;
  final households = <Household>[];

  setUp(() async => dir = await Directory.systemTemp.createTemp('ntv_share_backup'));
  tearDown(() async {
    for (final h in households) {
      h.leave();
      h.backups?.dispose();
    }
    households.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dir.delete(recursive: true);
  });

  final mom = momAndKids().first;
  const email = 'share-signin@example.com';

  Future<(Household, String)> linkedHousehold() async {
    await writeHousehold(dir, momAndKids(), fakeLibrary(), logos: 0);
    final h = await openHousehold(dir);
    households.add(h);
    final store = ShareSessionStore(h.root);
    await store.load();
    final session = sessionJson('user-mom');
    await store.put(mom.id, ShareSignIn(session: session, userId: 'user-mom', email: email));
    await h.root.flush();
    return (h, session);
  }

  test('a backup holds no share session tokens and no share email', () async {
    final (h, session) = await linkedHousehold();
    final tokens = jsonDecode(session) as Map<String, Object?>;
    final built = await BackupArchive.build(dir, reason: BackupReason.manual, device: 'Test TV');
    final text = utf8.decode(gzip.decode(built.bytes));
    for (final secret in [tokens['access_token'] as String, tokens['refresh_token'] as String, email, 'user-mom']) {
      expect(text, isNot(contains(secret)));
    }
    expect(text, isNot(contains(ShareSessionStore.fileName)));
    expect(h.profiles, isNotEmpty);
  });

  test('a restore keeps this device\'s share sign-ins', () async {
    final (h, session) = await linkedHousehold();
    final backup = (await h.backups!.backUp(BackupReason.manual))!;
    final bytes = await h.backups!.store.read(backup);
    await BackupRestorer(h).restore(bytes);
    final after = ShareSessionStore(h.root);
    await after.load();
    expect(after[mom.id]?.session, session);
    expect(after[mom.id]?.email, email);
  });
}
