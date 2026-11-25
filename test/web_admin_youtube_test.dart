import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/web_admin/api_client.dart';
import 'package:nightingale_tv/web_admin/app.dart';
import 'package:nightingale_tv/web_admin/youtube_frame.dart';

/// The web admin's YouTube setup and Watch page against a fake API and a
/// fake YouTube player (docker-youtube 3.1, 3.2).
void main() {
  late _Api api;
  late _Frame frame;

  setUp(() {
    api = _Api();
    frame = _Frame();
    YouTubeFrame.override = () => frame;
  });
  tearDown(() => YouTubeFrame.override = null);

  Future<void> start(WidgetTester tester, String path, {Size size = const Size(1280, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WebAdminApp(api: ApiClient(api.client, base: Uri.parse('http://nas.local:8484/'))));
    await tester.pumpAndSettle();
    AdminScope.of(tester.element(find.byType(Navigator).first)).router.go(path);
    await tester.pumpAndSettle();
  }

  /// Add a server → YouTube, the client step filled in, Continue: the code.
  Future<void> toCode(WidgetTester tester, {PointerDeviceKind kind = PointerDeviceKind.touch}) async {
    await tester.tap(find.text('Add a server'), kind: kind);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-youtube')), kind: kind);
    await tester.pumpAndSettle();
    expect(find.text('Your own Google client'), findsOneWidget);
    expect(find.text('Upload JSON file'), findsOneWidget);
    expect(find.text('Turn on YouTube Data API v3.'), findsOneWidget);
    expect(find.textContaining('coffeehauslabs.com/ntv/youtube-client'), findsOneWidget);
    final cont = find.byKey(const ValueKey('client-continue'));
    expect(tester.widget<FilledButton>(cont).onPressed, isNull, reason: 'both fields empty');
    await tester.enterText(find.byKey(const ValueKey('client-id')), 'own-client');
    await tester.pump();
    expect(tester.widget<FilledButton>(cont).onPressed, isNull, reason: 'the secret is empty');
    await tester.enterText(find.byKey(const ValueKey('client-secret')), 'own-client-secret');
    await tester.pump();
    expect(tester.widget<FilledButton>(cont).onPressed, isNotNull);
  }

  group('Add a server → YouTube (3.1)', () {
    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      testWidgets('client, code, picker and colour with ${kind.name}', (tester) async {
        await start(tester, '/profiles/p1/servers');
        await toCode(tester, kind: kind);
        await tester.tap(find.byKey(const ValueKey('client-continue')), kind: kind);
        await tester.pumpAndSettle();
        expect(api.lastBody['POST profiles/p1/youtube/start'], {'clientId': 'own-client', 'clientSecret': 'own-client-secret'});
        expect(find.text('ABC-DEF-001'), findsOneWidget);
        expect(find.text('YouTube Terms of Service'), findsOneWidget);
        expect(find.text('Privacy policy'), findsOneWidget);
        expect(find.text('Open google.com/device'), findsOneWidget);
        // Google says yes: the picker, in title order.
        api.approve();
        await tester.pumpAndSettle();
        expect(find.text('YouTube channels'), findsOneWidget);
        final titles = [for (final t in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) (t.title! as Text).data];
        expect(titles, ['Apples', 'Bananas', 'Cherries']);
        await tester.enterText(find.byKey(const ValueKey('subscription-search')), 'an');
        await tester.pump();
        expect(find.byType(CheckboxListTile), findsOneWidget, reason: 'only Bananas matches');
        await tester.enterText(find.byKey(const ValueKey('subscription-search')), '');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('sub-UCa')), kind: kind);
        await tester.tap(find.byKey(const ValueKey('sub-UCc')), kind: kind);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('picker-done')), kind: kind);
        await tester.pumpAndSettle();
        expect(api.lastBody['PUT profiles/p1/servers/s2/youtube/channels'], {'ids': ['UCa', 'UCc']});
        // The colour step, starting at wine.
        expect(find.byKey(const ValueKey('color-wine')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('color-blue')), kind: kind);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('color-done')), kind: kind);
        await tester.pumpAndSettle();
        expect(api.lastBody['POST profiles/p1/youtube/start/run1/color'], {'name': 'blue'});
        await tester.tap(find.byKey(const ValueKey('youtube-finished')), kind: kind);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      });
    }

    testWidgets('with the keyboard: Tab between fields, Enter to go on, Space to check', (tester) async {
      await start(tester, '/profiles/p1/servers');
      await toCode(tester);
      // Enter in the secret field continues.
      await tester.showKeyboard(find.byKey(const ValueKey('client-secret')));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('ABC-DEF-001'), findsOneWidget);
      api.approve();
      await tester.pumpAndSettle();
      // Tab from the search field reaches Done, then the first row.
      await tester.showKeyboard(find.byKey(const ValueKey('subscription-search')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('sub-UCa'))).value, isTrue);
      final done = find.byKey(const ValueKey('picker-done'));
      Focus.of(tester.element(find.descendant(of: done, matching: find.byType(Text)))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(api.lastBody['PUT profiles/p1/servers/s2/youtube/channels'], {'ids': ['UCa']});
    });

    testWidgets('a refused client stays on the client step with Google\'s reason', (tester) async {
      api.refuse = true;
      await start(tester, '/profiles/p1/servers');
      await toCode(tester);
      await tester.tap(find.byKey(const ValueKey('client-continue')));
      await tester.pumpAndSettle();
      expect(find.text("Google didn't accept this client. It must be of the type TVs and Limited Input devices."), findsOneWidget);
      expect(find.byKey(const ValueKey('client-id')), findsOneWidget);
    });

    testWidgets('an expired code is replaced on the same step; Cancel goes back to the client', (tester) async {
      await start(tester, '/profiles/p1/servers');
      await toCode(tester);
      await tester.tap(find.byKey(const ValueKey('client-continue')));
      await tester.pumpAndSettle();
      api.expire();
      await tester.pumpAndSettle();
      expect(find.text('ABC-DEF-002'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('code-cancel')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('DELETE profiles/p1/youtube/start/run1'));
      expect(find.byKey(const ValueKey('client-id')), findsOneWidget);
    });

    testWidgets('closing the picker of a first add takes the server away', (tester) async {
      await start(tester, '/profiles/p1/servers');
      await toCode(tester);
      await tester.tap(find.byKey(const ValueKey('client-continue')));
      await tester.pumpAndSettle();
      api.approve();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('DELETE profiles/p1/servers/s2'));
    });
  });

  group('a YouTube server on the Servers page (3.1)', () {
    testWidgets('its channel count, Channels, Google client; no quality limit; Remove says access ends', (tester) async {
      api.hasYouTube = true;
      await start(tester, '/profiles/p1/servers');
      expect(find.text('2 channels'), findsOneWidget);
      expect(find.byKey(const ValueKey('youtube-channels')), findsOneWidget);
      expect(find.byKey(const ValueKey('youtube-client')), findsOneWidget);
      expect(find.byType(DropdownMenu<int?>), findsOneWidget, reason: 'only the Jellyfin server has a quality limit');
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(find.text("Its channels leave the lineup, and Nightingale TV's access to your YouTube account ends."), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Channels: unchecking one asks first, naming it', (tester) async {
      api.hasYouTube = true;
      await start(tester, '/profiles/p1/servers');
      await tester.tap(find.byKey(const ValueKey('youtube-channels')));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('sub-UCb'))).value, isTrue);
      await tester.tap(find.byKey(const ValueKey('sub-UCb')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('picker-done')));
      await tester.pumpAndSettle();
      expect(find.text('Remove Bananas from the guide?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(api.lastBody['PUT profiles/p1/servers/s2/youtube/channels'], {'ids': ['UCa']});
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('Google client opens the client step for that server', (tester) async {
      api.hasYouTube = true;
      await start(tester, '/profiles/p1/servers');
      await tester.tap(find.byKey(const ValueKey('youtube-client')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('client-id')), 'own-client');
      await tester.enterText(find.byKey(const ValueKey('client-secret')), 'own-client-secret');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('client-continue')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST profiles/p1/servers/s2/youtube/client'));
    });
  });

  group('Watch (3.2)', () {
    testWidgets('the list: number, name, now and next, and the daily-limit note', (tester) async {
      api.dailyLimit = true;
      await start(tester, '/profiles/p1/watch');
      expect(find.text('Watch'), findsWidgets, reason: 'in the navigation and as the title');
      expect(find.text('501  Apples'), findsOneWidget);
      expect(find.text('Now playing: Apple pie'), findsOneWidget);
      expect(find.text('Up next: Apple tart'), findsOneWidget);
      expect(find.byKey(const ValueKey('note-dailyLimit')), findsOneWidget);
    });

    testWidgets('no YouTube channels: says where to add them', (tester) async {
      api.noChannels = true;
      await start(tester, '/profiles/p1/watch');
      expect(find.text('This profile has no YouTube channels. Add YouTube in Servers.'), findsOneWidget);
    });

    testWidgets("playing: YouTube's player at the offset, the next on ended, paused when hidden, Esc back", (tester) async {
      await start(tester, '/profiles/p1/watch');
      await tester.tap(find.text('501  Apples'));
      await tester.pumpAndSettle();
      expect(frame.loads, [('a1', const Duration(seconds: 125))]);
      // The bar above the player, nothing over it.
      expect(find.text('501  Apples'), findsOneWidget);
      expect(find.byKey(const ValueKey('watch-line')), findsOneWidget);
      expect(find.byType(Drawer), findsNothing, reason: 'the whole window');
      frame.emit(const YouTubeFrameEnded('a1'));
      await tester.pumpAndSettle();
      expect(api.calls.last, 'GET profiles/p1/youtube/yt1/now');
      expect(api.lastQuery['ended'], 'a1');
      expect(frame.loads.last, ('a2', Duration.zero));
      frame.hide(true);
      await tester.pump();
      expect(frame.paused, 1);
      frame.hide(false);
      await tester.pumpAndSettle();
      expect(frame.loads.last.$1, 'a2', reason: 'at the scheduled point again');
      expect(frame.loads, hasLength(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Now playing: Apple pie'), findsOneWidget);
      expect(frame.disposed, isTrue);
    });

    testWidgets('Back returns to the list; a video that won\'t play moves on', (tester) async {
      await start(tester, '/profiles/p1/watch', size: const Size(390, 800));
      await tester.tap(find.text('501  Apples'));
      await tester.pumpAndSettle();
      frame.emit(const YouTubeFrameError(150, 'a1'));
      await tester.pumpAndSettle();
      expect(frame.loads.last.$1, 'a2');
      await tester.tap(find.byKey(const ValueKey('watch-back')));
      await tester.pumpAndSettle();
      expect(find.text('Now playing: Apple pie'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'nothing overflows on a phone');
    });

    testWidgets("Escape caught on the page (focus left with YouTube's controls) also returns to the list", (tester) async {
      await start(tester, '/profiles/p1/watch');
      await tester.tap(find.text('501  Apples'));
      await tester.pumpAndSettle();
      frame.pageEscape();
      await tester.pumpAndSettle();
      expect(find.text('Now playing: Apple pie'), findsOneWidget);
      expect(frame.disposed, isTrue);
    });

    testWidgets('a channel whose YouTube needs sign-in says so in the bar', (tester) async {
      api.needsSignIn = true;
      await start(tester, '/profiles/p1/watch/yt1');
      expect(find.text('Sign in to YouTube again'), findsOneWidget);
      expect(frame.loads, isEmpty);
    });
  });
}

class _Frame extends YouTubeFrame {
  final loads = <(String, Duration)>[];
  int paused = 0;
  bool disposed = false;
  bool _hidden = false;
  final _events = StreamController<YouTubeFrameEvent>.broadcast(sync: true);
  final _hide = StreamController<bool>.broadcast(sync: true);
  final _esc = StreamController<void>.broadcast(sync: true);

  /// Escape pressed on the page outside Flutter (after YouTube's controls).
  void pageEscape() => _esc.add(null);

  void emit(YouTubeFrameEvent e) => _events.add(e);
  void hide(bool on) {
    _hidden = on;
    _hide.add(on);
  }

  @override
  Widget view() => const ColoredBox(color: Colors.black, child: SizedBox.expand());
  @override
  Future<void> load(String videoId, Duration start) async => loads.add((videoId, start));
  @override
  void pause() => paused++;
  @override
  void dispose() => disposed = true;
  @override
  Stream<YouTubeFrameEvent> get events => _events.stream;
  @override
  Stream<bool> get hiddenChanges => _hide.stream;
  @override
  Stream<void> get escapes => _esc.stream;
  @override
  bool get hidden => _hidden;
}

class _Api {
  bool refuse = false;
  bool hasYouTube = false;
  bool dailyLimit = false;
  bool noChannels = false;
  bool needsSignIn = false;
  final calls = <String>[];
  final lastBody = <String, Object?>{};
  Map<String, String> lastQuery = {};

  /// The video the channel's schedule has on.
  String playing = 'a1';

  /// The long wait's answer, once Google has given one.
  Completer<Map<String, Object?>>? _wait;
  void approve() => _answer({
        'state': 'done',
        'serverKey': 's2',
        'color': {
          'key': 's2',
          'name': 'YouTube',
          'selected': 'wine',
          'palette': [
            {'name': 'wine', 'label': 'Wine', 'hex': '#7a1f3d'},
            {'name': 'blue', 'label': 'Blue', 'hex': '#1f4f9a'},
          ],
        },
      });
  void expire() => _answer({'state': 'expired', 'userCode': 'ABC-DEF-002', 'verificationUrl': 'https://www.google.com/device'});
  void _answer(Map<String, Object?> a) {
    final w = _wait;
    _wait = null;
    w?.complete(a);
  }

  late final client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    final key = '${request.method} $path';
    calls.add(key);
    lastQuery = request.url.queryParameters;
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    lastBody[key] = body;
    http.Response json(Object? data, {int status = 200}) =>
        http.Response(jsonEncode(data), status, headers: {'content-type': 'application/json', 'etag': '"p1"'});
    final subs = [
      {'id': 'UCa', 'title': 'Apples', 'checked': hasYouTube},
      {'id': 'UCb', 'title': 'Bananas', 'checked': hasYouTube},
      {'id': 'UCc', 'title': 'Cherries', 'checked': false},
    ];
    switch (key) {
      case 'GET auth':
        return json({'password': true, 'signedIn': true});
      case 'GET me':
        return json({'id': 'u1', 'name': 'sam', 'role': 'admin', 'profiles': ['p1'], 'needsPassword': false, 'grownUp': true});
      case 'GET profiles':
        return json([
          {'id': 'p1', 'name': 'Home', 'kind': 'adult', 'color': 1, 'hasPin': false, 'exported': true, 'signedIn': true},
        ]);
      case 'GET status':
        return json({'started': true, 'device': 'nas', 'host': 'nas.local', 'profiles': [], 'canStartFresh': false});
      case 'GET profiles/p1/channels':
        return json({'logoMode': 'nowAndThen', 'plan': {'mode': 'off'}, 'premieres': {}, 'channels': []});
      case 'GET profiles/p1/colors':
        return json({'on': false, 'palette': [], 'sources': []});
      case 'GET convert-helper':
        return json({'available': false});
      case 'GET profiles/p1/servers':
        return json({
          'servers': [
            {'key': 'main', 'main': true, 'name': 'Home', 'kind': 'jellyfin', 'url': 'http://jf', 'user': 'mom', 'state': 'ok', 'stateLabel': 'OK', 'qualityLimitKbps': null, 'episodes': 3, 'movies': 1, 'songs': 0},
            if (hasYouTube)
              {'key': 's2', 'main': false, 'name': 'YouTube', 'kind': 'youtube', 'url': 'https://www.youtube.com', 'user': 'Mom Cooks', 'state': 'ok', 'stateLabel': 'OK', 'qualityLimitKbps': null, 'episodes': 0, 'movies': 0, 'songs': 0, 'youtubeChannels': 2},
          ],
          'order': ['main', if (hasYouTube) 's2'],
        });
      case 'POST profiles/p1/servers':
        return json({'stage': 'server', 'busy': false, 'finished': false});
      case 'POST profiles/p1/youtube/start' || 'POST profiles/p1/servers/s2/youtube/client':
        if (refuse) {
          return json({'error': "Google didn't accept this client. It must be of the type TVs and Limited Input devices."}, status: 400);
        }
        return json({'run': 'run1', 'userCode': 'ABC-DEF-001', 'verificationUrl': 'https://www.google.com/device', 'expiresAt': '2026-11-24T12:00:00Z'});
      case 'GET profiles/p1/youtube/start/run1':
        final w = _wait = Completer();
        return json(await w.future);
      case 'DELETE profiles/p1/youtube/start/run1':
        _answer({'state': 'cancelled'});
        return json({'state': 'cancelled'});
      case 'GET profiles/p1/servers/s2/youtube/channels':
        return json({'subscriptions': subs});
      case 'PUT profiles/p1/servers/s2/youtube/channels':
        return json({'channels': []});
      case 'POST profiles/p1/youtube/start/run1/color':
        return json({'state': 'done', 'serverKey': 's2'});
      case 'DELETE profiles/p1/servers/s2':
        return json({'servers': [], 'order': []});
      case 'GET profiles/p1/youtube/channels':
        return json({
          'channels': noChannels
              ? []
              : [
                  {
                    'id': 'yt1',
                    'number': 501,
                    'name': 'Apples',
                    'serverKey': 's2',
                    'now': {'title': 'Apple pie'},
                    'next': {'title': 'Apple tart'},
                  }
                ],
          'notes': [
            if (dailyLimit) {'serverKey': 's2', 'kind': 'dailyLimit', 'text': "YouTube's daily limit is reached.", 'until': '2026-11-25T08:00:00Z'},
          ],
        });
      case 'GET profiles/p1/youtube/yt1/now':
        if (needsSignIn) return json({'error': 'Sign in to YouTube again', 'needs': 'signIn'}, status: 409);
        if (request.url.queryParameters['ended'] == 'a1') playing = 'a2';
        final first = playing == 'a1';
        return json({
          'channel': {'id': 'yt1', 'number': 501, 'name': 'Apples'},
          'videoId': first ? 'a1' : 'a2',
          'title': first ? 'Apple pie' : 'Apple tart',
          'offsetSeconds': first ? 125 : 0,
          'endsAt': '2026-11-24T12:00:00Z',
          'next': {'videoId': first ? 'a2' : 'a3', 'title': 'Next'},
        });
      case 'GET profiles/p1/channels/yt1/logo':
        return http.Response('', 404);
    }
    return json({'error': 'not found: $key'}, status: 404);
  });
}
