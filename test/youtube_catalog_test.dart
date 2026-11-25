import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/server/youtube/google_sign_in.dart';
import 'package:nightingale_tv/server/youtube/youtube_api.dart';
import 'package:nightingale_tv/server/youtube/youtube_catalog.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';

import '../integration_test/fake_google.dart';

/// A signed-in [YouTubeApi] on [google] for account [sub].
Future<YouTubeApi> signedInApi(FakeGoogle google, String sub, {DateTime Function()? now}) async {
  final endpoints = GoogleEndpoints(oauth: google.url, api: google.url);
  final signIn = GoogleDeviceSignIn(const GoogleClient(id: 'shared-client', secret: 'shared-client-secret'),
      endpoints: endpoints, now: now, delay: (_) async {});
  google.approveAs = sub;
  final tokens = (await signIn.waitForTokens(await signIn.requestCode()))!;
  return YouTubeApi(GoogleAuth(signIn, tokens, now: now), endpoints: endpoints);
}

void main() {
  late FakeGoogle google;
  late YouTubeApi api;
  var clock = DateTime.utc(2026, 11, 23, 12);
  DateTime now() => clock;

  setUp(() async {
    clock = DateTime.utc(2026, 11, 23, 12);
    google = await FakeGoogle.start();
    google.channels['UCcook'] = FakeChannel('UCcook', 'Cooking Corner', videos: [
      FakeVideo('long1', published: DateTime.utc(2026, 11, 20)),
      FakeVideo('short1', short: true, length: const Duration(seconds: 40), published: DateTime.utc(2026, 11, 19)),
      FakeVideo('live1', live: 'live', published: DateTime.utc(2026, 11, 18)),
      FakeVideo('private1', privacy: 'unlisted', published: DateTime.utc(2026, 11, 17)),
      FakeVideo('age1', ageRestricted: true, published: DateTime.utc(2026, 11, 16)),
      FakeVideo('noembed1', embeddable: false, published: DateTime.utc(2026, 11, 15)),
      FakeVideo('long2', published: DateTime.utc(2026, 11, 14)),
    ]);
    google.channels['UCold'] = FakeChannel('UCold', 'Old Channel', longForm: false, videos: [
      FakeVideo('tiny', length: const Duration(minutes: 2), published: DateTime.utc(2026, 11, 2)),
      FakeVideo('edge', length: const Duration(minutes: 3), published: DateTime.utc(2026, 11, 3)),
      FakeVideo('ok', length: const Duration(minutes: 3, seconds: 1), published: DateTime.utc(2026, 11, 1)),
    ]);
    google.channels['UCbig'] = FakeChannel('UCbig', 'Big', videos: [
      for (var i = 0; i < 450; i++) FakeVideo('big$i', published: DateTime.utc(2026, 11, 1).subtract(Duration(hours: i))),
    ]);
    google.accounts['sub-mom'] = FakeAccount('sub-mom', title: 'Mom', subscriptions: ['UCold', 'UCcook', 'UCbig']);
    google.accounts['sub-sam'] = FakeAccount('sub-sam', subscriptions: ['UCbig']);
    api = await signedInApi(google, 'sub-mom', now: now);
  });
  tearDown(() => google.close());

  test('subscriptions in title order, only the signed-in account\'s', () async {
    final subs = await api.subscriptions();
    expect([for (final s in subs) s.title], ['Big', 'Cooking Corner', 'Old Channel']);
    expect(subs.first.avatarUrl, contains('UCbig'));
    final sam = await signedInApi(google, 'sub-sam', now: now);
    expect([for (final s in await sam.subscriptions()) s.channelId], ['UCbig']);
    expect(await api.myChannelTitle(), 'Mom');
    expect(await sam.myChannelTitle(), isNull);
  });

  test('the long-form list leaves out Shorts, live, private, age-restricted and non-embeddable videos', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCcook'], clock);
    final c = catalog.channels['UCcook']!;
    expect([for (final v in c.videos) v.id], ['long1', 'long2']);
    expect(c.uploadsOnly, isFalse);
    expect(c.title, 'Cooking Corner');
    expect(c.leftOut.keys, containsAll(['private1', 'age1', 'noembed1']));
    // Shorts and live never reach videos.list on the long-form list.
    expect(google.requests.any((r) => r.contains('short1')), isFalse);
  });

  test('without a long-form list, the uploads with 3 minutes or less left out as Shorts', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCold'], clock);
    final c = catalog.channels['UCold']!;
    expect(c.uploadsOnly, isTrue);
    expect([for (final v in c.videos) v.id], ['ok']);
  });

  test('first fetch: 200 videos at most, in at most 8 pages, 16 units a channel at most', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCbig'], clock);
    expect(catalog.channels['UCbig']!.videos.length, 200);
    expect(catalog.channels['UCbig']!.videos.first.id, 'big0');
    expect(google.units['playlistItems'], 4);
    expect(google.units['videos'], 4);
    expect(google.units['channels'], 1);
    expect(api.meter.today, google.unitTotal);
  });

  test('a refresh: one page and one details call a channel, new videos only, every 6 hours', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCcook'], clock);
    expect(catalog.due(clock, ['UCcook']), isFalse);
    google.units.clear();
    google.channels['UCcook']!.videos.insert(0, FakeVideo('new1', published: DateTime.utc(2026, 11, 23)));
    clock = clock.add(const Duration(hours: 5, minutes: 59));
    expect(catalog.due(clock, ['UCcook']), isFalse);
    clock = clock.add(const Duration(minutes: 1));
    expect(catalog.due(clock, ['UCcook']), isTrue);
    await catalog.refresh(api, ['UCcook'], clock);
    expect([for (final v in catalog.channels['UCcook']!.videos) v.id], ['new1', 'long1', 'long2']);
    expect(google.units, {'channels': 1, 'playlistItems': 1, 'videos': 1});
    // Only the new id was asked about.
    expect(google.requests.last, contains('id=new1&'));
    // A new pick is due at once.
    expect(catalog.due(clock, ['UCcook', 'UCold']), isTrue);
  });

  test('videos are re-checked after 25 days; a gone or now non-embeddable one is dropped', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCcook'], clock);
    clock = clock.add(const Duration(days: 25));
    google.channels['UCcook']!.videos.firstWhere((v) => v.id == 'long2').embeddable = false;
    await catalog.refresh(api, ['UCcook'], clock);
    final c = catalog.channels['UCcook']!;
    expect([for (final v in c.videos) v.id], ['long1']);
    expect(c.videos.single.fetchedAt, clock);
  });

  test('30 days without a refresh deletes the data even with no request', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCcook'], clock);
    expect(catalog.purge(clock.add(const Duration(days: 29, hours: 23))), isFalse);
    expect(catalog.purge(clock.add(const Duration(days: 30))), isTrue);
    expect(catalog.channels['UCcook']!.videos, isEmpty);
    expect(catalog.entries(), isEmpty);
  });

  test('videos the player refused leave at the next refresh', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCcook'], clock);
    catalog.refused.add('long1');
    clock = clock.add(const Duration(hours: 6));
    await catalog.refresh(api, ['UCcook'], clock);
    expect([for (final v in catalog.channels['UCcook']!.videos) v.id], ['long2']);
    expect(catalog.refused, isEmpty);
  });

  test('the daily limit is a quota exception, and unpicked channels leave', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCcook', 'UCold'], clock);
    google.quotaExceeded = true;
    await expectLater(catalog.refresh(api, ['UCcook'], clock), throwsA(isA<YouTubeQuotaException>()));
    expect(catalog.channels.keys, ['UCcook']);
  });

  test('catalog entries are YouTube videos of their channel, and the file round-trips', () async {
    final catalog = YouTubeCatalog();
    await catalog.refresh(api, ['UCcook'], clock);
    final entries = catalog.entries();
    expect(entries.map((e) => e.kind).toSet(), {MediaKind.youtubeVideo});
    expect(entries.first.seriesKey, 'yt:UCcook');
    expect(entries.first.seriesName, 'Cooking Corner');
    expect(entries.first.runtime, const Duration(minutes: 12));
    expect(entries.first.added, DateTime.utc(2026, 11, 20));
    final again = YouTubeCatalog.fromJson(catalog.toJson());
    expect(again.toJson(), catalog.toJson());
    expect(catalog.thumbnailOf('long1'), 'https://i.ytimg.com/vi/long1/hqdefault.jpg');
  });

  test('ISO 8601 lengths', () {
    expect(YouTubeApi.parseDuration('PT1H2M3S'), const Duration(hours: 1, minutes: 2, seconds: 3));
    expect(YouTubeApi.parseDuration('PT45S'), const Duration(seconds: 45));
    expect(YouTubeApi.parseDuration('P1DT2H'), const Duration(days: 1, hours: 2));
    expect(YouTubeApi.parseDuration('P0D'), Duration.zero);
    expect(YouTubeApi.parseDuration('soon'), isNull);
  });
}
