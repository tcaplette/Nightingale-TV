// A fake Google for the YouTube tests (youtube-subscriptions): the device
// sign-in, token refresh and revoke, and the YouTube Data API's
// channels, subscriptions, playlistItems and videos lists, with quota
// errors on demand. Serves both GoogleEndpoints.oauth and .api.
import 'dart:convert';
import 'dart:io';

class FakeVideo {
  FakeVideo(
    this.id, {
    this.title,
    this.length = const Duration(minutes: 12),
    DateTime? published,
    this.embeddable = true,
    this.privacy = 'public',
    this.live = 'none',
    this.ageRestricted = false,
    this.short = false,
  }) : published = published ?? DateTime.utc(2026, 11, 1);

  final String id;
  final String? title;
  Duration length;
  final DateTime published;
  bool embeddable;
  String privacy;
  String live;
  bool ageRestricted;

  /// In `UU` but not in `UULF` (a Short or a live stream).
  final bool short;

  /// Listed by `videos.list`; false once deleted.
  bool exists = true;

  Map<String, Object?> json() => {
        'id': id,
        'snippet': {
          'title': title ?? 'Video $id',
          'description': 'About $id',
          'publishedAt': published.toIso8601String(),
          'liveBroadcastContent': live,
          'thumbnails': {
            'high': {'url': 'https://i.ytimg.com/vi/$id/hqdefault.jpg'}
          },
        },
        'contentDetails': {
          'duration': 'PT${length.inHours}H${length.inMinutes % 60}M${length.inSeconds % 60}S',
          if (ageRestricted) 'contentRating': {'ytRating': 'ytAgeRestricted'},
        },
        'status': {'privacyStatus': privacy, 'embeddable': embeddable},
      };
}

class FakeChannel {
  FakeChannel(this.id, this.title, {List<FakeVideo>? videos, this.longForm = true}) : videos = videos ?? [];

  /// `UC…`.
  final String id;
  final String title;

  /// Newest first, as YouTube lists uploads.
  final List<FakeVideo> videos;

  /// Whether the channel has a `UULF` playlist.
  bool longForm;
}

class FakeAccount {
  FakeAccount(this.sub, {this.title, List<String>? subscriptions}) : subscriptions = subscriptions ?? [];
  final String sub;
  final String? title;

  /// Channel ids the account subscribes to.
  final List<String> subscriptions;
}

class FakeGoogle {
  FakeGoogle._(this._server) {
    _server.listen(_handle);
  }

  final HttpServer _server;

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<FakeGoogle> start() async => FakeGoogle._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  /// On [port] of every address, for an emulator (10.0.2.2) or the app
  /// built with NTV_GOOGLE_FAKE (tool/fake_google_server.dart).
  static Future<FakeGoogle> startOn(int port) async => FakeGoogle._(await HttpServer.bind(InternetAddress.anyIPv4, port));

  Future<void> close() => _server.close(force: true);

  /// Client ids Google accepts; any other is `invalid_client`.
  final clients = <String>{'shared-client', 'own-client'};

  /// A client's secret where it isn't `<id>-secret` (a real client file).
  final clientSecrets = <String, String>{};

  final accounts = <String, FakeAccount>{};
  final channels = <String, FakeChannel>{};

  /// Every request, as `METHOD path?query`.
  final requests = <String>[];

  /// Data API requests per path (`subscriptions`, `videos`…), each a unit.
  final units = <String, int>{};

  int get unitTotal => units.values.fold(0, (a, b) => a + b);

  /// The Data API answers 403 quotaExceeded while true.
  bool quotaExceeded = false;

  /// How the next device code ends: the account that allows it, or null
  /// (Deny) once [deny] is set.
  String? approveAs;
  bool deny = false;

  /// The first poll answers slow_down.
  bool slowDownOnce = false;

  /// What the next sign-in grants (YouTube's box can be left unticked).
  String grantedScope = 'openid https://www.googleapis.com/auth/youtube.readonly';

  /// Codes expire this soon.
  Duration codeLife = const Duration(minutes: 30);

  int _seq = 0;
  final _codes = <String, ({String client, DateTime expires})>{};

  /// Refresh token → (account, client); gone once revoked.
  final refreshTokens = <String, ({String sub, String client})>{};
  final _access = <String, String>{};
  final revoked = <String>[];

  /// Revokes every token of [sub] on Google's side (myaccount.google.com).
  void revokeAccount(String sub) => refreshTokens.removeWhere((_, v) => v.sub == sub);

  static String _idToken(String sub) {
    String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    return '${b64({'alg': 'none'})}.${b64({'sub': sub, 'iss': 'https://accounts.google.com'})}.sig';
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    requests.add('${req.method} $path${req.uri.hasQuery ? '?${req.uri.query}' : ''}');
    try {
      if (req.method == 'POST') {
        final form = Uri.splitQueryString(await utf8.decodeStream(req));
        switch (path) {
          case '/device/code':
            return _deviceCode(req, form);
          case '/token':
            return _token(req, form);
          case '/revoke':
            final token = form['token'];
            // As Google: the whole grant ends, every token of that account
            // and client.
            final grant = token == null ? null : refreshTokens.remove(token);
            if (token != null && grant != null) {
              refreshTokens.removeWhere((_, v) => v == grant);
              revoked.add(token);
              return _json(req, 200, {});
            }
            return _json(req, 400, {'error': 'invalid_token'});
        }
      } else if (path.startsWith('/youtube/v3/')) {
        return _api(req, path.substring('/youtube/v3/'.length));
      }
      return _json(req, 404, {'error': 'not_found'});
    } on Object catch (e) {
      return _json(req, 500, {'error': '$e'});
    }
  }

