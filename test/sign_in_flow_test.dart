import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/plex/plex_account.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';

import 'login_screen_test.dart' show FakePlexAccount, fakeServer, server;

ServerInfo _info(ServerKind kind) =>
    ServerInfo(kind: kind, id: 'srv', name: 'Home Server', version: '10.11', url: 'http://jf.example');

void main() {
  late Directory dir;
  late AppState app;
  late List<ServerSession> signedIn;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_sign_in_flow');
    app = AppState(await AppStorage.at(dir), runAnalysis: false);
    await app.start();
    expect(app.phase, AppPhase.signedOut);
    signedIn = [];
  });
  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });

  SignInFlow flowFor(MediaServer? client, {ServerKind kind = ServerKind.jellyfin, PlexAccount? plex}) => SignInFlow(
        app,
        identify: (_) async => (client: client ?? fakeServer(kind), info: _info(kind)),
        plexAccount: plex,
        pickPlexConnection: (s) async => s.connections.first,
        completeSignIn: (session, _) async => signedIn.add(session),
      );

  test('Jellyfin: address, method, password', () async {
    final flow = flowFor(fakeServer(ServerKind.jellyfin, quickConnect: true));
    addTearDown(flow.dispose);
    await flow.connect('jf.example');
    expect(flow.step.stage, SignInStage.method);
    expect(flow.step.quickConnectAvailable, isTrue);
    flow.choosePassword();
    expect(flow.step.stage, SignInStage.password);
    await flow.signInWithPassword('howard', 'pw');
    expect(flow.finished, isTrue);
    expect(signedIn.single.userName, 'howard');
  });

  test('Emby without Quick Connect goes straight to the password', () async {
    final flow = flowFor(null, kind: ServerKind.emby);
    addTearDown(flow.dispose);
    await flow.connect('emby.example');
    expect(flow.step.stage, SignInStage.password);
    expect(flow.step.kind, ServerKind.emby);
  });

  test("a wrong password gives the TV's message and stays signed out", () async {
    final client = JellyfinClient(
        serverUrl: 'http://jf.example',
        deviceId: 'd',
        deviceName: 't',
        httpClient: MockClient((r) async => r.url.path == '/QuickConnect/Enabled'
            ? http.Response('false', 200)
            : http.Response('', 401)));
    final flow = flowFor(client);
    addTearDown(flow.dispose);
    await flow.connect('jf.example', then: SignInStage.password);
    await flow.signInWithPassword('howard', 'nope');
    expect(flow.step.error, 'Wrong username or password, or the session expired.');
    expect(flow.step.stage, SignInStage.password);
    expect(flow.finished, isFalse);
    expect(signedIn, isEmpty);
  });

  test('an empty address is refused', () async {
    final flow = flowFor(null);
    addTearDown(flow.dispose);
    await flow.connect('  ');
    expect(flow.step.error, 'Enter your server address.');
  });

  test("Plex from a restored profile's hint: its server and Home user without asking", () {
    fakeAsync((async) {
      app.signInHint = {'kind': 'plex', 'serverUrl': 'http://m2.local:32400', 'serverId': 'm2', 'userId': '2', 'userName': 'Kids'};
      final account = FakePlexAccount(
        users: const [
          PlexHomeUser(id: '1', uuid: 'dad', title: 'Dad', admin: true),
          PlexHomeUser(id: '2', uuid: 'kids', title: 'Kids'),
        ],
        serverList: [server('Basement', 'm1'), server('Attic', 'm2')],
      );
      final flow = flowFor(null, plex: account);
      expect(flow.hint?.plex, isTrue);
      flow.startFromHint();
      async.flushMicrotasks();
      expect(flow.step.stage, SignInStage.plexCode);
      expect(flow.step.plexCode, 'K7Q1');
      async.elapse(SignInFlow.plexPoll);
      expect(flow.finished, isTrue);
      expect((signedIn.single.serverId, signedIn.single.userName), ('m2', 'Kids'));
      flow.dispose();
    });
  });

  test("Plex: Home user with a PIN; a wrong PIN says so, the right one signs in", () {
    fakeAsync((async) {
      final account = FakePlexAccount(
        users: const [
          PlexHomeUser(id: '1', uuid: 'dad', title: 'Dad', admin: true, protected: true),
          PlexHomeUser(id: '2', uuid: 'kids', title: 'Kids'),
        ],
        serverList: [server('Basement', 'm1')],
        pinOf: {'dad': '1234'},
      );
      final flow = flowFor(null, plex: account);
      flow.startPlex();
      async.elapse(SignInFlow.plexPoll);
      expect(flow.step.stage, SignInStage.plexUsers);
      flow.pickUser(flow.step.homeUsers.first);
      async.flushMicrotasks();
      expect(flow.step.stage, SignInStage.plexPin);
      bool? right;
      flow.enterHomePin('9999').then((r) => right = r);
      async.flushMicrotasks();
      expect(right, isFalse);
      expect(flow.step.error, 'Wrong PIN');
      flow.enterHomePin('1234').then((r) => right = r);
      async.flushMicrotasks();
      expect(right, isTrue);
      expect(signedIn.single.userName, 'Dad');
      flow.dispose();
    });
  });

  test('Plex with several servers lists them; Back from the list goes to the start', () {
    fakeAsync((async) {
      final flow = flowFor(null, plex: FakePlexAccount(serverList: [server('Basement', 'm1'), server('Attic', 'm2')]));
      flow.startPlex();
      async.elapse(SignInFlow.plexPoll);
      expect(flow.step.stage, SignInStage.plexServers);
      expect(flow.step.servers!.map((s) => s.name), ['Basement', 'Attic']);
      flow.pickServer(flow.step.servers!.last);
      async.flushMicrotasks();
      expect(signedIn.single.serverId, 'm2');
      flow.dispose();
    });
  });

  test('plex.tv saying "too many requests" makes the code checks wait', () {
    fakeAsync((async) {
      final account = _ThrottledAccount();
      final flow = flowFor(null, plex: account);
      flow.startPlex();
      async.elapse(SignInFlow.plexPoll);
      expect(account.checks, 1, reason: 'refused with 429');
      async.elapse(SignInFlow.plexPoll * 7);
      expect(account.checks, 1, reason: 'about 15 s without asking');
      account.throttled = false;
      async.elapse(SignInFlow.plexPoll);
      expect(account.checks, 2);
      expect(flow.finished, isTrue);
      flow.dispose();
    });
  });
}

/// plex.tv refusing checks with 429 until [throttled] is cleared, then
/// linked.
class _ThrottledAccount extends FakePlexAccount {
  _ThrottledAccount() : super(serverList: [server('Basement', 'm1')]);
  bool throttled = true;

  @override
  Future<PlexPin?> checkPin(PlexPin pin) async {
    checks++;
    if (throttled) throw ServerException('plex.tv error 429.', statusCode: 429);
    return PlexPin(id: pin.id, code: pin.code, authToken: 'account-token');
  }
}
