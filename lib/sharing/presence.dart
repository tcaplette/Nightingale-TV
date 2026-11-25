import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../l10n/tr.dart';
import '../library/library_index.dart';
import '../playback/tuner.dart';
import 'share_client.dart';

/// What this profile is watching, as published (friend-presence, "What is
/// published"): nothing else ever leaves the device.
@immutable
class Watching {
  const Watching({this.title, required this.channelName, this.sharedChannelId, required this.startedAt});

  /// The show's name for episodes, the movie's title for movies; null when
  /// there's none to give (a live channel without a guide, off the air).
  final String? title;
  final String channelName;

  /// The shared channel's id, when the channel is shared or a shared copy.
  final String? sharedChannelId;

  /// When this started, by the backend's clock.
  final DateTime startedAt;

  /// The same thing being watched (the start time aside).
  bool sameAs(Watching? o) =>
      o != null && o.title == title && o.channelName == channelName && o.sharedChannelId == sharedChannelId;
}

/// A presence row as read: a friend's (or, cleared, nobody's) now watching.
@immutable
class PresenceRow {
  const PresenceRow({
    required this.userId,
    this.title,
    this.channelName,
    this.sharedChannelId,
    this.startedAt,
    required this.updatedAt,
  });

  final String userId;
  final String? title;

  /// Null when the row is cleared: not watching.
  final String? channelName;
  final String? sharedChannelId;
  final DateTime? startedAt;

  /// Last refreshed, by the backend's clock.
  final DateTime updatedAt;

  bool get watching => channelName != null;

