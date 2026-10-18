// Programming blocks UI test. Needs no server: it seeds a fake library and
// lineup in a temp folder, then drives the block screens and the guide.
//
//   SNAP_DIR=/tmp/snaps flutter test integration_test/blocks_test.dart -d linux
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/playback/tuner.dart';

import '../test/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create a programming block and see it in the guide', (tester) async {
    final h = await UiHarness.start(
      tester,
      fakeLibrary(
        shows: {'DuckTales': 30, 'Animaniacs': 25, 'Rugrats': 26, 'Doug': 20, 'Full House': 40, 'Family Matters': 32},
        genres: {
          'DuckTales': ['Animation'],
          'Animaniacs': ['Animation'],
          'Rugrats': ['Animation'],
          'Doug': ['Animation'],
          'Full House': ['Comedy'],
          'Family Matters': ['Comedy'],
        },
        movies: 6,
      ),
    );
    final app = h.app, tuner = h.tuner;
    final wait = h.wait, snap = h.snap, press = h.press, tap = h.tap, tapOn = h.tapOn;

    // Menu → Programming blocks (third item).
    await press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    expect(find.text('New programming block'), findsOneWidget);
    await snap('b1-blocks-empty');

    // New block: OK on the focused "New programming block" button.
    await press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'Saturday Morning Cartoons');
    await wait(const Duration(milliseconds: 300));

    // Saving with nothing to play explains what's missing.
    await tap('Save');
    expect(find.text('Choose some shows or movies for the block to play.'), findsOneWidget);
    await snap('b2-editor-needs-content');

    await tap('Choose shows & movies');
    for (final show in ['Animaniacs (2000)', 'DuckTales (2000)', 'Rugrats (2000)']) {
      await tap(show);
    }
    await snap('b3-content-picker');
    await tap('Done');

    await tap('Only between dates');
    await tap('Weekends');
    await snap('b4-editor-filled');

    await tap('Choose shows & movies'); // reopen and close: selections are kept
    expect(tester.widgetList(find.byIcon(Icons.check_box)).length, greaterThanOrEqualTo(3));
    await press(LogicalKeyboardKey.escape);

    await tapOn(find.byIcon(Icons.tv));
    await snap('b5-channel-picker');
    await tap('A new channel just for this block');
    await tap('Save');
    expect(app.blocks, hasLength(1));
    final block = app.blocks.single;
    expect(block.title, 'Saturday Morning Cartoons');
    expect(block.days, {6, 7});
    expect(block.hasSeason, isTrue);
    expect(block.playlist, isNotEmpty);
    final blockChannel = app.channelById(block.channelId)!;
    expect(blockChannel.blockOnly, isTrue);
    await snap('b6-blocks-list');

    // A second block on channel 2 that's on the air right now, to see the
    // guide band and the banner. Created directly; the editor's time
    // steppers would take dozens of presses to reach "now".
    final now = DateTime.now();
    final start = max(0, (now.hour * 60 + now.minute) ~/ 15 * 15 - 15);
    final afterSchool = app.newBlock()
      ..title = 'After School Toons'
      ..channelId = app.channels.first.id
      ..days = {1, 2, 3, 4, 5, 6, 7}
      ..startMinute = start % (24 * 60)
      ..endMinute = (start + 75) % (24 * 60)
      ..source = const ChannelSource(genres: ['Animation']);
    await tester.runAsync(() => app.saveBlock(afterSchool));
    expect(app.blockConflict(afterSchool), isNull);
    final program = app.scheduleFor(app.channels.first)!.programAt(now);
    expect(program.blockTitle, 'After School Toons');

    // Back to TV, then the guide.
    await press(LogicalKeyboardKey.escape);
    await press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    await tester.runAsync(() => tuner.tune(app.channels.first));
    await press(LogicalKeyboardKey.keyI, after: const Duration(seconds: 1));
    await wait(const Duration(milliseconds: 500));
    await snap('b7-banner-in-block');
    await press(LogicalKeyboardKey.keyG, after: const Duration(seconds: 1));
    await snap('b8-guide-band');

    // The block-only channel is off the air on a weekday.
    await press(LogicalKeyboardKey.escape);
    await tester.runAsync(() => tuner.tuneNumber(blockChannel.number));
    await wait(const Duration(seconds: 1));
    if (now.weekday <= 5) {
      expect(tuner.status, TunerStatus.offAir);
      expect(find.textContaining('Back on the air'), findsWidgets);
      await snap('b9-off-air');
    }

    // Everything was saved.
    final reloaded = AppState(app.storage);
    await tester.runAsync(reloaded.start);
    expect(reloaded.blocks.map((b) => b.title), ['Saturday Morning Cartoons', 'After School Toons']);
    expect(reloaded.channelById(blockChannel.id)?.blockOnly, isTrue);

    await h.dispose();
  });

  testWidgets('program a block lineup, slot by slot', (tester) async {
    final h = await UiHarness.start(
      tester,
      fakeLibrary(shows: {'DuckTales': 30, 'Animaniacs': 25, 'Rugrats': 26, 'Full House': 40}),
    );
    final app = h.app, tuner = h.tuner;
    final wait = h.wait, snap = h.snap, press = h.press, tap = h.tap, tapOn = h.tapOn;

    // Menu → Programming blocks → New programming block.
    await press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    await press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'Saturday Morning Cartoons');
    await wait(const Duration(milliseconds: 300));

    await tap('A lineup');
    await tap('Save');
    expect(find.text('Add a show to the lineup.'), findsOneWidget);

    for (final show in ['DuckTales (2000)', 'Rugrats (2000)', 'Animaniacs (2000)']) {
      await tap(show == 'DuckTales (2000)' ? 'Add a show' : 'Add another show');
      await tap(show);
    }
    // Animaniacs (last row): two episodes, moved up a slot.
    await tapOn(find.text('+'));
    await tapOn(find.text('▲'));
    expect(find.text('2 episodes'), findsOneWidget);
    expect(find.textContaining('NEXT AIRING'), findsOneWidget);
    await snap('l1-lineup-editor');

    // Back to a mix and again: the lineup is kept.
    await tap('A mix');
    expect(find.text('Choose shows & movies'), findsOneWidget);
    await tap('A lineup');
    expect(find.text('2 episodes'), findsOneWidget);

    await tap('Save');
    final block = app.blocks.single;
    expect(
      [for (final s in block.lineup) (s.seriesKey, s.count)],
      [('ducktales|2000', 1), ('animaniacs|2000', 2), ('rugrats|2000', 1)],
    );
    expect(block.playlist, hasLength(30 + 25 + 26));

    // A lineup on the air now on channel 2, to see it in the guide.
    final now = DateTime.now();
    final start = max(0, (now.hour * 60 + now.minute) ~/ 15 * 15 - 15);
    final onNow = app.newBlock()
      ..title = 'After School Toons'
      ..channelId = app.channels.first.id
      ..days = {1, 2, 3, 4, 5, 6, 7}
      ..startMinute = start % (24 * 60)
      ..endMinute = (start + 120) % (24 * 60)
      ..lineup = [LineupSlot(seriesKey: 'rugrats|2000'), LineupSlot(seriesKey: 'ducktales|2000', count: 2)];
    await tester.runAsync(() => app.saveBlock(onNow));
    final programs = app.scheduleFor(app.channels.first)!.programsBetween(now, now.add(const Duration(hours: 1)));
    expect(programs.first.blockTitle, 'After School Toons');

    await press(LogicalKeyboardKey.escape);
    await press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    await tester.runAsync(() => tuner.tune(app.channels.first));
    await press(LogicalKeyboardKey.keyI, after: const Duration(seconds: 1));
    await wait(const Duration(milliseconds: 500));
    expect(find.textContaining('Next '), findsWidgets);
    await snap('l2-banner-next');
    await press(LogicalKeyboardKey.keyG, after: const Duration(seconds: 1));
    await snap('l3-guide-lineup');

    await h.dispose();
  });

  testWidgets('remote focus stays on the lineup while editing it', (tester) async {
    final h = await UiHarness.start(tester, fakeLibrary(shows: {'DuckTales': 30, 'Animaniacs': 25, 'Rugrats': 26}));
    final wait = h.wait, press = h.press, tap = h.tap;

    await press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    await press(LogicalKeyboardKey.enter, after: const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'Cartoons');
    await wait(const Duration(milliseconds: 300));
    await tap('A lineup');
    for (final show in ['DuckTales (2000)', 'Animaniacs (2000)', 'Rugrats (2000)']) {
      await tap(show == 'DuckTales (2000)' ? 'Add a show' : 'Add another show');
      await tap(show);
    }

    /// The focused button, and the show whose row it's in.
    (String?, String?) focused() {
      final rect = FocusManager.instance.primaryFocus?.rect;
      String? row;
      for (final name in ['DuckTales', 'Animaniacs', 'Rugrats']) {
        final names = find.text(name);
        if (rect != null &&
            names.evaluate().isNotEmpty &&
            (tester.getCenter(names.first).dy - rect.center.dy).abs() < 40) {
          row = name;
        }
      }
      return (h.focusedLabel(), row);
    }

    /// Focuses [label] in [show]'s row, then presses OK.
    Future<void> press0(String label, String show) async {
      final y = tester.getCenter(find.text(show).first).dy;
      final button = find
          .text(label)
          .evaluate()
          .firstWhere((e) => (tester.getCenter(find.byWidget(e.widget)).dy - y).abs() < 40);
      Focus.of(button).requestFocus();
      await wait(const Duration(milliseconds: 300));
      expect(focused(), (label, show));
      await press(LogicalKeyboardKey.enter);
    }

    // Moving Animaniacs to the top turns its ▲ off: focus goes to its ▼.
    await press0('▲', 'Animaniacs');
    expect(focused(), ('▼', 'Animaniacs'), reason: 'after moving to the top');
    // Moving it back down keeps focus with it.
    await press0('▼', 'Animaniacs');
    expect(focused(), ('▼', 'Animaniacs'), reason: 'after moving down one');
    // Moving Rugrats... the last row's ▼ is off; moving DuckTales to the
    // bottom lands on its ▲.
    await press0('▼', 'DuckTales');
    await press0('▼', 'DuckTales');
    expect(focused(), ('▲', 'DuckTales'), reason: 'after moving to the bottom');
    // Up to four episodes: the last + turns off, focus goes to −.
    for (var i = 0; i < 3; i++) {
      if (focused().$1 == '+') {
        await press(LogicalKeyboardKey.enter);
      } else {
        await press0('+', 'Rugrats');
      }
    }
    expect(find.text('4 episodes'), findsOneWidget);
    expect(focused(), ('−', 'Rugrats'), reason: 'after reaching four episodes');
    // Now Animaniacs, Rugrats, DuckTales. Removing a row focuses the row
    // that takes its place, or the one above, or "Add a show".
    await press0('Remove', 'Rugrats');
    expect(focused(), ('Remove', 'DuckTales'), reason: 'after removing a middle row');
    await press(LogicalKeyboardKey.enter);
    expect(focused(), ('Remove', 'Animaniacs'), reason: 'after removing the last row');
    await press(LogicalKeyboardKey.enter);
    expect(focused(), ('Add a show', null), reason: 'after removing the only row');

    await h.dispose();
  });
}
