// A shared PlaybackInfo request fails as an error for every caller, in each
// caller's own zone: the integration tests start the app (and its launch
// request) inside tester.runAsync, and the TV screen's tune joins it from
// the test's zone.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_decide_zones');
    app = await signedInApp(dir, fakeLibrary());
  });

  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });

  test('a request asked in another zone fails as an error in the caller\'s', () async {
    final client = FakeClient([]);
    app.client = client;
    final uncaught = <Object>[];
    runZonedGuarded(() {
      client.holdDecisions = Completer<void>();
      // The launch's early request, with its own error handling.
      unawaited(app.decide('src', 4000).then((_) {}, onError: (Object _) {}));
    }, (e, s) => uncaught.add(e));
    expect(app.deciding('src', 4000), isTrue);

    // The tune joins it.
    final joined = app.decide('src', 4000);
    client.holdDecisions!.completeError(JellyfinException('Could not reach the server (Connection refused).'));
    await expectLater(joined.timeout(const Duration(seconds: 5)), throwsA(isA<JellyfinException>()));
    expect(uncaught, isEmpty, reason: 'nothing escapes as uncaught');
    expect(app.deciding('src', 4000), isFalse);
  });

  test('a request that succeeds answers everyone who joined it', () async {
    final client = FakeClient([]);
    app.client = client;
    client.holdDecisions = Completer<void>();
    final first = app.decide('src', null);
    final joined = app.decide('src', null);
    client.holdDecisions!.complete();
    expect((await first).template, isNull);
    expect((await joined).template, isNull);
    expect(client.decisions, hasLength(1), reason: 'one request, shared');
  });
}
