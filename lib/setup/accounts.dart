import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'server_db.dart';
import '../l10n/tr.dart';

enum Role { admin, user }

/// A user account (user-accounts), as the API shows it: never its hash.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.role,
    required this.disabled,
    required this.profiles,
    required this.hasPassword,
  });

  final String id;
  final String name;
  final Role role;
  final bool disabled;

  /// Assigned profile ids (admins reach every profile anyway).
  final Set<String> profiles;

  /// False for an account a restore added: it can't sign in until an admin
  /// sets a password ("Needs a password").
  final bool hasPassword;

  bool get isAdmin => role == Role.admin;

  /// Whether this account may use profile [id].
  bool mayUse(String id) => isAdmin || profiles.contains(id);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'disabled': disabled,
        'profiles': profiles.toList()..sort(),
        'needsPassword': !hasPassword,
      };
}

/// Why an account call was refused, with the status the API answers.
class AccountException implements Exception {
  AccountException(this.message, {this.status = HttpStatus.badRequest, this.english});
  final String message;

  /// [message] for the server's log, when it may be in a browser's language.
  final String? english;
  final int status;
  @override
  String toString() => message;
}

/// User accounts, roles, profile assignments and sessions in [ServerDb]
/// (user-accounts, design D6), replacing docker-server-core's single admin
/// password. Hashing, cookies and lockout work as that password's did.
///
/// While there are no accounts, or after `NTV_RESET_PASSWORD=1`, a random
/// setup token (logged as the setup link) makes the first admin or resets
/// an admin's password.
class Accounts {
  Accounts._(this.db, this._clock);

  /// docker-server-core's password file, turned into the account "admin".
  static const legacyFile = 'admin.json';

  static const minPasswordLength = 8;
  static const maxNameLength = 32;

  /// PBKDF2 rounds (at least 100,000 by the spec).
  @visibleForTesting
  static int iterations = 150000;

  static const sessionLife = Duration(days: 30);

  /// PIN unlocks last until the session has been unused this long.
  static const unlockLife = Duration(hours: 1);

  /// Wrong passwords (or PINs) from one address, or for one user name,
  /// within [lockWindow] that lock it out for [lockWindow].
  static const maxFailures = 5;
  static const lockWindow = Duration(minutes: 1);

  static String get lastAdminText => tr.makeSomeoneElse;
  static String get setupLinkText => tr.openTheSetup;
  static String get wrongText => tr.wrongUserName;
  static String get lockedText => tr.tooManyWrong;

  final ServerDb db;
  final DateTime Function() _clock;

  /// The setup token, while there are no accounts or after a reset.
  String? setupToken;

  final _failures = <String, List<DateTime>>{};
  final _lockedUntil = <String, DateTime>{};

  /// PIN unlocks by session hash (in memory: a restart asks again).
  final _unlocks = <String, _Unlocks>{};

  /// Opens the database in [root], turns an `admin.json` into the account
  /// "admin", and with [reset] (`NTV_RESET_PASSWORD=1`) ends every session.
  /// Makes a setup token when there are no accounts or on [reset].
  /// [log] gets the lines worth logging.
  static Future<Accounts> load(Directory root,
      {bool reset = false, DateTime Function()? clock, void Function(String line)? log}) async {
    final accounts = Accounts._(ServerDb.open(root), clock ?? DateTime.now);
    await accounts._upgrade(root, log ?? (_) {});
    if (reset) accounts.db.db.execute('DELETE FROM sessions');
    if (reset || !accounts.hasUsers) accounts.setupToken = _random(16);
    return accounts;
  }

  void close() => db.close();