  void _deviceCode(HttpRequest req, Map<String, String> form) {
    if (!clients.contains(form['client_id'])) return _json(req, 401, {'error': 'invalid_client'});
    final code = 'device-${++_seq}';
    _codes[code] = (client: form['client_id']!, expires: DateTime.now().add(codeLife));
    _json(req, 200, {
      'device_code': code,
      'user_code': 'ABC-DEF-${_seq.toString().padLeft(3, '0')}',
      'verification_url': 'https://www.google.com/device',
      'expires_in': codeLife.inSeconds,
      'interval': 1,
    });
  }

  void _token(HttpRequest req, Map<String, String> form) {
    final client = form['client_id'];
    if (!clients.contains(client) || form['client_secret'] != (clientSecrets[client] ?? '$client-secret')) {
      return _json(req, 401, {'error': 'invalid_client'});
    }
    if (form['grant_type'] == 'refresh_token') {
      final owner = refreshTokens[form['refresh_token']];
      if (owner == null || owner.client != client) return _json(req, 400, {'error': 'invalid_grant'});
      return _json(req, 200, {'access_token': _newAccess(owner.sub), 'expires_in': 3599, 'token_type': 'Bearer'});
    }
    final code = _codes[form['device_code']];
    if (code == null) return _json(req, 400, {'error': 'invalid_grant'});
    if (DateTime.now().isAfter(code.expires)) return _json(req, 428, {'error': 'expired_token'});
    if (slowDownOnce) {
      slowDownOnce = false;
      return _json(req, 428, {'error': 'slow_down'});
    }
    if (deny) return _json(req, 403, {'error': 'access_denied'});
    final sub = approveAs;
    if (sub == null) return _json(req, 428, {'error': 'authorization_pending'});
    _codes.remove(form['device_code']);
    final refresh = 'refresh-${++_seq}';
    refreshTokens[refresh] = (sub: sub, client: code.client);
    _json(req, 200, {
      'access_token': _newAccess(sub),
      'refresh_token': refresh,
      'expires_in': 3599,
      'id_token': _idToken(sub),
      'scope': grantedScope,
      'token_type': 'Bearer',
    });
  }

  String _newAccess(String sub) {
    final token = 'access-${++_seq}';
    _access[token] = sub;
    return token;
  }

  void _api(HttpRequest req, String call) {
    final auth = req.headers.value('authorization') ?? '';
    final sub = _access[auth.replaceFirst('Bearer ', '')];
    if (sub == null || !refreshTokens.values.any((t) => t.sub == sub)) {
      return _json(req, 401, {'error': {'code': 401, 'errors': [{'reason': 'authError'}]}});
    }
    units[call] = (units[call] ?? 0) + 1;
    if (quotaExceeded) {
      return _json(req, 403, {'error': {'code': 403, 'errors': [{'reason': 'quotaExceeded'}]}});
    }
    final q = req.uri.queryParameters;
    final account = accounts[sub]!;
    final page = int.tryParse(q['pageToken'] ?? '') ?? 0;
    final size = int.tryParse(q['maxResults'] ?? '') ?? 5;
    Map<String, Object?> paged(List<Object?> all) => {
          'items': all.skip(page * size).take(size).toList(),
          if ((page + 1) * size < all.length) 'nextPageToken': '${page + 1}',
          'pageInfo': {'totalResults': all.length},
        };
    switch (call) {
      case 'channels':
        if (q['mine'] == 'true') {
          return _json(req, 200, {
            'items': [
              if (account.title != null)
                {
                  'id': 'UC-$sub',
                  'snippet': {'title': account.title}
                }
            ]
          });
        }
        return _json(req, 200, {
          'items': [
            for (final id in (q['id'] ?? '').split(','))
              if (channels[id] case final c?)
                {
                  'id': id,
                  'snippet': {
                    'title': c.title,
                    'thumbnails': {
                      'default': {'url': 'https://yt3.ggpht.com/$id=s88'}
                    },
                  }
                }
          ]
        });
      case 'subscriptions':
        return _json(req, 200, paged([
          for (final id in account.subscriptions)
            {
              'snippet': {
                'title': channels[id]!.title,
                'resourceId': {'kind': 'youtube#channel', 'channelId': id},
                'thumbnails': {
                  'default': {'url': 'https://yt3.ggpht.com/$id=s88'}
                },
              }
            }
        ]));
      case 'playlistItems':
        final list = q['playlistId'] ?? '';
        final longForm = list.startsWith('UULF');
        final channel = channels['UC${list.substring(longForm ? 4 : 2)}'];
        if (channel == null || (longForm && !channel.longForm)) {
          return _json(req, 404, {'error': {'code': 404, 'errors': [{'reason': 'playlistNotFound'}]}});
        }
        return _json(req, 200, paged([
          for (final v in channel.videos)
            if (!longForm || (!v.short && v.live == 'none'))
              {
                'contentDetails': {'videoId': v.id, 'videoPublishedAt': v.published.toIso8601String()}
              }
        ]));
      case 'videos':
        final ids = (q['id'] ?? '').split(',');
        final all = {for (final c in channels.values) for (final v in c.videos) v.id: v};
        return _json(req, 200, {
          'items': [for (final id in ids) if (all[id] case final v? when v.exists) v.json()]
        });
    }
    _json(req, 404, {'error': {'code': 404}});
  }

  void _json(HttpRequest req, int status, Object body) {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    req.response.close();
  }
}
