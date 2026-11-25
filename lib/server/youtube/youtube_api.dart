import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../playback/playback_diagnostics.dart';
import 'google_sign_in.dart';

/// One of the account's subscriptions.
class YouTubeSubscription {
  const YouTubeSubscription({required this.channelId, required this.title, this.avatarUrl});

  final String channelId;
  final String title;
  final String? avatarUrl;

  Map<String, Object?> toJson() => {'id': channelId, 'title': title, 'avatar': ?avatarUrl};

  static YouTubeSubscription? fromJson(Object? j) => j is Map && j['id'] is String
      ? YouTubeSubscription(channelId: j['id'] as String, title: j['title'] as String? ?? '', avatarUrl: j['avatar'] as String?)
      : null;
}

/// A video as the catalog keeps it (D6).
class YouTubeVideo {
  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.length,
    required this.published,
    required this.fetchedAt,
    this.description = '',
    this.thumbnail,
  });

  final String id;
  final String title;
  final String description;
  final Duration length;
  final DateTime published;
  final String? thumbnail;

  /// When YouTube last said it may play (D6's refresh-or-delete rule).
  final DateTime fetchedAt;

  YouTubeVideo checkedAt(DateTime when) => YouTubeVideo(
      id: id, title: title, description: description, length: length, published: published, thumbnail: thumbnail, fetchedAt: when);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        if (description.isNotEmpty) 'description': description,
        'length': length.inSeconds,
        'published': published.toUtc().toIso8601String(),
        'thumb': ?thumbnail,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      };

  static YouTubeVideo? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    final published = DateTime.tryParse(j['published'] as String? ?? '');
    final fetched = DateTime.tryParse(j['fetchedAt'] as String? ?? '');
    if (published == null || fetched == null) return null;
    return YouTubeVideo(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      length: Duration(seconds: (j['length'] as num?)?.toInt() ?? 0),
      published: published,
      thumbnail: j['thumb'] as String?,
      fetchedAt: fetched,
    );
  }
}

/// What `videos.list` says of an id: playable here, or why not.
sealed class VideoCheck {
  const VideoCheck();
}

class VideoPlayable extends VideoCheck {
  const VideoPlayable(this.video);
  final YouTubeVideo video;
}

class VideoLeftOut extends VideoCheck {
  const VideoLeftOut(this.reason);

  /// `gone`, `private`, `live`, `notEmbeddable`, `ageRestricted`, `short`.
  final String reason;
}

/// YouTube's daily limit for this client is reached.
class YouTubeQuotaException implements Exception {
  const YouTubeQuotaException();
  @override
  String toString() => 'YouTubeQuotaException';
}

/// The API answered with something else (network, 5xx, a refused call).
class YouTubeApiException implements Exception {
  const YouTubeApiException(this.detail, {this.statusCode});
  final String detail;
  final int? statusCode;
  @override
  String toString() => 'YouTubeApiException($statusCode $detail)';
}

/// Units each call costs, as Google lists them, and today's total
/// (youtube-subscriptions 1.3/9.6: the in-app count the quota checks use).
class YouTubeQuotaMeter {
  YouTubeQuotaMeter({DateTime Function()? now, this.onCount}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// After each count (the profile saves the day's count).
  final void Function(YouTubeQuotaMeter meter)? onCount;

  /// Every list call the app makes costs 1 unit.
  static const unitsPerCall = 1;

  String? _day;
  int _today = 0;
  final calls = <String, int>{};

  int get today => _today;

  /// The quota day is Pacific time; UTC−8 is near enough to count.
  String _dayOf(DateTime t) => t.toUtc().subtract(const Duration(hours: 8)).toIso8601String().substring(0, 10);

  void count(String call) {
    final day = _dayOf(_now());
    if (day != _day) {
      _day = day;
      _today = 0;
      calls.clear();
    }
    _today += unitsPerCall;
    calls[call] = (calls[call] ?? 0) + unitsPerCall;
    PlaybackDiagnostics.note('YOUTUBE', 'units $call +$unitsPerCall today $_today');
    onCount?.call(this);
  }

  Map<String, Object?> toJson() => {'day': _day, 'today': _today, 'calls': calls};

  /// The day's count saved before this run, added to what this run has
  /// counted so far; another day's is dropped.
  void restore(Object? json) {
    if (json case {'day': final String day, 'today': final int today}) {
      final now = _dayOf(_now());
      if (day != now) return;
      if (_day != now) {
        _day = now;
        _today = 0;
        calls.clear();
      }
      _today += today;
      if (json['calls'] case final Map<String, Object?> saved) {
        for (final MapEntry(:key, :value) in saved.entries) {
          if (value is int) calls[key] = (calls[key] ?? 0) + value;
        }
      }
    }
  }
}

/// The YouTube Data API v3 for one signed-in account (D5, D6). Every call
/// is a list call of 1 unit; [meter] counts them.
class YouTubeApi {
  YouTubeApi(this.auth, {http.Client? httpClient, GoogleEndpoints? endpoints, YouTubeQuotaMeter? meter})
      : _http = httpClient ?? http.Client(),
        _endpoints = endpoints ?? GoogleEndpoints.current,
        meter = meter ?? YouTubeQuotaMeter();

