import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/remote/remote_control.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;
  late Household household;
  late RemoteControl remote;
  final pressed = <LogicalKeyboardKey>[];
  final http = HttpClient();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_remote');
    await signedInApp(dir, fakeLibrary());
    household = Household(await AppStorage.at(dir));
    await household.start();
    pressed.clear();
    remote = RemoteControl(household, dispatch: (key, physical) {
      pressed.add(key);
      return true;
    });
    await remote.setEnabled(true, port: 0);
  });

  tearDown(() async {
    await remote.stop();
    await dir.delete(recursive: true);
  });

  Uri at(String path) => Uri.parse('http://127.0.0.1:${remote.port}$path');

  Future<(int, String)> get(String path) async {
    final response = await (await http.getUrl(at(path))).close();
    return (response.statusCode, await utf8.decodeStream(response));
  }

  Future<(int, Object?)> post(String path, Object body, {bool header = true}) async {
    final request = await http.postUrl(at(path));
    request.headers.contentType = ContentType.json;
    if (header) request.headers.set(RemoteControl.actionHeader, '1');
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('serves the remote page', () async {
    final (status, body) = await get('/');
    expect(status, 200);
    expect(body, contains('Nightingale TV Remote'));
    expect(remote.url, isNotNull);
  });

  test('reports who is watching and the lineup', () async {
    final (status, body) = await get('/api/state');
    expect(status, 200);
    final state = jsonDecode(body) as Map<String, Object?>;
    expect(state['profile'], 'Tester');
    final channels = (state['channels'] as List).cast<Map<String, Object?>>();
    expect(channels, isNotEmpty);
    expect(channels.first['now'], isA<String>());
  });

  test('buttons become key presses', () async {
    final (status, body) = await post('/api/key', {'key': 'up'});
    expect(status, 200);
    expect(body, {'handled': true});
    await post('/api/key', {'key': '7'});
    await post('/api/key', {'key': 'guide'});
    expect(pressed, [LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.digit7, LogicalKeyboardKey.keyG]);
  });

  test('requests from other web pages and bad requests are refused', () async {
    expect((await post('/api/key', {'key': 'up'}, header: false)).$1, 403);
    expect((await post('/api/key', {'key': 'self-destruct'})).$1, 400);
    expect((await post('/api/tune', {'number': 'two'})).$1, 400);
    expect((await get('/etc/passwd')).$1, 404);
    expect(pressed, isEmpty);
  });

  test('only home-network addresses are allowed', () {
    bool ok(String a) => RemoteControl.isPrivate(InternetAddress(a));
    expect(ok('127.0.0.1'), isTrue);
    expect(ok('192.168.1.20'), isTrue);
    expect(ok('10.0.0.5'), isTrue);
    expect(ok('172.20.1.1'), isTrue);
    expect(ok('172.32.1.1'), isFalse);
    expect(ok('8.8.8.8'), isFalse);
  });

  test('the on/off setting is remembered', () async {
    await remote.setEnabled(false);
    expect(remote.url, isNull);
    var again = RemoteControl(household);
    await again.load();
    expect(again.enabled, isFalse);

    await remote.setEnabled(true, port: 0);
    again = RemoteControl(household);
    await again.load();
    expect(again.enabled, isTrue);
    expect(again.url, isNotNull);
    await again.stop();
  });
}
