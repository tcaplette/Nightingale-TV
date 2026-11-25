import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../app_version.dart';
import '../data/app_storage.dart';
import '../platform/install_info.dart';
import '../platform/platform_info.dart';
import '../server/live_tv.dart';
import 'memory_watch.dart';
import 'native_fault.dart';
import 'report_policy.dart';
import 'report_scrubber.dart';
import 'report_switch.dart';
import 'session_record.dart';
import 'startup_trail.dart';
import 'video_report.dart';

/// The live checks' hooks (error-reporting, crash-visibility D7), set with
/// `NTV_FORCE_ERROR` or the `debug.nightingale_tv.force_error` property.
enum ForcedCheck {
  /// One uncaught Dart error, 5 s after start-up.
  dart,

  /// The same caught failure every 20 s, for the repeat limit.
  repeat,

  /// The main isolate busy for 10 s, from 5 s after start-up.
  anr,

  /// `raise(SIGSEGV)` 5 s after start-up: a real native crash.
  native,

  /// `kill(getpid(), SIGKILL)` 5 s after start-up, in the foreground, as
  /// Android's low-memory killer does.
  exit,

  /// `household.start()` held for 90 s, so the slow-start watchdog fires.
  slowstart;

  /// The hook named [value], or null for none (or an unknown name).
  static ForcedCheck? parse(String? value) =>
      value == null ? null : values.where((c) => c.name == value.trim()).firstOrNull;
}

/// Error reports to the Nightingale TV GlitchTip project (error-reporting).
///
/// Only builds made with a DSN report ([available]); without one the SDK is
/// never started, so nothing is sent or queued. On Android the full
/// `sentry_flutter` SDK runs, which also catches Java/Kotlin crashes and
/// freezes; on Linux (app and server mode) only the Dart SDK runs.
abstract final class ErrorReports {
  /// The GlitchTip project's DSN, from `error_reporting.env` at build time.
  static const dsn = String.fromEnvironment('NTV_ERROR_DSN');

  /// Whether this build can report at all.
  static bool get available => (debugDsn ?? dsn).isNotEmpty;

  @visibleForTesting
  static String? debugDsn;

  /// Where tests send reports instead of GlitchTip.
  @visibleForTesting
  static Transport? debugTransport;

  /// Tests hear each caught failure and whether it counts as expected.
  @visibleForTesting
  static void Function(Object error, String area, bool expected)? debugOnCapture;

  /// Tests leave Flutter's error handlers alone.
  @visibleForTesting
  static bool debugInstallHandlers = true;

  /// Takes the personal data out of every event and breadcrumb.
  static final scrubber = ReportScrubber();

  static ReportLimiter limiter = ReportLimiter();

  static bool _serverMode = false;
  static bool _running = false;

  /// Crumbs go to the SDK itself once it's up and has the trail kept
  /// before it; until then only the session record keeps them.
  static bool _crumbsToSdk = false;
  static bool _handlersInstalled = false;

  /// The SDK is started and sending.
  static bool get running => _running;

  /// `android-tv`, `android-phone`, `linux` or `server`.
  static String get environment => _serverMode
      ? 'server'
      : PlatformInfo.isAndroid
          ? (PlatformInfo.isTelevision ? 'android-tv' : 'android-phone')
          : 'linux';

  static String get formFactor => _serverMode
      ? 'server'
      : PlatformInfo.isAndroid
          ? (PlatformInfo.isTelevision ? 'tv' : 'phone')
          : 'desktop';

  static String get release => 'nightingale-tv@$appVersion';

  /// Android 8 and later run the plugin's Android SDK, which also catches
  /// Java/Kotlin crashes and freezes. It needs Android 8, so Android 7 (and
  /// Linux) report Dart errors through the Dart SDK alone.
  static bool get usesAndroidSdk => PlatformInfo.isAndroid && (PlatformInfo.androidSdk ?? 0) >= 26;

  /// Opens reporting and starts it, in one (tests).
  static Future<void> startApp(AppStorage storage) async {
    await openApp(storage);
    await startReporting();
  }

  /// The app's first step after storage opens (crash-visibility D6): reads
  /// this device's switch, the live-check hook and the previous launch's
  /// session record, and starts this launch's. A few milliseconds; the SDK
  /// starts in [startReporting], which nothing waits for.
  static Future<void> openApp(AppStorage storage, {DateTime? launchedAt}) async {
    _serverMode = false;
    _hookBreadcrumbs();
    await ReportSwitch.instance.load(storage);
    scrubber.setFolders([Platform.environment['HOME'], storage.root.path]);
    _forced = await _readForced();
    await _openSession(storage, recording: available && ReportSwitch.instance.on, launchedAt: launchedAt);
  }

