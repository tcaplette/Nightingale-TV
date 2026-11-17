import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import 'presence.dart';
import 'share_session_store.dart';
import 'watch_party.dart';

/// A share profile (share-accounts, "Share profile"). Never holds an email.
@immutable
class ShareProfile {
  const ShareProfile({
    required this.userId,
    required this.name,
    required this.handle,
    this.avatar = 'fox',
    this.avatarColor = 0,
    this.station = '',
    this.presence,
  });

  final String userId;
  final String name;
  final String handle;

  /// A built-in avatar's id (lib/icons/avatars).
  final String avatar;

  /// An index into the avatar palette.
  final int avatarColor;
  final String station;

  /// Show what I'm watching (friend-presence D4): `friends`, `off`, or null
  /// before it was asked. Saved with [ShareClient.setPresence], never by
  /// [toRow].
  final String? presence;

  static const nameMax = 30;
  static const stationMax = 30;
  static final handlePattern = RegExp(r'^[a-z0-9_]{3,20}$');

  /// [input] as a handle: lower case, without a leading @.
  static String cleanHandle(String input) => input.trim().replaceFirst(RegExp('^@'), '').toLowerCase();

  static ShareProfile fromJson(Map<String, dynamic> j) => ShareProfile(
        userId: j['user_id'] as String,
        name: (j['display_name'] ?? j['name']) as String,
        handle: j['handle'] as String,
        avatar: j['avatar'] as String? ?? 'fox',
        avatarColor: (j['avatar_color'] as num?)?.toInt() ?? 0,
        station: j['station'] as String? ?? '',
        presence: j['presence'] as String?,
      );

  Map<String, Object?> toRow() => {
        'user_id': userId,
        'display_name': name,
        'handle': handle,
        'avatar': avatar,
        'avatar_color': avatarColor,
        'station': station,
      };

  /// This profile with Show what I'm watching set to [value].
  ShareProfile withPresence(String value) => ShareProfile(
      userId: userId, name: name, handle: handle, avatar: avatar, avatarColor: avatarColor, station: station, presence: value);

  ShareProfile copyWith({String? name, String? handle, String? avatar, int? avatarColor, String? station}) =>
      ShareProfile(
        userId: userId,
        name: name ?? this.name,
        handle: handle ?? this.handle,
        avatar: avatar ?? this.avatar,
        avatarColor: avatarColor ?? this.avatarColor,
        station: station ?? this.station,
        presence: presence,
      );
}

/// The live friend code on show in Add friend.
@immutable
class FriendInvite {
  const FriendInvite(this.code, this.expiresAt);

  final String code;
  final DateTime expiresAt;
}

/// What a code turned out to be.
enum InviteStatus {
  ok,

  /// "That's your own code"
  own,

  /// Unknown, used, expired, or blocked either way: "This invite has
  /// expired or was already used" (blocks are never revealed).
  gone,

  /// 10 failed tries in an hour: "Too many tries. Try again later"
  limited,
}

@immutable
class InviteResult {
  const InviteResult(this.status, [this.from, this.kind = 'friend', this.channels = const [], this.party, this.showTitle]);

  final InviteStatus status;

  /// The code's owner (peek) or the new friend (redeem), when [status] is ok.
  final ShareProfile? from;

  /// `friend`, or `channels` for a link that also delivers channels
  /// (channel-sharing).
  final String kind;

  /// A `channels` invite's channel names (peek), in the sender's order.
  final List<String> channels;

  /// A `watch` invite's party and its program's title (watch-together).
  final String? party;
  final String? showTitle;
}

/// A channel shared with this account (channel-sharing): its share row,
/// without the recipe.
@immutable
class IncomingShare {
  const IncomingShare({
    required this.id,
    required this.sharedChannelId,
    required this.state,
    required this.ended,
    required this.name,
    required this.version,
    required this.from,
    required this.createdAt,
  });

  final String id;
  final String sharedChannelId;

  /// `new`, `added` or `declined`.
  final String state;
  final bool ended;
  final String name;
  final int version;
  final ShareProfile? from;
  final DateTime createdAt;

  /// Waiting in Shared with you.
  bool get waiting => state == 'new' && !ended;

