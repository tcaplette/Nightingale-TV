part of '../setup_server.dart';

/// YouTube on the server (docker-youtube D2, D3, D5): signing in with the
/// user's own Google client, the long wait for Google's answer, a new
/// client on an existing server, picking subscriptions, and what's on a
/// YouTube channel now for the Watch page. Tokens and client secrets never
/// leave the server or reach its log.
extension _YouTubeApi on SetupServer {
  List<ApiRoute> get _youTubeRoutes => [
        ApiRoute('POST', 'profiles/{id}/youtube/start', Access.profileSettings, _youTubeStart, revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/youtube/start/{run}', Access.profileSettings, _youTubeWait,
            revision: Revision.none),
        ApiRoute('POST', 'profiles/{id}/youtube/start/{run}/color', Access.profileSettings, _youTubeColor,
            revision: Revision.none),
        ApiRoute('DELETE', 'profiles/{id}/youtube/start/{run}', Access.profileSettings, _youTubeCancel,
            revision: Revision.none, checkIfMatch: false),
        ApiRoute('POST', 'profiles/{id}/servers/{key}/youtube/client', Access.profileSettings, _youTubeNewClient,
            revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/servers/{key}/youtube/channels', Access.profileSettings, _youTubeSubscriptions),
        ApiRoute('PUT', 'profiles/{id}/servers/{key}/youtube/channels', Access.profileSettings, _youTubePicks),
        ApiRoute('GET', 'profiles/{id}/youtube/channels', Access.profile, _youTubeWatchList),
        ApiRoute('GET', 'profiles/{id}/youtube/avatar', Access.profile, _youTubeAvatar, revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/youtube/{channel}/now', Access.profile, _youTubeNow),
      ];

  /// How long a wait for Google's answer is held open.
  static const youTubeWaitMax = Duration(seconds: 25);

  /// The sign-in slot of profile [id].
  static String _youTubeSlot(String id) => '$id/youtube';

  /// `{clientId, clientSecret}` as the user's own client; 400 without one.
  Future<GoogleClient> _ownClient(ApiRequest r) async {
    final body = await r.body();
    final id = body.string('clientId')?.trim() ?? '';
    final secret = body.string('clientSecret')?.trim() ?? '';
    ServerLog.secret(secret);
    if (id.isEmpty || secret.isEmpty) throw ApiError(HttpStatus.badRequest, tr.youTubeServerOwnClient);
    return GoogleClient(id: id, secret: secret, own: true);
  }

  /// A sign-in with the user's own client: adding YouTube to a signed-in
  /// profile, or signing a profile in with it.
  Future<Object?> _youTubeStart(ApiRequest r) async {
    final client = await _ownClient(r);
    final app = await _app(r['id']);
    return _youTubeBegin(r['id'], app, client,
        youTubeSignInFlow?.call(app, null) ?? SignInFlow(app, adding: app.session != null));
  }

  /// A new client on existing YouTube server `{key}` (Google client, and
  /// Sign in again, which always asks for the user's own client).
  Future<Object?> _youTubeNewClient(ApiRequest r) async {
    final client = await _ownClient(r);
    final app = await _app(r['id']);
    final key = r['key'];
    final server = app.servers.byKey(key) ?? (throw ApiError(HttpStatus.notFound, tr.noSuchServer));
    if (server.kind != ServerKind.youtube) throw ApiError(HttpStatus.badRequest, tr.noSuchServer);
    return _youTubeBegin(r['id'], app, client, youTubeSignInFlow?.call(app, key) ?? SignInFlow(app, againKey: key));
  }

  Future<Object?> _youTubeBegin(String id, AppState app, GoogleClient client, SignInFlow flow) async {
    final slot = _youTubeSlot(id);
    _signIns.remove(slot)?.flow.dispose();
    final before = {for (final s in app.servers.all) s.key};
    await flow.startYouTube(client: client);
    final step = flow.step;
    if (step.stage != SignInStage.youtubeCode || step.youtube.code == null) {
      flow.dispose();
      throw ApiError(HttpStatus.badRequest, step.error ?? tr.couldNotReachGoogle);
    }
    final s = _signIns[slot] = _SignIn(app, flow)
      ..run = _newRun()
      ..keysBefore = before;
    // Google said yes: the server is added (or signed in) with no channels
    // yet; the picker then works on it by its key (D3).
    flow.state.addListener(() {
      if (flow.step.stage == SignInStage.youtubePicker && !flow.step.busy && !s.picked) {
        s.picked = true;
        unawaited(flow.youTubePicked(const []));
      }
      _onYouTubeStep(id, s);
    });
    return {'run': s.run, ..._codeJson(step.youtube.code!)};
  }

  static String _newRun() {
    final rng = Random.secure();
    return List.generate(12, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static Map<String, Object?> _codeJson(DeviceCode code) => {
        'userCode': code.userCode,
        'verificationUrl': code.verificationUrl,
        'expiresAt': code.expiresAt.toUtc().toIso8601String(),
      };

  /// The sign-in finished (or reached its colour step): the profile's
  /// revision moves on, and the export picks up a new main sign-in.
  void _onYouTubeStep(String id, _SignIn s) {
    if (s.done || _youTubeKey(s) == null) return;
    s.done = true;
    for (final server in s.app.servers.all) {
      ServerLog.secret(server.session?.accessToken);
    }
    ServerLog.info('${household.profileById(id)?.name}: YouTube signed in.');
    _bumpProfile(id);
  }

  /// The YouTube server the sign-in in [s] made or signed in again; null
  /// until it has.
  String? _youTubeKey(_SignIn s) {
    final flow = s.flow;
    if (flow.step.stage == SignInStage.color) return flow.step.colorKey;
    if (!flow.finished) return null;
    if (flow.againKey case final key?) return key;
    if (!flow.adding) return ServerSet.mainKey;
    return s.app.servers.all
        .where((x) => x.kind == ServerKind.youtube && !s.keysBefore.contains(x.key))
        .map((x) => x.key)
        .firstOrNull;
  }

  _SignIn _youTubeRun(ApiRequest r) {
    final s = _signIns[_youTubeSlot(r['id'])];
    if (s == null || s.run != r['run']) throw ApiError(HttpStatus.notFound, tr.startSigningIn);
    return s;
  }

  /// Waits (up to [youTubeWaitMax]) for Google's answer: `pending`,
  /// `expired` with the new code, `cancelled` with why, or `done` with the
  /// server's key (and its colour step when it has one). `?code=` is the
  /// code the page shows.
  Future<Object?> _youTubeWait(ApiRequest r) async {
    final s = _youTubeRun(r);
    final shown = r.query['code'];
    Map<String, Object?>? answer() {
      final step = s.flow.step;
      final key = _youTubeKey(s);
      if (key != null) {
        return {
          'state': 'done',
          'serverKey': key,
          if (step.stage == SignInStage.color) 'color': _colorStepJson(s.app, key),
        };
      }
      final code = step.youtube.code;
      if (step.stage == SignInStage.youtubeCode && code != null) {
        if (shown != null && shown != code.userCode) return {'state': 'expired', ..._codeJson(code), 'error': ?step.error};
        return null;
      }
      if (step.stage == SignInStage.youtubePicker || step.busy) return null;
      return {'state': 'cancelled', 'error': step.error ?? tr.signInWasCancelled};
    }

    final end = clock().add(youTubeWaitMax);
    while (true) {
      if (answer() case final a?) return a;
      final left = end.difference(clock());
      if (left <= Duration.zero || _signIns[_youTubeSlot(r['id'])] != s) break;
      await _changeOf(s.flow.state, left);
    }
    final code = s.flow.step.youtube.code;
    return {'state': 'pending', if (code != null) ..._codeJson(code), 'error': ?s.flow.step.error};
  }

  /// The colour step's choice for the YouTube server just added.
  Future<Object?> _youTubeColor(ApiRequest r) async {
    final s = _youTubeRun(r);
    final name = (await r.body()).string('name');
    if (s.flow.step.stage != SignInStage.color) throw ApiError(HttpStatus.conflict, tr.couldntDoThat);
    if (ServerColor.byName(name) == null) throw ApiError(HttpStatus.badRequest, tr.couldntDoThat);
    await s.flow.chooseColor(name!);
    _signIns.remove(_youTubeSlot(r['id']));
    s.flow.dispose();
    return {'state': 'done', 'serverKey': ?_youTubeKey(s)};
  }

  /// Cancel: a code no longer waited for is dropped; on the colour step the
  /// server stays with the colour it has.
  Future<Object?> _youTubeCancel(ApiRequest r) async {
    final s = _youTubeRun(r);
    if (s.flow.step.stage == SignInStage.color) await s.flow.keepColor();
    _signIns.remove(_youTubeSlot(r['id']));
    s.flow.dispose();
    return {'state': 'cancelled'};
  }

  YouTubeServer _youTubeServer(AppState app, String key) {
    final server = app.servers.byKey(key) ?? (throw ApiError(HttpStatus.notFound, tr.noSuchServer));
    if (server.kind != ServerKind.youtube) throw ApiError(HttpStatus.badRequest, tr.noSuchServer);
    final yt = app.youtube.serverOf(key);
    if (yt == null || server.state == ServerState.needsSignIn) {
      throw ApiError(HttpStatus.conflict, tr.signInToYouTubeAgain, {'needs': 'signIn'});
    }
    return yt;
  }

  /// The daily limit's refusal, with when it resets.
  ApiError _dailyLimit(DateTime? until) => ApiError(HttpStatus.tooManyRequests, tr.youTubeDailyLimitShort,
      {if (until != null) 'until': until.toUtc().toIso8601String()});

  /// The account's subscriptions in title order, each with its picked
  /// state, then picks no longer subscribed to. No limit: every server here
  /// has its own client (D3).
  Future<Object?> _youTubeSubscriptions(ApiRequest r) async {
    final app = await _app(r['id']);
    final key = r['key'];
    final yt = _youTubeServer(app, key);
    if (yt.quotaBlockedUntil case final until?) throw _dailyLimit(until);
    final List<YouTubeSubscription> subs;
    try {
      subs = await yt.subscriptions();
    } on YouTubeQuotaException {
      throw _dailyLimit(yt.quotaBlockedUntil);
    } on ServerException catch (e) {
      if (e.statusCode == 401) throw ApiError(HttpStatus.conflict, tr.signInToYouTubeAgain, {'needs': 'signIn'});
      throw ApiError(HttpStatus.badGateway, tr.couldNotReachGoogle);
    }
    _youTubeSubs['${r['id']}/$key'] = subs;
    final picked = {for (final c in app.youTubeChannels) if (c.youtube!.serverKey == key) c.youtube!.channelId: c};
    final subscribed = {for (final s in subs) s.channelId};
    return {
      'subscriptions': [
        for (final s in subs) {...s.toJson(), 'checked': picked.containsKey(s.channelId)},
        for (final MapEntry(key: id, value: c) in picked.entries)
          if (!subscribed.contains(id))
            {
              'id': id,
              'title': c.name,
              if (c.icon.kind == ChannelIconKind.remote) 'avatar': c.icon.value,
              'checked': true,
              'subscribed': false,
            },
      ],
    };
  }

  /// `{"ids": [...]}`: server `{key}`'s picks, as the picker's Done. A
  /// channel for each new pick; unpicked ones go.
  Future<Object?> _youTubePicks(ApiRequest r) async {
    final app = await _app(r['id']);
    final key = r['key'];
    _youTubeServer(app, key);
    final ids = (await r.body()).strings('ids') ?? (throw ApiError(HttpStatus.badRequest, tr.couldntDoThat));
    final known = <String, YouTubeSubscription>{
      for (final c in app.youTubeChannels)
        if (c.youtube!.serverKey == key)
          c.youtube!.channelId: YouTubeSubscription(
              channelId: c.youtube!.channelId,
              title: c.name,
              avatarUrl: c.icon.kind == ChannelIconKind.remote ? c.icon.value : null),
      for (final s in _youTubeSubs['${r['id']}/$key'] ?? const <YouTubeSubscription>[]) s.channelId: s,
    };
    final picks = <YouTubeSubscription>[];
    for (final id in {...ids}) {
      picks.add(known[id] ?? (throw ApiError(HttpStatus.badRequest, tr.couldntDoThat)));
    }
    try {
      await app.setYouTubePicks(key, picks);
    } on StateError catch (e) {
      throw ApiError(HttpStatus.badRequest, e.message);
    }
    return {
      'channels': [
        for (final c in app.youTubeChannels)
          if (c.youtube!.serverKey == key) {'id': c.id, 'number': c.number, 'name': c.name}
      ],
    };
  }

  /// A YouTube channel's avatar for the picker, fetched here so the page
  /// loads nothing from elsewhere: only from YouTube's picture hosts.
  Future<Object?> _youTubeAvatar(ApiRequest r) async {
    await _app(r['id']);
    final uri = Uri.tryParse(r.query['url'] ?? '');
    const hosts = ['ggpht.com', 'googleusercontent.com', 'ytimg.com'];
    if (uri == null || !uri.isScheme('https') || !hosts.any((h) => uri.host == h || uri.host.endsWith('.$h'))) {
      throw ApiError(HttpStatus.notFound);
    }
    // A list row's size, not the 800 px YouTube often names.
    await _sendPicture(r, _smallAvatar(uri), null);
    return ApiRequest.handled;
  }

  /// [uri] at 88 px, for avatars from YouTube's picture hosts that take a
  /// size (`=s800-c-k…`); others as they are.
  static Uri _smallAvatar(Uri uri) {
    final sized = RegExp(r'=s\d+(-[^/]*)?$');
    if (!uri.host.endsWith('ggpht.com') && !uri.host.endsWith('googleusercontent.com')) return uri;
    return sized.hasMatch(uri.path) ? uri.replace(path: uri.path.replaceFirst(sized, '=s88-c-k-c0x00ffffff-no-rj')) : uri;
  }

  /// The profile's YouTube channels for the Watch page, with what's on now
  /// and next, and what the TV says about each YouTube server.
  Future<Object?> _youTubeWatchList(ApiRequest r) async {
    final app = await _app(r['id']);
    final now = clock();
    final notes = <Map<String, Object?>>[];
    for (final s in app.servers.all) {
      if (s.kind != ServerKind.youtube) continue;
      if (s.state == ServerState.needsSignIn) {
        notes.add({'serverKey': s.key, 'kind': 'signIn', 'text': tr.signInToYouTubeAgain});
      } else if (app.youtube.serverOf(s.key)?.quotaBlockedUntil case final until?) {
        notes.add({
          'serverKey': s.key,
          'kind': 'dailyLimit',
          'text': tr.youTubeDailyLimitShort,
          'until': until.toUtc().toIso8601String(),
        });
      }
    }
    return {
      'channels': [
        for (final c in app.youTubeChannels)
          {
            'id': c.id,
            'number': c.number,
            'name': c.displayName,
            if (c.icon.kind == ChannelIconKind.remote) 'avatar': c.icon.value,
            'serverKey': c.youtube!.serverKey,
            ...?_nowAndNext(app, c, now),
          }
      ],
      'notes': notes,
    };
  }

  /// What's on [c] at [now] and next, by title.
  static Map<String, Object?>? _nowAndNext(AppState app, Channel c, DateTime now) {
    final schedule = app.scheduleFor(c);
    if (schedule == null) return null;
    final on = schedule.playbackAt(now);
    if (on.item == null) return null;
    final next = schedule.playbackAt(on.end);
    return {
      'now': {'title': on.item!.title, 'start': on.start.toUtc().toIso8601String(), 'end': on.end.toUtc().toIso8601String()},
      if (next.item != null)
        'next': {'title': next.item!.title, 'start': next.start.toUtc().toIso8601String(), 'end': next.end.toUtc().toIso8601String()},
    };
  }

  /// What YouTube channel `{channel}` plays now, as the TV's tuner works it
  /// out (D5): the video, how far into it the schedule is, when it ends,
  /// and the next one. `?ended=<videoId>`: that video just ended, so the
  /// next one is asked for.
  Future<Object?> _youTubeNow(ApiRequest r) async {
    final app = await _app(r['id']);
    final c = app.channelById(r['channel']);
    if (c == null || !c.isYouTube) throw ApiError(HttpStatus.notFound, tr.noSuchChannel);
    if (app.servers.byKey(c.youtube!.serverKey)?.state == ServerState.needsSignIn) {
      throw ApiError(HttpStatus.conflict, tr.signInToYouTubeAgain, {'needs': 'signIn'});
    }
    final schedule = app.scheduleFor(c);
    final now = clock();
    var on = schedule?.playbackAt(now);
    if (schedule == null || on == null || on.item == null) throw ApiError(HttpStatus.notFound, tr.noVideosYet);
    final ended = r.query['ended'];
    // Near its end, or reported ended: the next one (as the tuner does).
    if (on.end.difference(now) < const Duration(seconds: 4) ||
        (ended != null && ServerSet.rawId(on.item!.sourceId) == ended)) {
      on = schedule.playbackAt(on.end);
      if (on.item == null) throw ApiError(HttpStatus.notFound, tr.noVideosYet);
    }
    final videoStart = on.start.subtract(on.itemFrom);
    final offset = now.difference(videoStart);
    final next = schedule.playbackAt(on.end);
    return {
      'channel': {'id': c.id, 'number': c.number, 'name': c.displayName},
      'videoId': ServerSet.rawId(on.item!.sourceId),
      'title': on.item!.title,
      'offsetSeconds': offset.isNegative ? 0 : offset.inSeconds,
      'endsAt': on.end.toUtc().toIso8601String(),
      'next': next.item == null ? null : {'videoId': ServerSet.rawId(next.item!.sourceId), 'title': next.item!.title},
    };
  }
}

/// Completes when [listenable] changes, or after [max].
Future<void> _changeOf(Listenable listenable, Duration max) {
  final done = Completer<void>();
  void changed() {
    if (!done.isCompleted) done.complete();
  }

  listenable.addListener(changed);
  final timer = Timer(max, changed);
  return done.future.whenComplete(() {
    timer.cancel();
    listenable.removeListener(changed);
  });
}
