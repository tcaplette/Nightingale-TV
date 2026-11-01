import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/ui/break_plan_editor_screen.dart';
import 'package:nightingale_tv/ui/commercials_screen.dart';
import 'package:nightingale_tv/ui/pool_editor_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'portrait_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<(PortraitHarness, CommercialPool, CommercialPool)> start(WidgetTester tester, {bool television = false}) async {
    runAs(TargetPlatform.android, television: television);
    setWindow(tester, television ? const Size(1920, 1080) : pixel8);
    final h = await PortraitHarness.start(tester);
    final (ads, idents) = (await tester.runAsync(() async {
      final ads = await h.app.createPool();
      final idents = await h.app.createPool();
      await h.app.renamePool(ads, 'Retro ads');
      await h.app.renamePool(idents, 'Idents');
      await h.app.setPoolKind(idents, PoolKind.bumpers);
      return (ads, idents);
    }))!;
    return (h, ads, idents);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
    expect(PlatformInfo.isAndroid, isTrue);
  }

  Future<void> tapShown(WidgetTester tester, Finder target) async {
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.scrollUntilVisible(target, 300, scrollable: page);
    await tester.pump();
    await tester.tap(target);
    await settle(tester);
  }

  testWidgets('the pool editor sets the type, and says what it means', (tester) async {
    final (h, ads, _) = await start(tester);
    await h.show(tester, PoolEditorScreen(pool: ads));
    await settle(tester);
    expect(find.textContaining('fills breaks'), findsOneWidget);
    await tester.tap(find.widgetWithText(TvToggle, PoolKind.bumpers.label));
    await settle(tester);
    expect(ads.kind, PoolKind.bumpers);
    expect(find.textContaining('opens and closes breaks'), findsOneWidget);
    expect(find.textContaining('at most half of a break'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the Commercials screen shows each pool\'s type and where bumpers play', (tester) async {
    final (h, _, _) = await start(tester);
    await h.show(tester, const CommercialsScreen());
    await settle(tester);
    expect(find.textContaining('Retro ads  ·  Commercials'), findsOneWidget);
    expect(find.textContaining('Idents  ·  Bumpers'), findsOneWidget);
    expect(find.textContaining('open and close breaks, and never play as ads'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('choosers list only their own type', (tester) async {
    final (h, _, idents) = await start(tester);
    CustomRoles? saved;
    await h.show(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              saved = await Navigator.of(context).push<CustomRoles>(MaterialPageRoute(
                  builder: (_) => const BreakPlanEditorScreen(
                      initial: CustomRoles(preRoll: Duration(seconds: 15)), title: 'Break settings')));
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);

    await tester.tap(find.textContaining('Clips from:').first);
    await settle(tester);
    expect(find.textContaining('All pools'), findsOneWidget);
    expect(find.textContaining('Retro ads'), findsOneWidget);
    expect(find.textContaining('Idents'), findsNothing);
    await tester.tap(find.textContaining('All pools'));
    await settle(tester);

    await tapShown(tester, find.text('One pool…'));
    expect(find.textContaining('All bumper pools'), findsOneWidget);
    expect(find.textContaining('Idents'), findsOneWidget);
    expect(find.textContaining('Retro ads'), findsNothing);
    await tester.tap(find.textContaining('Idents'));
    await settle(tester);
    expect(find.text('Idents…'), findsOneWidget);

    await tapShown(tester, find.text('Save'));
    expect(saved?.bumperPool, idents.id);
    expect(saved?.noBumpers, isFalse);
    await finish(tester);
  });

  testWidgets('▲▼ reach the BUMPERS row, landing on its chosen option', (tester) async {
    final (h, _, _) = await start(tester, television: true);
    await h.show(tester, const BreakPlanEditorScreen(initial: CustomRoles(), title: 'Break settings'));
    await settle(tester);
    bool focused(String label) {
      final node = tester.widget<TvToggle>(find.widgetWithText(TvToggle, label).last).focusNode;
      return node?.hasFocus ?? false;
    }

    // Pre-roll, every, length, post, tail, then bumpers.
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
    }
    expect(focused('All bumper pools'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(focused('None'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(focused('None'), isFalse);
    await finish(tester);
  });
}
