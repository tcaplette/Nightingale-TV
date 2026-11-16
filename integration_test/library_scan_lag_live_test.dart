// The main thread keeps up during a library scan (library-scan-anr 4.2,
// 4.3): a 50 ms timer on the main isolate must never fire 100 ms late while
// the scan runs (LagWatch, the same measurement diagnostics builds log as
// `SCAN lag max`).
//
// 1. The test-data.md server: sign in, tune a channel, rescan while it plays.
//      flutter test integration_test/library_scan_lag_live_test.dart -d <device> \
//        --dart-define=SCAN_URL=… --dart-define=SCAN_USER=… --dart-define=SCAN_PW=…
//    (on Linux, SCAN_URL, SCAN_USER and SCAN_PW can be environment variables
//    instead). Skipped without them.
// 2. A generated library of 20,000 series and 200,000 episodes on the fake
//    Jellyfin in this process: sign in, tune, rescan. Always runs. Its
//    videos don't stream, so the channel shows "No signal" meanwhile.
//
// On a device, run a prebuilt profile build, so the lag is a release
// build's and no build runs beside the emulator:
//   flutter build apk --profile --flavor free --target-platform android-x64 \
//     -t integration_test/library_scan_lag_live_test.dart --dart-define=SCAN_URL=… …
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/library_scan_lag_live_test.dart \
//     --use-application-binary=build/app/outputs/flutter-apk/app-free-profile.apk -d emulator-5554
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/playback_diagnostics.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

import '../test/fixtures.dart';
import 'fake_jellyfin.dart';

String _setting(String name, String defined) => defined.isNotEmpty ? defined : Platform.environment[name] ?? '';
final _url = _setting('SCAN_URL', const String.fromEnvironment('SCAN_URL'));
final _user = _setting('SCAN_USER', const String.fromEnvironment('SCAN_USER'));
final _pw = _setting('SCAN_PW', const String.fromEnvironment('SCAN_PW'));

/// The most a tick may be late during a scan.
const _limit = Duration(milliseconds: 100);

