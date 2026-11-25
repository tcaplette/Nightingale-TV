// The profile's YouTube unit count (youtube-subscriptions 9.6): kept for the
// Pacific day across restarts, and gone with the last YouTube sign-in.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/smb/secret_store.dart';
import 'package:nightingale_tv/server/youtube/youtube_server.dart';

void main() {
  late Directory dir;
  // 10:00 Pacific on 23 November.
  var now = DateTime.utc(2026, 11, 23, 18);

  setUp(() => dir = Directory.systemTemp.createTempSync('youtube_units'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<YouTubeProfile> profile() async {
    final storage = await AppStorage.at(dir);
    return YouTubeProfile(storage, SecretStore(storage), picksOf: (_) => const [], now: () => now);
  }

  test('a restart the same Pacific day goes on counting; the next day starts again', () async {
    final first = await profile();
    first.meter
      ..count('subscriptions')
      ..count('subscriptions')
      ..count('videos');
    await first.meterSettled;

    final second = await profile();
    second.meter.count('playlistItems');
    await second.meterSettled;
    expect(second.meter.today, 4);
    expect(second.meter.calls, {'subscriptions': 2, 'videos': 1, 'playlistItems': 1});

    // 00:30 Pacific the next day.
    now = DateTime.utc(2026, 11, 24, 8, 30);
    final third = await profile();
    third.meter.count('videos');
    await third.meterSettled;
    expect(third.meter.today, 1);
    expect(third.meter.calls, {'videos': 1});
  });

  test('removing the last YouTube sign-in leaves no youtube folder, count included', () async {
    final p = await profile();
    p.meter.count('subscriptions');
    await p.meterSettled;
    Directory('${dir.path}/youtube/s2').createSync(recursive: true);
    File('${dir.path}/youtube/s2/catalog.json').writeAsStringSync('{}');
    Directory('${dir.path}/youtube/s3').createSync(recursive: true);
    const session = ServerSession(
        kind: ServerKind.youtube, serverUrl: 'https://www.youtube.com', serverName: 'YouTube',
        serverId: 'yt:1', userId: '1', userName: 'A', accessToken: 'none', deviceId: 'd');
    await p.forget(session, 's2');
    expect(File('${dir.path}/youtube/units.json').existsSync(), isTrue, reason: 's3 is still signed in');
    await p.forget(session, 's3');
    expect(Directory('${dir.path}/youtube').existsSync(), isFalse);
  });
}
