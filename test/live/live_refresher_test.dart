import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/live/live_cache.dart';
import 'package:nightingale_tv/live/live_refresher.dart';
import 'package:nightingale_tv/live/live_source.dart';

void main() {
  final start = DateTime(2026, 10, 21, 8);

  /// A refresher over [sources] in fake time; [fails] says whether the
  /// next refresh of a source fails. Returns the calls made, as
  /// "minutes since start: id channels/guide".
  ({LiveRefresher refresher, List<String> calls, Map<String, LiveRefreshState> states}) setUpRefresher(
      FakeAsync async, List<LiveSource> sources,
      {Map<String, LiveRefreshState>? states, bool Function(String id)? fails, Duration? takes}) {
    final calls = <String>[];
    final s = states ?? {for (final x in sources) x.id: LiveRefreshState()};
    DateTime now() => start.add(async.elapsed);
    final r = LiveRefresher(
      sources: () => sources,
      stateOf: (x) => s[x.id]!,
      now: now,
      refresh: (x, {required channels, required guide}) async {
        calls.add('${async.elapsed.inMinutes}: ${x.id}${channels ? ' channels' : ''}${guide ? ' guide' : ''}');
        if (takes != null) await Future<void>.delayed(takes);
        final state = s[x.id]!;
        if (fails?.call(x.id) ?? false) {
          state
            ..failures += 1
            ..errorAt = now()
            ..lastError = "Couldn't reach the playlist";
        } else {
          if (channels) state.channelsAt = now();
          if (guide) state.guideAt = now();
          state.failures = 0;
        }
      },
    );
    return (refresher: r, calls: calls, states: s);
  }

  LiveSource m3u(String id) => LiveSource(id: id, kind: LiveSourceKind.m3u, name: id);
  LiveSource server(String id) => LiveSource(id: id, kind: LiveSourceKind.server, name: id);

  test('M3U: fresh at start waits; the guide every 12 hours, the playlist every 24', () {
    fakeAsync((async) {
      final t = setUpRefresher(async, [m3u('a')], states: {
        'a': LiveRefreshState(channelsAt: start.subtract(const Duration(hours: 1)), guideAt: start.subtract(const Duration(hours: 1))),
      });
      t.refresher.start();
      async.flushMicrotasks();
      expect(t.calls, isEmpty);
      async.elapse(const Duration(hours: 24));
      expect(t.calls, ['660: a guide', '1380: a channels guide']);
      t.refresher.stop();
    });
  });

  test('M3U: stale at start refreshes at once', () {
    fakeAsync((async) {
      final t = setUpRefresher(async, [m3u('a')], states: {
        'a': LiveRefreshState(channelsAt: start.subtract(const Duration(hours: 30)), guideAt: start.subtract(const Duration(hours: 2))),
      });
      t.refresher.start();
      async.flushMicrotasks();
      expect(t.calls, ['0: a channels']);
      t.refresher.stop();
    });
  });

  test('server: everything at start, the guide every 30 minutes, the channel list hourly', () {
    fakeAsync((async) {
      final t = setUpRefresher(async, [server('s')], states: {
        's': LiveRefreshState(channelsAt: start.subtract(const Duration(minutes: 5)), guideAt: start.subtract(const Duration(minutes: 5))),
      });
      t.refresher.start();
      async.elapse(const Duration(minutes: 61));
      expect(t.calls, ['0: s channels guide', '30: s guide', '60: s channels guide']);
      t.refresher.stop();
    });
  });

  test('a failure keeps retrying after 5, 15, then 60 minutes', () {
    fakeAsync((async) {
      var failing = true;
      final t = setUpRefresher(async, [m3u('a')], fails: (_) => failing);
      t.refresher.start();
      async.elapse(const Duration(minutes: 5 + 15 + 60 + 60 + 1));
      expect(t.calls.map((c) => c.split(':').first), ['0', '5', '20', '80', '140']);
      expect(t.states['a']!.lastError, "Couldn't reach the playlist");
      failing = false;
      async.elapse(const Duration(minutes: 60));
      expect(t.calls.last, startsWith('200:'));
      expect(t.states['a']!.failures, 0);
      async.elapse(const Duration(hours: 1));
      expect(t.calls, hasLength(6));
      t.refresher.stop();
    });
  });

  test('Refresh now runs at once, even while waiting to retry; never two at a time', () {
    fakeAsync((async) {
      final t = setUpRefresher(async, [m3u('a')], fails: (_) => true, takes: const Duration(seconds: 30));
      t.refresher.start();
      async.elapse(const Duration(minutes: 1));
      expect(t.calls, hasLength(1));
      unawaited(t.refresher.refreshNow(m3u('a')));
      async.flushMicrotasks();
      expect(t.calls, hasLength(2));
      unawaited(t.refresher.refreshNow(m3u('a')));
      async.flushMicrotasks();
      expect(t.calls, hasLength(2));
      t.refresher.stop();
      async.elapse(const Duration(hours: 2));
      expect(t.calls, hasLength(2));
    });
  });
}
