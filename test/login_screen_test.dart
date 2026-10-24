import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/emby_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/plex/plex_account.dart';
import 'package:nightingale_tv/server/plex/plex_connections.dart';
import 'package:nightingale_tv/ui/login_screen.dart';

import 'portrait_harness.dart';

/// plex.tv, scripted: a code that links after [linkAfter] checks, a Home
/// and servers.
class FakePlexAccount extends PlexAccount {
  FakePlexAccount({this.users = const [], this.serverList = const [], this.linkAfter = 1, this.pinOf = const {}})
      : super(clientId: 'test-device', deviceName: 'test');

  final List<PlexHomeUser> users;
  final List<PlexResource> serverList;
  final Map<String, String> pinOf;
  int linkAfter;

  int created = 0;
  int checks = 0;
  bool expireNext = false;
  final switched = <String>[];

  @override
  Future<PlexPin> createPin() async => PlexPin(id: ++created, code: 'K7Q$created');

  @override
  Future<PlexPin?> checkPin(PlexPin pin) async {
    checks++;
    if (expireNext) {
      expireNext = false;
      return null;
    }
    return checks >= linkAfter ? PlexPin(id: pin.id, code: pin.code, authToken: 'account-token') : pin;
  }

  @override
  Future<List<PlexHomeUser>> homeUsers(String token) async => users;

  @override
  Future<String> switchUser(String token, PlexHomeUser user, {String? pin}) async {
    if (pinOf[user.uuid] case final want? when want != pin) throw PlexWrongPin();
    switched.add(user.uuid);
    return 'token-${user.uuid}';
  }

  @override
  Future<List<PlexResource>> servers(String token) async => serverList;

  @override
  Future<PlexUser> user(String token) async => PlexUser(id: 'id-$token', uuid: token, title: 'Linked user');
}

PlexResource server(String name, String id, {String? owner}) => PlexResource(
      name: name,
      clientIdentifier: id,
      accessToken: 'server-token-$id',
      owned: owner == null,
      ownerName: owner,
      online: true,
      connections: [PlexConnection(uri: 'http://$id.local:32400', local: true)],
    );

/// A Jellyfin or Emby server at jf.example, from canned answers.
JellyfinClient fakeServer(ServerKind kind, {bool quickConnect = false}) {
  final http = MockClient((r) async {
    if (r.url.path == '/QuickConnect/Enabled') return Response(jsonEncode(quickConnect), 200);
    if (r.url.path == '/Users/AuthenticateByName') {
      return Response(jsonEncode({'AccessToken': 'tok', 'User': {'Id': 'u1', 'Name': 'howard'}}), 200);
    }
    return Response('', 404);
  });
  return kind == ServerKind.emby
      ? EmbyClient(serverUrl: 'http://jf.example', deviceId: 'd', deviceName: 't', httpClient: http)
      : JellyfinClient(serverUrl: 'http://jf.example', deviceId: 'd', deviceName: 't', httpClient: http);
}

typedef Response = http.Response;

