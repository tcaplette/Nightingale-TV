import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/server/youtube/google_sign_in.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';

import '../integration_test/fake_google.dart';
import 'fixtures.dart';

const own = GoogleClient(id: 'own-client', secret: 'own-client-secret', own: true);

void main() {
  late Directory dir;
  late FakeGoogle google;
  late AppState app;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('youtube_flow');
    google = await FakeGoogle.start();
    GoogleEndpoints.override = GoogleEndpoints(oauth: google.url, api: google.url);
    google.channels['UCa'] = FakeChannel('UCa', 'Apples', videos: [FakeVideo('a1')]);
    google.channels['UCb'] = FakeChannel('UCb', 'Bananas', videos: [FakeVideo('b1')]);
    google.accounts['mom'] = FakeAccount('mom', title: 'Mom', subscriptions: ['UCb', 'UCa']);
    app = await signedInApp(dir, fakeLibrary());
  });

  tearDown(() async {
    // A refresh the picks started finishes before the folder goes.
    for (var i = 0; i < 500 && app.refreshing; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await app.close();
    await google.close();
    GoogleEndpoints.override = null;
    dir.deleteSync(recursive: true);
  });

  SignInFlow flow({bool adding = true, String? againKey}) =>
      SignInFlow(app, adding: adding, againKey: againKey)..googleDelay = (_) async => Future<void>.delayed(Duration.zero);

  Future<void> until(SignInFlow f, bool Function(SignInStep s) done) async {
    for (var i = 0; i < 200 && !done(f.step); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(f.step), isTrue, reason: 'stage ${f.step.stage} error ${f.step.error}');
  }

  test('a build without a client: YouTube stays on the connect step and says so, never the own-client screen', () async {
    final f = flow();
    expect(GoogleClient.shared, isNull);
    final before = f.step.stage;
    await f.startYouTube();
    expect(f.step.stage, before);
    expect(f.step.stage, isNot(SignInStage.youtubeClient));
    expect(f.step.error, 'This build has no YouTube client. Its README says how to add one.');
    f.dispose();
  });

  test('with Nightingale TV\'s client, Add a server → YouTube shows the code, never the own-client screen', () async {
    GoogleClient.sharedOverride = const GoogleClient(id: 'shared-client', secret: 'shared-client-secret');
    addTearDown(() => GoogleClient.sharedOverride = null);
    final f = flow();
    final stages = <SignInStage>[];
    void seen() => stages.add(f.step.stage);
    f.state.addListener(seen);
    await f.startYouTube();
    f.state.removeListener(seen);
    expect(f.step.stage, SignInStage.youtubeCode);
    expect(f.step.youtube.code!.userCode, isNotEmpty);
    expect(stages, isNot(contains(SignInStage.youtubeClient)));
    f.dispose();
  });

  test('Nightingale TV\'s client refused by Google: the message on the connect step, not the own-client screen',
      () async {
    GoogleClient.sharedOverride = const GoogleClient(id: 'retired-client', secret: 'x');
    addTearDown(() => GoogleClient.sharedOverride = null);
    final f = flow();
    final before = f.step.stage;
    await f.startYouTube();
    expect(f.step.stage, before);
    expect(f.step.error, contains('TVs and Limited Input devices'));
    f.dispose();
  });

  test('Servers → YouTube → Google client still opens the own-client screen', () async {
    GoogleClient.sharedOverride = const GoogleClient(id: 'shared-client', secret: 'shared-client-secret');
    addTearDown(() => GoogleClient.sharedOverride = null);
    final f = flow(adding: false);
    f.showGoogleClient();
    expect(f.step.stage, SignInStage.youtubeClient);
    f.dispose();
  });

  test('Add a server → YouTube: the code, the picker in title order, Done adds it with its channels, then the colour', () async {
    final f = flow();
    await f.startYouTube(client: own);
    expect(f.step.stage, SignInStage.youtubeCode);
    expect(f.step.youtube.code!.userCode, isNotEmpty);
    expect(f.step.kind, ServerKind.youtube);
    google.approveAs = 'mom';
    await until(f, (s) => s.stage == SignInStage.youtubePicker);
    expect([for (final s in f.step.youtube.subscriptions!) s.title], ['Apples', 'Bananas']);
    await f.youTubePicked([f.step.youtube.subscriptions!.first]);
    final yt = app.servers.added.single;
    expect(yt.kind, ServerKind.youtube);
    expect(yt.session!.clientId, own.id);
    expect(app.youTubeChannels.single.name, 'Apples');
    if (app.guideColorsOn) {
      expect(f.step.stage, SignInStage.color);
      expect(f.step.colorKey, yt.key);
      expect(app.serverColors[yt.key]?.name, 'wine');
    }
    f.dispose();
  });

  test('Deny on Google\'s page: back at the connect step with "Sign-in was cancelled", nothing added', () async {
    final f = flow();
    await f.startYouTube(client: own);
    google.deny = true;
    await until(f, (s) => s.stage == SignInStage.server);
    expect(f.step.error, 'Sign-in was cancelled');
    expect(app.servers.added, isEmpty);
    f.dispose();
  });

  test('an expired code is replaced without leaving the step', () async {
    google.codeLife = const Duration(milliseconds: 1);
    final f = flow();
    await f.startYouTube(client: own);
    final first = f.step.youtube.code!.userCode;
    google.codeLife = const Duration(minutes: 30);
    await until(f, (s) => s.youtube.code != null && s.youtube.code!.userCode != first);
    expect(f.step.stage, SignInStage.youtubeCode);
    f.dispose();
  });

  test('YouTube\'s box left unticked on Google\'s page: revoked, and a new code with why', () async {
    google.grantedScope = 'openid';
    final f = flow();
    await f.startYouTube(client: own);
    final first = f.step.youtube.code!.userCode;
    // The partial grant once; the new code then waits for the user.
    void stop() {
      if (f.step.error != null) google.approveAs = null;
    }
    f.state.addListener(stop);
    google.approveAs = 'mom';
    await until(f, (s) => s.error != null);
    f.state.removeListener(stop);
    expect(f.step.stage, SignInStage.youtubeCode);
    expect(f.step.youtube.code!.userCode, isNot(first));
    expect(f.step.error, contains('needs to see your YouTube subscriptions'));
    expect(google.revoked, hasLength(1));
    expect(app.servers.added, isEmpty);
    google
      ..approveAs = null
      ..grantedScope = 'openid https://www.googleapis.com/auth/youtube.readonly';
    f.dispose();
  });

  test('a client Google refuses: its message on the own-client screen', () async {
    final f = flow();
    await f.startYouTube(client: const GoogleClient(id: 'web-client', secret: 'x', own: true));
    expect(f.step.stage, SignInStage.youtubeClient);
    expect(f.step.error, contains('TVs and Limited Input devices'));
    f.dispose();
  });

  test('Back on the code or the picker: nothing kept, the token revoked', () async {
    final f = flow();
    await f.startYouTube(client: own);
    google.approveAs = 'mom';
    await until(f, (s) => s.stage == SignInStage.youtubePicker);
    f.back();
    expect(f.step.stage, SignInStage.server);
    await until(f, (_) => google.revoked.isNotEmpty);
    expect(app.servers.added, isEmpty);
    f.dispose();
  });

  test('the same Google account a second time is refused by name', () async {
    final f = flow();
    await f.startYouTube(client: own);
    google.approveAs = 'mom';
    await until(f, (s) => s.stage == SignInStage.youtubePicker);
    await f.youTubePicked(const []);
    f.dispose();
    final again = flow();
    await again.startYouTube(client: own);
    await until(again, (s) => s.stage == SignInStage.server && s.error != null);
    expect(again.step.error, 'YouTube is already in this profile');
    again.dispose();
  });

  /// [key]'s refresh token as the secret store keeps it.
  Future<String?> refreshOf(String key) async =>
      (await app.youtube.secrets.values(app.servers.byKey(key)!.session!.accessToken))?['refresh'];

  test('Sign in again with the same client keeps the channels; the old token is dropped, not revoked', () async {
    final f = flow();
    await f.startYouTube(client: own);
    google.approveAs = 'mom';
    await until(f, (s) => s.stage == SignInStage.youtubePicker);
    await f.youTubePicked([f.step.youtube.subscriptions!.first]);
    f.dispose();
    final key = app.servers.added.single.key;
    final before = app.servers.added.single.session!.accessToken;
    final again = flow(adding: false, againKey: key);
    await again.startYouTube();
    await until(again, (_) => again.finished);
    expect(app.servers.byKey(key)!.session!.accessToken, isNot(before));
    expect(app.youTubeChannels, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Google's revoke would end the new sign-in too (one grant per client).
    expect(google.revoked, isEmpty);
    expect(google.refreshTokens, contains(await refreshOf(key)), reason: 'the new sign-in still works');
    expect(await app.youtube.secrets.values(before), isNull, reason: 'the old token is dropped');
    again.dispose();
  });

  test('back to Nightingale TV\'s client with more than 5 channels is refused and says why', () async {
    GoogleClient.sharedOverride = const GoogleClient(id: 'shared-client', secret: 'shared-client-secret');
    addTearDown(() => GoogleClient.sharedOverride = null);
    for (var i = 0; i < 6; i++) {
      google.channels['UCx$i'] = FakeChannel('UCx$i', 'Extra $i', videos: [FakeVideo('x$i')]);
    }
    google.accounts['mom'] = FakeAccount('mom', title: 'Mom', subscriptions: ['UCb', 'UCa', for (var i = 0; i < 6; i++) 'UCx$i']);
    final f = flow();
    google.approveAs = 'mom';
    await f.startYouTube(client: own);
    await until(f, (s) => s.stage == SignInStage.youtubePicker);
    await f.youTubePicked(f.step.youtube.subscriptions!);
    f.dispose();
    final key = app.servers.added.single.key;
    expect(app.youTubeChannels, hasLength(8));
    final back = flow(adding: false, againKey: key);
    back.showGoogleClient();
    await back.startYouTube(client: GoogleClient.shared);
    expect(back.step.stage, SignInStage.youtubeClient);
    expect(back.step.error, 'Nightingale TV\'s client allows 5 YouTube channels. Remove some in Channels first.');
    expect(app.servers.byKey(key)!.session!.clientId, 'own-client');
    back.dispose();
  });

  test('back from an own client to Nightingale TV\'s: the channels kept, the own client forgotten', () async {
    GoogleClient.sharedOverride = const GoogleClient(id: 'shared-client', secret: 'shared-client-secret');
    addTearDown(() => GoogleClient.sharedOverride = null);
    final f = flow();
    google.approveAs = 'mom';
    await f.startYouTube(client: own);
    await until(f, (s) => s.stage == SignInStage.youtubePicker);
    await f.youTubePicked([f.step.youtube.subscriptions!.first]);
    f.dispose();
    final key = app.servers.added.single.key;
    expect(app.servers.byKey(key)!.session!.clientId, 'own-client');
    final channels = [for (final c in app.youTubeChannels) (c.number, c.name)];
    // Servers → YouTube → Google client → Use Nightingale TV's client.
    final back = flow(adding: false, againKey: key);
    await back.startYouTube(client: GoogleClient.shared);
    await until(back, (_) => back.finished);
    expect(back.finished, isTrue, reason: '${back.step.error}');
    expect(app.servers.byKey(key)!.session!.clientId, isNull);
    expect((await app.youtube.googleClientOf(app.servers.byKey(key)!.session!))?.id, 'shared-client');
    expect([for (final c in app.youTubeChannels) (c.number, c.name)], channels);
    await until(back, (_) => google.revoked.isNotEmpty);
    expect(google.revoked, isNotEmpty, reason: 'the own client\'s token');
    expect(google.refreshTokens, contains(await refreshOf(key)), reason: 'the new sign-in still works');
    back.dispose();
  });
}
