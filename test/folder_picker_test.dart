import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/folder_picker_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

/// A movie library: `Extras` (3 movies, 4 trailers), `New Picks` (5 loose
/// movies), `Empty`, and `Die Hard`, a single-movie folder the server lists
/// as the movie (jellyfin-folder-browse).
class _MovieLibrary extends FakeClient {
  _MovieLibrary() : super([]);

  @override
  Future<List<ServerLibrary>> libraries() async =>
      [const ServerLibrary(id: 'movies', name: 'Movies', collectionType: 'movies')];

  @override
  Future<List<FolderNode>> folderTree(String libraryId) async => [
        FolderNode(id: 'ex', name: 'Extras', type: 'Folder', children: [
          for (var i = 1; i <= 3; i++) FolderNode(id: 'em$i', name: 'Feature $i', type: 'Movie'),
          for (var i = 1; i <= 4; i++) FolderNode(id: 't$i', name: 'Trailer $i', type: 'Video'),
        ]),
        FolderNode(id: 'np', name: 'New Picks', type: 'Folder', children: [
          for (var i = 1; i <= 5; i++) FolderNode(id: 'n$i', name: 'Loose $i', type: 'Movie'),
        ]),
        FolderNode(id: 'tr', name: 'Trailers', type: 'Folder', children: [
          FolderNode(id: 'tt', name: 'Teaser', type: 'Video'),
        ]),
        FolderNode(id: 'em', name: 'Empty', type: 'Folder'),
        FolderNode(id: 'dh', name: 'Die Hard', type: 'Movie'),
      ]..sort(FolderNode.compare);
}

void main() {
  late Directory dir;
  late AppState app;
  late Tuner tuner;

  /// The picker over a launcher page; [done] gets what it pops.
  Future<void> showPicker(WidgetTester tester, {required bool forChannel, required void Function(List<PoolRoot>?) done}) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_folder_picker');
      app = await signedInApp(dir, fakeLibrary());
      app.client = _MovieLibrary();
    });
    tuner = Tuner(app, player: FakePlayer([]))
      ..prefetch = false
      ..preload = false;
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      // Above the navigator, so the pushed picker sees the app.
      builder: (context, child) => AppScope(app: app, tuner: tuner, child: TvCanvas(child: child!)),
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async => done(await Navigator.of(context).push<List<PoolRoot>>(MaterialPageRoute(
                builder: (_) => FolderPickerScreen(initial: const [], forChannel: forChannel, poolName: 'Ads')))),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tuner.dispose();
      await tester.runAsync(() async {
        await app.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await dir.delete(recursive: true);
      });
    });
    await tester.tap(find.text('Open'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Movies'), findsOneWidget);
  }

  /// Lets the folder tree load after a library opens.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

  /// The detail text in [name]'s row.
  String? detail(WidgetTester tester, String name) {
    final row = find.ancestor(of: find.text(name), matching: find.byType(AnimatedContainer)).first;
    final texts = [for (final t in tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))) t.data];
    return texts.length > 1 ? texts[1] : null;
  }

  bool hasOpenArrow(WidgetTester tester, String name) {
    final row = find.ancestor(of: find.text(name), matching: find.byType(AnimatedContainer)).first;
    return find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)).evaluate().isNotEmpty;
  }

  testWidgets('D-pad: a movies-only folder opens and lists its movies; a movie and a folder tick as roots',
      (tester) async {
    List<PoolRoot>? picked;
    await showPicker(tester, forChannel: true, done: (r) => picked = r);
    expect(focused(), 'lib:movies');
    await press(tester, LogicalKeyboardKey.arrowRight);
    await settle(tester);
    // Folders first, then the movie whose folder the server merged into it.
    expect(focused(), 'f:em');
    expect(detail(tester, 'Empty'), 'Nothing inside');
    expect(detail(tester, 'Extras'), '3 inside', reason: 'a channel lists no trailers');
    expect(detail(tester, 'New Picks'), '5 inside');
    expect(detail(tester, 'Trailers'), 'No movies');
    expect(detail(tester, 'Die Hard'), 'Movie');
    expect(hasOpenArrow(tester, 'New Picks'), isTrue);
    expect(hasOpenArrow(tester, 'Die Hard'), isFalse);
    expect(hasOpenArrow(tester, 'Trailers'), isFalse);

    // Into New Picks, tick its first movie, back up.
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'f:np');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'f:n1');
    for (var i = 1; i <= 5; i++) {
      expect(find.text('Loose $i'), findsOneWidget);
    }
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'f:n1', reason: 'a movie has nothing to open');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), 'f:np');

    // Die Hard, and the Extras folder.
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'f:dh');
    await press(tester, LogicalKeyboardKey.enter);
    for (var i = 0; i < 3; i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(focused(), 'f:ex');
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text('3 ticked'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect({for (final r in picked!) r.itemId: r.label}, {
      'n1': 'Movies › New Picks › Loose 1',
      'dh': 'Movies › Die Hard',
      'ex': 'Movies › Extras',
    });
  });

  testWidgets('a pool picker lists every video; trailers count and tick', (tester) async {
    List<PoolRoot>? picked;
    await showPicker(tester, forChannel: false, done: (r) => picked = r);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(detail(tester, 'Extras'), '7 inside');
    expect(detail(tester, 'Trailers'), '1 inside');
    expect(focused(), 'f:em');
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'f:em1');
    expect(find.text('Trailer 4'), findsOneWidget);
    expect(detail(tester, 'Trailer 4'), 'Video');
    for (var i = 0; i < 6; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focused(), 'f:t4');
    await press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect([for (final r in picked!) r.itemId], ['t4']);
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('${kind.name}: the name opens a folder, and ticks a movie', (tester) async {
      List<PoolRoot>? picked;
      await showPicker(tester, forChannel: true, done: (r) => picked = r);
      Future<void> tap(String text) async {
        await tester.tap(find.text(text), kind: kind);
        await tester.pumpAndSettle();
      }

      await tap('Movies');
      await settle(tester);
      expect(find.text('Trailer 1'), findsNothing);
      await tap('New Picks');
      expect(find.text('Loose 3'), findsOneWidget);
      await tap('Loose 3');
      expect(find.text('1 ticked'), findsOneWidget);
      // Back up, and tick a movie at the top.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tap('Die Hard');
      expect(find.text('2 ticked'), findsOneWidget);
      await tap('Done');
      expect([for (final r in picked!) r.itemId], ['n3', 'dh']);
    });
  }
}
