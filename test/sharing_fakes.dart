import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/sharing/presence.dart';
import 'package:nightingale_tv/sharing/share_client.dart';

import 'sharing_test.dart' show sessionJson;

/// The sharing backend, in memory: Auth's email codes, the tables this app
/// reads, and the Edge Functions, answering as the real ones do.
class FakeShareBackend {
  /// Also stands in for Realtime (friend-presence).
  FakeShareBackend() {
    ShareClient.debugRealtime = (onRow, onReady) {
      _onRow = onRow;
      realtimeOpen = true;
      scheduleMicrotask(onReady);
    };
    ShareClient.debugRealtimeStop = () {
      _onRow = null;
      realtimeOpen = false;
    };
    ShareClient.debugPartyInvites = (onChange) => partyInvitesChanged = onChange;
  }

  // ---- Watch together (watch-together) ----

  /// What my_party_invites answers.
  final partyInvites = <Map<String, Object?>>[];
  void Function()? partyInvitesChanged;

  static const userId = 'user-me';
  static const otp = '123456';

  // ---- Friend presence (friend-presence) ----

  /// This account's published row, as last sent.
  Map<String, Object?>? myWatching;

  /// Every publish, in order (null for a clear).
  final published = <Map<String, Object?>?>[];

  /// Friends' rows, as the select returns them.
  final watchingRows = <Map<String, Object?>>[];

  /// The presence feed is open (the app's Realtime socket).
  bool realtimeOpen = false;
  void Function(PresenceRow row)? _onRow;

  /// The backend's clock (server-time); the device's unless set.
  DateTime Function() serverClock = () => DateTime.now().toUtc();

  /// [friend] starts watching [title] on [channel]: the select returns it
  /// and the feed (if open) brings it.
  void friendWatching(ShareProfile friend, {String? title, required String channel, String? sharedId, DateTime? updatedAt}) {
    final row = {
      'user_id': friend.userId,
      'title': title,
      'channel_name': channel,
      'shared_channel_id': sharedId,
      'started_at': serverClock().toIso8601String(),
      'updated_at': (updatedAt ?? serverClock()).toIso8601String(),
    };
    watchingRows
      ..removeWhere((r) => r['user_id'] == friend.userId)
      ..add(row);
    _onRow?.call(PresenceRow.fromJson(row));
  }

  /// [friend] stops: the row cleared.
  void friendStopped(ShareProfile friend) {
    final row = {'user_id': friend.userId, 'updated_at': serverClock().toIso8601String()};
    watchingRows.removeWhere((r) => r['user_id'] == friend.userId);
    _onRow?.call(PresenceRow.fromJson(row));
  }

  /// The code shown in Add friend.
  String myCode = 'AB3K9Q';

  /// Codes others made: their owner, or a status the functions answer.
  final codes = <String, Object>{
    'XY7Z2M': const ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler', avatar: 'owl', avatarColor: 1),
    'GGGGGG': InviteStatus.gone,
    'MMMMMM': InviteStatus.limited,
  };

  Map<String, Object?>? profile;

  // ---- Channel sharing (channel-sharing) ----

  /// Shared channels by id: {owner, name, recipe, version, stopped}.
  final sharedChannels = <String, Map<String, Object?>>{};

  /// Shares sent to this account: {id, shared_channel_id, state, ended_at, created_at, from}.
  final incoming = <Map<String, Object?>>[];

  /// Shares this account sent: shared channel id → receiver ids.
  final outgoing = <String, List<String>>{};

  /// What share-channels was last asked: {recipes, to, link}.
  Map<String, Object?>? lastShare;

  /// A share of [recipe] by [from] (its shared channel made too).
  Map<String, Object?> shareIn(String sharedId, Map<String, Object?> recipe,
      {ShareProfile from = const ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler', station: 'Tyler TV'),
      int version = 1}) {
    sharedChannels[sharedId] = {'owner': from.userId, 'name': recipe['name'], 'recipe': recipe, 'version': version};
    final row = {
      'id': 'share-${incoming.length + 1}',
      'shared_channel_id': sharedId,
      'state': 'new',
      'ended_at': null,
      'created_at': DateTime.utc(2026, 11, 16, incoming.length).toIso8601String(),
      'from': _fnProfile(from),
    };
    incoming.add(row);
    return row;
  }