  /// Starts the SDK, if this build has a DSN and the device's switch is on,
  /// then sends what the previous launch left to report. Not awaited before
  /// the first frame.
  static Future<void> startReporting() async {
    if (available && ReportSwitch.instance.on) {
      await _start();
      StartupTrail.step('reporting started');
      await _reportPrevious();
    }
    _previous = null;
  }

  /// Server mode: on unless `NTV_ERROR_REPORTS=0`; [log] says once when it's
  /// off. With [storage], it keeps a session record, so a server that dies
  /// without being stopped is reported when it starts again.
  static Future<void> startServer(Map<String, String> env,
      {required void Function(String) log, String? dataFolder, AppStorage? storage}) async {
    _serverMode = true;
    _hookBreadcrumbs();
    scrubber.setFolders([env['HOME'], dataFolder]);
    final on = available && env['NTV_ERROR_REPORTS'] != '0';
    if (storage != null) await _openSession(storage, recording: on);
    if (!available) {
      log('Error reporting is off: this build has no reporting address.');
      return;
    }
    if (env['NTV_ERROR_REPORTS'] == '0') {
      log('Error reporting is off (NTV_ERROR_REPORTS=0).');
      return;
    }
    await _start();
    await _reportPrevious();
    log('Error reports are sent to the Nightingale TV developer; set NTV_ERROR_REPORTS=0 to turn them off.');
  }

  // ---- The session record (crash-visibility D2–D5) --------------------------

  static SessionRecord? _session;
  static SessionRecord? _previous;
  static String? _forced;
  static StartupTrail? _trail;
  static MemoryWatch? _memory;
  static AppLifecycleListener? _lifecycle;

  /// This launch's record: its id tags every event, and it holds the
  /// recent reports.
  static SessionRecord? get session => _session;

  @visibleForTesting
  static set debugSession(SessionRecord? record) => _session = record;

  /// Reads the previous launch's record (and Android's clean-exit mark for
  /// it), then starts this launch's, keeping the recent reports.
  static Future<void> _openSession(AppStorage storage, {required bool recording, DateTime? launchedAt}) async {
    final previous = await SessionRecord.read(storage);
    final mark = File(storage.pathOf(SessionRecord.cleanExitFile));
    try {
      if (await mark.exists()) {
        if (previous != null && (await mark.readAsString()).trim() == previous.id) previous.cleanExit = true;
        await mark.delete();
      }
    } on FileSystemException catch (e) {
      debugPrint('Clean-exit mark unreadable: $e');
    }
    _previous = previous;
    _session?.dispose();
    final record = _session = SessionRecord.start(
        version: appVersion, platform: environment, recording: recording, started: launchedAt, previous: previous);
    // Server mode is always "in front": only a stop is a clean exit.
    unawaited(record.attach(storage));
    unawaited(PlatformInfo.setSessionId(record.id));
  }

  /// The app's watchers (crash-visibility D3–D5), from main(): start-up
  /// steps and the slow-start watchdog, foreground changes, memory.
  static void watchApp({required DateTime launchedAt}) {
    final record = _session;
    if (record == null) return;
    _trail?.dispose();
    final trail = _trail = StartupTrail.current = StartupTrail(record,
        launchedAt: launchedAt,
        onSlowStart: (reason) => unawaited(sendSlowStart(record, reason)),
        onCrumb: (message, data) => breadcrumb('startup', message, data: data));
    trail.start();
    final memory = _memory = MemoryWatch(
        onSample: record.setMemory, onCrumb: (message, data) => breadcrumb('memory', message, data: data));
    PlatformInfo.onTrimMemory =
        (level) => breadcrumb('memory', MemoryWatch.trimCrumb(level), data: {'level': level});
    _lifecycle = AppLifecycleListener(onStateChange: lifecycleChanged);
    if (record.foreground) memory.start();
  }

  /// In front: resumed; on a PC also inactive (another window has focus).
  /// Android moves an app to the background before a force-stop or a swipe
  /// from recents, so those are never "in front".
  @visibleForTesting
  static void lifecycleChanged(AppLifecycleState state) {
    final front = state == AppLifecycleState.resumed || (!PlatformInfo.isAndroid && state == AppLifecycleState.inactive);
    breadcrumb('lifecycle', state.name);
    _session?.setForeground(front);
    if (front) {
      _memory?.start();
    } else {
      _memory?.stop();
    }
  }

