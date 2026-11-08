import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/caption_size.dart';
import 'package:nightingale_tv/playback/subtitles.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/captions_picker.dart';
import 'package:nightingale_tv/ui/playback_screen.dart';
import 'package:nightingale_tv/ui/widgets/screen_layout.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

const english = SubtitleTrack(id: '2', codec: 'subrip', language: 'eng', position: 0);
const spanish = SubtitleTrack(id: '3', codec: 'subrip', language: 'spa', position: 1);

class _Tuner extends Tuner {
  _Tuner(super.app, {super.player});

  List<SubtitleTrack> tracks = const [english, spanish];
  bool burned = false;
  bool live = false;

  @override
  bool get captionsBurnedIn => burned;
  @override
  bool get isLive => live;
  @override
  List<SubtitleTrack>? get subtitleTracks => tracks;
  @override
  Future<List<SubtitleTrack>?> loadSubtitleTracks() async => tracks;
}

void main() {
  late Directory dir;
  late AppState app;
  late _Tuner tuner;
  late BuildContext screen;

  Future<void> start(WidgetTester tester, {ScreenLayout? layout, Widget? home, Size view = const Size(1920, 1080)}) async {
    tester.view.physicalSize = view;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_caption_picker');
      app = await signedInApp(dir, fakeLibrary());
      await app.setPlayback(app.settings.playback.copyWith(captions: true));
    });
    tuner = _Tuner(app, player: FakePlayer([]))..shownSubtitle = english;
    final body = Builder(builder: (context) {
      screen = context;
      return home ?? const SizedBox.expand();
    });
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      // Above the Navigator, as TvCanvas is: dialogs are under it too.
      builder: layout == null ? null : (context, child) => ScreenLayoutScope(layout: layout, child: child!),
      home: AppScope(app: app, tuner: tuner, child: body),
    ));
    addTearDown(() async {
      tuner.dispose();
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.runAsync(() async {
        await app.close();
        await dir.delete(recursive: true);
      });
    });
  }

  /// The test font's glyphs are far wider than the app's: at this scale the
  /// sizes are one row, as they are on a TV.
  void realisticTextWidth(WidgetTester tester) {
    tester.platformDispatcher.textScaleFactorTestValue = 0.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> open(WidgetTester tester) async {
    showCaptionsPicker(screen, tuner);
    await tester.pumpAndSettle();
  }

  Finder inDialog(Finder f) => find.descendant(of: find.byType(Dialog), matching: f);

  TvToggle toggle(WidgetTester tester, String label) => tester.widget<TvToggle>(
      inDialog(find.byWidgetPredicate((w) => w is TvToggle && w.label == label)));

  String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvToggle>()?.label;

  Text sample(WidgetTester tester) => tester.widget<Text>(find.text(captionSampleText));

  List<String> sizeLabels() => [for (final s in CaptionSize.values) s.label];

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pumpAndSettle();
  }

  testWidgets('opens focused on the current track; Size is above it; Left and Right move along it', (tester) async {
    realisticTextWidth(tester);
    await start(tester);
    await open(tester);
    expect(focused(), subtitleLabel(english));
    expect(toggle(tester, 'Medium').on, isTrue);
    expect(tester.getTopLeft(inDialog(find.text('Size'))).dy, lessThan(tester.getTopLeft(inDialog(find.text('Off'))).dy));

    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), 'Off');
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(sizeLabels(), contains(focused()));
    expect(focused(), 'Small', reason: 'straight above the left-aligned rows');
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Medium');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), 'Small');
  });

  testWidgets('choosing a size saves it, applies it and leaves the picker open with focus kept', (tester) async {
    realisticTextWidth(tester);
    await start(tester);
    final player = tuner.media as FakePlayer;
    await open(tester);
    expect(sample(tester).style!.fontSize, 54);

    await key(tester, LogicalKeyboardKey.arrowUp);
    await key(tester, LogicalKeyboardKey.arrowUp);
    while (focused() != 'Large') {
      await key(tester, LogicalKeyboardKey.arrowRight);
    }
    await key(tester, LogicalKeyboardKey.enter);

    expect(find.byType(Dialog), findsOneWidget);
    expect(focused(), 'Large');
    expect(app.settings.playback.captionSize, CaptionSize.large);
    expect(player.captionSizes.last, CaptionSize.large);
    expect(toggle(tester, 'Large').on, isTrue);
    expect(toggle(tester, 'Medium').on, isFalse);
    expect(sample(tester).style!.fontSize, 68);
  });

  testWidgets('with a pointer or touch too', (tester) async {
    await start(tester);
    await open(tester);
    await tester.tap(inDialog(find.text('Extra large')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(app.captionSize.value, CaptionSize.extraLarge);
  });

  testWidgets('the rows below stay where they are whatever the size', (tester) async {
    await start(tester);
    await open(tester);
    final y = tester.getTopLeft(inDialog(find.text('Off'))).dy;
    for (final s in CaptionSize.values) {
      await tester.tap(inDialog(find.text(s.label)));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(inDialog(find.text('Off'))).dy, y, reason: s.label);
    }
  });

  testWidgets('captions off: the size is still saved', (tester) async {
    await start(tester);
    await tester.runAsync(() => app.setPlayback(app.settings.playback.copyWith(captions: false)));
    await open(tester);
    await tester.tap(inDialog(find.text('Small')));
    await tester.pumpAndSettle();
    expect(app.settings.playback.captionSize, CaptionSize.small);
    expect(app.settings.playback.captions, isFalse);
  });

  testWidgets('on a live channel too', (tester) async {
    await start(tester);
    tuner.live = true;
    await open(tester);
    expect(focused(), 'On');
    await tester.tap(inDialog(find.text('Large')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(app.captionSize.value, CaptionSize.large);
  });

  testWidgets('a track row still closes the picker', (tester) async {
    await start(tester);
    await open(tester);
    await tester.tap(inDialog(find.text('Off')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('burned in: the note replaces the sizes and the track rows still work', (tester) async {
    await start(tester);
    tuner.burned = true;
    await open(tester);
    expect(find.text(burnedInCaptionsNote), findsOneWidget);
    expect(inDialog(find.text('Large')), findsNothing);
    expect(find.text(captionSampleText), findsNothing);
    expect(focused(), subtitleLabel(english));
    await tester.tap(inDialog(find.text('Off')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('upright, the sample is scaled to the picture', (tester) async {
    await start(tester, layout: const ScreenLayout.portrait(Size(1080, 2000)), view: const Size(1080, 2000));
    await open(tester);
    expect(sample(tester).textScaler, const TextScaler.linear(1080 / 1920));
  });

  testWidgets('a long track list scrolls, and focus stays in view', (tester) async {
    await start(tester);
    tuner.tracks = [for (var i = 0; i < 30; i++) SubtitleTrack(id: '$i', codec: 'subrip', language: 'eng', position: i, title: 'Track $i')];
    tuner.shownSubtitle = tuner.tracks[25];
    await open(tester);
    expect(tester.takeException(), isNull);
    final row = find.ancestor(of: find.text(subtitleLabel(tuner.tracks[25])), matching: find.byType(TvToggle));
    expect(tester.getRect(row).bottom, lessThanOrEqualTo(1080));
    expect(tester.getRect(row).top, greaterThanOrEqualTo(0));
  });

  testWidgets('the menu edits the same size the picker shows', (tester) async {
    await start(tester, home: const PlaybackScreen(), view: const Size(1920, 4000));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TvToggle, 'Large'));
    await tester.pumpAndSettle();
    expect(app.settings.playback.captionSize, CaptionSize.large);
    expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, 'Large')).on, isTrue);

    await open(tester);
    expect(toggle(tester, 'Large').on, isTrue);
    await tester.tap(inDialog(find.text('Small')));
    await tester.pumpAndSettle();
    Navigator.of(screen).pop();
    await tester.pumpAndSettle();
    expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, 'Small')).on, isTrue);
    expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, 'Large')).on, isFalse);
  });
}
