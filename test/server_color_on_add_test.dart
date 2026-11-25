import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/ui/guide_color_screen.dart';
import 'package:nightingale_tv/ui/login_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fixtures.dart';
import 'multi_server_fakes.dart';
import 'portrait_harness.dart';

/// Add a server ends with its guide colour (server-color-on-add).
void main() {
  ServerInfo infoOf(FakeServer s) => ServerInfo(kind: ServerKind.jellyfin, id: s.serverId, name: s.name, version: '10.11', url: s.url);

  /// A flow on [app] that finds [server] at any address.
  SignInFlow flowTo(AppState app, FakeServer server, {bool adding = true, String? againKey}) =>
      SignInFlow(app, adding: adding, againKey: againKey, identify: (_) async => (client: server.client, info: infoOf(server)));

  /// Address, password: the sign-in done.
  Future<void> signIn(SignInFlow flow) async {
    await flow.connect('b.example');
    flow.choosePassword();
    await flow.signInWithPassword('dad', 'pw');
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('the flow', () {
    late Directory dir;
    late AppState app;
    late FakeServer basement;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('server_color_on_add');
      app = await signedInApp(dir, fakeLibrary());
      basement = FakeServer('Basement', items: renamed(fakeItems(shows: const {'Zed': 4}), 'b'), url: 'http://b.example', serverId: 'b');
    });
    tearDown(() async {
      // The added server's library is read in the background.
      await until(() => !app.isRefreshingLibrary);
      await app.close();
      await dir.delete(recursive: true);
    });

    test('adding a server ends on its colour, with the suggestion; a choice is saved and finishes', () async {
      final flow = flowTo(app, basement);
      addTearDown(flow.dispose);
      await signIn(flow);
      expect(app.servers.all, hasLength(2), reason: 'the server is added before its colour is asked');
      expect(flow.step.stage, SignInStage.color);
      expect(flow.finished, isFalse);
      final key = flow.step.colorKey!;
      expect(app.servers.byKey(key)!.name, 'Basement');
      // Jellyfin's purple is the main server's: the next unused one.
      expect(app.serverColors[key]!.name, 'green');
      await flow.chooseColor('wine');
      expect(flow.finished, isTrue);
      expect(app.settings.serverColors[key], 'wine');
      expect(app.serverColors[key]!.name, 'wine');
    });

    test("removing a server forgets its colour", () async {
      final flow = flowTo(app, basement);
      addTearDown(flow.dispose);
      await signIn(flow);
      final key = flow.step.colorKey!;
      await flow.chooseColor('wine');
      await until(() => !app.isRefreshingLibrary);
      await app.removeServer(key);
      expect(app.settings.serverColors.containsKey(key), isFalse);
    });

    test('an unknown colour changes nothing', () async {
      final flow = flowTo(app, basement);
      addTearDown(flow.dispose);
      await signIn(flow);
      await flow.chooseColor('yellow');
      expect(flow.finished, isFalse);
      expect(flow.step.stage, SignInStage.color);
      expect(app.settings.serverColors, isEmpty);
    });

    test('Back on the colour step keeps the suggestion and finishes; the server stays', () async {
      final flow = flowTo(app, basement);
      addTearDown(flow.dispose);
      await signIn(flow);
      final key = flow.step.colorKey!;
      flow.back();
      await until(() => flow.finished);
      expect(flow.finished, isTrue);
      expect(app.servers.byKey(key), isNotNull);
      expect(app.settings.serverColors[key], 'green');
    });

    test('closed on the colour step: the server keeps its suggestion', () async {
      final flow = flowTo(app, basement);
      await signIn(flow);
      final key = flow.step.colorKey!;
      flow.dispose();
      await until(() => app.settings.serverColors[key] != null);
      expect(app.settings.serverColors[key], 'green');
      expect(app.servers.byKey(key), isNotNull);
    });

    test('with server colours off there is no colour step', () async {
      await app.setGuideServerColors(false);
      final flow = flowTo(app, basement);
      addTearDown(flow.dispose);
      await signIn(flow);
      expect(app.servers.all, hasLength(2));
      expect(flow.finished, isTrue);
      expect(flow.step.stage, isNot(SignInStage.color));
    });

    test('Sign in again has no colour step, and the server keeps its colour', () async {
      final add = flowTo(app, basement);
      await signIn(add);
      final key = add.step.colorKey!;
      await add.chooseColor('olive');
      add.dispose();
      final again = flowTo(app, basement, adding: false, againKey: key);
      addTearDown(again.dispose);
      await signIn(again);
      expect(again.finished, isTrue);
      expect(again.step.stage, isNot(SignInStage.color));
      expect(app.serverColors[key]!.name, 'olive');
    });
  });

  test('the first sign-in has no colour step', () async {
    final dir = await Directory.systemTemp.createTemp('server_color_first');
    final app = AppState(await AppStorage.at(dir), runAnalysis: false);
    await app.start();
    addTearDown(() async {
      await until(() => !app.isRefreshingLibrary);
      await app.close();
      await dir.delete(recursive: true);
    });
    final home = FakeServer('Home', items: fakeItems(), url: 'http://home.example', serverId: 'h');
    final flow = flowTo(app, home, adding: false);
    addTearDown(flow.dispose);
    await signIn(flow);
    expect(flow.finished, isTrue);
    expect(flow.step.stage, isNot(SignInStage.color));
    expect(app.settings.serverColors, isEmpty);
  });

  group('the screen', () {
    late SignInFlow flow;
    late FakeServer basement;

    Future<PortraitHarness> open(WidgetTester tester, Size size) async {
      setWindow(tester, size);
      final h = await PortraitHarness.start(tester);
      basement = FakeServer('Basement', items: renamed(fakeItems(shows: const {'Zed': 4}), 'b'), url: 'http://b.example', serverId: 'b');
      // Over a page, as Servers opens it, so returning shows.
      await h.show(
          tester,
          Builder(
              builder: (context) => Center(
                  child: TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => LoginScreen(
                              adding: true,
                              identify: (_) async => (client: basement.client, info: infoOf(basement)),
                              prepareFlow: (f) => flow = f))),
                      child: const Text('Servers')))));
      await tester.tap(find.text('Servers'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => signIn(flow));
      await settleUntil(tester, () => flow.step.stage == SignInStage.color);
      return h;
    }

    String? focusedColor() {
      final toggle = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvToggle>();
      return (toggle?.key as ValueKey<String>?)?.value;
    }

    testWidgets('TV: the step lists every colour, the suggestion focused, a colour in use named; the D-pad chooses',
        (tester) async {
      runAs(TargetPlatform.android, television: true);
      final h = await open(tester, const Size(1920, 1080));
      expect(flow.step.stage, SignInStage.color);
      expect(find.byType(GuideColorList), findsOneWidget);
      expect(find.text(tr.guideColorTitle('Basement')), findsOneWidget);
      expect(find.text(tr.guideColorHelp), findsOneWidget);
      for (final c in ServerColor.palette) {
        expect(find.byKey(ValueKey('color-${c.name}')), findsOneWidget);
      }
      expect(focusedColor(), 'color-green');
      final main = h.app.sourceName(h.app.servers.main.key)!;
      expect(find.text(tr.guideColorUsedBy(tr.colorPurple, main)), findsOneWidget);
      // Down three: green → amber → teal → magenta.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      expect(focusedColor(), 'color-magenta');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await settleUntil(tester, () => find.byType(LoginScreen).evaluate().isEmpty);
      expect(flow.finished, isTrue);
      expect(find.byType(LoginScreen), findsNothing, reason: 'back to Servers');
      final key = h.app.servers.all.last.key;
      expect(h.app.settings.serverColors[key], 'magenta');
    });

    testWidgets('TV: Back keeps the suggestion and returns', (tester) async {
      runAs(TargetPlatform.android, television: true);
      final h = await open(tester, const Size(1920, 1080));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleUntil(tester, () => find.byType(LoginScreen).evaluate().isEmpty);
      expect(find.byType(LoginScreen), findsNothing);
      expect(h.app.settings.serverColors[h.app.servers.all.last.key], 'green');
    });

    testWidgets('phone: a tap chooses a colour', (tester) async {
      runAs(TargetPlatform.android);
      final h = await open(tester, narrowPhone);
      expect(find.byType(GuideColorList), findsOneWidget);
      final olive = find.byKey(const ValueKey('color-olive'));
      await tester.ensureVisible(olive);
      await tester.pumpAndSettle();
      await tester.tap(olive);
      await settleUntil(tester, () => find.byType(LoginScreen).evaluate().isEmpty);
      expect(find.byType(LoginScreen), findsNothing);
      expect(h.app.settings.serverColors[h.app.servers.all.last.key], 'olive');
    });

    testWidgets("the server's Guide colour screen is unchanged: choosing returns", (tester) async {
      runAs(TargetPlatform.android, television: true);
      setWindow(tester, const Size(1920, 1080));
      final h = await PortraitHarness.start(tester);
      final other = FakeServer('Attic', items: fakeItems(), url: 'http://a.example', serverId: 'a');
      await tester.runAsync(() => h.app.addServer(other.session, other.client, refresh: false));
      final key = h.app.servers.all.last.key;
      await h.show(
          tester,
          Builder(
              builder: (context) => Center(
                  child: TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GuideColorScreen(sourceKey: key))),
                      child: const Text('Servers')))));
      await tester.tap(find.text('Servers'));
      await tester.pumpAndSettle();
      expect(focusedColor(), 'color-green');
      await tester.tap(find.byKey(const ValueKey('color-cocoa')));
      await settle(tester);
      expect(find.byType(GuideColorScreen), findsNothing);
      expect(h.app.settings.serverColors[key], 'cocoa');
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    // Page transitions run on the test clock.
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// [settle]s until [done]: the saves and the sign-in are real async work,
/// which a loaded machine slows down.
Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
  var i = 0;
  do {
    await settle(tester);
  } while (!done() && ++i < 100);
}