  /// The app is closing on purpose: the next launch reports nothing.
  static Future<void> markCleanExit() => _session?.markClean() ?? Future.value();

  /// Android says the user ended the app (force-stop, swipe away).
  static bool userEnded(String? exitReason) => exitReason == 'user_requested' || exitReason == 'user_stopped';

  /// The previous launch died in front without a clean exit.
  static bool wasUnexpectedExit(SessionRecord previous, {String? exitReason}) =>
      previous.recording && previous.foreground && !previous.cleanExit && !userEnded(exitReason);

  /// The previous launch never reached a usable screen and never said so.
  static bool wasSlowStart(SessionRecord previous) =>
      previous.recording &&
      previous.platform != 'server' &&
      !previous.slowStartSent &&
      !StartupTrail.reachedUsable(previous);

  static Future<void> _reportPrevious() async {
    final previous = _previous;
    _previous = null;
    if (previous == null || !_running) return;
    if (previous.recording && previous.foreground && !previous.cleanExit) {
      final exit = await PlatformInfo.exitReason(previous.started);
      final reason = exit?['reason'] as String?;
      if (wasUnexpectedExit(previous, exitReason: reason)) await _sendUnexpectedExit(previous, exit);
    }
    if (wasSlowStart(previous)) await sendSlowStart(previous, SlowStartReason.previousLaunch);
  }

  static Future<void> _sendUnexpectedExit(SessionRecord previous, Map<Object?, Object?>? exit) async {
    final reason = exit?['reason'] as String?;
    final contexts = Contexts();
    contexts['previous_session'] = {
      'id': previous.id,
      'version': previous.version,
      'platform': previous.platform,
      'started': previous.started.toUtc().toIso8601String(),
      'stage': previous.stage,
      'library': previous.library,
      'steps': StartupTrail.describeSteps(previous),
    };
    if (previous.memory case final m?) contexts['memory'] = m.toContext();
    if (exit != null) {
      contexts['exit_info'] = {
        'reason': reason,
        'description': exit['description'],
        'status': exit['status'],
        'pss_mb': ((exit['pss'] as num?) ?? 0) ~/ (1024 * 1024),
        'rss_mb': ((exit['rss'] as num?) ?? 0) ~/ (1024 * 1024),
      };
    }
    final event = SentryEvent(
      message: SentryMessage('Unexpected exit'),
      level: SentryLevel.fatal,
      tags: {
        'area': 'exit',
        'previous_session': previous.id,
        'previous_version': previous.version,
        'stage': previous.stage ?? 'none',
        'exit_reason': ?reason,
      },
      contexts: contexts,
    );
    keepTrail(event.eventId, [for (final t in previous.trail) t.toBreadcrumb()]);
    await Sentry.captureEvent(event, withScope: (scope) => scope.clearBreadcrumbs());
  }

  /// "Slow start" (crash-visibility D4): about this launch from the
  /// watchdog, or about [record] (the previous launch) from the next.
  static Future<void> sendSlowStart(SessionRecord record, SlowStartReason reason) async {
    if (!_running || record.slowStartSent) return;
    final previous = !identical(record, _session);
    if (!previous) {
      record.slowStartSent = true;
      unawaited(record.saveNow());
    }
    final contexts = Contexts();
    contexts['startup'] = {
      'reason': reason.text,
      'stage': record.stage,
      'library': record.library,
      'steps': StartupTrail.describeSteps(record),
      if (previous) 'session': record.id,
    };
    final event = SentryEvent(
      message: SentryMessage('Slow start'),
      level: SentryLevel.warning,
      tags: {
        'area': 'startup',
        'slow_start': reason.name,
        'stage': record.stage ?? 'none',
        'library_path': record.library ?? 'not read',
        if (previous) 'previous_session': record.id,
        if (previous) 'previous_version': record.version,
      },
      contexts: contexts,
    );
    if (previous) keepTrail(event.eventId, [for (final t in record.trail) t.toBreadcrumb()]);
    await Sentry.captureEvent(event, withScope: previous ? (scope) => scope.clearBreadcrumbs() : null);
  }

