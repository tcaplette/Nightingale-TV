import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../app_version.dart';
import '../data/app_storage.dart';
import '../platform/install_info.dart';
import '../platform/platform_info.dart';
import 'report_policy.dart';
import 'report_scrubber.dart';
import 'report_switch.dart';

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

  /// Tests leave Flutter's error handlers alone.
  @visibleForTesting
  static bool debugInstallHandlers = true;

  /// Takes the personal data out of every event and breadcrumb.
  static final scrubber = ReportScrubber();

  static ReportLimiter limiter = ReportLimiter();

  static bool _serverMode = false;
  static bool _running = false;
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

  /// Starts reporting in the app, if this build has a DSN and the device's
  /// switch is on. Not awaited before the first frame.
  static Future<void> startApp(AppStorage storage) async {
    _serverMode = false;
    await ReportSwitch.instance.load(storage);
    scrubber.setFolders([Platform.environment['HOME'], storage.root.path]);
    if (!available || !ReportSwitch.instance.on) return;
    await _start();
  }

  /// Server mode: on unless `NTV_ERROR_REPORTS=0`; [log] says once when it's
  /// off.
  static Future<void> startServer(Map<String, String> env, {required void Function(String) log, String? dataFolder}) async {
    _serverMode = true;
    scrubber.setFolders([env['HOME'], dataFolder]);
    if (!available) {
      log('Error reporting is off: this build has no reporting address.');
      return;
    }
    if (env['NTV_ERROR_REPORTS'] == '0') {
      log('Error reporting is off (NTV_ERROR_REPORTS=0).');
      return;
    }
    await _start();
    log('Error reports are sent to the Nightingale TV developer; set NTV_ERROR_REPORTS=0 to turn them off.');
  }

  /// The device's switch (the Error reports screen): off closes the SDK at
  /// once and discards reports still queued; on starts it again.
  static Future<void> setOn(bool on) async {
    // Reporting stops (or starts) at once; the switch is saved meanwhile.
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
    await Sentry.configureScope((scope) async {
      await scope.setTag('form_factor', formFactor);
      await scope.setTag('renderer', PlatformInfo.renderer ?? 'default');
      await scope.setTag('official_build', await _officialBuild());
    });
  }

  static Future<void> _stop() async {
    if (!_running) return;
    _running = false;
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
    // Java/Kotlin crashes and freezes stay on; native (NDK) crash handling
    // isn't in the APK at all (android/app/build.gradle.kts).
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
  static const categories = {'navigation', 'tune', 'server', 'error'};

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
    final tags = event.tags ??= {};
    tags.putIfAbsent('area', () => 'uncaught');
    final why = limiter.admit(ReportPolicy.fingerprint(event), test: tags['area'] == 'test');
    if (why != null) {
      _leftOut('${thrown?.runtimeType ?? 'message'} ($why)', tags['area']);
      return null;
    }
    scrubber.scrubEvent(event);
    if (!_serverMode) unawaited(ReportSwitch.instance.sent(event.eventId.toString()));
    return event;
  }

  static void _leftOut(String what, String? area) =>
      breadcrumb('error', 'Not reported: $what', data: {'area': area ?? 'uncaught'});

  /// An unexpected failure the app caught and showed the user (D5), tagged
  /// with its [area] (`playback`, `sign-in`, `library`, `backup`).
  /// [expected] failures, and those [ReportPolicy] knows are expected,
  /// become breadcrumbs.
  static void capture(Object error, StackTrace? stack, {required String area, bool expected = false}) {
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

  /// A trail entry in one of the app's [categories].
  static void breadcrumb(String category, String message, {Map<String, Object?>? data}) {
    if (!_running) return;
    unawaited(Sentry.addBreadcrumb(Breadcrumb(category: category, message: message, data: data)));
  }

  /// For the live checks of error reporting only: `NTV_FORCE_ERROR` (Linux,
  /// server mode) or the `debug.nightingale_tv.force_error` property
  /// (Android, which only adb can set). `dart` throws one uncaught error
  /// 5 s after start-up; `repeat` fails the same way as a stream open,
  /// every 20 s, for the repeat limit.
  static Future<void> forceErrorForChecks() async {
    final what = PlatformInfo.isAndroid ? await PlatformInfo.forcedError() : Platform.environment['NTV_FORCE_ERROR'];
    switch (what) {
      case 'dart':
        Timer(const Duration(seconds: 5), () => throw StateError('Forced uncaught error (error reporting check)'));
      case 'repeat':
        Timer.periodic(const Duration(seconds: 20), (_) {
          try {
            throw StateError('Forced stream failure (error reporting check)');
          } on StateError catch (e, stack) {
            capture(e, stack, area: 'playback');
          }
        });
    }
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
    _serverMode = false;
    debugDsn = null;
    debugTransport = null;
    limiter = ReportLimiter();
    scrubber
      ..setNames(const [])
      ..setFolders(const []);
  }
}