  static IncomingShare fromJson(Map<String, dynamic> j) => IncomingShare(
        id: j['id'] as String,
        sharedChannelId: j['shared_channel_id'] as String,
        state: j['state'] as String? ?? 'new',
        ended: j['ended_at'] != null,
        name: j['name'] as String? ?? '',
        version: (j['version'] as num?)?.toInt() ?? 1,
        from: j['from'] is Map ? ShareProfile.fromJson(Map<String, dynamic>.from(j['from'] as Map)) : null,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// A channel this account shares, with who has it.
@immutable
class OutgoingShare {
  const OutgoingShare({required this.id, required this.name, required this.version, required this.stopped, required this.receivers});

  final String id;
  final String name;
  final int version;
  final bool stopped;

  /// The receivers whose shares are active.
  final List<String> receivers;
}

/// What share-channels answered: each channel's version, and for a link
/// its invite.
@immutable
class SharedChannels {
  const SharedChannels(this.versions, [this.invite]);

  final Map<String, int> versions;
  final FriendInvite? invite;
}

/// A recipe to publish: the shared channel's stable id, its name and the
/// recipe's JSON.
typedef RecipeUpload = ({String id, String name, Map<String, Object?> recipe});

/// share-channels refused: the receivers aren't all friends, or the
/// recipes were too big.
class ShareRefused implements Exception {
  const ShareRefused(this.status);

  final String status;
}

@immutable
class FriendsList {
  const FriendsList(this.friends, this.blocked);

  /// Sorted by name.
  final List<ShareProfile> friends;
  final List<ShareProfile> blocked;
}

/// The backend can't be reached (or answered with a server error): "Sharing
/// is unavailable right now". Never blocks TV use.
class ShareUnavailable implements Exception {
  const ShareUnavailable([this.cause]);

  final Object? cause;

  @override
  String toString() => 'ShareUnavailable($cause)';
}

/// The handle belongs to another account: "That handle is taken."
class HandleTaken implements Exception {
  const HandleTaken();
}

/// The profile's sign-in was rejected (the account was deleted or signed out
/// everywhere): the Sharing screen asks to set up again.
class ShareSignedOut implements Exception {
  const ShareSignedOut();
}

enum CodeCheck { ok, wrong, newCodeNeeded }

/// The email-code step's rules (share-accounts, "Setting up sharing"):
/// "Send a new code" after 60 seconds, a new code after 5 wrong ones.
class SignInAttempt {
  SignInAttempt(this.email, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const resendAfter = Duration(seconds: 60);
  static const maxWrong = 5;

  final String email;
  final DateTime Function() _clock;
  DateTime? _sentAt;
  int _wrong = 0;

  int get wrong => _wrong;
  bool get needsNewCode => _wrong >= maxWrong;

  void sent() {
    _sentAt = _clock();
    _wrong = 0;
  }

  /// How long until "Send a new code" is available (zero when it is).
  Duration get resendIn {
    final at = _sentAt;
    if (at == null) return Duration.zero;
    final left = resendAfter - _clock().difference(at);
    return left.isNegative ? Duration.zero : left;
  }

  bool get canResend => resendIn == Duration.zero;

  CodeCheck wrongCode() {
    _wrong++;
    return needsNewCode ? CodeCheck.newCodeNeeded : CodeCheck.wrong;
  }

  /// A plausible email address: something@something.something.
  static bool looksLikeEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());
}

/// One profile's share account (share-accounts D1, D4): the only place in
/// the app that talks to the sharing backend.
///
/// It sends nothing until [start]: the profile is in front, the app is
/// shown and awake. [stop] (hidden, asleep, another profile) stops even the
/// token refresh. Every request is something the user asked for on the
/// Sharing screen, apart from refreshing the sign-in while started.
class ShareClient implements PresenceBackend, PartyBackend {
  ShareClient({
    required this.profileId,
    required this._store,
    required String url,
    required String key,
    http.Client? httpClient,
  }) : _sb = SupabaseClient(url, key,
            httpClient: httpClient,
            authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit)) {
    // Not refreshing until started.
    _sb.auth.stopAutoRefresh();
    _authEvents = _sb.auth.onAuthStateChange.listen(_onAuth, onError: (Object _) {});
  }

  final String profileId;
  final ShareSessionStore _store;
  final SupabaseClient _sb;
  late final StreamSubscription<AuthState> _authEvents;

  bool _started = false;
  bool _recovered = false;
  bool _disposed = false;

  /// Linked to a share account on this device.
  final linked = ValueNotifier(false);

  /// The backend couldn't be reached the last time it was asked.
  final unavailable = ValueNotifier(false);

  /// Called when this profile has just been linked (signed in with a
  /// code), not when a saved sign-in is restored.
  void Function()? onLinked;

  @override
  bool get started => _started;

  String? get email => _store[profileId]?.email;
  @override
  String? get userId => _store[profileId]?.userId;

  /// Starts: restores the sign-in (a request only when it has to be
  /// refreshed) and the background refresh. Nothing for an unlinked profile.
  Future<void> start() {
    // A second caller while the sign-in is being restored waits for it, so
    // nothing is sent without the token.
    if (_started || _disposed) return _starting ?? Future.value();
    return _starting = _start().whenComplete(() => _starting = null);
  }

  Future<void>? _starting;

  Future<void> _start() async {
    _started = true;
    final saved = _store[profileId];
    linked.value = saved != null;
    if (saved == null) return;
    if (!_recovered) {
      try {
        await _sb.auth.recoverSession(saved.session);
        _recovered = true;
        unavailable.value = false;
      } on AuthRetryableFetchException catch (e) {
        // Offline: keep the sign-in and try again on the next start.
        unavailable.value = true;
        debugPrint('Sharing unavailable: $e');
      } on AuthException catch (e) {
        if (_disposed) return;
        if (_isSignInRejected(e)) {
          // Rejected: the account was deleted or signed out everywhere.
          debugPrint('Sharing sign-in rejected: $e');
          await _forget();
        } else {
          unavailable.value = true;
          debugPrint('Sharing unavailable: $e');
        }
      } on Object catch (e) {
        if (_disposed) return;
        unavailable.value = true;
        debugPrint('Sharing unavailable: $e');
      }
    }
    if (_started && linked.value) _sb.auth.startAutoRefresh();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _sb.auth.stopAutoRefresh();
    // No socket while hidden or asleep (friend-presence D6).
    unawaited(_closeRealtime());
  }

  Future<void> _closeRealtime() async {
    await stopWatchingRows();
    await stopWatchingPartyInvites();
    for (final room in _rooms.toList()) {
      await room.close();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    stop();
    await _authEvents.cancel();
    await _sb.dispose();
    linked.dispose();
    unavailable.dispose();
  }

  void _onAuth(AuthState state) {
    if (_disposed) return;
    final session = state.session;
    switch (state.event) {
      case AuthChangeEvent.signedIn || AuthChangeEvent.tokenRefreshed || AuthChangeEvent.userUpdated:
        if (session == null) return;
        unawaited(_store.put(
            profileId,
            ShareSignIn(
              session: jsonEncode(session.toJson()),
              userId: session.user.id,
              email: session.user.email ?? _store[profileId]?.email ?? '',
            )));
        linked.value = true;
      case AuthChangeEvent.signedOut:
        unawaited(_store.remove(profileId));
        linked.value = false;
      default:
    }
  }

  Future<void> _forget() async {
    if (_disposed) return;
    _recovered = false;
    _sb.auth.stopAutoRefresh();
    await _store.remove(profileId);
    linked.value = false;
  }

  /// Runs [request] while started, turning failures into the app's own
  /// exceptions.
  Future<T> _call<T>(Future<T> Function() request) async {
    if (!_started) throw StateError('Sharing is stopped');
    try {
      final result = await request();
      unavailable.value = false;
      return result;
    } on AuthRetryableFetchException catch (e) {
      unavailable.value = true;
      throw ShareUnavailable(e);
    } on SocketException catch (e) {
      unavailable.value = true;
      throw ShareUnavailable(e);
    } on http.ClientException catch (e) {
      unavailable.value = true;
      throw ShareUnavailable(e);
    } on TimeoutException catch (e) {
      unavailable.value = true;
      throw ShareUnavailable(e);
    } on FunctionException catch (e) {
      if (e.status == 401) {
        await _forget();
        throw const ShareSignedOut();
      }
      unavailable.value = true;
      throw ShareUnavailable(e);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' || e.code == '401') {
        await _forget();
        throw const ShareSignedOut();
      }
      rethrow;
    } on AuthException catch (e) {
      if (_isSignInRejected(e)) {
        await _forget();
        throw const ShareSignedOut();
      }
      rethrow;
    }
  }

  /// The backend turned the sign-in down (not a network or server failure).
  static bool _isSignInRejected(AuthException e) =>
      e is AuthSessionMissingException ||
      {'refresh_token_not_found', 'refresh_token_already_used', 'session_not_found', 'session_expired', 'user_not_found',
              'bad_jwt'}
          .contains(e.code) ||
      (e is AuthApiException && (e.statusCode == '400' || e.statusCode == '401' || e.statusCode == '403'));

  Future<Map<String, dynamic>> _fn(String name, [Map<String, Object?> body = const {}]) async {
    // A fresh token first: the functions client sends the one it has.
    await _sb.auth.getSession();
    final r = await _sb.functions.invoke(name, body: body);
    final data = r.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) return Map<String, dynamic>.from(jsonDecode(data) as Map);
    throw ShareUnavailable('unexpected $name answer');
  }

