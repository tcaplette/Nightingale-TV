// Against the real YouTube Data API (youtube-subscriptions 1.4, 9.x): the
// filters on the test videos in test-data.md. Runs only with a refresh
// token and the shared client:
//   NTV_YOUTUBE_LIVE_TOKEN=<refresh token> flutter test test/youtube_live_api_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/youtube/google_sign_in.dart';
import 'package:nightingale_tv/server/youtube/youtube_api.dart';
import 'package:nightingale_tv/server/youtube/youtube_catalog.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';

void main() {
  final token = Platform.environment['NTV_YOUTUBE_LIVE_TOKEN'];
  final file = File(GoogleClient.sharedAsset);
  final skip = token == null || !file.existsSync() ? 'needs NTV_YOUTUBE_LIVE_TOKEN and the client file' : null;

  late YouTubeApi api;
  setUpAll(() {
    if (skip != null) return;
    final client = GoogleClient.fromDownload(jsonDecode(file.readAsStringSync()))!;
    final signIn = GoogleDeviceSignIn(GoogleClient(id: client.id, secret: client.secret), endpoints: GoogleEndpoints.google);
    api = YouTubeApi(
        GoogleAuth(signIn, GoogleTokens(accessToken: '', refreshToken: token!, expiresAt: DateTime(0))),
        endpoints: GoogleEndpoints.google);
  });

  test('the test videos: playable ones kept, the rest left out with the right reason', () async {
    final now = DateTime.now();
    final checks = await api.videos([
      'M7lc1UVf-VE', 'dQw4w9WgXcQ', 'LX0y0vofwTA', 'krmFCzTWrHc', 'JdaPtYNCE9Q', 'tj4knR4r1UU', 'deleted0000',
    ], now: now, dropShorts: true);
    String what(String id) => switch (checks[id]) {
          VideoPlayable() => 'playable',
          VideoLeftOut(:final reason) => reason,
          null => 'missing',
        };
    expect(what('M7lc1UVf-VE'), 'playable');
    expect(what('dQw4w9WgXcQ'), 'playable');
    expect(what('LX0y0vofwTA'), 'notEmbeddable');
    expect(what('krmFCzTWrHc'), 'ageRestricted');
    expect(what('JdaPtYNCE9Q'), 'short');
    expect(what('tj4knR4r1UU'), 'live');
    expect(what('deleted0000'), 'gone');
    expect(api.meter.today, 1);
  }, skip: skip);

  test('the account\'s subscriptions in title order, and a first fetch of one', () async {
    final subs = await api.subscriptions();
    expect(subs.length, greaterThan(50));
    final titles = [for (final s in subs) s.title.toLowerCase()];
    expect(titles, [...titles]..sort());
    final catalog = YouTubeCatalog();
    final pick = subs.first.channelId;
    await catalog.refresh(api, [pick], DateTime.now());
    final c = catalog.channels[pick]!;
    expect(c.uploadsOnly, isFalse, reason: 'the long-form list exists');
    expect(c.videos.length, lessThanOrEqualTo(YouTubeCatalog.maxVideos));
    for (var i = 1; i < c.videos.length; i++) {
      expect(c.videos[i - 1].published.isBefore(c.videos[i].published), isFalse, reason: 'newest first');
    }
    // ignore: avoid_print
    print('first fetch of 1 channel: ${c.videos.length} videos, ${api.meter.today} units today');
  }, skip: skip);
}
