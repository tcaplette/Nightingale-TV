import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../l10n/tr.dart';
import '../library/library_index.dart';
import '../playback/party_schedule.dart';
import '../playback/playback_diagnostics.dart';
import '../playback/tuner.dart';
import 'party_reactions.dart';
import 'party_timeline.dart';
import 'recipe_matcher.dart';
import 'share_client.dart';

/// A party as the backend gives it (`party_json`).
@immutable
class PartyInfo {
  const PartyInfo({
    required this.id,
    required this.host,
    required this.channelName,
    required this.state,
    required this.ended,
    required this.members,
  });

  final String id;
  final String host;
  final String channelName;
  final Map<String, Object?> state;
  final bool ended;
  final List<ShareProfile> members;

  static PartyInfo fromJson(Map<String, dynamic> j) => PartyInfo(
        id: j['id'] as String,
        host: j['host'] as String,
        channelName: j['channel_name'] as String? ?? '',
        state: j['state'] is Map ? Map<String, Object?>.from(j['state'] as Map) : const {},
        ended: j['ended'] == true,
        members: [
          for (final m in j['members'] as List? ?? const [])
            if (m is Map) ShareProfile.fromJson(Map<String, dynamic>.from(m)),
        ],
      );
}

/// An open invite to a live party (the banner, Sharing → Watch parties).
@immutable
class PartyInvite {
  const PartyInvite({required this.party, required this.host, required this.title, required this.channelName, required this.at});

  final String party;
  final ShareProfile host;
  final String title;
  final String channelName;
  final DateTime at;