  /// docker-server-core's `admin.json`: the same hash becomes the admin
  /// "admin"; its sessions end (one more sign-in).
  Future<void> _upgrade(Directory root, void Function(String) log) async {
    final file = File('${root.path}/$legacyFile');
    if (!await file.exists()) return;
    if (hasUsers) return;
    Map<String, Object?>? password;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, Object?> && json['password'] is Map<String, Object?>) {
        password = json['password'] as Map<String, Object?>;
      }
    } on Object {
      // Unreadable: nothing to carry over.
    }
    if (password case {'hash': final String hash, 'salt': final String salt, 'iterations': final int rounds}) {
      final now = _now();
      db.db.execute(
          'INSERT INTO users(id, name, role, pw_hash, pw_salt, pw_iter, created, password_changed) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [_random(8), 'admin', Role.admin.name, hash, salt, rounds, now, now]);
      log('The admin password is now the account "admin".');
    }
    await file.rename('${file.path}.migrated');
  }

  String _now() => _clock().toUtc().toIso8601String();

  // ---- Reading ---------------------------------------------------------------

  bool get hasUsers => db.db.select('SELECT 1 FROM users LIMIT 1').isNotEmpty;

  List<Account> users() => [
        for (final row in db.db.select('SELECT * FROM users ORDER BY name COLLATE NOCASE')) _account(row),
      ];

  Account? byId(String id) {
    final rows = db.db.select('SELECT * FROM users WHERE id = ?', [id]);
    return rows.isEmpty ? null : _account(rows.first);
  }

  Account? byName(String name) {
    final rows = db.db.select('SELECT * FROM users WHERE name = ? COLLATE NOCASE', [name.trim()]);
    return rows.isEmpty ? null : _account(rows.first);
  }

  List<Account> get admins => [for (final a in users()) if (a.isAdmin) a];

  Account _account(Map<String, Object?> row) {
    final id = row['id'] as String;
    return Account(
      id: id,
      name: row['name'] as String,
      role: Role.values.byName(row['role'] as String),
      disabled: row['disabled'] == 1,
      profiles: {
        for (final p in db.db.select('SELECT profile_id FROM user_profiles WHERE user_id = ?', [id]))
          p['profile_id'] as String,
      },
      hasPassword: row['pw_hash'] != null,
    );
  }

  // ---- Checks ------------------------------------------------------------------

  /// Why [password] can't be used, if it can't.
  static String? problemWithPassword(String password) =>
      password.length < minPasswordLength ? tr.useAtLeast(minPasswordLength) : null;

  /// Why [name] can't be a user name, if it can't.
  static String? problemWithName(String name) {
    final n = name.trim();
    if (n.isEmpty) return tr.enterAUser;
    if (n.length > maxNameLength) return tr.useAtMost(maxNameLength);
    return null;
  }

  void _checkToken(String token) {
    final want = setupToken;
    if (want == null || !_same(token, want)) {
      throw AccountException(setupLinkText, status: HttpStatus.forbidden);
    }
  }

  // ---- First run and reset -------------------------------------------------

  /// With the setup token and no accounts: makes [name] the first admin.
  /// Returns a session id for it.
  Future<String> createFirstAdmin(String token, String name, String password) async {
    _checkToken(token);
    if (hasUsers) throw AccountException(setupLinkText, status: HttpStatus.forbidden);
    final account = await addUser(name: name, role: Role.admin, password: password);
    setupToken = null;
    return _newSession(account.id);
  }

  /// With the setup token after a reset: a new password for admin [userId],
  /// signed in as it. Every other account is kept as it is.
  Future<String> resetAdminPassword(String token, String userId, String password) async {
    _checkToken(token);
    final account = byId(userId);
    if (account == null || !account.isAdmin) throw AccountException(tr.chooseAnAdmin);
    await setPassword(userId, password);
    if (account.disabled) db.db.execute('UPDATE users SET disabled = 0 WHERE id = ?', [userId]);
    setupToken = null;
    return _newSession(userId);
  }

  // ---- Signing in --------------------------------------------------------------

  /// Whether sign-in attempts from [from], or for [name], are refused now.
  bool lockedOut(String from, [String? name]) =>
      _locked('a:$from') || (name != null && _locked('n:${name.trim().toLowerCase()}'));

  bool _locked(String key) {
    final until = _lockedUntil[key];
    if (until == null) return false;
    if (_clock().isBefore(until)) return true;
    _lockedUntil.remove(key);
    return false;
  }

  /// Counts a wrong password or PIN from [from] for [name].
  void recordFailure(String from, [String? name]) {
    for (final key in ['a:$from', if (name != null) 'n:${name.trim().toLowerCase()}']) {
      final now = _clock();
      final recent = (_failures[key] ?? [])..removeWhere((t) => now.difference(t) >= lockWindow);
      _failures[key] = recent..add(now);
      if (recent.length >= maxFailures) {
        _lockedUntil[key] = now.add(lockWindow);
        recent.clear();
      }
    }
  }

  /// Signs [name] in from address [from]. Returns a new session id, or
  /// throws [AccountException].
  Future<String> signIn(String name, String password, String from) async {
    if (lockedOut(from, name)) throw AccountException(lockedText, english: runInLanguage('en', () => lockedText), status: HttpStatus.tooManyRequests);
    final rows = db.db.select('SELECT * FROM users WHERE name = ? COLLATE NOCASE', [name.trim()]);
    final row = rows.firstOrNull;
    final hash = row?['pw_hash'] as String?;
    // An unknown name costs the same as a wrong password.
    final salt = row?['pw_salt'] as String? ?? base64.encode(List.filled(16, 0));
    final rounds = row?['pw_iter'] as int? ?? iterations;
    final tried = base64.encode(await _hash(password, base64.decode(salt), rounds));
    if (row == null || hash == null || !_same(tried, hash)) {
      recordFailure(from, name);
      throw AccountException(wrongText, english: runInLanguage('en', () => wrongText), status: HttpStatus.forbidden);
    }
    if (row['disabled'] == 1) throw AccountException(tr.thisAccountIs, english: runInLanguage('en', () => tr.thisAccountIs), status: HttpStatus.forbidden);
    _failures.remove('a:$from');
    _failures.remove('n:${name.trim().toLowerCase()}');
    return _newSession(row['id'] as String);
  }

  /// The account signed in with session [id], or null (unknown, expired,
  /// or its account turned off). Counts as a request for PIN unlocks.
  Account? accountFor(String? id) {
    if (id == null || id.isEmpty) return null;
    final key = _sessionKey(id);
    final rows = db.db.select('SELECT * FROM sessions WHERE hash = ?', [key]);
    if (rows.isEmpty) return null;
    final now = _clock();
    if (DateTime.parse(rows.first['expires'] as String).isBefore(now)) {
      db.db.execute('DELETE FROM sessions WHERE hash = ?', [key]);
      _unlocks.remove(key);
      return null;
    }
    final account = byId(rows.first['user_id'] as String);
    if (account == null || account.disabled) return null;
    final seen = DateTime.parse(rows.first['last_seen'] as String);
    if (now.difference(seen) > const Duration(minutes: 1)) {
      db.db.execute('UPDATE sessions SET last_seen = ? WHERE hash = ?', [_now(), key]);
    }
    final unlocks = _unlocks[key];
    if (unlocks != null) {
      if (now.difference(unlocks.lastRequest) > unlockLife) {
        _unlocks.remove(key);
      } else {
        unlocks.lastRequest = now;
      }
    }
    return account;
  }

  Future<void> signOut(String? id) async {
    if (id == null) return;
    final key = _sessionKey(id);
    db.db.execute('DELETE FROM sessions WHERE hash = ?', [key]);
    _unlocks.remove(key);
  }

  Future<String> _newSession(String userId) async {
    final id = _random(32);
    final now = _clock();
    db.db.execute('DELETE FROM sessions WHERE expires < ?', [now.toUtc().toIso8601String()]);
    db.db.execute('INSERT INTO sessions(hash, user_id, expires, last_seen) VALUES (?, ?, ?, ?)',
        [_sessionKey(id), userId, now.add(sessionLife).toUtc().toIso8601String(), _now()]);
    return id;
  }

  void _endSessions(String userId, {String? except}) {
    final keep = except == null ? null : _sessionKey(except);
    final ended = db.db.select('SELECT hash FROM sessions WHERE user_id = ?', [userId]);
    for (final row in ended) {
      final hash = row['hash'] as String;
      if (hash == keep) continue;
      db.db.execute('DELETE FROM sessions WHERE hash = ?', [hash]);
      _unlocks.remove(hash);
    }
  }

  // ---- PIN unlocks ---------------------------------------------------------------

  /// Session [id] gave profile [profileId]'s PIN.
  void unlockProfile(String id, String profileId) =>
      (_unlocks[_sessionKey(id)] ??= _Unlocks(_clock())).profiles.add(profileId);

  bool profileUnlocked(String? id, String profileId) =>
      id != null && (_unlocks[_sessionKey(id)]?.profiles.contains(profileId) ?? false);

  /// Session [id] gave a grown-up's PIN.
  void unlockGrownUp(String id) => (_unlocks[_sessionKey(id)] ??= _Unlocks(_clock())).grownUp = true;

  bool grownUpUnlocked(String? id) => id != null && (_unlocks[_sessionKey(id)]?.grownUp ?? false);

  // ---- Managing users ----------------------------------------------------------

  /// Adds an account. [password] null leaves it needing one (restores).
  Future<Account> addUser(
      {required String name, required Role role, String? password, Set<String> profiles = const {}}) async {
    if (problemWithName(name) case final problem?) throw AccountException(problem);
    if (password != null) {
      if (problemWithPassword(password) case final problem?) throw AccountException(problem);
    }
    if (byName(name) != null) throw AccountException(tr.thereIsAlready(name.trim()), status: HttpStatus.conflict);
    final id = _random(8);
    final hashed = password == null ? null : await _newHash(password);
    final now = _now();
    db.transaction(() {
      db.db.execute(
          'INSERT INTO users(id, name, role, pw_hash, pw_salt, pw_iter, created, password_changed) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [id, name.trim(), role.name, hashed?.hash, hashed?.salt, hashed?.rounds, now, password == null ? null : now]);
      _setProfiles(id, profiles);
    });
    return byId(id)!;
  }

  /// Changes [userId]'s name, role, disabled state or profiles. Turning
  /// an account off ends its sessions. The last enabled admin stays one.
  Account updateUser(String userId, {String? name, Role? role, bool? disabled, Set<String>? profiles}) {
    final account = byId(userId) ?? (throw AccountException(tr.noSuchUser, status: HttpStatus.notFound));
    final losesAdmin = account.isAdmin && !account.disabled && ((role != null && role != Role.admin) || disabled == true);
    if (losesAdmin && _enabledAdmins().length <= 1) throw AccountException(lastAdminText, status: HttpStatus.conflict);
    if (name != null && name.trim() != account.name) {
      if (problemWithName(name) case final problem?) throw AccountException(problem);
      final other = byName(name);
      if (other != null && other.id != userId) {
        throw AccountException(tr.thereIsAlready(name.trim()), status: HttpStatus.conflict);
      }
    }
    db.transaction(() {
      if (name != null) db.db.execute('UPDATE users SET name = ? WHERE id = ?', [name.trim(), userId]);
      if (role != null) db.db.execute('UPDATE users SET role = ? WHERE id = ?', [role.name, userId]);
      if (disabled != null) db.db.execute('UPDATE users SET disabled = ? WHERE id = ?', [disabled ? 1 : 0, userId]);
      if (profiles != null) _setProfiles(userId, profiles);
    });
    if (disabled == true) _endSessions(userId);
    return byId(userId)!;
  }

  List<Account> _enabledAdmins() => [for (final a in admins) if (!a.disabled) a];

  void _setProfiles(String userId, Set<String> profiles) {
    db.db.execute('DELETE FROM user_profiles WHERE user_id = ?', [userId]);
    for (final p in profiles) {
      db.db.execute('INSERT INTO user_profiles(user_id, profile_id) VALUES (?, ?)', [userId, p]);
    }
  }

  /// Sets [userId]'s password, ending its sessions but [keepSession].
  Future<void> setPassword(String userId, String password, {String? keepSession}) async {
    if (problemWithPassword(password) case final problem?) throw AccountException(problem);
    if (byId(userId) == null) throw AccountException(tr.noSuchUser, status: HttpStatus.notFound);
    final h = await _newHash(password);
    db.db.execute('UPDATE users SET pw_hash = ?, pw_salt = ?, pw_iter = ?, password_changed = ? WHERE id = ?',
        [h.hash, h.salt, h.rounds, _now(), userId]);
    _endSessions(userId, except: keepSession);
  }

  /// The signed-in user (session [sessionId]) changes their own password,
  /// giving [current]; their other sessions end.
  Future<void> changeOwnPassword(String sessionId, String current, String password, String from) async {
    final account = accountFor(sessionId) ?? (throw AccountException(tr.signInFirst, status: HttpStatus.unauthorized));
    if (lockedOut(from, account.name)) throw AccountException(lockedText, status: HttpStatus.tooManyRequests);
    final row = db.db.select('SELECT pw_hash, pw_salt, pw_iter FROM users WHERE id = ?', [account.id]).first;
    final hash = row['pw_hash'] as String?;
    final tried = hash == null
        ? ''
        : base64.encode(await _hash(current, base64.decode(row['pw_salt'] as String), row['pw_iter'] as int));
    if (hash == null || !_same(tried, hash)) {
      recordFailure(from, account.name);
      throw AccountException(tr.yourCurrentPassword, status: HttpStatus.forbidden);
    }
    await setPassword(account.id, password, keepSession: sessionId);
  }

  /// Removes [userId] and ends its sessions. Never the last enabled admin.
  void removeUser(String userId) {
    final account = byId(userId) ?? (throw AccountException(tr.noSuchUser, status: HttpStatus.notFound));
    if (account.isAdmin && !account.disabled && _enabledAdmins().length <= 1) {
      throw AccountException(lastAdminText, status: HttpStatus.conflict);
    }
    _endSessions(userId);
    db.db.execute('DELETE FROM users WHERE id = ?', [userId]);
  }

  /// Drops assignments to profiles not in [existing] (a profile was
  /// deleted, or a backup restored).
  void keepProfiles(Iterable<String> existing) {
    final keep = existing.toSet();
    for (final row in db.db.select('SELECT DISTINCT profile_id FROM user_profiles')) {
      final id = row['profile_id'] as String;
      if (!keep.contains(id)) db.db.execute('DELETE FROM user_profiles WHERE profile_id = ?', [id]);
    }
  }

  // ---- Backups (design D9) -------------------------------------------------------

  /// The accounts for a server backup: names, roles, disabled states and
  /// profiles. No ids, hashes, salts or sessions.
  Map<String, Object?> backupSection() => {
        'users': [
          for (final a in users())
            {'name': a.name, 'role': a.role.name, 'disabled': a.disabled, 'profiles': a.profiles.toList()..sort()},
        ],
      };

  /// After a household restore: [section]'s accounts (a server backup's)
  /// matched by name. A match keeps its password and takes the backup's
  /// role, disabled state and profiles; a new name is added needing a
  /// password; accounts the backup lacks are kept. Profiles not in
  /// [profiles] are dropped everywhere, and [keepAdmin] (who restored)
  /// stays an enabled admin. Without a section only the profiles are
  /// tidied.
  void restoreSection(Map<String, Object?>? section, {required Iterable<String> profiles, String? keepAdmin}) {
    final existing = profiles.toSet();
    final list = section?['users'];
    db.transaction(() {
      if (list is List) {
        for (final u in list.whereType<Map<String, Object?>>()) {
          final name = u['name'];
          if (name is! String || problemWithName(name) != null) continue;
          final role = u['role'] == Role.admin.name ? Role.admin : Role.user;
          final disabled = u['disabled'] == true;
          final assigned = {
            for (final p in (u['profiles'] as List? ?? const []).whereType<String>())
              if (existing.contains(p)) p,
          };
          final match = byName(name);
          final String id;
          if (match == null) {
            id = _random(8);
            db.db.execute('INSERT INTO users(id, name, role, disabled, created) VALUES (?, ?, ?, ?, ?)',
                [id, name.trim(), role.name, disabled ? 1 : 0, _now()]);
          } else {
            id = match.id;
            db.db.execute('UPDATE users SET role = ?, disabled = ? WHERE id = ?', [role.name, disabled ? 1 : 0, id]);
          }
          _setProfiles(id, assigned);
        }
      }
      if (keepAdmin != null) {
        db.db.execute('UPDATE users SET role = ?, disabled = 0 WHERE id = ?', [Role.admin.name, keepAdmin]);
      }
    });
    keepProfiles(existing);
    // Accounts the backup turned off are signed out.
    for (final a in users()) {
      if (a.disabled) _endSessions(a.id);
    }
  }

  // ---- Hashing -----------------------------------------------------------------

  Future<({String hash, String salt, int rounds})> _newHash(String password) async {
    final salt = _randomBytes(16);
    final rounds = iterations;
    final hash = await _hash(password, salt, rounds);
    return (hash: base64.encode(hash), salt: base64.encode(salt), rounds: rounds);
  }

  static String _sessionKey(String id) => sha256.convert(utf8.encode(id)).toString();

  /// Off the main isolate: 150,000 rounds would hold up streams.
  static Future<Uint8List> _hash(String password, List<int> salt, int rounds) {
    final p = utf8.encode(password), s = Uint8List.fromList(salt);
    return Isolate.run(() => pbkdf2(p, s, rounds));
  }

  /// PBKDF2-HMAC-SHA256, one 32-byte block.
  @visibleForTesting
  static Uint8List pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  /// Compares without stopping at the first difference.
  static bool _same(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));
  }

  /// [bytes] random bytes, as hex.
  static String _random(int bytes) => _randomBytes(bytes).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// A session's PIN unlocks, kept while it's in use.
class _Unlocks {
  _Unlocks(this.lastRequest);
  DateTime lastRequest;
  final profiles = <String>{};
  bool grownUp = false;
}
