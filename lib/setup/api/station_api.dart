part of '../setup_server.dart';

/// Channel groups and guide tabs, programming blocks, and commercials
/// (admin-api), each over the AppState method the TV's screen calls.
extension _StationApi on SetupServer {
  List<ApiRoute> get _stationRoutes => [
        ApiRoute('GET', 'profiles/{id}/groups', Access.profile, _groups),
        ApiRoute('POST', 'profiles/{id}/groups', Access.profileSettings, _addGroup),
        ApiRoute('PUT', 'profiles/{id}/groups/{gid}', Access.profileSettings, _renameGroup),
        ApiRoute('DELETE', 'profiles/{id}/groups/{gid}', Access.profileSettings, _deleteGroup),
        ApiRoute('PUT', 'profiles/{id}/groups/{gid}/channels', Access.profileSettings, _setGroupChannels),
        ApiRoute('GET', 'profiles/{id}/tabs', Access.profile, _groups),
        ApiRoute('PUT', 'profiles/{id}/tabs', Access.profileSettings, _setTabs),
        ApiRoute('GET', 'profiles/{id}/blocks', Access.profile, _blocks),
        ApiRoute('POST', 'profiles/{id}/blocks', Access.profileSettings, _addBlock),
        ApiRoute('GET', 'profiles/{id}/blocks/{bid}', Access.profile, _block),
        ApiRoute('PUT', 'profiles/{id}/blocks/{bid}', Access.profileSettings, _saveBlock),
        ApiRoute('DELETE', 'profiles/{id}/blocks/{bid}', Access.profileSettings, _deleteBlock),
        ApiRoute('GET', 'profiles/{id}/blocks/{bid}/playlist', Access.profile, _blockPlaylist),
        ApiRoute('POST', 'profiles/{id}/blocks/preview', Access.profile, _previewBlock, revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/commercials', Access.profile, _commercials),
        ApiRoute('PUT', 'profiles/{id}/commercials/plan', Access.profileSettings, _setGlobalPlan),
        ApiRoute('PUT', 'profiles/{id}/channels/{cid}/plan', Access.profileSettings, _setChannelPlan),
        ApiRoute('POST', 'profiles/{id}/pools', Access.profileSettings, _addPool),
        ApiRoute('PUT', 'profiles/{id}/pools/{pid}', Access.profileSettings, _updatePool),
        ApiRoute('DELETE', 'profiles/{id}/pools/{pid}', Access.profileSettings, _deletePool),
        ApiRoute('PUT', 'profiles/{id}/pools/{pid}/roots', Access.profileSettings, _setPoolRoots),
      ];

  // ---- Groups and tabs ---------------------------------------------------------

  ChannelGroup _groupOf(AppState app, String id) =>
      app.settings.groups.where((g) => g.id == id).firstOrNull ?? (throw ApiError(HttpStatus.notFound, 'No such group.'));

  Future<Object?> _groups(ApiRequest r) async {
    final app = await _app(r['id']);
    return {
      'groups': [for (final g in app.settings.groups) g.toJson()],
      'tabs': [
        for (final id in app.allTabIds)
          {
            'id': id,
            'name': app.tabName(id),
            'hidden': app.settings.hiddenTabs.contains(id),
            'group': app.settings.groups.any((g) => g.id == id),
          },
      ],
    };
  }

  Future<Object?> _addGroup(ApiRequest r) async {
    final app = await _app(r['id']);
    final group = await app.createGroup((await r.body()).string('name') ?? '');
    final channels = (await r.body()).strings('channelIds');
    if (channels != null) await _putInGroup(app, group, channels);
    return {...await _groups(r) as Map<String, Object?>, 'created': group.id};
  }

  Future<Object?> _renameGroup(ApiRequest r) async {
    final app = await _app(r['id']);
    final name = (await r.body()).string('name') ?? '';
    if (name.trim().isEmpty) throw ApiError(HttpStatus.badRequest, 'Give the group a name.');
    await app.renameGroup(_groupOf(app, r['gid']), name);
    return _groups(r);
  }

  Future<Object?> _deleteGroup(ApiRequest r) async {
    final app = await _app(r['id']);
    await app.deleteGroup(_groupOf(app, r['gid']));
    return _groups(r);
  }

  /// Makes the group hold exactly `channelIds`, through the TV's
  /// one-at-a-time membership changes.
  Future<Object?> _setGroupChannels(ApiRequest r) async {
    final app = await _app(r['id']);
    final ids = (await r.body()).strings('channelIds') ?? (throw ApiError(HttpStatus.badRequest, 'Send channelIds.'));
    await _putInGroup(app, _groupOf(app, r['gid']), ids);
    return _groups(r);
  }

  Future<void> _putInGroup(AppState app, ChannelGroup group, List<String> ids) async {
    final want = ids.toSet();
    for (final id in want) {
      if (app.channelById(id) == null) throw ApiError(HttpStatus.badRequest, 'No such channel.');
    }
    for (final id in [...group.channelIds]) {
      final ch = app.channelById(id);
      if (!want.contains(id) && ch != null) await app.setInGroup(group, ch, false);
    }
    for (final id in ids) {
      if (!group.channelIds.contains(id)) await app.setInGroup(group, app.channelById(id)!, true);
    }
  }

  /// The tabs' order (`order`, All first) and the hidden ones (`hidden`),
  /// through the TV's moves and hide switches.
  Future<Object?> _setTabs(ApiRequest r) async {
    final app = await _app(r['id']);
    final body = await r.body();
    if (body.strings('order') case final order?) {
      final known = app.allTabIds;
      if (order.toSet().length != known.length || !order.toSet().containsAll(known)) {
        throw ApiError(HttpStatus.badRequest, 'Send every tab once.');
      }
      for (var i = 1; i < order.length; i++) {
        final at = app.allTabIds.indexOf(order[i]);
        if (at != i && order[i] != GuideTabs.all) await app.moveTab(order[i], i - at);
      }
    }
    if (body.strings('hidden') case final hidden?) {
      final want = hidden.toSet();
      for (final id in app.allTabIds) {
        final now = app.settings.hiddenTabs.contains(id);
        if (now != want.contains(id)) await app.setTabHidden(id, want.contains(id));
      }
    }
    return _groups(r);
  }

  // ---- Blocks ---------------------------------------------------------------------

  ProgramBlock _blockOf(AppState app, String id) =>
      app.blocks.where((b) => b.id == id).firstOrNull ?? (throw ApiError(HttpStatus.notFound, 'No such block.'));

  Map<String, Object?> _blockJson(AppState app, ProgramBlock b) => {
        ...b.toJson(),
        'playlist': const <String>[],
        'view': {
          'playlistLength': b.playlist.length,
          'channel': app.channelById(b.channelId)?.name,
          'describe': describeBlock(b),
        },
      };

  Future<Object?> _blocks(ApiRequest r) async {
    final app = await _app(r['id']);
    return {
      'blocks': [for (final b in app.blocks) _blockJson(app, b)],
      'newBlock': app.newBlock().toJson(),
      // Kid profiles get no minimum rating or late-night shortcut.
      'kidProfile': app.maxRatingRank != null,
    };
  }

  Future<Object?> _block(ApiRequest r) async {
    final app = await _app(r['id']);
    return _blockJson(app, _blockOf(app, r['bid']));
  }

  /// [body]'s block, with the playlist and anchor the server keeps.
  ProgramBlock _decodeBlock(Map<String, Object?> body, {ProgramBlock? existing, required String id}) {
    try {
      final json = body.object('block') ?? body;
      return ProgramBlock.fromJson({
        ...json,
        'id': id,
        'playlist': existing?.playlist ?? const <String>[],
        'anchor': (existing?.anchor ?? DateTime.now()).toIso8601String(),
      });
    } on ApiError {
      rethrow;
    } on Object {
      throw ApiError(HttpStatus.badRequest, "That isn't a programming block.");
    }
  }

  /// Saves [block] under the TV's rules; with `newChannel`, on a new
  /// block channel named after it; `lineupMode`: it plays a lineup.
  Future<ProgramBlock> _saveChecked(AppState app, ProgramBlock block, Map<String, Object?> body) async {
    final newChannel = body.boolean('newChannel') ?? false;
    // New roots are fetched first, as the TV's editor does when they're added.
    await app.resolveRoots(block.source.roots);
    final problem = app.blockProblem(block, newChannel: newChannel, lineupMode: body.boolean('lineupMode') ?? block.hasLineup);
    if (problem != null) throw ApiError(HttpStatus.badRequest, problem);
    if (newChannel) block.channelId = (await app.createBlockChannel(block.title)).id;
    await app.saveBlock(block);
    return block;
  }

  Future<Object?> _addBlock(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    final body = await r.body();
    final block = _decodeBlock(body, id: app.newBlock().id);
    return _blockJson(app, await _saveChecked(app, block, body));
  }

  Future<Object?> _saveBlock(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    final existing = _blockOf(app, r['bid']);
    final body = await r.body();
    final block = _decodeBlock(body, existing: existing, id: existing.id);
    return _blockJson(app, await _saveChecked(app, block, body));
  }

  Future<Object?> _deleteBlock(ApiRequest r) async {
    final app = await _app(r['id']);
    await app.deleteBlock(_blockOf(app, r['bid']));
    return {'ok': true};
  }

  /// What a block plays, resolved by the server: at most 500 items, with
  /// the total.
  Future<Object?> _blockPlaylist(ApiRequest r) async {
    final app = await _app(r['id']);
    final block = _blockOf(app, r['bid']);
    return _playlistJson(app, app.blockPlaylist(block));
  }

  /// What an unsaved block would play, and its next airing.
  Future<Object?> _previewBlock(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    final body = await r.body();
    final block = _decodeBlock(body, id: body.object('block')?['id'] as String? ?? app.newBlock().id);
    final existing = app.blocks.where((b) => b.id == block.id).firstOrNull;
    if (existing != null) {
      block
        ..playlist = existing.playlist
        ..anchor = existing.anchor;
    }
    await app.resolveRoots(block.source.roots);
    final preview = app.previewBlock(block, (body.boolean('newChannel') ?? false) ? null : block.channelId);
    String iso(DateTime t) => t.toUtc().toIso8601String();
    return {
      ..._playlistJson(app, app.blockPlaylist(block)),
      'problem': app.blockProblem(block,
          newChannel: body.boolean('newChannel') ?? false, lineupMode: body.boolean('lineupMode') ?? block.hasLineup),
      if (preview != null)
        'next': {
          'start': iso(preview.airing.start),
          'end': iso(preview.airing.end),
          'programs': [
            for (final p in preview.programs.take(50)) {'title': p.title, 'detail': p.detail, 'start': iso(p.start)},
          ],
        },
    };
  }

  static Map<String, Object?> _playlistJson(AppState app, List<String> ids) => {
        'total': ids.length,
        'items': [
          for (final id in ids.take(500))
            if (app.library[id] case final e?) {'id': id, 'title': e.guideTitle, 'detail': e.subtitle},
        ],
      };

  // ---- Commercials ----------------------------------------------------------------

  CommercialPool _poolOf(AppState app, String id) =>
      app.poolById(id) ?? (throw ApiError(HttpStatus.notFound, 'No such pool.'));

  Future<Object?> _commercials(ApiRequest r) async {
    final app = await _app(r['id']);
    return {
      'plan': app.settings.commercialPlan.toJson(),
      'pools': [
        for (final p in app.settings.commercialPools)
          {
            ...p.toJson(),
            'view': {'clips': app.catalog.clipsFor(p.id).length},
          },
      ],
      'clips': app.catalog.clipsFor(null).length,
      'channels': [
        for (final c in app.allChannels)
          if (!c.isLive) {'id': c.id, 'number': c.number, 'name': c.name, 'plan': c.commercialPlan?.toJson()},
      ],
    };
  }

  BreakPlan? _decodePlan(Object? json) {
    if (json == null) return null;
    if (json is! Map<String, Object?>) throw ApiError(HttpStatus.badRequest, "That isn't a break plan.");
    try {
      return BreakPlan.fromJson(json);
    } on Object {
      throw ApiError(HttpStatus.badRequest, "That isn't a break plan.");
    }
  }

  Future<Object?> _setGlobalPlan(ApiRequest r) async {
    final app = await _app(r['id']);
    final plan = _decodePlan((await r.body())['plan']) ?? (throw ApiError(HttpStatus.badRequest, 'Send a plan.'));
    await app.setGlobalPlan(plan);
    return _commercials(r);
  }

  /// A channel's own plan; `{"plan": null}` follows the main one again.
  Future<Object?> _setChannelPlan(ApiRequest r) async {
    final app = await _app(r['id']);
    final ch = app.channelById(r['cid']) ?? (throw ApiError(HttpStatus.notFound, 'No such channel.'));
    if (ch.isLive) throw ApiError(HttpStatus.badRequest, 'Live channels have no breaks.');
    await app.setChannelPlan(ch, _decodePlan((await r.body())['plan']));
    return _commercials(r);
  }

  Future<Object?> _addPool(ApiRequest r) async {
    final app = await _app(r['id']);
    final pool = await app.createPool();
    final name = (await r.body()).string('name');
    if (name != null && name.trim().isNotEmpty) await app.renamePool(pool, name);
    return {...await _commercials(r) as Map<String, Object?>, 'created': pool.id};
  }

  /// A pool's new `name`, `kind` (`commercials` or `bumpers`), or both.
  Future<Object?> _updatePool(ApiRequest r) async {
    final app = await _app(r['id']);
    final body = await r.body();
    final name = body['name'] == null && body['kind'] != null ? null : body.string('name') ?? '';
    if (name != null && name.trim().isEmpty) throw ApiError(HttpStatus.badRequest, 'Give the pool a name.');
    final PoolKind? kind = switch (body['kind']) {
      null => null,
      final k => PoolKind.values.asNameMap()[k] ?? (throw ApiError(HttpStatus.badRequest, "That isn't a pool type.")),
    };
    final pool = _poolOf(app, r['pid']);
    if (name != null) await app.renamePool(pool, name);
    if (kind != null) await app.setPoolKind(pool, kind);
    return _commercials(r);
  }

  Future<Object?> _deletePool(ApiRequest r) async {
    final app = await _app(r['id']);
    await app.deletePool(_poolOf(app, r['pid']));
    return _commercials(r);
  }

  /// The folders a pool draws from (`roots`: PoolRoot JSON); a re-scan
  /// follows, as on the TV.
  Future<Object?> _setPoolRoots(ApiRequest r) async {
    final app = await _app(r['id']);
    final list = (await r.body())['roots'];
    if (list is! List) throw ApiError(HttpStatus.badRequest, 'Send roots.');
    final List<PoolRoot> roots;
    try {
      roots = [for (final j in list.cast<Map<String, Object?>>()) PoolRoot.fromJson(j)];
    } on Object {
      throw ApiError(HttpStatus.badRequest, "Those aren't pool folders.");
    }
    await app.setPoolRoots(_poolOf(app, r['pid']), roots);
    return _commercials(r);
  }
}
