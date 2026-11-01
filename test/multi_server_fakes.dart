import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/server/media_server.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

/// A Jellyfin-like server for multi-server tests: serves [items] from one
/// "TV" library (and a "box" collection), logs every request, and can be
/// taken down or have its sign-in revoked.
class FakeServer {
  FakeServer(this.name,
      {required this.items, this.url = 'https://jf.example', this.serverId, this.collection = const []});

  final String name;
  final String url;
  final String? serverId;
  FakeItems items;

  /// The ids in the "box" collection.
  List<String> collection;

  /// Every request's path and query, in order.
  final requests = <String>[];
  bool down = false;
  bool revoked = false;

  ServerSession get session => ServerSession(
      serverUrl: url,
      serverName: name,
      userId: 'u',
      userName: 'tester',
      accessToken: 't-$name',
      deviceId: 'dev',
      serverId: serverId);

  late final client = _client();

  FakeClient _client() => FakeClient([], serverUrl: url, httpClient: MockClient(answer), userId: 'u', accessToken: 't-$name');

  Future<http.Response> answer(http.Request r) async {
    requests.add(r.url.toString().substring(url.length));
    if (down) throw http.ClientException('Connection refused');
    if (revoked) return http.Response('', 401);
    if (r.url.path == '/UserViews') {
      return http.Response(
          jsonEncode({
            'Items': [
              {'Id': 'tv', 'Name': 'TV Shows', 'CollectionType': 'tvshows'},
            ]
          }),
          200);
    }
    if (r.url.path == '/Users/AuthenticateByName') {
      return http.Response(
          jsonEncode({
            'AccessToken': 't-$name',
            'ServerId': serverId,
            'User': {'Id': 'u', 'Name': jsonDecode(r.body)['Username']},
          }),
          200);
    }
    if (r.url.path == '/QuickConnect/Enabled') return http.Response('false', 200);
    if (r.url.path == '/System/Info/Public') {
      return http.Response(jsonEncode({'ServerName': name, 'Version': '10.9', 'Id': serverId}), 200);
    }
    final q = r.url.queryParameters;
    final byId = {for (final i in [...items.episodes, ...items.movies]) i['Id']: i};
    final all = switch ((q['ParentId'], q['IncludeItemTypes'])) {
      ('tv', 'Series') => items.series,
      ('tv', 'Episode') => items.episodes,
      ('tv', 'Movie') => items.movies,
      ('box', _) => [for (final id in collection) ?byId[id]],
      _ => const <Map<String, Object?>>[],
    };
    return http.Response(jsonEncode({'Items': all, 'TotalRecordCount': all.length}), 200);
  }
}

/// [items] with every id given [prefix] (another server's own ids for the
/// same titles), and provider ids when [tvdb] is set.
FakeItems renamed(FakeItems items, String prefix) {
  Map<String, Object?> re(Map<String, Object?> i) => {
        ...i,
        'Id': '$prefix${i['Id']}',
        if (i['SeriesId'] != null) 'SeriesId': '$prefix${i['SeriesId']}',
      };
  return (
    series: [for (final i in items.series) re(i)],
    episodes: [for (final i in items.episodes) re(i)],
    movies: [for (final i in items.movies) re(i)],
    commercials: [for (final i in items.commercials) re(i)],
  );
}
