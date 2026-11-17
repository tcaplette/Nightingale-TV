import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/share_service.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/sharing_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'backup_fixtures.dart';
import 'fake_playback.dart';
import 'fixtures.dart';
import 'sharing_fakes.dart';

void main() {
  late Directory dir;
  late Household h;
  late Tuner tuner;
  late FakeShareBackend backend;
  ShareService? service;

  /// Lets real work (files, the fake backend, JSON isolates) move on.
  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Mom and Kids, [watching] in front; sharing on, with the fake backend,
  /// unless [sharing] is false.
  Future<void> setUpHousehold(WidgetTester tester, {String watching = 'Mom', bool sharing = true, Size? window}) async {
    tester.view.physicalSize = window ?? const Size(3200, 4000);
    tester.view.devicePixelRatio = window == null ? 1 : 2.625;
    addTearDown(tester.view.reset);
    backend = FakeShareBackend();
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_sharing_screen');
      await writeHousehold(dir, momAndKids(), fakeLibrary(), logos: 0);
      h = await openHousehold(dir);
      await h.select(h.profiles.firstWhere((p) => p.name == watching));
      if (sharing) {
        service = h.sharing = ShareService(h, h.root,
            url: 'https://share.test',
            key: 'sb_publishable_test',
            host: 'share.example',
            httpClient: backend.client,
            watchLifecycle: false);
        await service!.load();
      }
    });
    tuner = Tuner(h.app!, player: FakePlayer([]));
    addTearDown(() async {
      tuner.dispose();
      await tester.runAsync(() async {
        h.leave();
        h.backups!.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await dir.delete(recursive: true);
      });
    });
  }

  Future<void> show(WidgetTester tester, Widget screen, {bool canvas = false}) async {
    await tester.pumpWidget(HouseholdScope(
      household: h,
      child: AppScope(
        app: h.app!,
        tuner: tuner,
        child: MaterialApp(
          theme: GuideTheme.cableGuide.toThemeData(),
          // The app's canvas gives every screen its Material.
          builder: canvas
              ? (context, child) => TvCanvas(child: child!)
              : (context, child) => Material(type: MaterialType.transparency, child: child),
          home: screen,
        ),
      ),
    ));
    await settle(tester);
  }

  /// Takes the screen down and stops sharing's timers before the test ends.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      h.sharing = null;
      service?.dispose();
      service = null;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }

  String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

  bool fieldFocused(String label) =>
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvTextField>()?.label == label;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key, [int rounds = 3]) async {
    await tester.sendKeyEvent(key);
    await settle(tester, rounds);
  }

  /// Down until the button [label] has focus (at most [max] presses).
  Future<void> downTo(WidgetTester tester, String label, {int max = 40}) async {
    for (var i = 0; i < max && focused() != label; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown, 1);
    }
    expect(focused(), label);
  }

  /// The focused field's text, typed (the on-screen keyboard's job).
  Future<void> type(WidgetTester tester, String text) async {
    final field = find.descendant(
        of: find.byWidgetPredicate((w) => w is TvTextField && fieldFocused(w.label)), matching: find.byType(EditableText));
    await tester.enterText(field, text);
    await settle(tester, 2);
  }

  group('menu', () {
    testWidgets('an adult profile has Sharing', (tester) async {
      await setUpHousehold(tester);
      await show(tester, const MenuScreen());
      expect(find.text('Sharing'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a kid profile has no Sharing entry', (tester) async {
      await setUpHousehold(tester, watching: 'Kids');
      await show(tester, const MenuScreen());
      expect(find.text('Sharing'), findsNothing);
      await finish(tester);
    });

    testWidgets('no entry when this build has no sharing', (tester) async {
      await setUpHousehold(tester, sharing: false);
      await show(tester, const MenuScreen());
      expect(find.text('Sharing'), findsNothing);
      await finish(tester);
    });
  });

  testWidgets('the D-pad goes through setup and Add friend with Select alone', (tester) async {
    await setUpHousehold(tester);
    await show(tester, const SharingScreen());
    expect(find.text('No video is ever sent between users.'), findsOneWidget);
    expect(focused(), 'Set up');
    await press(tester, LogicalKeyboardKey.enter);

    // Email, then Send code.
    expect(fieldFocused('Email'), isTrue);
    await type(tester, 'sam@example.com');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'Send code');
    await press(tester, LogicalKeyboardKey.enter, 6);

    // The code: a wrong one first.
    expect(find.text('We sent a 6-digit code to sam@example.com. Enter it here.'), findsOneWidget);
    expect(fieldFocused('6-digit code'), isTrue);
    expect(find.textContaining('Send a new code ('), findsOneWidget, reason: 'not for 60 seconds');
    await type(tester, '000000');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'Sign in');
    await press(tester, LogicalKeyboardKey.enter, 6);
    expect(find.text('That code isn\'t right'), findsOneWidget);
    await tester.tap(find.byType(EditableText));
    await settle(tester, 2);
    await type(tester, FakeShareBackend.otp);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'Sign in');
    await press(tester, LogicalKeyboardKey.enter, 10);

    // The share profile: the profile's name suggested; a taken handle refused.
    expect(find.text('Your share profile'), findsOneWidget);
    expect(fieldFocused('Display name'), isTrue);
    expect(find.text('Mom'), findsWidgets);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(fieldFocused('Handle'), isTrue);
    await type(tester, 'Tyler');
    await settle(tester, 8);
    expect(find.text('That handle is taken.'), findsOneWidget);
    await type(tester, 'mom_tv');
    await settle(tester, 8);
    expect(find.text('That handle is taken.'), findsNothing);
    await downTo(tester, 'Save');
    await press(tester, LogicalKeyboardKey.enter, 12);

    // Show what I'm watching, the last step of setup: Friends first.
    expect(find.text('Let your friends see what you\'re watching?'), findsOneWidget);
    expect(focused(), 'Friends');
    await press(tester, LogicalKeyboardKey.enter, 12);
    expect(backend.profile!['presence'], 'friends');

    // Linked: the code three ways, and Enter a code focused.
    expect(find.text('@mom_tv'), findsOneWidget);
    expect(find.text('AB3K·9Q'), findsOneWidget);
    expect(find.text('https://share.example/ntv/i/AB3K9Q'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Send invite'), findsNothing, reason: 'not on a TV or a PC');
    expect(focused(), 'Enter a code');
    await press(tester, LogicalKeyboardKey.enter);
    expect(fieldFocused('Friend\'s code'), isTrue);
    await type(tester, 'xy7z 2m');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'Cancel');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Add');
    await press(tester, LogicalKeyboardKey.enter, 8);

    // The confirmation: Cancel first, so a double press adds no one.
    expect(find.text('Add Tyler (@tyler) as a friend?'), findsOneWidget);
    expect(focused(), 'Cancel');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Add');
    await press(tester, LogicalKeyboardKey.enter, 10);
    expect(find.text('You and Tyler are friends now.'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter, 4);
    expect(find.text('Tyler  @tyler', findRichText: true), findsOneWidget);
    expect(backend.friends.single.handle, 'tyler');

    // New code replaces the shown one.
    expect(focused(), 'Enter a code', reason: 'focus comes back where it was');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'New code');
    await press(tester, LogicalKeyboardKey.enter, 8);
    expect(find.text('NEW2·CD'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an air mouse or touch taps through, and every refusal is said', (tester) async {
    await setUpHousehold(tester);
    await show(tester, const SharingScreen());
    await tester.tap(find.text('Set up'));
    await settle(tester);
    expect(fieldFocused('Email'), isTrue, reason: 'the tapped button is gone; the new step takes focus');
    await tester.enterText(find.byType(EditableText), 'not an email');
    await tester.tap(find.text('Send code'));
    await settle(tester);
    expect(find.text('Enter an email address, such as name@example.com.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'sam@example.com');
    await tester.tap(find.text('Send code'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText), FakeShareBackend.otp);
    await tester.tap(find.text('Sign in'));
    await settle(tester, 12);
    await tester.tap(find.text('Save'));
    await settle(tester, 12);
    await tester.tap(find.text('Off'));
    await settle(tester, 12);
    expect(backend.profile!['presence'], 'off');
    expect(find.text('AB3K·9Q'), findsOneWidget);
    expect(find.text('Show what I\'m watching: Off'), findsOneWidget);

    Future<String> enter(String code) async {
      await tester.tap(find.text('Enter a code'));
      await settle(tester, 3);
      await tester.enterText(find.byType(EditableText).last, code);
      await tester.tap(find.text('Add').last);
      await settle(tester, 8);
      final message = tester.widgetList<Text>(find.descendant(of: find.byType(Dialog), matching: find.byType(Text)))
          .map((t) => t.data)
          .whereType<String>()
          .join(' | ');
      if (find.text('OK').evaluate().isNotEmpty) {
        await tester.tap(find.text('OK'));
        await settle(tester, 3);
      }
      return message;
    }

    expect(await enter('ab3k.9q'), contains('That\'s your own code'));
    expect(await enter('GGGGGG'), contains('This invite has expired or was already used'));
    expect(await enter('MMMMMM'), contains('Too many tries. Try again later'));
    expect(await enter('ZZZZZZ'), contains('This invite has expired or was already used'));
    await tester.tap(find.text('Enter a code'));
    await settle(tester, 3);
    await tester.enterText(find.byType(EditableText).last, 'nope');
    await tester.tap(find.text('Add').last);
    await settle(tester, 3);
    expect(find.text('A code has 6 letters and numbers, such as AB3K·9Q.'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await settle(tester, 3);

    // A friend added, removed, added again and blocked, all by tapping.
    Future<void> tap(String text, {bool rich = false}) async {
      await tester.tap(find.text(text, findRichText: rich).last);
      await settle(tester, 6);
    }

    expect(await enter('XY7Z2M'), contains('Add Tyler (@tyler) as a friend?'));
    await tap('Add');
    expect(find.text('You and Tyler are friends now.'), findsOneWidget);
    await tap('OK');
    await tap('Tyler  @tyler', rich: true);
    await tap('Remove friend');
    expect(find.text('Remove Tyler as a friend? You both stop being friends.'), findsOneWidget);
    await tap('Remove');
    expect(find.text('No friends yet. Share your code to add one.'), findsOneWidget);
    expect(backend.friends, isEmpty);

    backend.codes['XY7Z2M'] = backend.friends.isEmpty
        ? const ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler', avatar: 'owl', avatarColor: 1)
        : InviteStatus.gone;
    await enter('XY7Z2M');
    await tap('Add');
    await tap('OK');
    await tap('Tyler  @tyler', rich: true);
    await tap('Block');
    await tap('Block');
    expect(find.text('Blocked'), findsOneWidget);
    expect(backend.blocked.single.handle, 'tyler');
    await tap('Tyler  @tyler', rich: true);
    await tap('Unblock');
    expect(backend.blocked, isEmpty);
    expect(find.text('Blocked'), findsNothing);
    await finish(tester);
  });

  testWidgets('a linked profile opens Sharing with Enter a code focused', (tester) async {
    await setUpHousehold(tester);
    backend.profile = {
      'user_id': FakeShareBackend.userId,
      'presence': 'friends',
      'display_name': 'Mom',
      'handle': 'mom_tv',
      'avatar': 'fox',
      'avatar_color': 0,
      'station': '',
    };
    await tester.runAsync(() async {
      final c = await service!.setUp(h.current!);
      await c!.verifyCode('sam@example.com', FakeShareBackend.otp);
    });
    await show(tester, const SharingScreen());
    await settle(tester, 6);
    expect(find.text('AB3K·9Q'), findsOneWidget);
    expect(focused(), 'Enter a code', reason: 'a remote has a control to start on');

    // Deleting: the confirmation names what goes; afterwards Set up has focus.
    await tester.tap(find.text('Delete sharing account'));
    await settle(tester, 3);
    expect(find.textContaining('your share profile (@mom_tv)'), findsOneWidget);
    expect(focused(), 'Cancel');
    await tester.tap(find.text('Delete').last);
    await settle(tester, 8);
    expect(find.text('Your sharing account was deleted.'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter, 6);
    expect(focused(), 'Set up');
    expect(service!.store.isLinked(h.current!.id), isFalse);
    expect(backend.requests, contains('POST /functions/v1/delete-account'));
    await finish(tester);
  });

  testWidgets('linked before friend presence: asked first, Friends focused; Friends lines update live', (tester) async {
    await setUpHousehold(tester);
    backend.profile = {
      'user_id': FakeShareBackend.userId,
      'display_name': 'Mom',
      'handle': 'mom_tv',
      'avatar': 'fox',
      'avatar_color': 0,
      'station': '',
    };
    const tyler = ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler', avatar: 'owl', avatarColor: 1);
    backend.friends.add(tyler);
    await tester.runAsync(() async {
      final c = await service!.setUp(h.current!);
      await c!.verifyCode('sam@example.com', FakeShareBackend.otp);
    });
    await show(tester, const SharingScreen());
    await settle(tester, 6);
    expect(find.text('Let your friends see what you\'re watching?'), findsOneWidget);
    expect(find.text('AB3K·9Q'), findsNothing, reason: 'asked before anything else');
    expect(focused(), 'Friends');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Off');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.enter, 12);
    expect(backend.profile!['presence'], 'friends');
    expect(find.text('Show what I\'m watching: Friends'), findsOneWidget);
    expect(focused(), 'Enter a code');

    // Tyler starts watching while the list is open, then stops.
    await tester.runAsync(() async {
      await service!.presence.attach(service!.active, h.app);
      await pumpEventQueue();
    });
    await settle(tester, 4);
    backend.friendWatching(tyler, title: 'The Office', channel: '90s Sitcoms', sharedId: 'sc-1');
    await settle(tester, 2);
    expect(find.text('Watching The Office on 90s Sitcoms'), findsOneWidget);
    backend.friendStopped(tyler);
    await settle(tester, 2);
    expect(find.text('Watching The Office on 90s Sitcoms'), findsNothing);

    // The setting can be changed here at any time.
    await tester.tap(find.text('Show what I\'m watching: Friends'));
    await settle(tester, 4);
    expect(focused(), 'Friends', reason: 'the current choice');
    await tester.tap(find.text('Off').last);
    await settle(tester, 8);
    expect(backend.profile!['presence'], 'off');
    expect(find.text('Show what I\'m watching: Off'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('upright on a phone: one column, nothing cut off or overflowing', (tester) async {
    await setUpHousehold(tester, window: const Size(1080, 2400));
    backend.profile = {
      'user_id': FakeShareBackend.userId,
      'presence': 'friends',
      'display_name': 'Mom',
      'handle': 'mom_tv',
      'avatar': 'fox',
      'avatar_color': 0,
      'station': 'Mom TV',
    };
    await tester.runAsync(() async {
      final c = await service!.setUp(h.current!);
      await c!.verifyCode('sam@example.com', FakeShareBackend.otp);
    });
    await show(tester, const SharingScreen(), canvas: true);
    await settle(tester, 6);
    expect(find.text('AB3K·9Q'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final element in find.byType(TvFocusable).evaluate()) {
      final box = element.renderObject! as RenderBox;
      if (!box.hasSize || !box.attached) continue;
      final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
      expect(rect.left, greaterThanOrEqualTo(-0.5));
      expect(rect.right, lessThanOrEqualTo(window.width + 0.5));
    }
    await finish(tester);
  });

  testWidgets('an invite link on a kid profile says to switch; on an adult it opens the confirmation', (tester) async {
    await setUpHousehold(tester, watching: 'Kids');
    final navigator = GlobalKey<NavigatorState>();
    // Stands for the TV screen arriving under the message and taking focus.
    final under = FocusNode(debugLabel: 'tv screen');
    addTearDown(under.dispose);
    Future<void> host() async {
      await tester.pumpWidget(HouseholdScope(
        household: h,
        child: AppScope(
          app: h.app!,
          tuner: tuner,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: GuideTheme.cableGuide.toThemeData(),
            builder: (context, child) => SharingInviteHost(
                household: h, navigator: navigator, child: Material(type: MaterialType.transparency, child: child)),
            home: Focus(focusNode: under, child: const SizedBox()),
          ),
        ),
      ));
      await settle(tester);
    }

    await host();
    service!.pendingCode.value = 'XY7Z2M';
    await settle(tester);
    expect(find.text('Switch to an adult profile to add friends.'), findsOneWidget);
    expect(focused(), 'OK');
    under.requestFocus();
    await settle(tester, 2);
    expect(focused(), 'OK', reason: 'the remote can still reach the message');
    expect(service!.pendingCode.value, 'XY7Z2M', reason: 'kept for an adult profile');
    await tester.tap(find.text('OK'));
    await settle(tester);

    // Mom, not set up yet: Sharing opens on setup and keeps the code.
    await tester.runAsync(() => h.select(h.profiles.firstWhere((p) => p.name == 'Mom')));
    tuner.dispose();
    tuner = Tuner(h.app!, player: FakePlayer([]));
    await host();
    await settle(tester);
    expect(find.text('Set up'), findsOneWidget);
    expect(service!.pendingCode.value, 'XY7Z2M');
    await tester.tap(find.text('Set up'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText), 'sam@example.com');
    await tester.tap(find.text('Send code'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText), FakeShareBackend.otp);
    await tester.tap(find.text('Sign in'));
    await settle(tester, 12);
    await tester.tap(find.text('Save'));
    await settle(tester, 12);
    // Show what I'm watching, then the confirmation for the link's code.
    expect(find.text('Add Tyler (@tyler) as a friend?'), findsNothing);
    await tester.tap(find.text('Friends'));
    await settle(tester, 16);
    expect(find.text('Add Tyler (@tyler) as a friend?'), findsOneWidget);
    expect(service!.pendingCode.value, isNull);
    await finish(tester);
  });
}
