import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/youtube/google_sign_in.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';

import '../integration_test/fake_google.dart';

void main() {
  late FakeGoogle google;
  late GoogleEndpoints endpoints;
  final waits = <Duration>[];
  const shared = GoogleClient(id: 'shared-client', secret: 'shared-client-secret');

  setUp(() async {
    google = await FakeGoogle.start();
    endpoints = GoogleEndpoints(oauth: google.url, api: google.url);
    google.accounts['sub-mom'] = FakeAccount('sub-mom', title: 'Mom');
    waits.clear();
  });
  tearDown(() => google.close());

  GoogleDeviceSignIn signIn({GoogleClient client = shared, DateTime Function()? now}) => GoogleDeviceSignIn(client,
      endpoints: endpoints, now: now, delay: (d) async => waits.add(d));

  test('a code, then tokens once the code is allowed, with the account id', () async {
    final s = signIn();
    final code = await s.requestCode();
    expect(code.userCode, isNotEmpty);
    expect(code.verificationUrl, 'https://www.google.com/device');
    var polls = 0;
    final tokens = s.waitForTokens(code, cancelled: () {
      if (++polls == 3) google.approveAs = 'sub-mom';
      return false;
    });
    final t = (await tokens)!;
    expect(t.subject, 'sub-mom');
    expect(t.refreshToken, startsWith('refresh-'));
    expect(google.requests.where((r) => r == 'POST /token').length, greaterThanOrEqualTo(3));
    // Only openid and read-only YouTube are asked for.
    expect(googleScopes.split(' '), ['openid', 'https://www.googleapis.com/auth/youtube.readonly']);
  });

  test('slow_down adds 5 seconds to the wait', () async {
    google.slowDownOnce = true;
    google.approveAs = 'sub-mom';
    final s = signIn();
    final code = await s.requestCode();
    await s.waitForTokens(code);
    expect(waits, [const Duration(seconds: 1), const Duration(seconds: 6)]);
  });

  test('Deny on Google\'s page is a cancelled sign-in', () async {
    google.deny = true;
    final s = signIn();
    final code = await s.requestCode();
    await expectLater(s.waitForTokens(code),
        throwsA(isA<GoogleSignInException>().having((e) => e.failure, 'failure', GoogleSignInFailure.cancelled)));
  });

  test('an expired code says so, for a new one to be asked for', () async {
    google.codeLife = Duration.zero;
    final s = signIn();
    final code = await s.requestCode();
    await expectLater(s.waitForTokens(code),
        throwsA(isA<GoogleSignInException>().having((e) => e.failure, 'failure', GoogleSignInFailure.expired)));
  });

  test('Back or Cancel stops waiting with nothing', () async {
    final s = signIn();
    final code = await s.requestCode();
    expect(await s.waitForTokens(code, cancelled: () => true), isNull);
  });

  test('a client Google refuses is invalidClient', () async {
    final s = signIn(client: const GoogleClient(id: 'web-client', secret: 'x', own: true));
    await expectLater(s.requestCode(),
        throwsA(isA<GoogleSignInException>().having((e) => e.failure, 'failure', GoogleSignInFailure.invalidClient)));
  });

  test('tokens refresh 60 s before they expire, and invalid_grant once revoked', () async {
    google.approveAs = 'sub-mom';
    var clock = DateTime(2026, 11, 23, 12);
    final s = signIn(now: () => clock);
    final tokens = (await s.waitForTokens(await s.requestCode()))!;
    final auth = GoogleAuth(s, tokens, now: () => clock);
    final first = await auth.accessToken();
    expect(first, tokens.accessToken);
    clock = clock.add(const Duration(minutes: 58));
    expect(await auth.accessToken(), first, reason: '61 s left: still good');
    clock = clock.add(const Duration(seconds: 61));
    final second = await auth.accessToken();
    expect(second, isNot(first));
    expect(auth.refreshToken, tokens.refreshToken);
    google.revokeAccount('sub-mom');
    await expectLater(auth.accessToken(force: true),
        throwsA(isA<GoogleSignInException>().having((e) => e.failure, 'failure', GoogleSignInFailure.invalidGrant)));
  });

  test('revoke ends the sign-in on Google\'s side; a failed one never throws', () async {
    google.approveAs = 'sub-mom';
    final s = signIn();
    final tokens = (await s.waitForTokens(await s.requestCode()))!;
    expect(await s.revoke(tokens.refreshToken), isTrue);
    expect(google.revoked, [tokens.refreshToken]);
    expect(await s.revoke(tokens.refreshToken), isFalse);
  });

  test('the shared client comes from the bundled file, own clients from Google\'s file', () {
    // Tests don't load the bundled client (youtube_client_config_test does).
    expect(GoogleClient.shared, isNull);
    final own = GoogleClient.fromDownload({
      'installed': {'client_id': ' id.apps.googleusercontent.com ', 'client_secret': 'GOCSPX-x', 'project_id': 'p'}
    });
    expect(own, const GoogleClient(id: 'id.apps.googleusercontent.com', secret: 'GOCSPX-x'));
    expect(own!.own, isTrue);
    expect(GoogleClient.fromDownload({'web': {'client_id': 'x'}}), isNull);
    expect(GoogleClient.fromDownload('nope'), isNull);
  });
}
