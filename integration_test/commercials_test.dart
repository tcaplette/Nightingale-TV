// Commercials UI test. Needs no real server: a fake Jellyfin serves the
// libraries and folders, and the reel's analysis is seeded.
//
//   SNAP_DIR=/tmp/snaps flutter test integration_test/commercials_test.dart -d linux
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/ui/break_plan_editor_screen.dart';
import 'package:nightingale_tv/ui/commercials_screen.dart';
import 'package:nightingale_tv/ui/folder_picker_screen.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/pool_editor_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import '../test/fixtures.dart';
import 'fake_jellyfin.dart';
import 'harness.dart';

const _shows = {'Cheers': 40, 'Taxi': 30, 'Wings': 30};
const _genres = {
  'Cheers': ['Comedy'],
  'Taxi': ['Comedy'],
  'Wings': ['Drama'],
};

/// Three short ads and a 2-hour reel (ad-4).
const _ads = [Duration(seconds: 30), Duration(seconds: 15), Duration(seconds: 60), Duration(hours: 2)];

/// The reel, already split into 30-second clips.
final _reelCuts = {
  'ad-4': [for (var i = 0; i < 40; i++) Span(Duration(seconds: i * 31), Duration(seconds: i * 31 + 30))],
};

Future<UiHarness> _start(WidgetTester tester, {void Function(List<Map<String, Object?>>)? editChannels}) =>
    UiHarness.start(
      tester,
      fakeLibrary(shows: _shows, genres: _genres, commercials: _ads),
      server: fakeItems(shows: _shows, genres: _genres, commercials: _ads),
      reelCuts: _reelCuts,
      editChannels: editChannels,
    );