// ignore: avoid_print
void _say(String s) => print('${DateTime.now().toIso8601String()} SCANLAG $s');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  PlaybackDiagnostics.debugWatchLag = true;

  /// Signs in to [url], lets the TV screen tune its first channel (and,
  /// with [mustPlay], waits until it plays), rescans meanwhile, and returns
  /// the scans' lag: (sign-in scan, rescan).
  Future<(Duration, Duration, AppState)> scanWhilePlaying(WidgetTester tester, Directory dir,
      {required String url, required String user, required String password, required bool mustPlay}) async {
    if (!Platform.isAndroid) MediaKit.ensureInitialized();
    final household = Household(await AppStorage.at(dir), runAnalysis: false);
    late final AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    final signedIn = DateTime.now();
    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      final client = app.clientFor(ServerKind.jellyfin, url) as JellyfinClient;
      final info = await client.publicInfo();
      final session = await client.authenticateByName(user, password, serverName: info.name);
      await app.completeSignIn(session, client);
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    final first = LagWatch.last!;
    _say('sign-in scan: lag max ${first.max.inMilliseconds} ms (at ${first.at.inMilliseconds} ms) over ${first.length.inMilliseconds} ms '
        '(${first.ticks} ticks); sign-in to ready ${DateTime.now().difference(signedIn).inSeconds} s; '
        '${app.library.series.length} shows, ${app.library.episodes.length} episodes');

    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 1));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    // The TV screen tunes at launch; tuning again would only cut that short.
    // A channel whose stream fails gives way to the next, up to 8.
    final failures = <String>[];
    for (var attempt = 0; attempt < 8; attempt++) {
      final tuneBy = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(tuneBy) && tuner.status != TunerStatus.playing && tuner.status != TunerStatus.error) {
        await wait(const Duration(milliseconds: 250));
      }
      _say('tuned ${tuner.channel?.name}: ${tuner.status}${tuner.error != null ? ' (${tuner.error})' : ''}');
      if (tuner.status == TunerStatus.playing || !mustPlay) break;
      failures.add('${tuner.channel?.name}: ${tuner.error}');
      final next = app.channels[(app.channels.indexOf(tuner.channel!) + 1) % app.channels.length];
      await tester.runAsync(() => tuner.tune(next));
    }
    if (mustPlay) expect(tuner.status, TunerStatus.playing, reason: 'no channel played: ${failures.join('; ')}');

    // The screen alone, for comparison: the same 50 ms timer, no scan.
    late final LagWatch idle;
    await tester.runAsync(() async => idle = PlaybackDiagnostics.watchLag()!);
    await wait(const Duration(seconds: 5));
    idle.stop('IDLE');
    final baseline = LagWatch.last!;
    _say('TV screen without a scan: lag max ${baseline.max.inMilliseconds} ms (at ${baseline.at.inMilliseconds} ms) '
        'over ${baseline.length.inMilliseconds} ms');

    // The rescan, with frames drawn all along as the TV screen would.
    LagWatch.last = null;
    late final Future<void> refresh;
    await tester.runAsync(() async => refresh = app.refreshLibrary(background: true));
    var done = false;
    refresh.whenComplete(() => done = true).ignore();
    final until = DateTime.now().add(const Duration(minutes: 10));
    while (!done && DateTime.now().isBefore(until)) {
      await wait(const Duration(milliseconds: 200));
    }
    expect(done, isTrue, reason: 'the rescan took over 10 minutes');
    expect(app.syncError, isNull);
    final second = LagWatch.last!;
    _say('rescan while playing: SCAN lag max ${second.max.inMilliseconds} ms (at ${second.at.inMilliseconds} ms) '
        'over ${second.length.inMilliseconds} ms '
        '(${second.ticks} ticks), peak rss ${ProcessInfo.maxRss ~/ (1024 * 1024)} MB');

    await tester.runAsync(() async {
      await tuner.stop();
      await app.storage.flush();
    });
    return (first.max, second.max, app);
  }

  testWidgets('the test server: a rescan while a channel plays keeps the main thread under 100 ms late',
      (tester) async {
    if (_url.isEmpty || _user.isEmpty || _pw.isEmpty) {
      markTestSkipped('Set SCAN_URL, SCAN_USER and SCAN_PW to run against the test server.');
      return;
    }
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_scan_lag');
    final (first, rescan, app) = await scanWhilePlaying(tester, dir, url: _url, user: _user, password: _pw, mustPlay: true);
    expect(app.library.series, isNotEmpty);
    expect(rescan, lessThan(_limit), reason: 'SCAN lag max ${rescan.inMilliseconds} ms');
    expect(first, lessThan(_limit), reason: 'sign-in scan lag max ${first.inMilliseconds} ms');
    await tester.runAsync(() => app.client?.logout() ?? Future<void>.value());
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('20,000 series with 200,000 episodes: the scan keeps the main thread under 100 ms late',
      (tester) async {
    const shows = 20000, perShow = 10;
    final items = fakeItems(shows: {for (var i = 1; i <= shows; i++) 'Generated Show $i': perShow});
    final fake = (await tester.runAsync(() => FakeJellyfin.start(items)))!;
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_scan_lag');
    final (first, rescan, app) =
        await scanWhilePlaying(tester, dir, url: fake.url, user: 'tester', password: FakeJellyfin.password, mustPlay: false);
    expect(app.library.series, hasLength(shows));
    expect(app.library.episodes, hasLength(shows * perShow));
    expect(rescan, lessThan(_limit), reason: 'SCAN lag max ${rescan.inMilliseconds} ms');
    expect(first, lessThan(_limit), reason: 'sign-in scan lag max ${first.inMilliseconds} ms');
    await tester.runAsync(() async {
      await fake.close();
      await dir.delete(recursive: true);
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}
