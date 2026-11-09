
part of '../setup_server.dart';

/// Signing in to the web admin, the first admin and admin resets, the
/// signed-in account, users (admin) and PIN unlocks (user-accounts).
extension _AccountsApi on SetupServer {
  List<ApiRoute> get _accountRoutes => [
        ApiRoute('GET', 'auth', Access.public, _auth),
        ApiRoute('POST', 'password', Access.public, _setupPassword),
        ApiRoute('POST', 'session', Access.public, _signIn),
        ApiRoute('DELETE', 'session', Access.public, _signOut),
        ApiRoute('GET', 'me', Access.signedIn, (r) async => _me(r)),
        ApiRoute('PUT', 'me/password', Access.signedIn, _changeOwnPassword),
        ApiRoute('GET', 'users', Access.admin, (r) async => _users(), revision: Revision.household),
        ApiRoute('POST', 'users', Access.admin, _addUser, revision: Revision.household),
        ApiRoute('GET', 'users/{uid}', Access.admin, (r) async => _user(r['uid']), revision: Revision.household),
        ApiRoute('PUT', 'users/{uid}', Access.admin, _updateUser, revision: Revision.household),
        ApiRoute('DELETE', 'users/{uid}', Access.admin, _removeUser, revision: Revision.household),
        ApiRoute('PUT', 'users/{uid}/password', Access.admin, _setUserPassword, revision: Revision.household),
        ApiRoute('PUT', 'users/{uid}/profiles', Access.admin, _setUserProfiles, revision: Revision.household),
        ApiRoute('POST', 'profiles/{id}/unlock', Access.signedIn, _unlock, revision: Revision.none),
      ];

  /// Whether the setup link's token is [token].
  bool _tokenIs(String? token) => token != null && token == accounts.setupToken;

  /// Sign-in state; with the setup token, what it's for (the first admin,
  /// or an admin reset with the admins to choose from).
  Future<Object?> _auth(ApiRequest r) async {
    final token = r.query['token'];
    final withToken = _tokenIs(token);
    return {
      'password': accounts.hasUsers,
      'signedIn': r.account != null,
      if (r.account != null) 'me': _me(r),
      if (withToken) 'setup': accounts.hasUsers ? 'reset' : 'first',
      if (withToken && accounts.hasUsers)
        'admins': [
          for (final a in accounts.admins) {'id': a.id, 'name': a.name},
        ],
    };
  }

  Map<String, Object?> _me(ApiRequest r) {
    final account = r.account!;
    return {
      ...account.toJson(),
      'grownUp': account.isAdmin || accounts.grownUpUnlocked(r.session),
      'unlocked': [
        for (final p in household.profiles)
          if (account.mayUse(p.id) && (account.isAdmin || !p.hasPin || accounts.profileUnlocked(r.session, p.id))) p.id,
      ],
    };
  }

  /// With the setup token: the first admin (no accounts yet), or a new
  /// password for the admin chosen after a reset. Signs in as it.
  Future<Object?> _setupPassword(ApiRequest r) async {
    final body = await r.body();
    final password = body.string('password') ?? '';
    ServerLog.secret(password);
    final token = body.string('token') ?? '';
    try {
      final String session;
      if (!accounts.hasUsers) {
        final name = (body.string('name') ?? 'admin').trim();
        session = await accounts.createFirstAdmin(token, name.isEmpty ? 'admin' : name, password);
        ServerLog.info('The first admin account, "${accounts.accountFor(session)?.name}", was made.');
      } else {
        session = await accounts.resetAdminPassword(token, body.string('user') ?? '', password);
        ServerLog.info('A new password was set for "${accounts.accountFor(session)?.name}".');
      }
      _setCookie(r.response, session, Accounts.sessionLife);
      _householdRevision++;
      return {'ok': true};
    } on AccountException catch (e) {
      throw ApiError(e.status, e.message);
    }
  }

  Future<Object?> _signIn(ApiRequest r) async {
    final body = await r.body();
    final password = body.string('password') ?? '';
    ServerLog.secret(password);
    final name = body.string('name') ?? '';
    try {
      final session = await accounts.signIn(name, password, r.from);
      _setCookie(r.response, session, Accounts.sessionLife);
      return {'ok': true};
    } on AccountException catch (e) {
      ServerLog.info('Web admin sign-in refused from ${r.from}: ${e.english ?? e.message}');
      throw ApiError(e.status, e.message);
    }
  }

  Future<Object?> _signOut(ApiRequest r) async {
    await accounts.signOut(r.session);
    _setCookie(r.response, '', Duration.zero);
    return {'ok': true};
  }