  /// The device's switch (the Error reports screen): off closes the SDK at
  /// once and discards reports still queued; on starts it again.
  static Future<void> setOn(bool on) async {
    // Reporting stops (or starts) at once; the switch is saved meanwhile.
    // Off also disarms an armed video report (video-report).
    if (!on) VideoReports.instance.disarm();
    if (on) {
      _session?.startRecording();
    } else {
      _session?.stopRecording();
    }
    final saving = ReportSwitch.instance.setOn(on);
    if (available) {
      if (on) {
        await _start();
      } else {
        await _stop();
      }
    }
    await saving;
  }

  static Future<void> _start() async {
    if (_running) return;
    _running = true;
    limiter = ReportLimiter();
    if (usesAndroidSdk) {
      await SentryFlutter.init(_configureFlutter);
    } else {
      // Linux and Android 7: the Dart SDK alone, and the error handlers it
      // doesn't install.
      _installHandlers();
      await Sentry.init(_configure);
    }
    final session = _session;
    await Sentry.configureScope((scope) async {
      await scope.setTag('form_factor', formFactor);
      await scope.setTag('renderer', PlatformInfo.renderer ?? 'default');
      await scope.setTag('official_build', await _officialBuild());
      // A native crash (sent by the next launch) carries it too, through
      // the SDK's scope sync, so it matches its "Unexpected exit".
      if (session != null) await scope.setTag('session', session.id);
    });
    // The trail kept before the SDK was up (start-up steps), then each
    // crumb as it comes: a copy, since crumbs keep arriving meanwhile, and
    // each goes to the SDK once.
    final early = [...?session?.trail];
    _crumbsToSdk = true;
    for (final t in early) {
      await Sentry.addBreadcrumb(t.toBreadcrumb());
    }
  }

  static Future<void> _stop() async {
    if (!_running) return;
    _running = false;
    _crumbsToSdk = false;
    await Sentry.close();
    // The Android SDK keeps unsent reports in the cache folder.
    if (usesAndroidSdk) {
      try {
        final queue = Directory('${(await getApplicationCacheDirectory()).path}/sentry');
        if (await queue.exists()) await queue.delete(recursive: true);
      } on Object catch (e) {
        debugPrint('Error reports: queue not cleared: $e');
      }
    }
  }

  static Future<String> _officialBuild() async {
    if (!PlatformInfo.isAndroid) return 'unsigned';
    try {
      final info = await InstallSwitching.info();
      return info == null ? 'unknown' : (info.ownBuild ? 'no' : 'yes');
    } on Object {
      return 'unknown';
    }
  }

  static void _configureFlutter(SentryFlutterOptions o) {
    _configure(o);
    // Java/Kotlin crashes and freezes stay on, and so does native crash
    // handling (sentry-android-ndk, crash-visibility D1); the scope (tags,
    // breadcrumbs) is synced to it, so a native crash carries the session.
    o
      ..enableAutoNativeBreadcrumbs = false
      ..enableUserInteractionBreadcrumbs = false
      ..enableUserInteractionTracing = false
      ..enableAutoPerformanceTracing = false
      ..enableFramesTracking = false
      ..enableAutoSessionTracking = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false;
  }

  static void _configure(SentryOptions o) {
    o
      ..dsn = debugDsn ?? dsn
      ..release = release
      ..environment = environment
      ..sendDefaultPii = false
      ..tracesSampleRate = 0
      ..enablePrintBreadcrumbs = false
      ..sendClientReports = false
      ..maxBreadcrumbs = 40
      ..beforeSend = filter
      ..beforeBreadcrumb = filterBreadcrumb;
    o.addInAppInclude('nightingale_tv');
    // Uncaught errors come through PlatformDispatcher.onError with their own
    // type; the isolate's listener would send each again as a plain String.
    for (final i in o.integrations.whereType<IsolateErrorIntegration>().toList()) {
      o.removeIntegration(i);
    }
    if (debugTransport case final transport?) o.transport = transport;
  }

  /// Breadcrumb categories the app records itself; everything else (the
  /// SDK's HTTP, console and lifecycle trail) is dropped.
  static const categories = {'navigation', 'tune', 'server', 'error', 'startup', 'memory', 'lifecycle'};

  @visibleForTesting
  static Breadcrumb? filterBreadcrumb(Breadcrumb? crumb, Hint hint) {
    if (crumb == null || !categories.contains(crumb.category)) return null;
    return scrubber.scrubBreadcrumb(crumb);
  }

