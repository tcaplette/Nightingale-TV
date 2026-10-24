import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';

import 'fixtures.dart';

/// A PNG the logo store could have made, and its name.
Uint8List fakeLogo([int shade = 0]) =>
    Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)..clear(img.ColorRgb8(shade, shade, shade))));

String logoNameFor(int i) => '${i.toRadixString(16).padLeft(16, '0')}.png';

/// The access token [writeProfile] signs [id] in with.
String tokenFor(String id) => 'secret-token-$id';

/// The Plex account token [writeProfile] gives a Plex sign-in of [id].
String accountTokenFor(String id) => 'secret-account-$id';

/// Writes [p]'s files under [root]: signed in to [serverId] (a [kind]
/// server: null for Jellyfin, `emby` or `plex`) with a cached [library] and
/// lineup, and one programming block. Returns its install id.
Future<String> writeProfile(Directory root, Profile p, LibraryIndex library,
    {String serverId = 's1', bool signedIn = true, Map<String, Object?>? settings, String? kind}) async {
  final dir = Directory('${root.path}/profiles/${p.id}');
  final app = await signedInApp(dir, library, serverId: serverId, settings: settings);
  await app.saveBlock(app.newBlock()..title = 'Cartoons');
  final installId = app.settings.installId;
  await app.close();
  final storage = AppStorage.existing(dir);
  if (signedIn) {
    await storage.writeJson('session.json', {
      'serverUrl': 'http://127.0.0.1:9',
      'serverName': 'Home',
      'serverId': serverId,
      'userId': 'u-${p.id}',
      'userName': p.name.toLowerCase(),
      'accessToken': tokenFor(p.id),
      'deviceId': installId,
      'kind': ?kind,
      if (kind == 'plex') 'accountToken': accountTokenFor(p.id),
    });
  } else {
    await storage.delete('session.json');
  }
  await storage.flush();
  return installId;
}

/// A household of [profiles] in [root], each written by [writeProfile],
/// with [logos] custom logos.
Future<void> writeHousehold(Directory root, List<Profile> profiles, LibraryIndex library,
    {int logos = 0, String serverId = 's1'}) async {
  final storage = await AppStorage.at(root);
  for (final p in profiles) {
    await writeProfile(root, p, library, serverId: serverId);
  }
  await storage.writeJson('profiles.json', [for (final p in profiles) p.toJson()]);
  for (var i = 0; i < logos; i++) {
    await File('${storage.logosDir.path}/${logoNameFor(i + 1)}').writeAsBytes(fakeLogo(i * 40));
  }
  await storage.flush();
}

/// The household in [root], making backups into `backups/`, started.
Future<Household> openHousehold(Directory root, {bool start = true}) async {
  final h = Household(await AppStorage.at(root), runAnalysis: false);
  h.backups = BackupScheduler(h, BackupStore(Directory('${root.path}/backups')));
  if (start) await h.start();
  return h;
}

/// "Mom" (grown-up, PIN 1234) and "Kids".
List<Profile> momAndKids() => [
      Profile(id: 'mom0000000000001', name: 'Mom')..setPin('1234'),
      Profile(id: 'kids000000000002', name: 'Kids', kind: ProfileKind.kid, color: 1),
    ];
