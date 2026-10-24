import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/open.dart' as loader;
import 'package:sqlite3/sqlite3.dart';

/// Server mode's account database (user-accounts, design D6):
/// `nightingale.db` in the household root, over the system libsqlite3.
/// Station data stays in the JSON files; the TV app never opens this.
class ServerDb {
  ServerDb._(this.db);

  static const fileName = 'nightingale.db';

  /// Its files, which backups leave out.
  static const files = [fileName, '$fileName-wal', '$fileName-shm', '$fileName-journal'];

  /// Migration n (1-based) takes the schema from version n - 1 to n.
  static const migrations = [
    '''
CREATE TABLE users(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE COLLATE NOCASE,
  role TEXT NOT NULL CHECK(role IN ('admin','user')),
  disabled INTEGER NOT NULL DEFAULT 0,
  pw_hash TEXT,
  pw_salt TEXT,
  pw_iter INTEGER,
  created TEXT NOT NULL,
  password_changed TEXT
);
CREATE TABLE user_profiles(
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  profile_id TEXT NOT NULL,
  PRIMARY KEY(user_id, profile_id)
);
CREATE TABLE sessions(
  hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires TEXT NOT NULL,
  last_seen TEXT NOT NULL
);
''',
  ];

  final Database db;

  /// The schema version (`PRAGMA user_version`).
  int get version => db.userVersion;

  /// Opens (or makes) the database in [root] and runs the migrations it
  /// hasn't had, each in its own transaction. Throws [ServerDbException]
  /// when one fails, leaving the version it had before.
  static ServerDb open(Directory root, {@visibleForTesting List<String> migrations = migrations}) {
    _useSystemLibrary();
    final db = sqlite3.open('${root.path}/$fileName');
    try {
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = NORMAL');
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA busy_timeout = 5000');
      for (var v = db.userVersion; v < migrations.length; v++) {
        db.execute('BEGIN');
        try {
          db.execute(migrations[v]);
          db.userVersion = v + 1;
          db.execute('COMMIT');
        } on Object catch (e) {
          db.execute('ROLLBACK');
          throw ServerDbException('The account database\'s migration ${v + 1} failed: $e');
        }
      }
    } on Object {
      db.dispose();
      rethrow;
    }
    return ServerDb._(db);
  }

  /// The package looks for `libsqlite3.so`, which only the dev package
  /// installs; the runtime package (`libsqlite3-0`) has `libsqlite3.so.0`.
  static void _useSystemLibrary() {
    loader.open.overrideFor(loader.OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so.0');
        // ignore: avoid_catching_errors
      } on ArgumentError {
        return DynamicLibrary.open('libsqlite3.so');
      }
    });
  }

  /// Runs [body] in one transaction.
  T transaction<T>(T Function() body) {
    db.execute('BEGIN');
    try {
      final result = body();
      db.execute('COMMIT');
      return result;
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => db.dispose();
}

class ServerDbException implements Exception {
  ServerDbException(this.message);
  final String message;
  @override
  String toString() => message;
}
