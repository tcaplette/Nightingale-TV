// crash-visibility: the session record, previous-session reports, the
// start-up trail and its watchdog, memory crumbs, the library path, and the
// live-check hooks.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/reporting/error_reports.dart';
import 'package:nightingale_tv/reporting/memory_watch.dart';
import 'package:nightingale_tv/reporting/report_switch.dart';
import 'package:nightingale_tv/reporting/session_record.dart';
import 'package:nightingale_tv/reporting/startup_trail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _Sent implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }

  Future<List<Map<String, Object?>>> events() async => [
        for (final e in envelopes)
          for (final item in e.items)
            if (item.header.type == 'event') jsonDecode(utf8.decode(await item.dataFactory())) as Map<String, Object?>,
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('live-check hooks', () {
    test('hook names are parsed; unknown or unset is none', () {
      expect(ForcedCheck.parse('native'), ForcedCheck.native);
      expect(ForcedCheck.parse('exit'), ForcedCheck.exit);
      expect(ForcedCheck.parse('slowstart'), ForcedCheck.slowstart);
      expect(ForcedCheck.parse('dart'), ForcedCheck.dart);
      expect(ForcedCheck.parse(null), isNull);
      expect(ForcedCheck.parse(''), isNull);
      expect(ForcedCheck.parse('segv'), isNull);
    });

    test('nothing is armed unless a hook is set', () {
      fakeAsync((async) {
        ForcedCheck? armed = ForcedCheck.dart;
        ErrorReports.forceErrorForChecks(read: () => null).then((c) => armed = c);
        async.flushMicrotasks();
        expect(armed, isNull);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('native arms one fault, 5 s after start-up (not fired here)', () {
      fakeAsync((async) {
        ForcedCheck? armed;
        ErrorReports.forceErrorForChecks(read: () => 'native').then((c) => armed = c);
        async.flushMicrotasks();
        expect(armed, ForcedCheck.native);
        expect(async.pendingTimers, hasLength(1));
        expect(async.pendingTimers.single.duration, const Duration(seconds: 5));
      });
    });

    test('slowstart holds start-up only when set', () async {
      await ErrorReports.debugReset();
      final watch = Stopwatch()..start();
      await ErrorReports.holdForChecks(hold: const Duration(seconds: 5));
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    });
  });

  group('session record', () {
    late Directory dir;
    late AppStorage storage;
    late _Sent sent;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('crash_visibility');
      storage = await AppStorage.at(dir);
      sent = _Sent();
      await ErrorReports.debugReset();
      ReportSwitch.instance.reset();
      ErrorReports.debugDsn = 'https://public@reports.invalid/2';
      ErrorReports.debugTransport = sent;
      ErrorReports.debugInstallHandlers = false;
    });
    tearDown(() async {
      await pumpEventQueue();
      await storage.flush();
      await ErrorReports.debugReset();
      ReportSwitch.instance.reset();
      await dir.delete(recursive: true);
    });

    SessionRecord previous(
        {bool foreground = true,
        bool cleanExit = false,
        bool recording = true,
        List<String> steps = const ['storage open', 'ready']}) {
      final started = DateTime.now().subtract(const Duration(minutes: 10));
      return SessionRecord(
        id: 'aaaabbbbcccc',
        version: '1.2.6+5008',
        platform: 'android-tv',
        started: started,
        recording: recording,
        foreground: foreground,
        cleanExit: cleanExit,
        stage: steps.isEmpty ? null : steps.last,
        steps: [for (final (i, s) in steps.indexed) StartupStep(s, started.add(Duration(seconds: i)))],
        trail: [
          TrailEntry(at: started.add(const Duration(minutes: 1)), category: 'tune', message: 'Tuned 3'),
          TrailEntry(at: started.add(const Duration(minutes: 2)), category: 'memory', message: 'Memory trim: RUNNING_LOW'),
        ],
        memory: MemorySample(
            at: started, available: 300 << 20, total: 2000 << 20, threshold: 200 << 20, lowMemory: false, rss: 400 << 20),
        reports: [RecentReport(kind: 'test', at: started, id: '11112222333344445555666677778888')],
      );
    }

    Future<void> launchAfter(SessionRecord? before) async {
      if (before != null) await storage.writeJson(SessionRecord.file, before.toJson());
      await storage.flush();
      await ErrorReports.startApp(storage);
      await pumpEventQueue();
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    Future<List<String?>> messages() async => [
          for (final e in await sent.events())
            ((e['message'] as Map?)?['formatted'] ?? (e['message'] as Map?)?['message']) as String?,
        ];

    test('in front with no clean exit: "Unexpected exit" with the trail and memory', () async {
      await launchAfter(previous());
      final events = await sent.events();
      expect(await messages(), ['Unexpected exit']);
      final e = events.single;
      expect(e['level'], 'fatal');
      final tags = (e['tags']! as Map).cast<String, Object?>();
      expect(tags['area'], 'exit');
      expect(tags['previous_session'], 'aaaabbbbcccc');
      expect(tags['session'], ErrorReports.session!.id, reason: 'every event carries this launch\'s session');
      expect(tags['stage'], 'ready');
      final crumbs = [for (final b in e['breadcrumbs']! as List) (b as Map)['message']];
      expect(crumbs, ['Tuned 3', 'Memory trim: RUNNING_LOW'], reason: 'the previous trail, not this launch\'s');
      final contexts = (e['contexts']! as Map).cast<String, Object?>();
      expect((contexts['memory']! as Map)['available_mb'], 300);
      // The new record keeps the recent reports and adds this one.
      expect([for (final r in ErrorReports.session!.reports) r.kind], ['test', 'exit']);
    });

    test('in the background, or a clean exit: nothing', () async {
      await launchAfter(previous(foreground: false));
      expect(await messages(), isEmpty);
      await ErrorReports.debugReset();
      ErrorReports.debugDsn = 'https://public@reports.invalid/2';
      ErrorReports.debugTransport = sent;
      await launchAfter(previous(cleanExit: true));
      expect(await messages(), isEmpty);
    });

    test('Android\'s clean-exit mark for that session counts as a clean exit', () async {
      final before = previous();
      await File('${dir.path}/${SessionRecord.cleanExitFile}').create(recursive: true);
      await File('${dir.path}/${SessionRecord.cleanExitFile}').writeAsString(before.id);
      await launchAfter(before);
      expect(await messages(), isEmpty);
      expect(File('${dir.path}/${SessionRecord.cleanExitFile}').existsSync(), isFalse, reason: 'used once');
    });

    test('a session recorded with reporting off is never reported', () async {
      await launchAfter(previous(recording: false));
      expect(await messages(), isEmpty);
    });

    test('crumbs arriving while the SDK starts don\'t break the replay of the early trail', () async {
      await ErrorReports.openApp(storage);
      for (var i = 0; i < 5; i++) {
        ErrorReports.breadcrumb('startup', 'step $i');
      }
      // Crumbs from other work between the replay's awaits: microtask
      // chains, restarted on every event-loop turn.
      var n = 0;
      void chain(int left) {
        if (left == 0) return;
        ErrorReports.breadcrumb('memory', 'crumb ${n++}');
        scheduleMicrotask(() => chain(left - 1));
      }

      chain(50);
      final more = Timer.periodic(Duration.zero, (_) => chain(50));
      await ErrorReports.startReporting();
      more.cancel();
      expect(ErrorReports.running, isTrue);
      // Every crumb reached the SDK once: early ones replayed, later ones
      // sent as they came.
      late List<String?> sdk;
      await Sentry.configureScope((scope) => sdk = [for (final b in scope.breadcrumbs) b.message]);
      expect(sdk.toSet().length, sdk.length, reason: 'no crumb twice');
    });

    test('a previous launch\'s trail survives the SDK putting this launch\'s on the event', () async {
      await ErrorReports.openApp(storage);
      final event = SentryEvent(message: SentryMessage('Unexpected exit'), tags: {'area': 'exit'});
      ErrorReports.keepTrail(event.eventId, [Breadcrumb(category: 'tune', message: 'Tuned 3')]);
      // What Android's LoadContextsIntegration does to every event.
      event.breadcrumbs = [Breadcrumb(category: 'startup', message: 'ready')];
      final out = ErrorReports.filter(event, Hint());
      expect([for (final b in out!.breadcrumbs!) b.message], ['Tuned 3']);
    });

    test('exits the user asked for are not reported', () {
      final p = previous();
      expect(ErrorReports.wasUnexpectedExit(p), isTrue);
      expect(ErrorReports.wasUnexpectedExit(p, exitReason: 'low_memory'), isTrue);
      expect(ErrorReports.wasUnexpectedExit(p, exitReason: 'signaled'), isTrue);
      expect(ErrorReports.wasUnexpectedExit(p, exitReason: 'user_requested'), isFalse);
      expect(ErrorReports.wasUnexpectedExit(p, exitReason: 'user_stopped'), isFalse);
    });

    test('the trail keeps the last 40, in order', () {
      final r = SessionRecord.start(version: 'v', platform: 'linux', recording: true);
      for (var i = 0; i < 55; i++) {
        r.addCrumb(TrailEntry(at: DateTime(2026, 1, 1, 0, 0, i), category: 'tune', message: 'Tuned $i'));
      }
      expect(r.trail, hasLength(40));
      expect([for (final t in r.trail) t.message], [for (var i = 15; i < 55; i++) 'Tuned $i']);
      r.dispose();
    });

    test('the stored trail is scrubbed: no address, token or name reaches the file', () async {
      ErrorReports.setNames(['Grandma Jo']);
      await ErrorReports.startApp(storage);
      ErrorReports.breadcrumb('server', 'Grandma Jo signed in to http://192.168.1.20:8096/web?api_key=0123456789abcdef0123',
          data: {'url': 'https://jelly.example.org/Items', 'token': 'X-Emby-Token=a1b2c3d4e5f6a7b8c9d0e1f2'});
      await ErrorReports.session!.saveNow();
      await storage.flush();
      final text = await File('${dir.path}/${SessionRecord.file}').readAsString();
      expect(text, contains('signed in to <server>'));
      for (final secret in ['Grandma', '192.168', 'jelly.example', '0123456789abcdef', 'a1b2c3d4e5f6']) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
    });

    test('the previous launch never reached a usable screen: "Slow start" from this one, once', () async {
      await launchAfter(previous(foreground: false, steps: const ['storage open', 'household started', 'settings read']));
      expect(await messages(), ['Slow start']);
      final e = (await sent.events()).single;
      final tags = (e['tags']! as Map).cast<String, Object?>();
      expect(tags['area'], 'startup');
      expect(tags['slow_start'], 'previousLaunch');
      expect(tags['stage'], 'settings read');
      final steps = ((e['contexts']! as Map)['startup']! as Map)['steps'] as List;
      expect(steps, ['0.0 s storage open', '1.0 s household started', '2.0 s settings read']);

      // This launch reaches the TV: the next launch reports nothing about it.
      final trail = StartupTrail(ErrorReports.session!, launchedAt: DateTime.now(), onSlowStart: (_) {});
      trail
        ..add('storage open')
        ..add('ready');
      trail.dispose();
      await ErrorReports.markCleanExit();
      await storage.flush();
      sent.envelopes.clear();
      await ErrorReports.debugReset();
      ErrorReports.debugDsn = 'https://public@reports.invalid/2';
      ErrorReports.debugTransport = sent;
      await launchAfter(null);
      expect(await messages(), isEmpty);
    });

    test('a launch that sent its own "Slow start" isn\'t reported again', () async {
      final p = previous(foreground: false, steps: const ['storage open'])..slowStartSent = true;
      await launchAfter(p);
      expect(await messages(), isEmpty);
    });
  });

  group('start-up watchdog', () {
    SessionRecord record(DateTime start, DateTime Function() now) =>
        SessionRecord(id: 'x', version: 'v', platform: 'android-tv', started: start, now: now);

    test('fires once at 60 s without a usable screen', () {
      fakeAsync((async) {
        final start = async.getClock(DateTime(2026, 11, 18)).now();
        final r = record(start, () => async.getClock(DateTime(2026, 11, 18)).now());
        final fired = <SlowStartReason>[];
        final trail = StartupTrail(r, launchedAt: start, onSlowStart: fired.add)..start();
        trail.add('storage open');
        async.elapse(const Duration(seconds: 59));
        expect(fired, isEmpty);
        async.elapse(const Duration(seconds: 2));
        expect(fired, [SlowStartReason.noScreen]);
        trail.add('syncing');
        async.elapse(const Duration(minutes: 5));
        expect(fired, hasLength(1), reason: 'once per launch');
        trail.dispose();
      });
    });

    test('fires at 3 minutes of a launch library download', () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime(2026, 11, 18));
        final start = clock.now();
        final r = record(start, clock.now);
        final fired = <SlowStartReason>[];
        final trail = StartupTrail(r, launchedAt: start, onSlowStart: fired.add)..start();
        trail
          ..add('storage open')
          ..add('library read', detail: 'unreadable (FormatException)')
          ..add('syncing');
        expect(r.library, 'unreadable (FormatException)');
        async.elapse(const Duration(minutes: 2, seconds: 59));
        expect(fired, isEmpty, reason: 'the download screen is usable');
        async.elapse(const Duration(seconds: 2));
        expect(fired, [SlowStartReason.libraryDownload]);
        trail.dispose();
      });
    });

    test('a step\'s immediate save carries its crumb', () async {
      final dir = await Directory.systemTemp.createTemp('step_save');
      addTearDown(() => dir.delete(recursive: true));
      final storage = await AppStorage.at(dir);
      final r = SessionRecord(id: 'x', version: 'v', platform: 'android-tv', started: DateTime.now());
      await r.attach(storage);
      final trail = StartupTrail(r,
          launchedAt: r.started,
          onSlowStart: (_) {},
          onCrumb: (m, _) => r.addCrumb(TrailEntry(at: DateTime.now(), category: 'startup', message: m)));
      trail.add('first picture');
      await storage.flush();
      final saved = SessionRecord.fromJson(jsonDecode(await File('${dir.path}/${SessionRecord.file}').readAsString()));
      expect([for (final t in saved!.trail) t.message], ['first picture'], reason: 'no wait for the 3 s throttle');
      r.dispose();
      trail.dispose();
    });

    test('a quick start sends nothing', () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime(2026, 11, 18));
        final start = clock.now();
        final r = record(start, clock.now);
        final fired = <SlowStartReason>[];
        final trail = StartupTrail(r, launchedAt: start, onSlowStart: fired.add)..start();
        trail.add('storage open');
        async.elapse(const Duration(seconds: 2));
        trail.add('syncing');
        async.elapse(const Duration(seconds: 40));
        trail.add('ready');
        expect(trail.closed, isTrue);
        trail.add('settings read');
        expect(r.steps.last.name, 'ready', reason: 'no steps after the launch is done');
        trail.add('first picture');
        expect(r.stage, 'first picture');
        async.elapse(const Duration(minutes: 10));
        expect(fired, isEmpty);
        trail.dispose();
      });
    });
  });

  group('library path', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('library_path');
      IndexBuilder.useIsolate = false;
    });
    tearDown(() async {
      IndexBuilder.useIsolate = true;
      await dir.delete(recursive: true);
    });

    test('missing, corrupt, and a file LibraryIndex.fromJson rejects', () async {
      final path = '${dir.path}/library.json';
      expect((await IndexBuilder.savedRead(path)).path, 'missing');
      await File(path).writeAsString('{"fetchedAt": "2026-11-18T00:00:00Z", "series": [');
      final corrupt = await IndexBuilder.savedRead(path);
      expect(corrupt.path, 'unreadable (FormatException)');
      expect(corrupt.index, isNull, reason: 'treated as missing, as before');
      await File(path).writeAsString('{"series": 5}');
      final rejected = await IndexBuilder.savedRead(path);
      expect(rejected.path, startsWith('unreadable ('));
      expect(rejected.path, isNot(contains('series')), reason: 'the type, never the content');
      expect(() => rejected.index, throwsA(anything), reason: 'still thrown, as before');
    });
  });

  group('memory crumbs', () {
    final t = DateTime(2026, 11, 18);
    MemorySample s({required int availMb, bool low = false}) =>
        MemorySample(at: t, available: availMb << 20, total: 2000 << 20, threshold: 200 << 20, lowMemory: low, rss: 300 << 20);

    test('steady memory: no crumb', () {
      expect(MemoryWatch.crumbFor(null, s(availMb: 900)), isNull);
      expect(MemoryWatch.crumbFor(s(availMb: 900), s(availMb: 850)), isNull);
    });

    test('one crumb when lowMemory flips, each way', () {
      expect(MemoryWatch.crumbFor(s(availMb: 900), s(availMb: 180, low: true)), startsWith('Device low on memory'));
      expect(MemoryWatch.crumbFor(s(availMb: 180, low: true), s(availMb: 170, low: true)), isNull);
      expect(MemoryWatch.crumbFor(s(availMb: 180, low: true), s(availMb: 900)), startsWith('Device memory recovered'));
    });

    test('one crumb when free memory falls under twice the threshold', () {
      expect(MemoryWatch.crumbFor(s(availMb: 900), s(availMb: 390)), startsWith('Device memory near low'));
      expect(MemoryWatch.crumbFor(s(availMb: 390), s(availMb: 350)), isNull, reason: 'not again while under');
    });

    test('Linux: /proc/meminfo', () {
      const meminfo = 'MemTotal:       16000000 kB\nMemFree:          500000 kB\nMemAvailable:    4000000 kB\n';
      final sample = MemoryWatch.linuxSample(meminfo, rss: 1 << 20, at: t);
      expect(sample.total, 16000000 * 1024);
      expect(sample.available, 4000000 * 1024);
      expect(sample.threshold, 16000000 * 1024 ~/ 20);
      expect(sample.lowMemory, isFalse);
    });

    test('a sample every 30 s while in front only', () {
      fakeAsync((async) {
        var samples = 0;
        final crumbs = <String>[];
        final watch = MemoryWatch(
            onSample: (_) => samples++,
            onCrumb: (m, _) => crumbs.add(m),
            sample: () async => s(availMb: 900));
        watch.start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 61));
        expect(samples, 3);
        watch.stop();
        async.elapse(const Duration(minutes: 2));
        expect(samples, 3);
        expect(crumbs, isEmpty);
      });
    });
  });

  test('foreground follows the lifecycle; Android counts only resumed', () async {
    await ErrorReports.debugReset();
    final r = ErrorReports.debugSession = SessionRecord.start(version: 'v', platform: 'linux', recording: true);
    ErrorReports.lifecycleChanged(AppLifecycleState.inactive);
    expect(r.foreground, isTrue, reason: 'a PC window without focus is still in front');
    ErrorReports.lifecycleChanged(AppLifecycleState.hidden);
    expect(r.foreground, isFalse);
    ErrorReports.lifecycleChanged(AppLifecycleState.resumed);
    expect(r.foreground, isTrue);
    expect([for (final t in r.trail) t.message], ['inactive', 'hidden', 'resumed'], reason: 'kept even before the SDK is up');
    await ErrorReports.debugReset();
  });
}
