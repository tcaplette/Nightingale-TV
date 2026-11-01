part of '../setup_server.dart';

/// A profile's servers (multi-server, admin-api): the list with state and
/// item counts, adding one and signing one in again with the same steps as
/// `profiles/{id}/sign-in` (Plex link code included), removing one, the
/// Play from order and each server's quality limit. No token ever leaves
/// the server.
extension _ServersApi on SetupServer {
  List<ApiRoute> get _serverRoutes => [
        ApiRoute('GET', 'profiles/{id}/servers', Access.profile, (r) async => _serversJson(await _app(r['id'])),
            revision: Revision.none),
        ApiRoute('POST', 'profiles/{id}/servers', Access.profileSettings, _addServerStep, revision: Revision.none),
        ApiRoute('POST', 'profiles/{id}/servers/{key}/sign-in', Access.profileSettings, _serverSignInStep,
            revision: Revision.none),
        ApiRoute('DELETE', 'profiles/{id}/servers/{key}', Access.profileSettings, _removeServer),
        ApiRoute('PUT', 'profiles/{id}/servers/order', Access.profileSettings, _orderServers),
        ApiRoute('PATCH', 'profiles/{id}/servers/{key}', Access.profileSettings, _editServer),
      ];

  Map<String, Object?> _serversJson(AppState app) {
    final counts = app.serverCounts();
    return {
      'servers': [
        for (final s in app.servers.ordered)
          {
            'key': s.key,
            'main': s.isMain,
            'name': s.name,
            'kind': s.kind.name,
            'url': s.serverUrl,
            'user': s.userName,
            'state': s.state.name,
            'stateLabel': s.state.label,
            'qualityLimitKbps': s.qualityLimitKbps,
            'episodes': counts[s.key]?.episodes ?? 0,
            'movies': counts[s.key]?.movies ?? 0,
            'songs': counts[s.key]?.songs ?? 0,
          }
      ],
      'order': app.servers.order,
    };
  }

  /// Add a server: `{"action": "start"}`, then the sign-in steps.
  Future<Object?> _addServerStep(ApiRequest r) {
    final id = r['id'];
    return _signInStepIn(r, '$id/add', (app) async {
      final flow = serverSignInFlow?.call(app, null) ?? SignInFlow(app, adding: true);
      return (flow: flow, onStep: (_SignIn s) => _onServerSignIn(id, s));
    });
  }

  /// Sign in again to `{key}`, pre-filled from what's known of it.
  Future<Object?> _serverSignInStep(ApiRequest r) {
    final id = r['id'], key = r['key'];
    return _signInStepIn(r, '$id/again/$key', (app) async {
      if (app.servers.byKey(key) == null) throw ApiError(HttpStatus.notFound, 'No such server.');
      final flow = serverSignInFlow?.call(app, key) ?? SignInFlow(app, againKey: key);
      return (flow: flow, onStep: (_SignIn s) => _onServerSignIn(id, s));
    });
  }

  /// A server added or signed in again: its tokens never reach the log.
  void _onServerSignIn(String id, _SignIn s) {
    if (!s.flow.finished || s.done) return;
    s.done = true;
    for (final server in s.app.servers.all) {
      ServerLog.secret(server.session?.accessToken);
      ServerLog.secret(server.session?.accountToken);
    }
    ServerLog.info('${household.profileById(id)?.name}: servers now ${[for (final x in s.app.servers.ordered) x.name].join(', ')}.');
    _bumpProfile(id);
    unawaited(Future<void>(s.flow.dispose));
  }

  Future<Object?> _removeServer(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    final server = app.servers.byKey(r['key']) ?? (throw ApiError(HttpStatus.notFound, 'No such server.'));
    if (server.isMain) throw ApiError(HttpStatus.conflict, 'Sign out of the profile to change its main server.');
    await app.removeServer(server.key);
    return _serversJson(app);
  }

  /// `{"order": ["s2", "main"]}`: every key, in Play from order.
  Future<Object?> _orderServers(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    final order = (await r.body()).strings('order') ?? (throw ApiError(HttpStatus.badRequest, '"order" is missing.'));
    if (order.length != app.servers.order.length || !order.toSet().containsAll(app.servers.order)) {
      throw ApiError(HttpStatus.badRequest, '"order" should name every server once.');
    }
    for (final (i, key) in order.indexed) {
      await app.moveServer(key, i - app.servers.order.indexOf(key));
    }
    return _serversJson(app);
  }

  /// `{"qualityLimitKbps": 2000}`, or null for the profile's.
  Future<Object?> _editServer(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    final server = app.servers.byKey(r['key']) ?? (throw ApiError(HttpStatus.notFound, 'No such server.'));
    final body = await r.body();
    if (body.containsKey('qualityLimitKbps')) {
      final kbps = body.integer('qualityLimitKbps');
      if (kbps != null && kbps < 500) throw ApiError(HttpStatus.badRequest, 'A quality limit is at least 500 kbps.');
      await app.setServerQualityLimit(server.key, kbps);
    }
    return _serversJson(app);
  }
}
