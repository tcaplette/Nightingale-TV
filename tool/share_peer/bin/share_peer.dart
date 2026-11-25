// A second sharing user for live checks (share-accounts, design D13).
//
// Reads the project URL and public key from sharing.env, and the secret key from
// supabase-credentials.txt (both git-ignored, at the repo root). The secret key is used
// only for test-account admin calls; every user action goes through the public key and a
// real sign-in, exactly as the app does. NTV_TEST_EMAIL in supabase-credentials.txt is the
// address the generated test accounts are made from: a tag goes in before the @
// (you+ntv-test@example.com → you+ntv-test-presence-<stamp>@example.com).
//
//   dart run tool/share_peer/bin/share_peer.dart <command> …
//
//   create-user <email>                       make a confirmed account
//   otp <email>                               print a fresh 6-digit sign-in code for <email>
//                                             (an unknown email is signed up, as in the app)
//   profile <email> [name handle [avatar color station]]   show, or create/update
//   invite <email> [--new]                    show the live friend code (makes one if none)
//   peek <email> <code>                       look at a code without redeeming
//   redeem <email> <code>                     redeem a code
//   friends <email>                           list friends and blocked
//   block|unblock|remove <email> <handle>     act on a friend (or a blocked account)
//   delete <email>                            delete the account through delete-account
//   rls-check <emailA> <emailB>               check the backend data rules (task 3.3)
//
// Channel sharing (channel-sharing):
//   shares <email>                            the shares sent to <email>, ended ones included
//   accept|decline <email> <shareId>          set a share's Add or Decline state
//   recipe <email> <sharedChannelId>          dump a shared channel's recipe
//   my-shares <email>                         the channels <email> shares, with receivers
//   stop <email> <sharedChannelId>            stop sharing a channel
//   remove-shared <email> <sharedChannelId>   delete a shared channel and its shares (test clean-up)
//   share-channels <email> <recipe.json> (--to <handle>… | --link) [--id <uuid>]
//                                             publish recipes and share them; <recipe.json> holds
//                                             one recipe or a list. --id reuses a shared-channel id
//                                             (publishes a new version); with neither --to nor
//                                             --link it only publishes
//   channel-rls-check <sender> <receiver> <stranger>   check the channel-sharing data rules
//
// Friend presence (friend-presence):
//   watch <email> <shared-channel-id|none> <channel> <title|-> [--keep]
//                                             publish what <email> is watching ("-": no title, a
//                                             live channel without a guide); --keep refreshes it
//                                             every 2 minutes until killed (kill -9 for a stale row)
//   stop <email>                              clear it (not watching)
//   presence <email>                          the presence rows <email> can read, with their age
//                                             by the backend's clock
//   presence-follow <email>                   print each friend's presence change as it arrives over
//                                             Realtime, with the local time (until killed)
//   presence-check <A> <B> <stranger>         check the presence data rules and Realtime (A and B
//                                             friends; makes and deletes a temporary account)
//
// Watch together (watch-together D9; bin/party.dart):
//   party-host <email> <recipe.json> [--invite <handle>…] [--link] [--start <i>] [--offset <s>]
//              [--break <i>:<at s>:<length s>]… [--for <s>] [--channel <name>]
//                                             host a party without a player: walks the recipe's
//                                             items on a simulated clock, broadcasts timelines
//                                             (on change and every 5 s), applies actions, logs
//                                             reactions; stdin: pause, resume, skip <s>, restart,
//                                             live, next, react <emoji>, invite <handle>, leave
//   party-join <email> [<party>|-] [--for <s>]   join as a guest and log every timeline, action and
//                                             reaction; stdin: pause, resume, skip <s>, restart,
//                                             live, react <emoji>, leave ("-": the newest invite)
//   react <email> <party|-> <emoji>           one reaction as a member
//   pause|resume|restart|live <email> <party|->   one action as a member
//   skip <email> <party|-> [seconds]          skip forward (negative: back), default 30
//   leave <email> <party|->                   leave (the host ends the party)
//   party-check <A> <B> <stranger>            check the watch-together data rules (task 2.4; A and
//                                             B friends; makes and deletes temporary accounts)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