  final GoogleAuth auth;
  final http.Client _http;
  final GoogleEndpoints _endpoints;
  final YouTubeQuotaMeter meter;

  static const _timeout = Duration(seconds: 20);

  /// A Short is at most 3 minutes (the `UU` fallback's rule, D6).
  static const shortLimit = Duration(minutes: 3);

  Future<Map<String, Object?>?> _get(String path, Map<String, String> query, {bool missingIsNull = false}) async {
    final uri = Uri.parse('${_endpoints.api}/youtube/v3/$path').replace(queryParameters: query);
    for (var attempt = 0; ; attempt++) {
      final token = await auth.accessToken(force: attempt > 0);
      meter.count(path);
      final http.Response response;
      try {
        response = await _http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(_timeout);
      } on Object catch (e) {
        throw YouTubeApiException(e.runtimeType.toString());
      }
      Object? json;
      try {
        json = jsonDecode(response.body);
      } on FormatException {
        json = null;
      }
      final map = json is Map<String, Object?> ? json : <String, Object?>{};
      if (response.statusCode == 200) return map;
      // An access token refused before its time: refresh it once.
      if (response.statusCode == 401 && attempt == 0) continue;
      final reasons = {
        for (final e in ((map['error'] as Map?)?['errors'] as List?) ?? const [])
          if (e is Map && e['reason'] is String) e['reason'] as String,
      };
      if (response.statusCode == 403 && reasons.any(const {'quotaExceeded', 'dailyLimitExceeded', 'rateLimitExceeded'}.contains)) {
        throw const YouTubeQuotaException();
      }
      if (response.statusCode == 404 && missingIsNull) return null;
      throw YouTubeApiException(reasons.join(','), statusCode: response.statusCode);
    }
  }

  /// The account's own YouTube channel title, for the server's user name;
  /// null when it has none.
  Future<String?> myChannelTitle() async {
    final json = await _get('channels', {'part': 'snippet', 'mine': 'true', 'maxResults': '1'});
    final items = json?['items'] as List? ?? const [];
    if (items.isEmpty) return null;
    return ((items.first as Map)['snippet'] as Map?)?['title'] as String?;
  }

  /// Every subscription of the signed-in account, in title order (one unit
  /// a page of 50).
  Future<List<YouTubeSubscription>> subscriptions() async {
    final result = <YouTubeSubscription>[];
    String? page;
    do {
      final json = await _get('subscriptions', {
        'part': 'snippet',
        'mine': 'true',
        'maxResults': '50',
        'order': 'alphabetical',
        'pageToken': ?page,
      });
      for (final item in (json?['items'] as List? ?? const []).whereType<Map>()) {
        final snippet = item['snippet'] as Map? ?? const {};
        final id = (snippet['resourceId'] as Map?)?['channelId'] as String?;
        if (id == null) continue;
        result.add(YouTubeSubscription(channelId: id, title: snippet['title'] as String? ?? id, avatarUrl: _thumb(snippet)));
      }
      page = json?['nextPageToken'] as String?;
    } while (page != null);
    result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return result;
  }

  /// Picked channels' current names and avatars (one unit for 50).
  Future<Map<String, ({String title, String? avatar})>> channels(List<String> ids) async {
    final result = <String, ({String title, String? avatar})>{};
    for (var i = 0; i < ids.length; i += 50) {
      final chunk = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
      final json = await _get('channels', {'part': 'snippet', 'id': chunk.join(','), 'maxResults': '50'});
      for (final item in (json?['items'] as List? ?? const []).whereType<Map>()) {
        final id = item['id'] as String?;
        final snippet = item['snippet'] as Map? ?? const {};
        if (id != null) result[id] = (title: snippet['title'] as String? ?? id, avatar: _thumb(snippet));
      }
    }
    return result;
  }

