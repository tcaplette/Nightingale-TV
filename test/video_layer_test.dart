// The picture on Android's video layer, from Flutter's side
// (system-video-layer D3–D5): where the hole is, that nothing round it hides
// the layer, and the effects the player is told to draw.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/device_effects.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/playback/video_hole.dart';
import 'package:nightingale_tv/playback/video_look.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/portrait_watch_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/crt_effects.dart';

import 'fake_playback.dart';
import 'portrait_harness.dart';

const _tv = Size(1920, 1080);

/// The layers round the hole that would keep it from reaching the video.
List<String> _isolating(RenderVideoHole hole) {
  final found = <String>[];
  // ignore: invalid_use_of_protected_member
  for (Layer? layer = hole.layer; layer != null; layer = layer.parent) {
    final isolates = switch (layer) {
      final OpacityLayer l => (l.alpha ?? 255) < 255,
      ColorFilterLayer() || ImageFilterLayer() || ShaderMaskLayer() || BackdropFilterLayer() => true,
      final ClipRectLayer l => l.clipBehavior == Clip.antiAliasWithSaveLayer,
      final ClipRRectLayer l => l.clipBehavior == Clip.antiAliasWithSaveLayer,
      final ClipPathLayer l => l.clipBehavior == Clip.antiAliasWithSaveLayer,
      _ => false,
    };
    if (isolates) found.add('${layer.runtimeType}');
  }
  return found;
}

