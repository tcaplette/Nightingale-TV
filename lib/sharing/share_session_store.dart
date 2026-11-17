import '../data/app_storage.dart';

/// One profile's share sign-in on this device.
class ShareSignIn {
  const ShareSignIn({required this.session, required this.userId, required this.email});

  /// The Supabase session as its JSON text (access and refresh tokens).
  final String session;
  final String userId;
  final String email;

  Map<String, Object?> toJson() => {'session': session, 'userId': userId, 'email': email};

  static ShareSignIn? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final session = json['session'], userId = json['userId'], email = json['email'];
    if (session is! String || userId is! String || email is! String) return null;
    return ShareSignIn(session: session, userId: userId, email: email);
  }
}

/// The device's share sign-ins, keyed by profile id (share-accounts D4).
///
/// `share_sessions.json` at the top of the data folder: not in a profile's
/// folder, so backups (which read only the files they name) never hold it,
/// and a restore (which replaces `profiles/` and `logos/`) keeps it. Android
/// system backup copies only `backups/cloud/`, so it isn't there either.
class ShareSessionStore {
  ShareSessionStore(this._storage);

  static const fileName = 'share_sessions.json';

  final AppStorage _storage;
  final _signIns = <String, ShareSignIn>{};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final json = await _storage.readJson(fileName);
    if (json is! Map<String, Object?>) return;
    for (final e in json.entries) {
      if (ShareSignIn.fromJson(e.value) case final s?) _signIns[e.key] = s;
    }
  }

  ShareSignIn? operator [](String profileId) => _signIns[profileId];

  bool isLinked(String profileId) => _signIns.containsKey(profileId);

  Iterable<String> get profileIds => _signIns.keys;

  Future<void> put(String profileId, ShareSignIn signIn) {
    _signIns[profileId] = signIn;
    return _save();
  }

  Future<void> remove(String profileId) async {
    if (_signIns.remove(profileId) != null) await _save();
  }

  Future<void> _save() => _storage.writeJson(fileName, {
        for (final e in _signIns.entries) e.key: e.value.toJson(),
      }, private: true);
}
