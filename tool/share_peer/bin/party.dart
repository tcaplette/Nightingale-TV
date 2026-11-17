// Watch-together commands (watch-together D9): the peer as a party host without a player,
// as a guest, and one-shot actions and reactions. See the file header of share_peer.dart.
part of 'share_peer.dart';

/// The six party reactions, in the party row's order.
const _reactions = ['😂', '😮', '❤️', '👏', '😱', '🍿'];

String _clock() => DateTime.now().toIso8601String().substring(11, 23);

void _log(String line) => stdout.writeln('${_clock()} $line');

/// The backend clock's offset from this machine's: the sample with the shortest round trip
/// of [samples] (D3).
Future<Duration> _clockOffset(SupabaseClient c, {int samples = 5}) async {
  ({Duration rtt, Duration offset})? best;
  for (var i = 0; i < samples; i++) {
    final sent = DateTime.now();
    final server = await _serverNow(c);
    final rtt = DateTime.now().difference(sent);
    final offset = server.add(rtt ~/ 2).difference(DateTime.now());
    if (best == null || rtt < best.rtt) best = (rtt: rtt, offset: offset);
  }
  return best!.offset;
}

/// A party's two Realtime topics, joined as [c]: `party:<id>` (actions, reactions,
/// hello/bye) and `party:<id>:host` (the timeline).
class _PartyLink {
  _PartyLink(this.c, this.party);

  final SupabaseClient c;
  final String party;
  late final RealtimeChannel room;
  late final RealtimeChannel host;
  final names = <String, String>{};

  String name(Object? id) => names[id] ?? '$id';

  static Map<String, dynamic> _inner(Map<String, dynamic> m) =>
      m['payload'] is Map ? Map<String, dynamic>.from(m['payload'] as Map) : m;

  /// Joins both topics; [on] gets each message as (topic kind, event, payload).
  Future<void> join(void Function(String event, Map<String, dynamic> payload) on) async {
    final token = c.auth.currentSession?.accessToken;
    if (token != null) await c.realtime.setAuth(token);
    for (final p in await _profiles(c)) {
      names[p['user_id'] as String] = p['display_name'] as String;
    }
    Future<RealtimeChannel> open(String topic, List<String> events) async {
      final ready = Completer<void>();
      var ch = c.channel(topic, opts: const RealtimeChannelConfig(private: true));
      for (final e in events) {
        ch = ch.onBroadcast(event: e, callback: (m) => on(e, _inner(m)));
      }
      ch.subscribe((status, [err]) {
        if (status == RealtimeSubscribeStatus.subscribed && !ready.isCompleted) ready.complete();
        if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
          if (!ready.isCompleted) ready.completeError('$topic: $status ${err ?? ''}');
        }
      });
      await ready.future.timeout(const Duration(seconds: 15));
      return ch;
    }

    room = await open('party:$party', const ['action', 'reaction', 'hello', 'bye']);
    host = await open('party:$party:host', const ['timeline']);
  }

  Future<ChannelResponse> say(String event, Map<String, dynamic> payload) =>
      room.sendBroadcastMessage(event: event, payload: payload);

  Future<ChannelResponse> timeline(Map<String, dynamic> payload) =>
      host.sendBroadcastMessage(event: 'timeline', payload: payload);

  Future<void> close() async {
    await c.removeAllChannels();
  }
}

/// A recipe's items as party items: each episode carries its show (the timeline holds one
/// item, so there's no show list to index).
List<Map<String, dynamic>> _partyItems(Map<String, dynamic> recipe) {
  final shows = [for (final s in recipe['shows'] as List? ?? const []) Map<String, dynamic>.from(s as Map)];
  return [
    for (final raw in recipe['items'] as List? ?? const [])
      if (raw is Map)
        {
          ...Map<String, dynamic>.from(raw)..remove('s'),
          if (raw['s'] is int) 'show': shows[raw['s'] as int],
        }
  ];
}

String _itemLabel(Map<String, dynamic>? item) {
  if (item == null) return '-';
  if (item['m'] is Map) return '${(item['m'] as Map)['t']} (${(item['m'] as Map)['y'] ?? '?'})';
  final show = item['show'] is Map ? (item['show'] as Map)['name'] : '?';
  return '$show S${item['se'] ?? '?'}E${item['ep'] ?? '?'} "${item['t']}"';
}

