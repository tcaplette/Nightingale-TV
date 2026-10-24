import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/emby_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_clients.dart';

/// A response recorded from the Emby 4.10 test container
/// (tool/test_servers), trimmed.
Object? fixture(String name) => jsonDecode(File('test/fixtures/emby/$name.json').readAsStringSync());

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

const userId = '900ca7ffb70648a8bdb33214f9b4de2f';

EmbyClient emby(Future<http.Response> Function(http.Request r) handler, {bool signedIn = true}) => EmbyClient(
      serverUrl: 'http://emby.local:8096',
      deviceId: 'dev1',
      deviceName: 'Living room',
      accessToken: signedIn ? 'emby-token' : null,
      userId: signedIn ? userId : null,
      httpClient: MockClient(handler),
    );

void main() {
  test("Emby's public info is told apart from Jellyfin's", () async {
    final info = await emby((r) async => json(fixture('system_info_public')), signedIn: false).publicInfo();
    expect(info.kind, ServerKind.emby);
    expect(info.version, '4.10.2.0');
    final jellyfin = JellyfinClient(
      serverUrl: 'http://jf.local',
      deviceId: 'd',
      deviceName: 't',
      httpClient: MockClient((r) async => json({
            'ServerName': 'Den',
            'Version': '10.11.0',
            'ProductName': 'Jellyfin Server',
            'Id': 'abc',
            'StartupWizardCompleted': true,
          })),
    );
    expect((await jellyfin.publicInfo()).kind, ServerKind.jellyfin);
    // Emby's answer to a plain Jellyfin client, as the address step sees it.
    final asJellyfin = JellyfinClient(
        serverUrl: 'http://emby.local', deviceId: 'd', deviceName: 't',
        httpClient: MockClient((r) async => json(fixture('system_info_public'))));
    expect((await asJellyfin.publicInfo()).kind, ServerKind.emby);
  });

  test('sign-in sends Emby\'s header, and later requests carry the token', () async {
    final requests = <http.Request>[];
    final client = emby((r) async {
      requests.add(r);
      return r.url.path == '/Users/AuthenticateByName' ? json(fixture('authenticate')) : json({});
    }, signedIn: false);
    final session = await client.authenticateByName('admin', 'pw', serverName: 'Attic');
    expect(session.kind, ServerKind.emby);
    expect(session.userId, userId);
    expect(session.accessToken, 'emby-token');
    final signIn = requests.single;
    expect(signIn.headers['X-Emby-Authorization'],
        'Emby Client="Nightingale TV", Device="Living room", DeviceId="dev1", Version="${JellyfinClient.clientVersion}"');
    expect(signIn.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(signIn.body), {'Username': 'admin', 'Pw': 'pw'});
    await client.checkSession();
    expect(requests.last.url.path, '/Users/$userId');
    expect(requests.last.headers['X-Emby-Token'], 'emby-token');
  });

  test('Quick Connect is off when Emby has no such route', () async {
    expect(await emby((r) async => http.Response('not found', 404), signedIn: false).quickConnectEnabled(), isFalse);
  });

  test('libraries come from the user\'s views', () async {
    final libs = await emby((r) async {
      expect(r.url.path, '/Users/$userId/Views');
      expect(r.url.queryParameters, isEmpty);
      return json(fixture('views'));
    }).libraries();
    expect({for (final l in libs) l.name: l.collectionType}, {
      'Home Videos': 'homevideos',
      'Movies': 'movies',
      'Music': 'music',
      'Music Videos': 'musicvideos',
      'TV': 'tvshows',
    });
  });

  test('item listings page through the user\'s items', () async {
    final starts = <String?>[];
    final episodes = (fixture('episodes_page') as Map<String, Object?>)['Items'] as List;
    final items = await emby((r) async {
      expect(r.url.path, '/Users/$userId/Items');
      expect(r.url.queryParameters.containsKey('userId'), isFalse);
      starts.add(r.url.queryParameters['StartIndex']);
      final start = int.parse(r.url.queryParameters['StartIndex']!);
      return json({'Items': start == 0 ? episodes.sublist(0, 2) : episodes.sublist(2), 'TotalRecordCount': 3});
    }).allItems({'IncludeItemTypes': 'Episode'}, pageSize: 2);
    expect(starts, ['0', '2']);
    expect(items, hasLength(3));
  });

  test('the scan maps Emby items into the index, with chapters and Etags', () async {
    final client = emby((r) async {
      if (r.url.path.endsWith('/Views')) return json(fixture('views'));
      final q = r.url.queryParameters;
      if (q['ParentId'] == '3' && q['IncludeItemTypes'] == 'Series') return json(fixture('series'));
      if (q['ParentId'] == '3' && q['IncludeItemTypes'] == 'Episode') {
        expect(q['Fields'], contains('Etag'));
        return json(fixture('episodes_page'));
      }
      return json({'Items': [], 'TotalRecordCount': 0});
    });
    final index = await client.fetchLibraryIndex();
    expect(index.episodes, hasLength(3));
    final first = index.episodes.first;
    expect(first.seriesName, isNotNull);
    expect(first.season, 1);
    expect(first.etag, isNotNull);
    expect(first.chapters, hasLength(3), reason: 'two act breaks and the start');
    expect(index.series.map((s) => s.name), contains(first.seriesName));
  });

  test('an item without an Etag gets one from its modified date', () async {
    final items = await emby((r) async => json({
          'Items': [
            {'Id': '9', 'Name': 'x', 'DateModified': '2026-10-21T18:00:00Z'}
          ],
          'TotalRecordCount': 1,
        })).allItems({'Fields': 'Etag'});
    expect(items.single['Etag'], '2026-10-21T18:00:00Z|');
  });

  group('PlaybackInfo', () {
    Map<String, Object?> answer({bool direct = false, String reasons = 'ContainerBitrateExceedsLimit'}) {
      final j = fixture('playback_info_transcode') as Map<String, Object?>;
      final source = ((j['MediaSources'] as List).first as Map<String, Object?>);
      source['SupportsDirectPlay'] = direct;
      source['TranscodingUrl'] =
          (source['TranscodingUrl'] as String).replaceFirst('ContainerBitrateExceedsLimit', reasons);
      return j;
    }

    late Map<String, Object?> body;
    EmbyClient deciding(Map<String, Object?> response) => emby((r) async {
          expect(r.url.path, '/Items/137/PlaybackInfo');
          body = jsonDecode(r.body) as Map<String, Object?>;
          return json(response);
        });

    test('direct play', () async {
      final d = await deciding(answer(direct: true)).playbackDecision('137');
      expect(d.transcode, isFalse);
      // Emby's source ids aren't the item's: left out, Emby uses the first.
      expect(body.containsKey('MediaSourceId'), isFalse);
    });

    test('direct stream when only the audio converts', () async {
      final d = await deciding(answer(reasons: 'AudioCodecNotSupported')).playbackDecision('137');
      expect((d.transcode, d.directStream), (true, true));
    });

    test('a transcode under a cap, without the token in its URL', () async {
      final d = await deciding(answer()).playbackDecision('137', maxBitrate: 4000000);
      expect(body['MaxStreamingBitrate'], 4000000);
      expect((d.transcode, d.directStream), (true, false));
      final t = d.transcodeTemplate!;
      expect(t.toString(), startsWith('http://emby.local:8096/videos/137/stream.ts?'));
      expect(t.queryParameters.keys.map((k) => k.toLowerCase()), isNot(contains('api_key')));
      expect(d.sourceCodec, 'h264');
      final job = await emby((r) async => json({})).transcodeUri(t, playSessionId: 'job1', startAt: const Duration(seconds: 90));
      expect(job.queryParameters['PlaySessionId'], 'job1');
      expect(job.queryParameters['StartTimeTicks'], '900000000');
    });
  });

  test('a 10-bit HEVC source is converted, not copied, when the URL limits the bit depth', () {
    // As Emby 4.10 answered the Android emulator's profile (HEVC Main, 8-bit).
    final t = Uri.parse('http://emby.local/videos/158/stream.ts?VideoCodec=h264,hevc,mpeg2video'
        '&hevc-profile=main&hevc-videobitdepth=8&TranscodeReasons=AudioCodecNotSupported');
    Map<String, Object?> source(String profile, int depth) => {
          'MediaStreams': [
            {'Type': 'Video', 'Codec': 'hevc', 'Profile': profile, 'BitDepth': depth},
            {'Type': 'Audio', 'Codec': 'ac3'},
          ]
        };
    expect(EmbyClient.videoFits(t, source('Main 10', 10)), isFalse);
    expect(EmbyClient.videoFits(t, source('Main', 8)), isTrue);
  });

  test('the static stream leaves the media source to Emby', () {
    final uri = emby((r) async => json({})).streamUri('137');
    expect(uri.path, '/Videos/137/stream');
    expect(uri.queryParameters, {'static': 'true'});
  });

  test('reports, and stopping a transcode', () async {
    final sent = <http.Request>[];
    final client = emby((r) async {
      sent.add(r);
      return http.Response('', 204);
    });
    const report = PlaybackReport(itemId: '137', playSessionId: 's1', position: Duration(seconds: 10));
    await client.reportPlaybackStart(report);
    await client.reportPlaybackProgress(report);
    await client.reportPlaybackStopped(report);
    await client.stopTranscode('job1');
    expect([for (final r in sent) '${r.method} ${r.url.path}'], [
      'POST /Sessions/Playing',
      'POST /Sessions/Playing/Progress',
      'POST /Sessions/Playing/Stopped',
      'DELETE /Videos/ActiveEncodings',
    ]);
    final body = jsonDecode(sent.first.body) as Map<String, Object?>;
    expect(body['ItemId'], '137');
    expect(body.containsKey('MediaSourceId'), isFalse);
    expect(sent.last.url.queryParameters, {'deviceId': 'dev1', 'playSessionId': 'job1'});
  });

  test('no media-segment request: Emby has none', () async {
    var asked = false;
    final segments = await emby((r) async {
      asked = true;
      return json({});
    }).commercialSegments('137');
    expect(segments, isEmpty);
    expect(asked, isFalse);
  });

  test('folders for pools come from the user\'s items, as a tree', () async {
    final tree = await emby((r) async {
      expect(r.url.path, '/Users/$userId/Items');
      return json(fixture('home_videos_folders'));
    }).folderTree('7');
    expect(tree.single.name, 'Home Videos');
    expect(tree.single.children.single.name, 'Commercials');
    expect(tree.single.children.single.children.single.name, 'Reels');
  });

  test('the address step finds Emby, and makes an Emby client for it', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((r) async {
      if (r.uri.path == '/System/Info/Public') {
        r.response.headers.contentType = ContentType.json;
        r.response.write(jsonEncode(fixture('system_info_public')));
      } else {
        r.response.statusCode = 404;
      }
      await r.response.close();
    });
    final found = await identifyServer('http://127.0.0.1:${server.port}', deviceId: 'd', deviceName: 't');
    expect(found.info.kind, ServerKind.emby);
    expect(found.client, isA<EmbyClient>());
    found.client.close();
  });
}
