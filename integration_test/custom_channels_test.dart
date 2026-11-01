// Custom channels UI test (custom-channels 7.4), with keys only. Needs no
// real server: a fake Jellyfin serves the libraries and a collection.
//
//   SNAP_DIR=/tmp/snaps flutter test integration_test/custom_channels_test.dart -d linux
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/folder_picker_screen.dart';
import 'package:nightingale_tv/ui/source_picker_screen.dart';

import '../test/fixtures.dart';
import 'harness.dart';

const _shows = {'Alpha': 12, 'Beta': 8, 'Gamma': 6};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('build a channel with the D-pad, edit it, give it slots, reset the lineup', (tester) async {
    final h = await UiHarness.start(
      tester,
      fakeLibrary(shows: _shows, movies: 6),
      server: fakeItems(shows: _shows, movies: 6),
      collections: {
        '80s Sitcoms': {
          'box80s': ['Alpha-e1', 'Alpha-e2', 'Beta-e1', 'movie-1']
        }
      },
    );
    final app = h.app;
    final before = app.allChannels.length;
    const up = LogicalKeyboardKey.arrowUp, down = LogicalKeyboardKey.arrowDown;
    const left = LogicalKeyboardKey.arrowLeft, right = LogicalKeyboardKey.arrowRight;
    const ok = LogicalKeyboardKey.enter, back = LogicalKeyboardKey.escape;

    await h.press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
    await h.choose('Channels & icons', down);
    expect(find.byType(ChannelEditorScreen), findsOneWidget);
    await h.snap('cc1-channels');

    // Nothing picked: Back adds nothing.
    await h.choose('New channel', up);
    expect(find.byType(SourcePickerScreen), findsOneWidget);
    await h.press(back, after: const Duration(seconds: 1));
    expect(app.allChannels, hasLength(before));

    await h.press(ok, after: const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), '80s TV');
    await h.wait(const Duration(milliseconds: 300));
    await h.choose('Add…', down);
    expect(find.byType(FolderPickerScreen), findsOneWidget);
    await h.press(down);
    await h.press(right, after: const Duration(seconds: 1));
    await h.press(right, after: const Duration(seconds: 1));
    await h.press(ok);
    await h.snap('cc2-folder-picker');
    await h.press(back);
    await h.press(back);
    await h.choose('Done', down);
    expect(find.byType(SourcePickerScreen), findsOneWidget);
    expect(find.text('4 programs'), findsOneWidget, reason: 'the root is fetched at once');
    expect(find.textContaining('80s Sitcoms (collection)'), findsWidgets);
    await h.snap('cc3-source');
    await h.moveTo('Clear', up);
    await h.choose('Done', left);
    expect(find.byType(SourcePickerScreen), findsNothing);
    expect(app.allChannels, hasLength(before + 1));
    final ch = app.allChannels.firstWhere((c) => c.name == '80s TV');
    expect(ch.isCustom, isTrue);
    expect(ch.playlist.toSet(), {'Alpha-e1', 'Alpha-e2', 'Beta-e1', 'movie-1'});

    // Edit it: add a show.
    await h.press(right);
    await h.choose('Edit content', down);
    expect(find.byType(SourcePickerScreen), findsOneWidget);
    await h.press(ok); // The first show, focused.
    await h.press(right);
    await h.choose('Done', down);
    expect(find.byType(SourcePickerScreen), findsNothing);
    expect(ch.playlist.where((id) => id.startsWith('Alpha')), hasLength(12));

    // 30-minute filler slots.
    for (var i = 0; i < 12 && !(h.focusedLabel()?.endsWith(' min') ?? false); i++) {
      await h.press(down, after: const Duration(milliseconds: 250));
    }
    await h.choose('30 min', right);
    expect(ch.slotRule, const SlotRule(length: Duration(minutes: 30)));
    await h.wait(const Duration(milliseconds: 300));
    await h.snap('cc4-slots');
    expect(find.text('TAIL'), findsOneWidget);
    expect(ch.anchor.minute % 30, 0);

    // Reset the lineup: the channel stays.
    await h.press(left);
    await h.press(back, after: const Duration(seconds: 1));
    await h.choose('Reset channel lineup', down);
    await h.choose('Reset', left);
    await h.wait(const Duration(seconds: 1));
    final kept = app.channelById(ch.id);
    expect(kept, isNotNull);
    expect(kept!.slotRule?.length, const Duration(minutes: 30));
    expect(kept.source.roots.single.itemId, 'box80s');
    await h.dispose();
  });

  // Run with a mouse on the TV layout and by touch on a phone:
  //   --dart-define=CC_INPUT=mouse | touch  --plain-name "without the D-pad"
  testWidgets('build a channel without the D-pad', (tester) async {
    const input = String.fromEnvironment('CC_INPUT', defaultValue: 'mouse');
    // Real device events reach the app, not only the test's own.
    if (input == 'uhid') {
      (tester.binding as LiveTestWidgetsFlutterBinding).shouldPropagateDevicePointerEvents = true;
    }
    final h = await UiHarness.start(
      tester,
      fakeLibrary(shows: _shows, movies: 6),
      server: fakeItems(shows: _shows, movies: 6),
      collections: {
        '80s Sitcoms': {
          'box80s': ['Alpha-e1', 'Alpha-e2', 'Beta-e1', 'movie-1']
        }
      },
    );
    final app = h.app;
    final kind = input == 'touch' ? PointerDeviceKind.touch : PointerDeviceKind.mouse;

    /// Hovers where [target] says, then presses where it says after that:
    /// a mouse's hover focuses, which can scroll what's under it.
    Future<void> press(Offset Function() target) async {
      if (input == 'uhid') {
        // A real mouse (tool/uhid_mouse): drive.py clicks where this asks.
        final dpr = tester.view.devicePixelRatio;
        // Hover first: it focuses, which can scroll the target. Then click
        // where it is now.
        var at = target();
        // ignore: avoid_print
        print('UHIDMOVE ${at.dx * dpr} ${at.dy * dpr}');
        await h.wait(const Duration(seconds: 9));
        at = target();
        // ignore: avoid_print
        print('UHID ${at.dx * dpr} ${at.dy * dpr}');
        await h.wait(const Duration(seconds: 10));
        return;
      }
      final gesture = await tester.createGesture(kind: kind);
      var at = target();
      if (kind == PointerDeviceKind.mouse) {
        await gesture.addPointer(location: at);
        await gesture.moveTo(at);
        await h.wait(const Duration(milliseconds: 500));
        at = target();
        await gesture.moveTo(at);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.down(at);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      if (kind == PointerDeviceKind.mouse) await gesture.removePointer();
      await h.wait(const Duration(milliseconds: 800));
    }

    Future<void> click(String text) async {
      final finder = find.text(text);
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).last);
      }
      await tester.ensureVisible(finder.last);
      await tester.pump();
      await press(() => tester.getCenter(finder.last));
    }

    // The TV opens the menu with a mouse's right click and on a phone with a
    // long press; the screen under test is what's being checked, so it's opened directly.
    await tester.runAsync(() async {});
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => const ChannelEditorScreen())));
    await h.wait(const Duration(seconds: 1));

    await click('New channel');
    await tester.enterText(find.byType(TextField), 'By $input');
    await h.wait(const Duration(milliseconds: 300));
    await click('Add…');
    await click('TV Shows');
    await click('tv');
    await h.wait(const Duration(seconds: 1));
    await h.snap('cc-$input-folders');
    // The tick box is at the row's left, the name opens.
    // The tick box on the collection's own row: the nearest to its name.
    await press(() {
      final label = tester.getCenter(find.text('80s Sitcoms'));
      final ticks = [
        for (var i = 0; i < find.byIcon(Icons.check_box_outline_blank).evaluate().length; i++)
          tester.getCenter(find.byIcon(Icons.check_box_outline_blank).at(i)),
      ]..sort((a, b) => (a - label).distance.compareTo((b - label).distance));
      return ticks.first;
    });
    expect(find.byIcon(Icons.check_box), findsOneWidget, reason: 'the collection is ticked');
    await click('Done');
    expect(find.byType(FolderPickerScreen), findsNothing);
    await h.wait(const Duration(seconds: 1));
    await h.snap('cc-$input-source');
    expect(find.text('4 programs'), findsOneWidget);
    await click('Done');
    await h.wait(const Duration(seconds: 1));
    await h.snap('cc-$input-done');
    final ch = app.allChannels.firstWhere((c) => c.name == 'By $input');
    expect(ch.playlist.toSet(), {'Alpha-e1', 'Alpha-e2', 'Beta-e1', 'movie-1'});
    if (input == 'uhid') (tester.binding as LiveTestWidgetsFlutterBinding).shouldPropagateDevicePointerEvents = false;
    await h.dispose();
  });
}