  /// Every Dart event before it goes: dropped when reporting is off, when
  /// it's an expected outcome or over the repeat limits; otherwise
  /// scrubbed, and its ID kept for the Error reports screen.
  @visibleForTesting
  static SentryEvent? filter(SentryEvent event, Hint hint) {
    if (!_serverMode && !ReportSwitch.instance.on) return null;
    final thrown = event.throwable;
    if (thrown != null && ReportPolicy.isExpected(thrown)) {
      _leftOut('${thrown.runtimeType} (expected)', event.tags?['area']);
      return null;
    }
    if (_ownTrails.remove(event.eventId) case final trail?) event.breadcrumbs = trail;
    final tags = event.tags ??= {};
    tags.putIfAbsent('area', () => 'uncaught');
    // Video reports have limits of their own (video-report D10) and never
    // use up the errors' budget.
    final why = tags['area'] == 'video_report'
        ? null
        : limiter.admit(ReportPolicy.fingerprint(event), test: tags['area'] == 'test');
    if (why != null) {
      _leftOut('${thrown?.runtimeType ?? 'message'} ($why)', tags['area']);
      return null;
    }
    scrubber.scrubEvent(event);
    if (!_serverMode) {
      final id = event.eventId.toString();
      unawaited(ReportSwitch.instance.sent(id));
      _session?.addReport(RecentReport(kind: kindOf(tags['area']), at: DateTime.now(), id: id));
    }
    return event;
  }

  /// Reports about a previous launch carry that launch's trail, not this
  /// one's. On Android the SDK puts the native scope's breadcrumbs on every
  /// event (LoadContextsIntegration), so the trail is set again in [filter],
  /// which runs after it.
  static final _ownTrails = <SentryId, List<Breadcrumb>>{};

  @visibleForTesting
  static void keepTrail(SentryId event, List<Breadcrumb> trail) => _ownTrails[event] = trail;

  /// The recent reports' kind (crash-visibility D6) for an event's area.
  static String kindOf(String? area) => switch (area) {
        'test' => 'test',
        'video_report' => 'video',
        'exit' => 'exit',
        'startup' => 'slowStart',
        _ => 'error',
      };

  static void _leftOut(String what, String? area) =>
      breadcrumb('error', 'Not reported: $what', data: {'area': area ?? 'uncaught'});

  /// An unexpected failure the app caught and showed the user (D5), tagged
  /// with its [area] (`playback`, `sign-in`, `library`, `backup`).
  /// [expected] failures, and those [ReportPolicy] knows are expected,
  /// become breadcrumbs.
  static void capture(Object error, StackTrace? stack, {required String area, bool expected = false}) {
    debugOnCapture?.call(error, area, expected || ReportPolicy.isExpected(error));
    if (!_running) return;
    if (expected || ReportPolicy.isExpected(error)) {
      _leftOut('${error.runtimeType} (expected)', area);
      return;
    }
    unawaited(Sentry.captureException(error, stackTrace: stack, withScope: (scope) => scope.setTag('area', area)));
  }

  /// The Error reports screen's "Send a test report": the new report's ID,
  /// or null when nothing was sent.
  static Future<String?> sendTest() async {
    if (!_running) return null;
    final id = await Sentry.captureMessage('Test report from the Error reports screen',
        level: SentryLevel.info, withScope: (scope) => scope.setTag('area', 'test'));
    if (id == const SentryId.empty()) return null;
    return id.toString();
  }

  /// Code that can't import this file (see [liveTvBreadcrumb]) leaves its
  /// trail entries through hooks.
  static void _hookBreadcrumbs() {
    liveTvBreadcrumb = (category, message, data) => breadcrumb(category, message, data: data);
  }

  /// A trail entry in one of the app's [categories], scrubbed. It's kept in
  /// the session record as well (crash-visibility D3), so a report sent
  /// after the process died carries it; the record keeps it even before
  /// the SDK is up.
  static void breadcrumb(String category, String message, {Map<String, Object?>? data}) {
    final record = _session;
    final keep = record != null && record.recording;
    if (!_crumbsToSdk && !keep) return;
    final crumb = scrubber.scrubBreadcrumb(Breadcrumb(category: category, message: message, data: data));
    if (keep) record.addCrumb(TrailEntry.of(crumb));
    if (_crumbsToSdk) unawaited(Sentry.addBreadcrumb(crumb));
  }

  static Future<String?> _readForced() async =>
      PlatformInfo.isAndroid ? await PlatformInfo.forcedError() : Platform.environment['NTV_FORCE_ERROR'];

