import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/remote/firewall_check.dart';
import 'package:nightingale_tv/remote/remote_control.dart';
import 'package:nightingale_tv/remote/remote_page.dart';
import 'package:nightingale_tv/sharing/party_reactions.dart';
import 'package:nightingale_tv/sharing/share_service.dart';
import 'package:nightingale_tv/sharing/watch_party.dart';

import 'fake_party.dart';
import 'fake_playback.dart';
import 'fixtures.dart';

/// The phone remote in a watch party (phone-remote, "Reactions from the
/// phone").
void main() {
  late Directory dir;
  late Household household;
  late RemoteControl remote;
  late Tuner tuner;
  late WatchParty party;
  late FakePartyBackend backend;
  late DateTime now;
  final http = HttpClient();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_remote_party');
    await signedInApp(dir, fakeLibrary());
    household = Household(await AppStorage.at(dir));
    await household.start();
    household.sharing = ShareService(household, household.root, watchLifecycle: false);
    now = DateTime.now();
    final app = household.app!;
    app.client = FakeClient([]);
    tuner = Tuner(app, player: FakePlayer([]), clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1);
    await tuner.tune(app.channels.first);
    await pumpEventQueue();
    WatchParty.checkEvery = const Duration(hours: 1);
    WatchParty.heartbeat = const Duration(hours: 1);
    WatchParty.stateEvery = const Duration(hours: 1);
    party = household.sharing!.party..tuner = tuner;
    backend = FakePartyBackend(partyProfile('tyler', 'Tyler'), () => now);
    await party.attach(backend, app);
    remote = RemoteControl(household, firewallCheck: FirewallCheck(linux: false), isThisDevice: (_) async => false);
    await remote.setEnabled(true, port: 0);
  });

  tearDown(() async {
    await remote.stop();
    household.sharing!.dispose();
    tuner.dispose();
    await household.app?.close();
    await household.root.flush();
    await dir.delete(recursive: true);
  });

  Future<(int, Map<String, Object?>?)> send(String method, String path, {Object? body, String? key}) async {
    final request = await http.openUrl(method, Uri.parse('http://127.0.0.1:${remote.port}$path'));
    if (method == 'POST') {
      request.headers.contentType = ContentType.json;
      request.headers.set(RemoteControl.actionHeader, '1');
    }
    if (key != null) request.headers.set(RemoteControl.keyHeader, key);
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text) as Map<String, Object?>);
  }

  Future<String> paired() async {
    remote.openPairing();
    final (status, body) = await send('POST', '/api/pair', body: {'code': remote.pairingCode, 'name': 'Phone'});
    expect(status, 200);
    return body!['key']! as String;
  }

  test('the state carries the party while the TV is in one', () async {
    final key = await paired();
    expect((await send('GET', '/api/state', key: key)).$2!['party'], isNull);
    await party.start();
    final (_, state) = await send('GET', '/api/state', key: key);
    expect(state!['party'], {'active': true, 'reactions': partyReactions});
    await party.leave();
    expect((await send('GET', '/api/state', key: key)).$2!['party'], isNull, reason: 'the pad goes with the party');
  });

  test('a paired phone reacts as the TV\'s profile, once a second', () async {
    final key = await paired();
    await party.start();
    final shown = <FloatingReaction>[];
    party.reactions.listen(shown.add);
    final (status, body) = await send('POST', '/api/react', body: {'emoji': '🍿'}, key: key);
    expect(status, 200);
    expect(body!['sent'], isTrue);
    expect(backend.room.sent.last.$1, 'reaction');
    expect(backend.room.sent.last.$2, {'by': 'tyler', 'emoji': '🍿'});
    expect((await send('POST', '/api/react', body: {'emoji': '😂'}, key: key)).$2!['sent'], isFalse,
        reason: 'within the second');
    // The service's party runs on the real clock.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect((await send('POST', '/api/react', body: {'emoji': '😂'}, key: key)).$2!['sent'], isTrue);
    await pumpEventQueue();
    expect(shown.map((r) => r.emoji), ['🍿', '😂']);
  });

  test('an unpaired phone can\'t react', () async {
    await paired();
    await party.start();
    for (final k in [null, 'not-a-key']) {
      expect((await send('POST', '/api/react', body: {'emoji': '🍿'}, key: k)).$1, 401);
    }
    expect(backend.room.sent.where((s) => s.$1 == 'reaction'), isEmpty);
  });

  test('no reacting outside a party, and only the six reactions', () async {
    final key = await paired();
    expect((await send('POST', '/api/react', body: {'emoji': '🍿'}, key: key)).$1, 409);
    await party.start();
    expect((await send('POST', '/api/react', body: {'emoji': '💩'}, key: key)).$1, 400);
  });

  test('the page hides the pad within 5 seconds of the party ending', () {
    final html = remotePageHtml();
    // It reads the state every 3 seconds and shows the pad only while the
    // state has a party.
    expect(html, contains("setInterval(() => { if (!document.hidden) refresh(); }, 3000)"));
    expect(html, contains(r"$('react').hidden = !party;"));
    expect(html, contains("post('/api/react', { emoji: e })"));
  });
}