void main() {
  setUp(() {
    DeviceEffects.instance.reset();
    CrtShader.instance.available.value = false;
  });

  RenderVideoHole hole(WidgetTester tester) =>
      tester.renderObject<RenderVideoHole>(find.byType(VideoHole));

  /// [home] for the first channel, playing on the video layer with [retro].
  Future<(PortraitHarness, FakePlayer)> show(WidgetTester tester, Widget Function(FakePlayer player) home,
      {RetroSettings retro = const RetroSettings(), Size window = _tv}) async {
    runAs(TargetPlatform.android);
    setWindow(tester, window);
    final h = await PortraitHarness.start(tester);
    final player = (h.tuner.media as FakePlayer)..onVideoLayer = true;
    await tester.runAsync(() => h.app.setMainRetro(retro));
    h.tuner
      ..channel = h.app.channels.first
      ..status = TunerStatus.playing;
    await h.show(tester, home(player));
    await tester.pump(const Duration(milliseconds: 100));
    return (h, player);
  }

  Future<void> end(WidgetTester tester, PortraitHarness h) async {
    h.tuner.status = TunerStatus.idle;
    await h.end(tester);
  }

  group('where the hole is', () {
    for (final (shape, video, picture, shown) in [
      (PictureShape.original, const Size(1920, 1080), const Rect.fromLTRB(0, 0, 1920, 1080), const Rect.fromLTRB(0, 0, 1920, 1080)),
      (PictureShape.original, const Size(640, 480), const Rect.fromLTRB(240, 0, 1680, 1080), const Rect.fromLTRB(240, 0, 1680, 1080)),
      (PictureShape.original, const Size(1280, 534), const Rect.fromLTRB(0, 139.5, 1920, 940.5), const Rect.fromLTRB(0, 139.5, 1920, 940.5)),
      (PictureShape.fill43, const Size(1920, 1080), const Rect.fromLTRB(0, 0, 1920, 1080), const Rect.fromLTRB(240, 0, 1680, 1080)),
      (PictureShape.fit43, const Size(1920, 1080), const Rect.fromLTRB(240, 135, 1680, 945), const Rect.fromLTRB(240, 135, 1680, 945)),
    ]) {
      testWidgets('$shape with a $video picture', (tester) async {
        final (h, player) = await show(tester, (_) => const TvScreen(), retro: RetroSettings(shape: shape));
        player.videoSize.value = video;
        await tester.pump();
        await tester.pump();
        final at = hole(tester);
        expect(at.pictureOnScreen, rectMoreOrLessEquals(picture, epsilon: 0.01));
        expect(at.shownOnScreen, rectMoreOrLessEquals(shown, epsilon: 0.01));
        expect(player.places.last, rectMoreOrLessEquals(picture, epsilon: 0.01));
        expect(_isolating(at), isEmpty);
        await end(tester, h);
      });
    }

    testWidgets('the guide preview, and back to full screen', (tester) async {
      final guide = ValueNotifier(false);
      final (h, player) = await show(
          tester,
          (_) => ValueListenableBuilder(
              valueListenable: guide,
              builder: (context, open, _) => open
                  ? GuideView(onWatch: (_) {}, onClose: () {}, onMenu: () {})
                  : const TvPicture()));
      expect(player.places.last, const Rect.fromLTRB(0, 0, 1920, 1080));
      guide.value = true;
      await tester.pump();
      final preview = hole(tester).pictureOnScreen!;
      expect(preview.width, closeTo(preview.height * 16 / 9, 2));
      expect(preview.right, lessThan(1920));
      expect(preview.left, greaterThan(960));
      expect(_isolating(hole(tester)), isEmpty);
      expect(player.places, hasLength(1), reason: 'a smaller place waits for the frame to be drawn');
      await tester.pump();
      await tester.pump();
      expect(player.places.last, preview);
      guide.value = false;
      await tester.pump();
      expect(player.places.last, const Rect.fromLTRB(0, 0, 1920, 1080), reason: 'a larger place is taken at once');
      await end(tester, h);
    });

    testWidgets('the portrait watch screen', (tester) async {
      final (h, player) = await show(
          tester,
          (_) => PortraitWatchScreen(picture: const TvPicture(), onTune: (_) {}, onMenu: () {}, onFullScreen: () {}),
          window: const Size(412, 915));
      final at = hole(tester).pictureOnScreen!;
      expect(at.left, closeTo(0, 1));
      expect(at.width, closeTo(412 * tester.view.devicePixelRatio, 2));
      expect(at.height, closeTo(at.width * 9 / 16, 2));
      expect(player.places.last, at);
      expect(_isolating(hole(tester)), isEmpty);
      await end(tester, h);
    });

    testWidgets('a place smaller in one direction only is taken at once', (tester) async {
      final size = ValueNotifier(const Size(400, 800));
      final places = <Rect>[];
      final holes = VideoHoles((_, r) {
        places.add(r);
        return true;
      });
      setWindow(tester, _tv);
      await tester.pumpWidget(Align(
        alignment: Alignment.topLeft,
        child: ValueListenableBuilder(
          valueListenable: size,
          builder: (context, s, _) => SizedBox.fromSize(
              size: s,
              child: VideoHole(video: const Size(160, 90), fit: BoxFit.contain, open: true, holes: holes)),
        ),
      ));
      await tester.pump();
      places.clear();
      // A phone turned sideways.
      size.value = const Size(800, 400);
      await tester.pump();
      expect(places, hasLength(1));
      // Only the video's own shape changed: no frame to wait for.
    });
  });

  group('black until there is a picture', () {
    testWidgets('closed before the first frame and after the surface goes', (tester) async {
      final (h, player) = await show(tester, (_) => const TvScreen());
      expect(hole(tester).open, isTrue);
      expect(hole(tester), paints..rect(color: Colors.black)..rect(rect: const Rect.fromLTRB(0, 0, 1920, 1080)));
      player.hasPicture.value = false;
      await tester.pump();
      expect(hole(tester).open, isFalse);
      expect(hole(tester), isNot(paints..rect(color: Colors.black)..rect()), reason: 'black, and nothing clear');
      await end(tester, h);
    });

    testWidgets('no size yet: black, and no place', (tester) async {
      final places = <Rect>[];
      await tester.pumpWidget(VideoHole(
          video: null,
          fit: BoxFit.contain,
          open: true,
          holes: VideoHoles((_, r) {
            places.add(r);
            return true;
          })));
      await tester.pump();
      expect(places, isEmpty);
      expect(hole(tester), isNot(paints..rect()..rect()));
    });

    testWidgets('a place nobody took is given again', (tester) async {
      var ready = false;
      final places = <Rect>[];
      final holes = VideoHoles((_, r) {
        if (ready) places.add(r);
        return ready;
      });
      await tester.pumpWidget(VideoHole(video: const Size(160, 90), fit: BoxFit.contain, open: true, holes: holes));
      await tester.pump();
      expect(places, isEmpty);
      ready = true;
      holes.placeAgain();
      await tester.pump();
      expect(places, hasLength(1));
    });
  });

  group('nothing hides the layer', () {
    testWidgets('a screen opening and closing over it', (tester) async {
      final (h, player) = await show(tester, (_) => const TvScreen());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.push(MaterialPageRoute<void>(builder: (_) => const ColoredBox(color: Colors.blue)));
      await tester.pump();
      for (var t = 0; t < 450; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        final at = tester.renderObjectList<RenderVideoHole>(find.byType(VideoHole, skipOffstage: false));
        for (final one in at) {
          expect(_isolating(one), isEmpty, reason: 'opening, ${t + 50} ms');
          expect(one.pictureOnScreen, const Rect.fromLTRB(0, 0, 1920, 1080), reason: 'and it stays still');
        }
      }
      await tester.pump(const Duration(seconds: 1));
      navigator.pop();
      await tester.pump();
      for (var t = 0; t < 450; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(_isolating(hole(tester)), isEmpty, reason: 'closing, ${t + 50} ms');
      }
      await tester.pump(const Duration(seconds: 1));
      expect(player.places, hasLength(1), reason: 'the layer never moved');
      await end(tester, h);
    });

    testWidgets('every CRT style, in every shape', (tester) async {
      CrtShader.instance.available.value = true;
      final (h, _) = await show(tester, (_) => const TvScreen());
      for (final style in CrtStyle.values) {
        for (final shape in PictureShape.values) {
          await tester.runAsync(() => h.app.setMainRetro(RetroSettings(crt: style, shape: shape)));
          await tester.pump();
          expect(_isolating(hole(tester)), isEmpty, reason: '$style $shape');
        }
      }
      await end(tester, h);
    });

    testWidgets('the sleep screen and dimming are over it', (tester) async {
      final (h, _) = await show(tester, (_) => const TvPicture(dimmed: true));
      expect(_isolating(hole(tester)), isEmpty);
      await end(tester, h);
    });
  });

  group('the effects on the video', () {
    testWidgets('Arcade: the same colours, curve and glow as over it; the captions and the logo stay over the video',
        (tester) async {
      CrtShader.instance.available.value = true;
      final (h, player) = await show(tester, (_) => const TvScreen(), retro: const RetroSettings(crt: CrtStyle.arcade));
      final v = CrtStyle.arcade.valuesWith(const CrtValues());
      expect(
          player.looks.last,
          (
            VideoLook(
                matrix: crtColorMatrix(v),
                curvature: 0.05,
                glow: 0.6,
                // The glow is worked out over them.
                overlay: const VideoOverlay(scanlines: 0.5, lines: 240, mask: 0.1, vignette: 0.3)),
            true
          ));
      expect(tester.layers.whereType<ColorFilterLayer>(), isNotEmpty, reason: 'the logo and cards keep the colour');
      final captions = find.byKey(const ValueKey('captions'));
      expect(captions, findsOneWidget);
      expect(find.ancestor(of: captions, matching: find.byType(CrtLayers)), findsOneWidget);
      await end(tester, h);
    });

    testWidgets('without glow the interface draws the scanlines over the video; with it, only over what is there',
        (tester) async {
      CrtShader.instance.available.value = true;
      BlendMode blend() {
        final modes = <BlendMode>[];
        for (final p in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
          final painter = p.painter;
          if (painter == null || painter.runtimeType.toString() != '_OverlayPainter') continue;
          modes.add((painter as dynamic).blendMode as BlendMode);
        }
        return modes.single;
      }

      final (h, player) = await show(tester, (_) => const TvScreen(),
          retro: const RetroSettings(
              crt: CrtStyle.custom, custom: CrtValues(scanlines: CrtLevel.high, curvature: CrtLevel.low)));
      expect(player.looks.last.$1.overlay, VideoOverlay.none);
      expect(blend(), BlendMode.srcOver);
      await tester.runAsync(() => h.app.setMainRetro(const RetroSettings(
          crt: CrtStyle.custom, custom: CrtValues(scanlines: CrtLevel.high, glow: CrtLevel.low))));
      await tester.pump();
      expect(player.looks.last.$1.overlay, const VideoOverlay(scanlines: 0.5));
      expect(blend(), BlendMode.srcATop);
      await end(tester, h);
    });

    testWidgets('a style that changes nothing in the video asks for nothing', (tester) async {
      final (h, player) = await show(tester, (_) => const TvScreen(),
          retro: const RetroSettings(
              crt: CrtStyle.custom,
              custom: CrtValues(vignette: CrtLevel.high)));
      expect(player.looks.last.$1, VideoLook.none);
      expect(player.looks.last.$1.any, isFalse);
      await end(tester, h);
    });

    testWidgets('where the shader cannot draw, the colour stays and the curve and glow do not', (tester) async {
      final (h, player) = await show(tester, (_) => const TvScreen(), retro: const RetroSettings(crt: CrtStyle.arcade));
      final look = player.looks.last.$1;
      expect(look.matrix, isNotNull);
      expect((look.curvature, look.glow), (0, 0));
      await end(tester, h);
    });

    testWidgets('the guide preview draws none, for a channel that has them', (tester) async {
      final (h, player) = await show(
          tester, (_) => GuideView(onWatch: (_) {}, onClose: () {}, onMenu: () {}),
          retro: const RetroSettings(crt: CrtStyle.arcade));
      expect(player.looks.last.$1.any, isTrue);
      expect(player.looks.last.$2, isFalse);
      await end(tester, h);
    });

    testWidgets('a player that cannot apply them: none on the video, nothing over it to match', (tester) async {
      CrtShader.instance.available.value = true;
      final (h, player) = await show(tester, (_) => const TvScreen(), retro: const RetroSettings(crt: CrtStyle.arcade));
      DeviceEffects.instance.videoEffectsFailed();
      await tester.pump();
      expect(player.looks.last.$1, VideoLook.none);
      expect(tester.layers.whereType<ColorFilterLayer>(), isEmpty);
      expect(find.text(TvScreen.effectsFallback), findsOneWidget, reason: 'said once');
      await tester.pump(const Duration(seconds: 10));
      await end(tester, h);
    });

    testWidgets('a stream they cannot be applied to: none over it either, and back with the next', (tester) async {
      CrtShader.instance.available.value = true;
      final (h, player) = await show(tester, (_) => const TvScreen(), retro: const RetroSettings(crt: CrtStyle.arcade));
      final asked = player.looks.last;
      player.videoLookApplied.value = false;
      await tester.pump();
      expect(player.looks.last, asked, reason: 'the channel still asks for them');
      expect(tester.layers.whereType<ColorFilterLayer>(), isEmpty);
      player.videoLookApplied.value = true;
      await tester.pump();
      expect(tester.layers.whereType<ColorFilterLayer>(), isNotEmpty);
      await end(tester, h);
    });

    test('dropped frames count against the budget', () {
      final w = FrameBudgetWatcher(budget: const Duration(milliseconds: 16), seconds: 3);
      var dropped = 0;
      for (final (drops, over) in [(0, false), (5, false), (5, false), (5, true)]) {
        w.addFrame(const Duration(milliseconds: 4));
        w.addDropped(dropped += drops);
        expect(w.endSecond(), over);
      }
      // A new open starts the count again.
      w.addDropped(1);
      w.addFrame(const Duration(milliseconds: 4));
      expect(w.endSecond(), isFalse);
      w.addDropped(3);
      expect(w.endSecond(), isFalse, reason: '2 in a second are not over');
    });
  });

  test('two looks with the same values are the same', () {
    expect(const VideoLook(curvature: 0.05), const VideoLook(curvature: 0.05));
    expect(const VideoLook(matrix: [1, 2]), const VideoLook(matrix: [1, 2]));
    expect(const VideoLook(matrix: [1, 2]), isNot(const VideoLook(matrix: [1, 3])));
    expect(GuideTheme.cableGuide.toThemeData().pageTransitionsTheme.builders.keys, [TargetPlatform.android]);
  });
}