void main() {
  late PortraitHarness h;
  late List<ServerSession> signedIn;

  Future<void> open(WidgetTester tester,
      {Future<IdentifiedServer> Function(String)? identify,
      PlexAccount? account,
      Future<PlexConnection?> Function(PlexResource)? pick,
      Map<String, Object?>? hint}) async {
    setWindow(tester, const Size(1920, 1080));
    h = await PortraitHarness.start(tester);
    h.app.signInHint = hint;
    signedIn = [];
    await h.show(
        tester,
        LoginScreen(
          identify: identify,
          plexAccount: account,
          pickPlexConnection: pick ?? (s) async => s.connections.first,
          completeSignIn: (session, client) async => signedIn.add(session),
        ));
    await tester.pump();
  }

  Future<void> connect(WidgetTester tester, String address) async {
    await tester.enterText(find.byType(TextField), address);
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> tick(WidgetTester tester) async {
    await tester.pump(LoginScreen.plexPoll);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('a Jellyfin address keeps its steps: method, then password', (tester) async {
    await open(tester,
        identify: (_) async => (
              client: fakeServer(ServerKind.jellyfin, quickConnect: true),
              info: const ServerInfo(url: 'http://jf.example', name: 'Den', version: '10.11.0', id: 'jf1'),
            ));
    await connect(tester, 'jf.example');
    expect(find.text('Quick Connect (use your phone)'), findsOneWidget);
    expect(find.text('Jellyfin 10.11.0 · http://jf.example'), findsOneWidget);
    await tester.tap(find.text('Sign in with password'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'howard');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();
    expect(signedIn.single.kind, ServerKind.jellyfin);
  });

  testWidgets('an Emby address asks for the password, with no Quick Connect', (tester) async {
    await open(tester,
        identify: (_) async => (
              client: fakeServer(ServerKind.emby),
              info: const ServerInfo(
                  url: 'http://jf.example', name: 'Attic', version: '4.10.2.0', id: 'em1', kind: ServerKind.emby),
            ));
    await connect(tester, 'jf.example');
    expect(find.text('Sign in to Attic'), findsOneWidget);
    expect(find.text('Emby 4.10.2.0 · http://jf.example'), findsOneWidget);
    expect(find.textContaining('Quick Connect'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'howard');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();
    expect(signedIn.single.kind, ServerKind.emby);
    expect(signedIn.single.serverName, 'Attic');
  });

  testWidgets('a wrong address says so and stays on the address step', (tester) async {
    await open(tester, identify: (a) async => throw ServerException('No Jellyfin, Emby or Plex server found at $a. Connection refused'));
    await connect(tester, 'nothing.example');
    expect(find.textContaining('No Jellyfin, Emby or Plex server found at nothing.example'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('a Plex address: link code, then that server without the list', (tester) async {
    final account = FakePlexAccount(linkAfter: 2, serverList: [server('Basement', 'm1'), server('Attic', 'm2')]);
    await open(tester,
        account: account,
        identify: (_) async => (
              client: fakeServer(ServerKind.jellyfin),
              info: const ServerInfo(url: 'http://m2.local:32400', name: 'Plex', version: '1.43', id: 'm2', kind: ServerKind.plex),
            ));
    await connect(tester, 'm2.local:32400');
    expect(find.text('K7Q1'), findsOneWidget);
    expect(find.text('Go to plex.tv/link on your phone or computer and enter this code.'), findsOneWidget);
    // Not linked on the first check, linked on the second.
    await tick(tester);
    expect(signedIn, isEmpty);
    await tick(tester);
    expect(find.text('Choose a server'), findsNothing);
    final s = signedIn.single;
    expect((s.kind, s.serverId, s.serverName, s.serverUrl), (ServerKind.plex, 'm2', 'Attic', 'http://m2.local:32400'));
    expect(s.accessToken, 'server-token-m2');
    expect(s.accountToken, 'account-token');
  });

  testWidgets('Sign in with Plex: one server and one user skip both lists', (tester) async {
    final account = FakePlexAccount(serverList: [server('Basement', 'm1')]);
    await open(tester, account: account);
    await tester.tap(find.text('Sign in with Plex'));
    await tester.pump();
    await tick(tester);
    expect(signedIn.single.serverId, 'm1');
    expect(find.text("Who's signing in?"), findsNothing);
  });

  testWidgets('servers, owned and shared, are listed when there are several', (tester) async {
    final account = FakePlexAccount(serverList: [server('Basement', 'm1'), server("Grandpa's Plex", 'm3', owner: 'gramps')]);
    await open(tester, account: account);
    await tester.tap(find.text('Sign in with Plex'));
    await tester.pump();
    await tick(tester);
    expect(find.text('Choose a server'), findsOneWidget);
    expect(find.text('Basement'), findsOneWidget);
    expect(find.text("Grandpa's Plex — Shared by gramps"), findsOneWidget);
    // D-pad: down to the shared one, OK.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(signedIn.single.serverId, 'm3');
  });

  testWidgets('an account with no servers says to ask for a share', (tester) async {
    await open(tester, account: FakePlexAccount());
    await tester.tap(find.text('Sign in with Plex'));
    await tester.pump();
    await tick(tester);
    expect(find.text("This Plex account has no servers. Ask the server's owner to share it with you."), findsOneWidget);
  });

  testWidgets('a Home user with a PIN: a wrong PIN clears the pad, the right one signs in', (tester) async {
    final account = FakePlexAccount(
      users: const [
        PlexHomeUser(id: '1', uuid: 'dad', title: 'Dad', protected: true, admin: true),
        PlexHomeUser(id: '2', uuid: 'kids', title: 'Kids'),
      ],
      pinOf: const {'dad': '1234'},
      serverList: [server('Basement', 'm1')],
    );
    await open(tester, account: account);
    await tester.tap(find.text('Sign in with Plex'));
    await tester.pump();
    await tick(tester);
    expect(find.text("Who's signing in?"), findsOneWidget);
    await tester.tap(find.text('Dad'));
    await tester.pump();
    expect(find.text('PIN for Dad'), findsOneWidget);
    for (final d in '9999'.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$d')));
      await tester.pump();
    }
    await tester.pump();
    expect(find.text('Wrong PIN'), findsOneWidget);
    expect((tester.widget<Text>(find.byKey(const ValueKey('pin-dots')))).data, '○  ○  ○  ○');
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$d')));
      await tester.pump();
    }
    await tester.pump();
    await tester.pump();
    expect(account.switched, ['dad']);
    expect(signedIn.single.accountToken, 'token-dad');
    expect(signedIn.single.userName, 'Dad');
  });

  testWidgets('a Home user without a PIN signs in at once', (tester) async {
    final account = FakePlexAccount(
      users: const [
        PlexHomeUser(id: '1', uuid: 'dad', title: 'Dad', protected: true, admin: true),
        PlexHomeUser(id: '2', uuid: 'kids', title: 'Kids'),
      ],
      serverList: [server('Basement', 'm1')],
    );
    await open(tester, account: account);
    await tester.tap(find.text('Sign in with Plex'));
    await tester.pump();
    await tick(tester);
    await tester.tap(find.text('Kids'));
    await tester.pump();
    await tester.pump();
    expect(signedIn.single.userName, 'Kids');
    expect(signedIn.single.accountToken, 'token-kids');
  });

  testWidgets("a restored Plex profile: a link code, then the backup's server and Home user", (tester) async {
    final account = FakePlexAccount(
      users: const [
        PlexHomeUser(id: '1', uuid: 'dad', title: 'Dad', admin: true),
        PlexHomeUser(id: '2', uuid: 'kids', title: 'Kids'),
      ],
      serverList: [server('Basement', 'm1'), server('Attic', 'm2')],
    );
    await open(tester, account: account, hint: {
      'kind': 'plex',
      'serverUrl': 'http://m2.local:32400',
      'serverName': 'Attic',
      'serverId': 'm2',
      'userId': '2',
      'userName': 'Kids',
    });
    await tester.pump();
    expect(find.text('K7Q1'), findsOneWidget);
    await tick(tester);
    expect(find.text("Who's signing in?"), findsNothing);
    expect(find.text('Choose a server'), findsNothing);
    expect(account.switched, ['kids']);
    expect((signedIn.single.serverId, signedIn.single.userName), ('m2', 'Kids'));
  });

  testWidgets('a server that answers at no address can be tried again from the list', (tester) async {
    final account = FakePlexAccount(serverList: [server('Basement', 'm1')]);
    var answering = false;
    await open(tester, account: account, pick: (s) async => answering ? s.connections.first : null);
    await tester.tap(find.text('Sign in with Plex'));
    await tester.pump();
    await tick(tester);
    expect(find.text('Basement is not answering at any of its addresses. Is it on?'), findsOneWidget);
    expect(find.text('Waiting for the code to be linked…'), findsNothing);
    answering = true;
    await tester.tap(find.text('Basement'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(signedIn.single.serverId, 'm1');
  });

  testWidgets('Back during the link code stops checking it', (tester) async {
    final account = FakePlexAccount(linkAfter: 1000);
    await open(tester, account: account);
    await tester.tap(find.text('Sign in with Plex'));
    await tester.pump();
    await tick(tester);
    expect(account.checks, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Connect'), findsOneWidget);
    await tick(tester);
    await tick(tester);
    expect(account.checks, 1, reason: 'no checks after leaving the step');
  });

  testWidgets('an expired code is replaced by a new one', (tester) async {
    final account = FakePlexAccount(linkAfter: 1000);
    await open(tester, account: account);
    await tester.tap(find.text('Sign in with Plex'));
    await tester.pump();
    expect(find.text('K7Q1'), findsOneWidget);
    account.expireNext = true;
    await tick(tester);
    expect(find.text('K7Q2'), findsOneWidget);
    expect(find.text('K7Q1'), findsNothing);
  });

  test('connection choice: local first, then remote, then the relay; HTTPS first within each', () async {
    const local = PlexConnection(uri: 'http://192.168.1.5:32400', local: true);
    const localTls = PlexConnection(uri: 'https://192-168-1-5.abc.plex.direct:32400', local: true);
    const remote = PlexConnection(uri: 'https://8-8-8-8.abc.plex.direct:32400');
    const relay = PlexConnection(uri: 'https://relay.abc.plex.direct:8443', relay: true);
    const r = PlexResource(name: 'B', clientIdentifier: 'm', accessToken: 't', connections: [relay, remote, local, localTls]);
    expect(rankConnections(r), [localTls, local, remote, relay]);
    Future<PlexConnection?> pickWith(Set<PlexConnection> answering) =>
        pickConnection(r, probe: (c) async => answering.contains(c));
    expect(await pickWith({local, remote, relay}), local);
    expect(await pickWith({remote, relay}), remote);
    expect(await pickWith({relay}), relay);
    expect(await pickWith({}), isNull);
  });
}
