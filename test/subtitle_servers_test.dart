import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/emby_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/plex/plex_client.dart';

/// Item listings recorded from the Docker test servers (tool/test_servers)
/// for the subtitle test movies (make_media.sh): "Sub Test Embedded" (an
/// English and a Spanish track inside the file, neither default) and "Sub
/// Test External" (only `Sub Test External (2026).en.srt` beside it).
Map<String, Object?> fixture(String server, String name) =>
    jsonDecode(File('test/fixtures/$server/$name.json').readAsStringSync()) as Map<String, Object?>;

http.Response json(Object? body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

void main() {
  group('Jellyfin', () {
    final sent = <http.Request>[];
    JellyfinClient jellyfin(Map<String, Object?> item) => JellyfinClient(
          serverUrl: 'http://jf.local:8097',
          deviceId: 'dev1',
          deviceName: 'Living room',
          accessToken: 'jf-token',
          userId: 'u1',
          httpClient: MockClient((r) async {
            sent.add(r);
            return json(item);
          }),
        );
    setUp(sent.clear);

    test('embedded tracks, in the file order, from the item listing', () async {
      final item = fixture('jellyfin', 'item_subtitles_embedded');
      final tracks = await jellyfin(item).subtitleTracks('02f10eabe9b6edd254a42290a92c96b5');
      expect(sent.single.url.path, '/Users/u1/Items/02f10eabe9b6edd254a42290a92c96b5');
      expect(sent.single.url.path, isNot(contains('PlaybackInfo')));
      expect([for (final t in tracks) (t.id, t.language, t.isExternal, t.position, t.isDefault)], [
        ('2', 'eng', false, 0, false),
        ('3', 'spa', false, 1, false),
      ]);
      expect(tracks.first.codec, 'subrip');
      expect(tracks.first.burnsWhenConverting, isFalse, reason: 'text tracks load beside a conversion');
    });

    test('an external sidecar, and its stream URL at 0 and at a conversion join', () async {
      final item = fixture('jellyfin', 'item_subtitles_external');
      final client = jellyfin(item);
      const id = 'ea32ecb07427af6e0220b43f2980769a';
      final [track] = await client.subtitleTracks(id);
      expect((track.id, track.language, track.isExternal, track.position), ('0', 'eng', true, null));
      expect(client.subtitleUri(id, track).toString(), 'http://jf.local:8097/Videos/$id/$id/Subtitles/0/0/Stream.srt');
      // Jellyfin moves cues to the join only when it converts the format.
      expect(client.subtitleUri(id, track, startAt: const Duration(minutes: 2)).toString(),
          'http://jf.local:8097/Videos/$id/$id/Subtitles/0/1200000000/Stream.vtt');
      final uri = client.subtitleUri(id, track)!;
      expect(uri.queryParameters.keys.map((k) => k.toLowerCase()), isNot(anyOf(contains('api_key'), contains('apikey'))));
    });

    test('an image track burns while converting and has no stream of its own', () {
      final [pgs] = JellyfinClient.parseSubtitleTracks({
        'MediaSources': [
          {
            'Id': 'm1',
            'MediaStreams': [
              {'Type': 'Subtitle', 'Index': 3, 'Codec': 'PGSSUB', 'Language': 'fre', 'IsForced': true},
            ],
          },
        ],
      });
      expect((pgs.isImage, pgs.burnsWhenConverting, pgs.isForced, pgs.language), (true, true, true, 'fre'));
      expect(jellyfin(const {}).subtitleUri('m1', pgs), isNull);
    });

    test('a burned conversion asks SubtitleStreamIndex with Encode; none without', () async {
      final client = jellyfin(const {});
      final t = Uri.parse('http://jf.local:8097/videos/1/stream.ts?VideoCodec=h264&MediaSourceId=1&PlaySessionId=x');
      const pgs = SubtitleTrack(id: '3', codec: 'pgssub', burnsWhenConverting: true);
      final burned = await client.transcodeUri(t, playSessionId: 'job1', startAt: Duration.zero, burn: pgs);
      expect(burned.queryParameters['SubtitleStreamIndex'], '3');
      expect(burned.queryParameters['SubtitleMethod'], 'Encode');
      final plain = await client.transcodeUri(burned, playSessionId: 'job2', startAt: Duration.zero);
      expect(plain.queryParameters.keys, isNot(anyOf(contains('SubtitleStreamIndex'), contains('SubtitleMethod'))));
      expect(plain.queryParameters['PlaySessionId'], 'job2');
    });
  });

  group('Emby', () {
    EmbyClient emby(Map<String, Object?> item) => EmbyClient(
          serverUrl: 'http://emby.local:8096',
          deviceId: 'dev1',
          deviceName: 'Living room',
          accessToken: 'emby-token',
          userId: 'u1',
          httpClient: MockClient((r) async => json(item)),
        );

    test("embedded tracks, and its own media source in the stream URL", () async {
      final client = emby(fixture('emby', 'item_subtitles_embedded'));
      final tracks = await client.subtitleTracks('174');
      expect([for (final t in tracks) (t.id, t.language, t.position, t.source)], [
        ('2', 'eng', 0, 'mediasource_174'),
        ('3', 'spa', 1, 'mediasource_174'),
      ]);
      expect(client.subtitleUri('174', tracks[1], startAt: const Duration(minutes: 2)).toString(),
          'http://emby.local:8096/Videos/174/mediasource_174/Subtitles/3/1200000000/Stream.vtt');
    });

    test('an external sidecar after the file\'s streams, its two-letter language normalized', () async {
      final client = emby(fixture('emby', 'item_subtitles_external'));
      final [track] = await client.subtitleTracks('176');
      expect((track.id, track.language, track.isExternal, track.codec), ('2', 'eng', true, 'srt'));
      expect(client.subtitleUri('176', track).toString(),
          'http://emby.local:8096/Videos/176/mediasource_176/Subtitles/2/0/Stream.srt');
    });
  });

  group('Plex', () {
    final sent = <http.Request>[];
    PlexClient plex(Map<String, Object?> metadata) => PlexClient(
          serverUrl: 'http://192.168.1.20:32400',
          deviceId: 'dev1',
          deviceName: 'Living room',
          accessToken: 'server-token',
          userId: '1001',
          httpClient: MockClient((r) async {
            sent.add(r);
            return r.url.path.startsWith('/library/metadata/') ? json(metadata) : json({'MediaContainer': {'size': 0}});
          }),
        );
    setUp(sent.clear);

    test('embedded tracks burn while converting; Plex hands out only files beside the video', () async {
      final client = plex(fixture('plex', 'metadata_subtitles_embedded'));
      final tracks = await client.subtitleTracks('129');
      expect(sent.single.url.path, '/library/metadata/129');
      expect([for (final t in tracks) (t.id, t.language, t.position, t.source, t.burnsWhenConverting)], [
        ('179', 'eng', 0, '104', true),
        ('180', 'spa', 1, '104', true),
      ]);
      expect(client.subtitleUri('129', tracks.first), isNull);
    });

    test("an external sidecar loads from its stream, in the source's times", () async {
      final client = plex(fixture('plex', 'metadata_subtitles_external'));
      final [track] = await client.subtitleTracks('130');
      expect((track.id, track.language, track.isExternal, track.burnsWhenConverting), ('183', 'eng', true, false));
      expect(client.subtitleUri('130', track, startAt: const Duration(minutes: 20)).toString(),
          'http://192.168.1.20:32400/library/streams/183');
    });

    test("a burn selects the stream on the part for the job's decision, then puts the selection back", () async {
      final client = plex(fixture('plex', 'metadata_subtitles_embedded'));
      final tracks = await client.subtitleTracks('129');
      sent.clear();
      final t = Uri.parse('http://192.168.1.20:32400/video/:/transcode/universal/start.m3u8'
          '?path=%2Flibrary%2Fmetadata%2F129&subtitles=none&copyts=1&offset=0');
      final job = await client.transcodeUri(t, playSessionId: 'job1', startAt: const Duration(seconds: 90), burn: tracks[1]);
      expect([for (final r in sent) '${r.method} ${r.url.path} ${r.url.queryParameters['subtitleStreamID'] ?? r.url.queryParameters['subtitles']}'], [
        'PUT /library/parts/104 180',
        'GET /video/:/transcode/universal/decision burn',
        'PUT /library/parts/104 0',
      ]);
      expect(job.queryParameters['subtitles'], 'burn');
      sent.clear();
      final plain = await client.transcodeUri(t, playSessionId: 'job2', startAt: Duration.zero);
      expect(sent.single.url.queryParameters['subtitles'], 'none');
      expect(plain.queryParameters['subtitles'], 'none');
    });
  });
}
