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
                      name: address.contains('plex') ? plex.name : 'Home',
                      version: '10.11',
                      id: address.contains('plex') ? plex.serverId : 's1'),
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

  test("adding a server ends with its guide colour: the suggestion selected, colours in use named, a choice kept; closing keeps the suggestion", () async {
    final base = '/api/v1/profiles/${id()}/servers';
    await admin.post(base, {'action': 'start'});
    await admin.post(base, {'action': 'connect', 'address': 'plex.example'});
    await admin.post(base, {'action': 'choosePassword'});
    var step = (await admin.post(base, {'action': 'password', 'user': 'dad', 'password': 'pw'})).json! as Map;
    expect(step['stage'], 'color');
    expect(step['finished'], isFalse);
    final color = step['color'] as Map;
    expect(color['key'], 's2');
    expect(color['name'], 'Basement');
    // A Jellyfin server's colour is purple: the main server has it, so the
    // next unused one is suggested.
    final palette = (color['palette'] as List).cast<Map>();
    expect([for (final c in palette) c['name']], [for (final c in ServerColor.palette) c.name]);
    expect(palette.firstWhere((c) => c['name'] == 'purple'), containsPair('usedBy', 'Home'));
    expect(color['selected'], isNot('purple'));
    expect(palette.firstWhere((c) => c['name'] == color['selected']).containsKey('usedBy'), isFalse);
    expect(palette.first['hex'], matches(RegExp(r'^#[0-9a-f]{6}$')));
    // An unknown colour is refused, and the step stays.
    var r = await admin.post(base, {'action': 'color', 'name': 'yellow'});
    expect(r.status, 400);
    step = (await admin.post(base, {'action': 'step'})).json! as Map;
    expect(step['stage'], 'color');
    step = (await admin.post(base, {'action': 'color', 'name': 'wine'})).json! as Map;
    expect(step['finished'], isTrue);
    final a = await app();
    expect(a.serverColors['s2']!.name, 'wine');
    expect(a.settings.serverColors['s2'], 'wine');
    expect(((await admin.get('/api/v1/profiles/${id()}/colors')).json! as Map)['sources'], contains(containsPair('color', 'wine')));

    // A second add, closed on the colour step: added, with its suggestion.
    plex = FakeServer('Attic', items: renamed(fakeItems(shows: const {'Yak': 2}), 'q'), url: 'http://attic.plex.example', serverId: 'p3');
    await admin.post(base, {'action': 'start'});
    await admin.post(base, {'action': 'connect', 'address': 'attic.plex.example'});
    await admin.post(base, {'action': 'choosePassword'});
    step = (await admin.post(base, {'action': 'password', 'user': 'dad', 'password': 'pw'})).json! as Map;
    expect(step['stage'], 'color');
    final suggested = (step['color'] as Map)['selected'];
    expect(suggested, isNot(anyOf('purple', 'wine')));
    r = await admin.post(base, {'action': 'cancel'});
    expect(r.status, 200, reason: '${r.json}');
    expect(a.servers.all, hasLength(3));
    expect(a.settings.serverColors['s3'], suggested);
    // The added servers' libraries are read in the background.
    for (var i = 0; i < 500 && a.isRefreshingLibrary; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });

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
    // Its guide colour last (server-color-on-add).
    expect(step['stage'], 'color');
    expect(step['finished'], isFalse);
    step = (await keep(admin.post(base, {'action': 'color', 'name': 'green'}))).json! as Map;
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