/// `party-host <email> <recipe.json> [--invite <handle>…] [--link] [--start <i>] [--offset <s>]`
///   `[--break <i>:<at s>:<length s>]… [--for <s>] [--channel <name>]`
///
/// Walks the recipe's items on a simulated clock: item `<i>` from `<offset>`, each for its runtime,
/// with the given break windows. Broadcasts a timeline on every change and every 5 seconds,
/// writes the party's state every 30 seconds, applies members' actions, and logs actions,
/// reactions, joins and leaves. Commands on stdin: pause, resume, skip <s>, restart, live,
/// next, `react <emoji>`, `invite <handle>`, leave.
Future<void> _partyHost(List<String> a) async {
  final email = a[0];
  final recipe = Map<String, dynamic>.from(jsonDecode(File(a[1]).readAsStringSync()) as Map);
  final items = _partyItems(recipe);
  if (items.isEmpty) throw StateError('the recipe has no items');
  final invite = <String>[];
  var link = false, start = 0, offset = 0, runFor = 0;
  var channel = recipe['name'] as String? ?? 'Party Channel';
  final breaks = <int, List<({int at, int length})>>{};
  for (var i = 2; i < a.length; i++) {
    switch (a[i]) {
      case '--invite':
        while (i + 1 < a.length && !a[i + 1].startsWith('--')) {
          invite.add(a[++i]);
        }
      case '--link':
        link = true;
      case '--start':
        start = int.parse(a[++i]);
      case '--offset':
        offset = int.parse(a[++i]);
      case '--for':
        runFor = int.parse(a[++i]);
      case '--channel':
        channel = a[++i];
      case '--break':
        final p = a[++i].split(':').map(int.parse).toList();
        (breaks[p[0]] ??= []).add((at: p[1], length: p[2]));
    }
  }
  final c = await _as(email);
  final me = c.auth.currentUser!.id;
  final offsetToServer = await _clockOffset(c);
  int now() => DateTime.now().add(offsetToServer).millisecondsSinceEpoch;
  _log('clock offset ${offsetToServer.inMilliseconds} ms');

  // The simulated channel.
  var index = start % items.length;
  var anchor = now() - offset * 1000; // backend ms at which position 0 plays
  var playing = true;
  int? pausedAt;
  var seq = 0;
  final done = <int>{}; // breaks of the current item already played (by index in its list)
  Map<String, dynamic>? lastBy;

  int runtimeMs(int i) => ((items[i]['rt'] as num?) ?? 0).toInt() * 1000;
  List<({int at, int length})> breaksOf(int i) => breaks[i] ?? const [];
  int partyNow() => playing ? now() : pausedAt!;
  int position() => partyNow() - anchor;

  /// The current item's next break that hasn't played, as a window on the party clock.
  ({int index, int startMs, int lengthMs})? pendingBreak() {
    final list = breaksOf(index);
    for (var k = 0; k < list.length; k++) {
      if (done.contains(k)) continue;
      return (index: k, startMs: anchor + list[k].at * 1000, lengthMs: list[k].length * 1000);
    }
    return null;
  }

  Map<String, dynamic> timeline() {
    final b = pendingBreak();
    final next = (index + 1) % items.length;
    return {
      'v': 1,
      'seq': seq,
      'item': items[index],
      'title': items[index]['show'] is Map ? (items[index]['show'] as Map)['name'] : (items[index]['m'] as Map?)?['t'],
      'anchorMs': anchor,
      'playing': playing,
      'pausedAt': pausedAt,
      'break': b == null ? null : {'startMs': b.startMs, 'lengthMs': b.lengthMs},
      'next': items[next],
      'by': lastBy,
      'sentMs': now(),
    };
  }

  final started = await _fn(c, 'start-party', {
    'channel_name': channel,
    'state': timeline(),
    'invite': [for (final h in invite) await _idForHandle(c, h)],
    'link': link,
  });
  if (started['status'] != 'ok') throw StateError('start-party: $started');
  final party = (started['party'] as Map)['id'] as String;
  _log('party $party started on "$channel"${started['code'] == null ? '' : ' code ${started['code']}'}');
  stdout.writeln('PARTY $party');

  final link_ = _PartyLink(c, party);
  var ending = false;

  Future<void> publish({Map<String, dynamic>? by}) async {
    seq++;
    lastBy = by;
    final t = timeline();
    final r = await link_.timeline(t);
    final b = t['break'] as Map?;
    _log('timeline seq=$seq ${_itemLabel(items[index])} pos=${(position() / 1000).toStringAsFixed(1)}s '
        '${playing ? 'playing' : 'paused'}${b == null ? '' : ' break@${((b['startMs'] as int) - anchor) ~/ 1000}s+${(b['lengthMs'] as int) ~/ 1000}s'}'
        '${by == null ? '' : ' by=${link_.name(by['user'])}:${by['kind']}'} ($r)');
  }

  void apply(String kind, String by, {int byMs = 0}) {
    final t = now();
    switch (kind) {
      case 'pause':
        if (!playing) return;
        playing = false;
        pausedAt = t;
      case 'resume':
        if (playing) return;
        final paused = t - pausedAt!;
        anchor += paused;
        playing = true;
        pausedAt = null;
      case 'skip':
        final rt = runtimeMs(index);
        final pos = (position() + byMs).clamp(0, rt);
        anchor = partyNow() - pos;
        // Breaks behind the new position have played.
        final list = breaksOf(index);
        for (var k = 0; k < list.length; k++) {
          if (list[k].at * 1000 < pos) {
            done.add(k);
          } else {
            done.remove(k);
          }
        }
      case 'restart':
        anchor = partyNow();
        done.clear();
      case 'live':
        if (!playing) {
          playing = true;
          pausedAt = null;
        }
      case 'next':
        index = (index + 1) % items.length;
        anchor = partyNow();
        done.clear();
      default:
        return;
    }
    unawaited(publish(by: {'user': by, 'kind': kind == 'skip' ? (byMs < 0 ? 'back' : 'forward') : kind}));
  }

  await link_.join((event, p) {
    switch (event) {
      case 'action':
        _log('action by ${link_.name(p['by'])}: ${p['kind']}${p['byMs'] == null ? '' : ' ${p['byMs']} ms'}');
        apply(p['kind'] as String? ?? '', p['by'] as String? ?? '', byMs: (p['byMs'] as num?)?.toInt() ?? 0);
      case 'reaction':
        _log('reaction by ${link_.name(p['by'])}: ${p['emoji']}');
      case 'hello':
        _log('hello from ${link_.name(p['by'])}');
        // A newcomer gets the timeline at once.
        unawaited(publish(by: lastBy));
      case 'bye':
        _log('bye from ${link_.name(p['by'])}');
    }
  });
  await publish();

  // The simulated clock: breaks end, items end.
  final tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
    if (!playing || ending) return;
    final b = pendingBreak();
    final t = now();
    if (b != null && t >= b.startMs + b.lengthMs) {
      done.add(b.index);
      anchor += b.lengthMs;
      unawaited(publish());
      return;
    }
    if (b == null && position() >= runtimeMs(index)) {
      index = (index + 1) % items.length;
      anchor = t;
      done.clear();
      unawaited(publish());
    }
  });
  final beat = Timer.periodic(const Duration(seconds: 5), (_) {
    if (!ending) unawaited(link_.timeline(timeline()));
  });
  final save = Timer.periodic(const Duration(seconds: 30), (_) async {
    if (ending) return;
    try {
      await c.from('watch_parties').update({'state': timeline()}).eq('id', party);
    } on Object catch (e) {
      _log('state write: $e');
    }
  });

  final finished = Completer<void>();
  Future<void> leave() async {
    if (ending) return;
    ending = true;
    tick.cancel();
    beat.cancel();
    save.cancel();
    await link_.say('bye', {'by': me, 'ended': true});
    final r = await _fn(c, 'leave-party', {'party': party});
    _log('left: $r');
    await link_.close();
    if (!finished.isCompleted) finished.complete();
  }

  final input = stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) async {
    final w = line.trim().split(RegExp(r'\s+'));
    switch (w.first) {
      case 'pause' || 'resume' || 'restart' || 'live' || 'next':
        _log('host: ${w.first}');
        apply(w.first, me);
      case 'skip':
        final s = w.length > 1 ? int.parse(w[1]) : 30;
        _log('host: skip $s s');
        apply('skip', me, byMs: s * 1000);
      case 'react':
        final r = await link_.say('reaction', {'by': me, 'emoji': w.length > 1 ? w[1] : _reactions.first});
        _log('host reacted ${w.length > 1 ? w[1] : _reactions.first} ($r)');
      case 'invite':
        _log('invite: ${await _fn(c, 'start-party', {'party': party, 'invite': [await _idForHandle(c, w[1])]})}');
      case 'leave' || 'quit':
        await leave();
    }
  }, onError: (Object _) {});
  if (runFor > 0) Timer(Duration(seconds: runFor), () => unawaited(leave()));
  await finished.future;
  await input.cancel();
}