  // ---- Signing in ---------------------------------------------------------

  /// Sends a 6-digit code to [email], making the account on first use.
  Future<void> sendCode(String email) => _call(() => _sb.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true));

  /// Signs in with [code]: true when it was right.
  Future<bool> verifyCode(String email, String code) => _call(() async {
        try {
          final r = await _sb.auth.verifyOTP(type: OtpType.email, email: email.trim(), token: code.trim());
          if (r.session == null) return false;
          _recovered = true;
          // The auth event saves it too; this makes it certain before the
          // next screen reads it.
          await _store.put(
              profileId,
              ShareSignIn(
                  session: jsonEncode(r.session!.toJson()),
                  userId: r.session!.user.id,
                  email: r.session!.user.email ?? email.trim()));
          linked.value = true;
          if (_started) _sb.auth.startAutoRefresh();
          onLinked?.call();
          return true;
        } on AuthApiException catch (e) {
          if (e.code == 'otp_expired' || e.code == 'validation_failed' || e.statusCode == '403') return false;
          rethrow;
        }
      });

  /// Unlinks this profile on this device only.
  Future<void> signOut() async {
    try {
      if (_started) await _sb.auth.signOut(scope: SignOutScope.local);
    } on Object catch (e) {
      // Signing out here still works offline.
      debugPrint('Sharing sign-out: $e');
    }
    await _forget();
  }

  /// Deletes the share account and everything stored for it, everywhere.
  Future<void> deleteAccount() async {
    final r = await _call(() => _fn('delete-account'));
    if (r['status'] != 'ok') throw ShareUnavailable('delete-account: $r');
    await _forget();
  }

  // ---- Share profile ------------------------------------------------------

  /// This account's share profile; null before it's made.
  @override
  Future<ShareProfile?> profile() => _call(() async {
        final rows = await _sb.from('share_profiles').select().eq('user_id', _uid);
        return rows.isEmpty ? null : ShareProfile.fromJson(rows.first);
      });

  String get _uid => _sb.auth.currentUser?.id ?? userId ?? (throw const ShareSignedOut());

  /// Whether [handle] is free (or already this account's).
  Future<bool> handleAvailable(String handle) =>
      _call(() async => await _sb.rpc('handle_available', params: {'p_handle': handle}) == true);

  /// Makes or updates the share profile; [HandleTaken] when the handle is
  /// another account's.
  Future<ShareProfile> saveProfile(ShareProfile p) => _call(() async {
        try {
          final row = await _sb.from('share_profiles').upsert(p.copyWith().toRow()..['user_id'] = _uid).select().single();
          return ShareProfile.fromJson(row);
        } on PostgrestException catch (e) {
          if (e.code == '23505') throw const HandleTaken();
          rethrow;
        }
      });

  // ---- Invites ------------------------------------------------------------

  /// The live friend code; a new one when there's none, or with [fresh]
  /// ("New code", which ends the old one at once).
  Future<FriendInvite> friendInvite({bool fresh = false}) => _call(() async {
        if (!fresh) {
          final live = await _sb
              .from('invites')
              .select('code, expires_at')
              .eq('owner', _uid)
              .eq('kind', 'friend')
              .isFilter('used_at', null)
              .gt('expires_at', DateTime.now().toUtc().toIso8601String())
              .order('created_at', ascending: false)
              .limit(1);
          if (live.isNotEmpty) {
            return FriendInvite(live.first['code'] as String, DateTime.parse(live.first['expires_at'] as String));
          }
        }
        final r = await _fn('make-invite');
        if (r['status'] != 'ok') throw ShareUnavailable('make-invite: $r');
        return FriendInvite(r['code'] as String, DateTime.parse(r['expires_at'] as String));
      });

  static InviteStatus _status(Object? s) => switch (s) {
        'ok' => InviteStatus.ok,
        'own' => InviteStatus.own,
        'limited' => InviteStatus.limited,
        _ => InviteStatus.gone,
      };

  /// Whose [code] it is, without using it.
  Future<InviteResult> peek(String code) => _call(() async {
        final r = await _fn('peek-invite', {'code': code});
        final from = r['from'];
        return InviteResult(
          _status(r['status']),
          from is Map ? ShareProfile.fromJson(Map<String, dynamic>.from(from)) : null,
          r['kind'] as String? ?? 'friend',
          [for (final c in r['channels'] as List? ?? const []) if (c is Map && c['name'] is String) c['name'] as String],
          r['party'] as String?,
          (r['show'] as Map?)?['title'] as String?,
        );
      });

  /// Uses [code]: both accounts are friends at once.
  Future<InviteResult> redeem(String code) => _call(() async {
        final r = await _fn('redeem-invite', {'code': code});
        final friend = r['friend'];
        return InviteResult(_status(r['status']),
            friend is Map ? ShareProfile.fromJson(Map<String, dynamic>.from(friend)) : null, r['kind'] as String? ?? 'friend',
            const [], r['party'] as String?, (r['show'] as Map?)?['title'] as String?);
      });

  // ---- Friends ------------------------------------------------------------

  @override
  Future<FriendsList> friends() => _call(() async {
        final me = _uid;
        final pairs = await _sb.from('friendships').select('user_a, user_b');
        final blocks = await _sb.from('blocks').select('blocked');
        final profiles = {
          for (final row in await _sb.from('share_profiles').select()) row['user_id'] as String: ShareProfile.fromJson(row),
        };
        final friendIds = [for (final f in pairs) (f['user_a'] == me ? f['user_b'] : f['user_a']) as String];
        final blockedIds = [for (final b in blocks) b['blocked'] as String];
        int byName(ShareProfile a, ShareProfile b) {
          final n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return n != 0 ? n : a.handle.compareTo(b.handle);
        }

        return FriendsList(
          [for (final id in friendIds) ?profiles[id]]..sort(byName),
          [for (final id in blockedIds) ?profiles[id]]..sort(byName),
        );
      });

  /// Ends the friendship on both sides.
  Future<void> removeFriend(String friendId) => _call(() async {
        final me = _uid;
        final (a, b) = me.compareTo(friendId) < 0 ? (me, friendId) : (friendId, me);
        await _sb.from('friendships').delete().eq('user_a', a).eq('user_b', b);
      });

  /// Blocks [userId], which also ends the friendship.
  Future<void> block(String userId) =>
      _call(() async => _sb.from('blocks').upsert({'blocker': _uid, 'blocked': userId}, ignoreDuplicates: true));

  Future<void> unblock(String userId) =>
      _call(() async => _sb.from('blocks').delete().eq('blocker', _uid).eq('blocked', userId));

  // ---- Channel sharing (channel-sharing) ----------------------------------

  /// A channel call: a database error (not a sign-in one) reads as
  /// "Sharing is unavailable right now", like a network failure.
  Future<T> _channelCall<T>(Future<T> Function() request) => _call(() async {
        try {
          return await request();
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST301' || e.code == '401') rethrow;
          unavailable.value = true;
          throw ShareUnavailable(e);
        }
      });

  /// Publishes [recipes] and shares them with the friends [to], or with
  /// [link] makes a `channels` invite. With neither it only publishes (a
  /// new version for Keep updated).
  Future<SharedChannels> shareChannels(List<RecipeUpload> recipes, {List<String> to = const [], bool link = false}) =>
      _channelCall(() async {
        final r = await _fn('share-channels', {
          'recipes': [for (final x in recipes) {'id': x.id, 'name': x.name, 'recipe': x.recipe}],
          if (to.isNotEmpty) 'to': to,
          if (link) 'link': true,
        });
        if (r['status'] != 'ok') throw ShareRefused('${r['status']}');
        return SharedChannels(
          {
            for (final c in r['channels'] as List? ?? const [])
              if (c is Map) c['id'] as String: (c['version'] as num).toInt(),
          },
          r['code'] is String ? FriendInvite(r['code'] as String, DateTime.parse(r['expires_at'] as String)) : null,
        );
      });

  /// Every share sent to this account, ended ones included, oldest first.
  Future<List<IncomingShare>> channelShares() => _channelCall(() async {
        final rows = await _sb.rpc('my_channel_shares');
        return [for (final r in rows as List? ?? const []) IncomingShare.fromJson(Map<String, dynamic>.from(r as Map))];
      });

  /// A shared channel's recipe JSON and version; null when it can't be read
  /// (the share ended).
  Future<({Map<String, Object?> recipe, int version})?> sharedRecipe(String sharedChannelId) => _channelCall(() async {
        final rows = await _sb.from('shared_channels').select('recipe, version').eq('id', sharedChannelId);
        if (rows.isEmpty) return null;
        return (
          recipe: Map<String, Object?>.from(rows.first['recipe'] as Map),
          version: (rows.first['version'] as num).toInt(),
        );
      });

  /// Add (`added`) or Decline (`declined`) on a share sent to this account.
  Future<void> setShareState(String shareId, String state) =>
      _channelCall(() async => _sb.from('channel_shares').update({'state': state}).eq('id', shareId));

  /// The channels this account shares, with their active receivers' ids.
  Future<List<OutgoingShare>> myShares() => _channelCall(() async {
        final rows = await _sb
            .from('shared_channels')
            .select('id, name, version, stopped_at, channel_shares(recipient, ended_at)')
            .eq('owner', _uid);
        return [
          for (final r in rows)
            OutgoingShare(
              id: r['id'] as String,
              name: r['name'] as String? ?? '',
              version: (r['version'] as num?)?.toInt() ?? 1,
              stopped: r['stopped_at'] != null,
              receivers: [
                for (final s in r['channel_shares'] as List? ?? const [])
                  if (s is Map && s['ended_at'] == null) s['recipient'] as String,
              ],
            ),
        ];
      });

  /// Ends every share of [sharedChannelId]; receivers keep their copies.
  Future<void> stopSharing(String sharedChannelId) => _channelCall(() async => _sb
      .from('shared_channels')
      .update({'stopped_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', sharedChannelId)
      .isFilter('stopped_at', null));

  // ---- Friend presence (friend-presence) ----------------------------------

  /// A presence call: like a channel call, a database error reads as
  /// unavailable.
  Future<T> _presenceCall<T>(Future<T> Function() request) => _channelCall(request);

  /// Show what I'm watching: `friends` or `off`.
  @override
  Future<void> setPresence(String value) =>
      _presenceCall(() async => _sb.from('share_profiles').update({'presence': value}).eq('user_id', _uid));

  /// Publishes what this account is watching; null clears it (D1: cleared,
  /// not deleted, so only friends hear about it).
  @override
  Future<void> setWatching(Watching? w) => _presenceCall(() async => _sb.from('now_watching').upsert({
        'user_id': _uid,
        'title': w?.title,
        'channel_name': w?.channelName,
        'shared_channel_id': w?.sharedChannelId,
        'started_at': w?.startedAt.toUtc().toIso8601String(),
      }));

  /// Every presence row this account may read but its own.
  @override
  Future<List<PresenceRow>> watchingRows() => _presenceCall(() async {
        final rows = await _sb.from('now_watching').select().neq('user_id', _uid);
        return [for (final r in rows) PresenceRow.fromJson(r)];
      });

  /// One reading of the backend's clock, with the request's round trip.
  @override
  Future<({DateTime server, Duration rtt})> serverTime() => _presenceCall(() async {
        await _sb.auth.getSession();
        final sent = DateTime.now();
        final r = await _sb.functions.invoke('server-time', method: HttpMethod.get);
        final rtt = DateTime.now().difference(sent);
        final data = r.data is String ? jsonDecode(r.data as String) : r.data;
        final ms = (data is Map ? data['now'] : null) as num?;
        if (ms == null) throw const ShareUnavailable('unexpected server-time answer');
        return (server: DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true), rtt: rtt);
      });

  RealtimeChannel? _rows;

  /// Tests stand in for Realtime (a WebSocket the fake HTTP backend can't
  /// answer): [debugRealtime] gets the row feed, [debugRealtimeStop] hears
  /// it close.
  @visibleForTesting
  static void Function(void Function(PresenceRow row) onRow, void Function() onReady)? debugRealtime;
  @visibleForTesting
  static void Function()? debugRealtimeStop;
  bool _debugWatching = false;

  /// Follows friends' presence rows over Realtime. [onReady] once changes
  /// flow (a moment after the channel joins), [onError] when it fails.
  @override
  Future<void> watchRows(
      {required void Function(PresenceRow row) onRow,
      required void Function() onReady,
      required void Function(Object error) onError}) async {
    if (!_started) throw StateError('Sharing is stopped');
    await stopWatchingRows();
    if (debugRealtime case final fake?) {
      _debugWatching = true;
      fake((row) {
        if (row.userId != userId) onRow(row);
      }, onReady);
      return;
    }
    // The socket signs in with the current token.
    await _sb.auth.getSession();
    final token = _sb.auth.currentSession?.accessToken;
    if (token != null) await _sb.realtime.setAuth(token);
    var ready = false;
    _rows = _sb
        .channel('now-watching')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'now_watching',
            callback: (p) {
              final row = p.newRecord;
              if (row.isEmpty || row['user_id'] == userId) return;
              try {
                onRow(PresenceRow.fromJson(row));
              } on Object catch (e) {
                debugPrint('Presence row: $e');
              }
            })
        .onSystemEvents((payload) {
          if (ready || payload is! Map || payload['extension'] != 'postgres_changes') return;
          if (payload['status'] == 'ok') {
            ready = true;
            onReady();
          }
        })
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
            onError(error ?? status);
          }
        });
  }

  /// Leaves the presence channel and closes the socket at once.
  @override
  Future<void> stopWatchingRows() async {
    if (_debugWatching) {
      _debugWatching = false;
      debugRealtimeStop?.call();
    }
    final rows = _rows;
    _rows = null;
    if (rows == null) return;
    try {
      // The socket closes with its last channel.
      await _sb.removeChannel(rows);
    } on Object catch (e) {
      debugPrint('Presence socket: $e');
    }
  }

  // ---- Watch together (watch-together) ------------------------------------

  /// A party call: a database error reads as unavailable.
  Future<T> _partyCall<T>(Future<T> Function() request) => _channelCall(request);

  static PartyJoinStatus _joinStatus(Object? s) => switch (s) {
        'ok' => PartyJoinStatus.ok,
        'ended' => PartyJoinStatus.ended,
        'full' => PartyJoinStatus.full,
        _ => PartyJoinStatus.notAllowed,
      };

  static FriendInvite? _inviteOf(Map<String, dynamic> r) =>
      r['code'] is String ? FriendInvite(r['code'] as String, DateTime.parse(r['expires_at'] as String)) : null;

  @override
  Future<PartyStarted> startParty(
          {required String channelName, required Map<String, Object?> state, List<String> invite = const [], bool link = false}) =>
      _partyCall(() async {
        final r = await _fn('start-party', {'channel_name': channelName, 'state': state, 'invite': invite, 'link': link});
        if (r['status'] != 'ok') throw ShareRefused('${r['status']}');
        return (party: PartyInfo.fromJson(Map<String, dynamic>.from(r['party'] as Map)), invite: _inviteOf(r));
      });

  @override
  Future<FriendInvite?> inviteToParty(String party, {List<String> invite = const [], bool link = false}) => _partyCall(() async {
        final r = await _fn('start-party', {'party': party, 'invite': invite, 'link': link});
        if (r['status'] != 'ok') throw ShareRefused('${r['status']}');
        return _inviteOf(r);
      });

  @override
  Future<(PartyJoinStatus, PartyInfo?)> joinParty(String party) => _partyCall(() async {
        final r = await _fn('join-party', {'party': party});
        final status = _joinStatus(r['status']);
        return (status, r['party'] is Map ? PartyInfo.fromJson(Map<String, dynamic>.from(r['party'] as Map)) : null);
      });

  @override
  Future<bool> leaveParty(String party, {bool hostGone = false}) => _partyCall(() async {
        final r = await _fn('leave-party', {'party': party, if (hostGone) 'reason': 'host-gone'});
        return r['ended'] == true;
      });

  @override
  Future<void> writePartyState(String party, Map<String, Object?> state) =>
      _partyCall(() async => _sb.from('watch_parties').update({'state': state}).eq('id', party));

  @override
  Future<List<ShareProfile>> partyMembers(String party) => _partyCall(() async {
        final rows = await _sb.rpc('party_members_of', params: {'p_party': party});
        return [for (final m in rows as List? ?? const []) if (m is Map) ShareProfile.fromJson(Map<String, dynamic>.from(m))];
      });

  @override
  Future<List<PartyInvite>> partyInvites() => _partyCall(() async {
        final rows = await _sb.rpc('my_party_invites');
        return [for (final r in rows as List? ?? const []) ?PartyInvite.fromJson(r)];
      });


  final _rooms = <_Room>{};

  @override
  Future<PartyRoom> openPartyRoom(String party,
      {required void Function(String event, Map<String, dynamic> payload) onMessage,
      required void Function(String user, bool left) onMember}) async {
    if (!_started) throw StateError('Sharing is stopped');
    await _sb.auth.getSession();
    final token = _sb.auth.currentSession?.accessToken;
    if (token != null) await _sb.realtime.setAuth(token);
    Map<String, dynamic> inner(Map<String, dynamic> m) =>
        m['payload'] is Map ? Map<String, dynamic>.from(m['payload'] as Map) : m;
    Future<RealtimeChannel> join(RealtimeChannel ch) {
      final ready = Completer<RealtimeChannel>();
      ch.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed && !ready.isCompleted) ready.complete(ch);
        if ((status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) && !ready.isCompleted) {
          ready.completeError(ShareUnavailable(error ?? status));
        }
      });
      return ready.future.timeout(const Duration(seconds: 15));
    }

    var room = _sb.channel('party:$party', opts: const RealtimeChannelConfig(private: true));
    for (final e in const ['action', 'reaction', 'hello', 'bye']) {
      room = room.onBroadcast(event: e, callback: (m) => onMessage(e, inner(m)));
    }
    final host = _sb
        .channel('party:$party:host', opts: const RealtimeChannelConfig(private: true))
        .onBroadcast(event: 'timeline', callback: (m) => onMessage('timeline', inner(m)));
    // Joins and leaves through Postgres Changes (not a private topic: the
    // table's own rules apply).
    final members = _sb.channel('party-members:$party').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'party_members',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'party_id', value: party),
        callback: (p) {
          final row = p.newRecord;
          if (row['user_id'] is String) onMember(row['user_id'] as String, row['left_at'] != null);
        });
    final r = _Room(this, await join(room), await join(host), members..subscribe());
    _rooms.add(r);
    return r;
  }

  RealtimeChannel? _invites;

  /// Tests that stand in for Realtime ([debugRealtime]) get the invite feed
  /// here instead of a socket.
  @visibleForTesting
  static void Function(void Function() onChange)? debugPartyInvites;

  @override
  Future<void> watchPartyInvites(void Function() onChange) async {
    if (!_started) throw StateError('Sharing is stopped');
    await stopWatchingPartyInvites();
    if (debugRealtime != null) {
      debugPartyInvites?.call(onChange);
      return;
    }
    await _sb.auth.getSession();
    final token = _sb.auth.currentSession?.accessToken;
    if (token != null) await _sb.realtime.setAuth(token);
    var ready = false;
    _invites = _sb
        .channel('party-invites')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'party_invites', callback: (_) => onChange())
        .onSystemEvents((payload) {
          if (ready || payload is! Map || payload['extension'] != 'postgres_changes') return;
          if (payload['status'] == 'ok') {
            ready = true;
            onChange();
          }
        })
        .subscribe();
  }

  @override
  Future<void> stopWatchingPartyInvites() async {
    final ch = _invites;
    _invites = null;
    if (ch == null) return;
    try {
      await _sb.removeChannel(ch);
    } on Object catch (e) {
      debugPrint('Party invites socket: $e');
    }
  }
}

class _Room implements PartyRoom {
  _Room(this._client, this._room, this._host, this._members);

  final ShareClient _client;
  final RealtimeChannel _room, _host, _members;
  bool _closed = false;

  @override
  Future<void> send(String event, Map<String, Object?> payload) async {
    if (_closed) return;
    await _room.sendBroadcastMessage(event: event, payload: Map<String, dynamic>.from(payload));
  }

  @override
  Future<void> sendTimeline(Map<String, Object?> payload) async {
    if (_closed) return;
    await _host.sendBroadcastMessage(event: 'timeline', payload: Map<String, dynamic>.from(payload));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _client._rooms.remove(this);
    for (final ch in [_room, _host, _members]) {
      try {
        await _client._sb.removeChannel(ch);
      } on Object catch (e) {
        debugPrint('Party socket: $e');
      }
    }
  }
}
