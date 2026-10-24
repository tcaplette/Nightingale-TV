// A tiny Jellyfin for the UI tests: libraries, a folder tree, the items of
// a fake library, and empty answers for everything else. Videos don't
// stream (404), so playback shows "No signal", as with no server at all.
import 'dart:convert';
import 'dart:io';

import '../test/fixtures.dart';

class FakeJellyfin {
  FakeJellyfin._(this._server, this.items, this.folders);

  /// The id `/System/Info/Public` reports.
  static const serverId = 'fake-server';

  /// Library ids.
  static const tvLibrary = 'tv';
  static const adsLibrary = 'ads';

  /// The folder inside the Commercials library holding [FakeItems.commercials].
  static const reelFolder = 'reels';

  final HttpServer _server;
  final FakeItems items;

  /// Folder-like items per library (the `/Items?IncludeItemTypes=Folder,…`
  /// listing).
  final Map<String, List<Map<String, Object?>>> folders;

  /// Paths asked for, e.g. to check what was scanned.
  final requests = <Uri>[];

  /// When true, every request fails (as if the server were down).
  bool down = false;

  /// The password `/Users/AuthenticateByName` takes (any user name).
  static const password = 'fake-password';

  /// The token a sign-in gets.
  static const accessToken = 'fake-access-token-0123456789';

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<FakeJellyfin> start(FakeItems items) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final folders = {
      adsLibrary: [
        {'Id': reelFolder, 'Name': '80s-2000s-commercial-compilation', 'Type': 'Folder', 'ParentId': 'root'},
        {'Id': 'bumpers', 'Name': 'Station bumpers', 'Type': 'Folder', 'ParentId': 'root'},
      ],
      tvLibrary: [
        {'Id': 'tv-root', 'Name': 'tv', 'Type': 'Folder', 'ParentId': 'root'},
        for (final s in items.series) {'Id': s['Id'], 'Name': s['Name'], 'Type': 'Series', 'ParentId': 'tv-root'},
      ],
    };
    final fake = FakeJellyfin._(server, items, folders);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> _handle(HttpRequest request) async {
    requests.add(request.uri);
    final response = request.response;
    void json(Object? body) {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
    }

    final q = request.uri.queryParameters;
    final path = request.uri.path;
    if (down) {
      response.statusCode = HttpStatus.serviceUnavailable;
    } else if (path == '/System/Info/Public') {
      json({'ServerName': 'Fake', 'Version': '10.11.11', 'ProductName': 'Jellyfin Server', 'Id': serverId});
    } else if (path == '/Users/AuthenticateByName' && request.method == 'POST') {
      final body = jsonDecode(await utf8.decodeStream(request)) as Map<String, Object?>;
      if (body['Pw'] == password) {
        json({'AccessToken': accessToken, 'User': {'Id': 'u1', 'Name': body['Username']}});
      } else {
        response.statusCode = HttpStatus.unauthorized;
      }
    } else if (path == '/QuickConnect/Enabled') {
      json(false);
    } else if (path == '/Users/Me') {
      json({'Id': 'u1', 'Name': 'tester'});
    } else if (path == '/UserViews') {
      json({
        'Items': [
          {'Id': adsLibrary, 'Name': 'Commercials', 'CollectionType': 'tvshows'},
          {'Id': tvLibrary, 'Name': 'TV Shows', 'CollectionType': 'tvshows'},
        ],
      });
    } else if (path == '/Items') {
      final list = _items(q['ParentId'] ?? '', (q['IncludeItemTypes'] ?? '').split(','));
      json({'Items': list, 'TotalRecordCount': list.length, 'StartIndex': 0});
    } else if (RegExp(r'^/Items/[^/]+/Images/(Logo|Primary)$').hasMatch(path)) {
      // A 1×1 PNG, only for a request with the sign-in.
      final auth = '${request.headers.value('authorization')} ${request.headers.value('x-emby-token')} ${q['api_key']}';
      if (auth.contains(accessToken)) {
        response.headers.contentType = ContentType('image', 'png');
        response.add(base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));
      } else {
        response.statusCode = HttpStatus.unauthorized;
      }
    } else if (path.startsWith('/Sessions')) {
      response.statusCode = HttpStatus.noContent;
    } else {
      // Media segments (none) and video streams (none).
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }

  List<Map<String, Object?>> _items(String parent, List<String> types) {
    if (types.contains('Folder')) return folders[parent] ?? const [];
    final everything = switch (parent) {
      adsLibrary || reelFolder => items.commercials,
      tvLibrary || 'tv-root' => [...items.series, ...items.episodes, ...items.movies],
      _ => const <Map<String, Object?>>[],
    };
    return [for (final i in everything) if (types.contains(i['Type'])) i];
  }

  Future<void> close() => _server.close(force: true);
}
