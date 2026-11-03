import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/retro.dart';
import 'package:nightingale_tv/web_admin/api_client.dart';
import 'package:nightingale_tv/web_admin/app.dart';
import 'package:nightingale_tv/web_admin/widgets/common.dart';

/// The web admin against a fake API (docker-web-admin 6.16). Runs on the
/// VM and with `flutter test --platform chrome`.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  Future<void> start(WidgetTester tester, {Size size = const Size(1280, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WebAdminApp(api: ApiClient(api.client, base: Uri.parse('http://nas.local:8484/'))));
    await tester.pumpAndSettle();
  }

  void go(WidgetTester tester, String path) =>
      AdminScope.of(tester.element(find.byType(Navigator).first)).router.go(path);

  group('shell', () {
    testWidgets('wide screens show the side navigation; phones a menu', (tester) async {
      api.signedIn = true;
      await start(tester);
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('Channels'), findsWidgets);
      expect(find.text('Users'), findsOneWidget, reason: 'admin pages for an admin');
      expect(find.byTooltip('Open navigation menu'), findsNothing);

      await start(tester, size: const Size(360, 780));
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Programming blocks'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'nothing overflows at 360 px');
    });

    testWidgets('a user sees no admin pages', (tester) async {
      api
        ..signedIn = true
        ..role = 'user';
      await start(tester);
      expect(find.text('Users'), findsNothing);
      expect(find.text('Backups'), findsNothing);
      expect(find.text('Live TV export'), findsNothing);
    });
  });

  group('sign-in', () {
    testWidgets('signing in with a name and password, then the page', (tester) async {
      await start(tester);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'User name'), 'sam');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong user name or password.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct horse');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.startsWith('POST session')), hasLength(2));
      expect(api.lastBody['session'], {'name': 'sam', 'password': 'correct horse'});
      expect(find.text('2  Sitcoms'), findsOneWidget, reason: "the signed-in profile's channels");
    });

    testWidgets('a server with no accounts only says to open the setup link', (tester) async {
      api.hasUsers = false;
      await start(tester);
      expect(find.text("Open the setup link from the server's log."), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a session that ends goes to sign-in, and back to the page after', (tester) async {
      api.signedIn = true;
      await start(tester);
      go(tester, '/profiles/p1/channels/c1');
      await tester.pumpAndSettle();
      api.signedIn = false;
      await tester.tap(find.widgetWithText(SwitchListTile, 'Favorite'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'User name'), 'sam');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct horse');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Name and number'), findsOneWidget, reason: 'back on the channel editor');
    });
  });

  group('channel editor', () {
    testWidgets('a change is sent with If-Match; a stale one shows the latest', (tester) async {
      api.signedIn = true;
      await start(tester);
      go(tester, '/profiles/p1/channels/c1');
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Laughs');
      await tester.tap(find.text('Save name and number'));
      await tester.pumpAndSettle();
      expect(api.lastBody['PUT profiles/p1/channels/c1'], {'name': 'Laughs', 'number': 2});
      expect(api.lastIfMatch, '"p1"');
      expect(find.text('2  Laughs'), findsOneWidget);

      // Someone else saved meanwhile.
      api.revision = 7;
      api.channel['name'] = 'Changed elsewhere';
      await tester.tap(find.widgetWithText(SwitchListTile, 'Hidden from the guide'));
      await tester.pumpAndSettle();
      expect(find.text('Changed in another window. Showing the latest.'), findsOneWidget);
      expect(find.text('2  Changed elsewhere'), findsOneWidget);
      expect(api.channel['hidden'], isFalse, reason: 'the stale change was refused');
    });
  });

  group('retro look', () {
    testWidgets('a channel\'s CRT effect is saved and shown, and Main setting follows again', (tester) async {
      api.signedIn = true;
      await start(tester);
      go(tester, '/profiles/p1/channels/c1');
      await tester.pumpAndSettle();
      final field = find.widgetWithText(DropdownButtonFormField<CrtStyle?>, 'CRT effect');
      await tester.scrollUntilVisible(field, 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining("They don't apply to Live TV export"), findsOneWidget);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arcade').last);
      await tester.pumpAndSettle();
      expect(api.lastBody['PUT profiles/p1/channels/c1'], {'retro': {'crt': 'arcade'}});
      expect(find.text('Arcade'), findsOneWidget);
      await tester.tap(find.widgetWithText(DropdownButtonFormField<CrtStyle?>, 'CRT effect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main setting (Off)').last);
      await tester.pumpAndSettle();
      expect(api.lastBody['PUT profiles/p1/channels/c1'], {'retro': <String, Object?>{}});
      expect(find.text('Effects on this device'), findsNothing);
    });
  });

  group('block editor', () {
    testWidgets('a block the lineup made says so, in the list and in its editor', (tester) async {
      api
        ..signedIn = true
        ..blocks = [
          {
            ...ProgramBlock(
              id: 'lineup:daytime:c1',
              title: 'Daytime',
              channelId: 'c1',
              days: {1, 2, 3, 4, 5, 6, 7},
              startMinute: 360,
              endMinute: 1080,
              source: const ChannelSource(),
              order: PlaybackOrder.cyclic,
              playlist: const [],
              anchor: DateTime(2026, 11, 3),
              generated: Daypart.daytime,
            ).toJson(),
            'view': {'describe': 'Every day  ·  6:00 AM – 6:00 PM', 'channel': 'Laugh Track', 'playlistLength': 0},
          },
        ];
      await start(tester);
      go(tester, '/profiles/p1/blocks');
      await tester.pumpAndSettle();
      expect(find.textContaining('From the lineup · Every day'), findsOneWidget);
      await tester.tap(find.text('Daytime'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Change anything and it becomes yours.'), findsOneWidget);
    });

    testWidgets('a new block is sent as the model, and the server\'s rule shows beside it', (tester) async {
      api.signedIn = true;
      await start(tester);
      go(tester, '/profiles/p1/blocks/new');
      await tester.pumpAndSettle();
      final pageList = find.descendant(of: find.byType(ProfileGate), matching: find.byType(Scrollable)).first;
      Future<void> save() async {
        await tester.scrollUntilVisible(find.text('Save'), 300, scrollable: pageList);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      }

      await save();
      expect(find.text('Give the block a title.'), findsOneWidget);
      await tester.scrollUntilVisible(find.widgetWithText(TextField, 'Title'), -300, scrollable: pageList);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Cartoons');
      await tester.scrollUntilVisible(find.text('Alpha (10)'), 300, scrollable: pageList);
      await tester.tap(find.text('Alpha (10)'));
      await tester.pumpAndSettle();
      await save();
      final sent = api.lastBody['POST profiles/p1/blocks']! as Map<String, Object?>;
      final block = ProgramBlock.fromJson(sent);
      expect(block.title, 'Cartoons');
      expect(block.source.seriesKeys, ['alpha']);
      expect(block.days, {DateTime.saturday});
      expect(sent['lineupMode'], isFalse);
      expect(find.text('Programming blocks'), findsWidgets, reason: 'back on the list');
    });

    Finder pageList() => find.descendant(of: find.byType(ProfileGate), matching: find.byType(Scrollable)).first;

    Future<void> save(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.text('Save'), 300, scrollable: pageList());
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets("the late-night shortcut fills in the editor with the channel's source and order", (tester) async {
      api
        ..signedIn = true
        ..channel['order'] = 'weighted';
      await start(tester);
      go(tester, '/profiles/p1/blocks');
      await tester.pumpAndSettle();
      await tester.tap(find.text('New late-night block'));
      await tester.pumpAndSettle();
      expect(find.text('New late-night block'), findsOneWidget, reason: 'the editor is open');
      await save(tester);
      final block = ProgramBlock.fromJson(api.lastBody['POST profiles/p1/blocks']! as Map<String, Object?>);
      expect((block.title, block.startMinute, block.endMinute, block.order), ('Late Night', 23 * 60, 4 * 60, PlaybackOrder.weighted));
      expect(block.days, {1, 2, 3, 4, 5, 6, 7});
      expect(block.source.seriesKeys, ['alpha']);
      expect(block.source.ratingFloor, RatingFloor.mature);
    });

    testWidgets('the minimum rating stays when shows are picked again', (tester) async {
      api.signedIn = true;
      await start(tester);
      go(tester, '/profiles/p1/blocks/new');
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Prime');
      final floor = find.widgetWithText(DropdownButtonFormField<RatingFloor?>, 'Minimum rating');
      await tester.scrollUntilVisible(floor, 300, scrollable: pageList());
      await tester.tap(floor);
      await tester.pumpAndSettle();
      await tester.tap(find.text(RatingFloor.teen.label).last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Alpha (10)'), -300, scrollable: pageList());
      await tester.tap(find.text('Alpha (10)'));
      await tester.pumpAndSettle();
      await save(tester);
      final block = ProgramBlock.fromJson(api.lastBody['POST profiles/p1/blocks']! as Map<String, Object?>);
      expect(block.source.seriesKeys, ['alpha']);
      expect(block.source.ratingFloor, RatingFloor.teen);
    });

    testWidgets('kid profiles get no shortcut and no minimum rating', (tester) async {
      api
        ..signedIn = true
        ..kidProfile = true;
      await start(tester);
      go(tester, '/profiles/p1/blocks');
      await tester.pumpAndSettle();
      expect(find.text('New late-night block'), findsNothing);
      go(tester, '/profiles/p1/blocks/late-night');
      await tester.pumpAndSettle();
      expect(find.text('Minimum rating'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Late');
      await tester.scrollUntilVisible(find.text('Alpha (10)'), 300, scrollable: pageList());
      await tester.tap(find.text('Alpha (10)'));
      await tester.pumpAndSettle();
      await save(tester);
      final block = ProgramBlock.fromJson(api.lastBody['POST profiles/p1/blocks']! as Map<String, Object?>);
      expect(block.source.ratingFloor, isNull, reason: 'no shortcut defaults on a kid profile');
    });
  });
}

/// An in-memory `/api/v1/` with one admin, one profile, one channel.
class FakeApi {
  bool hasUsers = true;
  bool signedIn = false;
  String role = 'admin';
  bool kidProfile = false;

  /// The profile's blocks, as the server lists them.
  List<Map<String, Object?>> blocks = [];
  int revision = 1;
  final calls = <String>[];
  final lastBody = <String, Object?>{};
  String? lastIfMatch;

  final channel = <String, Object?>{
    ...Channel(
      id: 'c1',
      number: 2,
      name: 'Sitcoms',
      icon: const ChannelIcon.builtin('tv'),
      source: const ChannelSource(seriesKeys: ['alpha']),
      order: PlaybackOrder.cyclic,
      playlist: const [],
      anchor: DateTime.utc(2026, 10, 24),
    ).toJson(),
  };

  Map<String, Object?> get channelView => {
        ...channel,
        'view': {'playlistLength': 10, 'auto': true, 'music': false, 'logoMode': 'nowAndThen', 'plan': {'mode': 'off'}},
      };

  late final client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    final key = '${request.method} $path';
    calls.add(key);
    lastIfMatch = request.headers['If-Match'] ?? lastIfMatch;
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    lastBody[path == 'session' ? 'session' : key] = body;
    http.Response json(Object? data, {int status = 200}) => http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json', 'etag': path.startsWith('profiles/p1/') ? '"p$revision"' : '"h1"'});
    if (request.method != 'GET' && request.headers['X-Nightingale-TV'] != '1') return json({'error': 'no header'}, status: 403);
    if (key == 'GET auth') return json({'password': hasUsers, 'signedIn': signedIn});
    if (key == 'POST session') {
      final ok = (body as Map)['password'] == 'correct horse';
      if (ok) signedIn = true;
      return ok ? json({'ok': true}) : json({'error': 'Wrong user name or password.'}, status: 403);
    }
    if (!signedIn) return json({'error': 'Sign in first.'}, status: 401);
    if ((request.method == 'PUT' || request.method == 'DELETE') && request.headers['If-Match'] != '"p$revision"' &&
        path.startsWith('profiles/p1/')) {
      return json({'error': 'Changed in another window. Showing the latest.', 'current': channelView}, status: 409);
    }
    switch (key) {
      case 'GET me':
        return json({'id': 'u1', 'name': 'sam', 'role': role, 'profiles': ['p1'], 'needsPassword': false, 'grownUp': true});
      case 'GET profiles':
        return json([
          {'id': 'p1', 'name': 'Home', 'kind': 'adult', 'color': 1, 'hasPin': false, 'exported': true, 'signedIn': true},
        ]);
      case 'GET status':
        return json({'started': true, 'device': 'nas', 'host': 'nas.local', 'profiles': [], 'canStartFresh': false});
      case 'GET profiles/p1/channels':
        return json({'logoMode': 'nowAndThen', 'plan': {'mode': 'off'}, 'premieres': {}, 'channels': [channelView]});
      case 'GET profiles/p1/channels/c1':
        return json(channelView);
      case 'PUT profiles/p1/channels/c1':
        channel.addAll((body as Map).cast<String, Object?>());
        revision++;
        return json(channelView);
      case 'GET profiles/p1/commercials':
        return json({'plan': {'mode': 'off'}, 'pools': [], 'clips': 0, 'channels': []});
      case 'GET profiles/p1/blocks':
        return json({
          'blocks': blocks,
          'kidProfile': kidProfile,
          'newBlock': ProgramBlock(
            id: 'block:new',
            title: '',
            channelId: 'c1',
            days: {DateTime.saturday},
            startMinute: 420,
            endMinute: 720,
            source: const ChannelSource(includeEpisodes: false),
            order: PlaybackOrder.cyclic,
            playlist: const [],
            anchor: DateTime(2026, 10, 24),
          ).toJson(),
        });
      case 'GET profiles/p1/library/catalog':
        return json({
          'shows': [
            {'key': 'alpha', 'id': 's1', 'name': 'Alpha', 'episodes': 10},
          ],
          'genres': ['comedy'],
          'movies': 0,
          'songs': 0,
          'musicVideos': 0,
          'musicGenres': [],
          'decades': [],
        });
      case 'POST profiles/p1/blocks/preview':
        return json({'total': 10, 'items': [], 'problem': null});
      case 'POST profiles/p1/blocks':
        final b = (body as Map).cast<String, Object?>();
        if ((b['title'] as String).isEmpty) return json({'error': 'Give the block a title.'}, status: 400);
        return json({...b, 'view': {'describe': 'Sat', 'channel': 'Sitcoms'}});
    }
    return json({'error': 'Not found.'}, status: 404);
  });
}