String? _focusNode() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a mid-roll on the banner; Automatic while watching keeps the show on', (tester) async {
    // The first channel has its own Automatic plan and is 8 minutes into a
    // slot: in its first mid-roll (7:35–10:35).
    final h = await _start(tester, editChannels: (channels) {
      channels.first['commercialPlan'] = BreakPlan.automatic.toJson();
      channels.first['anchor'] = DateTime.now().subtract(const Duration(minutes: 8)).toUtc().toIso8601String();
    });
    final app = h.app;
    final first = app.allChannels.first;
    expect(app.catalog.clipsFor(null).length, 43, reason: '3 short ads and the reel\'s 40 clips');
    expect(app.breaksFor(first), isTrue);

    await h.tuner.tune(first);
    await h.wait(const Duration(seconds: 1));
    expect(h.tuner.inBreak, isTrue);
    expect(h.tuner.segment!.role, BreakRole.mid);
    expect(h.tuner.program!.item!.kind.name, 'episode', reason: 'the banner shows the program');
    expect(find.textContaining('Commercial break'), findsOneWidget);
    expect(find.text(h.tuner.program!.title), findsWidgets);
    await h.snap('c1-banner-commercial-break');

    // Another channel, following the main setting (Off).
    await h.press(LogicalKeyboardKey.arrowUp, after: const Duration(seconds: 1));
    final watching = h.tuner.channel!;
    expect(app.breaksFor(watching), isFalse);
    final segment = h.tuner.segment!;
    final program = h.tuner.program!.item!.id;

    await h.openMenuItem('Commercials');
    expect(find.byType(CommercialsScreen), findsOneWidget);
    expect(h.focusedLabel(), 'Off');
    await h.snap('c2-commercials-off');
    await h.choose('Automatic', LogicalKeyboardKey.arrowRight);
    expect(app.settings.commercialPlan.mode, BreakMode.automatic);
    expect(app.breaksFor(watching), isTrue);
    // The segment playing plays on; the same program stays on air.
    expect(identical(h.tuner.segment, segment), isTrue);
    expect(h.tuner.program!.item!.id, program);
    expect(find.text('43 clips from 1 pool.'), findsOneWidget);
    await h.snap('c3-commercials-automatic');

    // The guide: half-hour cells from the next slot on.
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    await h.press(LogicalKeyboardKey.keyG, after: const Duration(seconds: 1));
    expect(find.byType(GuideView), findsOneWidget);
    await h.snap('c4-guide-half-hours');
    final now = DateTime.now();
    // (The first channel's anchor was set off the clock on purpose.)
    for (final ch in app.channels.where((c) => c.commercialPlan == null)) {
      final schedule = app.scheduleFor(ch)!;
      final on = schedule.programAt(now);
      for (final p in schedule.programsBetween(on.end, now.add(const Duration(hours: 3)))) {
        expect(p.start.minute % 30, 0, reason: '${ch.name}: ${p.title} at ${p.start}');
        expect(p.duration.inMinutes, 30);
      }
    }
    expect(h.tuner.program!.item!.id, program, reason: 'still the same program');
    await h.dispose();
  });

  testWidgets('pools: create, pick folders, rename, delete', (tester) async {
    final h = await _start(tester);
    final app = h.app;
    await h.openMenuItem('Commercials');

    // Down to "New pool", past the existing pool.
    await h.choose('New pool', LogicalKeyboardKey.arrowDown);
    expect(find.byType(PoolEditorScreen), findsOneWidget);
    final pool = app.settings.commercialPools.last;
    expect(pool.name, 'Commercials 2');
    expect(h.focusedLabel(), 'Add folders…');
    await h.snap('c5-new-pool');

    // The folder picker, with keys only.
    await h.press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    expect(find.byType(FolderPickerScreen), findsOneWidget);
    expect(_focusNode(), 'lib:${FakeJellyfin.adsLibrary}');
    await h.press(LogicalKeyboardKey.arrowRight, after: const Duration(seconds: 1));
    expect(_focusNode(), 'f:${FakeJellyfin.reelFolder}', reason: '▶ opens the library');
    expect(find.text('80s-2000s-commercial-compilation'), findsOneWidget);
    await h.press(LogicalKeyboardKey.enter);
    await h.snap('c6-folder-picker');
    await h.press(LogicalKeyboardKey.arrowLeft);
    expect(_focusNode(), 'lib:${FakeJellyfin.adsLibrary}', reason: '◀ goes back to the libraries');
    // Into TV Shows, into its storage folder, and back up with ESC.
    await h.press(LogicalKeyboardKey.arrowDown);
    await h.press(LogicalKeyboardKey.arrowRight, after: const Duration(seconds: 1));
    expect(_focusNode(), 'f:tv-root');
    await h.press(LogicalKeyboardKey.arrowRight, after: const Duration(seconds: 1));
    expect(_focusNode(), startsWith('f:series-'));
    await h.press(LogicalKeyboardKey.escape);
    expect(_focusNode(), 'f:tv-root');
    await h.press(LogicalKeyboardKey.escape);
    expect(_focusNode(), 'lib:${FakeJellyfin.tvLibrary}');
    await h.choose('Done', LogicalKeyboardKey.arrowDown);
    expect(find.byType(PoolEditorScreen), findsOneWidget);
    expect(pool.roots.single.itemId, FakeJellyfin.reelFolder);
    expect(pool.roots.single.label, 'Commercials › 80s-2000s-commercial-compilation');
    // The re-scan files the reel's videos under both pools.
    for (var i = 0; i < 40 && (app.refreshing || app.catalog.clipsFor(pool.id).isEmpty); i++) {
      await h.wait(const Duration(milliseconds: 250));
    }
    expect(app.catalog.clipsFor(pool.id), hasLength(43));
    expect(find.text('Commercials › 80s-2000s-commercial-compilation'), findsOneWidget);
    await h.snap('c7-pool-with-folder');

    // Rename: ▲ to the name, type, OK.
    for (var i = 0; i < 8 && !isEditingText(); i++) {
      await h.press(LogicalKeyboardKey.arrowUp, after: const Duration(milliseconds: 250));
    }
    expect(isEditingText(), isTrue);
    await tester.enterText(find.byType(TextField), 'Bumpers');
    // OK in a text field reaches it as the keyboard's "done" action.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await h.wait(const Duration(milliseconds: 500));
    expect(pool.name, 'Bumpers');

    // The server going away while picking: an error with "Try again", and
    // the pool unchanged.
    h.server!.down = true;
    await h.choose('Add folders…', LogicalKeyboardKey.arrowDown);
    expect(find.text('Couldn\'t reach the server'), findsOneWidget);
    expect(h.focusedLabel(), 'Try again');
    await h.snap('c8-folder-picker-error');
    h.server!.down = false;
    await h.press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    expect(_focusNode(), 'lib:${FakeJellyfin.adsLibrary}');
    await h.press(LogicalKeyboardKey.escape);
    expect(find.byType(PoolEditorScreen), findsOneWidget);
    expect(pool.roots.single.itemId, FakeJellyfin.reelFolder, reason: 'cancelled: unchanged');

    // Delete, behind a confirmation (Cancel has focus).
    await h.choose('Delete pool', LogicalKeyboardKey.arrowDown);
    expect(find.text('Delete "Bumpers"?'), findsOneWidget);
    expect(h.focusedLabel(), 'Cancel');
    await h.choose('Delete', LogicalKeyboardKey.arrowRight);
    expect(find.byType(PoolEditorScreen), findsNothing);
    expect(app.settings.commercialPools.map((p) => p.name), ['Commercials']);
    await h.dispose();
  });

  testWidgets('every Custom setting with keys; one channel with its own plan', (tester) async {
    final h = await _start(tester);
    final app = h.app;
    await h.openMenuItem('Commercials');
    await h.choose('Custom', LogicalKeyboardKey.arrowRight);
    expect(app.settings.commercialPlan, const BreakPlan(mode: BreakMode.custom));
    await h.choose('Break settings…', LogicalKeyboardKey.arrowRight);
    expect(find.byType(BreakPlanEditorScreen), findsOneWidget);
    expect(h.focusedLabel(), 'None', reason: 'starts on the pre-roll setting');
    await h.snap('c9a-break-settings-open');

    Future<void> pick(String label) => h.choose(label, LogicalKeyboardKey.arrowRight);
    Future<void> down() => h.press(LogicalKeyboardKey.arrowDown, after: const Duration(milliseconds: 300));
    Future<void> pool(String name) async {
      await h.moveTo('Clips from: All pools', LogicalKeyboardKey.arrowRight);
      await h.press(LogicalKeyboardKey.enter, after: const Duration(milliseconds: 800));
      await h.choose('$name  ·  ${app.catalog.clipsFor(app.settings.commercialPools.single.id).length} clips',
          LogicalKeyboardKey.arrowDown);
    }

    await pick('30 s');
    await pool('Commercials');
    await down();
    await pick('8 min');
    await down();
    await pick('1:30');
    await pool('Commercials');
    await down();
    await pick('2 min');
    await pool('Commercials');
    await down();
    await pick('To :30');
    await pool('Commercials');
    await h.snap('c9-break-settings');
    expect(find.text('FALLBACK'), findsNothing, reason: 'no fallback setting');
    await h.choose('Save', LogicalKeyboardKey.arrowDown);
    final pid = app.settings.commercialPools.single.id;
    final roles = app.settings.commercialPlan.roles;
    expect(app.settings.commercialPlan.mode, BreakMode.custom);
    expect(roles.preRoll, const Duration(seconds: 30));
    expect(roles.midInterval, const Duration(minutes: 8));
    expect(roles.midLength, const Duration(seconds: 90));
    expect(roles.postRoll, const Duration(minutes: 2));
    expect(roles.tailGrid, const Duration(minutes: 30));
    for (final role in BreakRole.values) {
      expect(roles.poolFor(role), pid, reason: role.name);
    }

    // A channel's own Custom plan, leaving the main one alone.
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    await h.tap('Channels & icons');
    final ch = app.allChannels.first;
    await h.tap('Custom…');
    expect(find.text('BREAKS ON ${ch.name.toUpperCase()}'), findsOneWidget);
    await down();
    await pick('6 min');
    await h.choose('Save', LogicalKeyboardKey.arrowDown);
    expect(ch.commercialPlan!.mode, BreakMode.custom);
    expect(ch.commercialPlan!.roles.midInterval, const Duration(minutes: 6));
    expect(app.settings.commercialPlan.roles, roles, reason: 'the main plan is unchanged');
    await h.snap('c10-channel-custom');
    await h.tap('Main setting (Custom)');
    expect(ch.commercialPlan, isNull);
    await h.dispose();
  });
}