  static PresenceRow fromJson(Map<String, dynamic> j) => PresenceRow(
        userId: j['user_id'] as String,
        title: j['title'] as String?,
        channelName: j['channel_name'] as String?,
        sharedChannelId: j['shared_channel_id'] as String?,
        startedAt: DateTime.tryParse(j['started_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// A friend watching now.
@immutable
class FriendWatching {
  const FriendWatching(this.friend, this.row);

  final ShareProfile friend;
  final PresenceRow row;

  /// "Watching The Office on 90s Sitcoms", or "Watching 90s Sitcoms".
  String get line => switch (row.title) {
        final t? => tr.presenceWatchingOn(t, row.channelName ?? ''),
        null => tr.presenceWatchingChannel(row.channelName ?? ''),
      };
}

/// What presence needs from the backend; [ShareClient] in the app, a fake
/// in tests.
abstract interface class PresenceBackend {
  bool get started;
  String? get userId;
  Future<ShareProfile?> profile();
  Future<FriendsList> friends();
  Future<void> setPresence(String value);
  Future<void> setWatching(Watching? w);
  Future<List<PresenceRow>> watchingRows();
  Future<({DateTime server, Duration rtt})> serverTime();
  Future<void> watchRows(
      {required void Function(PresenceRow row) onRow,
      required void Function() onReady,
      required void Function(Object error) onError});
  Future<void> stopWatchingRows();
}

/// Show what I'm watching (D4).
enum PresenceSetting {
  friends,
  off;

  static PresenceSetting? parse(String? s) => switch (s) {
        'friends' => friends,
        'off' => off,
        _ => null,
      };
}

/// Friend presence for the profile in front (friend-presence D2–D6): what
/// this profile publishes, and what its friends are watching.
///
/// [attach] gives it the profile's started, linked client (or null:
/// hidden, asleep, a kid or unlinked profile); [tuner] is the profile's
/// tuner. Before the client stops, [clearBeforeStop] takes what's
/// published down.
class Presence extends ChangeNotifier {
  Presence({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Refreshes what's published this often while watching (D2).
  @visibleForTesting
  static Duration heartbeat = const Duration(minutes: 2);

  /// A row not refreshed for this long, by the backend's clock, is ignored (D3).
  static const stale = Duration(minutes: 5);

  /// How long a clear may hold up going to the background or to sleep.
  static const clearTimeout = Duration(seconds: 3);

  final DateTime Function() _clock;

  PresenceBackend? _client;
  AppState? _app;
  Tuner? _tuner;
  bool _disposed = false;

  /// Show what I'm watching, as the account has it; null until it's read,
  /// or before the question was asked.
  PresenceSetting? get setting => _setting;
  PresenceSetting? _setting;

  /// The setting has been read from the account since this attach.
  bool get settingKnown => _settingKnown;
  bool _settingKnown = false;

  /// Watch privately: in memory only, so it's off at the next launch.
  final private = ValueNotifier(false);

  /// The backend's clock minus this device's (D3).
  Duration _offset = Duration.zero;

  /// Friends' rows and profiles, by account.
  final _rows = <String, PresenceRow>{};
  final _friends = <String, ShareProfile>{};

  /// "Tyler and Sam are watching now": once per app start (D5).
  final notice = ValueNotifier<String?>(null);
  bool _noticeShown = false;
  bool _firstLoadDone = false;

  /// What was last published and the backend took; null when the row is
  /// cleared. [_unsure] when the last send failed, so the next connect sends
  /// again (a retried clear, D2).
  Watching? _published;
  bool _unsure = true;
  Watching? _current;
  Future<void>? _sending;
  bool _sendAgain = false;
  Timer? _heartbeat;
  Timer? _staleTimer;
  int _attachGeneration = 0;
  Future<void>? _connecting;

  bool get attached => _client != null && (_client?.started ?? false);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    _staleTimer?.cancel();
    _tuner?.removeListener(_tunerChanged);
    _app?.removeListener(_tunerChanged);
    private.removeListener(_privateChanged);
    private.dispose();
    notice.dispose();
    super.dispose();
  }

  // ---- Inputs -----------------------------------------------------------------

  /// The profile's tuner while it's watching.
  set tuner(Tuner? t) {
    if (identical(t, _tuner)) return;
    _tuner?.removeListener(_tunerChanged);
    _tuner = t;
    _tuner?.addListener(_tunerChanged);
    _tunerChanged();
  }

  Tuner? get tuner => _tuner;

  bool _privateListening = false;

  /// Gives the profile in front's started, linked [client] and its [app];
  /// null for none. Each attach with a client is a connect.
  Future<void> attach(PresenceBackend? client, AppState? app) async {
    if (_disposed) return;
    if (!_privateListening) {
      _privateListening = true;
      private.addListener(_privateChanged);
    }
    if (!identical(app, _app)) {
      _app?.removeListener(_tunerChanged);
      _app = app;
      _app?.addListener(_tunerChanged);
    }
    final changed = !identical(client, _client);
    if (changed) {
      final old = _client;
      _client = client;
      _attachGeneration++;
      _heartbeat?.cancel();
      _heartbeat = null;
      _staleTimer?.cancel();
      _rows.clear();
      _friends.clear();
      _setting = null;
      _settingKnown = false;
      _firstLoadDone = false;
      // A new account or profile: what it published is unknown.
      _published = null;
      _unsure = true;
      if (old != null) unawaited(old.stopWatchingRows().catchError((Object _) {}));
      notifyListeners();
    }
    // Connecting waits on Realtime; the caller doesn't.
    if (client != null && client.started && (changed || (!_firstLoadDone && _connecting == null))) {
      final generation = _attachGeneration;
      final connecting = _connecting = _connect(client, generation);
      unawaited(connecting.whenComplete(() {
        if (identical(_connecting, connecting)) _connecting = null;
      }));
    } else {
      _sync();
    }
  }

  /// The client is about to stop (hidden, asleep, another profile, signing
  /// out): what's published comes down first, within [clearTimeout].
  Future<void> clearBeforeStop() async {
    final client = _client;
    if (client == null || !client.started) return;
    if (_published == null && !_unsure) return;
    try {
      // A send under way goes first, but never holds this up for long.
      await _sending?.timeout(clearTimeout, onTimeout: () {});
      await client.setWatching(null).timeout(clearTimeout);
      _published = null;
      _unsure = false;
    } on Object catch (e) {
      // Retried on the next connect; friends ignore it after 5 minutes.
      _unsure = true;
      debugPrint('Presence clear: $e');
    }
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  /// Show what I'm watching changed here (Sharing): saved to the account;
  /// Off takes what's published down at once.
  /// [client] is the Sharing screen's, when it isn't attached yet (setup).
  Future<void> setSetting(PresenceSetting value, {PresenceBackend? client}) async {
    final via = client ?? _client;
    if (via == null) throw StateError('Sharing is stopped');
    await via.setPresence(value.name);
    if (!identical(via, _client)) return;
    _setting = value;
    _settingKnown = true;
    notifyListeners();
    _sync();
    await _sending;
  }

  /// Sharing's friends list was refreshed (a friend added, removed or
  /// blocked).
  void friendsChanged(List<ShareProfile> friends) {
    _friends
      ..clear()
      ..addEntries(friends.map((f) => MapEntry(f.userId, f)));
    notifyListeners();
  }

  // ---- Connecting -------------------------------------------------------------

  Future<void> _connect(PresenceBackend client, int generation) async {
    bool current() => !_disposed && generation == _attachGeneration && client.started;
    try {
      final me = await client.profile();
      if (!current()) return;
      _setting = PresenceSetting.parse(me?.presence);
      _settingKnown = true;
      notifyListeners();
      // A pending clear (or what's on now) goes first.
      _sync();
      await _measureClock(client);
      if (!current()) return;
      final ready = Completer<void>();
      await client.watchRows(
        onRow: (row) {
          if (current()) _onRow(row);
        },
        onReady: () {
          if (!ready.isCompleted) ready.complete();
        },
        onError: (e) {
          // No chips rather than an error (a refused connection).
          debugPrint('Presence updates: $e');
          if (!ready.isCompleted) ready.completeError(e);
        },
      );
      await ready.future.timeout(const Duration(seconds: 15));
      if (!current()) return;
      // Loaded after changes flow, so none falls between.
      final friends = await client.friends();
      final rows = await client.watchingRows();
      if (!current()) return;
      friendsChanged(friends.friends);
      for (final r in rows) {
        _rows[r.userId] = r;
      }
      _firstLoadDone = true;
      _rowsChanged();
      _maybeNotice();
    } on Object catch (e) {
      debugPrint('Presence unavailable: $e');
    }
  }

  /// The backend clock's offset from 3 samples, keeping the one with the
  /// shortest round trip (D3).
  Future<void> _measureClock(PresenceBackend client) async {
    ({DateTime server, Duration rtt, DateTime local})? best;
    for (var i = 0; i < 3; i++) {
      try {
        final s = await client.serverTime();
        final local = _clock();
        if (best == null || s.rtt < best.rtt) best = (server: s.server, rtt: s.rtt, local: local);
      } on Object catch (e) {
        debugPrint('Presence clock: $e');
      }
    }
    if (best == null) return;
    // The server read the clock about half a round trip before the answer.
    _offset = best.server.add(best.rtt ~/ 2).difference(best.local);
  }

  /// The backend's time now.
  DateTime serverNow() => _clock().add(_offset);

  @visibleForTesting
  Duration get clockOffset => _offset;

  void _onRow(PresenceRow row) {
    _rows[row.userId] = row;
    if (!_friends.containsKey(row.userId) && row.watching) unawaited(_refreshFriends());
    _rowsChanged();
  }

  Future<void> _refreshFriends() async {
    final client = _client;
    if (client == null || !client.started) return;
    try {
      friendsChanged((await client.friends()).friends);
    } on Object catch (e) {
      debugPrint('Presence friends: $e');
    }
  }

  void _rowsChanged() {
    notifyListeners();
    _armStaleTimer();
  }

  /// Wakes when the next live row goes stale, so it leaves the screen.
  void _armStaleTimer() {
    _staleTimer?.cancel();
    final now = serverNow();
    Duration? next;
    for (final r in _rows.values) {
      if (!r.watching) continue;
      final left = r.updatedAt.add(stale).difference(now);
      if (left.isNegative) continue;
      if (next == null || left < next) next = left;
    }
    if (next == null) return;
    _staleTimer = Timer(next + const Duration(seconds: 1), _rowsChanged);
  }

  // ---- What friends are watching -------------------------------------------------

  /// Watching, and refreshed within [stale] by the backend's clock.
  bool _live(PresenceRow r) => r.watching && serverNow().difference(r.updatedAt) <= stale;

  /// Friends watching now, by name.
  List<FriendWatching> get watching {
    final out = [
      for (final r in _rows.values)
        if (_friends[r.userId] case final f? when _live(r)) FriendWatching(f, r),
    ];
    out.sort((a, b) => a.friend.name.toLowerCase().compareTo(b.friend.name.toLowerCase()));
    return out;
  }

  /// What [friendId] is watching now, if anything.
  FriendWatching? of(String friendId) {
    final r = _rows[friendId], f = _friends[friendId];
    return r != null && f != null && _live(r) ? FriendWatching(f, r) : null;
  }

  /// The friends watching shared channel [sharedId] now.
  List<ShareProfile> on(String? sharedId) =>
      sharedId == null ? const [] : [for (final w in watching) if (w.row.sharedChannelId == sharedId) w.friend];

  /// The friends watching [ch], when it's a shared channel (or a copy of one).
  List<ShareProfile> onChannel(Channel? ch) => on(ch?.share?.id);

  void _maybeNotice() {
    if (_noticeShown || !_firstLoadDone) return;
    final app = _app;
    if (app == null) return;
    final mine = {for (final c in app.channels) ?c.share?.id};
    final names = [
      for (final w in watching)
        if (w.row.sharedChannelId case final id? when mine.contains(id)) w.friend.name,
    ];
    // Once per app start, even when no one is on (the first connect counts).
    _noticeShown = true;
    if (names.isEmpty) return;
    notice.value = names.length == 1 ? tr.presenceNoticeOne(names.single) : tr.presenceNoticeMany(joinNames(names));
  }

  // ---- Publishing -------------------------------------------------------------

  /// What should be published now; null for nothing.
  Watching? _wanted() {
    final client = _client, tuner = _tuner, app = _app;
    if (client == null || !client.started || tuner == null || app == null) return null;
    if (_setting != PresenceSetting.friends || private.value) return null;
    // A kid profile never publishes (it's never linked either).
    if (app.maxRatingRank != null) return null;
    if (!identical(tuner.app, app)) return null;
    final ch = tuner.channel;
    if (ch == null || tuner.status == TunerStatus.idle) return null;
    final title = presenceTitle(tuner.program);
    final name = ch.displayName.length > 100 ? ch.displayName.substring(0, 100) : ch.displayName;
    final shared = ch.share?.id;
    final now = _current;
    if (now != null && now.title == title && now.channelName == name && now.sharedChannelId == shared) return now;
    return Watching(title: title, channelName: name, sharedChannelId: shared, startedAt: serverNow());
  }

  void _tunerChanged() {
    final next = _wanted();
    if (identical(next, _current)) return;
    _current = next;
    _sync();
  }

  void _privateChanged() {
    _current = _wanted();
    _sync();
  }

  /// Sends what's wanted when it differs from what's published; one send at
  /// a time, the latest wins.
  void _sync() {
    _current = _wanted();
    if (_sending != null) {
      _sendAgain = true;
      return;
    }
    _sending = _send().whenComplete(() {
      _sending = null;
      if (_sendAgain) {
        _sendAgain = false;
        _sync();
      }
    });
  }

  Future<void> _send() async {
    final client = _client;
    if (client == null || !client.started) return;
    final want = _current;
    final same = want == null ? _published == null : want.sameAs(_published);
    if (same && !_unsure) {
      _armHeartbeat();
      return;
    }
    // Nothing published and nothing wanted, on a fresh attach: a clear
    // costs one request and covers a row left by a crash.
    try {
      await client.setWatching(want);
      _published = want;
      _unsure = false;
    } on Object catch (e) {
      _unsure = true;
      debugPrint('Presence publish: $e');
    }
    _armHeartbeat();
  }

  /// Every [heartbeat] while something is published.
  void _armHeartbeat() {
    if (_published == null || _unsure) {
      _heartbeat?.cancel();
      _heartbeat = null;
      return;
    }
    _heartbeat ??= Timer.periodic(heartbeat, (_) => unawaited(_beat()));
  }

  Future<void> _beat() async {
    final client = _client, w = _published;
    if (client == null || !client.started || w == null || _sending != null) return;
    try {
      await client.setWatching(w);
    } on Object catch (e) {
      debugPrint('Presence heartbeat: $e');
    }
  }

  @visibleForTesting
  Watching? get published => _published;
}

/// The title published for [program] (D2): the show's name for episodes,
/// the movie's title for movies, the guide's programme on a live channel;
/// null otherwise (a live channel without a guide, music, off the air).
/// During a break the tuner's program is still the show, so it keeps its
/// title. An episode with no show name gives none (never its episode title).
String? presenceTitle(ScheduledProgram? program) {
  final item = program?.item;
  if (program == null || item == null) return null;
  if (program.isLive && item.id.contains('@gap')) return null;
  // A home video's name never leaves the device.
  if (item.isHome) return null;
  final t = switch (item.kind) {
    // Never the episode's own title; nothing for a show without a name
    // (the library files those under a placeholder).
    MediaKind.episode => item.seriesName == SeriesEntry.unknownName ? null : item.seriesName,
    MediaKind.movie => item.title,
    // A YouTube channel's video, as for any program (youtube-subscriptions D13).
    MediaKind.youtubeVideo => item.title,
    _ => null,
  };
  return t == null || t.trim().isEmpty ? null : (t.length > 200 ? t.substring(0, 200) : t);
}
