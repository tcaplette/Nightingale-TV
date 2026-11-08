import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';

/// Folder listings captured from the test server (names, ids and parents
/// only).
final _captured = jsonDecode(File('test/fixtures/folder_tree.json').readAsStringSync()) as Map<String, Object?>;

/// A Jellyfin movie library as `folderTree` lists it: the storage folder
/// `movies`; `Action` (12 movie folders), `Westerns` (3), single-movie
/// folders (listed as their movies), `New Picks` (5 loose movie files) and
/// `Extras` (3 movies, 2 trailers, a music video and a home video).
final movieLibrary = <Map<String, Object?>>[
  for (final i in _movieLibraryItems)
    if (i['Type'] == 'Folder') i else {...i, 'RunTimeTicks': 1200000000},
];

final _movieLibraryItems = <Map<String, Object?>>[
  {'Id': 'store', 'Name': 'movies', 'Type': 'Folder', 'ParentId': 'lib'},
  {'Id': 'act', 'Name': 'Action', 'Type': 'Folder', 'ParentId': 'store'},
  for (var i = 1; i <= 12; i++) {'Id': 'a$i', 'Name': 'Action $i', 'Type': 'Movie', 'ParentId': 'act'},
  {'Id': 'west', 'Name': 'Westerns', 'Type': 'Folder', 'ParentId': 'store'},
  for (var i = 1; i <= 3; i++) {'Id': 'w$i', 'Name': 'Western $i', 'Type': 'Movie', 'ParentId': 'west'},
  {'Id': 'dh', 'Name': 'Die Hard', 'Type': 'Movie', 'ParentId': 'store'},
  {'Id': 'heat', 'Name': 'Heat', 'Type': 'Movie', 'ParentId': 'store'},
  {'Id': 'alien', 'Name': 'Alien', 'Type': 'Movie', 'ParentId': 'store'},
  {'Id': 'np', 'Name': 'New Picks', 'Type': 'Folder', 'ParentId': 'store'},
  for (var i = 1; i <= 5; i++) {'Id': 'n$i', 'Name': 'Loose $i', 'Type': 'Movie', 'ParentId': 'np'},
  {'Id': 'ex', 'Name': 'Extras', 'Type': 'Folder', 'ParentId': 'store'},
  for (var i = 1; i <= 3; i++) {'Id': 'em$i', 'Name': 'Feature $i', 'Type': 'Movie', 'ParentId': 'ex'},
  {'Id': 't1', 'Name': 'Trailer 1', 'Type': 'Trailer', 'ParentId': 'ex'},
  {'Id': 't2', 'Name': 'Trailer 2', 'Type': 'Trailer', 'ParentId': 'ex'},
  {'Id': 'mv', 'Name': 'Song', 'Type': 'MusicVideo', 'ParentId': 'ex'},
  {'Id': 'hv', 'Name': 'Party', 'Type': 'Video', 'ParentId': 'ex'},
  // A movie that's missing on disk is left out.
  {'Id': 'gone', 'Name': 'Gone', 'Type': 'Movie', 'ParentId': 'store', 'LocationType': 'Virtual'},
];

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
      expect(asked.queryParameters['IncludeItemTypes'], 'Folder,Series,Season,BoxSet,Movie,Video,MusicVideo,Trailer');
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

    test('a movie library: every folder, its movies, and single-movie folders as their movies', () async {
      late Uri asked;
      final client = _client((r) async {
        asked = r.url;
        return _json({'Items': movieLibrary, 'TotalRecordCount': movieLibrary.length});
      });
      final tree = await client.folderTree('lib');
      expect(asked.queryParameters['IncludeItemTypes'], 'Folder,Series,Season,BoxSet,Movie,Video,MusicVideo,Trailer',
          reason: 'one listing holds the folders and the videos');
      final top = tree.single;
      expect(top.name, 'movies');
      // Folders first, then the movies whose own folder Jellyfin merged
      // into them.
      expect([for (final n in top.children) n.name],
          ['Action', 'Extras', 'New Picks', 'Westerns', 'Alien', 'Die Hard', 'Heat']);
      expect([for (final n in top.children) n.type], ['Folder', 'Folder', 'Folder', 'Folder', 'Movie', 'Movie', 'Movie']);
      expect(top.children.where((n) => n.isVideo).map((n) => n.id), ['alien', 'dh', 'heat']);
      final action = top.children.firstWhere((n) => n.name == 'Action');
      expect(action.children, hasLength(12));
      expect(action.children.every((n) => n.type == 'Movie' && n.children.isEmpty), isTrue);
      final picks = top.children.firstWhere((n) => n.name == 'New Picks');
      expect([for (final n in picks.children) n.name], ['Loose 1', 'Loose 2', 'Loose 3', 'Loose 4', 'Loose 5']);
      final extras = top.children.firstWhere((n) => n.name == 'Extras');
      expect(extras.children.map((n) => n.type), ['Movie', 'Movie', 'Movie', 'Video', 'Video', 'Video', 'Video'],
          reason: 'music videos and trailers are plain videos');
    });

    test('channel pickers list only movies as videos; pool pickers list every video', () {
      final tree = FolderNode.buildTree(movieLibrary);
      FolderNode extras(List<FolderNode> t) => t.single.children.firstWhere((n) => n.name == 'Extras');
      expect(extras(FolderNode.shown(tree, programsOnly: true)).children, hasLength(3));
      expect(extras(FolderNode.shown(tree, programsOnly: false)).children, hasLength(7));
      expect(extras(tree).children, hasLength(7), reason: 'the tree itself is left as it is');
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

  group('single items as roots', () {
    /// [movieLibrary] as the server answers it: an item by `Ids`, or the
    /// videos under a `ParentId`.
    JellyfinClient library(List<Uri> asked) => _client((r) async {
          asked.add(r.url);
          final q = r.url.queryParameters;
          if (r.url.path == '/UserViews') return _json({'Items': []});
          List<Map<String, Object?>> items;
          if (q['Ids'] case final id?) {
            items = [for (final i in movieLibrary) if (i['Id'] == id) i];
          } else {
            final types = q['IncludeItemTypes']!.split(',');
            final parent = q['ParentId'];
            items = [
              for (final i in movieLibrary)
                if (i['ParentId'] == parent && types.contains(i['Type'])) i,
            ];
          }
          return _json({'Items': items, 'TotalRecordCount': items.length});
        });

    test('a movie root is that movie, without listing under it', () async {
      final asked = <Uri>[];
      expect(await library(asked).idsUnder('dh'), ['dh']);
      expect(asked.single.queryParameters['Ids'], 'dh');
    });

    test('a folder root lists the movies in it', () async {
      final asked = <Uri>[];
      expect(await library(asked).idsUnder('np'), ['n1', 'n2', 'n3', 'n4', 'n5']);
      expect(asked.last.queryParameters['ParentId'], 'np');
    });

    test('a trailer never plays as a program', () async {
      expect(await library([]).idsUnder('t1'), isEmpty);
    });

    test('a pool root that is a single video holds that video', () async {
      final asked = <Uri>[];
      final index = await library(asked).fetchLibraryIndex(pools: [
        CommercialPool(id: 'p', name: 'Trailers', roots: [
          const PoolRoot(itemId: 't1', libraryId: 'lib', label: 'Movies › Extras › Trailer 1'),
          const PoolRoot(itemId: 'ex', libraryId: 'lib', label: 'Movies › Extras'),
        ]),
      ]);
      expect(index.commercials.map((c) => c.id), containsAll(['t1', 't2', 'mv', 'hv', 'em1']));
      final lookup = asked.firstWhere((u) => u.queryParameters['Ids'] == 't1');
      expect(lookup.queryParameters['Fields'], 'Chapters,Etag', reason: 'what the index keeps of a commercial');
      expect(asked.where((u) => u.queryParameters['ParentId'] == 't1'), isEmpty);
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
      expect(client.commercialSegments('item1'), throwsA(isA<ServerException>()));
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
    const session = ServerSession(
      serverUrl: 'https://jf.example',
      serverName: 'Home',
      userId: 'u1',
      userName: 'me',
      accessToken: 't',
      deviceId: 'd',
    );
    expect(ServerSession.fromJson(session.toJson()).serverId, isNull);
    final known = session.withServerId('srv');
    expect(ServerSession.fromJson(known.toJson()).serverId, 'srv');
    expect(known.withDeviceId('d2').serverId, 'srv');
  });

  group('transcoding', () {
    test('streamUri is the static stream', () {
      final u = _client((r) async => _json(null)).streamUri('item1');
      expect(u.toString(), 'https://jf.example/Videos/item1/stream?static=true&mediaSourceId=item1');
    });

    test('playbackInfo sends the cap and a profile that direct-plays anything', () async {
      late Map<String, Object?> body;
      late http.Request sent;
      final client = _client((r) async {
        sent = r;
        body = jsonDecode(r.body) as Map<String, Object?>;
        return _json({
          'PlaySessionId': 'srv',
          'MediaSources': [
            {'Id': 'item1', 'SupportsDirectPlay': true, 'SupportsDirectStream': true},
          ],
        });
      });
      final decision = await client.playbackDecision('item1', maxBitrate: 8000000, startAt: const Duration(minutes: 10));
      expect(decision.transcode, isFalse);
      expect(sent.method, 'POST');
      expect(sent.url.path, '/Items/item1/PlaybackInfo');
      expect(sent.headers['Authorization'], contains('Token="secret-token"'));
      expect(body['UserId'], 'u1');
      expect(body['MaxStreamingBitrate'], 8000000);
      expect(body['StartTimeTicks'], const Duration(minutes: 10).inMicroseconds * 10);
      expect([body['EnableDirectPlay'], body['EnableDirectStream'], body['AllowVideoStreamCopy'], body['AllowAudioStreamCopy']],
          everyElement(isTrue));
      final profile = body['DeviceProfile'] as Map<String, Object?>;
      expect(profile['MaxStreamingBitrate'], 8000000);
      expect(profile['DirectPlayProfiles'], [
        {'Type': 'Video'},
        {'Type': 'Audio'},
      ], reason: 'no container or codec limits');
      final transcoding = (profile['TranscodingProfiles'] as List).single as Map<String, Object?>;
      expect(transcoding, containsPair('Protocol', 'http'));
      expect(transcoding, containsPair('Container', 'ts'));
      expect(transcoding, containsPair('VideoCodec', 'h264'));
      expect(transcoding, containsPair('AudioCodec', 'aac'));
    });

    test('a transcode answer gives an absolute URL without the token in it', () async {
      final client = _client((r) async => _json({
            'PlaySessionId': 'srv',
            'MediaSources': [
              {
                'Id': 'item1',
                'SupportsDirectPlay': false,
                'TranscodingUrl': '/videos/item1/stream.ts?&DeviceId=d&MediaSourceId=item1&VideoCodec=h264'
                    '&ApiKey=secret-token&PlaySessionId=srv&TranscodeReasons=ContainerBitrateExceedsLimit',
                'TranscodingSubProtocol': 'http',
              },
            ],
          }));
      final decision = await client.playbackDecision('item1', maxBitrate: 2000000);
      final template = decision.transcodeTemplate!;
      expect(template.origin, 'https://jf.example');
      expect(template.path, '/videos/item1/stream.ts');
      expect(template.toString(), isNot(contains('secret-token')));
      expect(template.queryParameters['VideoCodec'], 'h264');
      expect(template.queryParameters.containsKey(''), isFalse);

      final job = await client.transcodeUri(template, playSessionId: 'job1', startAt: const Duration(seconds: 90));
      expect(job.queryParameters['PlaySessionId'], 'job1');
      expect(job.queryParameters['StartTimeTicks'], '900000000');
      expect(job.queryParameters['DeviceId'], 'd');
      expect(job.toString(), isNot(contains('srv')));
    });

    test('a server under a base path keeps it', () {
      final client = JellyfinClient(serverUrl: 'https://jf.example/jellyfin', deviceId: 'd', deviceName: 'pc');
      expect(client.transcodeTemplate('/videos/x/stream.ts?api_key=k&a=1').toString(),
          'https://jf.example/jellyfin/videos/x/stream.ts?a=1');
    });

    test('forcing a transcode rules out direct play and stream copy', () async {
      late Map<String, Object?> body;
      final client = _client((r) async {
        body = jsonDecode(r.body) as Map<String, Object?>;
        return _json({
          'MediaSources': [
            {'Id': 'item1', 'SupportsDirectPlay': true, 'TranscodingUrl': '/videos/item1/stream.ts?a=1'},
          ],
        });
      });
      final decision = await client.playbackDecision('item1', forceTranscode: true);
      expect(decision.transcode, isTrue);
      expect([body['EnableDirectPlay'], body['EnableDirectStream'], body['AllowVideoStreamCopy'], body['AllowAudioStreamCopy']],
          everyElement(isFalse));
      expect(body.containsKey('MaxStreamingBitrate'), isFalse, reason: 'no cap');
      expect(body['EnableTranscoding'], isTrue);
    });

    test('no transcode URL when one is needed is an error', () async {
      final client = _client((r) async => _json({
            'MediaSources': [
              {'Id': 'item1', 'SupportsDirectPlay': false},
            ],
          }));
      expect(client.playbackDecision('item1', maxBitrate: 2000000), throwsA(isA<ServerException>()));
    });

    test('stopTranscode deletes the job by device and session', () async {
      late http.Request sent;
      final client = _client((r) async {
        sent = r;
        return http.Response('', 204);
      });
      await client.stopTranscode('job1');
      expect(sent.method, 'DELETE');
      expect(sent.url.path, '/Videos/ActiveEncodings');
      expect(sent.url.queryParameters, {'deviceId': 'd', 'playSessionId': 'job1'});
    });

    test('reports say how the item plays', () {
      const direct = PlaybackReport(itemId: 'i', playSessionId: 's', position: Duration(seconds: 1));
      expect(direct.toJson()['PlayMethod'], 'DirectPlay');
      const transcoded = PlaybackReport(
          itemId: 'i', playSessionId: 'job1', position: Duration(seconds: 1), playMethod: PlayMethod.transcode);
      expect(transcoded.toJson(), containsPair('PlayMethod', 'Transcode'));
      expect(transcoded.toJson(), containsPair('PlaySessionId', 'job1'));
    });
  });
}