part 'party.dart';

late final String _url;
late final String _key;
late final String _secret;

/// NTV_TEST_EMAIL from supabase-credentials.txt, when it's set.
String? _testEmail;

String _requireTestEmail() {
  final e = _testEmail;
  if (e == null || !RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(e)) {
    throw StateError('NTV_TEST_EMAIL is missing from supabase-credentials.txt');
  }
  return e;
}

/// A test account's address: NTV_TEST_EMAIL with `-<tag>` inserted before the @.
String _taggedEmail(String tag) {
  final e = _requireTestEmail();
  final at = e.indexOf('@');
  return '${e.substring(0, at)}-$tag${e.substring(at)}';
}

/// `@<domain>` of NTV_TEST_EMAIL, for the "no email in profile rows" check.
String _testDomain() {
  final e = _requireTestEmail();
  return e.substring(e.indexOf('@'));
}

Map<String, String> _envFile(String path) {
  final out = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#') || !t.contains('=')) continue;
    final i = t.indexOf('=');
    out[t.substring(0, i)] = t.substring(i + 1);
  }
  return out;
}

String _repoRoot() {
  var dir = File(Platform.script.toFilePath()).parent;
  while (!File('${dir.path}/sharing.env').existsSync()) {
    if (dir.parent.path == dir.path) {
      throw StateError('sharing.env not found above ${Platform.script}');
    }
    dir = dir.parent;
  }
  return dir.path;
}

SupabaseClient _admin() => SupabaseClient(_url, _secret,
    authOptions: const AuthClientOptions(autoRefreshToken: false));

SupabaseClient _anon() => SupabaseClient(_url, _key,
    authOptions: const AuthClientOptions(autoRefreshToken: false));

Future<String> _otp(String email) async {
  final r = await _admin()
      .auth
      .admin
      .generateLink(type: GenerateLinkType.magiclink, email: email);
  return r.properties.emailOtp;
}

/// Signs in as [email] with a real email OTP, as the app does.
Future<SupabaseClient> _as(String email) async {
  final c = _anon();
  await c.auth.verifyOTP(
      type: OtpType.email, email: email, token: await _otp(email));
  return c;
}

Future<Map<String, dynamic>> _fn(SupabaseClient c, String name,
    [Map<String, dynamic> body = const {}]) async {
  final r = await c.functions.invoke(name, body: body);
  return Map<String, dynamic>.from(r.data as Map);
}

Future<List<Map<String, dynamic>>> _profiles(SupabaseClient c) async =>
    List<Map<String, dynamic>>.from(await c.from('share_profiles').select());

Future<String> _idForHandle(SupabaseClient c, String handle) async {
  final p = (await _profiles(c)).where(
      (p) => (p['handle'] as String).toLowerCase() == handle.toLowerCase());
  if (p.isEmpty) throw StateError('no visible profile @$handle');
  return p.first['user_id'] as String;
}

void _print(Object? o) =>
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(o));

Future<void> main(List<String> args) async {
  final root = _repoRoot();
  final share = _envFile('$root/sharing.env');
  final creds = _envFile('$root/supabase-credentials.txt');
  _url = share['NTV_SHARE_URL']!;
  _key = share['NTV_SHARE_KEY']!;
  _secret = creds['SUPABASE_SECRET_KEY']!;
  final testEmail = creds['NTV_TEST_EMAIL']?.trim();
  _testEmail = (testEmail == null || testEmail.isEmpty) ? null : testEmail;
  if (args.isEmpty) {
    stderr.writeln('usage: share_peer <command> … (see the file header)');
    exit(2);
  }
  try {
    await _run(args.first, args.skip(1).toList());
    exit(0);
  } on Object catch (e) {
    stderr.writeln('share_peer: $e');
    exit(1);
  }
}

