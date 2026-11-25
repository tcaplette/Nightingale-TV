import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/server/smb/smb_profile.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/server_set.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/convert/ffmpeg_programs.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/server/smb/secret_store.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_server.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

import 'smb_fakes.dart';

void main() {
  setUpAll(() => SmbGateway.inIsolate = false);
  tearDownAll(SmbGateway.stop);

  test('a share as the main server: start-up, its client, and sign-out forgetting its password', () async {
    final dir = await Directory.systemTemp.createTemp('smb_main');
    addTearDown(() => dir.delete(recursive: true));
    final storage = await AppStorage.at(Directory('${dir.path}/p'), logosDir: Directory('${dir.path}/logos'));
    final ref = await SecretStore(storage).put(const SmbCredentials(user: 'u', password: 'secret-pw'));
    await storage.writeJson('session.json', {
      'kind': 'smb', 'serverUrl': 'smb://127.0.0.1:1/media', 'serverName': 'media', 'serverId': 'id1', //
      'userId': 'u', 'userName': 'u', 'accessToken': ref, 'deviceId': 'd',
    });
    await storage.writeJson('smb_shares.json', {
      'shares': {
        'id1': {
          'folders': [
            {'path': '', 'type': 'movies'}
          ]
        }
      }
    });
    await storage.flush();
    final app = AppState(storage, runAnalysis: false);
    addTearDown(app.close);
    await app.start();
    expect(app.client, isA<SmbServer>());
    expect(SmbGateway.running, isTrue);
    expect(await app.smb.credentials(ref), isNotNull);
    // The share isn't there: the first scan fails, and the profile stays.
    expect(app.syncError, isNotNull);
    await app.signOut();
    await storage.flush();
    expect(File('${dir.path}/p/${SecretStore.file}').existsSync(), isFalse);
    expect(File('${dir.path}/p/smb_shares.json').existsSync(), isFalse);
    expect(app.phase, AppPhase.signedOut);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a share signed in to, or added, has a pool for each Commercials and Bumpers folder', () async {
    IndexBuilder.useIsolate = false;
    FfmpegPrograms.reset(const FfmpegPrograms(ffmpeg: '/nonexistent/ffmpeg', ffprobe: '/nonexistent/ffprobe'));
    addTearDown(() {
      FfmpegPrograms.reset();
      SmbProfile.openOverride = null;
    });
    FakeShare share(String name) => FakeShare({
          'Movies/Heat (1995).mkv': 10,
          'Commercials/Soda.mkv': 1,
          'Bumpers/Station ID.mkv': 1,
          'Notes/$name.txt': 1,
        });
    final shares = {'media': share('media'), 'more': share('more')};
    SmbProfile.openOverride = (address, who, {knownSmb1 = false, workers = 2}) async => shares[address.share]!;
    final dir = await Directory.systemTemp.createTemp('smb_pools');
    addTearDown(() => dir.delete(recursive: true));
    final app = AppState(await AppStorage.at(Directory('${dir.path}/p'), logosDir: Directory('${dir.path}/logos')), runAnalysis: false);
    addTearDown(app.close);
    await app.start();
    SignInFlow flow({bool adding = false}) => SignInFlow(app, adding: adding)
      ..openShare = ((address, who) async => shares[address.share]!);

    // The first sign-in: the folder names are suggested as Movies,
    // Commercials and Bumpers.
    final first = flow();
    await first.smbConnect('smb://nas/media');
    expect(first.step.smb.mappings, {'Movies': SmbFolderType.movies, 'Commercials': SmbFolderType.commercials, 'Bumpers': SmbFolderType.bumpers});
    await first.finishSmb();
    first.dispose();
    // Each pool's root is its folder, by the id it has in the library.
    Set<(PoolKind, String)> pools() => {for (final p in app.settings.commercialPools) (p.kind, p.roots.single.itemId)};
    final media = app.servers.main.key;
    expect(pools(), {
      (PoolKind.commercials, ServerSet.globalId(media, smbIdOf('Commercials/'))),
      (PoolKind.bumpers, ServerSet.globalId(media, smbIdOf('Bumpers/'))),
    });

    // Another share added to the profile.
    final added = flow(adding: true);
    await added.smbConnect('smb://nas/more');
    await added.finishSmb();
    added.dispose();
    final more = app.servers.all.last.key;
    expect(more, isNot(media));
    expect(pools(), hasLength(4));
    expect(pools(), containsAll([
      (PoolKind.commercials, ServerSet.globalId(more, smbIdOf('Commercials/'))),
      (PoolKind.bumpers, ServerSet.globalId(more, smbIdOf('Bumpers/'))),
    ]));
    // The same folders saved again add no pools.
    await app.setSmbMappings(more, app.smb.configOf((app.servers.all.last.client! as SmbServer).serverId).mappings, refresh: false);
    expect(pools(), hasLength(4));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