  /// The sender publishes [recipe] as a new version.
  void publish(String sharedId, Map<String, Object?> recipe) {
    final c = sharedChannels[sharedId]!;
    c['recipe'] = recipe;
    c['version'] = (c['version'] as int) + 1;
  }

  /// Ends the shares of [sharedId] (stopped, unfriended).
  void end(String sharedId) {
    for (final r in incoming) {
      if (r['shared_channel_id'] == sharedId) r['ended_at'] = DateTime.utc(2026, 11, 17).toIso8601String();
    }
  }

  bool _readable(String id) =>
      sharedChannels[id]?['owner'] == userId ||
      incoming.any((r) => r['shared_channel_id'] == id && r['ended_at'] == null);

  final friends = <ShareProfile>[];
  final blocked = <ShareProfile>[];
  final takenHandles = {'tyler'};
  final requests = <String>[];

  late final client = MockClient(_answer);

  late http.Request _request;

  http.Response _json(Object? body, {int status = 200}) => http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'}, request: _request);

  http.Response _empty(int status) => http.Response('', status, request: _request);

  Map<String, Object?> _row(ShareProfile p) => {
        'user_id': p.userId,
        'display_name': p.name,
        'handle': p.handle,
        'avatar': p.avatar,
        'avatar_color': p.avatarColor,
        'station': p.station,
      };

  Map<String, Object?> _fnProfile(ShareProfile p) =>
      {'user_id': p.userId, 'name': p.name, 'handle': p.handle, 'avatar': p.avatar, 'avatar_color': p.avatarColor, 'station': p.station};