  static PartyInvite? fromJson(Object? j) {
    if (j is! Map || j['party'] is! String || j['host'] is! Map) return null;
    return PartyInvite(
      party: j['party'] as String,
      host: ShareProfile.fromJson(Map<String, dynamic>.from(j['host'] as Map)),
      title: j['title'] as String? ?? '',
      channelName: j['channel_name'] as String? ?? '',
      at: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// What start-party answered: the party, and for Get a link its invite.
typedef PartyStarted = ({PartyInfo party, FriendInvite? invite});

/// Why a join didn't happen.
enum PartyJoinStatus { ok, ended, full, notAllowed, unavailable }

/// A party's two Realtime topics, joined (D7): `party:<id>` for actions,
/// reactions and hello/bye, `party:<id>:host` for the timeline.
abstract interface class PartyRoom {
  Future<void> send(String event, Map<String, Object?> payload);
  Future<void> sendTimeline(Map<String, Object?> payload);
  Future<void> close();
}

/// What a party needs from the backend; [ShareClient] in the app, a fake in
/// tests.
abstract interface class PartyBackend {
  bool get started;
  String? get userId;
  Future<ShareProfile?> profile();
  Future<({DateTime server, Duration rtt})> serverTime();
  Future<PartyStarted> startParty(
      {required String channelName, required Map<String, Object?> state, List<String> invite, bool link});
  Future<FriendInvite?> inviteToParty(String party, {List<String> invite, bool link});
  Future<(PartyJoinStatus, PartyInfo?)> joinParty(String party);

  /// True when the party ended with it.
  Future<bool> leaveParty(String party, {bool hostGone = false});
  Future<void> writePartyState(String party, Map<String, Object?> state);
  Future<List<ShareProfile>> partyMembers(String party);
  Future<List<PartyInvite>> partyInvites();

  /// Joins [party]'s topics. [onMessage] gets each broadcast's event and
  /// payload; [onMember] each member row's change (user, left).
  Future<PartyRoom> openPartyRoom(String party,
      {required void Function(String event, Map<String, dynamic> payload) onMessage,
      required void Function(String user, bool left) onMember});

  /// Follows this account's party invites; [onChange] at each change, and
  /// once when changes flow.
  Future<void> watchPartyInvites(void Function() onChange);
  Future<void> stopWatchingPartyInvites();
}

/// How a member's picture stands against the host's.
enum PartySync { inSync, catchingUp, missing }

/// The party in progress on this device.
class _Session {
  _Session({required this.id, required this.host, required this.channelName, required this.room});

  final String id;
  final String host;
  final String channelName;
  final PartyRoom room;
  final members = <String, ShareProfile>{};

  /// The host's latest timeline (guests) or the last one sent (host).
  PartyTimeline? timeline;
  int seq = 0;

  /// When the host was last heard from (guests).
  DateTime lastBeat = DateTime.now();

  /// The guest's party channel.
  Channel? channel;
  bool ending = false;
}

/// Watch together (watch-together D1–D8) for the profile in front: starting,
/// inviting and joining parties, the host's timeline, a guest's following
/// and drift correction, party-wide transport, reactions, joins and leaves.
///
/// [attach] gives it the started, linked client (or null); [tuner] is the
/// profile's tuner. Before the client stops, [leaveBeforeStop] leaves.
class WatchParty extends ChangeNotifier {
  WatchParty({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    limiter = ReactionLimiter(clock: _clock);
  }

  final DateTime Function() _clock;

  /// The host sends its timeline again this often (D1).
  @visibleForTesting
  static Duration heartbeat = const Duration(seconds: 5);

  /// The host writes the party's state at least this often (late joiners,
  /// and the backend's "host gone" judgement).
  @visibleForTesting
  static Duration stateEvery = const Duration(seconds: 30);

  /// A guest who hasn't heard from the host for this long ends the party.
  static const hostGoneAfter = Duration(seconds: 60);

  /// The backend clock is measured again this often (D3).
  static const clockEvery = Duration(minutes: 5);

  /// How often a guest's drift is checked.
  @visibleForTesting
  static Duration checkEvery = const Duration(seconds: 1);

  /// Drift thresholds (D3).
  static const seekAbove = Duration(seconds: 2);
  static const nudgeAbove = Duration(milliseconds: 250);
  static const nudgedWithin = Duration(milliseconds: 100);
  static const nudge = 0.05;

  /// A nudge that hasn't brought the drift down by 100 ms in this long
  /// means the player can't change speed (passthrough audio): seek instead.
  static const nudgeGivesUp = Duration(seconds: 8);

  /// Invite banners go after this.
  static const bannerFor = Duration(seconds: 30);

  /// Most friends invited at once.
  static const maxInvited = 7;
  static const maxMembers = 8;

  late final ReactionLimiter limiter;

  PartyBackend? _client;
  AppState? _app;
  Tuner? _tuner;
  ShareProfile? _me;
  bool _disposed = false;
  int _attachGeneration = 0;

  _Session? _s;

  /// The backend's clock less this device's (D3), and when it was measured.
  Duration _offset = Duration.zero;
  DateTime? _measuredAt;

  Timer? _beat;
  Timer? _stateTimer;
  Timer? _check;
  Timer? _bannerTimer;
  DateTime? _stateWrittenAt;
  bool _stateWriteDue = false;

  /// The action whose timeline hasn't gone out yet (host).
  PartyBy? _pendingBy;
  DateTime? _pendingUntil;
  Timer? _pendingTimer;

  // Drift (guest).
  double _speed = 1;
  bool _nudgeWorks = true;
  DateTime? _nudgeSince;
  Duration _nudgeFrom = Duration.zero;
  DateTime? _lastSeek;

  /// How far ahead an open or a seek aims: what moves cost while they landed
  /// (a slow link takes seconds; the costliest lately, fading by a fifth at
  /// each landing) and a margin, so the next lands a little ahead and holds
  /// the picture for the rest. A landing ahead is exact to correct; one
  /// behind needs another seek.
  Duration _seekLead = initialLead;
  Duration _leadUsed = Duration.zero;
  Duration _moveCost = Duration.zero;
  bool _landing = false;
  int _opensSeen = 0;

  /// The picture held for a guest that landed ahead.
  Timer? _holdTimer;
  bool _holding = false;

  /// The piece on screen when last checked, and whether it's still catching
  /// up (opened or seeked, not yet within a second).
  ScheduledProgram? _onScreen;
  bool _catchingUp = true;

  /// The player's position at the last check, to tell playing from stalled.
  ({Duration position, DateTime at})? _lastReading;

  /// A seek's landing is judged no sooner than this after it.
  static const _landAfter = Duration(milliseconds: 1500);
  static const _maxLead = Duration(seconds: 10);

  /// A seek still buffering after this long is judged anyway.
  static const _landWithin = Duration(seconds: 30);

  /// The first open's lead, before any landing was measured, and the margin
  /// a learned lead adds.
  static const initialLead = Duration(seconds: 3);
  static const _leadMargin = Duration(milliseconds: 750);
  static const _costDecay = 0.8;

  /// Ahead by more than this is a seek rather than a hold.
  static const _maxHold = Duration(seconds: 10);
  PartySync _sync = PartySync.catchingUp;

  RecipeMatcher? _matcher;
  LibraryIndex? _matcherOf;

  /// Open invites, newest first.
  List<PartyInvite> get invites => List.unmodifiable(_invites);
  var _invites = <PartyInvite>[];
  final _seenInvites = <String>{};

  /// The invite banner's invite while it's up.
  final banner = ValueNotifier<PartyInvite?>(null);

  final _reactions = StreamController<FloatingReaction>.broadcast();
  final _toasts = StreamController<String>.broadcast();
  int _reactionIds = 0;

  /// Reactions to float up the picture.
  Stream<FloatingReaction> get reactions => _reactions.stream;

  /// "Sam joined", "Sam paused", "Tyler ended the watch party".
  Stream<String> get toasts => _toasts.stream;

  bool get attached => _client != null && (_client?.started ?? false);
  bool get active => _s != null;
  bool get isHost => _s != null && _s!.host == _client?.userId;
  String? get partyId => _s?.id;
  String? get myId => _client?.userId;
  PartySync get sync => _sync;
  PartyTimeline? get timeline => _s?.timeline;

  /// The members, the host first.
  List<({ShareProfile profile, bool host})> get members {
    final s = _s;
    if (s == null) return const [];
    final out = [for (final p in s.members.values) (profile: p, host: p.userId == s.host)];
    out.sort((a, b) => a.host == b.host ? 0 : (a.host ? -1 : 1));
    return out;
  }

  String get hostName => _s?.members[_s?.host]?.name ?? '';

  /// Room for more members (the host's Invite).
  bool get hasRoom => (_s?.members.length ?? 0) < maxMembers;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimers();
    _bannerTimer?.cancel();
    _tuner?.removeListener(_tunerChanged);
    banner.dispose();
    unawaited(_reactions.close());
    unawaited(_toasts.close());
    super.dispose();
  }

  void _stopTimers() {
    _beat?.cancel();
    _stateTimer?.cancel();
    _check?.cancel();
    _pendingTimer?.cancel();
    _beat = _stateTimer = _check = _pendingTimer = null;
    _endHold();
  }

  // ---- Inputs -----------------------------------------------------------------

  set tuner(Tuner? t) {
    if (identical(t, _tuner)) return;
    _tuner?.removeListener(_tunerChanged);
    _tuner = t;
    _tuner?.addListener(_tunerChanged);
    t?.partyLead = _seekLead;
  }

  Tuner? get tuner => _tuner;

  /// Gives the profile in front's started, linked [client] and its [app];
  /// null for none.
  Future<void> attach(PartyBackend? client, AppState? app) async {
    if (_disposed) return;
    _app = app;
    if (identical(client, _client)) return;
    final old = _client;
    _client = client;
    _attachGeneration++;
    PlaybackDiagnostics.note('PARTY', 'attach ${client == null ? 'none' : 'client'} (was ${old == null ? 'none' : 'client'})');
    _me = null;
    _invites = [];
    _seenInvites.clear();
    banner.value = null;
    if (old != null) unawaited(old.stopWatchingPartyInvites().catchError((Object _) {}));
    notifyListeners();
    if (client == null || !client.started) return;
    final generation = _attachGeneration;
    bool current() => !_disposed && generation == _attachGeneration && client.started;
    try {
      _me = await client.profile();
      if (!current()) return;
      // Invites already waiting don't pop up a banner: they're listed.
      _seenInvites.addAll((await client.partyInvites()).map((i) => i.party));
      await client.watchPartyInvites(() {
        if (current()) unawaited(_loadInvites());
      });
      if (current()) await _loadInvites();
    } on Object catch (e) {
      debugPrint('Watch parties unavailable: $e');
    }
  }

  Future<void> _loadInvites() async {
    final client = _client;
    if (client == null || !client.started) return;
    try {
      final list = await client.partyInvites();
      _invites = [for (final i in list) if (i.party != _s?.id) i];
      // A new one, while the app is open: the banner (D8).
      final fresh = _invites.where((i) => !_seenInvites.contains(i.party)).firstOrNull;
      _seenInvites.addAll(_invites.map((i) => i.party));
      if (fresh != null) _showBanner(fresh);
      if (banner.value != null && !_invites.any((i) => i.party == banner.value!.party)) banner.value = null;
      notifyListeners();
    } on Object catch (e) {
      debugPrint('Watch party invites: $e');
    }
  }

  void _showBanner(PartyInvite invite) {
    PlaybackDiagnostics.note('PARTY', 'invite banner for ${invite.party}');
    banner.value = invite;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(bannerFor, () {
      if (identical(banner.value, invite)) banner.value = null;
    });
  }

  /// Not now (the banner's, or Back): it stays in Sharing → Watch parties.
  void hideBanner() {
    if (banner.value != null) PlaybackDiagnostics.note('PARTY', 'invite banner hidden');
    _bannerTimer?.cancel();
    banner.value = null;
  }


  // ---- The clock --------------------------------------------------------------

  /// The backend's time now.
  int backendNow() => _clock().add(_offset).millisecondsSinceEpoch;

  @visibleForTesting
  Duration get clockOffset => _offset;

  /// The sample with the shortest round trip of 5 (D3); again after
  /// [clockEvery].
  Future<void> _measureClock({bool force = false}) async {
    final client = _client;
    if (client == null) return;
    final at = _measuredAt;
    if (!force && at != null && _clock().difference(at) < clockEvery) return;
    ({DateTime server, Duration rtt, DateTime local})? best;
    for (var i = 0; i < 5; i++) {
      try {
        final s = await client.serverTime();
        final local = _clock();
        if (best == null || s.rtt < best.rtt) best = (server: s.server, rtt: s.rtt, local: local);
      } on Object catch (e) {
        debugPrint('Party clock: $e');
      }
    }
    if (best == null) return;
    _offset = best.server.add(best.rtt ~/ 2).difference(best.local);
    _measuredAt = _clock();
    PlaybackDiagnostics.note('PARTY', 'clock offset ${_offset.inMilliseconds} ms (rtt ${best.rtt.inMilliseconds} ms)');
  }

  DateTime _local(int backendMs) => DateTime.fromMillisecondsSinceEpoch(backendMs - _offset.inMilliseconds);

  // ---- Starting and joining -------------------------------------------------------

  /// Whether Watch together is offered on [ch] (D8): a Nightingale channel
  /// with something on, outside a party, linked and connected.
  /// Not on live or YouTube channels (watch-together; youtube-subscriptions
  /// D13).
  bool canStartOn(Channel? ch) => attached && !active && ch != null && !ch.isLive && !ch.isYouTube && _me != null;

  /// Starts a party for what [tuner] plays, inviting [friends]; with [link]
  /// a `watch` invite comes back. Throws [ShareUnavailable] when the backend
  /// can't be reached.
  Future<FriendInvite?> start({List<String> friends = const [], bool link = false}) async {
    final client = _client, tuner = _tuner, app = _app;
    final ch = tuner?.channel;
    if (client == null || tuner == null || app == null || ch == null || ch.isLive || ch.isYouTube) {
      throw const ShareUnavailable('nothing to watch together');
    }
    if (_s != null) await leave();
    await _measureClock();
    final tl = _hostTimeline() ?? PartyTimeline(item: null, title: '', anchorMs: backendNow());
    final started = await client.startParty(
        channelName: ch.displayName, state: tl.toJson(), invite: friends.take(maxInvited).toList(), link: link);
    final party = started.party;
    final s = await _open(party);
    for (final m in party.members) {
      s.members[m.userId] = m;
    }
    if (_me case final me?) s.members[me.userId] = me;
    tuner.partyHosting = true;
    _beat = Timer.periodic(heartbeat, (_) => _heartbeat());
    _stateTimer = Timer.periodic(stateEvery, (_) => unawaited(_writeState(force: true)));
    // A host whose picture moves on its own still publishes (keyframe
    // joins, a hand-over the tuner made without telling).
    _check = Timer.periodic(checkEvery, (_) => _hostCheck());
    _hostCheck();
    PlaybackDiagnostics.note('PARTY', 'hosting ${party.id} on "${ch.displayName}"');
    notifyListeners();
    return started.invite;
  }

  /// The host invites more friends (the party row's Invite), up to 8 in all.
  Future<FriendInvite?> inviteMore({List<String> friends = const [], bool link = false}) async {
    final s = _s, client = _client;
    if (s == null || client == null || !isHost) return null;
    return client.inviteToParty(s.id, invite: friends, link: link);
  }

  /// Joins [party] as a guest: its program plays from this library at the
  /// host's position.
  Future<PartyJoinStatus> join(String party) async {
    final client = _client, tuner = _tuner, app = _app;
    if (client == null || tuner == null || app == null) return PartyJoinStatus.unavailable;
    if (_s?.id == party) return PartyJoinStatus.ok;
    if (_s != null) await leave();
    hideBanner();
    final (status, info) = await client.joinParty(party);
    if (status != PartyJoinStatus.ok || info == null) return status;
    await _measureClock(force: true);
    final s = await _open(info);
    for (final m in info.members) {
      s.members[m.userId] = m;
    }
    if (_me case final me?) s.members[me.userId] = me;
    s.channel = _partyChannel(info.channelName);
    _invites.removeWhere((i) => i.party == party);
    s.lastBeat = _clock();
    _check = Timer.periodic(checkEvery, (_) => _guestCheck());
    final me = _me;
    unawaited(s.room.send('hello', {
      'by': client.userId,
      if (me != null) 'profile': me.toRow()..['name'] = me.name,
    }).catchError((Object _) {}));
    PlaybackDiagnostics.note('PARTY', 'joined ${info.id} hosted by ${s.members[info.host]?.name ?? info.host}');
    // The state row has the host's latest timeline: playing starts at once.
    if (PartyTimeline.fromJson(info.state) case final tl?) await _onTimeline(tl);
    notifyListeners();
    return PartyJoinStatus.ok;
  }

  Future<_Session> _open(PartyInfo info) async {
    late final _Session s;
    final room = await _client!.openPartyRoom(info.id,
        onMessage: (event, payload) {
          if (identical(_s, s)) _onMessage(event, payload);
        },
        onMember: (user, left) {
          if (identical(_s, s)) _onMember(user, left);
        });
    s = _Session(id: info.id, host: info.host, channelName: info.channelName, room: room);
    _s = s;
    limiter.clear();
    _sync = PartySync.catchingUp;
    _speed = 1;
    _nudgeWorks = true;
    _nudgeSince = null;
    _setLead(initialLead);
    _leadUsed = Duration.zero;
    _moveCost = Duration.zero;
    _landing = false;
    _endHold();
    _lastSeek = null;
    _onScreen = null;
    _catchingUp = true;
    _lastReading = null;
    return s;
  }

  /// A guest's channel for the host's: its name, the party's icon, the
  /// number of the channel left.
  Channel _partyChannel(String hostChannel) {
    final back = _tuner?.channel;
    return Channel(
      id: 'party',
      number: back?.number ?? 0,
      name: tr.partyChannelName(hostChannel),
      icon: const ChannelIcon.builtin('celebration'),
      source: const ChannelSource(includeEpisodes: false),
      order: PlaybackOrder.cyclic,
      playlist: const [],
      anchor: DateTime.fromMillisecondsSinceEpoch(0),
      auto: false,
    );
  }

  // ---- Leaving and ending ---------------------------------------------------------

  /// Leaves: a guest goes back to its own lineup, on [to] or the channel it
  /// had before; the host's leaving ends the party for everyone.
  Future<void> leave({Channel? to}) async {
    final s = _s, client = _client;
    if (s == null) return;
    final host = isHost;
    _endLocally();
    unawaited(s.room.send('bye', {'by': client?.userId, if (host) 'ended': true}).catchError((Object _) {}));
    try {
      await client?.leaveParty(s.id);
    } on Object catch (e) {
      debugPrint('Leave party: $e');
    }
    await s.room.close().catchError((Object _) {});
    await _tuner?.leaveParty(to: to);
    notifyListeners();
  }

  /// The client is about to stop (background, sleep, another profile, sign
  /// out): the party is left, within a few seconds.
  Future<void> leaveBeforeStop() async {
    if (_s == null) return;
    try {
      await leave().timeout(const Duration(seconds: 3));
    } on Object catch (e) {
      debugPrint('Leave party before stop: $e');
    }
  }

  void _endLocally() {
    _stopTimers();
    _s?.ending = true;
    _s = null;
    _pendingBy = null;
    _sync = PartySync.catchingUp;
    _speed = 1;
  }

  /// The party ended (the host left or went quiet): everyone goes back.
  Future<void> _ended({required bool byHost}) async {
    final s = _s;
    if (s == null || s.ending) return;
    final name = s.members[s.host]?.name ?? '';
    _endLocally();
    _toast(byHost ? tr.partyEnded(name) : tr.partyLost);
    PlaybackDiagnostics.note('PARTY', 'ended (${byHost ? 'host' : 'lost'})');
    await s.room.close().catchError((Object _) {});
    await _tuner?.leaveParty();
    notifyListeners();
    unawaited(_loadInvites());
  }

  // ---- Messages ---------------------------------------------------------------------

  void _onMessage(String event, Map<String, dynamic> p) {
    final s = _s;
    if (s == null) return;
    switch (event) {
      case 'timeline':
        if (isHost || p['seq'] is! num) return;
        if (PartyTimeline.fromJson(p) case final tl?) unawaited(_onTimeline(tl));
      case 'action':
        if (isHost && p['by'] is String && p['kind'] is String) {
          PlaybackDiagnostics.note('PARTY', 'action from ${s.members[p['by']]?.name ?? p['by']}: ${p['kind']}'
              '${p['byMs'] == null ? '' : ' ${p['byMs']} ms'}');
          _hostApply(p['by'] as String, p['kind'] as String, (p['byMs'] as num?)?.toInt() ?? 0);
        }
      case 'reaction':
        final by = p['by'], emoji = p['emoji'];
        if (by is String && emoji is String && partyReactions.contains(emoji) && s.members.containsKey(by)) {
          final shown = limiter.allow(by);
          PlaybackDiagnostics.note('PARTY', 'reaction from ${s.members[by]?.name} $emoji ${shown ? 'shown' : 'ignored (within a second)'}');
          if (shown) _float(by, emoji);
        }
      case 'hello':
        final by = p['by'];
        if (by is! String) return;
        final profile = p['profile'];
        final known = s.members.containsKey(by);
        if (profile is Map) {
          try {
            s.members[by] = ShareProfile.fromJson({...Map<String, dynamic>.from(profile), 'user_id': by});
          } on Object {
            // A profile this version can't read: the member row brings it.
          }
        }
        if (!s.members.containsKey(by)) unawaited(_refreshMembers());
        if (!known && s.members.containsKey(by)) _toast(tr.partyJoined(s.members[by]!.name));
        // A newcomer gets the timeline at once.
        if (isHost && s.timeline != null) unawaited(_send(s.timeline!));
        notifyListeners();
      case 'bye':
        final by = p['by'];
        if (by == s.host || p['ended'] == true) {
          unawaited(_ended(byHost: true));
          return;
        }
        if (by is String) _memberLeft(by);
    }
  }

  void _onMember(String user, bool left) {
    final s = _s;
    if (s == null) return;
    if (left) {
      if (user == s.host || user == _client?.userId) {
        unawaited(_ended(byHost: true));
      } else {
        _memberLeft(user);
      }
    } else if (!s.members.containsKey(user)) {
      unawaited(_refreshMembers(announce: true));
    }
  }

  void _memberLeft(String user) {
    final s = _s;
    final gone = s?.members.remove(user);
    if (gone == null) return;
    _toast(tr.partyLeft(gone.name));
    notifyListeners();
  }

  Future<void> _refreshMembers({bool announce = false}) async {
    final s = _s, client = _client;
    if (s == null || client == null) return;
    try {
      final list = await client.partyMembers(s.id);
      if (!identical(_s, s)) return;
      for (final m in list) {
        if (!s.members.containsKey(m.userId)) {
          s.members[m.userId] = m;
          if (announce && m.userId != client.userId) _toast(tr.partyJoined(m.name));
        }
      }
      notifyListeners();
    } on Object catch (e) {
      debugPrint('Party members: $e');
    }
  }

  void _toast(String message) {
    if (!_toasts.isClosed) _toasts.add(message);
  }

  void _float(String by, String emoji) {
    if (_reactions.isClosed) return;
    _reactions.add(FloatingReaction(id: _reactionIds++, emoji: emoji, from: _s?.members[by], at: _clock()));
  }

  /// "Sam paused" and so on.
  String _didText(String name, String kind) => switch (kind) {
        'pause' => tr.partyPaused(name),
        'resume' => tr.partyResumed(name),
        'restart' => tr.partyRestarted(name),
        'live' => tr.partyWentLive(name),
        _ => tr.partySkipped(name),
      };

  // ---- Reactions and transport (every member) ------------------------------------

  /// Sends [emoji] to everyone (one per second; extra presses are ignored).
  bool react(String emoji) {
    final s = _s, me = _client?.userId;
    if (s == null || me == null || !partyReactions.contains(emoji)) return false;
    if (!limiter.allow(me)) {
      PlaybackDiagnostics.note('PARTY', 'reaction $emoji not sent (within a second)');
      return false;
    }
    PlaybackDiagnostics.note('PARTY', 'reaction $emoji sent');
    _float(me, emoji);
    unawaited(s.room.send('reaction', {'by': me, 'emoji': emoji}).catchError((Object e) {
      debugPrint('Reaction: $e');
    }));
    return true;
  }

  /// Pause, resume, skip ([by] forward or back), restart or Live for the
  /// whole party (D4): the host applies it, a guest asks the host.
  void act(String kind, {Duration by = Duration.zero}) {
    final s = _s, me = _client?.userId;
    if (s == null || me == null) return;
    if (isHost) {
      _hostApply(me, kind, by.inMilliseconds);
      return;
    }
    PlaybackDiagnostics.note('PARTY', 'action sent: $kind${kind == 'skip' ? ' ${by.inMilliseconds} ms' : ''}');
    unawaited(s.room.send('action', {'by': me, 'kind': kind, if (kind == 'skip') 'byMs': by.inMilliseconds}).catchError((Object e) {
      debugPrint('Party action: $e');
    }));
  }

  /// Toggles pause for the party: by the host's state, as the guest last saw it.
  void togglePause() {
    final tl = _s?.timeline;
    final paused = isHost ? (_tuner?.paused ?? false) : (tl != null && !tl.playing);
    act(paused ? 'resume' : 'pause');
  }

  // ---- The host ---------------------------------------------------------------------

  PartyTimeline? _hostTimeline() {
    final tuner = _tuner, app = _app;
    if (tuner == null || app == null) return null;
    final schedule = tuner.schedule, program = tuner.program, segment = tuner.segment;
    if (schedule == null || program == null || segment == null) return null;
    return hostTimeline(
      schedule: schedule,
      program: program,
      segment: segment,
      view: tuner.viewNow(),
      wall: _clock(),
      paused: tuner.paused,
      offset: _offset,
      library: app.library,
    );
  }

  void _tunerChanged() {
    final s = _s, tuner = _tuner;
    if (s == null || tuner == null || s.ending) return;
    if (isHost) {
      // The host tuned away from the party's channel (the phone remote):
      // the party ends.
      if (tuner.channel == null || tuner.channel!.displayName != s.channelName) {
        unawaited(leave());
        return;
      }
      _hostCheck();
    } else if (s.timeline != null && !tuner.partyGuest && tuner.channel != null) {
      // Something tuned a channel: the guest has left.
      unawaited(leave());
    }
  }

  /// Publishes the timeline when it changed (D1).
  void _hostCheck() {
    final s = _s, tuner = _tuner;
    if (s == null || !isHost || tuner == null || s.ending) return;
    // A skip under way publishes once it lands.
    if (tuner.seekTarget != null) return;
    final tl = _hostTimeline();
    if (tl == null) return;
    final by = _pendingUntil != null && _clock().isBefore(_pendingUntil!) ? _pendingBy : null;
    if (tl.sameAs(s.timeline) && by == null) return;
    _pendingBy = null;
    _pendingTimer?.cancel();
    _publish(tl, by: by);
  }

  void _publish(PartyTimeline tl, {PartyBy? by}) {
    final s = _s;
    if (s == null) return;
    final out = tl.copyWith(seq: ++s.seq, by: () => by, sentMs: backendNow());
    s.timeline = out;
    PlaybackDiagnostics.note('PARTY', 'timeline sent seq=${out.seq} item="${out.title}" '
        'position=${_secs(out.positionAt(backendNow()))}s ${out.playing ? 'playing' : 'paused'}'
        '${out.brk == null ? '' : ' break=${_secs(Duration(milliseconds: out.brk!.startMs - out.anchorMs))}s+${out.brk!.lengthMs ~/ 1000}s'}'
        '${by == null ? '' : ' by=${by.user}:${by.kind}'}');
    unawaited(_send(out));
    unawaited(_writeState());
    notifyListeners();
  }

  Future<void> _send(PartyTimeline tl) async {
    try {
      await _s?.room.sendTimeline(tl.copyWith(sentMs: backendNow()).toJson());
    } on Object catch (e) {
      debugPrint('Party timeline: $e');
    }
  }

  void _heartbeat() {
    final tl = _s?.timeline;
    if (tl != null && isHost) unawaited(_send(tl));
  }

  /// The state row: on change, at most every 5 seconds, and every
  /// [stateEvery] regardless.
  Future<void> _writeState({bool force = false}) async {
    final s = _s, client = _client, tl = _s?.timeline;
    if (s == null || client == null || tl == null || !isHost) return;
    final at = _stateWrittenAt;
    if (!force && at != null && _clock().difference(at) < const Duration(seconds: 5)) {
      if (!_stateWriteDue) {
        _stateWriteDue = true;
        Timer(const Duration(seconds: 5) - _clock().difference(at), () {
          _stateWriteDue = false;
          unawaited(_writeState());
        });
      }
      return;
    }
    _stateWrittenAt = _clock();
    try {
      await client.writePartyState(s.id, tl.toJson());
    } on Object catch (e) {
      debugPrint('Party state: $e');
    }
  }

  /// A member's action on the host's tuner (D4), in the order received.
  void _hostApply(String user, String kind, int byMs) {
    final s = _s, tuner = _tuner;
    if (s == null || tuner == null) return;
    final shown = kind == 'skip' ? (byMs < 0 ? 'back' : 'forward') : kind;
    _pendingBy = (user: user, kind: shown);
    _pendingUntil = _clock().add(const Duration(seconds: 3));
    switch (kind) {
      case 'pause':
        unawaited(tuner.pause());
      case 'resume':
        unawaited(tuner.resume());
      case 'skip':
        tuner.skip(Duration(milliseconds: byMs));
      case 'restart':
        unawaited(tuner.restart());
      case 'live':
        unawaited(tuner.goLive());
      default:
        _pendingBy = null;
        return;
    }
    _toast(_didText(s.members[user]?.name ?? '', shown));
    // An action that changed nothing (already paused, at the live point)
    // still tells everyone.
    _pendingTimer?.cancel();
    _pendingTimer = Timer(Tuner.seekDebounce + const Duration(milliseconds: 800), () {
      final by = _pendingBy, tl = _s?.timeline;
      if (by == null || tl == null) return;
      _pendingBy = null;
      _publish(_hostTimeline() ?? tl, by: by);
    });
  }

  // ---- A guest ----------------------------------------------------------------------

  RecipeMatcher _matcherFor(LibraryIndex library) {
    if (!identical(_matcherOf, library)) {
      _matcherOf = library;
      _matcher = RecipeMatcher(library);
    }
    return _matcher!;
  }

  MediaEntry? _match(PartyItem? item) {
    final app = _app;
    if (item == null || app == null) return null;
    final id = item.matchIn(_matcherFor(app.library));
    return id == null ? null : app.library[id];
  }

  Future<void> _onTimeline(PartyTimeline tl) async {
    final s = _s, tuner = _tuner, app = _app;
    if (s == null || tuner == null || app == null || isHost) return;
    s.lastBeat = _clock();
    final last = s.timeline;
    if (last != null && tl.seq <= last.seq) return;
    s.timeline = tl;
    final by = tl.by;
    if (by != null && last != null && by.user != _client?.userId) {
      _toast(_didText(s.members[by.user]?.name ?? '', by.kind));
    } else if (by != null && last != null) {
      _toast(_didText(_me?.name ?? '', by.kind));
    }
    final item = _match(tl.item), next = _match(tl.next);
    final ch = s.channel ??= _partyChannel(s.channelName);
    final schedule = PartySchedule(
      anchor: _local(tl.anchorMs),
      item: item,
      title: tl.title,
      hostRuntime: tl.item?.runtime ?? Duration.zero,
      breakStart: tl.brk == null ? null : _local(tl.brk!.startMs),
      breakLength: Duration(milliseconds: tl.brk?.lengthMs ?? 0),
      nextItem: next,
      nextTitle: tl.next?.title,
      nextHostRuntime: tl.next?.runtime ?? Duration.zero,
      clips: app.catalog,
      roles: app.planFor(ch).roles,
      seed: s.id.hashCode,
    );
    PlaybackDiagnostics.note('PARTY', 'timeline received seq=${tl.seq} item="${tl.title}"'
        '${tl.item != null && item == null ? ' (not on this library)' : ''} '
        'target=${_secs(tl.positionAt(backendNow()))}s ${tl.playing ? 'playing' : 'paused'}'
        '${tl.brk == null ? '' : ' break=${_secs(Duration(milliseconds: tl.brk!.startMs - tl.anchorMs))}s+${tl.brk!.lengthMs ~/ 1000}s'}'
        '${by == null ? '' : ' by=${by.kind}'} late=${backendNow() - tl.sentMs}ms');
    // A change (an action, the next program) ends a hold: the picture goes
    // where the new timeline says.
    if (_holding) {
      _endHold();
      await tuner.partyHold(false);
    }
    await tuner.followParty(ch, schedule, frozenAt: tl.playing ? null : _local(tl.pausedAt!));
    // A skip or a restart is corrected now, not at the next check.
    if (identical(_s, s)) _correct(tuner);
    notifyListeners();
  }

  /// Every [checkEvery]: the host still there, and drift corrected (D3).
  void _guestCheck() {
    final s = _s, tuner = _tuner;
    if (s == null || tuner == null || isHost || s.ending) return;
    if (_clock().difference(s.lastBeat) > hostGoneAfter) {
      unawaited(_hostGone());
      return;
    }
    // Every few minutes the clock is measured again.
    if (_measuredAt != null && _clock().difference(_measuredAt!) >= clockEvery) unawaited(_measureClock());
    final before = _sync;
    _correct(tuner);
    if (_sync != before) notifyListeners();
  }

  void _correct(Tuner tuner) {
    if (tuner.partyMissing case final t? when t.isNotEmpty) {
      _sync = PartySync.missing;
      _setSpeed(tuner, 1);
      return;
    }
    if (_holding) {
      _sync = PartySync.catchingUp;
      return;
    }
    final seg = tuner.segment;
    if (seg == null || seg.isBreak || seg.item == null || tuner.paused || !tuner.pictured) {
      _setSpeed(tuner, 1);
      _nudgeSince = null;
      _sync = tuner.paused || (seg != null && seg.isBreak && tuner.pictured) ? PartySync.inSync : PartySync.catchingUp;
      return;
    }
    final now = _clock();
    final target = seg.positionAt(tuner.viewNow());
    final actual = tuner.itemPosition;
    final drift = actual - target;
    final size = drift.abs();
    // A new piece on screen (an open, a hand-over): catching up again.
    // An open's landing is judged like a seek's, by how far ahead it opened
    // (a resume or a hand-over moves nothing).
    if (!identical(seg, _onScreen)) {
      _onScreen = seg;
      _catchingUp = true;
      if (tuner.partyOpens != _opensSeen) {
        _opensSeen = tuner.partyOpens;
        _landing = true;
        _lastSeek = now.subtract(_landAfter);
        _leadUsed = tuner.partyOpenedAhead;
        _lastReading = null;
      }
    }
    // Playing, not stalled: the picture moved about as far as the clock.
    final last = _lastReading;
    final moving = last != null &&
        actual - last.position >= (now.difference(last.at) * 0.6) &&
        actual - last.position <= now.difference(last.at) * 1.6;
    _lastReading = (position: actual, at: now);
    final seeked = _lastSeek;
    if (_landing && seeked != null) {
      // A seek under way: once the picture moves again, how far it fell
      // behind tells how far ahead the next one aims. Players report the
      // seek's target while they buffer, so it's judged only when moving.
      final waited = now.difference(seeked);
      if (waited < _landAfter || (!moving && waited < _landWithin)) {
        _sync = PartySync.catchingUp;
        return;
      }
      _landing = false;
      // A picture that never moved again says nothing about the move.
      if (moving && size < _maxLead) {
        // What the move cost: how far behind it would have landed aiming
        // at the target.
        // A move's cost varies on a busy link, and landing behind costs a
        // whole move more than holding: the lead comes down slowly.
        final lost = _leadUsed - drift;
        final decayed = _moveCost * _costDecay;
        _moveCost = lost > decayed ? lost : decayed;
        _setLead(_moveCost + _leadMargin);
        PlaybackDiagnostics.note('PARTY', 'landed drift=${drift.inMilliseconds}ms; lead now ${_seekLead.inMilliseconds}ms');
      }
    }
    // Ahead, where a nudge won't do (catching up, over 2 s, or a player that
    // can't change speed): the picture waits for the host, exactly.
    if (drift > nudgeAbove &&
        drift <= _maxHold &&
        (_catchingUp || size > seekAbove || !_nudgeWorks || !tuner.canNudgeSpeed)) {
      _hold(tuner, drift);
      PlaybackDiagnostics.note('PARTY', 'sync target=${_secs(target)}s player=${_secs(actual)}s '
          'drift=${drift.inMilliseconds}ms speed=${_speed.toStringAsFixed(2)}');
      return;
    }
    if (size <= const Duration(seconds: 1)) _catchingUp = false;
    if (moving && (size > seekAbove || (_catchingUp && size > const Duration(seconds: 1)))) {
      // Over 2 s, or still catching up after an open or a seek: a seek.
      // Never while the picture stands still: a buffering player reports
      // where it's going, and another seek only starts the wait again.
      _seek(tuner, target);
    } else if (size > nudgeAbove || (_speed != 1 && size > nudgedWithin)) {
      if (_nudgeWorks && tuner.canNudgeSpeed) {
        // A stall makes the drift grow whatever the speed: the nudge is
        // judged from the largest drift since.
        if (_nudgeSince == null || size > _nudgeFrom) {
          _nudgeSince = now;
          _nudgeFrom = size;
        } else if (now.difference(_nudgeSince!) > nudgeGivesUp && size > _nudgeFrom - const Duration(milliseconds: 100)) {
          // The speed didn't take (passthrough audio): seek-only from now.
          _nudgeWorks = false;
          PlaybackDiagnostics.note('PARTY', 'speed nudge has no effect; correcting by seeking');
        }
        _setSpeed(tuner, drift.isNegative ? 1 + nudge : 1 - nudge);
      }
      if (!_nudgeWorks || !tuner.canNudgeSpeed) {
        _setSpeed(tuner, 1);
        final last = _lastSeek;
        if (size > const Duration(milliseconds: 500) &&
            (last == null || _clock().difference(last) > const Duration(seconds: 10))) {
          _seek(tuner, target);
        }
      }
    } else {
      _setSpeed(tuner, 1);
      _nudgeSince = null;
    }
    _sync = size > const Duration(seconds: 1) ? PartySync.catchingUp : PartySync.inSync;
    PlaybackDiagnostics.note('PARTY', 'sync target=${_secs(target)}s player=${_secs(actual)}s '
        'drift=${drift.inMilliseconds}ms speed=${_speed.toStringAsFixed(2)}');
  }

  void _seek(Tuner tuner, Duration target) {
    _lastSeek = _clock();
    _landing = true;
    _leadUsed = _seekLead;
    _nudgeSince = null;
    _setSpeed(tuner, 1);
    unawaited(tuner.partySeek(target + _seekLead));
  }

  void _setLead(Duration lead) {
    _seekLead = lead > _maxLead ? _maxLead : lead;
    _tuner?.partyLead = _seekLead;
  }

  /// Holds the picture for [ahead]: the host's position gets there.
  void _hold(Tuner tuner, Duration ahead) {
    _endHold();
    _holding = true;
    _sync = PartySync.catchingUp;
    _setSpeed(tuner, 1);
    _nudgeSince = null;
    unawaited(tuner.partyHold(true));
    _holdTimer = Timer(ahead, () {
      if (!_holding) return;
      _endHold();
      unawaited(tuner.partyHold(false));
    });
  }

  /// Ends a hold without touching the player (a timeline or a leave moves
  /// it anyway); the timer's own end resumes it.
  void _endHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holding = false;
    _lastReading = null;
  }

  void _setSpeed(Tuner tuner, double speed) {
    if (_speed == speed) return;
    _speed = speed;
    unawaited(tuner.setPartySpeed(speed).catchError((Object _) {}));
  }

  Future<void> _hostGone() async {
    final s = _s, client = _client;
    if (s == null || s.ending) return;
    PlaybackDiagnostics.note('PARTY', 'no word from the host for ${hostGoneAfter.inSeconds} s');
    var ended = false;
    try {
      ended = await client?.leaveParty(s.id, hostGone: true) ?? false;
    } on Object catch (e) {
      debugPrint('Party host gone: $e');
    }
    await _ended(byHost: ended);
  }

  @visibleForTesting
  double get debugSpeed => _speed;

  @visibleForTesting
  bool get debugNudgeWorks => _nudgeWorks;

  @visibleForTesting
  Duration get debugLead => _seekLead;

  @visibleForTesting
  bool get debugHolding => _holding;

  @visibleForTesting
  void debugCheck() => isHost ? _hostCheck() : _guestCheck();
}

String _secs(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(3);
