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
}
