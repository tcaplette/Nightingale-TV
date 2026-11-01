// retro-presentation: the 4:3 frame, surround, CRT layers, overlay themes and
// the settings screens.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/playback/device_effects.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/retro_look_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/broadcast_cards.dart';
import 'package:nightingale_tv/ui/widgets/channel_logo_bug.dart';
import 'package:nightingale_tv/ui/widgets/crt_effects.dart';
import 'package:nightingale_tv/ui/widgets/overlay_style.dart';
import 'package:nightingale_tv/ui/widgets/retro_frame.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/playback/tuner.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

const _canvas = Size(1920, 1080);

Widget _app(Widget child) => MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: MediaQuery(data: const MediaQueryData(size: _canvas), child: SizedBox.fromSize(size: _canvas, child: child)),
    );

/// Whatever [RetroFrame] lays out, as the size its child gets.
class _Probe extends StatelessWidget {
  const _Probe();
  static Size? media;
  @override
  Widget build(BuildContext context) {
    media = MediaQuery.sizeOf(context);
    return const SizedBox.expand();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    DeviceEffects.instance.reset();
    CrtShader.instance.available.value = false;
  });

  group('the frame', () {
    test('sizes on 1920×1080', () {
      expect(RetroFrame.frameIn(PictureShape.original, _canvas), _canvas);
      expect(RetroFrame.frameIn(PictureShape.fill43, _canvas), const Size(1440, 1080));
      expect(RetroFrame.frameIn(PictureShape.fit43, _canvas), const Size(1440, 1080));
      expect(RetroFrame.frameIn(PictureShape.fit43, const Size(400, 400)), const Size(400, 300));
    });

    test('fill crops and fit shows everything', () {
      expect(RetroFrame.fitFor(PictureShape.fill43), BoxFit.cover);
      expect(RetroFrame.fitFor(PictureShape.fit43), BoxFit.contain);
      expect(RetroFrame.fitFor(PictureShape.original), BoxFit.contain);
    });

    testWidgets('in 4:3 what is inside has the frame as its screen, centred', (tester) async {
      _fullView(tester);
      await tester.pumpWidget(_app(const RetroFrame(
        retro: ResolvedRetro(shape: PictureShape.fill43),
        child: _Probe(),
      )));
      expect(_Probe.media, const Size(1440, 1080));
      final box = tester.getRect(find.byType(_Probe));
      expect(box, const Rect.fromLTWH(240, 0, 1440, 1080));
    });

    testWidgets('Original takes the whole space, with no surround', (tester) async {
      _fullView(tester);
      await tester.pumpWidget(_app(const RetroFrame(
        retro: ResolvedRetro(surround: Surround.charcoal),
        child: _Probe(),
      )));
      expect(_Probe.media, _canvas);
      expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color == const Color(0xFF26282C)), findsNothing);
      final clip = tester.widget<ClipRect>(find.descendant(of: find.byType(RetroFrame), matching: find.byType(ClipRect)).first);
      expect(clip.clipBehavior, Clip.none);
    });

    testWidgets('the logo sits inside the frame\'s title-safe margin', (tester) async {
      _fullView(tester);
      await tester.pumpWidget(_app(RetroFrame(
        retro: const ResolvedRetro(shape: PictureShape.fill43),
        child: Stack(children: [
          ChannelLogoBug(
            icon: const ChannelIcon(kind: ChannelIconKind.badge, value: 'KTV', color: 0xFFFF0000),
            mode: LogoMode.always,
            segment: null,
          ),
        ]),
      )));
      final rect = tester.getRect(find.byType(AnimatedOpacity));
      final box = ChannelLogoBug.boxIn(const Size(1440, 1080));
      expect(rect.right, 1680 - box.right);
      expect(rect.bottom, 1080 - box.bottom);
      expect(rect.left, greaterThan(240));
    });
  });

  group('the picture in a 4:3 frame', () {
    testWidgets('a full-screen card is scaled inside the frame; the video is asked to fill it', (tester) async {
      _fullView(tester);
      late Directory dir;
      late AppState app;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('retro-picture');
        app = await signedInApp(dir, fakeLibrary());
        await app.setMainRetro(const RetroSettings(shape: PictureShape.fill43));
      });
      final player = FakePlayer([]);
      final tuner = Tuner(app, player: player, clock: DateTime.now)
        ..prefetch = false
        ..preload = false
        ..channel = app.channels.first
        ..status = TunerStatus.offAir;
      addTearDown(() async {
        tuner.dispose();
        await tester.runAsync(() async {
          await app.close();
          await dir.delete(recursive: true);
        });
      });
      await tester.pumpWidget(MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: AppScope(app: app, tuner: tuner, child: const TvCanvas(child: TvPicture())),
      ));
      await tester.pump();
      expect(player.lastFit, BoxFit.cover);
      final card = tester.getRect(find.byType(StatusCard));
      expect(card.left, moreOrLessEquals(240));
      expect(card.width, moreOrLessEquals(1440));
      expect(card.height, moreOrLessEquals(810), reason: 'the whole card, not cropped');
    });
  });

  group('the surround', () {
    Future<void> show(WidgetTester tester, ResolvedRetro retro, {ChannelIcon? icon}) => tester.pumpWidget(_app(
          RetroFrame(retro: retro, icon: icon, child: const SizedBox.expand()),
        ));

    Finder colored(Color c) => find.byWidgetPredicate((w) => w is ColoredBox && w.color == c);

    testWidgets('colors', (tester) async {
      await show(tester, const ResolvedRetro(shape: PictureShape.fit43, surround: Surround.charcoal));
      expect(colored(const Color(0xFF26282C)), findsOneWidget);
      await show(tester, const ResolvedRetro(shape: PictureShape.fit43, surround: Surround.channel),
          icon: const ChannelIcon(kind: ChannelIconKind.badge, value: 'K', color: 0xFFD00000));
      expect(colored(const Color(0xFFD00000)), findsOneWidget);
    });

    testWidgets('an icon with no color, and a missing image, show black', (tester) async {
      await show(tester, const ResolvedRetro(shape: PictureShape.fit43, surround: Surround.channel),
          icon: const ChannelIcon(kind: ChannelIconKind.jellyfin, value: 'x'));
      expect(colored(Colors.black), findsOneWidget);
      final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('retro-frame'));
      final app = AppState((await tester.runAsync(() => AppStorage.at(dir!)))!);
      await tester.pumpWidget(_app(RetroFrame(
        retro: const ResolvedRetro(shape: PictureShape.fit43, surround: Surround.image, surroundImage: 'gone.png'),
        app: app,
        child: const SizedBox.expand(),
      )));
      expect(colored(Colors.black), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.runAsync(() => dir!.delete(recursive: true));
    });
  });

  group('CRT', () {
    test('scanlines stay whole device pixels, doubling when they would go under 2', () {
      expect(scanlinePeriod(1080, 480), 2);
      expect(scanlinePeriod(1080, 240), 5);
      expect(scanlinePeriod(2160, 480), 5);
      expect(scanlinePeriod(540, 480), 2);
      expect(scanlinePeriod(300, 480), 3, reason: '0.6 doubles to 2.5');
      expect(scanlinePeriod(100, 480), 3, reason: '0.2 doubles to 3.3');
    });

    test('the color matrix: none when nothing changes, gain with scanlines', () {
      expect(crtColorMatrix(const CrtValues()), isNull);
      final m = crtColorMatrix(const CrtValues(scanlines: CrtLevel.high))!;
      expect(m[0], closeTo(1.22, 0.001));
      expect(m[6], closeTo(1.22, 0.001));
      expect(m[12], closeTo(1.22, 0.001));
      final warm = crtColorMatrix(const CrtValues(color: CrtColor.warm))!;
      expect(warm[0], greaterThan(1));
      expect(warm[12], lessThan(1));
    });

    test('where the shader can\'t draw, the rest of the style still applies; the device switch ends it all', () {
      final arcade = CrtStyle.arcade.valuesWith(const CrtValues());
      final without = effectiveCrt(arcade, switchOn: true, shaderAvailable: false);
      expect(without.curvature, CrtLevel.off);
      expect(without.glow, CrtLevel.off);
      expect(without.scanlines, CrtLevel.high);
      expect(without.mask, CrtLevel.medium);
      expect(without.color, CrtColor.vivid);
      expect(arcade.curvature, CrtLevel.medium, reason: 'the saved values stay');
      expect(effectiveCrt(arcade, switchOn: true, shaderAvailable: true), arcade);
      expect(effectiveCrt(arcade, switchOn: false, shaderAvailable: true), const CrtValues());
    });

    testWidgets('no effect means no overlay, shader or color layer', (tester) async {
      await tester.pumpWidget(_app(const CrtLayers(values: CrtValues(), child: SizedBox.expand())));
      expect(find.byType(RawImage), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.layers.whereType<ColorFilterLayer>(), isEmpty);
    });

    testWidgets('an effect draws the overlay over its child, and the device switch removes it', (tester) async {
      final arcade = CrtStyle.arcade.valuesWith(const CrtValues());
      await tester.pumpWidget(_app(CrtLayers(values: arcade, child: const SizedBox.expand())));
      expect(find.byType(RawImage), findsOneWidget);
      expect(tester.layers.whereType<ColorFilterLayer>(), isNotEmpty);
      await DeviceEffects.instance.setOn(false);
      await tester.pump();
      expect(find.byType(RawImage), findsNothing);
      expect(tester.layers.whereType<ColorFilterLayer>(), isEmpty);
    });

    testWidgets('changing effect keeps what plays beneath in place', (tester) async {
      final key = GlobalKey<_StateProbeState>();
      Widget at(CrtValues v) => _app(CrtLayers(values: v, child: _StateProbe(key: key)));
      await tester.pumpWidget(at(const CrtValues()));
      final state = key.currentState;
      await tester.pumpWidget(at(CrtStyle.arcade.valuesWith(const CrtValues())));
      expect(key.currentState, same(state));
      await tester.pumpWidget(at(const CrtValues()));
      expect(key.currentState, same(state));
    });

    group('the fallback', () {
      const over = Duration(milliseconds: 30), under = Duration(milliseconds: 5);
      FrameBudgetWatcher watcher() => FrameBudgetWatcher(budget: const Duration(milliseconds: 16));

      test('fires after 10 over-budget seconds in a row', () {
        final w = watcher();
        for (var s = 0; s < 9; s++) {
          w.addFrame(over);
          expect(w.endSecond(), isFalse);
        }
        w.addFrame(over);
        expect(w.endSecond(), isTrue);
      });

      test('one good second starts it again', () {
        final w = watcher();
        for (var s = 0; s < 9; s++) {
          w.addFrame(over);
          w.endSecond();
        }
        w.addFrame(under);
        expect(w.endSecond(), isFalse);
        w.addFrame(over);
        expect(w.endSecond(), isFalse);
      });

      test('an isolated spike doesn\'t count, and a second with no frames ends the streak', () {
        final w = watcher();
        for (var s = 0; s < 20; s++) {
          for (var i = 0; i < 4; i++) {
            w.addFrame(under);
          }
          w.addFrame(const Duration(milliseconds: 98));
          expect(w.endSecond(), isFalse);
        }
        final x = watcher();
        for (var s = 0; s < 9; s++) {
          x.addFrame(over);
          x.endSecond();
        }
        expect(x.endSecond(), isFalse);
        x.addFrame(over);
        expect(x.endSecond(), isFalse);
      });
    });
  });

  group('overlay themes', () {
    final g = GuideTheme.cableGuide;

    testWidgets('outside a scope is Standard: export\'s offscreen cards stay as they are', (tester) async {
      late OverlayStyle style;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        style = OverlayStyle.of(c);
        return const SizedBox();
      })));
      expect(style.theme, OverlayThemeName.standard);
      expect(style.accent, g.accent);
    });

    test('Standard is today\'s look', () {
      final s = OverlayStyle.named(OverlayThemeName.standard, g);
      expect(s.display(60).fontFamily, g.display(60).fontFamily);
      expect(s.display(60).color, g.text);
      expect(s.body(26, color: g.textDim).color, g.textDim);
      expect(s.number('12'), '12');
      expect(s.backdrop, g.backdrop);
      expect(s.panel.color, g.panel.withValues(alpha: 0.94));
      expect(s.numberTile.color, g.accent);
      expect(s.logoPlate, isNull);
      expect(s.monoLogo, isFalse);
    });

    test('each theme has its own look', () {
      final vcr = OverlayStyle.named(OverlayThemeName.vcr, g);
      expect(vcr.display(40).fontFamily, OverlayStyle.vcrFont);
      expect(vcr.display(40).fontFamilyFallback, contains('Barlow'), reason: 'names the pixel font lacks');
      expect(vcr.panel.color, isNull, reason: 'no panels');
      expect(vcr.number('3'), 'CH 03');
      expect(vcr.number('12_'), '12_', reason: 'digits being typed');
      final cable = OverlayStyle.named(OverlayThemeName.cableBox, g);
      expect(cable.panel.color, const Color(0xFF0A2A8C));
      expect(cable.number('7'), '007');
      expect(cable.accent, const Color(0xFFFFE14D));
      final ident = OverlayStyle.named(OverlayThemeName.stationIdent, g);
      expect(ident.panel.gradient, isNotNull);
      expect(ident.banner.gradient, isNotNull);
    });

    testWidgets('the Channel color accent replaces the theme\'s', (tester) async {
      late OverlayStyle style;
      await tester.pumpWidget(_app(OverlayThemeScope.of(
        retro: const ResolvedRetro(overlay: OverlayThemeName.cableBox, accent: OverlayAccent.channel),
        icon: const ChannelIcon(kind: ChannelIconKind.badge, value: 'K', color: 0xFFD00000),
        child: Builder(builder: (c) {
          style = OverlayStyle.of(c);
          return const SizedBox();
        }),
      )));
      expect(style.accent, const Color(0xFFD00000));
    });

    testWidgets('the channel number and status cards read the theme', (tester) async {
      await tester.pumpWidget(_app(const OverlayThemeScope(
        theme: OverlayThemeName.vcr,
        child: Stack(children: [
          Positioned(top: 60, right: 90, child: ChannelNumberOsd(text: '3')),
        ]),
      )));
      expect(find.text('CH 03'), findsOneWidget);
      final text = tester.widget<Text>(find.text('CH 03'));
      expect(text.style!.fontFamily, OverlayStyle.vcrFont);
      await tester.pumpWidget(_app(const OverlayThemeScope(
        theme: OverlayThemeName.cableBox,
        child: StatusCard(icon: Icons.tv_off, title: 'OFF THE AIR'),
      )));
      expect(find.text('OFF THE AIR'), findsOneWidget);
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      expect((box.decoration as BoxDecoration).color, const Color(0xFF0A2A8C));
    });
  });

  group('the Retro look screen', () {
    late Directory dir;
    late AppState app;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('retro-screen');
      app = AppState(await AppStorage.at(dir));
      await app.start();
      await DeviceEffects.instance.load(app.storage);
    });

    tearDown(() async {
      DeviceEffects.instance.reset();
      await dir.delete(recursive: true);
    });

    Future<void> show(WidgetTester tester, {Size window = _canvas}) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tuner = Tuner(app, player: FakePlayer([]), clock: DateTime.now)
        ..prefetch = false
        ..preload = false;
      addTearDown(tuner.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: AppScope(
          app: app,
          tuner: tuner,
          child: TvCanvas(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const RetroLookScreen()),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('D-pad: focus starts on a control, moves down, and Select picks', (tester) async {
      await show(tester);
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(app.settings.retro.shape, PictureShape.fill43);
      await tester.tap(find.text('Arcade'));
      await tester.pump();
      expect(app.settings.retro.crt, CrtStyle.arcade);
    });

    testWidgets('touch picks; the preview follows at once; nothing restarts', (tester) async {
      await show(tester);
      await tester.tap(find.text('4:3 fit').first);
      await tester.pump();
      expect(app.settings.retro.shape, PictureShape.fit43);
      final frame = tester.widget<RetroFrame>(find.descendant(of: find.byType(RetroPreview), matching: find.byType(RetroFrame)));
      expect(frame.retro.shape, PictureShape.fit43);
    });

    testWidgets('curvature and glow are marked where they can\'t be drawn, and the choice is saved as it was', (tester) async {
      await show(tester);
      await tester.dragUntilVisible(find.text('CURVATURE'), find.byType(ListView), const Offset(0, -400));
      expect(find.text(RetroLookScreen.notAvailable), findsWidgets);
      expect(app.settings.retro.custom.curvature, CrtLevel.low);
    });

    testWidgets('the device switch and the export note are there', (tester) async {
      await show(tester);
      expect(find.text(retroExportNote), findsOneWidget);
      await tester.dragUntilVisible(find.text(RetroLookScreen.switchLabel), find.byType(ListView), const Offset(0, -400));
      await tester.tap(find.text(RetroLookScreen.switchLabel));
      await tester.pump();
      expect(DeviceEffects.instance.on, isFalse);
      expect(app.settings.toJson().toString(), isNot(contains('device')));
    });
  });
}

void _fullView(WidgetTester tester) {
  tester.view.physicalSize = _canvas;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key});
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

