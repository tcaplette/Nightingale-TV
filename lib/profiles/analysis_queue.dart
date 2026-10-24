import 'dart:async';

import 'package:flutter/foundation.dart';

import '../commercials/analysis/media_analyzer.dart';

/// Server mode's media analysis: one exported profile at a time, in profile
/// order (design D4). A profile keeps the turn until its analysis has
/// nothing left to do, then the next one gets it. After a whole round in
/// which nobody had anything to do, the queue rests for [rest] before
/// asking around again, so new work (a library refresh) is still found.
///
/// Holding off while an export stream plays is each analyzer's own
/// `exportBusy` rule; the turn doesn't move for it.
class AnalysisQueue {
  /// How long to rest after a round with no work.
  @visibleForTesting
  static Duration rest = const Duration(minutes: 10);

  final _allowed = <String, ValueNotifier<bool>>{};

  /// Each exported profile's `AppState.analysisState`, and its listener.
  final _idle = <String, ValueListenable<AnalyzerState>>{};
  final _listeners = <String, VoidCallback>{};
  List<String> _order = const [];
  String? _turn;

  /// Whether the profile holding the turn has worked in it.
  bool _worked = false;

  /// Turns in a row that found nothing to do.
  int _idleTurns = 0;
  Timer? _resting;

  /// Who analyzes now, if anyone.
  String? get turn => _turn;

  /// [profileId]'s turn, for its [AppState.analysisAllowed].
  ValueListenable<bool> allowedFor(String profileId) => _allowed.putIfAbsent(profileId, () => ValueNotifier(false));

  /// The exported profiles, in profile order, and what each one's analysis
  /// is doing (null while it isn't loaded).
  void setProfiles(List<String> order, ValueListenable<AnalyzerState>? Function(String id) idleOf) {
    for (final id in [..._idle.keys]) {
      if (!order.contains(id) || !identical(idleOf(id), _idle[id])) _idle.remove(id)!.removeListener(_listeners.remove(id)!);
    }
    for (final id in order) {
      final idle = idleOf(id);
      if (idle == null || _idle.containsKey(id)) continue;
      final listener = _listeners[id] = () => _onIdle(id);
      _idle[id] = idle..addListener(listener);
    }
    _order = [for (final id in order) if (_idle.containsKey(id)) id];
    if (_turn != null && !_order.contains(_turn)) {
      _set(_turn!, false);
      _turn = null;
    }
    if (_turn == null && _resting == null) _next(after: null);
  }

  void _onIdle(String id) {
    final idle = _idle[id];
    if (id != _turn || idle == null) return;
    switch (idle.value) {
      case AnalyzerState.working:
        _worked = true;
        _idleTurns = 0;
      case AnalyzerState.idle:
        _passOn();
      case AnalyzerState.starting:
        break;
    }
  }

  void _passOn() {
    final id = _turn;
    if (id == null) return;
    if (!_worked) _idleTurns++;
    if (_idleTurns >= _order.length) {
      // Nobody had anything to do: rest, then go round again.
      _set(id, false);
      _turn = null;
      _idleTurns = 0;
      _resting = Timer(rest, () {
        _resting = null;
        _next(after: id);
      });
      return;
    }
    _next(after: id);
  }

  /// Gives the turn to the profile after [after] (or the first).
  void _next({required String? after}) {
    if (_order.isEmpty) return;
    final i = after == null ? -1 : _order.indexOf(after);
    final id = _order[(i + 1) % _order.length];
    if (_turn != null) _set(_turn!, false);
    _turn = id;
    _worked = false;
    _set(id, true);
    // Already idle (signed out, or nothing to analyze): no change will be
    // heard, so pass on now.
    if (_idle[id]?.value == AnalyzerState.idle) {
      scheduleMicrotask(() {
        if (_turn == id && _idle[id]?.value == AnalyzerState.idle) _passOn();
      });
    }
  }

  void _set(String id, bool on) => (allowedFor(id) as ValueNotifier<bool>).value = on;

  void dispose() {
    _resting?.cancel();
    for (final e in _idle.entries) {
      e.value.removeListener(_listeners[e.key]!);
    }
    _idle.clear();
    _listeners.clear();
  }
}