/// The party to act in for [c]: [arg] (an id), else the newest party [c] is invited to or in.
Future<String> _partyFor(SupabaseClient c, String? arg) async {
  if (arg != null && arg != '-') return arg;
  final me = c.auth.currentUser!.id;
  final invites = await c
      .from('party_invites')
      .select('party_id, created_at')
      .eq('invitee', me)
      .inFilter('state', ['new', 'joined'])
      .order('created_at', ascending: false)
      .limit(1);
  if (invites.isNotEmpty) return invites.first['party_id'] as String;
  final mine = await c
      .from('party_members')
      .select('party_id, joined_at')
      .eq('user_id', me)
      .isFilter('left_at', null)
      .order('joined_at', ascending: false)
      .limit(1);
  if (mine.isEmpty) throw StateError('no party to join');
  return mine.first['party_id'] as String;
}

/// `party-join <email> [<party>|-] [--for <s>]`
///
/// Joins as a guest and logs each timeline (the program, its position by the backend clock,
/// play state, break) with the actions it carries, and reactions, joins and leaves. Commands
/// on stdin: pause, resume, `skip <s>`, restart, live, `react <emoji>`, leave.
Future<void> _partyJoin(List<String> a) async {
  final c = await _as(a[0]);
  final me = c.auth.currentUser!.id;
  final party = await _partyFor(c, a.length > 1 && !a[1].startsWith('--') ? a[1] : null);
  var runFor = 0;
  final i = a.indexOf('--for');
  if (i >= 0) runFor = int.parse(a[i + 1]);
  final joined = await _fn(c, 'join-party', {'party': party});
  if (joined['status'] != 'ok') throw StateError('join-party: $joined');
  final offsetToServer = await _clockOffset(c);
  int now() => DateTime.now().add(offsetToServer).millisecondsSinceEpoch;
  _log('joined $party (clock offset ${offsetToServer.inMilliseconds} ms)');
  final link_ = _PartyLink(c, party);
  var lastSeq = -1;
  var lastBeat = DateTime.now();
  await link_.join((event, p) {
    switch (event) {
      case 'timeline':
        lastBeat = DateTime.now();
        final seq = (p['seq'] as num?)?.toInt() ?? 0;
        if (seq == lastSeq) return;
        lastSeq = seq;
        final playing = p['playing'] == true;
        final t = playing ? now() : (p['pausedAt'] as num).toInt();
        final pos = t - (p['anchorMs'] as num).toInt();
        final b = p['break'] as Map?;
        final inBreak = b != null && t >= (b['startMs'] as num) && t < (b['startMs'] as num) + (b['lengthMs'] as num);
        final by = p['by'] as Map?;
        _log('timeline seq=$seq ${_itemLabel(p['item'] as Map<String, dynamic>?)} pos=${(pos / 1000).toStringAsFixed(1)}s '
            '${playing ? 'playing' : 'paused'}'
            '${b == null ? '' : ' break=${(((b['startMs'] as num) - (p['anchorMs'] as num)) / 1000).toStringAsFixed(1)}s+${((b['lengthMs'] as num) / 1000).toStringAsFixed(0)}s${inBreak ? ' (now)' : ''}'}'
            '${by == null ? '' : ' by=${link_.name(by['user'])}:${by['kind']}'}');
      case 'action':
        _log('action by ${link_.name(p['by'])}: ${p['kind']}${p['byMs'] == null ? '' : ' ${p['byMs']} ms'}');
      case 'reaction':
        _log('reaction by ${link_.name(p['by'])}: ${p['emoji']}');
      case 'hello':
        _log('hello from ${link_.name(p['by'])}');
      case 'bye':
        _log('bye from ${link_.name(p['by'])}${p['ended'] == true ? ' (ended the party)' : ''}');
    }
  });
  await link_.say('hello', {'by': me});
  final finished = Completer<void>();
  var leaving = false;
  Future<void> leave() async {
    if (leaving) return;
    leaving = true;
    await link_.say('bye', {'by': me});
    _log('left: ${await _fn(c, 'leave-party', {'party': party})}');
    await link_.close();
    if (!finished.isCompleted) finished.complete();
  }

  final watchdog = Timer.periodic(const Duration(seconds: 5), (_) async {
    if (DateTime.now().difference(lastBeat) > const Duration(seconds: 60) && !leaving) {
      _log('no host heartbeat for 60 s');
      leaving = true;
      _log('left: ${await _fn(c, 'leave-party', {'party': party, 'reason': 'host-gone'})}');
      await link_.close();
      if (!finished.isCompleted) finished.complete();
    }
  });
  final input = stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) async {
    final w = line.trim().split(RegExp(r'\s+'));
    switch (w.first) {
      case 'pause' || 'resume' || 'restart' || 'live':
        _log('send ${w.first} (${await link_.say('action', {'by': me, 'kind': w.first})})');
      case 'skip':
        final s = w.length > 1 ? int.parse(w[1]) : 30;
        _log('send skip $s s (${await link_.say('action', {'by': me, 'kind': 'skip', 'byMs': s * 1000})})');
      case 'react':
        _log('reacted (${await link_.say('reaction', {'by': me, 'emoji': w.length > 1 ? w[1] : _reactions.first})})');
      case 'leave' || 'quit':
        await leave();
    }
  }, onError: (Object _) {});
  if (runFor > 0) Timer(Duration(seconds: runFor), () => unawaited(leave()));
  await finished.future;
  watchdog.cancel();
  await input.cancel();
}