  Future<Object?> _changeOwnPassword(ApiRequest r) async {
    final body = await r.body();
    final current = body.string('current') ?? '', password = body.string('password') ?? '';
    ServerLog.secret(current);
    ServerLog.secret(password);
    await _accountCall(() => accounts.changeOwnPassword(r.session!, current, password, r.from));
    return _me(r);
  }

  // ---- Users (admin) -------------------------------------------------------------

  List<Map<String, Object?>> _users() => [for (final a in accounts.users()) a.toJson()];

  Map<String, Object?> _user(String id) =>
      (accounts.byId(id) ?? (throw ApiError(HttpStatus.notFound, tr.noSuchUser))).toJson();

  /// Profile ids in [body]'s "profiles", each one that exists.
  Set<String> _profileIds(Map<String, Object?> body) {
    final ids = body.strings('profiles') ?? const [];
    for (final id in ids) {
      if (household.profileById(id) == null) throw ApiError(HttpStatus.badRequest, tr.noSuchProfile);
    }
    return ids.toSet();
  }

  static Role? _role(String? name) => switch (name) {
        null => null,
        'admin' => Role.admin,
        'user' => Role.user,
        _ => throw ApiError(HttpStatus.badRequest, tr.theRoleIs),
      };

  Future<Object?> _addUser(ApiRequest r) async {
    final body = await r.body();
    final password = body.string('password');
    ServerLog.secret(password);
    final account = await _accountCall(() => accounts.addUser(
          name: body.string('name') ?? '',
          role: _role(body.string('role')) ?? Role.user,
          password: password ?? '',
          profiles: _profileIds(body),
        ));
    ServerLog.info('${r.account!.name} added the user "${account.name}".');
    return account.toJson();
  }

  Future<Object?> _updateUser(ApiRequest r) async {
    final body = await r.body();
    final account = await _accountCall(() async => accounts.updateUser(r['uid'],
        name: body.string('name'),
        role: _role(body.string('role')),
        disabled: body.boolean('disabled'),
        profiles: body.containsKey('profiles') ? _profileIds(body) : null));
    return account.toJson();
  }

  Future<Object?> _removeUser(ApiRequest r) async {
    final name = accounts.byId(r['uid'])?.name;
    await _accountCall(() async => accounts.removeUser(r['uid']));
    ServerLog.info('${r.account!.name} removed the user "$name".');
    return {'ok': true};
  }

  Future<Object?> _setUserPassword(ApiRequest r) async {
    final body = await r.body();
    final password = body.string('password') ?? '';
    ServerLog.secret(password);
    // Setting your own keeps this browser signed in.
    final keep = r['uid'] == r.account!.id ? r.session : null;
    await _accountCall(() => accounts.setPassword(r['uid'], password, keepSession: keep));
    return _user(r['uid']);
  }

  Future<Object?> _setUserProfiles(ApiRequest r) async {
    final body = await r.body();
    final account = await _accountCall(() async => accounts.updateUser(r['uid'], profiles: _profileIds(body)));
    return account.toJson();
  }

  Future<T> _accountCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AccountException catch (e) {
      throw ApiError(e.status, e.message);
    }
  }

  // ---- PIN unlocks -------------------------------------------------------------

  /// A profile's PIN (`{"pin"}`) or a grown-up's (`{"grownUp": pin}`),
  /// kept on the session for an hour from its last request. Wrong PINs
  /// count toward the sign-in lockout.
  Future<Object?> _unlock(ApiRequest r) async {
    final account = r.account!;
    final id = r['id'];
    if (!account.mayUse(id)) throw ApiError(HttpStatus.forbidden, SetupServer.notYoursText);
    final profile = _profile(id);
    if (accounts.lockedOut(r.from, account.name)) {
      throw ApiError(HttpStatus.tooManyRequests, tr.tooManyWrongPins);
    }
    final body = await r.body();
    if (body.string('pin') case final pin?) {
      if (!account.isAdmin && profile.hasPin && !profile.checkPin(pin)) {
        accounts.recordFailure(r.from, account.name);
        throw ApiError(HttpStatus.forbidden, tr.wrongPin);
      }
      accounts.unlockProfile(r.session!, id);
    }
    if (body.string('grownUp') case final pin?) {
      if (!account.isAdmin && household.grownUpWithPin(pin) == null) {
        accounts.recordFailure(r.from, account.name);
        throw ApiError(HttpStatus.forbidden, tr.wrongPin);
      }
      accounts.unlockGrownUp(r.session!);
    }
    return _me(r);
  }
}
