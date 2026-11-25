// youtube-shared-client 4.2, 4.3: the picker's limit applies on Nightingale
// TV's client only ("n of 5", greyed rows that say where to go), never on an
// own client; Use Nightingale TV's client is greyed with too many channels.
// D-pad, pointer and touch.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/server/youtube/youtube_api.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';
import 'package:nightingale_tv/ui/youtube_screens.dart';

final subs = [
  for (var i = 0; i < 8; i++) YouTubeSubscription(channelId: 'UC$i', title: 'Channel $i'),
];

void main() {
  late List<YouTubeSubscription>? done;

  Future<void> pick(WidgetTester tester, {required int? others}) async {
    tester.view.physicalSize = const Size(1920, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    done = null;
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: Scaffold(
        body: YouTubePicker(subscriptions: subs, current: const [], others: others, onDone: (p) => done = p),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder row(int i) => find.byKey(ValueKey('UC$i'));
  bool enabled(WidgetTester tester, int i) => tester.widget<YouTubeCheckRow>(row(i)).onPressed != null;
  String count(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('picked-count'))).data!;
  final limitText = tr.youTubeSharedLimit(AppState.youTubeSharedLimit);

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pumpAndSettle();
  }

  testWidgets('D-pad: "3 of 5", two more checked, then the rest greyed and skipped', (tester) async {
    await pick(tester, others: 3);
    expect(count(tester), tr.youTubePickedOf(3, 5));
    // Focus starts on Done; down to the first row, check it, then the next.
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.select);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.select);
    expect(count(tester), tr.youTubePickedOf(5, 5));
    for (var i = 2; i < 8; i++) {
      expect(enabled(tester, i), isFalse, reason: 'row $i');
    }
    expect(find.text(limitText), findsNWidgets(6));
    // Down from the last checked row goes nowhere new: no greyed row takes focus.
    String? focusedRow() =>
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<YouTubeCheckRow>()?.title;
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedRow(), 'Channel 1');
    // OK there unchecks it, and the rest are enabled again.
    await key(tester, LogicalKeyboardKey.select);
    expect(count(tester), tr.youTubePickedOf(4, 5));
    expect(find.text(limitText), findsNothing);
    expect(enabled(tester, 7), isTrue);
  });

  testWidgets('pointer: a click on a greyed row does nothing; on a checked one it unchecks', (tester) async {
    await pick(tester, others: 4);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    Future<void> click(Finder f) async {
      await mouse.moveTo(tester.getCenter(f));
      await mouse.down(tester.getCenter(f));
      await mouse.up();
      await tester.pumpAndSettle();
    }

    await click(row(0));
    expect(count(tester), tr.youTubePickedOf(5, 5));
    await click(row(1));
    expect(count(tester), tr.youTubePickedOf(5, 5));
    expect(enabled(tester, 1), isFalse);
    await click(row(0));
    expect(count(tester), tr.youTubePickedOf(4, 5));
    expect(enabled(tester, 1), isTrue);
  });

  testWidgets('touch: the same; Done gives the picks', (tester) async {
    await pick(tester, others: 4);
    await tester.tap(row(3));
    await tester.pumpAndSettle();
    await tester.tap(row(4), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(count(tester), tr.youTubePickedOf(5, 5));
    expect(find.text(limitText), findsNWidgets(7));
    await tester.tap(find.byWidgetPredicate((w) => w is TvButton && w.label == tr.done));
    await tester.pumpAndSettle();
    expect([for (final s in done!) s.channelId], ['UC3']);
  });

  testWidgets('an own client: no count and no limit, every row can be checked', (tester) async {
    await pick(tester, others: null);
    expect(find.byKey(const ValueKey('picked-count')), findsNothing);
    for (var i = 0; i < 8; i++) {
      await tester.tap(row(i));
      await tester.pumpAndSettle();
    }
    expect(find.text(limitText), findsNothing);
    await tester.tap(find.byWidgetPredicate((w) => w is TvButton && w.label == tr.done));
    await tester.pumpAndSettle();
    expect(done, hasLength(8));
  });

  testWidgets('Google client: Use Nightingale TV\'s client greyed with the reason when there are too many',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var used = 0;
    Future<void> form({required bool tooMany}) async {
      await tester.pumpWidget(MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GoogleClientForm(
                key: ValueKey(tooMany), onUse: (_) {}, onUseShared: () => used++, sharedTooMany: tooMany),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    final shared = find.byKey(const ValueKey('use-shared-client'));
    final reason = tr.youTubeSharedTooMany(AppState.youTubeSharedLimit);
    await form(tooMany: true);
    expect(tester.widget<TvButton>(shared).onPressed, isNull);
    expect(find.text(reason), findsOneWidget);
    await tester.tap(shared, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(used, 0);
    await form(tooMany: false);
    expect(find.text(reason), findsNothing);
    await tester.tap(shared);
    await tester.pumpAndSettle();
    expect(used, 1);
  });
}