/// `react|pause|resume|skip|restart|live|leave <email> <party|-> [emoji|seconds]`: one message as
/// a member (joining first if it isn't one).
Future<void> _partyOnce(String cmd, List<String> a) async {
  final c = await _as(a[0]);
  final me = c.auth.currentUser!.id;
  final party = await _partyFor(c, a.length > 1 ? a[1] : null);
  if (cmd == 'leave') {
    _print(await _fn(c, 'leave-party', {'party': party}));
    return;
  }
  final joined = await _fn(c, 'join-party', {'party': party});
  if (joined['status'] != 'ok') throw StateError('join-party: $joined');
  final link_ = _PartyLink(c, party);
  await link_.join((_, _) {});
  final r = switch (cmd) {
    'react' => await link_.say('reaction', {'by': me, 'emoji': a.length > 2 ? a[2] : _reactions.first}),
    'skip' => await link_.say('action', {'by': me, 'kind': 'skip', 'byMs': (a.length > 2 ? int.parse(a[2]) : 30) * 1000}),
    _ => await link_.say('action', {'by': me, 'kind': cmd}),
  };
  _log('$cmd sent ($r)');
  // Give the socket a moment to deliver before closing.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await link_.close();
}

/// `party-check <A> <B> <stranger>`: the watch-together data rules (task 2.4). A hosts and
/// invites B; the stranger listens on both topics and receives nothing; B can't publish a
/// timeline; the 9th member is refused; the host leaving ends the party. Makes and deletes
/// temporary accounts for the size limit.
Future<void> _partyCheck(String emailA, String emailB, String emailX) async {
  var failures = 0;
  void check(bool ok, String what) {
    stdout.writeln('${ok ? 'ok  ' : 'FAIL'} $what');
    if (!ok) failures++;
  }

  final a = await _as(emailA);
  await Future<void>.delayed(const Duration(seconds: 2));
  final b = await _as(emailB);
  await Future<void>.delayed(const Duration(seconds: 2));
  final x = await _as(emailX);
  final idA = a.auth.currentUser!.id, idB = b.auth.currentUser!.id, idX = x.auth.currentUser!.id;

  final started = await _fn(a, 'start-party', {
    'channel_name': 'Party Check',
    'state': {'title': 'Check Show'},
    'invite': [idB],
    'link': true,
  });
  check(started['status'] == 'ok', 'A starts a party inviting B (${started['status']})');
  final party = (started['party'] as Map)['id'] as String;
  check(started['code'] is String, 'start-party made a watch code');

  // Invites and rows.
  final invB = await b.from('party_invites').select().eq('party_id', party);
  check(invB.length == 1 && invB.first['state'] == 'new', 'B reads its invite');
  final partyB = await b.from('watch_parties').select('state').eq('id', party);
  check(partyB.length == 1 && (partyB.first['state'] as Map)['title'] == 'Check Show', 'B (invited) reads the party\'s title');
  check((await x.from('watch_parties').select().eq('id', party)).isEmpty, 'the stranger can\'t read the party');
  check((await x.from('party_members').select().eq('party_id', party)).isEmpty, 'the stranger can\'t read its members');
  check((await x.from('party_invites').select().eq('party_id', party)).isEmpty, 'the stranger can\'t read its invites');
  check((await b.from('watch_parties').update({'state': {'title': 'Hijack'}}).eq('id', party).select()).isEmpty,
      'B can\'t write the party\'s state');
  var strangerJoin = await _fn(x, 'join-party', {'party': party});
  check(strangerJoin['status'] == 'not_allowed', 'the stranger can\'t join (${strangerJoin['status']})');

  // The preview.
  final code = started['code'] as String;
  final preview = await http.get(Uri.parse('$_url/functions/v1/invite-preview?code=$code'));
  final previewBody = preview.statusCode == 200 ? jsonDecode(preview.body) as Map : const {};
  check(preview.statusCode == 200 && previewBody['kind'] == 'watch' && (previewBody['show'] as Map?)?['title'] == 'Check Show',
      'invite-preview answers kind watch with show.title (${preview.statusCode} ${preview.body})');

  final joinedB = await _fn(b, 'join-party', {'party': party});
  check(joinedB['status'] == 'ok', 'B joins');

  // Realtime: A, B and the stranger on the topics.
  final seenB = <String>[], seenA = <String>[], seenX = <String>[];
  final la = _PartyLink(a, party), lb = _PartyLink(b, party);
  await la.join((e, p) => seenA.add('$e:${p['tag']}'));
  await lb.join((e, p) => seenB.add('$e:${p['tag']}'));
  var strangerJoined = true;
  final lx = _PartyLink(x, party);
  try {
    await lx.join((e, p) => seenX.add('$e:${p['tag']}'));
  } on Object catch (e) {
    strangerJoined = false;
    stdout.writeln('     (the stranger\'s subscribe was refused: $e)');
  }
  await la.timeline({'tag': 't1'});
  await la.say('reaction', {'by': idA, 'emoji': '😂', 'tag': 'r1'});
  await lb.say('action', {'by': idB, 'kind': 'pause', 'tag': 'a1'});
  await lb.timeline({'tag': 'forged'});
  if (strangerJoined) {
    await lx.say('reaction', {'by': idX, 'emoji': '🍿', 'tag': 'x1'});
    await lx.timeline({'tag': 'x2'});
  }
  await Future<void>.delayed(const Duration(seconds: 3));
  check(seenB.contains('timeline:t1'), 'B receives A\'s timeline');
  check(seenB.contains('reaction:r1'), 'B receives A\'s reaction');
  check(seenA.contains('action:a1'), 'A receives B\'s action');
  check(!seenA.contains('timeline:forged'), 'B can\'t publish a timeline (A never receives it)');
  check(seenX.isEmpty, 'the stranger receives nothing on the party topics');
  check(!seenA.contains('reaction:x1') && !seenB.contains('reaction:x1') && !seenA.contains('timeline:x2'),
      'the stranger can\'t send to the party');
  // The REST path, with the public key and the stranger's sign-in.
  final rest = await http.post(Uri.parse('$_url/realtime/v1/api/broadcast'),
      headers: {
        'apikey': _key,
        'Authorization': 'Bearer ${x.auth.currentSession!.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'messages': [
          {'topic': 'party:$party', 'event': 'reaction', 'payload': {'tag': 'x3'}, 'private': true}
        ]
      }));
  await Future<void>.delayed(const Duration(seconds: 2));
  check(!seenA.contains('reaction:x3'), 'the stranger\'s REST broadcast doesn\'t arrive (HTTP ${rest.statusCode})');

  // The size limit: 6 temporary friends bring it to 8; a 9th is refused.
  final temps = <SupabaseClient>[];
  final stamp = DateTime.now().millisecondsSinceEpoch;
  for (var i = 0; i < 7; i++) {
    final email = _taggedEmail('party-$stamp-$i');
    await _admin().auth.admin.createUser(AdminUserAttributes(email: email, emailConfirm: true));
    final t = await _as(email);
    await t.from('share_profiles').upsert({
      'user_id': t.auth.currentUser!.id,
      'display_name': 'Party $i',
      'handle': 'pty_${stamp % 1000000}_$i',
    });
    final inv = await _fn(a, 'make-invite');
    final r = await _fn(t, 'redeem-invite', {'code': inv['code']});
    if (r['status'] != 'ok') stdout.writeln('     (temp $i redeem: $r)');
    temps.add(t);
  }
  final joins = [for (final t in temps) (await _fn(t, 'join-party', {'party': party}))['status']];
  check(joins.take(6).every((s) => s == 'ok'), '6 more friends join, 8 in all (${joins.take(6).join(', ')})');
  check(joins.last == 'full', 'the 9th join is refused (${joins.last})');

  // The host leaves: the party ends for everyone.
  final left = await _fn(a, 'leave-party', {'party': party});
  check(left['status'] == 'ok' && left['ended'] == true, 'the host leaving ends the party');
  final rowB = await b.from('party_members').select('left_at').eq('party_id', party).eq('user_id', idB);
  check(rowB.isNotEmpty && rowB.first['left_at'] != null, 'B is no longer a member');
  final ended = await b.from('watch_parties').select('ended_at').eq('id', party);
  check(ended.isNotEmpty && ended.first['ended_at'] != null, 'B sees the party ended');
  final again = await _fn(b, 'join-party', {'party': party});
  check(again['status'] == 'ended', 'joining an ended party is refused (${again['status']})');
  final after = await http.get(Uri.parse('$_url/functions/v1/invite-preview?code=$code'));
  check(after.statusCode == 404, 'the ended party\'s watch link previews as 404 (${after.statusCode})');

  // A guest's host-gone is refused while the host still writes; deleting the host deletes the party.
  final p2 = await _fn(a, 'start-party', {'channel_name': 'Party Check 2', 'state': {'title': 'Two'}, 'invite': [idB]});
  final party2 = (p2['party'] as Map)['id'] as String;
  await _fn(b, 'join-party', {'party': party2});
  final gone = await _fn(b, 'leave-party', {'party': party2, 'reason': 'host-gone'});
  check(gone['ended'] == false, 'host-gone is refused while the host is writing');
  final p3 = await _fn(temps.first, 'start-party', {'channel_name': 'Temp Party', 'state': {'title': 'T'}});
  final party3 = (p3['party'] as Map)['id'] as String;

  await la.close();
  await lb.close();
  if (strangerJoined) await lx.close();
  for (final t in temps) {
    await _fn(t, 'delete-account');
  }
  check((await _admin().from('watch_parties').select().eq('id', party3)).isEmpty,
      'deleting the host\'s account deleted its party');
  check((await _admin().from('party_members').select().eq('party_id', party).eq('user_id', temps.first.auth.currentUser!.id)).isEmpty,
      'deleting a member\'s account deleted its rows');
  await _fn(a, 'leave-party', {'party': party2});
  stdout.writeln(failures == 0 ? 'Party check passed' : 'Party check: $failures failed');
  if (failures > 0) exit(1);
}
