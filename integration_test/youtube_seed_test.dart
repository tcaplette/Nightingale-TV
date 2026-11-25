// Live checks on Android (youtube-subscriptions 9.2, 9.3): sets up the app's
// own data on the device: the test server signed in, then YouTube added with
// the refresh token from task 1.3, its picks made and fetched. On Android the
// token is encrypted with the Keystore inside the device, so it can't be
// copied in with run-as; this runs the app's own code there instead. After
// it, install the app built the same way (same key) and it opens on them.
// It reads the shared client from the bundled asset, as the app does.
//   flutter test integration_test/youtube_seed_test.dart -d <device> \
//     --dart-define=JF_SERVER=... \
//     --dart-define=JF_USER=... --dart-define=JF_PW=... \
//     --dart-define=YT_TOKEN=... --dart-define=YT_PICKS=UC…,UC…,first
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/youtube/google_sign_in.dart';
import 'package:nightingale_tv/server/youtube/youtube_api.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';

const _server = String.fromEnvironment('JF_SERVER');
const _user = String.fromEnvironment('JF_USER');
const _password = String.fromEnvironment('JF_PW');
const _token = String.fromEnvironment('YT_TOKEN');
const _picks = String.fromEnvironment('YT_PICKS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the test server and YouTube, on the device', (tester) async {
    await GoogleClient.loadShared();
    if (_server.isEmpty || _token.isEmpty || GoogleClient.shared == null) {
      markTestSkipped('Set JF_SERVER, JF_USER, JF_PW, YT_TOKEN and add ${GoogleClient.sharedAsset}.');
      return;
    }
    await tester.runAsync(() async {
      final household = Household(await AppStorage.open(), runAnalysis: false);
      await household.start();
      final app = household.app!;
      if (app.session == null) {
        final client = app.clientFor(ServerKind.jellyfin, _server) as JellyfinClient;
        final info = await client.publicInfo();
        await app.completeSignIn(await client.authenticateByName(_user, _password, serverName: info.name), client);
      }
      final shared = GoogleClient.shared!;
      final signIn = GoogleDeviceSignIn(shared);
      final tokens = await signIn.refresh(_token);
      final api = YouTubeApi(GoogleAuth(signIn, tokens), meter: app.youtube.meter);
      final sub = tokens.idToken == null ? 'live' : GoogleTokens.subjectOf(tokens.idToken!) ?? 'live';
      final session = ServerSession(
        kind: ServerKind.youtube,
        serverUrl: 'https://www.youtube.com',
        serverName: 'YouTube',
        serverId: 'yt:$sub',
        userId: sub,
        userName: await api.myChannelTitle() ?? 'YouTube account',
        accessToken: await app.youtube.saveTokens(tokens, shared),
        deviceId: app.settings.installId,
      );
      final server = await app.addServer(session, app.clientForSession(session, key: app.servers.peekKey()), refresh: false);
      final wanted = _picks.split(',');
      final subs = await api.subscriptions();
      await app.setYouTubePicks(
          server.key, [for (final s in subs) if (wanted.contains(s.channelId)) s, if (wanted.contains('first')) subs.first],
          refresh: false);
      await app.setServerColor(server.key, 'wine');
      await app.refreshLibrary(background: true);
      // ignore: avoid_print
      print('SEEDED ${[for (final c in app.youTubeChannels) '${c.number} ${c.name} (${c.playlist.length})']}');
      await app.storage.flush();
      expect(app.phase, AppPhase.ready);
      expect(app.youTubeChannels, isNotEmpty);
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}
