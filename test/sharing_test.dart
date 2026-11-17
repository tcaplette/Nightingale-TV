import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/platform/install_info.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/sharing/invite_code.dart';
import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/share_service.dart';
import 'package:nightingale_tv/sharing/share_session_store.dart';
import 'package:nightingale_tv/sharing/sharing.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';

/// A Supabase session as gotrue saves it; [expired] makes it need a refresh.
/// gotrue reads the expiry from the access token, an (unsigned) JWT.
String sessionJson(String userId, {bool expired = false}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = expired ? now - 60 : now + 3600;
  String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': userId, 'exp': exp, 'role': 'authenticated'})}.c2ln';
  return jsonEncode({
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'refresh_token': 'refresh-token-1',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'sam@example.com',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-11-16T00:00:00Z',
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('invite codes', () {
    test('cleans any case, spaces, dots and the display dot', () {
      for (final input in ['AB3K9Q', 'ab3k9q', 'ab3k 9q', ' AB3K·9Q ', 'ab3k.9q', 'a b 3 k 9 q', 'AB3K-9Q']) {
        expect(InviteCode.clean(input), 'AB3K9Q', reason: input);
      }
    });

    test('refuses look-alikes, wrong lengths and other characters', () {
      for (final input in ['AB3K9', 'AB3K9QX', 'AB3KO9', 'AB3KI9', 'AB3K19', 'AB3K09', 'AB3KL9', 'AB3K9!', '']) {
        expect(InviteCode.clean(input), isNull, reason: input);
      }
    });

    test('display form and link', () {
      expect(InviteCode.display('AB3K9Q'), 'AB3K·9Q');
      expect(InviteCode.link('AB3K9Q', host: 'example.com'), 'https://example.com/ntv/i/AB3K9Q');
    });

    test('takes codes only from this host\'s invite links', () {
      const host = 'example.com';
      expect(InviteCode.fromLink('https://example.com/ntv/i/AB3K9Q', host: host), 'AB3K9Q');
      expect(InviteCode.fromLink('https://EXAMPLE.com/ntv/i/ab3k9q/', host: host), 'AB3K9Q');
      for (final link in [
        'http://example.com/ntv/i/AB3K9Q',
        'https://evil.example/ntv/i/AB3K9Q',
        'https://example.com/ntv/x/AB3K9Q',
        'https://example.com/ntv/i/AB3K9Q/more',
        'https://example.com/ntv/i/NOPE00',
        'not a link',
      ]) {
        expect(InviteCode.fromLink(link, host: host), isNull, reason: link);
      }
      expect(InviteCode.fromLink('https://example.com/ntv/i/AB3K9Q', host: ''), isNull);
    });
  });

  group('sign-in attempt', () {
    test('Send a new code after 60 seconds; a new code after 5 wrong ones', () {
      var now = DateTime(2026, 11, 16, 12);
      final a = SignInAttempt('sam@example.com', clock: () => now);
      a.sent();
      expect(a.canResend, isFalse);
      now = now.add(const Duration(seconds: 59));
      expect(a.resendIn, const Duration(seconds: 1));
      now = now.add(const Duration(seconds: 1));
      expect(a.canResend, isTrue);
      for (var i = 0; i < 4; i++) {
        expect(a.wrongCode(), CodeCheck.wrong);
      }
      expect(a.wrongCode(), CodeCheck.newCodeNeeded);
      expect(a.needsNewCode, isTrue);
      a.sent();
      expect(a.needsNewCode, isFalse);
    });

    test('emails', () {
      expect(SignInAttempt.looksLikeEmail('sam@example.com'), isTrue);
      expect(SignInAttempt.looksLikeEmail('sam@example'), isFalse);
      expect(SignInAttempt.looksLikeEmail('sam example.com'), isFalse);
    });

    test('handles', () {
      expect(ShareProfile.cleanHandle(' @Tyler '), 'tyler');
      expect(ShareProfile.handlePattern.hasMatch('ty'), isFalse);
      expect(ShareProfile.handlePattern.hasMatch('tyler_2'), isTrue);
      expect(ShareProfile.handlePattern.hasMatch('tyler-2'), isFalse);
      expect(ShareProfile.handlePattern.hasMatch('a' * 21), isFalse);
    });
  });

  group('sharing on or off', () {
    tearDown(() => Sharing.debugAvailable = null);

    test('off in this (debug) build, whatever the defines', () {
      expect(Sharing.available, isFalse);
    });

    test('never in server mode', () async {
      final dir = await Directory.systemTemp.createTemp('ntv_share');
      addTearDown(() => dir.delete(recursive: true));
      Sharing.debugAvailable = true;
      final server = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
      expect(ShareService.forHousehold(server), isNull);
    });
  });

  group('service and client', () {
    late Directory dir;
    late Household household;
    late List<http.Request> requests;
    late ShareService service;
    final mom = momAndKids().first;
    final kids = momAndKids().last;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ntv_share');
      await writeHousehold(dir, momAndKids(), fakeLibrary(), logos: 0);
      household = await openHousehold(dir);
      requests = [];
    });

    tearDown(() async {
      service.dispose();
      household.leave();
      household.backups?.dispose();
      InstallSwitching.debugReset();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await dir.delete(recursive: true);
    });

    Future<ShareService> open({http.Response Function(http.Request)? answer}) async {
      service = ShareService(household, household.root,
          url: 'https://share.test',
          key: 'sb_publishable_test',
          host: 'share.example',
          watchLifecycle: false,
          httpClient: MockClient((r) async {
            requests.add(r);
            return answer?.call(r) ?? http.Response('{}', 500);
          }));
      await service.load();
      return service;
    }

    Future<void> link(Profile p, {bool expired = false}) async {
      final store = ShareSessionStore(household.root);
      await store.load();
      await store.put(
          p.id, ShareSignIn(session: sessionJson('u-${p.id}', expired: expired), userId: 'u-${p.id}', email: 'sam@example.com'));
      await household.root.flush();
    }

    test('no profile linked: nothing is sent, whatever happens', () async {
      await open();
      await household.select(mom);
      service.hidden = true;
      service.hidden = false;
      service.asleep = true;
      service.asleep = false;
      await household.select(kids);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requests, isEmpty);
      expect(service.active, isNull);
    });

    test('a linked profile starts in front, from its saved sign-in, with no request', () async {
      await link(mom);
      await open();
      await household.select(mom);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.active?.started, isTrue);
      expect(service.active?.linked.value, isTrue);
      // Channel sharing connects (channel-sharing); the sign-in itself
      // needs no refresh.
      expect(requests.where((r) => r.url.path.startsWith('/auth/')), isEmpty,
          reason: 'a fresh sign-in is restored locally');
    });

    test('an expired sign-in: nothing goes out unsigned while it is being refreshed', () async {
      await link(mom, expired: true);
      final refresh = Completer<void>();
      final unsigned = <String>[];
      service = ShareService(household, household.root,
          url: 'https://share.test',
          key: 'sb_publishable_test',
          host: 'share.example',
          watchLifecycle: false,
          httpClient: MockClient((r) async {
            requests.add(r);
            if (r.url.path == '/auth/v1/token') {
              await refresh.future;
              return http.Response(sessionJson('u-${mom.id}'), 200, headers: {'content-type': 'application/json'});
            }
            if (r.url.path.startsWith('/rest/') && !(r.headers['Authorization'] ?? '').contains('.c2ln')) {
              unsigned.add(r.url.path);
            }
            return http.Response('[]', 200, headers: {'content-type': 'application/json'});
          }));
      await service.load();
      await household.select(mom);
      // The household's changes start the client again meanwhile.
      service.hidden = true;
      service.hidden = false;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      refresh.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.active?.started, isTrue);
      expect(unsigned, isEmpty, reason: 'every request carries the restored sign-in');
    });

    test('hidden or asleep: stopped, and requests are refused before they are sent', () async {
      await link(mom);
      await open();
      await household.select(mom);
      final client = service.active!;
      // In front, channel sharing connects; what counts is the silence after.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      service.hidden = true;
      await Future<void>.delayed(Duration.zero);
      requests.clear();
      expect(client.started, isFalse);
      await expectLater(client.friends(), throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requests, isEmpty, reason: 'nothing while hidden');
      service.hidden = false;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.started, isTrue);
      service.asleep = true;
      await Future<void>.delayed(Duration.zero);
      requests.clear();
      expect(client.started, isFalse);
      await expectLater(client.profile(), throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requests, isEmpty, reason: 'nothing while asleep');
    });

    test('an expired sign-in is refreshed only when the profile is in front', () async {
      await link(mom, expired: true);
      // Offline: the refresh can't get through.
      await open(answer: (r) => throw http.ClientException('offline'));
      service.hidden = true;
      await household.select(mom);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requests, isEmpty, reason: 'hidden');
      service.hidden = false;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(requests.map((r) => r.url.path), contains('/auth/v1/token'));
      expect(service.store.isLinked(mom.id), isTrue, reason: 'offline is not signed out');
    });

    test('a rejected refresh signs the profile out', () async {
      await link(mom, expired: true);
      await open(
          answer: (r) => http.Response(jsonEncode({'code': 'refresh_token_not_found', 'msg': 'Invalid Refresh Token'}), 400,
              headers: {'content-type': 'application/json'}));
      await household.select(mom);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(service.store.isLinked(mom.id), isFalse);
      expect(service.active?.linked.value ?? false, isFalse);
    });

    test('kid profiles are never linked, and a profile that becomes one is signed out', () async {
      await link(mom);
      await open();
      expect(service.clientFor(kids), isNull);
      // Another grown-up with a PIN, so Mom can become a kid profile.
      final dad = household.newProfile()
        ..name = 'Dad'
        ..setPin('4321');
      await household.saveProfile(dad);
      await household.select(dad);
      await household.saveProfile(Profile(id: mom.id, name: 'Mom', kind: ProfileKind.kid)..setPin('1234'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.store.isLinked(mom.id), isFalse);
      await household.root.flush();
      final saved = await household.root.readJson(ShareSessionStore.fileName);
      expect(jsonEncode(saved), isNot(contains('refresh-token-1')));
    });

    test('an invite link is kept as a pending code; other links are ignored', () async {
      await open();
      InstallSwitching.inviteLink.value = 'https://elsewhere.test/ntv/i/AB3K9Q';
      expect(service.pendingCode.value, isNull);
      expect(InstallSwitching.inviteLink.value, isNull, reason: 'taken and dropped');
      InstallSwitching.inviteLink.value = 'https://share.example/ntv/i/ab3k9q';
      expect(service.pendingCode.value, 'AB3K9Q');
      // No profile chosen yet, then a profile that isn't linked: still kept.
      household.leave();
      await household.select(mom);
      expect(service.pendingCode.value, 'AB3K9Q', reason: 'kept until the Sharing screen uses it');
      expect(requests, isEmpty);
    });
  });
}
