// Makes a backup holding an Emby profile and a Plex profile, from the test
// servers (tool/test_servers), for restoring on another device. Run once per
// server, with the same HOUSEHOLD folder (only one server runs at a time):
//
//   MEDIA_SERVER=emby EMBY_USER=... EMBY_PASSWORD=... HOUSEHOLD=/tmp/h \
//     flutter test integration_test/servers_backup_live_test.dart -d linux
//   MEDIA_SERVER=plex HOUSEHOLD=/tmp/h BACKUP_OUT=/tmp/two-servers.ntvbackup \
//     flutter test integration_test/servers_backup_live_test.dart -d linux
//
// Each run adds a profile ("Emby kid", "Plex dad") signed in to that server;
// the run with BACKUP_OUT also writes the backup there.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';

final _env = Platform.environment;

void main() {
  testWidgets('a profile on the ${_env['MEDIA_SERVER']} test server, backed up', (tester) async {
    final kind = _env['MEDIA_SERVER'], home = _env['HOUSEHOLD'];
    if ((kind != 'emby' && kind != 'plex') || home == null) {
      markTestSkipped('Set MEDIA_SERVER (emby or plex) and HOUSEHOLD.');
      return;
    }
    await tester.runAsync(() async {
      final dir = await Directory(home).create(recursive: true);
      final household = Household(await AppStorage.at(dir), runAnalysis: false);
      await household.start();
      final name = kind == 'emby' ? 'Emby kid' : 'Plex dad';
      var profile = household.profiles.where((p) => p.name == name).firstOrNull;
      if (profile == null) {
        // A first run's own profile is renamed; later ones are added.
        final fresh = household.profiles.length == 1 && household.current?.name == 'Me' && household.app?.session == null;
        final draft = fresh ? household.profiles.single : household.newProfile();
        draft.name = name;
        await household.saveProfile(draft);
        profile = household.profiles.firstWhere((p) => p.name == name);
      }
      await household.select(profile);
      final app = household.app!;
      if (app.session == null) {
        if (kind == 'emby') {
          final client = app.clientFor(ServerKind.emby, 'http://127.0.0.1:8096')
              as JellyfinClient;
          final info = await client.publicInfo();
          await app.completeSignIn(
              await client.authenticateByName(_env['EMBY_USER']!, _env['EMBY_PASSWORD']!, serverName: info.name),
              client);
        } else {
          const url = 'http://127.0.0.1:32400';
          final probe = app.clientFor(ServerKind.plex, url);
          final info = await probe.publicInfo();
          probe.close();
          final session = ServerSession(
            kind: ServerKind.plex,
            serverUrl: url,
            serverName: info.name,
            serverId: info.id,
            userId: 'local',
            userName: 'local',
            accessToken: '',
            deviceId: app.settings.installId,
          );
          await app.completeSignIn(session, app.clientForSession(session));
        }
      }
      expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
      expect(app.channels, isNotEmpty);
      // ignore: avoid_print
      print('$name: ${app.session!.kind.name} ${app.session!.serverUrl}, ${app.channels.length} channels');
      final out = _env['BACKUP_OUT'];
      if (out != null) {
        await household.flushAll();
        final built = await BackupArchive.build(dir, reason: 'manual', device: 'Linux test PC');
        await File(out).writeAsBytes(built.bytes);
        // ignore: avoid_print
        print('Backup: ${built.bytes.length} bytes, ${household.profiles.map((p) => p.name).join(', ')} → $out');
      }
      household.leave();
    });
  });
}
