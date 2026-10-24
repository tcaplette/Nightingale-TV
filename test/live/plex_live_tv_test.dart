import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/server/live_tv.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/plex/plex_client.dart';

Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/plex_live/$name.json').readAsStringSync()) as Map<String, Object?>;

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  late List<http.Request> requests;
  PlexClient plex(Map<String, Object? Function(http.Request)> routes, {int? status}) {
    requests = [];
    return PlexClient(
      serverUrl: 'http://plex.local:32400',
      deviceId: 'dev1',
      deviceName: 'Test',
      accessToken: 'tok',
      httpClient: MockClient((r) async {
        requests.add(r);
        final route = routes['${r.method} ${r.url.path}'];
        if (route == null) return http.Response('not found', 404);
        return json(route(r), status ?? 200);
      }),
    );
  }

  final epg = 'tv.plex.providers.epg.xmltv:2';
  Map<String, Object? Function(http.Request)> server() => {
        'GET /livetv/dvrs': (_) => fixture('dvrs'),
        'GET /$epg/lineups/dvr/channels': (_) => fixture('channels'),
        'GET /$epg/grid': (_) => fixture('grid_day'),
        'POST /livetv/dvrs/2/channels/fake21.test/tune': (_) => fixture('tune'),
        'GET /video/:/transcode/universal/decision': (r) =>
            fixture(r.url.queryParameters['X-Plex-Client-Profile-Extra']!.contains('mpeg2video') ? 'decision_copy' : 'decision_transcode'),
        'GET /:/timeline': (_) => {'MediaContainer': {}},
        'GET /video/:/transcode/universal/stop': (_) => {'MediaContainer': {}},
      };

  group('availability', () {
    test('a server with a DVR', () async {
      expect(await plex(server()).liveTv.availability(), LiveTvAvailability.available);
    });

    test('a server without a DVR', () async {
      final c = plex({
        'GET /livetv/dvrs': (_) => {
              'MediaContainer': {'size': 0},
            },
      });
      expect(await c.liveTv.availability(), LiveTvAvailability.noChannels);
    });

    test('a Home user without tuner access', () async {
      final c = plex({'GET /livetv/dvrs': (_) => {'error': 'forbidden'}}, status: 403);
      expect(await c.liveTv.availability(), LiveTvAvailability.noAccess);
    });
  });

  test("every DVR's channels, a channel on two DVRs once, grouped by lineup", () async {
    final dvrs = fixture('dvrs');
    final container = dvrs['MediaContainer'] as Map<String, Object?>;
    final first = (container['Dvr'] as List).first as Map<String, Object?>;
    container['Dvr'] = [first, {...first, 'key': '3', 'lineupTitle': 'Second'}];
    final c = plex({...server(), 'GET /livetv/dvrs': (_) => dvrs});
    final channels = await c.liveTv.channels();
    expect([for (final ch in channels) ch.key], ['fake21.test', 'fake41.test', 'fake71.test']);
    expect([for (final ch in channels) ch.number], ['2.1', '4.1', '7.1']);
    expect(channels.first.group, 'Fake tuner guide');
    expect(channels.first.logo, 'http://127.0.0.1:5104/logo/2.1.png');
    expect(channels.first.guideId, 'fake21.test');
  });

  test("the guide as Plex Web asks for it: each channel's grid, by day", () async {
    final c = plex(server());
    final from = DateTime.fromMillisecondsSinceEpoch(1792629000 * 1000);
    final guide = await c.liveTv.programs(['fake21.test'], from, from.add(const Duration(hours: 2)));
    final grids = requests.where((r) => r.url.path.endsWith('/grid')).toList();
    expect(grids, isNotEmpty);
    expect(grids.first.url.queryParameters['channelGridKey'], 'fake21.test');
    expect(grids.first.url.queryParameters['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(grids.first.headers['X-Plex-Token'], 'tok');
    final news = guide['fake21.test']!;
    expect(news.first.title, 'The News');
    expect(news.first.subtitle, 'Part 4');
    expect((news.first.season, news.first.episode), (3, 4));
    expect(news.first.rating, 'TV-PG');
    expect(news.first.isNew, isTrue);
    expect(news[1].isNew, isFalse);
    expect(news.first.start, from);
  });

  test("Linux: tunes, then direct-streams the tuned session through the decision; stopped frees the tuner", () async {
    final c = plex(server());
    final s = await c.liveTv.open('fake21.test');
    final tune = requests.singleWhere((r) => r.url.path.endsWith('/tune'));
    expect(tune.method, 'POST');
    expect(tune.headers['X-Plex-Session-Identifier'], s.playSessionId);
    final decision = requests.singleWhere((r) => r.url.path.endsWith('/decision'));
    expect(decision.url.queryParameters['path'], '/livetv/sessions/ac4f7022-5ae9-4179-9de2-6c206202e2ab');
    expect(decision.url.queryParameters['directStream'], '1');
    expect(decision.headers['X-Plex-Session-Identifier'], s.playSessionId);
    expect(s.method, PlayMethod.directStream);
    expect(s.uri.path, '/video/:/transcode/universal/start.m3u8');
    expect(s.uri.queryParameters['X-Plex-Session-Identifier'], s.playSessionId);
    expect(s.headers['X-Plex-Token'], 'tok');
    await c.liveTv.reportProgress(s, const Duration(seconds: 10));
    await c.liveTv.close(s);
    await c.liveTv.close(s);
    final timelines = requests.where((r) => r.url.path == '/:/timeline').toList();
    expect([for (final t in timelines) t.url.queryParameters['state']], ['playing', 'stopped']);
    expect(timelines.first.url.queryParameters['key'], '/livetv/sessions/ac4f7022-5ae9-4179-9de2-6c206202e2ab');
    expect(timelines.first.url.queryParameters['time'], '10000');
    expect(timelines.last.headers['X-Plex-Session-Identifier'], s.playSessionId);
    final stop = requests.singleWhere((r) => r.url.path.endsWith('/stop'));
    expect(stop.url.queryParameters['session'], s.transcodeSession);
  });

  test('Android: the decision on the tuned session converts MPEG-2; its transcode stops on close', () async {
    final c = plex(server());
    final s = await c.liveTv.open('fake21.test', profile: {
      'MaxStreamingBitrate': 1000000000,
      'DirectPlayProfiles': [
        {'Type': 'Video', 'Container': 'ts', 'VideoCodec': 'h264', 'AudioCodec': 'aac'},
      ],
      'TranscodingProfiles': [
        {'VideoCodec': 'h264', 'AudioCodec': 'aac'},
      ],
    });
    final decision = requests.singleWhere((r) => r.url.path.endsWith('/decision'));
    expect(decision.url.queryParameters['path'], '/livetv/sessions/ac4f7022-5ae9-4179-9de2-6c206202e2ab');
    expect(decision.url.queryParameters['offset'], '-1');
    expect(decision.url.queryParameters['X-Plex-Client-Profile-Name'], 'Generic');
    expect(decision.url.queryParameters.containsKey('maxVideoBitrate'), isFalse);
    expect(s.method, PlayMethod.transcode);
    expect(s.uri.path, '/video/:/transcode/universal/start.m3u8');
    expect(s.uri.queryParameters['session'], s.transcodeSession);
    await c.liveTv.close(s);
    expect(requests.last.url.path, '/video/:/transcode/universal/stop');
    expect(requests.last.url.queryParameters['session'], s.transcodeSession);
  });

  test('a capped Linux tune copies through the decision with the cap', () async {
    final c = plex(server());
    final s = await c.liveTv.open('fake21.test', maxBitrate: 4000000);
    final decision = requests.singleWhere((r) => r.url.path.endsWith('/decision'));
    expect(decision.url.queryParameters['maxVideoBitrate'], '4000');
    expect(s.method, PlayMethod.directStream);
  });

  test("a tune Plex can't do says why", () async {
    final c = plex({
      ...server(),
      'POST /livetv/dvrs/2/channels/fake21.test/tune': (_) => {
            'MediaContainer': {'size': 0, 'message': 'Could not tune channel. All tuners are in use.', 'status': -1},
          },
    });
    expect(
        () => c.liveTv.open('fake21.test'),
        throwsA(isA<LiveTvException>()
            .having((e) => e.failure, 'failure', LiveFailure.tunersBusy)
            .having((e) => e.message, 'message', contains('Could not tune'))));
  });
}
