// Android-only behavior, exercised on Linux through PlatformInfo's override,
// and the same code paths on Linux, which must not change.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nightingale_tv/commercials/analysis/ffmpeg_runner.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/icons/custom_icons.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/platform/android_back_bridge.dart';
import 'package:nightingale_tv/platform/device_images.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/remote/remote_control.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/commercials_screen.dart';
import 'package:nightingale_tv/ui/device_image_picker_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(PlatformInfo.debugReset);

  group('platform', () {
    test('the real host is Linux, not Android, even inside flutter test', () {
      expect(PlatformInfo.isAndroid, isFalse);
      expect(PlatformInfo.isDesktop, isTrue);
    });

    test('the override switches to Android and back', () {
      PlatformInfo.debugOverride = TargetPlatform.android;
      expect(PlatformInfo.isAndroid, isTrue);
      expect(PlatformInfo.isDesktop, isFalse);
      PlatformInfo.debugOverride = TargetPlatform.linux;
      expect(PlatformInfo.isAndroid, isFalse);
      expect(PlatformInfo.isDesktop, isTrue);
    });
  });

  group('device name', () {
    const channel = MethodChannel('nightingale_tv/platform');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('on a PC it is the host name, without asking a channel', () async {
      messenger.setMockMethodCallHandler(channel, (call) => fail('no channel on desktop'));
      await PlatformInfo.init();
      expect(PlatformInfo.deviceName, Platform.localHostname);
    });

    test('on Android it is what the platform reports', () async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (call) async => switch (call.method) {
            'deviceName' => 'SHIELD Android TV',
            'isTelevision' => true,
            _ => fail('unexpected ${call.method}'),
          });
      await PlatformInfo.init();
      expect(PlatformInfo.deviceName, 'SHIELD Android TV');
      expect(PlatformInfo.deviceName, isNot('localhost'));
      expect(PlatformInfo.isTelevision, isTrue);
    });

    test('a phone is not a TV, and neither is a PC', () async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (call) async => call.method == 'deviceName' ? 'Pixel 9' : false);
      await PlatformInfo.init();
      expect(PlatformInfo.isTelevision, isFalse);
      PlatformInfo.debugOverride = TargetPlatform.linux;
      expect(PlatformInfo.isTelevision, isFalse);
    });

    test('on Android with no answer it is still not localhost', () async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
      await PlatformInfo.init();
      expect(PlatformInfo.deviceName, 'Android');
    });
  });

  group('no programs on Android', () {
    test('ffmpeg is unavailable without starting a process', () async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      final runner = FfmpegRunner(
        run: (exe, args) => fail('started $exe on Android'),
        start: (exe, args) => fail('started $exe on Android'),
      );
      expect(await runner.available(), isFalse);
    });

    test('on Linux ffmpeg is still looked for', () async {
      final started = <String>[];
      final runner = FfmpegRunner(run: (exe, args) async {
        started.add(exe);
        return ProcessResult(1, 0, 'ffmpeg version 8.0', '');
      });
      expect(await runner.available(), isTrue);
      expect(started, ['ffmpeg']);
    });

    test('private files are written without chmod on Android', () async {
      final dir = await Directory.systemTemp.createTemp('nightingale_tv_android');
      addTearDown(() => dir.delete(recursive: true));
      final storage = await AppStorage.at(dir);

      PlatformInfo.debugOverride = TargetPlatform.android;
      await storage.writeJson('android.json', {'a': 1}, private: true);
      // Left at the default mode: chmod never ran.
      expect(File('${dir.path}/android.json').statSync().mode & 0x1ff, isNot(0x180));

      PlatformInfo.debugOverride = TargetPlatform.linux;
      await storage.writeJson('linux.json', {'a': 1}, private: true);
      expect(File('${dir.path}/linux.json').statSync().mode & 0x1ff, 0x180, reason: 'still 600 on Linux');
    });

    test('the commercials screen says what Android can do', () {
      PlatformInfo.debugOverride = TargetPlatform.android;
      expect(CommercialsScreen.ffmpegMissingText(1),
          'Long commercial videos without chapters can\'t be split on this device (1 waiting).');
      expect(CommercialsScreen.ffmpegMissingText(0),
          'Long commercial videos without chapters can\'t be split on this device.');
      expect(CommercialsScreen.ffmpegMissingText(3), isNot(contains('ffmpeg')));
      expect(CommercialsScreen.ffmpegMissingText(3), isNot(contains('Break points')));
    });

    test('on Linux it still says to install ffmpeg', () {
      expect(CommercialsScreen.ffmpegMissingText(2),
          'Install ffmpeg to split long commercial videos (2 waiting). '
          'Break points also land more naturally with it.');
    });
  });

  group('Live TV export', () {
    late Directory dir;
    late Household household;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_android_export');
      await signedInApp(dir, fakeLibrary());
      household = Household(await AppStorage.at(dir), runAnalysis: false);
      await household.start();
    });

    tearDown(() async {
      await household.export?.stop();
      await household.app?.close();
      await dir.delete(recursive: true);
    });

    test('is never set up on Android, whatever export.json says', () async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      final settings = File('${dir.path}/export.json');
      await settings.writeAsString('{"enabled":true}');
      await startExport(household, cacheDir: () async => dir);
      expect(household.export, isNull);
      expect(await settings.readAsString(), '{"enabled":true}', reason: 'the file is left alone');
    });

    test('is still set up on Linux', () async {
      await startExport(household, cacheDir: () async => dir);
      expect(household.export, isNotNull);
    });
  });

  group('phone remote in the background', () {
    late Directory dir;
    late Household household;
    late RemoteControl remote;
    final binding = TestWidgetsFlutterBinding.instance;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_android_remote');
      await signedInApp(dir, fakeLibrary());
      household = Household(await AppStorage.at(dir), runAnalysis: false);
      await household.start();
      remote = RemoteControl(household, dispatch: (key, physical) => true);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    tearDown(() async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await remote.stop();
      await household.app?.close();
      await dir.delete(recursive: true);
    });

    /// Home, then back to the app, as Android reports them.
    Future<void> hide() async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    Future<void> show() async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    test('closes its port when hidden and opens it again when shown', () async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      await remote.setEnabled(true, port: 0);
      final listener = watchRemoteLifecycle(remote)!;
      addTearDown(listener.dispose);
      expect(remote.port, isNotNull);
      remote.openPairing();

      await hide();
      expect(remote.port, isNull, reason: 'closed in the background');
      expect(remote.enabled, isTrue, reason: 'still turned on');
      expect(remote.pairingCode, isNull, reason: 'no pairing in the background');

      await show();
      expect(remote.port, isNotNull, reason: 'open again in front');
    });

    test('stays closed on return when it was off', () async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      final listener = watchRemoteLifecycle(remote)!;
      addTearDown(listener.dispose);
      await hide();
      await show();
      expect(remote.port, isNull);
    });

    test('nothing watches the lifecycle on Linux', () async {
      await remote.setEnabled(true, port: 0);
      expect(watchRemoteLifecycle(remote), isNull);
      await hide();
      expect(remote.port, isNotNull);
    });
  });

  group('system Back', () {
    // Design Open Question 1: observers are asked in the order they were
    // added, so a bridge added before runApp sees Back before WidgetsApp's
    // Navigator does.
    testWidgets('the bridge added first sees Back before the Navigator', (tester) async {
      final seen = <String>[];
      var handled = true;
      final bridge = AndroidBackBridge(dispatch: (key, physical) {
        seen.add('bridge ${key.keyLabel}');
        return handled;
      });
      tester.binding.addObserver(bridge);
      addTearDown(() => tester.binding.removeObserver(bridge));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Text('home')));
      navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Text('sub-screen')));
      await tester.pumpAndSettle();

      // A screen took the Back key: the Navigator never pops.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(seen, ['bridge Go Back']);
      expect(find.text('sub-screen'), findsOneWidget);

      // No screen took it: the Navigator pops as usual.
      handled = false;
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('sub-screen'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('Back reaches the focused screen as a Back key press', (tester) async {
      final bridge = AndroidBackBridge();
      tester.binding.addObserver(bridge);
      addTearDown(() => tester.binding.removeObserver(bridge));
      final keys = <LogicalKeyboardKey>[];
      await tester.pumpWidget(MaterialApp(
        home: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            keys.add(event.logicalKey);
            return KeyEventResult.handled;
          },
          child: const SizedBox.expand(),
        ),
      ));
      await tester.pump();
      expect(await tester.binding.handlePopRoute(), isTrue);
      expect(keys, [LogicalKeyboardKey.goBack]);
    });

    test('on Android Flutter always takes Back, even at the root', () async {
      final calls = <Object?>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') calls.add(call.arguments);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      // flutter test reports Android as the target platform, so the call goes through.
      expect(AndroidBackBridge.alwaysHandleBack(const NavigationNotification(canHandlePop: false)), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true]);
    });
  });

  group('TV canvas', () {
    Future<MediaQueryData> layOut(WidgetTester tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      tester.view.padding = const FakeViewPadding(left: 20);
      tester.view.viewPadding = const FakeViewPadding(left: 20);
      addTearDown(tester.view.reset);
      late MediaQueryData seen;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TvCanvas(child: child!),
        home: Builder(builder: (context) {
          seen = MediaQuery.of(context);
          return const SizedBox.expand(key: Key('screen'));
        }),
      ));
      return seen;
    }

    testWidgets('on Android, the keyboard and insets are in canvas units', (tester) async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      final media = await layOut(tester);
      // The canvas is drawn at half size, so 200 screen pixels of keyboard
      // are 400 canvas units.
      expect(media.size, TvCanvas.size);
      expect(tester.getSize(find.byKey(const Key('screen'))), const Size(1920, 1080 - 400));
      expect(media.viewInsets.bottom, 0, reason: 'already taken by the canvas');
      expect(media.padding.left, 40);
      expect(media.viewPadding.left, 40);
    });

    testWidgets('on Linux, MediaQuery passes through as before', (tester) async {
      final media = await layOut(tester);
      expect(media.size, TvCanvas.size);
      expect(tester.getSize(find.byKey(const Key('screen'))), TvCanvas.size);
      expect(media.viewInsets.bottom, 200);
      expect(media.padding.left, 20);
    });
  });

  group('pictures for icons on a TV', () {
    const images = [
      DeviceImage(uri: 'content://media/1', name: 'logo.png', folder: 'Download'),
      DeviceImage(uri: 'content://media/2', name: 'badge.jpg', folder: 'USB'),
    ];

    /// Opens the picker over a home screen; returns what it popped (or
    /// null), once it has.
    Future<DeviceImage? Function()> open(WidgetTester tester, Future<List<DeviceImage>> Function() load) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      DeviceImage? picked;
      await tester.pumpWidget(MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await Navigator.of(context).push<DeviceImage>(MaterialPageRoute(
                builder: (_) => DeviceImagePickerScreen(load: load, thumbnail: (_) async => null))),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => picked;
    }

    testWidgets('the first picture has focus; the D-pad and OK pick another', (tester) async {
      final picked = await open(tester, () async => images);
      expect(find.text('logo.png'), findsOneWidget);
      expect(find.text('USB'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'first picture');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(DeviceImagePickerScreen), findsNothing);
      expect(picked()?.name, 'badge.jpg');
    });

    testWidgets('an air mouse focuses a picture by pointing and picks it with a click', (tester) async {
      // As main() sets it up on a TV.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final picked = await open(tester, () async => images);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('badge.jpg')));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('first picture'));
      await mouse.down(tester.getCenter(find.text('badge.jpg')));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(picked()?.name, 'badge.jpg');
    });

    testWidgets('no permission says where to allow it', (tester) async {
      await open(tester, () async => throw DeviceImagesDenied());
      expect(find.textContaining('isn\'t allowed to see the pictures'), findsOneWidget);
    });

    testWidgets('no pictures says how to add some', (tester) async {
      await open(tester, () async => const []);
      expect(find.textContaining('No pictures on this device yet'), findsOneWidget);
    });

    test('a picture from the device is stored like a file from the file dialog', () async {
      final dir = await Directory.systemTemp.createTemp('icons');
      addTearDown(() => dir.delete(recursive: true));
      final store = CustomIconStore(dir);
      final png = img.encodePng(img.Image(width: 900, height: 300));
      final file = File('${dir.path}/source.png')..writeAsBytesSync(png);
      final fromFile = await store.import(file);
      final fromDevice = await store.importBytes(png, 'logo.png');
      expect(fromDevice, fromFile);
      final stored = img.decodePng(store.fileFor(fromDevice).readAsBytesSync())!;
      expect((stored.width, stored.height), (512, 171));
    });
  });
}