  Future<http.Response> _answer(http.Request r) async {
    _request = r;
    final path = r.url.path;
    requests.add('${r.method} $path');
    final single = (r.headers['accept'] ?? '').contains('vnd.pgrst.object');
    switch ((r.method, path)) {
      case ('POST', '/auth/v1/otp'):
        return _json({});
      case ('POST', '/auth/v1/verify'):
        final body = jsonDecode(r.body) as Map<String, Object?>;
        if (body['token'] != otp) return _json({'code': 'otp_expired', 'msg': 'Token has expired or is invalid'}, status: 403);
        return _json(jsonDecode(sessionJson(userId)));
      case ('POST', '/auth/v1/logout'):
        return _empty(204);
      case ('GET', '/rest/v1/share_profiles'):
        return _json([?profile, for (final f in [...friends, ...blocked]) _row(f)]
            .where((row) => r.url.queryParameters['user_id'] == null || 'eq.${row['user_id']}' == r.url.queryParameters['user_id'])
            .toList());
      case ('POST', '/rest/v1/share_profiles'):
        final row = Map<String, Object?>.from(jsonDecode(r.body) as Map);
        if (takenHandles.contains(row['handle'])) {
          return _json({'code': '23505', 'message': 'duplicate key value violates unique constraint', 'details': null, 'hint': null},
              status: 409);
        }
        profile = {...row, 'user_id': userId};
        return _json(single ? profile : [profile], status: 201);
      case ('POST', '/rest/v1/rpc/handle_available'):
        final h = (jsonDecode(r.body) as Map)['p_handle'];
        return _json(!takenHandles.contains(h));
      case ('GET', '/rest/v1/invites'):
        return _json([
          {'code': myCode, 'expires_at': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String()},
        ]);
      case ('GET', '/rest/v1/friendships'):
        return _json([
          for (final f in friends) {'user_a': userId, 'user_b': f.userId},
        ]);
      case ('GET', '/rest/v1/blocks'):
        return _json([
          for (final b in blocked) {'blocked': b.userId},
        ]);
      case ('DELETE', '/rest/v1/friendships'):
        final id = r.url.queryParameters['user_b']?.substring(3);
        friends.removeWhere((f) => f.userId == id);
        return _empty(204);
      case ('POST', '/rest/v1/blocks'):
        final id = (jsonDecode(r.body) as Map)['blocked'];
        final f = friends.where((f) => f.userId == id).toList();
        friends.removeWhere((f) => f.userId == id);
        blocked.addAll(f);
        return _empty(201);
      case ('DELETE', '/rest/v1/blocks'):
        final id = r.url.queryParameters['blocked']?.substring(3);
        blocked.removeWhere((b) => b.userId == id);
        return _empty(204);
      case ('POST', '/functions/v1/make-invite'):
        myCode = 'NEW2CD';
        return _json({
          'status': 'ok',
          'code': myCode,
          'kind': 'friend',
          'expires_at': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
        });
      case ('POST', '/functions/v1/peek-invite' || '/functions/v1/redeem-invite'):
        final code = (jsonDecode(r.body) as Map)['code'] as String;
        if (code == myCode) return _json({'status': 'own'});
        final what = codes[code];
        if (what is InviteStatus) return _json({'status': what.name});
        if (what is! ShareProfile) return _json({'status': 'gone'});
        if (path.endsWith('peek-invite')) return _json({'status': 'ok', 'kind': 'friend', 'from': _fnProfile(what)});
        codes[code] = InviteStatus.gone;
        friends.add(what);
        return _json({'status': 'ok', 'friend': _fnProfile(what)});
      case ('POST', '/rest/v1/rpc/my_party_invites'):
        return _json(partyInvites);
      case ('POST', '/rest/v1/rpc/my_channel_shares'):
        return _json([
          for (final r in incoming)
            {
              ...r,
              'name': sharedChannels[r['shared_channel_id']]?['name'],
              'version': sharedChannels[r['shared_channel_id']]?['version'],
            },
        ]);
      case ('POST', '/functions/v1/share-channels'):
        final body = Map<String, Object?>.from(jsonDecode(r.body) as Map);
        lastShare = body;
        final out = <Map<String, Object?>>[];
        for (final x in (body['recipes'] as List).cast<Map>()) {
          final id = x['id'] as String;
          final old = sharedChannels[id];
          final changed = old == null || jsonEncode(old['recipe']) != jsonEncode(x['recipe']);
          final version = old == null ? 1 : (old['version'] as int) + (changed ? 1 : 0);
          sharedChannels[id] = {'owner': userId, 'name': x['name'], 'recipe': x['recipe'], 'version': version};
          for (final to in (body['to'] as List? ?? const []).cast<String>()) {
            (outgoing[id] ??= []).add(to);
          }
          out.add({'id': id, 'version': version});
        }
        return _json({
          'status': 'ok',
          'channels': out,
          if (body['link'] == true) ...{
            'code': 'CH4NL5',
            'expires_at': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
          },
        });
      case ('GET', '/rest/v1/shared_channels'):
        final idFilter = r.url.queryParameters['id']?.substring(3);
        if (idFilter != null) {
          final c = sharedChannels[idFilter];
          if (c == null || !_readable(idFilter)) return _json([]);
          return _json([
            {'id': idFilter, 'recipe': c['recipe'], 'version': c['version'], 'name': c['name']},
          ]);
        }
        return _json([
          for (final e in sharedChannels.entries)
            if (e.value['owner'] == userId)
              {
                'id': e.key,
                'name': e.value['name'],
                'version': e.value['version'],
                'stopped_at': e.value['stopped'] == true ? '2026-11-17T00:00:00Z' : null,
                'channel_shares': [
                  for (final to in outgoing[e.key] ?? const <String>[]) {'recipient': to, 'ended_at': null},
                ],
              },
        ]);
      case ('PATCH', '/rest/v1/shared_channels'):
        final id = r.url.queryParameters['id']?.substring(3);
        sharedChannels[id]?['stopped'] = true;
        outgoing.remove(id);
        return _empty(204);
      case ('PATCH', '/rest/v1/channel_shares'):
        final id = r.url.queryParameters['id']?.substring(3);
        final state = (jsonDecode(r.body) as Map)['state'];
        for (final row in incoming) {
          if (row['id'] == id) row['state'] = state;
        }
        return _empty(204);
      case ('PATCH', '/rest/v1/share_profiles'):
        final body = Map<String, Object?>.from(jsonDecode(r.body) as Map);
        if (profile != null) profile = {...profile!, ...body};
        return _empty(204);
      case ('POST', '/rest/v1/now_watching'):
        final row = Map<String, Object?>.from(jsonDecode(r.body) as Map);
        myWatching = row['channel_name'] == null ? null : row;
        published.add(myWatching);
        return _empty(201);
      case ('GET', '/rest/v1/now_watching'):
        return _json(watchingRows);
      case ('GET', '/functions/v1/server-time'):
        return _json({'now': serverClock().millisecondsSinceEpoch});
      case ('POST', '/functions/v1/delete-account'):
        profile = null;
        friends.clear();
        return _json({'status': 'ok'});
    }
    return _json({'message': 'not found: ${r.method} $path'}, status: 404);
  }
}
