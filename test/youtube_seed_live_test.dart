// Live checks (youtube-subscriptions 9.1, 9.2): adds YouTube to a copy of a
// signed-in profile with the refresh token from task 1.3, through the app's
// own code (secret store, Add a server, picks, scan), so later checks need
// no new google.com/device code. Runs only when asked:
//   NTV_YOUTUBE_LIVE_TOKEN=<refresh token> NTV_SEED_DATA=<app data folder> \
//   NTV_SEED_PICKS=UC…,UC… flutter test test/youtube_seed_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/youtube/google_sign_in.dart';
import 'package:nightingale_tv/server/youtube/youtube_api.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';

void main() {
  final env = Platform.environment;
  final token = env['NTV_YOUTUBE_LIVE_TOKEN'], data = env['NTV_SEED_DATA'], picks = env['NTV_SEED_PICKS'];
  final skip = token == null || data == null || picks == null ? 'a live seed only' : null;

  test('YouTube added with the 1.3 sign-in, its picks made and fetched', () async {
    final client = GoogleClient.fromDownload(jsonDecode(File(GoogleClient.sharedAsset).readAsStringSync()))!;
    final shared = GoogleClient(id: client.id, secret: client.secret);
    // The app reads the shared client from the build; this seed passes the
    // same one to the sign-in it saves.
    final household = Household(await AppStorage.at(Directory(data!)), runAnalysis: false);
    await household.start();
    await household.select(household.profiles.first);
    final app = household.app!;
    final signIn = GoogleDeviceSignIn(shared, endpoints: GoogleEndpoints.google);
    final tokens = await signIn.refresh(token!);
    final idToken = tokens.idToken;
    final api = YouTubeApi(GoogleAuth(signIn, tokens), endpoints: GoogleEndpoints.google, meter: app.youtube.meter);
    final subject = idToken == null ? null : GoogleTokens.subjectOf(idToken);
    final sub = subject ?? 'live';
    final ref = await app.youtube.saveTokens(tokens, shared);
    final session = ServerSession(
      kind: ServerKind.youtube,
      serverUrl: 'https://www.youtube.com',
      serverName: 'YouTube',
      serverId: 'yt:$sub',
      userId: sub,
      userName: await api.myChannelTitle() ?? 'YouTube account',
      accessToken: ref,
      deviceId: app.settings.installId,
    );
    final server = await app.addServer(session, app.clientForSession(session, key: app.servers.peekKey()), refresh: false);
    final wanted = picks!.split(',');
    final subs = await api.subscriptions();
    final chosen = [for (final s in subs) if (wanted.contains(s.channelId)) s];
    if (wanted.contains('first')) chosen.add(subs.first);
    await app.setYouTubePicks(server.key, chosen, refresh: false);
    await app.setServerColor(server.key, 'wine');
    await app.refreshLibrary(background: true);
    // ignore: avoid_print
    print('SEEDED ${server.key}: ${[for (final c in app.youTubeChannels) '${c.number} ${c.name} (${c.playlist.length})']}'
        ' units today ${app.youtube.meter.today}');
    await app.storage.flush();
    household.leave();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));
}
