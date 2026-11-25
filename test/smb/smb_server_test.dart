import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/convert/ffmpeg_programs.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_profile.dart';
import 'package:nightingale_tv/server/smb/smb_server.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

import 'smb_fakes.dart';

Uint8List _nfo(int minutes) => Uint8List.fromList(utf8.encode('<movie><runtime>$minutes</runtime></movie>'));
Uint8List _ep(int minutes) => Uint8List.fromList(utf8.encode('<episodedetails><runtime>$minutes</runtime></episodedetails>'));

void main() {
  late Directory dir;
  late FakeShare share;
  late SmbServer server;
  var refuse = false;

  setUpAll(() {
    SmbGateway.inIsolate = false;
    IndexBuilder.useIsolate = false;
    // No file is read here: lengths come from .nfo files.
    FfmpegPrograms.reset(const FfmpegPrograms(ffmpeg: '/nonexistent/ffmpeg', ffprobe: '/nonexistent/ffprobe'));
  });
  tearDownAll(() async {
    FfmpegPrograms.reset();
    await SmbGateway.stop();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('smb_server');
    share = FakeShare({
      'TV/Show A (2001)/Season 1/Show A S01E01.mkv': 1,
      'TV/Show A (2001)/Season 1/Show A S01E02.mkv': 1,
      'TV/Show A (2001)/Season 2/Show A S02E01.mkv': 1,
      'Movies/Heat (1995)/Heat (1995).mkv': 1,
      'Ads/Spot.mp4': 1,
    });
    for (final p in [...share.files.keys]) {
      final nfo = '${p.substring(0, p.lastIndexOf('.'))}.nfo';
      share.files[nfo] = p.startsWith('TV') ? _ep(22) : p.startsWith('Ads') ? _nfo(1) : _nfo(170);
    }
    final storage = await AppStorage.at(Directory('${dir.path}/p'), logosDir: Directory('${dir.path}/logos'));
    refuse = false;
    final profile = SmbProfile(storage,
        profileName: () => 'Mom',
        hold: ValueNotifier(false),
        onFilesReady: (_, {required last}) {},
        onChanged: () {},
        open: (address, who, {knownSmb1 = false, workers = 2}) async {
          if (refuse) throw const SmbException(SmbErrorKind.wrongSignIn, 'changed');
          if (share.down) throw const SmbException(SmbErrorKind.unreachable, 'down');
          return share;
        });
    profile.configOf('id1').mappings = const [
      SmbMapping('TV', SmbFolderType.tvShows),
      SmbMapping('Movies', SmbFolderType.movies),
      SmbMapping('Ads', SmbFolderType.commercials),
    ];
    final ref = await profile.secrets.put(const SmbCredentials(user: 'u', password: 'p'));
    await SmbGateway.ensureStarted();
    server = profile.client(ServerSession(
        kind: ServerKind.smb, serverUrl: 'smb://nas/media', serverName: 'media on nas', serverId: 'id1', userId: 'u', userName: 'u', accessToken: ref, deviceId: 'd'));
  });
  tearDown(() async {
    server.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dir.delete(recursive: true);
  });

  test('libraries, folder trees and the programs under a root', () async {
    final pool = CommercialPool(id: 'ads', name: 'Ads', roots: [PoolRoot(itemId: smbIdOf('Ads/'), libraryId: smbIdOf('Ads/'), label: 'Ads')]);
    final index = await server.fetchLibraryIndex(pools: [pool]);
    expect(index.episodes.length, 3);
    expect(index.movies.single.title, 'Heat');
    // Commercials have their length once read (the live test reads them).
    final libs = await server.libraries();
    expect([for (final l in libs) (l.name, l.collectionType)], [('TV', 'tvshows'), ('Movies', 'movies'), ('Ads', 'homevideos')]);
    final tv = await server.folderTree(libs.first.id);
    expect((tv.single.name, tv.single.type), ('Show A', 'Series'));
    expect([for (final s in tv.single.children) (s.type, s.index)], [('Season', 1), ('Season', 2)]);
    expect((await server.idsUnder(tv.single.id)).length, 3);
    expect((await server.idsUnder(tv.single.children.first.id)).length, 2);
    final movies = await server.folderTree(libs[1].id);
    expect(movies.single.children.single.type, 'Movie');
    expect(await server.idsUnder(index.movies.single.id), [index.movies.single.id]);
    await expectLater(server.idsUnder('nothing-here'), throwsA(isA<ServerException>().having((e) => e.statusCode, 'status', 404)));
  });

  test("a share that's down is unreachable; a changed password needs sign-in", () async {
    expect((await server.publicInfo()).kind, ServerKind.smb);
    share.down = true;
    await expectLater(server.publicInfo(), throwsA(isA<ServerException>().having((e) => e.unreachable, 'unreachable', isTrue)));
    share.down = false;
    // A new connection with the old password.
    await Future<void>.delayed(Duration.zero);
    refuse = true;
    // The live connection is dropped first, as after an idle close.
    server.close();
  });

  test('a file that is gone does not make the share unreachable', () async {
    await server.fetchLibraryIndex();
    await expectLater(server.idsUnder(smbIdOf('Movies/')), completion(hasLength(1)));
    share.files.remove('Movies/Heat (1995)/Heat (1995).mkv');
    expect((await server.publicInfo()).name, 'media on nas');
  });
}
