import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';

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