Future<void> _run(String cmd, List<String> a) async {
  switch (cmd) {
    case 'create-user':
      final r = await _admin().auth.admin.createUser(
          AdminUserAttributes(email: a[0], emailConfirm: true));
      _print({'id': r.user?.id, 'email': r.user?.email});
    case 'otp':
      stdout.writeln(await _otp(a[0]));
    case 'profile':
      final c = await _as(a[0]);
      final me = c.auth.currentUser!.id;
      if (a.length >= 3) {
        await c.from('share_profiles').upsert({
          'user_id': me,
          'display_name': a[1],
          'handle': a[2].toLowerCase(),
          if (a.length > 3) 'avatar': a[3],
          if (a.length > 4) 'avatar_color': int.parse(a[4]),
          if (a.length > 5) 'station': a[5],
        });
      }
      _print(await c.from('share_profiles').select().eq('user_id', me));
    case 'invite':
      final c = await _as(a[0]);
      final me = c.auth.currentUser!.id;
      if (!a.contains('--new')) {
        final live = await c
            .from('invites')
            .select()
            .eq('owner', me)
            .eq('kind', 'friend')
            .isFilter('used_at', null)
            .gt('expires_at', DateTime.now().toUtc().toIso8601String());
        if (live.isNotEmpty) {
          _print(live.first);
          return;
        }
      }
      _print(await _fn(c, 'make-invite'));
    case 'peek':
      _print(await _fn(await _as(a[0]), 'peek-invite', {'code': a[1]}));
    case 'redeem':
      _print(await _fn(await _as(a[0]), 'redeem-invite', {'code': a[1]}));
    case 'friends':
      final c = await _as(a[0]);
      final me = c.auth.currentUser!.id;
      final fr = await c.from('friendships').select();
      final bl = await c.from('blocks').select();
      final profiles = {for (final p in await _profiles(c)) p['user_id']: p};
      String name(String id) => profiles[id] == null
          ? id
          : '${profiles[id]!['display_name']} (@${profiles[id]!['handle']})';
      _print({
        'friends': [
          for (final f in fr) name(f['user_a'] == me ? f['user_b'] : f['user_a'])
        ],
        'blocked': [for (final b in bl) name(b['blocked'] as String)],
      });
    case 'block':
      final c = await _as(a[0]);
      await c.from('blocks').insert({
        'blocker': c.auth.currentUser!.id,
        'blocked': await _idForHandle(c, a[1]),
      });
      stdout.writeln('blocked @${a[1]}');
    case 'unblock':
      final c = await _as(a[0]);
      await c
          .from('blocks')
          .delete()
          .eq('blocked', await _idForHandle(c, a[1]));
      stdout.writeln('unblocked @${a[1]}');
    case 'remove':
      final c = await _as(a[0]);
      final me = c.auth.currentUser!.id;
      final other = await _idForHandle(c, a[1]);
      final lo = me.compareTo(other) < 0 ? me : other;
      final hi = lo == me ? other : me;
      await c.from('friendships').delete().eq('user_a', lo).eq('user_b', hi);
      stdout.writeln('removed @${a[1]}');
    case 'delete':
      _print(await _fn(await _as(a[0]), 'delete-account'));
    case 'rls-check':
      await _rlsCheck(a[0], a[1]);
    case 'shares':
      _print(await (await _as(a[0])).rpc('my_channel_shares'));
    case 'accept' || 'decline':
      final c = await _as(a[0]);
      _print(await c
          .from('channel_shares')
          .update({'state': cmd == 'accept' ? 'added' : 'declined'})
          .eq('id', a[1])
          .select());
    case 'recipe':
      final rows = await (await _as(a[0]))
          .from('shared_channels')
          .select('id, name, version, recipe')
          .eq('id', a[1]);
      if (rows.isEmpty) throw StateError('no readable shared channel ${a[1]}');
      _print(rows.first);
    case 'my-shares':
      final c = await _as(a[0]);
      _print(await c
          .from('shared_channels')
          .select('id, name, version, stopped_at, channel_shares(recipient, state, ended_at)')
          .eq('owner', c.auth.currentUser!.id));
    case 'stop' when a.length == 1:
      final c = await _as(a[0]);
      _print(await c
          .from('now_watching')
          .upsert(_cleared(c.auth.currentUser!.id))
          .select());
    case 'watch':
      await _watch(a);
    case 'presence':
      await _presence(a[0]);
    case 'presence-follow':
      await _presenceFollow(a[0]);
    case 'party-host':
      return _partyHost(a);
    case 'party-join':
      return _partyJoin(a);
    case 'react' || 'pause' || 'resume' || 'restart' || 'live' || 'skip' || 'leave':
      return _partyOnce(cmd, a);
    case 'party-check':
      return _partyCheck(a[0], a[1], a[2]);
    case 'presence-check':
      await _presenceCheck(a[0], a[1], a[2]);
    case 'stop':
      final c = await _as(a[0]);
      _print(await c
          .from('shared_channels')
          .update({'stopped_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', a[1])
          .select('id, name, stopped_at'));
    case 'remove-shared':
      final c = await _as(a[0]);
      _print(await c.from('shared_channels').delete().eq('id', a[1]).select('id, name'));
    case 'share-channels':
      await _shareChannels(a);
    case 'channel-rls-check':
      await _channelRlsCheck(a[0], a[1], a[2]);
    default:
      throw ArgumentError('unknown command $cmd');
  }
}

/// Task 3.3: each account sees only its own rows and its friends' profiles; anonymous
/// sees nothing; no email is ever returned; no client writes where functions write.
Future<void> _rlsCheck(String emailA, String emailB) async {
  var failures = 0;
  void check(bool ok, String what) {
    stdout.writeln('${ok ? 'ok  ' : 'FAIL'} $what');
    if (!ok) failures++;
  }

  final a = await _as(emailA), b = await _as(emailB);
  final idA = a.auth.currentUser!.id, idB = b.auth.currentUser!.id;
  const tables = [
    'share_profiles',
    'friendships',
    'blocks',
    'invites',
    'redeem_attempts',
    'preview_hits',
  ];

  // Anonymous: nothing from any table (denied or empty).
  final anon = _anon();
  for (final t in tables) {
    var rows = 0;
    try {
      rows = (await anon.from(t).select()).length;
    } on PostgrestException {
      rows = 0;
    }
    check(rows == 0, 'anonymous reads nothing from $t');
  }

  for (final (who, c, me, other) in [('A', a, idA, idB), ('B', b, idB, idA)]) {
    final fr = await c.from('friendships').select();
    final friendIds = {
      for (final f in fr) f['user_a'] == me ? f['user_b'] : f['user_a']
    };
    check(fr.every((f) => f['user_a'] == me || f['user_b'] == me),
        '$who sees only friendships that include it (${fr.length})');
    final inv = await c.from('invites').select();
    check(inv.every((i) => i['owner'] == me),
        '$who sees only its own invites (${inv.length})');
    final bl = await c.from('blocks').select();
    check(bl.every((x) => x['blocker'] == me),
        '$who sees only its own blocks (${bl.length})');
    final blockedIds = {for (final x in bl) x['blocked']};
    final pr = await _profiles(c);
    check(
        pr.every((p) =>
            p['user_id'] == me ||
            friendIds.contains(p['user_id']) ||
            blockedIds.contains(p['user_id'])),
        '$who sees only its own, friends\' and blocked profiles (${pr.length})');
    check(pr.every((p) => !p.containsKey('email')) &&
            !jsonEncode(pr).contains(_testDomain()),
        '$who: no email in any profile');
    for (final t in ['redeem_attempts', 'preview_hits']) {
      var rows = 0;
      try {
        rows = (await c.from(t).select()).length;
      } on PostgrestException {
        rows = 0;
      }
      check(rows == 0, '$who reads nothing from $t');
    }
    Future<bool> refused(Future<Object?> Function() f) async {
      try {
        await f();
        return false;
      } on PostgrestException {
        return true;
      }
    }

    check(
        await refused(() => c.from('friendships').insert({
              'user_a': me.compareTo(other) < 0 ? me : other,
              'user_b': me.compareTo(other) < 0 ? other : me,
            })),
        '$who cannot add a friendship itself');
    check(
        await refused(() => c.from('invites').insert(
            {'code': 'ZZZZZZ', 'owner': me, 'kind': 'friend'})),
        '$who cannot write invites itself');
    check(
        await refused(() => c.from('share_profiles').insert({
              'user_id': other,
              'display_name': 'x',
              'handle': 'not_mine_${DateTime.now().millisecondsSinceEpoch % 100000}',
            })),
        '$who cannot write another account\'s profile');
    final changed = await c
        .from('share_profiles')
        .update({'display_name': 'Hacked'})
        .eq('user_id', other)
        .select();
    check(changed.isEmpty, '$who cannot change another account\'s profile');
    var rpcRefused = false;
    try {
      await c.rpc('redeem_invite', params: {'p_user': me, 'p_code': 'ZZZZZZ'});
    } on PostgrestException {
      rpcRefused = true;
    }
    check(rpcRefused, '$who cannot call the service-only redeem function');
  }
  stdout.writeln(failures == 0 ? 'RLS check passed' : 'RLS check: $failures failed');
  if (failures > 0) exit(1);
}

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// `share-channels <email> <recipe.json> (--to <handle>… | --link) [--id <uuid>]`
Future<void> _shareChannels(List<String> a) async {
  final c = await _as(a[0]);
  final json = jsonDecode(File(a[1]).readAsStringSync());
  final list = json is List ? json : [json];
  final to = <String>[];
  String? id;
  var link = false;
  for (var i = 2; i < a.length; i++) {
    switch (a[i]) {
      case '--to':
        while (i + 1 < a.length && !a[i + 1].startsWith('--')) {
          to.add(await _idForHandle(c, a[++i]));
        }
      case '--link':
        link = true;
      case '--id':
        id = a[++i];
    }
  }
  final recipes = [
    for (final (i, r) in list.indexed)
      {
        // A dump from `recipe` carries its id and recipe; a bare recipe is the recipe.
        'id': i == 0 && id != null ? id : (r['recipe'] != null ? r['id'] : null) ?? _uuid(),
        'name': (r['recipe'] ?? r)['name'],
        'recipe': r['recipe'] ?? r,
      }
  ];
  _print(await _fn(c, 'share-channels', {
    'recipes': recipes,
    if (to.isNotEmpty) 'to': to,
    if (link) 'link': true,
  }));
}

/// Task 2.3 (channel-sharing): a stranger can't read a recipe; the receiver reads it only
/// while its share is active, and can change only its share's state; only the sender writes.
Future<void> _channelRlsCheck(String sender, String receiver, String stranger) async {
  var failures = 0;
  void check(bool ok, String what) {
    stdout.writeln('${ok ? 'ok  ' : 'FAIL'} $what');
    if (!ok) failures++;
  }

  Future<bool> refused(Future<Object?> Function() f) async {
    try {
      final r = await f();
      return r is List && r.isEmpty;
    } on PostgrestException {
      return true;
    }
  }

  final s = await _as(sender), r = await _as(receiver), x = await _as(stranger);
  final rId = r.auth.currentUser!.id;
  final recipe = {
    'v': 1,
    'name': 'RLS check',
    'order': 'cyclic',
    'anchor': '2026-11-01T00:00:00Z',
    'shows': [
      {
        'ids': ['tvdb:79168'],
        'name': 'Friends',
        'year': 1994
      }
    ],
    'items': [
      {'s': 0, 'se': 1, 'ep': 1, 't': 'Pilot', 'rt': 1320}
    ],
  };
  final sent = await _fn(s, 'share-channels', {
    'recipes': [
      {'id': _uuid(), 'name': 'RLS check', 'recipe': recipe}
    ],
    'to': [rId],
  });
  check(sent['status'] == 'ok', 'sender shares with a friend (${sent['status']})');
  if (sent['status'] != 'ok') exit(1);
  final id = (sent['channels'] as List).first['id'] as String;

  var anonRows = 0;
  try {
    anonRows = (await _anon().from('shared_channels').select().eq('id', id)).length;
  } on PostgrestException {
    anonRows = 0;
  }
  check(anonRows == 0, 'anonymous reads no recipe');
  check((await x.from('shared_channels').select().eq('id', id)).isEmpty, 'a stranger reads no recipe');
  check((await x.from('channel_shares').select().eq('shared_channel_id', id)).isEmpty, 'a stranger sees no share');
  final strangerShares = await x.rpc('my_channel_shares') as List;
  check(strangerShares.every((e) => e['shared_channel_id'] != id), 'the stranger\'s share list lacks it');
  check(
      (await _fn(x, 'share-channels', {
            'recipes': [
              {'id': id, 'name': 'Hijack', 'recipe': recipe}
            ],
          }))['status'] ==
          'bad_request',
      'a stranger can\'t publish over the sender\'s id');

  final mine = await r.from('shared_channels').select('recipe').eq('id', id);
  check(mine.length == 1 && mine.first['recipe']['name'] == 'RLS check', 'the receiver reads the recipe');
  final share = (await r.from('channel_shares').select().eq('shared_channel_id', id)).first;
  check(
      await refused(() => r.from('shared_channels').update({'stopped_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).select()),
      'the receiver can\'t stop the sender\'s share');
  check(await refused(() => r.from('shared_channels').delete().eq('id', id).select()),
      'the receiver can\'t remove the recipe');
  check(
      await refused(() => r.from('channel_shares').update({'ended_at': DateTime.now().toUtc().toIso8601String()}).eq('id', share['id']).select()),
      'the receiver can\'t change ended_at');
  check(
      await refused(() => r.from('channel_shares').insert({'shared_channel_id': id, 'recipient': rId}).select()),
      'the receiver can\'t insert shares');
  final stateSet = await r.from('channel_shares').update({'state': 'declined'}).eq('id', share['id']).select();
  check(stateSet.length == 1 && stateSet.first['state'] == 'declined', 'the receiver changes its state');
  check(await refused(() => x.from('channel_shares').update({'state': 'added'}).eq('id', share['id']).select()),
      'a stranger can\'t change the state');
  var rpcRefused = false;
  try {
    await r.rpc('share_channels', params: {'p_owner': rId, 'p_recipes': [], 'p_to': [], 'p_link': false});
  } on PostgrestException {
    rpcRefused = true;
  }
  check(rpcRefused, 'the service-only share_channels function is refused');

  // Stop sharing: the share ends and the recipe is no longer readable by the receiver.
  await s.from('shared_channels').update({'stopped_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  check((await r.from('shared_channels').select().eq('id', id)).isEmpty, 'after Stop sharing the receiver reads no recipe');
  final ended = await r.from('channel_shares').select('ended_at').eq('id', share['id']);
  check(ended.length == 1 && ended.first['ended_at'] != null, 'after Stop sharing the receiver sees the share ended');
  check((await s.from('shared_channels').select().eq('id', id)).length == 1, 'the sender still reads its own');
  await s.from('shared_channels').delete().eq('id', id);
  stdout.writeln(failures == 0 ? 'Channel RLS check passed' : 'Channel RLS check: $failures failed');
  if (failures > 0) exit(1);
}


Map<String, Object?> _cleared(String me) => {
      'user_id': me,
      'title': null,
      'channel_name': null,
      'shared_channel_id': null,
      'started_at': null,
    };

Map<String, Object?> _watching(String me, String? shared, String channel, String? title) => {
      'user_id': me,
      'title': title,
      'channel_name': channel,
      'shared_channel_id': shared,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    };

/// `watch <email> <shared-channel-id|none> <channel> <title|-> [--keep]`
Future<void> _watch(List<String> a) async {
  final c = await _as(a[0]);
  final me = c.auth.currentUser!.id;
  final shared = a[1] == 'none' ? null : a[1];
  final title = a[3] == '-' ? null : a[3];
  final row = _watching(me, shared, a[2], title);
  _print(await c.from('now_watching').upsert(row).select());
  if (!a.contains('--keep')) return;
  stdout.writeln('refreshing every 2 minutes; kill to stop (the row goes stale after 5)');
  while (true) {
    await Future<void>.delayed(const Duration(minutes: 2));
    // A fresh token for each refresh (sign-ins last an hour).
    final again = await _as(a[0]);
    final r = await again.from('now_watching').update({'started_at': row['started_at']}).eq('user_id', me).select('updated_at');
    stdout.writeln('refreshed ${r.isEmpty ? '(no row)' : r.first['updated_at']}');
  }
}

/// The backend's clock (server-time).
Future<DateTime> _serverNow(SupabaseClient c) async {
  final r = await c.functions.invoke('server-time', method: HttpMethod.get);
  final data = r.data is String ? jsonDecode(r.data as String) : r.data;
  return DateTime.fromMillisecondsSinceEpoch(((data as Map)['now'] as num).toInt(), isUtc: true);
}

/// `presence <email>`
Future<void> _presence(String email) async {
  final c = await _as(email);
  final rows = await c.from('now_watching').select();
  final profiles = {for (final p in await _profiles(c)) p['user_id']: p};
  final now = await _serverNow(c);
  _print([
    for (final r in rows)
      {
        'who': profiles[r['user_id']] == null
            ? r['user_id']
            : '${profiles[r['user_id']]!['display_name']} (@${profiles[r['user_id']]!['handle']})',
        ...r,
        'age_seconds': now.difference(DateTime.parse(r['updated_at'] as String)).inSeconds,
      }
  ]);
}

/// Task 2.2 (friend-presence): a friend's row arrives over Postgres Changes; a
/// stranger's and a blocked friend's don't; deleting an account removes its row.
Future<void> _presenceCheck(String emailA, String emailB, String emailX) async {
  var failures = 0;
  void check(bool ok, String what) {
    stdout.writeln('${ok ? 'ok  ' : 'FAIL'} $what');
    if (!ok) failures++;
  }

  final a = await _as(emailA), b = await _as(emailB), x = await _as(emailX);
  final idA = a.auth.currentUser!.id, idB = b.auth.currentUser!.id, idX = x.auth.currentUser!.id;

  // What A's subscription receives, by account.
  final seen = <String, List<Map<String, dynamic>>>{};
  final subscribed = Completer<void>();
  final channel = a
      .channel('presence-check')
      .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'now_watching',
          callback: (p) {
            final row = p.newRecord.isNotEmpty ? p.newRecord : p.oldRecord;
            final id = row['user_id'] as String?;
            if (id != null) (seen[id] ??= []).add({'event': p.eventType.name, ...row});
          })
      // Postgres Changes are live once Realtime says so, a moment after SUBSCRIBED.
      .onSystemEvents((payload) {
        if (payload is Map && payload['extension'] == 'postgres_changes' && payload['status'] == 'ok') {
          if (!subscribed.isCompleted) subscribed.complete();
        }
      })
      .subscribe((status, [err]) {
    if (err != null) stderr.writeln('realtime: $status $err');
  });
  await subscribed.future.timeout(const Duration(seconds: 15));
  check(true, 'A subscribed to Postgres Changes on now_watching');

  Future<bool> arrives(String id, bool Function(Map<String, dynamic>) match) async {
    final until = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(until)) {
      if (seen[id]?.any(match) ?? false) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  // A friend.
  final t0 = DateTime.now();
  await b.from('now_watching').upsert(_watching(idB, null, 'Presence Check', 'Friend Show'));
  check(await arrives(idB, (r) => r['title'] == 'Friend Show'),
      'B\'s row reaches A over Realtime (${DateTime.now().difference(t0).inMilliseconds} ms)');
  final readB = await a.from('now_watching').select().eq('user_id', idB);
  check(readB.length == 1 && readB.first['title'] == 'Friend Show', 'A reads B\'s row');
  check(readB.isNotEmpty && readB.first.keys.toSet().difference(
          {'user_id', 'title', 'channel_name', 'shared_channel_id', 'started_at', 'updated_at'}).isEmpty,
      'the row holds only title, channel, shared id and times');
  await b.from('now_watching').upsert(_cleared(idB));
  check(await arrives(idB, (r) => r['channel_name'] == null && r['event'] == 'update'),
      'B stopping (cleared row) reaches A');

  // A stranger.
  await x.from('now_watching').upsert(_watching(idX, null, 'Presence Check', 'Stranger Show'));
  check(!await arrives(idX, (_) => true), 'the stranger\'s row never reaches A');
  check((await a.from('now_watching').select().eq('user_id', idX)).isEmpty, 'A can\'t read the stranger\'s row');
  await b.from('now_watching').upsert(_watching(idB, null, 'Presence Check', 'Friend Show 2'));
  check((await x.from('now_watching').select().eq('user_id', idB)).isEmpty, 'the stranger can\'t read B\'s row');
  var anonRows = 0;
  try {
    anonRows = (await _anon().from('now_watching').select()).length;
  } on PostgrestException {
    anonRows = 0;
  }
  check(anonRows == 0, 'anonymous reads nothing');
  check((await a.from('now_watching').update({'title': 'Hacked'}).eq('user_id', idB).select()).isEmpty,
      'A can\'t change B\'s row');
  var insertRefused = false;
  try {
    await x.from('now_watching').insert(_watching(idA, null, 'Hijack', 'Hijack'));
  } on PostgrestException {
    insertRefused = true;
  }
  check(insertRefused, 'the stranger can\'t write A\'s row');

  // A temporary friend, then blocked, then deleted.
  final emailE = _taggedEmail('presence-${DateTime.now().millisecondsSinceEpoch}');
  await _admin().auth.admin.createUser(AdminUserAttributes(email: emailE, emailConfirm: true));
  final e = await _as(emailE);
  final idE = e.auth.currentUser!.id;
  await e.from('share_profiles').upsert({
    'user_id': idE,
    'display_name': 'Temp',
    'handle': 'tmp_${DateTime.now().millisecondsSinceEpoch % 100000000}',
  });
  final invite = await _fn(e, 'make-invite');
  final redeemed = await _fn(a, 'redeem-invite', {'code': invite['code']});
  check(redeemed['status'] == 'ok', 'A and a temporary account become friends');
  await e.from('now_watching').upsert(_watching(idE, null, 'Presence Check', 'Temp Show'));
  check(await arrives(idE, (r) => r['title'] == 'Temp Show'), 'the new friend\'s row reaches A');
  await a.from('blocks').insert({'blocker': idA, 'blocked': idE});
  seen.remove(idE);
  await e.from('now_watching').upsert(_watching(idE, null, 'Presence Check', 'Blocked Show'));
  check(!await arrives(idE, (r) => r['title'] == 'Blocked Show'), 'a blocked friend\'s row never reaches A');
  check((await a.from('now_watching').select().eq('user_id', idE)).isEmpty, 'A can\'t read the blocked friend\'s row');
  await a.from('blocks').delete().eq('blocker', idA).eq('blocked', idE);
  final deleted = await _fn(e, 'delete-account');
  check(deleted['status'] == 'ok', 'the temporary account is deleted');
  final left = await _admin().from('now_watching').select().eq('user_id', idE);
  check(left.isEmpty, 'deleting the account removed its row');

  await b.from('now_watching').upsert(_cleared(idB));
  await x.from('now_watching').upsert(_cleared(idX));
  await a.removeChannel(channel);
  stdout.writeln(failures == 0 ? 'Presence check passed' : 'Presence check: $failures failed');
  if (failures > 0) exit(1);
}

/// `presence-follow <email>`
Future<void> _presenceFollow(String email) async {
  final c = await _as(email);
  final profiles = {for (final p in await _profiles(c)) p['user_id']: p['display_name']};
  c
      .channel('presence-follow')
      .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'now_watching',
          callback: (p) {
            final r = p.newRecord.isNotEmpty ? p.newRecord : p.oldRecord;
            final t = DateTime.now().toIso8601String().substring(11, 23);
            stdout.writeln('$t ${p.eventType.name} ${profiles[r['user_id']] ?? r['user_id']}: '
                '${r['channel_name'] == null ? 'not watching' : '${r['title']} on ${r['channel_name']} (${r['shared_channel_id']})'}');
          })
      .onSystemEvents((payload) {
        if (payload is Map && payload['extension'] == 'postgres_changes' && payload['status'] == 'ok') {
          stdout.writeln('following');
        }
      })
      .subscribe();
  // Sign-ins last an hour; follow at most that long.
  await Future<void>.delayed(const Duration(minutes: 55));
}
