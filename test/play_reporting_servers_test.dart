import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/emby_client.dart';
import 'package:nightingale_tv/server/plex/plex_client.dart';

/// Item answers recorded from the Docker test servers (tool/test_servers):
/// Jellyfin's "Sub Test Embedded" has a 52.156 s resume point and "Sub Test
/// External" none (watched); Emby's "Copper Moon" has a 5:00 resume point
/// and "Sub Test External" none; Plex's metadata_resume_point has a
/// 300.1 s `viewOffset` and metadata_no_resume_point none.
Map<String, Object?> fixture(String server, String name) =>
    jsonDecode(File('test/fixtures/$server/$name.json').readAsStringSync()) as Map<String, Object?>;

http.Response json(Object? body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

void main() {
  final sent = <http.Request>[];
  setUp(sent.clear);

  MockClient answering(Object? body) => MockClient((r) async {
        sent.add(r);
        return body == null ? http.Response('', 204) : json(body);
      });

  group('Jellyfin', () {
    JellyfinClient jellyfin([Object? body]) => JellyfinClient(
        serverUrl: 'http://jf.local:8097',
        deviceId: 'dev1',
        deviceName: 'Living room',
        accessToken: 'jf-token',
        userId: 'u1',
        httpClient: answering(body));

    test("the resume point is the user's PlaybackPositionTicks, from the item request", () async {
      final client = jellyfin(fixture('jellyfin', 'item_subtitles_embedded'));
      expect(await client.resumePoint('02f10eab'), const Duration(microseconds: 52156000));
      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/Users/u1/Items/02f10eab');
    });

    test('no resume point is zero', () async {
      expect(await jellyfin(fixture('jellyfin', 'item_subtitles_external')).resumePoint('ea32'), Duration.zero);
      expect(JellyfinClient.parseResumePoint(const {}), Duration.zero);
      expect(JellyfinClient.parseResumePoint(const {'UserData': {'PlaybackPositionTicks': -5}}), Duration.zero);
    });

    test('the transcode ping is the sessions ping, with the job, and nothing else', () async {
      await jellyfin().keepTranscodeAlive('job1');
      expect('${sent.single.method} ${sent.single.url.path}', 'POST /Sessions/Playing/Ping');
      expect(sent.single.url.queryParameters, {'playSessionId': 'job1'});
      expect(sent.single.body, '{}', reason: 'no playback report');
    });
  });

  group('Emby', () {
    EmbyClient emby([Object? body]) => EmbyClient(
        serverUrl: 'http://emby.local:8096',
        deviceId: 'dev1',
        deviceName: 'Living room',
        accessToken: 'emby-token',
        userId: 'u1',
        httpClient: answering(body));

    test("the resume point is the user's PlaybackPositionTicks", () async {
      final client = emby(fixture('emby', 'item_resume_point'));
      expect(await client.resumePoint('34'), const Duration(minutes: 5));
      expect(sent.single.url.path, '/Users/u1/Items/34');
      expect(await emby(fixture('emby', 'item_subtitles_external')).resumePoint('176'), Duration.zero);
    });

    test('the transcode ping', () async {
      await emby().keepTranscodeAlive('job1');
      expect('${sent.single.method} ${sent.single.url.path}', 'POST /Sessions/Playing/Ping');
      expect(sent.single.url.queryParameters, {'playSessionId': 'job1'});
    });
  });

  group('Plex', () {
    PlexClient plex([Object? body]) => PlexClient(
        serverUrl: 'http://192.168.1.20:32400',
        deviceId: 'dev1',
        deviceName: 'Living room',
        accessToken: 'server-token',
        userId: '1001',
        httpClient: answering(body));

    test('the resume point is viewOffset, from the metadata request', () async {
      final client = plex(fixture('plex', 'metadata_resume_point'));
      expect(await client.resumePoint('129'), const Duration(milliseconds: 300100));
      expect(sent.single.url.path, '/library/metadata/129');
      expect(await plex(fixture('plex', 'metadata_no_resume_point')).resumePoint('34'), Duration.zero);
    });

    test("the transcode ping is the universal transcoder's, not a timeline", () async {
      await plex().keepTranscodeAlive('job1');
      expect('${sent.single.method} ${sent.single.url.path}', 'GET /video/:/transcode/universal/ping');
      expect(sent.single.url.queryParameters['session'], 'job1');
    });
  });
}
