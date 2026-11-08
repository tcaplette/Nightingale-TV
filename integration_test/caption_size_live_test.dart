// Caption sizes on a real server with real playback (caption-size 5.2–5.7).
//
// Sign in with the test-data.md server's account. On a device, run the host
// side beside it, which carries out the real key presses, taps, system
// settings and screenshots the test asks for:
//   flutter test integration_test/caption_size_live_test.dart -d emulator-5554 \
//     --dart-define=CAP_PLAT=tv --dart-define=CAP_URL=… --dart-define=CAP_USER=… --dart-define=CAP_PW=… | tee run.log
//   integration_test/caption_size_host.py run.log shots emulator-5554
//   tool/uhid_mouse/drive.py run.log emulator-5554    (CAP_PLAT=tv, after adb root)
// CAP_PLAT is tv or phone. On Linux, in a private X server: CAP_PLAT=linux,
// the same variables and SNAP_DIR come from the environment.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide SubtitleTrack;
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/caption_size.dart';
import 'package:nightingale_tv/playback/exo_tuner_player.dart';
import 'package:nightingale_tv/playback/subtitles.dart' show subtitleLabel;
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_clients.dart';
import 'package:nightingale_tv/ui/captions_picker.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/playback_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

/// From the environment, or on a device from --dart-define.
final _env = <String, String?>{
  ...Platform.environment,
  for (final (k, v) in const [
    ('CAP_PLAT', String.fromEnvironment('CAP_PLAT')),
    ('CAP_URL', String.fromEnvironment('CAP_URL')),
    ('CAP_USER', String.fromEnvironment('CAP_USER')),
    ('CAP_PW', String.fromEnvironment('CAP_PW')),
  ])
    if (v != '') k: v,
};

// ignore: avoid_print
void _say(String s) => print('CAP $s');

