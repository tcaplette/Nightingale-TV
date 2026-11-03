import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/remote/firewall_check.dart';
import 'package:nightingale_tv/remote/remote_control.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;
  late Household household;
  final remotes = <RemoteControl>[];
  final pressed = <LogicalKeyboardKey>[];
  final http = HttpClient();

  /// Requests from the test count as from another device unless a test
  /// says otherwise.
  var fromThisDevice = false;

  RemoteControl make() {
    final r = RemoteControl(
      household,
      firewallCheck: FirewallCheck(linux: false),
      isThisDevice: (_) async => fromThisDevice,
      dispatch: (key, physical) {
        pressed.add(key);
        return true;
      },
    );
    remotes.add(r);
    return r;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_pairing');
    await signedInApp(dir, fakeLibrary());
    household = Household(await AppStorage.at(dir));
    await household.start();
    pressed.clear();
    fromThisDevice = false;
  });

  tearDown(() async {
    for (final r in remotes) {
      await r.stop();
    }
    remotes.clear();
    await household.root.flush();
    await dir.delete(recursive: true);
  });

  Uri at(RemoteControl r, String path) => Uri.parse('http://127.0.0.1:${r.port}$path');

  Future<(int, Object?)> send(RemoteControl r, String method, String path, {Object? body, String? key}) async {
    final request = await http.openUrl(method, at(r, path));
    if (method == 'POST') {
      request.headers.contentType = ContentType.json;
      request.headers.set(RemoteControl.actionHeader, '1');
    }
    if (key != null) request.headers.set(RemoteControl.keyHeader, key);
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    final json = response.headers.contentType?.mimeType == 'application/json';
    return (response.statusCode, json && text.isNotEmpty ? jsonDecode(text) : text);
  }

  Future<(int, Object?)> pair(RemoteControl r, Object? code, {String name = 'iPhone · Safari'}) =>
      send(r, 'POST', '/api/pair', body: {'code': code, 'name': name});

  Future<String> paired(RemoteControl r, {String name = 'iPhone · Safari'}) async {
    r.openPairing();
    final (status, body) = await pair(r, r.pairingCode, name: name);
    expect(status, 200);
    return (body! as Map)['key'] as String;
  }

  Future<int> press(RemoteControl r, String? key) async =>
      (await send(r, 'POST', '/api/key', body: {'key': 'up'}, key: key)).$1;

  Future<Map<String, Object?>> saved() async => (await household.root.readJson(RemoteControl.pairingsFile))! as Map<String, Object?>;

  /// A wrong code: one digit off the real one.
  String wrong(String code) => '${(int.parse(code[0]) + 1) % 10}${code.substring(1)}';

  test('pairs by code only while the window is open', () async {
    final r = make();
    await r.setEnabled(true, port: 0);
    final closed = await pair(r, '123456');
    expect(closed.$1, 403);
    expect((closed.$2! as Map)['error'], RemoteControl.pairingClosedMessage);

    r.openPairing();
    final code = r.pairingCode!;
    expect(code, matches(RegExp(r'^\d{6}$')));
    final (status, body) = await pair(r, '${code.substring(0, 3)} ${code.substring(3)}', name: 'x' * 60);
    expect(status, 200);
    final key = (body! as Map)['key'] as String;
    expect(base64Url.decode(base64Url.normalize(key)), hasLength(32));
    expect(r.pairings.single.name, hasLength(40));
    expect(await press(r, key), 200);
    expect(pressed, [LogicalKeyboardKey.arrowUp]);

    r.closePairing();
    expect(r.pairingCode, isNull);
    expect((await pair(r, code)).$1, 403);
  });

  test('state, key and tune need a known key', () async {
    final r = make();
    await r.setEnabled(true, port: 0);
    final key = await paired(r);
    for (final k in [null, 'not-a-key']) {
      expect((await send(r, 'GET', '/api/state', key: k)).$1, 401);
      expect(await press(r, k), 401);
      expect((await send(r, 'POST', '/api/tune', body: {'number': 2}, key: k)).$1, 401);
    }
    expect(pressed, isEmpty);
    final (status, state) = await send(r, 'GET', '/api/state', key: key);
    expect(status, 200);
    expect((state! as Map)['profile'], 'Tester');
    expect((await send(r, 'GET', '/')).$1, 200, reason: 'the page itself needs no key');
  });

  test('the code changes after a pairing and after 5 wrong codes', () async {
    final r = make();
    await r.setEnabled(true, port: 0);
    r.openPairing();
    final first = r.pairingCode!;
    expect((await pair(r, first)).$1, 200);
    final second = r.pairingCode!;
    expect(second, isNot(first));
    expect((await pair(r, first)).$1, 403, reason: 'a used code no longer pairs');

    for (var i = 0; i < 3; i++) {
      expect((await pair(r, wrong(second))).$1, 403);
    }
    expect(r.pairingCode, second, reason: '5 wrong codes counting the one above');
    expect((await pair(r, wrong(second))).$1, 403);
    expect(r.pairingCode, isNot(second));
    expect((await pair(r, second)).$1, 403, reason: 'the old code no longer pairs');
  });

  test('remove and remove all', () async {
    final r = make();
    await r.setEnabled(true, port: 0);
    final a = await paired(r, name: 'iPhone · Safari');
    final b = await paired(r, name: 'Android phone · Chrome');
    final c = await paired(r, name: 'iPad');
    expect(r.pairings, hasLength(3));

    await r.removePairing(r.pairings.firstWhere((p) => p.name == 'iPhone · Safari').id);
    expect(await press(r, a), 401);
    expect(await press(r, b), 200);

    await r.removeAllPairings();
    expect(r.pairings, isEmpty);
    expect(await press(r, b), 401);
    expect(await press(r, c), 401);
    expect((await saved())['pairings'], isEmpty);
  });

  test('pairing a 21st phone removes the one used longest ago', () async {
    final r = make();
    await r.setEnabled(true, port: 0);
    final keys = [for (var i = 0; i < RemoteControl.maxPairings; i++) await paired(r, name: 'Phone $i')];
    // Phone 0 was used most recently; phone 1 is now the oldest.
    for (final (i, p) in r.pairings.indexed) {
      p.lastUsed = DateTime.now().subtract(Duration(hours: p.name == 'Phone 0' ? 0 : 100 - i));
    }
    final oldest = r.pairings.reduce((a, b) => a.lastUsed.isBefore(b.lastUsed) ? a : b).name;
    await paired(r, name: 'Newest');
    expect(r.pairings, hasLength(RemoteControl.maxPairings));
    expect(r.pairings.map((p) => p.name), contains('Newest'));
    expect(r.pairings.map((p) => p.name), isNot(contains(oldest)));
    expect(await press(r, keys[0]), 200);
  });

  test('turning the remote off and on keeps pairings', () async {
    final r = make();
    await r.setEnabled(true, port: 0);
    final key = await paired(r);
    await r.setEnabled(false);
    await r.setEnabled(true, port: 0);
    expect(await press(r, key), 200);

    // And after the app restarts.
    await r.stop();
    final again = make();
    await again.load();
    expect(again.pairings.single.name, 'iPhone · Safari');
    expect(await press(again, key), 200);
  });

  test('only key hashes are saved, never the key', () async {
    final r = make();
    await r.setEnabled(true, port: 0);
    final key = await paired(r);
    await household.root.flush();
    final text = await File('${dir.path}/${RemoteControl.pairingsFile}').readAsString();
    expect(text, isNot(contains(key)));
    final p = ((await saved())['pairings']! as List).single as Map;
    expect(p['keyHash'], hasLength(64));
    expect(p.keys, containsAll(['id', 'name', 'keyHash', 'paired', 'lastUsed']));
    final settings = await household.root.readJson('remote.json');
    expect(settings, {'enabled': true}, reason: 'remote.json stays {enabled}');
  });

  test('a key from one TV is refused by another (two rooms)', () async {
    final living = make();
    await living.setEnabled(true, port: 0);
    final key = await paired(living);

    // A second TV with its own data folder.
    final other = await Directory.systemTemp.createTemp('nightingale_tv_pairing_bedroom');
    addTearDown(() => other.delete(recursive: true));
    await signedInApp(other, fakeLibrary());
    final bedroomHousehold = Household(await AppStorage.at(other));
    await bedroomHousehold.start();
    final bedroom = RemoteControl(bedroomHousehold, firewallCheck: FirewallCheck(linux: false));
    remotes.add(bedroom);
    await bedroom.setEnabled(true, port: 0);

    expect(await press(bedroom, key), 401);
    expect((await send(bedroom, 'GET', '/api/state', key: key)).$1, 401);
    expect(await press(living, key), 200);
    await bedroomHousehold.root.flush();
  });

  group('Working', () {
    test('comes from another device only, and is remembered', () async {
      final r = make();
      await r.setEnabled(true, port: 0);
      expect(r.status, RemoteStatus.notConfirmed);

      fromThisDevice = true;
      final key = await paired(r);
      expect(await press(r, key), 200);
      expect(r.status, RemoteStatus.notConfirmed, reason: 'a browser on this device proves nothing');

      fromThisDevice = false;
      var notified = 0;
      r.addListener(() => notified++);
      expect(await press(r, key), 200);
      expect(r.status, RemoteStatus.working);
      expect(notified, greaterThan(0), reason: 'the screen updates without reopening');
      expect((await saved())['confirmed'], {'address': r.url!.host, 'port': r.port});

      await r.stop();
      final again = make();
      await again.load();
      expect(again.status, RemoteStatus.notConfirmed, reason: 'a new port (port 0) clears it');
    });

    test('pairing from another device counts', () async {
      final r = make();
      await r.setEnabled(true, port: 0);
      await paired(r);
      expect(r.status, RemoteStatus.working);
    });

    test('an address or port change clears it', () async {
      final r = make();
      await r.setEnabled(true, port: 0);
      await paired(r);
      expect(r.status, RemoteStatus.working);

      r.confirmed = (address: '192.168.1.20', port: r.port!);
      r.url = Uri(scheme: 'http', host: '192.168.1.33', port: r.port);
      expect(r.status, RemoteStatus.notConfirmed, reason: 'new address');

      r.confirmed = (address: '192.168.1.33', port: 8642);
      r.url = Uri(scheme: 'http', host: '192.168.1.33', port: 8643);
      expect(r.status, RemoteStatus.notConfirmed, reason: 'new port');

      r.url = Uri(scheme: 'http', host: '192.168.1.33', port: 8642);
      expect(r.status, RemoteStatus.working);
    });

    test('a firewall known to block wins over Working', () async {
      final r = RemoteControl(
        household,
        isThisDevice: (_) async => false,
        firewallCheck: FirewallCheck(
          linux: true,
          read: (_) async => null,
          run: (exe, args) async => switch (args.first) {
            '--state' => (exitCode: 0, stdout: 'running\n'),
            '--get-default-zone' => (exitCode: 0, stdout: 'public\n'),
            _ when args.last.startsWith('--query-port') => (exitCode: 1, stdout: 'no\n'),
            _ => (exitCode: 2, stdout: ''),
          },
        ),
      );
      remotes.add(r);
      await r.setEnabled(true, port: 0);
      await paired(r);
      await r.checkFirewall();
      expect(r.status, RemoteStatus.blocked);
      expect(r.fixCommand, 'sudo firewall-cmd --permanent --add-port=${r.port}/tcp && sudo firewall-cmd --reload');
    });
  });
}
