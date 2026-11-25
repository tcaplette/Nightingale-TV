import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

import 'smb_fakes.dart';

void main() {
  late Directory dir;
  late AppState app;
  late List<ServerSession> signedIn;
  late FakeShare media;
  late List<String> opened;

  setUpAll(() => SmbGateway.inIsolate = false);
  tearDownAll(SmbGateway.stop);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('smb_sign_in');
    app = AppState(await AppStorage.at(Directory('${dir.path}/p'), logosDir: Directory('${dir.path}/logos')),
        runAnalysis: false, profileName: () => 'Mom');
    await app.start();
    signedIn = [];
    opened = [];
    media = FakeShare({'TV/Show/S01E01.mkv': 10, 'Movies/Heat (1995).mkv': 10, 'Music/a.mp3': 1, 'Backups/x.zip': 1});
  });
  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });

  SignInFlow flow({bool adding = false, String password = 'pw'}) => SignInFlow(app,
      adding: adding, completeSignIn: (session, _) async => signedIn.add(session))
    ..openShare = (address, who) async {
      opened.add('${address.url} ${who.isGuest ? 'guest' : who.user}');
      if (address.share != 'media') throw const SmbException(SmbErrorKind.gone, 'no share');
      if (who.isGuest) throw const SmbException(SmbErrorKind.guestsRefused, 'no guests');
      if (who.password != password) throw const SmbException(SmbErrorKind.wrongSignIn, 'wrong');
      return media;
    }
    ..listShares = (address, who) async {
      if (who.isGuest) throw const SmbException(SmbErrorKind.guestsRefused, 'no guests');
      return (shares: const [SmbShareInfo('media'), SmbShareInfo('music')], smb1: false);
    };

  test('an SMB address goes to the share, a sign-in, and its folders', () async {
    final f = flow();
    addTearDown(f.dispose);
    await f.connect(r'\\nas\media');
    // A guest first; the share wants a sign-in.
    expect(f.step.stage, SignInStage.smbSignIn);
    expect(opened, ['smb://nas/media guest']);
    await f.smbSignIn('alice', 'nope');
    expect(f.step.error, 'Wrong username or password, or the session expired.');
    expect(f.step.stage, SignInStage.smbSignIn);
    await f.smbSignIn('alice', 'pw');
    expect(f.step.stage, SignInStage.smbFolders);
    // TV, Movies and Music are suggested; Backups isn't.
    expect(f.step.smb.mappings, {'TV': SmbFolderType.tvShows, 'Movies': SmbFolderType.movies, 'Music': SmbFolderType.music});
    expect(f.step.smb.historyName, 'Mom');
    // A folder inside a mapped one takes its own type.
    await f.openSmbFolder('TV');
    expect(f.step.smb.folders, ['Show']);
    f.mapSmbFolder('TV/Show', SmbFolderType.homeVideos);
    f.back();
    await Future<void>.delayed(Duration.zero);
    expect(f.step.smb.folder, '');
    await f.finishSmb(historyName: 'Mom');
    expect(f.finished, isTrue);
    final s = signedIn.single;
    expect((s.kind, s.serverUrl, s.serverName, s.userName), (ServerKind.smb, 'smb://nas/media', 'media on nas', 'alice'));
    expect(s.accessToken, isNot(contains('pw')));
    expect(await app.smb.credentials(s.accessToken), isA<SmbCredentials>().having((c) => c.password, 'password', 'pw'));
    final config = app.smb.configOf(s.serverId!);
    expect({for (final m in config.mappings) m.path: m.type},
        {'TV': SmbFolderType.tvShows, 'Movies': SmbFolderType.movies, 'Music': SmbFolderType.music, 'TV/Show': SmbFolderType.homeVideos});
    // The share's own id, kept on it.
    expect(media.files.keys, contains('.nightingale/share.json'));
    expect(config.historyName, isNull, reason: "the profile's name is the default");
    // Nothing saved holds the password.
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      expect(String.fromCharCodes(file.readAsBytesSync()), isNot(contains('"pw"')), reason: file.path);
    }
  });

  test('a host: its shares, after a sign-in', () async {
    final f = flow();
    addTearDown(f.dispose);
    await f.connect('smb://nas');
    expect(f.step.stage, SignInStage.smbSignIn);
    await f.smbSignIn('alice', 'pw');
    expect(f.step.stage, SignInStage.smbShares);
    expect([for (final s in f.step.smb.shares) s.name], ['media', 'music']);
    await f.pickSmbShare('media');
    expect(f.step.stage, SignInStage.smbFolders);
    await f.finishSmb();
    expect(f.finished, isTrue);
  });

  test('no folder mapped: Done says so', () async {
    final f = flow();
    addTearDown(f.dispose);
    await f.connect('smb://nas/media');
    await f.smbSignIn('alice', 'pw');
    for (final p in [...f.step.smb.mappings.keys]) {
      f.mapSmbFolder(p, null);
    }
    await f.finishSmb();
    expect(f.step.error, 'Choose what at least one folder holds.');
    expect(f.finished, isFalse);
  });

  test("a read-only share gets an id from its root folder, and keeps history on the device", () async {
    media = FakeShare({'Movies/a.mkv': 1}, writable: false);
    final f = flow();
    addTearDown(f.dispose);
    await f.connect('smb://nas/media');
    await f.smbSignIn('alice', 'pw');
    expect(f.step.smb.writable, isFalse);
    await f.finishSmb();
    final id = signedIn.single.serverId!;
    expect(id, startsWith('smb-'));
    expect(app.smb.configOf(id).keepLocal, isTrue);
    // The same share at another address is the same share.
    final again = FakeShare({'Movies/a.mkv': 1}, writable: false);
    media = again;
    final f2 = flow();
    addTearDown(f2.dispose);
    await f2.connect('smb://192.168.1.5/media');
    await f2.smbSignIn('alice', 'pw');
    await f2.finishSmb();
    expect(signedIn.last.serverId, id);
  });

  test('a read-only share whose folder another share wrote its id in keeps that id, and history on the device', () async {
    media = FakeShare({'Movies/a.mkv': 1}, writable: false)
      ..files['.nightingale/share.json'] = Uint8List.fromList(utf8.encode('{"id":"smb-written-elsewhere"}'));
    final f = flow();
    addTearDown(f.dispose);
    await f.connect('smb://nas/media');
    await f.smbSignIn('alice', 'pw');
    expect(f.step.smb.writable, isFalse);
    await f.finishSmb();
    expect(signedIn.single.serverId, 'smb-written-elsewhere');
    expect(app.smb.configOf('smb-written-elsewhere').keepLocal, isTrue);
    expect(media.files.keys.where((k) => k.endsWith('.tmp')), isEmpty);
  });

  test('an address that is no address', () async {
    final f = flow();
    addTearDown(f.dispose);
    await f.connect('smb://');
    expect(f.step.error, contains("isn't a share's address"));
  });
}
