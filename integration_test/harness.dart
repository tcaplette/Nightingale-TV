// Shared setup for the UI tests that need no server: a signed-in app with a
// fake library in a temp folder, plus helpers to press keys, tap and take
// screenshots (saved to SNAP_DIR when it's set).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/commercials/analysis/analysis_cache.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/analysis/reel_cutter.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/broadcast_art.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/remote/remote_control.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import '../test/fixtures.dart';
import 'fake_jellyfin.dart';

class UiHarness {
  UiHarness._(this.tester, this.household, this._dir, this.server);

  final WidgetTester tester;
  final Household household;
  final Directory _dir;

  /// The fake Jellyfin, when started with one.
  final FakeJellyfin? server;

  /// The profile that's watching.
  AppState get app => household.app!;
  Tuner get tuner => AppScope.tunerOf(tester.element(find.byType(TvScreen, skipOffstage: false)));

  /// Starts the app on the TV screen with [library]. Its server address is
  /// unreachable, so playback shows "No signal".
  ///
  /// The library is saved the way installs from before profiles saved it,
  /// so every run also moves an existing setup into its first profile.
  ///
  /// With [remote], the phone remote is turned on (on a free port).
  ///
  /// With [server] (the items of [library], see [fakeItems]), a fake
  /// Jellyfin serves them, plus libraries and folders, so screens that ask
  /// the server work. [reelCuts] seeds analysis results: reel id → clips.
  /// [settings] and [editChannels] change what's saved first (see
  /// [signedInApp]). Background analysis is off.
  ///
  /// With [export], Live TV export is set up (off until turned on, with
  /// discovery kept off the real network).
  static Future<UiHarness> start(WidgetTester tester, LibraryIndex library,
      {bool remote = false,
      bool export = false,
      FakeItems? server,
      Map<String, List<Span>> reelCuts = const {},
      Map<String, Object?>? settings,
      void Function(List<Map<String, Object?>> channels)? editChannels}) async {
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_ui');
    late final FakeJellyfin? fake;
    final household = (await tester.runAsync(() async {
      fake = server == null ? null : await FakeJellyfin.start(server);
      final seeded = await signedInApp(dir, library,
          serverId: fake == null ? null : FakeJellyfin.serverId,
          serverUrl: fake?.url ?? 'http://127.0.0.1:9',
          settings: settings,
          editChannels: editChannels);
      await seeded.close();
      if (reelCuts.isNotEmpty) {
        final cache = await AnalysisCache.open(seeded.storage.analysisDir, FakeJellyfin.serverId);
        reelCuts.forEach((id, cuts) {
          cache.recordReel(library[id]!, ReelCuts(CutSource.detection, cuts), at: DateTime(2000));
        });
        await cache.flush();
        await cache.close();
      }
      final household = Household(await AppStorage.at(dir), runAnalysis: false);
      await household.start();
      if (remote) {
        // In tests the window may be in the background; "waking" it is
        // telling Flutter it's in front.
        household.remote = RemoteControl(household,
            wake: () async => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
        await household.remote!.setEnabled(true, port: 0);
      }
      if (export) {
        final service = household.export = ExportService(household,
            ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {},
            art: BroadcastArt(Directory('${dir.path}/export_cache')));
        await service.load();
      }
      return household;
    }))!;
    expect(household.app?.phase, AppPhase.ready);
    final h = UiHarness._(tester, household, dir, fake);
    await tester.pumpWidget(NightingaleTvApp(household: household));
    await h.wait(const Duration(seconds: 1));
    return h;
  }

  /// Lets [d] of real time pass, drawing frames all along so animations
  /// such as page transitions run to the end, as they would in the app.
  Future<void> wait(Duration d) async {
    final end = DateTime.now().add(d);
    do {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    } while (DateTime.now().isBefore(end));
    await tester.pump();
  }

  Future<void> snap(String name) async {
    final snapDir = Platform.environment['SNAP_DIR'];
    if (snapDir == null) return;
    await tester.pump();
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await tester.runAsync(
        () => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    await File('$snapDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  }

  Future<void> press(LogicalKeyboardKey key, {Duration after = const Duration(milliseconds: 500)}) async {
    // Flutter drops keyboard focus while its window is in the background,
    // which the test window is whenever someone is using another app.
    // Tell it the window is in front so key presses reach the app.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.sendKeyEvent(key);
    await wait(after);
  }

  Future<void> tapOn(Finder finder) async {
    // Lists build lazily: scroll until the target exists (up first, then down).
    if (finder.evaluate().isEmpty) {
      final list = find.byType(Scrollable).first;
      try {
        await tester.scrollUntilVisible(finder, -300, scrollable: list, maxScrolls: 10);
      } on StateError {
        await tester.scrollUntilVisible(finder, 300, scrollable: list);
      }
    }
    final target = finder.last;
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await wait(const Duration(milliseconds: 600));
  }

  Future<void> tap(String text) => tapOn(find.text(text));

  /// The label of the button (or toggle) with keyboard focus, if any.
  String? focusedLabel() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    String? label;
    context.visitAncestorElements((e) {
      final widget = e.widget;
      if (widget is TvButton) {
        label = widget.label;
        return false;
      }
      return true;
    });
    return label;
  }

  static final _opposite = {
    LogicalKeyboardKey.arrowLeft: LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowRight: LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowUp: LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown: LogicalKeyboardKey.arrowUp,
  };

  /// Presses [key] until the focused button is [label]. If focus stops
  /// moving first (the end of a row), tries the other way.
  Future<void> moveTo(String label, LogicalKeyboardKey key, {int tries = 20}) async {
    for (final k in [key, _opposite[key]!]) {
      for (var i = 0; i < tries && focusedLabel() != label; i++) {
        final before = FocusManager.instance.primaryFocus;
        await press(k, after: const Duration(milliseconds: 250));
        if (FocusManager.instance.primaryFocus == before) break;
      }
      if (focusedLabel() == label) return;
    }
    expect(focusedLabel(), label, reason: 'arrow keys never reached "$label"');
  }

  /// Moves to [label] with [key], then presses OK.
  Future<void> choose(String label, LogicalKeyboardKey key) async {
    await moveTo(label, key);
    await press(LogicalKeyboardKey.enter, after: const Duration(milliseconds: 700));
  }

  /// Opens the menu from the TV screen and picks [item].
  Future<void> openMenuItem(String item) async {
    await press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
    await tap(item);
  }

  Future<void> dispose() async {
    await tester.runAsync(() async {
      await household.remote?.stop();
      await household.export?.stop();
      await household.setExportedProfiles({});
      await household.app?.close();
      await server?.close();
    });
    await tester.pumpWidget(const SizedBox());
    await wait(const Duration(milliseconds: 500));
    await _dir.delete(recursive: true);
  }
}