const _captionBackground = Color(0xaa000000);
const _imageCodecs = {'pgssub', 'hdmv_pgs_subtitle', 'dvdsub', 'dvd_subtitle', 'dvbsub', 'dvb_subtitle'};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final plat = _env['CAP_PLAT'];

  testWidgets('caption sizes on ${plat ?? '(CAP_PLAT unset)'}', (tester) async {
    if (!const {'linux', 'tv', 'phone'}.contains(plat)) {
      markTestSkipped('Set CAP_PLAT (linux, tv or phone) and CAP_URL, CAP_USER, CAP_PW.');
      return;
    }
    final linux = plat == 'linux';
    // Real taps from the host reach the app.
    if (!linux) binding.shouldPropagateDevicePointerEvents = true;
    if (linux) MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_caption_live');
    var household = Household(await AppStorage.at(dir), runAnalysis: false);
    late AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> host(String command) async {
      _say('HOST $command');
      await wait(const Duration(milliseconds: 1300));
    }

    Future<void> snap(String name) async {
      await wait(const Duration(milliseconds: 500));
      await host('snap $plat-$name');
      await wait(const Duration(seconds: 1));
    }

    /// The whole canvas at 1920 wide, from Flutter's layers (Linux: the
    /// window under Xvfb is smaller than the canvas).
    Future<void> canvasSnap(String name) async {
      final snapDir = _env['SNAP_DIR'];
      if (snapDir == null) return;
      await tester.pump();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image = await tester.runAsync(() => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      await File('$snapDir/$plat-canvas-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    // ---- Sign in ---------------------------------------------------------------
    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      final found = await identifyServer(_env['CAP_URL']!, deviceId: app.settings.installId, deviceName: app.deviceName);
      final client = found.client as JellyfinClient;
      await app.completeSignIn(await client.authenticateByName(_env['CAP_USER']!, _env['CAP_PW']!, serverName: found.info.name), client);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    _say('signed in, ${app.library.movies.length} movies');

    // ---- A channel of the titles needed, no breaks, nothing reported ------------
    MediaEntry movie(String title) => app.library.movies.firstWhere((m) => m.title == title);
    final text = movie('Dumb and Dumber');
    final pgs = movie('Footloose');
    final mixed = movie(linux ? 'Dazed and Confused' : "There's Something About Mary");
    final burned = movie('The Big Lebowski');
    final libraries = (await tester.runAsync(app.client!.libraries))!;
    final movies = libraries.firstWhere((l) => l.name.toLowerCase().contains('movie'));
    await tester.runAsync(() async {
      await app.setGlobalPlan(BreakPlan.off);
      await app.setPlayback(app.settings.playback.copyWith(captions: true, reportPlayback: false));
    });
    final ch = (await tester.runAsync(() => app.createCustomChannel(
        'Captions',
        ChannelSource(roots: [PoolRoot(itemId: movies.id, libraryId: movies.id, label: movies.name)], includeMovies: true),
        order: PlaybackOrder.cyclic)))!;
    ch.playlist = [text.id, pgs.id, mixed.id, burned.id];
    await tester.runAsync(() => app.updateChannel(ch));

    ScheduledProgram airing(Channel on, MediaEntry item) {
      final s = app.scheduleFor(on)!;
      var seg = s.playbackAt(DateTime.now());
      for (var i = 0; i < 500; i++) {
        if (seg.item?.id == item.id) return seg;
        seg = s.playbackAt(seg.end);
      }
      throw StateError('${item.title} not on ${on.name}');
    }

    late Tuner tuner;
    Future<void> showApp() async {
      await tester.pumpWidget(NightingaleTvApp(household: household));
      await wait(const Duration(seconds: 2));
      tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    }

    Future<void> playing() async {
      for (var i = 0; i < 400 && tuner.status != TunerStatus.playing; i++) {
        await wait(const Duration(milliseconds: 100));
      }
      expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    }

    /// Tunes [on] with [item] on for [into] already.
    Future<void> tuneTo(Channel on, MediaEntry item, Duration into) async {
      final seg = airing(on, item);
      on.anchor = on.anchor.add(DateTime.now().subtract(into).difference(seg.start));
      on.slotCarry = null;
      await tester.runAsync(() => app.updateChannel(on));
      await tester.runAsync(() => tuner.tune(on));
      await playing();
      expect(tuner.segment?.item?.id, item.id);
      _say('on air: ${item.title}, converting=${tuner.converting}');
    }

    Future<List<SubtitleTrack>> tracks() async => (await tester.runAsync(tuner.loadSubtitleTracks)) ?? const [];

    Future<void> pick(SubtitleTrack? track) async {
      await tester.runAsync(() => tuner.pickSubtitle(track));
      await wait(const Duration(seconds: 2));
    }

    Future<void> setSize(CaptionSize? size) async {
      await tester.runAsync(() => app.setPlayback(app.settings.playback.copyWith(captionSize: () => size)));
      await wait(const Duration(milliseconds: 400));
    }

    /// The text cue showing now.
    String cue() {
      final media = tuner.media;
      if (media is ExoTunerPlayer) return media.cues.value.text.join(' / ');
      if (media is MediaKitTunerPlayer) return media.player.state.subtitle.where((l) => l.isNotEmpty).join(' / ');
      return '';
    }

    /// Plays until a text cue shows, then holds that picture.
    Future<void> holdOnCue() async {
      await tester.runAsync(tuner.media.resume);
      final end = DateTime.now().add(const Duration(seconds: 90));
      while (cue().isEmpty) {
        if (DateTime.now().isAfter(end)) fail('no text cue in 90 s (track ${tuner.shownSubtitle})');
        await wait(const Duration(milliseconds: 120));
      }
      await tester.runAsync(tuner.media.pause);
      await wait(const Duration(milliseconds: 500));
      _say('holding on cue "${cue()}"');
    }

    Finder captionText() => find.byWidgetPredicate((w) => w is Text && w.style?.backgroundColor == _captionBackground && w.data != captionSampleText);

    /// The caption's drawn size on the canvas: font size × box scale.
    double captionPx() {
      final t = tester.widget<Text>(captionText().first);
      return t.textScaler!.scale(t.style!.fontSize!);
    }

    String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

    final ok = linux ? LogicalKeyboardKey.enter : LogicalKeyboardKey.select;
    final adbNames = {
      LogicalKeyboardKey.arrowUp: 'DPAD_UP',
      LogicalKeyboardKey.arrowDown: 'DPAD_DOWN',
      LogicalKeyboardKey.arrowLeft: 'DPAD_LEFT',
      LogicalKeyboardKey.arrowRight: 'DPAD_RIGHT',
      LogicalKeyboardKey.select: 'DPAD_CENTER',
      LogicalKeyboardKey.goBack: 'BACK',
      LogicalKeyboardKey.keyM: 'M',
    };
    final back = linux ? LogicalKeyboardKey.escape : LogicalKeyboardKey.goBack;
    final keysDown = <LogicalKeyboardKey>{};

    Future<void> press(LogicalKeyboardKey k) async {
      if (linux) {
        await tester.sendKeyEvent(k);
        await wait(const Duration(milliseconds: 450));
        return;
      }
      // The emulator can lose an injected key (the first after launch,
      // sometimes): sent again until it has arrived.
      for (var attempt = 0; attempt < 4; attempt++) {
        keysDown.clear();
        await host('key ${adbNames[k]}');
        for (var i = 0; i < 40 && !keysDown.contains(k); i++) {
          await wait(const Duration(milliseconds: 100));
        }
        if (keysDown.contains(k)) {
          await wait(const Duration(milliseconds: 300));
          return;
        }
        _say('key ${adbNames[k]} did not arrive; sending it again');
      }
      fail('key ${adbNames[k]} never arrived');
    }

    /// Presses [k] until focus is on one of [labels] (at most [limit] times).
    Future<void> moveTo(LogicalKeyboardKey k, Set<String> labels, {int limit = 40}) async {
      for (var i = 0; i < limit && !labels.contains(focused()); i++) {
        await press(k);
      }
      expect(labels, contains(focused()));
    }

    Finder inDialog(Finder f) => find.descendant(of: find.byType(Dialog), matching: f);

    TvToggle toggleIn(Finder where, String label) => tester.widget<TvToggle>(find.descendant(of: where, matching: find.byWidgetPredicate((w) => w is TvToggle && w.label == label)));

    Set<String> sizeLabels() => {for (final s in CaptionSize.values) s.label};

    double samplePx() {
      final t = tester.widget<Text>(find.text(captionSampleText));
      return t.textScaler!.scale(t.style!.fontSize!);
    }

    /// Right shows the on-screen row, Up reaches Guide; Menu, Sleep, Captions.
    Future<void> openPickerByKeys() async {
      for (final k in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowRight,
        ok,
      ]) {
        await press(k);
      }
      await wait(const Duration(seconds: 2));
      expect(find.byType(Dialog), findsOneWidget, reason: 'the picker is open');
    }

    Future<void> openPickerDirectly() async {
      showCaptionsPicker(tester.element(find.byType(Overlay).first), tuner);
      await wait(const Duration(seconds: 2));
      expect(find.byType(Dialog), findsOneWidget, reason: 'the picker is open');
    }

    /// The physical pixel of [f]'s centre, for the host's input.
    String physical(Finder f) {
      final c = tester.getCenter(f.first);
      final r = tester.view.devicePixelRatio;
      return '${(c.dx * r).round()} ${(c.dy * r).round()}';
    }

    /// Opens Menu > Playback and scrolls to the sizes with keys.
    Future<void> menuSizesByKeys() async {
      await press(LogicalKeyboardKey.keyM);
      await wait(const Duration(seconds: 1));
      await moveTo(LogicalKeyboardKey.arrowDown, {'Playback'});
      await press(ok);
      await wait(const Duration(seconds: 1));
      expect(find.byType(PlaybackScreen), findsOneWidget);
      await moveTo(LogicalKeyboardKey.arrowDown, sizeLabels());
    }

    Future<void> leaveMenu() async {
      await press(back);
      await wait(const Duration(seconds: 1));
      // One more only if the menu is still up: Back on the TV leaves the app.
      if (find.byType(MenuScreen).evaluate().isNotEmpty) {
        await press(back);
        await wait(const Duration(seconds: 1));
      }
      expect(find.byType(PlaybackScreen), findsNothing);
      expect(find.byType(MenuScreen), findsNothing);
    }

    Future<void> restart() async {
      await tester.runAsync(() async {
        await tuner.stop();
        await household.app?.close();
      });
      await tester.pumpWidget(const SizedBox());
      household = Household(await tester.runAsync(() => AppStorage.at(dir)) as AppStorage, runAnalysis: false);
      await tester.runAsync(() async {
        await household.start();
        app = household.app!;
      });
      expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    }

    Channel channel() => app.channels.firstWhere((c) => c.name == 'Captions');

    HardwareKeyboard.instance.addHandler((e) {
      if (e is KeyDownEvent) keysDown.add(e.logicalKey);
      return false;
    });
    await showApp();
    await tester.runAsync(tuner.stop);

    // ---- Phone: tap the sizes upright, the sample matching the picture ---------
    if (plat == 'phone') {
      await tuneTo(ch, text, const Duration(minutes: 12));
      await holdOnCue();
      await openPickerDirectly();
      for (final s in CaptionSize.values) {
        await host('tap ${physical(inDialog(find.text(s.label)))}');
        expect(app.captionSize.value, s, reason: 'a real tap on ${s.label}');
        expect(find.byType(Dialog), findsOneWidget);
        // On screen: the picture's captions are inside its own scaled box.
        final sample = tester.getRect(find.text(captionSampleText)).height;
        final caption = tester.getRect(captionText().first).height;
        expect(sample, closeTo(caption, 1), reason: 'the sample is as tall on screen as the caption on the picture');
        _say('phone ${s.label}: on screen sample ${sample.toStringAsFixed(1)} caption ${caption.toStringAsFixed(1)}');
        await snap('picker-${s.name}');
      }
      await tester.runAsync(tuner.stop);
      await household.app?.close();
      binding.shouldPropagateDevicePointerEvents = false;
      return;
    }

    // ---- Text captions: the picker by keys ----------------------------------------
    await tuneTo(ch, text, const Duration(minutes: 12));
    final textTracks = await tracks();
    await wait(const Duration(seconds: 2));
    expect(tuner.shownSubtitle, isNotNull, reason: 'captions on: $textTracks');
    await holdOnCue();
    expect(app.captionSize.value, CaptionSize.medium);
    expect(captionPx(), 54, reason: 'the default, whole canvas');
    await openPickerByKeys();
    final current = subtitleLabel(tuner.shownSubtitle!);
    expect(focused(), current, reason: 'opens on the current track');
    await moveTo(LogicalKeyboardKey.arrowUp, sizeLabels(), limit: textTracks.length + 2);
    _say('Up reached the sizes at ${focused()}');
    expect(focused(), 'Small', reason: 'above the left-aligned rows');
    await press(LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Medium');
    await press(LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Large');
    await press(ok);
    await wait(const Duration(milliseconds: 500));
    expect(find.byType(Dialog), findsOneWidget, reason: 'stays open');
    expect(focused(), 'Large', reason: 'keeps focus');
    expect(app.settings.playback.captionSize, CaptionSize.large);
    expect(captionPx(), 68, reason: 'the caption behind the picker');
    expect(samplePx(), 68);
    await snap('picker-large');
    await press(back);
    await wait(const Duration(seconds: 1));
    expect(find.byType(Dialog), findsNothing);

    // ---- Each size, measured on the same held picture -------------------------------
    for (final s in CaptionSize.values) {
      await setSize(s);
      expect(captionPx(), s.px);
      await snap('text-${s.name}');
      await canvasSnap('text-${s.name}');
      final box = tester.getSize(captionText().first);
      _say('text ${s.label}: drawn ${captionPx()} box ${box.width.round()}x${box.height.round()} cue "${cue()}"');
    }

    // ---- The menu edits the same value ------------------------------------------
    await setSize(CaptionSize.medium);
    await menuSizesByKeys();
    await moveTo(LogicalKeyboardKey.arrowDown, {'Extra large'}, limit: 5);
    await press(ok);
    await wait(const Duration(milliseconds: 500));
    expect(app.settings.playback.captionSize, CaptionSize.extraLarge);
    expect(toggleIn(find.byType(PlaybackScreen), 'Extra large').on, isTrue);
    await leaveMenu();
    expect(captionPx(), 84);
    await openPickerByKeys();
    expect(toggleIn(find.byType(Dialog), 'Extra large').on, isTrue, reason: 'the picker agrees with the menu');
    await press(back);
    await wait(const Duration(seconds: 1));

    // ---- A pointer: the picker and the menu -----------------------------------------
    Future<void> point(Finder f) async {
      if (linux) {
        await tester.tap(f.first);
        await wait(const Duration(milliseconds: 500));
      } else {
        // A real mouse (tool/uhid_mouse/drive.py): hover first, as a hand
        // would, then click where the target is now.
        _say('UHIDMOVE ${physical(f)}');
        await wait(const Duration(seconds: 9));
        _say('UHID ${physical(f)}');
        await wait(const Duration(seconds: 9));
      }
    }

    await openPickerDirectly();
    await point(inDialog(find.text('Small')));
    expect(app.captionSize.value, CaptionSize.small, reason: 'a pointer in the picker');
    expect(find.byType(Dialog), findsOneWidget);
    await press(back);
    await wait(const Duration(seconds: 1));
    await press(LogicalKeyboardKey.keyM);
    await wait(const Duration(seconds: 1));
    await moveTo(LogicalKeyboardKey.arrowDown, {'Playback'});
    await press(ok);
    await wait(const Duration(seconds: 1));
    await moveTo(LogicalKeyboardKey.arrowDown, sizeLabels());
    await wait(const Duration(milliseconds: 500));
    await point(find.descendant(of: find.byType(PlaybackScreen), matching: find.text('Extra large')));
    expect(app.captionSize.value, CaptionSize.extraLarge, reason: 'a pointer in the menu');
    await leaveMenu();
    _say('pointer: picker and menu work');

    // ---- Survives a restart ------------------------------------------------------
    await restart();
    expect(app.settings.playback.captionSize, CaptionSize.extraLarge);
    expect(app.captionSize.value, CaptionSize.extraLarge);
    await showApp();
    await tuneTo(channel(), text, const Duration(minutes: 14));
    await holdOnCue();
    expect(captionPx(), 84, reason: 'after a restart');
    await snap('text-after-restart');
    _say('restart: still Extra large');

    // ---- The guide's small picture ------------------------------------------------
    if (linux) {
      await tester.runAsync(tuner.media.resume);
      await wait(const Duration(seconds: 1));
      await press(ok);
      await wait(const Duration(seconds: 2));
      await tester.runAsync(tuner.media.pause);
      final inGuide = captionPx();
      expect(inGuide, lessThan(84), reason: 'smaller in the preview');
      final box = tester.getSize(find.ancestor(of: captionText().first, matching: find.byType(LayoutBuilder)).first);
      final scale = inGuide / 84;
      _say('guide preview: drawn ${inGuide.toStringAsFixed(1)} in a ${box.width.round()}x${box.height.round()} box, scale ${scale.toStringAsFixed(3)}');
      await canvasSnap('guide');
      await press(back);
      await wait(const Duration(seconds: 1));
      await tester.runAsync(tuner.media.resume);
    }

    // ---- Image tracks ---------------------------------------------------------------
    Future<SubtitleTrack> imageTrack() async => (await tracks()).firstWhere((t) => _imageCodecs.contains(t.codec.toLowerCase()));

    await setSize(CaptionSize.medium);
    await tuneTo(channel(), pgs, const Duration(minutes: 20));
    expect(tuner.converting, isFalse, reason: 'direct play, for a track the player draws');
    await pick(await imageTrack());
    if (linux) {
      final mpv = (tuner.media as MediaKitTunerPlayer).debugDecks.first.platform as NativePlayer;
      Future<String?> get(String k) => tester.runAsync(() => mpv.getProperty(k));
      expect(await get('sub-visibility'), 'yes');
      expect(double.parse((await get('sub-scale'))!), closeTo(1, 0.001));
      final snapDir = _env['SNAP_DIR']!;
      Future<void> shot(String n) => tester.runAsync(() => Process.run('import', ['-window', 'root', '$snapDir/$plat-$n.png']));
      Future<int> diff(String a, String b) async {
        final r = (await tester.runAsync(() => Process.run('compare', ['-metric', 'AE', '-fuzz', '12%', '$snapDir/$plat-$a.png', '$snapDir/$plat-$b.png', 'null:'])))!;
        return double.tryParse('${r.stderr}'.trim().split(' ').first)?.round() ?? -1;
      }

      var held = false;
      for (var i = 0; i < 70 && !held; i++) {
        await wait(const Duration(seconds: 2));
        await tester.runAsync(tuner.media.pause);
        await wait(const Duration(milliseconds: 900));
        await shot('pgs-medium');
        await tester.runAsync(() => mpv.setProperty('sub-visibility', 'no'));
        await wait(const Duration(milliseconds: 900));
        await shot('pgs-none');
        await tester.runAsync(() => mpv.setProperty('sub-visibility', 'yes'));
        if (await diff('pgs-medium', 'pgs-none') > 800) {
          held = true;
        } else {
          await tester.runAsync(tuner.media.resume);
        }
      }
      expect(held, isTrue, reason: 'an image caption appeared over the picture');
      await setSize(CaptionSize.extraLarge);
      await wait(const Duration(seconds: 1));
      expect(double.parse((await get('sub-scale'))!), closeTo(84 / 54, 0.001));
      await shot('pgs-extraLarge');
      _say('pgs: shown, sub-scale follows');
      await tester.runAsync(tuner.media.resume);
    } else {
      final exo = tuner.media as ExoTunerPlayer;
      final end = DateTime.now().add(const Duration(seconds: 120));
      while (exo.cues.value.images.isEmpty) {
        if (DateTime.now().isAfter(end)) fail('no image cue in 120 s');
        await wait(const Duration(milliseconds: 120));
      }
      await tester.runAsync(exo.pause);
      await wait(const Duration(milliseconds: 500));
      final authored = tester.getRect(find.descendant(of: find.byType(ExoImageCues), matching: find.byType(Image)).first);
      await snap('pgs-medium');
      await setSize(CaptionSize.extraLarge);
      final grown = tester.getRect(find.descendant(of: find.byType(ExoImageCues), matching: find.byType(Image)).first);
      await snap('pgs-extraLarge');
      _say('pgs: ${authored.width.round()}x${authored.height.round()} -> ${grown.width.round()}x${grown.height.round()}, bottom ${authored.bottom.round()} -> ${grown.bottom.round()}');
      expect(grown.width / authored.width, closeTo(84 / 54, 0.01));
      expect(grown.center.dx, closeTo(authored.center.dx, 1));
      expect(grown.bottom, closeTo(authored.bottom, 1));
      await tester.runAsync(exo.resume);
    }

    // ---- From an image track back to text: drawn once --------------------------------
    await setSize(CaptionSize.large);
    await tuneTo(channel(), mixed, const Duration(minutes: 25));
    final all = await tracks();
    _say('mixed tracks: ${[for (final t in all) t.codec]}');
    await pick(all.firstWhere((t) => _imageCodecs.contains(t.codec.toLowerCase())));
    await wait(const Duration(seconds: 3));
    await pick(all.firstWhere((t) => !_imageCodecs.contains(t.codec.toLowerCase())));
    await holdOnCue();
    expect(captionPx(), 68);
    if (linux) {
      final mpv = (tuner.media as MediaKitTunerPlayer).debugDecks.first.platform as NativePlayer;
      expect(await tester.runAsync(() => mpv.getProperty('sub-visibility')), 'no', reason: "Flutter alone draws a text track");
    } else {
      expect((tuner.media as ExoTunerPlayer).cues.value.images, isEmpty, reason: 'text alone');
    }
    await snap('back-to-text');
    await tester.runAsync(tuner.media.resume);
    _say('back to text: drawn once');

    if (linux) {
      await tester.runAsync(tuner.stop);
      await household.app?.close();
      _say('DONE');
      return;
    }

    // ---- Burned in (a 10-bit title converts on the emulator) -------------------------
    await tuneTo(channel(), burned, const Duration(minutes: 30));
    await tracks();
    final until = DateTime.now().add(const Duration(seconds: 60));
    while (!tuner.captionsBurnedIn) {
      if (DateTime.now().isAfter(until)) fail('never burned in (converting=${tuner.converting}, ${tuner.shownSubtitle})');
      await wait(const Duration(milliseconds: 200));
    }
    await playing();
    await openPickerByKeys();
    expect(find.text(burnedInCaptionsNote), findsOneWidget);
    expect(inDialog(find.text('Large')), findsNothing, reason: 'the note replaces the sizes');
    await snap('burned-picker');
    await moveTo(LogicalKeyboardKey.arrowUp, {'Off'}, limit: 6);
    await press(ok);
    await wait(const Duration(seconds: 2));
    expect(find.byType(Dialog), findsNothing, reason: 'a track row still works');
    expect(tuner.captions, isFalse);
    _say('burned in: the note shows, and the rows work');
    await tester.runAsync(() => app.setPlayback(app.settings.playback.copyWith(captions: true)));

    // ---- The system's caption size ---------------------------------------------------
    /// Out of the app and back. No pumping while away: there are no frames
    /// to wait for.
    Future<void> awayAndBack() async {
      Future<void> pause(int seconds) => tester.runAsync(() => Future<void>.delayed(Duration(seconds: seconds))).then((_) {});
      _say('HOST home');
      await pause(5);
      _say('HOST launch');
      await pause(6);
      await wait(const Duration(seconds: 1));
    }

    await setSize(null);
    await host('scale 2.0');
    await restart();
    expect(app.settings.playback.captionSize, isNull);
    expect(app.captionSize.value, CaptionSize.extraLarge, reason: 'system 200%, no saved size');
    await showApp();
    await tester.runAsync(tuner.stop);
    _say('system 2.0 at launch: ${app.captionSize.value.label}');
    await host('scale 0.5');
    await awayAndBack();
    expect(app.captionSize.value, CaptionSize.small, reason: 'resume reads it again');
    _say('system 0.5 on resume: ${app.captionSize.value.label}');
    await tester.runAsync(() => app.setPlayback(app.settings.playback.copyWith(captionSize: () => CaptionSize.large)));
    await host('scale 2.0');
    await awayAndBack();
    expect(app.captionSize.value, CaptionSize.large, reason: 'a size chosen in the app wins');
    await host('scale-clear');
    _say('in-app choice wins');

    await tester.runAsync(tuner.stop);
    await household.app?.close();
    binding.shouldPropagateDevicePointerEvents = false;
    _say('DONE');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