  /// The long-form uploads playlist (D6): `UULF` + the channel id after
  /// `UC`, which holds uploads without Shorts and live streams.
  static String longFormPlaylist(String channelId) => 'UULF${channelId.substring(2)}';

  /// The whole uploads playlist, the fallback when [longFormPlaylist] is
  /// missing: Shorts are then left out by length.
  static String uploadsPlaylist(String channelId) => 'UU${channelId.substring(2)}';

  /// One page of [playlistId]'s video ids, newest first; null when the
  /// playlist doesn't exist.
  Future<({List<String> ids, String? next})?> playlistPage(String playlistId, {String? page}) async {
    final json = await _get(
        'playlistItems',
        {
          'part': 'contentDetails',
          'playlistId': playlistId,
          'maxResults': '50',
          'pageToken': ?page,
        },
        missingIsNull: true);
    if (json == null) return null;
    return (
      ids: [
        for (final item in (json['items'] as List? ?? const []).whereType<Map>())
          if ((item['contentDetails'] as Map?)?['videoId'] case final String id) id
      ],
      next: json['nextPageToken'] as String?,
    );
  }

  /// What YouTube says of each of [ids] (at most 50 a call): playable here,
  /// or left out and why. An id YouTube no longer lists is `gone`.
  /// [dropShorts]: the `UU` fallback, where 3 minutes or less is a Short.
  Future<Map<String, VideoCheck>> videos(List<String> ids, {required DateTime now, bool dropShorts = false}) async {
    final result = <String, VideoCheck>{};
    for (var i = 0; i < ids.length; i += 50) {
      final chunk = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
      final json = await _get('videos', {'part': 'contentDetails,status,snippet', 'id': chunk.join(','), 'maxResults': '50'});
      for (final item in (json?['items'] as List? ?? const []).whereType<Map>()) {
        final id = item['id'] as String?;
        if (id == null) continue;
        result[id] = check(item, now: now, dropShorts: dropShorts);
      }
      for (final id in chunk) {
        result.putIfAbsent(id, () => const VideoLeftOut('gone'));
      }
    }
    return result;
  }

  /// D6's filters on one `videos.list` item.
  static VideoCheck check(Map item, {required DateTime now, bool dropShorts = false}) {
    final snippet = item['snippet'] as Map? ?? const {};
    final status = item['status'] as Map? ?? const {};
    final details = item['contentDetails'] as Map? ?? const {};
    if (status['privacyStatus'] != 'public') return const VideoLeftOut('private');
    if ((snippet['liveBroadcastContent'] ?? 'none') != 'none') return const VideoLeftOut('live');
    if (status['embeddable'] != true) return const VideoLeftOut('notEmbeddable');
    if ((details['contentRating'] as Map?)?['ytRating'] == 'ytAgeRestricted') return const VideoLeftOut('ageRestricted');
    final length = parseDuration(details['duration'] as String?);
    if (length == null || length == Duration.zero) return const VideoLeftOut('live');
    if (dropShorts && length <= shortLimit) return const VideoLeftOut('short');
    final published = DateTime.tryParse(snippet['publishedAt'] as String? ?? '') ?? now;
    return VideoPlayable(YouTubeVideo(
      id: item['id'] as String,
      title: snippet['title'] as String? ?? '',
      description: snippet['description'] as String? ?? '',
      length: length,
      published: published,
      thumbnail: _thumb(snippet),
      fetchedAt: now,
    ));
  }

  /// ISO 8601 durations as YouTube writes them (`PT1H2M3S`, `P1DT2H`).
  static Duration? parseDuration(String? text) {
    if (text == null) return null;
    final m = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$').firstMatch(text);
    if (m == null) return null;
    int n(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    return Duration(days: n(1), hours: n(2), minutes: n(3), seconds: n(4));
  }

  static String? _thumb(Map snippet) {
    final thumbs = snippet['thumbnails'] as Map? ?? const {};
    for (final size in const ['high', 'medium', 'default']) {
      final url = (thumbs[size] as Map?)?['url'];
      if (url is String) return url;
    }
    return null;
  }

  void close() => _http.close();
}
