import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';

/// Folder listings captured from the test server (names, ids and parents
/// only).
final _captured = jsonDecode(File('test/fixtures/folder_tree.json').readAsStringSync()) as Map<String, Object?>;

JellyfinClient _client(Future<http.Response> Function(http.Request r) handler) => JellyfinClient(
      serverUrl: 'https://jf.example',
      deviceId: 'd',
      deviceName: 'pc',
      accessToken: 'secret-token',
      userId: 'u1',
      httpClient: MockClient(handler),
    );

http.Response _json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  group('folderTree', () {
    test('rebuilds the tree from ParentId; parents missing from the listing mean top level', () async {
      late Uri asked;
      final client = _client((r) async {
        asked = r.url;
        return _json(_captured['tvshows']);
      });
      final tree = await client.folderTree('767bffe4f11c93ef34b805451a696a4e');
      expect(asked.path, '/Items');
      expect(asked.queryParameters['ParentId'], '767bffe4f11c93ef34b805451a696a4e');
      expect(asked.queryParameters['Recursive'], 'true');
      expect(asked.queryParameters['IncludeItemTypes'], 'Folder,Series,Season,BoxSet');
      expect(asked.queryParameters['Fields'], 'ParentId', reason: 'never asks for file-system paths');

      // The library's storage folder ("tv") is the top; the shows are in it.
      // Seasons of missing episodes point at series that aren't listed; as
      // placeholders (Virtual) they are left out instead of showing up on
      // top.
      expect([for (final n in tree) n.name], ['tv']);
      final shows = tree.single.children;
      expect(shows, hasLength(11));
      expect(shows.every((n) => n.type == 'Series'), isTrue);
      expect(shows.first.name, startsWith('Archer Season 1'));
      final lotus = shows.firstWhere((n) => n.name == 'The White Lotus');
      expect(lotus.children.every((s) => s.type == 'Season'), isTrue);
      final names = [for (final n in shows) n.name];
      expect(names, [...names]..sort(FolderNode.naturalCompare));
    });

    test('a folder in the commercials library is a top-level choice', () async {
      final client = _client((r) async => _json(_captured['commercials']));
      final tree = await client.folderTree('f14aaf95b6735f2cdb8fe1d13938fd5c');
      expect([for (final n in tree) n.name], ['80s-2000s-commercial-compilation']);
      expect(tree.single.id, 'fb31127d8f4683aed627f3b1bae7bc7b');
    });

    test('several storage roots stay as separate top folders', () {
      final tree = FolderNode.buildTree([
        {'Id': 'a', 'Name': 'Disk 2', 'Type': 'Folder', 'ParentId': 'root'},
        {'Id': 'b', 'Name': 'Disk 10', 'Type': 'Folder', 'ParentId': 'root'},
        {'Id': 'c', 'Name': 'Ads', 'Type': 'Folder', 'ParentId': 'a'},
      ]);
      expect([for (final n in tree) n.name], ['Disk 2', 'Disk 10']);
      expect(tree.first.children.single.name, 'Ads');
    });
  });

  group('commercialSegments', () {
    test('reads Commercial segments in order', () async {
      late Uri asked;
      final client = _client((r) async {
        asked = r.url;
        return _json({
          'Items': [
            {'Type': 'Commercial', 'StartTicks': 6000000000, 'EndTicks': 7200000000},
            {'Type': 'Commercial', 'StartTicks': 4800000000, 'EndTicks': 6000000000},
            {'Type': 'Intro', 'StartTicks': 0, 'EndTicks': 600000000},
          ],
        });
      });
      final segments = await client.commercialSegments('item1');
      expect(asked.path, '/MediaSegments/item1');
      expect(asked.queryParameters['includeSegmentTypes'], 'Commercial');
      expect(segments, [
        (start: const Duration(minutes: 8), end: const Duration(minutes: 10)),
        (start: const Duration(minutes: 10), end: const Duration(minutes: 12)),
      ]);
    });

    test('404 (no segments, or an older server) means none', () async {
      final client = _client((r) async => http.Response('', 404));
      expect(await client.commercialSegments('item1'), isEmpty);
    });

    test('other errors are reported', () async {
      final client = _client((r) async => http.Response('', 500));
      expect(client.commercialSegments('item1'), throwsA(isA<JellyfinException>()));
    });
  });

  test('serverId comes from the public system info', () async {
    final client = _client((r) async {
      expect(r.url.path, '/System/Info/Public');
      return _json({'ServerName': 'Home', 'Version': '10.11.11', 'Id': '8b42d538d8474d8685a87697a21ce859'});
    });
    expect(await client.serverId(), '8b42d538d8474d8685a87697a21ce859');
  });

  test('sessions keep the server id through JSON and device renames', () {
    const session = JellyfinSession(
      serverUrl: 'https://jf.example',
      serverName: 'Home',
      userId: 'u1',
      userName: 'me',
      accessToken: 't',
      deviceId: 'd',
    );
    expect(JellyfinSession.fromJson(session.toJson()).serverId, isNull);
    final known = session.withServerId('srv');
    expect(JellyfinSession.fromJson(known.toJson()).serverId, 'srv');
    expect(known.withDeviceId('d2').serverId, 'srv');
  });
}
