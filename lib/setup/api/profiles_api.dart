part of '../setup_server.dart';

/// Profiles (admin-api): the list each account may see, editing through
/// `Household.saveProfile`, adding and removing (admin). Kind, rating and
/// PIN are admin-only; PIN hashes never leave the server.
extension _ProfilesApi on SetupServer {
  List<ApiRoute> get _profileRoutes => [
        ApiRoute('GET', 'profiles', Access.signedIn, _profiles, revision: Revision.household),
        ApiRoute('POST', 'profiles', Access.admin, _addProfile, revision: Revision.household),
        ApiRoute('GET', 'profiles/{id}', Access.profile, (r) => _profileJson(_profile(r['id']), r),
            revision: Revision.household),
        ApiRoute('PUT', 'profiles/{id}', Access.profileSettings, _editProfile, revision: Revision.household),
        ApiRoute('DELETE', 'profiles/{id}', Access.admin, _deleteProfile, revision: Revision.household),
      ];

  static const adminOnlyText = 'Only an admin can change that.';

  Future<List<Map<String, Object?>>> _profiles(ApiRequest r) async => [
        for (final p in household.profiles)
          if (r.account!.mayUse(p.id)) await _profileJson(p, r),
      ];

  Future<Map<String, Object?>> _profileJson(Profile p, ApiRequest r) async {
    final admin = r.isAdmin;
    return {
      'id': p.id,
      'name': p.name,
      'kind': p.kind.name,
      if (p.isKid) 'rating': p.rating.name,
      'color': p.color,
      'hasPin': p.hasPin,
      'exported': household.export?.settings.isExported(p.id) ?? false,
      'signedIn': (await _signInState(p)).signedIn,
      'locked': !admin && p.hasPin && !accounts.profileUnlocked(r.session, p.id),
      'needsGrownUp': !admin && p.isKid && !accounts.grownUpUnlocked(r.session),
    };
  }

  /// Applies [body]'s name, color, kind, rating and PIN to [draft].
  void _applyProfile(Profile draft, Map<String, Object?> body) {
    if (body.string('name') case final name?) draft.name = name.trim();
    if (body.integer('color') case final color?) draft.color = color;
    if (body.string('kind') case final kind?) {
      draft.kind = ProfileKind.values.asNameMap()[kind] ?? (throw ApiError(HttpStatus.badRequest, 'No such kind.'));
    }
    if (body.string('rating') case final rating?) {
      draft.rating = KidRating.values.asNameMap()[rating] ?? (throw ApiError(HttpStatus.badRequest, 'No such rating.'));
    }
    if (body.containsKey('pin')) {
      final pin = body.string('pin');
      if (pin != null && !Profile.isValidPin(pin)) throw ApiError(HttpStatus.badRequest, 'A PIN is 4 digits.');
      draft.setPin(pin);
    }
  }

  Future<void> _save(Profile draft) async {
    try {
      await household.saveProfile(draft);
    } on StateError catch (e) {
      throw ApiError(HttpStatus.conflict, e.message);
    }
  }

  /// A new profile. With only a name it's Start fresh: the new install's
  /// empty profile is used, and it's exported once it signs in.
  Future<Object?> _addProfile(ApiRequest r) async {
    final body = await r.body();
    final fresh = body.boolean('fresh') ?? body.keys.every((k) => k == 'name');
    if (fresh) return _startFresh(body);
    final draft = household.newProfile();
    _applyProfile(draft, body);
    await _save(draft);
    ServerLog.info('${r.account!.name} added the profile ${draft.name}.');
    return await _profileJson(draft, r);
  }

  /// Start fresh: a profile to sign in, exported once it has.
  Future<Object?> _startFresh(Map<String, Object?> body) async {
    final name = (body.string('name') ?? '').trim();
    final Profile profile;
    if (household.profiles.length == 1 && await household.hasNothingToKeep()) {
      // The new install's empty first profile becomes this one.
      profile = household.profiles.single;
      if (name.isNotEmpty) profile.name = name;
    } else {
      profile = household.newProfile()..name = name.isEmpty ? 'Me' : name;
    }
    final problem = household.problemWith(profile);
    if (problem != null) throw ApiError(HttpStatus.conflict, problem);
    await household.saveProfile(profile);
    _fresh.add(profile.id);
    return {'id': profile.id, 'name': profile.name};
  }

  Future<Object?> _editProfile(ApiRequest r) async {
    final profile = _profile(r['id']);
    final body = await r.body();
    if (!r.isAdmin) {
      final kind = body.string('kind'), rating = body.string('rating');
      final kindChanged = kind != null && kind != profile.kind.name;
      final ratingChanged = rating != null && rating != profile.rating.name;
      if (kindChanged || ratingChanged || body.containsKey('pin')) throw ApiError(HttpStatus.forbidden, adminOnlyText);
    }
    final draft = profile.copy();
    _applyProfile(draft, body);
    await _save(draft);
    return await _profileJson(household.profileById(draft.id)!, r);
  }

  Future<Object?> _deleteProfile(ApiRequest r) async {
    final profile = _profile(r['id']);
    _signIns.remove(profile.id)?.flow.dispose();
    if (_borrowed.remove(profile.id) != null) await household.releaseSetup(profile.id);
    try {
      await household.deleteProfile(profile);
    } on StateError catch (e) {
      throw ApiError(HttpStatus.conflict, e.message);
    } on BackupException catch (e) {
      throw ApiError(HttpStatus.conflict, e.message);
    }
    accounts.keepProfiles(household.profiles.map((p) => p.id));
    _profileRevisions.remove(profile.id);
    ServerLog.info('${r.account!.name} removed the profile ${profile.name}.');
    return {'ok': true};
  }
}