  /// For the live checks of error reporting only: `NTV_FORCE_ERROR` (Linux,
  /// server mode) or the `debug.nightingale_tv.force_error` property
  /// (Android, which only adb can set). See [ForcedCheck]. `anr` keeps the
  /// main isolate busy in Dart code, as GlitchTip issue 13 did, so a key
  /// pressed meanwhile makes Android report an ANR (library-scan-anr 6.3).
  /// `slowstart` is [holdForChecks]. Returns the hook armed, or null.
  static Future<ForcedCheck?> forceErrorForChecks({String? Function()? read}) async {
    final check = ForcedCheck.parse(read != null ? read() : (_forced ??= await _readForced()));
    switch (check) {
      case ForcedCheck.dart:
        Timer(const Duration(seconds: 5), () => throw StateError('Forced uncaught error (error reporting check)'));
      case ForcedCheck.anr:
        Timer(const Duration(seconds: 5), () => debugPrint('Forced busy main thread ended: ${_busyForAnrCheck(const Duration(seconds: 10))}'));
      case ForcedCheck.repeat:
        Timer.periodic(const Duration(seconds: 20), (_) {
          try {
            throw StateError('Forced stream failure (error reporting check)');
          } on StateError catch (e, stack) {
            capture(e, stack, area: 'playback');
          }
        });
      case ForcedCheck.native:
        Timer(const Duration(seconds: 5), NativeFault.segfault);
      case ForcedCheck.exit:
        // Killed only while in front, as the low-memory killer does to the
        // app being watched.
        Timer(const Duration(seconds: 5), () {
          if (_session?.foreground ?? true) return NativeFault.killSelf();
          Timer.periodic(const Duration(seconds: 1), (_) {
            if (_session?.foreground ?? true) NativeFault.killSelf();
          });
        });
      case ForcedCheck.slowstart || null:
        break;
    }
    return check;
  }

  /// The `slowstart` hook: holds start-up for [hold] (main() awaits it
  /// before `household.start()`).
  static Future<void> holdForChecks({Duration hold = const Duration(seconds: 90)}) async {
    if (ForcedCheck.parse(_forced) != ForcedCheck.slowstart) return;
    debugPrint('Start-up held for ${hold.inSeconds} s (slowstart check)');
    await Future<void>.delayed(hold);
  }

  /// Spins on the calling isolate for [length] (the `anr` check): Dart work
  /// that never yields, so its frames are the app's own code. Returns a
  /// value that depends on every step, so nothing is optimised away.
  @pragma('vm:never-inline')
  static int _busyForAnrCheck(Duration length) {
    final watch = Stopwatch()..start();
    var x = 1;
    while (watch.elapsed < length) {
      for (var i = 0; i < 100000; i++) {
        x = (x * 1103515245 + 12345) & 0x7fffffff;
      }
    }
    return x;
  }

  /// The household's names, taken out of every report (D4).
  /// Android's own crash reports get them too.
  static void setNames(Iterable<String?> names) {
    scrubber.setNames(names);
    if (PlatformInfo.isAndroid && available) unawaited(PlatformInfo.setReportNames(scrubber.names));
  }

  /// Linux: uncaught errors to GlitchTip, after (and as well as) whatever
  /// handled them before (diagnostics log, server log).
  static void _installHandlers() {
    if (_handlersInstalled || !debugInstallHandlers) return;
    _handlersInstalled = true;
    final flutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_running) {
        unawaited(Sentry.captureException(details.exception,
            stackTrace: details.stack, withScope: (scope) => scope.setTag('area', 'uncaught')));
      }
      flutterError?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final dartError = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      if (_running) {
        unawaited(Sentry.captureException(error, stackTrace: stack, withScope: (scope) => scope.setTag('area', 'uncaught')));
      }
      return dartError?.call(error, stack) ?? false;
    };
  }

  @visibleForTesting
  static Future<void> debugReset() async {
    if (_running) await Sentry.close();
    _running = false;
    _crumbsToSdk = false;
    _trail?.dispose();
    _trail = null;
    _memory?.stop();
    _memory = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    PlatformInfo.onTrimMemory = null;
    _session?.dispose();
    _session = null;
    _previous = null;
    _forced = null;
    _ownTrails.clear();
    _serverMode = false;
    debugDsn = null;
    debugTransport = null;
    limiter = ReportLimiter();
    scrubber
      ..setNames(const [])
      ..setFolders(const []);
  }
}
