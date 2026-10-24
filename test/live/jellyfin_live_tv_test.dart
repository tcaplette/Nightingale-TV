import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_live_tv.dart';
import 'package:nightingale_tv/server/emby_client.dart';
import 'package:nightingale_tv/server/live_tv.dart';
import 'package:nightingale_tv/server/media_server.dart';

Object? fixture(String dir, String name) => jsonDecode(File('test/fixtures/$dir/$name.json').readAsStringSync());

typedef Handler = http.Response Function(http.Request r);

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  late List<http.Request> requests;
  JellyfinClient jellyfin(Handler handler) {
    requests = [];
    return JellyfinClient(
      serverUrl: 'http://jf.local:8097',
      deviceId: 'dev1',
      deviceName: 'Test',
      accessToken: 'tok',
      userId: '8845e2cc88714e40b8586d5fa3a70950',
      httpClient: MockClient((r) async {
        requests.add(r);
        return handler(r);
      }),
    );
  }

  Handler serving(Map<String, Object? Function(http.Request)> routes) => (r) {
        final route = routes['${r.method} ${r.url.path}'];
        return route == null ? http.Response('not found', 404) : json(route(r));
      };

  group('availability', () {
    test('a server with channels the user may watch', () async {
      final c = jellyfin(serving({
        'GET /Users/Me': (_) => fixture('jellyfin_live', 'user'),
        'GET /LiveTv/Info': (_) => fixture('jellyfin_live', 'info'),
        'GET /LiveTv/Channels': (r) => {'Items': [], 'TotalRecordCount': 5},
      }));
      expect(await c.liveTv.availability(), LiveTvAvailability.available);
    });

    test('a user without Live TV access', () async {
      final c = jellyfin(serving({
        'GET /Users/Me': (_) => {
              'Id': 'u',
              'Policy': {'EnableLiveTvAccess': false},
            },
        'GET /LiveTv/Info': (_) => fixture('jellyfin_live', 'info'),
      }));
      expect(await c.liveTv.availability(), LiveTvAvailability.noAccess);
    });

    test('no tuner, or no channels (Emby without Premiere)', () async {
      final off = jellyfin(serving({
        'GET /Users/Me': (_) => fixture('jellyfin_live', 'user'),
        'GET /LiveTv/Info': (_) => {'IsEnabled': false, 'EnabledUsers': []},
      }));
      expect(await off.liveTv.availability(), LiveTvAvailability.noChannels);
      requests = [];
      final emby = EmbyClient(
        serverUrl: 'http://emby.local:8096',
        deviceId: 'dev1',
        deviceName: 'Test',
        accessToken: 'tok',
        userId: '900ca7ffb70648a8bdb33214f9b4de2f',
        httpClient: MockClient((r) async {
          requests.add(r);
          return serving({
            'GET /Users/900ca7ffb70648a8bdb33214f9b4de2f': (_) => {
                  'Policy': {'EnableLiveTvAccess': true},
                },
            'GET /LiveTv/Info': (_) => fixture('emby_live', 'info_no_premiere'),
            'GET /LiveTv/Channels': (_) => fixture('emby_live', 'channels_no_premiere'),
          })(r);
        }),
      );
      expect(await emby.liveTv.availability(), LiveTvAvailability.noChannels);
      expect(requests.first.headers['X-Emby-Token'], 'tok');
    });

    test('reasons as Add source shows them', () {
      expect(LiveTvAvailability.noChannels.reason('Den'), 'Den has no Live TV channels');
      expect(LiveTvAvailability.noAccess.reason('Den'), "Your Den account can't watch Live TV");
    });
  });

  test('channels, in number order, with logos through the image route', () async {
    final c = jellyfin(serving({'GET /LiveTv/Channels': (_) => fixture('jellyfin_live', 'channels')}));
    final channels = await c.liveTv.channels();
    expect([for (final ch in channels) ch.number], ['2.1', '4.1', '7.1', '9.1', '11.1']);
    expect(channels.first.name, 'Fake H264');
    expect(channels.first.key, '81d990986b8a488cdadeb5d6a5c275d0');
    expect(channels.first.logo, startsWith('http://jf.local:8097/Items/81d990986b8a488cdadeb5d6a5c275d0/Images/Primary'));
    expect(Uri.parse(channels.first.logo!).queryParameters['tag'], '5cf825f7e6b780dd3b75d3e0ce30f6a2');
    expect(requests.single.url.queryParameters['UserId'], '8845e2cc88714e40b8586d5fa3a70950');
  });

  test('programmes: 50 channels per request, mapped from the guide', () async {
    final items = (fixture('jellyfin_live', 'programs') as Map)['Items'] as List;
    final c = jellyfin(serving({'POST /LiveTv/Programs': (_) => {'Items': items}}));
    final ids = [for (var i = 0; i < 120; i++) 'c$i'];
    final from = DateTime.utc(2026, 10, 21, 23, 30), to = from.add(const Duration(hours: 6));
    final guide = await c.liveTv.programs(ids, from, to);
    expect(requests, hasLength(3));
    final bodies = [for (final r in requests) jsonDecode(r.body) as Map<String, Object?>];
    expect([for (final b in bodies) (b['ChannelIds'] as List).length], [50, 50, 20]);
    expect(bodies.first['MinEndDate'], '2026-10-21T23:30:00.000Z');
    expect(bodies.first['MaxStartDate'], '2026-10-22T05:30:00.000Z');
    final movies = guide['eb4f67106028ba972475175a7863d5f9']!;
    expect(movies.first.title, 'Test Movie');
    expect(movies.first.isMovie, isTrue);
    expect(movies.first.year, 1999);
    expect(movies.first.rating, 'PG');
    final news = guide.values.expand((l) => l).firstWhere((p) => p.title == 'The News');
    expect(news.subtitle, startsWith('Part'));
    expect(news.isMovie, isFalse);
  });

  group('opening a live stream', () {
    Handler opening(String fixtureName) => serving({
          'POST /Items/81d990986b8a488cdadeb5d6a5c275d0/PlaybackInfo': (_) => fixture('jellyfin_live', fixtureName),
          'POST /LiveStreams/Close': (_) => null,
          'DELETE /Videos/ActiveEncodings': (_) => null,
        });

    test('Linux direct play: the shared stream at the server address the app uses', () async {
      final c = jellyfin(opening('playbackinfo_direct_linux'));
      final s = await c.liveTv.open('81d990986b8a488cdadeb5d6a5c275d0');
      expect(s.method, PlayMethod.directPlay);
      expect(s.uri.toString(), startsWith('http://jf.local:8097/LiveTv/LiveStreamFiles/'));
      expect(s.uri.path, endsWith('/stream.ts'));
      expect(s.liveStreamId, isNotNull);
      final body = jsonDecode(requests.single.body) as Map<String, Object?>;
      expect(body['AutoOpenLiveStream'], isTrue);
      expect(body['MaxStreamingBitrate'], JellyfinLiveTv.noCap);
      expect(body['UserId'], '8845e2cc88714e40b8586d5fa3a70950');
      await c.liveTv.close(s);
      await c.liveTv.close(s);
      final closes = requests.where((r) => r.url.path == '/LiveStreams/Close').toList();
      expect(closes, hasLength(1));
      expect(closes.single.url.queryParameters['LiveStreamId'], s.liveStreamId);
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
    });

    test('a transcode: its URL without the token, closed with its encoding', () async {
      final c = jellyfin(opening('playbackinfo_transcode_linux'));
      final s = await c.liveTv.open('81d990986b8a488cdadeb5d6a5c275d0', maxBitrate: 4000000);
      expect(s.method, PlayMethod.transcode);
      expect(s.uri.host, 'jf.local');
      expect(s.uri.queryParameters.keys.map((k) => k.toLowerCase()), isNot(contains('apikey')));
      expect(s.uri.queryParameters['LiveStreamId'], s.liveStreamId);
      expect(s.headers['Authorization'], contains('Token="tok"'));
      expect((jsonDecode(requests.single.body) as Map)['MaxStreamingBitrate'], 4000000);
      await c.liveTv.close(s);
      final delete = requests.singleWhere((r) => r.method == 'DELETE');
      expect(delete.url.queryParameters, {'deviceId': 'dev1', 'playSessionId': s.playSessionId});
    });

    test('Android: MPEG-2 is converted; an HLS source with only audio to convert is a direct stream', () async {
      var c = jellyfin(opening('playbackinfo_transcode_android_mpeg2'));
      final mpeg2 = await c.liveTv.open('81d990986b8a488cdadeb5d6a5c275d0', profile: {'MaxStreamingBitrate': 1000000000});
      expect(mpeg2.method, PlayMethod.transcode);
      expect(mpeg2.uri.queryParameters['VideoCodec'], 'h264');
      c = jellyfin(opening('playbackinfo_hls'));
      final hls = await c.liveTv.open('81d990986b8a488cdadeb5d6a5c275d0', profile: {'MaxStreamingBitrate': 1000000000});
      expect(hls.method, PlayMethod.directStream);
    });

    test('failures name their cause', () async {
      Future<LiveFailure> failure(http.Response Function() answer) async {
        final c = jellyfin((_) => answer());
        try {
          await c.liveTv.open('x');
        } on LiveTvException catch (e) {
          return e.failure;
        }
        fail('opened');
      }

      expect(await failure(() => http.Response('LiveTvConflictException: All tuners are in use', 500)), LiveFailure.tunersBusy);
      expect(await failure(() => http.Response('forbidden', 403)), LiveFailure.refused);
      expect(await failure(() => http.Response('boom', 500)), LiveFailure.other);
      final unreachable = JellyfinClient(
          serverUrl: 'http://jf.local:8097',
          deviceId: 'd',
          deviceName: 'T',
          httpClient: MockClient((_) async => throw http.ClientException('refused')));
      expect(() => unreachable.liveTv.open('x'),
          throwsA(isA<LiveTvException>().having((e) => e.failure, 'failure', LiveFailure.unreachable)));
    });
  });

  test('reports carry the live stream and never mark anything played', () async {
    final c = jellyfin(serving({
      'POST /Items/81d990986b8a488cdadeb5d6a5c275d0/PlaybackInfo': (_) => fixture('jellyfin_live', 'playbackinfo_direct_linux'),
      'POST /Sessions/Playing': (_) => null,
      'POST /Sessions/Playing/Progress': (_) => null,
      'POST /Sessions/Playing/Stopped': (_) => null,
    }));
    final s = await c.liveTv.open('81d990986b8a488cdadeb5d6a5c275d0');
    await c.liveTv.reportStart(s);
    await c.liveTv.reportProgress(s, const Duration(seconds: 10));
    await c.liveTv.reportStopped(s, const Duration(seconds: 12));
    final reports = requests.where((r) => r.url.path.startsWith('/Sessions')).toList();
    expect([for (final r in reports) r.url.path], ['/Sessions/Playing', '/Sessions/Playing/Progress', '/Sessions/Playing/Stopped']);
    final progress = jsonDecode(reports[1].body) as Map<String, Object?>;
    expect(progress['ItemId'], '81d990986b8a488cdadeb5d6a5c275d0');
    expect(progress['LiveStreamId'], s.liveStreamId);
    expect(progress['PositionTicks'], 100000000);
    expect(progress['PlayMethod'], 'DirectPlay');
    expect(requests.where((r) => r.url.path.contains('PlayedItems')), isEmpty);
  });
}
