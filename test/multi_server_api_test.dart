import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_log.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/setup/accounts.dart';
import 'package:nightingale_tv/setup/setup_server.dart';
import 'package:nightingale_tv/setup/web_files.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';
import 'multi_server_fakes.dart';
import 'setup_client.dart';

/// The profile's servers through the admin API (multi-server 9.1).
void main() {
  late Directory dir;
  late Household household;
  late Accounts accounts;
  late SetupServer setup;
  late Client admin;
  late FakeServer plex;
  final iterations = Accounts.iterations;

  setUpAll(() => Accounts.iterations = 1000);
  tearDownAll(() => Accounts.iterations = iterations);

  setUp(() async {
    BackupArchive.useIsolate = false;
    ServerLog.output = (_) {};
    dir = await Directory.systemTemp.createTemp('multi_api');
    final mom = momAndKids().first;
    await writeHousehold(dir, [mom], fakeLibrary());
    household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
    accounts = await Accounts.load(dir);
    plex = FakeServer('Basement', items: renamed(fakeItems(shows: const {'Zed': 6}), 'p'), url: 'http://plex.example', serverId: 'p2');
    setup = SetupServer(household, accounts,
        port: 0,
        web: WebFiles(Directory('${dir.path}/no_web')),
        serverSignInFlow: (app, again) => SignInFlow(app,
            adding: again == null,
            againKey: again,
            identify: (address) async => (
                  client: address.contains('plex') ? plex.client : FakeServer('Home', items: fakeItems(), serverId: 's1').client,
                  info: ServerInfo(
                      url: address,
                      name: address.contains('plex') ? 'Basement' : 'Home',
                      version: '10.11',
                      id: address.contains('plex') ? 'p2' : 's1'),
                )));
    await setup.start();
    await household.start();
    admin = Client(setup.boundPort!);
    final r = await admin.post('/api/v1/password', {'token': accounts.setupToken, 'name': 'sam', 'password': 'correct horse'});
    expect(r.status, 200, reason: '${r.json}');
  });

  tearDown(() async {
    admin.close();
    await setup.stop();
    await household.closeAll();
    accounts.close();
    await dir.delete(recursive: true);
    BackupArchive.useIsolate = true;
    ServerLog.reset();
  });

  String id() => household.profiles.single.id;

  Future<AppState> app() async => (await household.appForSetup(id()))!;

  Future<void> waitForRefresh(AppState app) async {
    for (var i = 0; i < 200 && (app.isRefreshingLibrary || app.library['s2~pZed-e1'] == null); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('adding a server with its sign-in steps, then order, quality limit and remove; no token is ever sent', () async {
    final bodies = <String>[];
    Future<Answer> keep(Future<Answer> a) async {
      final r = await a;
      bodies.add(utf8.decode(r.bytes));
      return r;
    }

    final base = '/api/v1/profiles/${id()}/servers';
    var list = (await keep(admin.get(base))).json! as Map;
    expect((list['servers'] as List).single, containsPair('main', true));

    var step = (await keep(admin.post(base, {'action': 'start'}))).json! as Map;
    expect(step['stage'], 'server');
    // The profile's own server is refused.
    step = (await keep(admin.post(base, {'action': 'connect', 'address': 'home.example'}))).json! as Map;
    expect(step['error'], 'Home is already in this profile');
    step = (await keep(admin.post(base, {'action': 'connect', 'address': 'plex.example'}))).json! as Map;
    expect(step['stage'], 'method');
    await keep(admin.post(base, {'action': 'choosePassword'}));
    step = (await keep(admin.post(base, {'action': 'password', 'user': 'dad', 'password': 'pw'}))).json! as Map;
    expect(step['finished'], isTrue);
    await waitForRefresh(await app());

    list = (await keep(admin.get(base))).json! as Map;
    final servers = (list['servers'] as List).cast<Map>();
    expect([for (final s in servers) s['key']], ['main', 's2']);
    expect(servers.last, containsPair('state', 'ok'));
    expect(servers.last, containsPair('episodes', 6));
    final summary = (await keep(admin.get('/api/v1/profiles/${id()}/library'))).json! as Map;
    expect((summary['servers'] as List), hasLength(2));

    var r = await keep(admin.edit('PUT', '$base/order', body: {'order': ['s2', 'main']}, revisionOf: '/api/v1/profiles/${id()}/library'));
    expect(r.status, 200, reason: '${r.json}');
    expect((r.json! as Map)['order'], ['s2', 'main']);
    r = await keep(admin.edit('PATCH', '$base/s2', body: {'qualityLimitKbps': 2000}, revisionOf: '/api/v1/profiles/${id()}/library'));
    expect(((r.json! as Map)['servers'] as List).first, containsPair('qualityLimitKbps', 2000));
    r = await keep(admin.edit('DELETE', '$base/main', revisionOf: '/api/v1/profiles/${id()}/library'));
    expect(r.status, 409);
    r = await keep(admin.edit('DELETE', '$base/s2', revisionOf: '/api/v1/profiles/${id()}/library'));
    expect(r.status, 200, reason: '${r.json}');
    expect(((r.json! as Map)['servers'] as List), hasLength(1));
    expect(plex.requests.where((q) => q.startsWith('/Sessions/Logout')), isNotEmpty);

    for (final b in bodies) {
      expect(b, isNot(contains('t-Basement')));
      expect(b, isNot(contains(tokenFor(id()))));
    }
  });
}
