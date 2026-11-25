import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/convert/ffmpeg_programs.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/server_log.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_profile.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';
import 'package:nightingale_tv/setup/accounts.dart';
import 'package:nightingale_tv/setup/setup_server.dart';
import 'package:nightingale_tv/setup/web_files.dart';

import '../backup_fixtures.dart';
import '../fixtures.dart';
import '../setup_client.dart';
import 'smb_fakes.dart';

/// A share added, mapped and coloured through the admin API alone.
void main() {
  late Directory dir;
  late Household household;
  late Accounts accounts;
  late SetupServer setup;
  late Client admin;
  final iterations = Accounts.iterations;
  final share = FakeShare({'TV/Show/Show S01E01.mkv': 1, 'Movies/Heat (1995).mkv': 1, 'Backups/x.zip': 1});

  setUpAll(() {
    Accounts.iterations = 1000;
    SmbGateway.inIsolate = false;
    IndexBuilder.useIsolate = false;
    FfmpegPrograms.reset(const FfmpegPrograms(ffmpeg: '/nonexistent/ffmpeg', ffprobe: '/nonexistent/ffprobe'));
    SmbProfile.openOverride = (address, who, {knownSmb1 = false, workers = 2}) async => share;
  });
  tearDownAll(() async {
    Accounts.iterations = iterations;
    FfmpegPrograms.reset();
    SmbProfile.openOverride = null;
    await SmbGateway.stop();
  });

  setUp(() async {
    BackupArchive.useIsolate = false;
    ServerLog.output = (_) {};
    dir = await Directory.systemTemp.createTemp('smb_api');
    await writeHousehold(dir, [momAndKids().first], fakeLibrary());
    household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
    accounts = await Accounts.load(dir);
    setup = SetupServer(household, accounts,
        port: 0,
        web: WebFiles(Directory('${dir.path}/no_web')),
        serverSignInFlow: (app, again) => SignInFlow(app, adding: again == null, againKey: again)
          ..openShare = (address, who) async {
            if (who.isGuest) throw const SmbException(SmbErrorKind.guestsRefused, 'no');
            if (who.password != 'share-password-123') throw const SmbException(SmbErrorKind.wrongSignIn, 'no');
            return share;
          });
    await setup.start();
    await household.start();
    admin = Client(setup.boundPort!);
    final r = await admin.post('/api/v1/password', {'token': accounts.setupToken, 'name': 'sam', 'password': 'correct horse'});
    expect(r.status, 200);
  });

  tearDown(() async {
    admin.close();
    await setup.stop();
    await household.closeAll();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await household.flushAll();
    await AppStorage.flushAll();
    accounts.close();
    await dir.delete(recursive: true);
    BackupArchive.useIsolate = true;
    ServerLog.reset();
  });

  test('add, map, rename, colours and the guide; nothing secret comes back', () async {
    final id = household.profiles.single.id;
    final bodies = <String>[];
    Future<Map> call(Future<Answer> a) async {
      final r = await a;
      bodies.add(utf8.decode(r.bytes));
      expect(r.status, 200, reason: utf8.decode(r.bytes));
      return r.json! as Map;
    }

    final base = '/api/v1/profiles/$id/servers';
    await call(admin.post(base, {'action': 'start'}));
    var step = await call(admin.post(base, {'action': 'smb'}));
    expect(step['stage'], 'smbFind');
    // The step again, unchanged, as the dialog asks for it while searching.
    expect((await call(admin.post(base, {'action': 'step'})))['stage'], 'smbFind');
    step = await call(admin.post(base, {'action': 'smbAddress', 'address': 'smb://nas/media'}));
    expect(step['stage'], 'smbSignIn');
    step = await call(admin.post(base, {'action': 'smbSignIn', 'user': 'alice', 'password': 'share-password-123'}));
    expect(step['stage'], 'smbFolders');
    expect((step['smb'] as Map)['mappings'], {'TV': 'tvShows', 'Movies': 'movies'});
    step = await call(admin.post(base, {'action': 'smbMap', 'path': 'Movies', 'type': null}));
    step = await call(admin.post(base, {'action': 'smbDone'}));
    // The share's guide colour last (server-color-on-add): teal, SMB's own.
    expect(step['stage'], 'color');
    expect((step['color'] as Map)['selected'], 'teal');
    step = await call(admin.post(base, {'action': 'color', 'name': 'teal'}));
    expect(step['finished'], isTrue);

    final list = await call(admin.get(base));
    final added = (list['servers'] as List).cast<Map>().last;
    expect((added['kind'], added['name']), ('smb', 'media on nas'));
    final shareUrl = '$base/${added['key']}/share';
    var s = await call(admin.get(shareUrl));
    expect(s['folders'], [
      {'path': 'TV', 'type': 'tvShows'}
    ]);
    final folders = await call(admin.get('$shareUrl/folders'));
    expect({for (final f in folders['folders'] as List) (f as Map)['name']: f['suggested']},
        {'Backups': null, 'Movies': 'movies', 'TV': 'tvShows'});
    final r = await admin.edit('PUT', shareUrl,
        body: {
          'name': 'Basement NAS',
          'folders': [
            {'path': 'TV', 'type': 'tvShows'},
            {'path': 'Movies', 'type': 'movies'}
          ],
          'historyName': 'Family',
        },
        revisionOf: '/api/v1/profiles/$id/library');
    expect(r.status, 200, reason: utf8.decode(r.bytes));
    bodies.add(utf8.decode(r.bytes));
    s = r.json! as Map;
    expect((s['name'], s['historyName'], (s['folders'] as List).length), ('Basement NAS', 'Family', 2));

    final colors = await call(admin.get('/api/v1/profiles/$id/colors'));
    expect(colors['shown'], isTrue);
    expect([for (final c in colors['sources'] as List) (c as Map)['color']], ['purple', 'teal']);
    final c2 = await admin.edit('PUT', '/api/v1/profiles/$id/colors',
        body: {
          'colors': {added['key']: 'wine'}
        },
        revisionOf: '/api/v1/profiles/$id/library');
    expect(c2.status, 200, reason: utf8.decode(c2.bytes));
    final guide = await call(admin.get('/api/v1/profiles/$id/guide'));
    expect(guide['colors'], isNotNull);
    final airings = [for (final ch in guide['channels'] as List) ...((ch as Map)['airings'] as List).cast<Map>()];
    expect(airings.where((a) => a['color'] == '#4a2a80'), isNotEmpty, reason: "the main server's programs are purple");
    final helper = await call(admin.get('/api/v1/convert-helper'));
    expect(helper['available'], isFalse);

    for (final b in bodies) {
      expect(b, isNot(contains('share-password-123')));
      expect(b, isNot(contains('smb-')), reason: 'no secret reference either');
    }
  });
}
