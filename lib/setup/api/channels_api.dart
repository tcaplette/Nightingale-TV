part of '../setup_server.dart';

/// Channels, the main logo mode and premieres, the guide preview, custom
/// icons and channel logos (admin-api). Every change goes through the
/// AppState method the TV's channel editor calls.
extension _ChannelsApi on SetupServer {
  List<ApiRoute> get _channelRoutes => [
        ApiRoute('GET', 'profiles/{id}/channels', Access.profile, _channels),
        ApiRoute('POST', 'profiles/{id}/channels', Access.profileSettings, _addChannel),
        ApiRoute('POST', 'profiles/{id}/channels/reset', Access.profileSettings, _resetChannels),
        ApiRoute('GET', 'profiles/{id}/channels/{cid}', Access.profile, _channel),
        ApiRoute('PUT', 'profiles/{id}/channels/{cid}', Access.profileSettings, _editChannel),
        ApiRoute('PATCH', 'profiles/{id}/channels/{cid}', Access.profileSettings, _editChannel),
        ApiRoute('POST', 'profiles/{id}/channels/{cid}/reshuffle', Access.profileSettings, _reshuffleChannel),
        ApiRoute('DELETE', 'profiles/{id}/channels/{cid}', Access.profileSettings, _deleteChannel),
        ApiRoute('GET', 'profiles/{id}/channels/{cid}/logo', Access.profile, _channelLogo, revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/logo', Access.profile, _channelSettings),
        ApiRoute('PUT', 'profiles/{id}/logo', Access.profileSettings, _setLogo),
        ApiRoute('GET', 'profiles/{id}/premieres', Access.profile, _channelSettings),
        ApiRoute('PUT', 'profiles/{id}/premieres', Access.profileSettings, _setPremieres),
        ApiRoute('GET', 'profiles/{id}/retro', Access.profile, _channelSettings),
        ApiRoute('PUT', 'profiles/{id}/retro', Access.profileSettings, _setRetro),
        ApiRoute('GET', 'profiles/{id}/guide', Access.profile, _guide),
        ApiRoute('GET', 'profiles/{id}/icons', Access.profile, _icons),
        ApiRoute('POST', 'profiles/{id}/icons', Access.profileSettings, _uploadIcon),
        ApiRoute('GET', 'profiles/{id}/icons/{name}', Access.profile, _icon, revision: Revision.none),
        ApiRoute('DELETE', 'profiles/{id}/icons/{name}', Access.profileSettings, _deleteIcon),
      ];

  static const maxIcon = 5 << 20;
  static const iconTooBig = 'That picture is too big (5 MB at most).';
  static const maxGuideHours = 24;

  // ---- Channels -----------------------------------------------------------------

  Channel _channelOf(AppState app, String id) =>
      app.channelById(id) ?? (throw ApiError(HttpStatus.notFound, 'No such channel.'));

  /// [c]'s saved JSON (its playlist left to the server), with what the
  /// browser can't work out under "view".
  Map<String, Object?> _channelJson(AppState app, Channel c, DateTime now) {
    final schedule = app.scheduleFor(c);
    ScheduledProgram? on;
    try {
      on = schedule?.guideProgramAt(now);
    } on Object {
      on = null;
    }
    final live = c.live;
    final source = live == null ? null : app.live.sourceById(live.sourceId);
    final info = live == null ? null : app.live.lookup(c)?.info;
    return {
      ...c.toJson(),
      'playlist': const <String>[],
      'view': {
        'playlistLength': c.playlist.length,
        'auto': c.auto,
        'music': c.isMusic,
        'custom': c.isCustom,
        'playsPrograms': c.playsPrograms,
        'canReshuffle': app.canReshuffle(c),
        if (c.source.roots.isNotEmpty) 'missingRoots': [for (final r in c.source.roots) if (app.rootMissing(r)) r.itemId],
        'logoMode': app.logoModeFor(c).name,
        'retro': app.retroFor(c).toJson(),
        'mainRetro': app.settings.retro.toJson(),
        if (!c.isLive) 'plan': app.planFor(c).toJson(),
        'breaksPossible': !c.isLive && app.hasClipsFor(app.configuredPlanFor(c)),
        'hasLogo': switch (c.icon.kind) {
          ChannelIconKind.jellyfin || ChannelIconKind.custom || ChannelIconKind.remote => true,
          _ => false,
        },
        if (on != null)
          'now': {
            'title': on.title,
            'detail': on.detail,
            'start': on.start.toUtc().toIso8601String(),
            'end': on.end.toUtc().toIso8601String(),
          },
        if (live != null)
          'live': {
            'source': source?.name,
            'sourceId': live.sourceId,
            'number': live.sourceNumber,
            'hasSourceLogo': info?.logo != null,
            'sourceIcon': info == null ? null : LiveTvManager.defaultIcon(info).toJson(),
          },
      },
    };
  }

  Future<Object?> _channels(ApiRequest r) async {
    final app = await _app(r['id']);
    final now = clock();
    return {
      'logoMode': app.settings.logoMode.name,
      'retro': app.settings.retro.toJson(),
      'plan': app.settings.commercialPlan.toJson(),
      'premieres': app.settings.premieres.toJson(),
      'channels': [for (final c in app.allChannels) _channelJson(app, c, now)],
    };
  }

  Future<Object?> _channel(ApiRequest r) async {
    final app = await _app(r['id']);
    return _channelJson(app, _channelOf(app, r['cid']), clock());
  }

  /// The channel JSON sent back with changes: each changed field goes
  /// through the TV's own method (renumbering swaps, a new play order
  /// rebases its schedule).
  Future<Object?> _editChannel(ApiRequest r) async {
    final app = await _app(r['id']);
    final ch = _channelOf(app, r['cid']);
    final body = await r.body();
    // The whole model (as read, changed) is taken as it is, so a missing
    // logoMode or commercialPlan means "follow the main setting"; a few
    // fields alone change only those.
    final whole = body.containsKey('icon') && body.containsKey('source');
    bool has(String key) => whole || body.containsKey(key);
    _checkRetro(ChannelRetro.problemIn(body['retro']), body['retro']);
    final server = {'id': ch.id, 'playlist': ch.playlist, 'anchor': ch.anchor.toUtc().toIso8601String()};
    final Channel want;
    try {
      want = Channel.fromJson(whole ? {...body, ...server} : {...ch.toJson(), ...body, ...server});
    } on Object {
      throw ApiError(HttpStatus.badRequest, "That isn't a channel.");
    }
    if (body['slot'] != null && want.slotRule == null) {
      throw ApiError(HttpStatus.badRequest, 'Slot lengths are 15, 30, 60, 90 or 120 minutes.');
    }
    if (body['order'] != null && !PlaybackOrder.values.any((o) => o.name == body['order'])) {
      throw ApiError(HttpStatus.badRequest, "That isn't a play order.");
    }
    if (has('number') && want.number < 1) throw ApiError(HttpStatus.badRequest, 'Channel numbers start at 1.');
    if (has('order') && want.order != ch.order && ch.isMusic && want.order != PlaybackOrder.random) {
      throw ApiError(HttpStatus.badRequest, 'Music channels only shuffle.');
    }
    String json(Object? o) => jsonEncode(o);
    // A source is checked first: a refused change changes nothing else.
    if (has('source') && json(want.source.toJson()) != json(ch.source.toJson())) {
      try {
        await app.setChannelSource(ch, _customSource(body.object('source') ?? const {}));
      } on StateError catch (e) {
        throw ApiError(HttpStatus.badRequest, e.message);
      }
    }
    await app.updateChannel(ch,
        name: has('name') && want.name != ch.name ? want.name : null,
        number: has('number') && want.number != ch.number ? want.number : null,
        hidden: has('hidden') && want.hidden != ch.hidden ? want.hidden : null,
        favorite: has('favorite') && want.favorite != ch.favorite ? want.favorite : null,
        order: has('order') && want.order != ch.order && !ch.isLive ? want.order : null,
        icon: has('icon') && json(want.icon.toJson()) != json(ch.icon.toJson()) ? want.icon : null);
    if (has('logoMode') && want.logoMode != ch.logoMode) await app.setChannelLogoMode(ch, want.logoMode);
    if (has('retro') && want.retro != ch.retro) await app.setChannelRetro(ch, want.retro);
    if ((has('commercialPlan') || body.containsKey('commercials')) &&
        !ch.isLive &&
        json(want.commercialPlan?.toJson()) != json(ch.commercialPlan?.toJson())) {
      await app.setChannelPlan(ch, want.commercialPlan);
    }
    if (has('premieres') && want.premieres != ch.premieres && !ch.isLive) {
      await app.setChannelPremieres(ch, want.premieres);
    }
    if (has('slot') && want.slotRule != ch.slotRule && ch.playsPrograms) {
      await app.setSlotRule(ch, want.slotRule);
    } else if (body['slot'] != null && !ch.playsPrograms) {
      throw ApiError(HttpStatus.badRequest, "This channel doesn't have slots.");
    }
    return _channelJson(app, ch, clock());
  }

  /// A source as the TV's editor makes it: episodes only when shows or
  /// genres are picked, so roots or movies alone don't mean every show.
  static ChannelSource _customSource(Map<String, Object?> json) => ChannelSource.fromJson({
        'episodes': (json['seriesKeys'] as List?)?.isNotEmpty == true || (json['genres'] as List?)?.isNotEmpty == true,
        ...json,
      });

  Future<Object?> _reshuffleChannel(ApiRequest r) async {
    final app = await _app(r['id']);
    final ch = _channelOf(app, r['cid']);
    try {
      await app.reshuffleChannel(ch);
    } on StateError catch (e) {
      throw ApiError(HttpStatus.badRequest, e.message);
    }
    return _channelJson(app, ch, clock());
  }

  /// A block channel (`{"kind": "block", "name"}`), a music channel
  /// (`{"kind": "music", "name", "source": {songs, musicVideos, genres,
  /// decades}}`) or a custom channel (`{"kind": "custom", "name", "source":
  /// {roots, seriesKeys, genres, movies}, "order"}`).
  Future<Object?> _addChannel(ApiRequest r) async {
    final app = await _app(r['id']);
    final body = await r.body();
    final name = body.string('name') ?? '';
    final Channel ch;
    switch (body.string('kind')) {
      case 'block':
        ch = await app.createBlockChannel(name);
      case 'music':
        final source = ChannelSource.fromJson({...?body.object('source'), 'episodes': false, 'movies': false});
        try {
          ch = await app.createMusicChannel(name, source);
        } on StateError catch (e) {
          throw ApiError(HttpStatus.badRequest, e.message);
        }
      case 'custom':
        final order = body['order'];
        if (order != null && !PlaybackOrder.values.any((o) => o.name == order)) {
          throw ApiError(HttpStatus.badRequest, "That isn't a play order.");
        }
        try {
          ch = await app.createCustomChannel(name, _customSource(body.object('source') ?? const {}),
              order: order == null ? PlaybackOrder.random : PlaybackOrder.parse(order));
        } on StateError catch (e) {
          throw ApiError(HttpStatus.badRequest, e.message);
        }
      default:
        throw ApiError(HttpStatus.badRequest, 'The kind is "block", "music" or "custom".');
    }
    return _channelJson(app, ch, clock());
  }

  Future<Object?> _deleteChannel(ApiRequest r) async {
    final app = await _app(r['id']);
    try {
      await app.deleteUserChannel(_channelOf(app, r['cid']));
    } on StateError catch (e) {
      throw ApiError(HttpStatus.badRequest, e.message);
    }
    return {'ok': true};
  }

  /// Reset lineup: a safety backup first; if it can't be saved, nothing is
  /// reset.
  Future<Object?> _resetChannels(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    try {
      await app.resetChannels();
    } on BackupException catch (e) {
      throw ApiError(HttpStatus.conflict, "Couldn't save a safety backup first, so nothing was reset: ${e.message}");
    } on Object catch (e) {
      throw ApiError(HttpStatus.conflict, "Couldn't save a safety backup first, so nothing was reset: $e");
    }
    return _channels(r);
  }

  /// The main logo mode and premiere settings.
  Future<Object?> _channelSettings(ApiRequest r) async {
    final app = await _app(r['id']);
    return {
      'logoMode': app.settings.logoMode.name,
      'premieres': app.settings.premieres.toJson(),
      'retro': app.settings.retro.toJson(),
    };
  }

  /// Refuses retro settings with an unknown value, or a surround image that
  /// isn't a name in the custom logos folder.
  static void _checkRetro(String? problem, Object? json) {
    if (problem != null) throw ApiError(HttpStatus.badRequest, problem);
    final image = json is Map ? json['surroundImage'] : null;
    if (image is String && !_iconName.hasMatch(image)) {
      throw ApiError(HttpStatus.badRequest, "That isn't a picture in the custom logos folder.");
    }
  }

  /// The main retro look and the Custom style: what's in the body changes,
  /// the rest stays.
  Future<Object?> _setRetro(ApiRequest r) async {
    final app = await _app(r['id']);
    final body = await r.body();
    final edit = body.object('retro') ?? body;
    _checkRetro(RetroSettings.problemIn(edit), edit);
    final now = app.settings.retro.toJson();
    await app.setMainRetro(RetroSettings.fromJson({
      ...now,
      ...edit,
      if (edit['custom'] is Map) 'custom': {...now['custom'] as Map, ...edit['custom'] as Map},
      if (edit['accents'] is Map) 'accents': {...now['accents'] as Map, ...edit['accents'] as Map},
    }));
    return _channelSettings(r);
  }

  Future<Object?> _setLogo(ApiRequest r) async {
    final app = await _app(r['id']);
    final mode = LogoMode.parse((await r.body()).string('logoMode')) ??
        (throw ApiError(HttpStatus.badRequest, 'The logo mode is always, nowAndThen or off.'));
    await app.setMainLogoMode(mode);
    return _channelSettings(r);
  }

  Future<Object?> _setPremieres(ApiRequest r) async {
    final app = await _app(r['id']);
    final body = await r.body();
    final PremiereSettings premieres;
    try {
      premieres = PremiereSettings.fromJson(body.object('premieres') ?? body);
    } on Object {
      throw ApiError(HttpStatus.badRequest, "Those aren't premiere settings.");
    }
    await app.setPremiereSettings(premieres);
    return _channelSettings(r);
  }

  /// Channel `{cid}`'s logo picture: a show's server logo, an upload, or a
  /// live source's logo (`?source=1`: the source's own, whatever the
  /// channel uses). Built-in icons and badges are drawn by the browser.
  Future<Object?> _channelLogo(ApiRequest r) async {
    final app = await _app(r['id']);
    final ch = _channelOf(app, r['cid']);
    var icon = ch.icon;
    if (r.query['source'] == '1') {
      final info = app.live.lookup(ch)?.info ?? (throw ApiError(HttpStatus.notFound));
      icon = LiveTvManager.defaultIcon(info);
    }
    switch (icon.kind) {
      case ChannelIconKind.jellyfin:
        final client = app.clientOf(icon.value) ?? (throw ApiError(HttpStatus.notFound));
        await _sendPicture(r, client.imageUri(icon.value, ImageKind.logo, maxHeight: 160), client.authHeaders);
      case ChannelIconKind.custom:
        await _sendFile(r, app.icons.fileFor(icon.value));
      case ChannelIconKind.remote:
        final uri = Uri.tryParse(icon.value);
        if (uri == null || !uri.hasScheme || !uri.isScheme('http') && !uri.isScheme('https')) {
          throw ApiError(HttpStatus.notFound);
        }
        // A sign-in goes only to its own server (any of the profile's).
        final client = app.servers.all
            .map((s) => s.client)
            .where((c) => c != null && icon.value.startsWith(c.serverUrl))
            .firstOrNull;
        await _sendPicture(r, uri, client?.authHeaders);
      case ChannelIconKind.builtin || ChannelIconKind.badge:
        throw ApiError(HttpStatus.notFound);
    }
    return ApiRequest.handled;
  }

  // ---- Guide ----------------------------------------------------------------------

  /// What airs on each channel the guide shows, for up to 24 hours from
  /// `from` (default: the start of this hour): the TV guide's slots, which
  /// are the export's XMLTV programmes, with their breaks.
  Future<Object?> _guide(ApiRequest r) async {
    final app = await _app(r['id']);
    final now = clock();
    final from = DateTime.tryParse(r.query['from'] ?? '')?.toLocal() ?? DateTime(now.year, now.month, now.day, now.hour);
    final hours = (int.tryParse(r.query['hours'] ?? '') ?? 6).clamp(1, maxGuideHours);
    final to = from.add(Duration(hours: hours));
    String iso(DateTime t) => t.toUtc().toIso8601String();
    return {
      'from': iso(from),
      'to': iso(to),
      'channels': [
        for (final c in app.channels)
          {
            'id': c.id,
            'number': c.number,
            'name': c.name,
            'icon': c.icon.toJson(),
            'airings': [
              if (app.scheduleFor(c) case final schedule?)
                for (final p in schedule.guideProgramsBetween(from, to))
                  {
                    'start': iso(p.start),
                    'end': iso(p.end),
                    'title': p.title,
                    'detail': p.detail,
                    if (p.isOffAir) 'offAir': true,
                    'block': ?p.blockTitle,
                    if (p.isPremiere) 'premiere': true,
                    if (p.isLive) 'live': true,
                    if (p.isMusicHour) 'songs': p.songs!.length,
                    if (p.endsEarly) 'endsEarly': true,
                    'breaks': ?_breaksOf(schedule, p),
                  },
            ],
          },
      ],
    };
  }

  /// [p]'s breaks, in seconds, when its channel has any.
  static Map<String, Object?>? _breaksOf(ProgramSchedule schedule, ScheduledProgram p) {
    final item = p.item;
    if (schedule is! ChannelSchedule || item == null || p.isMusicHour || p.isLive) return null;
    final plan = schedule.slotPlanFor(item, ruled: p.blockTitle == null && !p.isPremiere);
    final total = plan.preRoll + plan.midLength * plan.midCount + plan.postRoll + plan.tail;
    if (total == Duration.zero) return null;
    return {
      'preRoll': plan.preRoll.inSeconds,
      'mids': plan.midCount,
      'midLength': plan.midLength.inSeconds,
      'postRoll': plan.postRoll.inSeconds,
      'tail': plan.tail.inSeconds,
    };
  }

  // ---- Custom icons -----------------------------------------------------------------

  static final _iconName = RegExp(r'^(offline-)?[0-9a-f]{16}\.(png|svg)$');

  Future<Object?> _icons(ApiRequest r) async {
    final app = await _app(r['id']);
    return {'icons': await app.icons.list()};
  }

  /// An uploaded picture (`?name=` its file name, for its type), checked
  /// and stored as the TV's icon import does; with `?kind=offline`, as a
  /// channel's offline image. More than 5 MB is refused before it's all
  /// read.
  Future<Object?> _uploadIcon(ApiRequest r) async {
    final app = await _app(r['id']);
    final bytes = await r.bytes(maxIcon, iconTooBig);
    try {
      if (r.query['kind'] == 'offline') {
        return {'name': await app.icons.importOfflineBytes(bytes, r.query['name'] ?? 'upload.png')};
      }
      final name = await app.icons.importBytes(bytes, r.query['name'] ?? 'upload.png');
      return {'name': name, 'icon': ChannelIcon(kind: ChannelIconKind.custom, value: name).toJson()};
    } on CustomIconException catch (e) {
      throw ApiError(HttpStatus.badRequest, e.message);
    }
  }

  Future<Object?> _icon(ApiRequest r) async {
    final name = r['name'];
    if (!_iconName.hasMatch(name)) throw ApiError(HttpStatus.notFound);
    final app = await _app(r['id']);
    await _sendFile(r, app.icons.fileFor(name));
    return ApiRequest.handled;
  }

  Future<Object?> _deleteIcon(ApiRequest r) async {
    final name = r['name'];
    if (!_iconName.hasMatch(name)) throw ApiError(HttpStatus.notFound);
    final app = await _app(r['id']);
    await app.deleteCustomIcon(name);
    return {'icons': await app.icons.list()};
  }

  Future<void> _sendFile(ApiRequest r, File file) async {
    if (!await file.exists()) throw ApiError(HttpStatus.notFound);
    r.response.headers
      ..contentType = file.path.endsWith('.svg') ? ContentType('image', 'svg+xml') : ContentType('image', 'png')
      ..set('Cache-Control', 'private, max-age=3600')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'");
    await r.response.addStream(file.openRead());
  }
}
