import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/program_block.dart';
import '../data/app_storage.dart';
import '../export/export_settings.dart';
import '../live/live_source.dart';
import '../live/live_source_files.dart';
import '../profiles/household.dart';
import '../profiles/profile.dart';
import '../server/media_server.dart';

/// Why a backup couldn't be made, read or restored, as one plain sentence.
class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Why a backup was made. The names are what backup files and the store's
/// file names hold.
abstract final class BackupReason {
  static const daily = 'daily';
  static const manual = 'manual';

  /// Opened from a file or uploaded from a phone (the store's kind only).
  static const file = 'file';
  static const beforeRestore = 'before-restore';
  static const beforeReset = 'before-reset';
  static const beforeDelete = 'before-delete';
  static const beforeUpgrade = 'before-upgrade';

  static const all = [daily, manual, file, beforeRestore, beforeReset, beforeDelete, beforeUpgrade];

  /// Safety backups, taken right before a big change.
  static bool isSafety(String reason) => reason.startsWith('before-');
}

/// What a backup holds, for lists and confirmations.
class BackupSummary {
  const BackupSummary({required this.profiles, required this.channels, required this.blocks, required this.logos});

  final List<String> profiles;
  final int channels;
  final int blocks;
  final int logos;

  /// "3 profiles · 42 channels · 5 blocks".
  String get line => [
        _count(profiles.length, 'profile'),
        _count(channels, 'channel'),
        _count(blocks, 'block'),
      ].join(' · ');

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

  Map<String, Object?> toJson() => {'profiles': profiles, 'channels': channels, 'blocks': blocks, 'logos': logos};
}

/// One profile's part of a backup: its saved state, as saved, and where it
/// signs in. Never its sign-in token or its Jellyfin device id.
class ProfileBackup {
  const ProfileBackup({this.settings, this.channels, this.blocks, this.signIn, this.liveSources, this.liveFiles = const {}});

  /// `settings.json` without `installId`.
  final Map<String, Object?>? settings;
  final List<Object?>? channels;
  final List<Object?>? blocks;

  /// Server URL, name and id, user id and name.
  final Map<String, Object?>? signIn;

  /// `live_sources.json` as saved (live-tv-sources), and the playlist and
  /// guide files picked on the device, by name, each gzip-compressed and
  /// base64-encoded (a guide can be hundreds of megabytes of XML). Never
  /// the cached channel lists or guide data.
  final Map<String, Object?>? liveSources;
  final Map<String, String> liveFiles;

  String? get serverId => signIn?['serverId'] as String?;

  Map<String, Object?> toJson() => {
        'settings': ?settings,
        'channels': ?channels,
        'blocks': ?blocks,
        'signIn': ?signIn,
        'liveSources': ?liveSources,
        if (liveFiles.isNotEmpty) 'liveFiles': liveFiles,
      };

  static ProfileBackup fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('profile');
    return ProfileBackup(
      settings: json['settings'] as Map<String, Object?>?,
      channels: json['channels'] as List<Object?>?,
      blocks: json['blocks'] as List<Object?>?,
      signIn: json['signIn'] as Map<String, Object?>?,
      liveSources: json['liveSources'] as Map<String, Object?>?,
      liveFiles: (json['liveFiles'] as Map?)?.cast<String, String>() ?? const {},
    );
  }

  /// Names a picked playlist or guide is copied in with
  /// ([LiveSourceStore.savePicked]), so no other name is ever written.
  static final liveFileName = RegExp(r'^[A-Za-z0-9_-]{1,80}-(playlist|guide)(\.[A-Za-z0-9]{1,5}){0,2}$');

  /// The sign-in hint fields of a saved session (or hint).
  static Map<String, Object?>? hintFrom(Object? session) {
    if (session is! Map<String, Object?>) return null;
    if (session['serverUrl'] is! String || session['userName'] is! String) return null;
    // Jellyfin hints have no kind, as before server kinds existed.
    final kind = ServerKind.fromJson(session['kind']);
    return {
      if (kind != ServerKind.jellyfin) 'kind': kind.name,
      'serverUrl': session['serverUrl'],
      'serverName': session['serverName'] ?? kind.label,
      'serverId': ?session['serverId'],
      'userId': ?session['userId'],
      'userName': session['userName'],
    };
  }
}

/// A backup of the whole household (backup-restore spec, D3): one
/// gzip-compressed JSON file, `.ntvbackup`, holding every state file as the
/// app saved it.
class BackupArchive {
  BackupArchive({
    this.version = currentVersion,
    required this.createdAt,
    required this.reason,
    required this.device,
    this.subject,
    required this.householdProfiles,
    this.export,
    this.remote,
    required this.profiles,
    required this.logos,
    this.server,
  });

  static const formatName = 'nightingale-tv-backup';

  /// Goes up only when an older app couldn't read a backup correctly.
  static const currentVersion = 1;

  /// The most a backup may hold once uncompressed (against gzip bombs).
  static const maxBytes = 64 * 1024 * 1024;

  static const damaged = 'This file isn\'t a Nightingale TV backup, or it\'s damaged.';
  static const newer = 'This backup was made by a newer version of Nightingale TV.';
  static const tooBig = 'This file is too big to be a Nightingale TV backup.';

  /// Logo names the logo store makes, so no other name is ever written.
  static final logoName = RegExp(r'^[0-9a-f]{16}\.(png|svg)$');

  /// Profile ids are folder names under `profiles/`.
  static final profileId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  final int version;
  final DateTime createdAt;
  final String reason;

  /// The device it was made on.
  final String device;

  /// The profile a "before-delete" backup was made for.
  final String? subject;

  /// `profiles.json` as saved.
  final List<Object?> householdProfiles;

  /// `export.json` and `remote.json` as saved (null when missing).
  final Object? export;
  final Object? remote;

  /// By profile id.
  final Map<String, ProfileBackup> profiles;

  /// Custom channel logos by file name.
  final Map<String, Uint8List> logos;

  /// A server's user accounts (docker-web-admin D9):
  /// `{"users": [{"name", "role", "disabled", "profiles": [ids]}]}`, never
  /// ids, password hashes, salts or sessions. Null in backups made on a TV,
  /// which also ignores it on restore.
  final Map<String, Object?>? server;

  /// Server files a backup never holds: the account database (and
  /// docker-server-core's password file). [build] reads only the files it
  /// names, so these can't get in; a restore leaves them where they are.
  static const neverBackedUp = [
    'nightingale.db',
    'nightingale.db-wal',
    'nightingale.db-shm',
    'nightingale.db-journal',
    'admin.json',
    'admin.json.migrated',
  ];

  /// What the content is, without when, why or where it was made: equal
  /// fingerprints mean nothing changed.
  late final String fingerprint = sha256.convert(utf8.encode(jsonEncode(_canonical(_content())))).toString();

  BackupSummary get summary => BackupSummary(
        profiles: [
          for (final p in householdProfiles)
            if (p is Map<String, Object?> && p['name'] is String) p['name'] as String,
        ],
        // Live channels are kept with their sources, not in channels.json.
        channels: profiles.values.fold(0, (n, p) => n + (p.channels?.length ?? 0) + _liveChannels(p.liveSources)),
        blocks: profiles.values.fold(0, (n, p) => n + (p.blocks?.length ?? 0)),
        logos: logos.length,
      );

  static int _liveChannels(Map<String, Object?>? live) => [
        if (live?['sources'] case final List<Object?> sources)
          for (final s in sources)
            if (s case {'chosen': final Map<String, Object?> chosen}) chosen.length,
      ].fold(0, (n, c) => n + c);

  /// The profile named in [householdProfiles] by [id].
  String? profileName(String id) => [
        for (final p in householdProfiles)
          if (p is Map<String, Object?> && p['id'] == id) p['name'] as String?,
      ].firstOrNull;

  /// Whether Live TV export is on in this backup for any profile.
  bool get exportOn {
    final s = ExportSettings.fromJson(export);
    return s.enabled && s.exportedProfileIds.isNotEmpty;
  }

  Map<String, Object?> _content() => {
        'household': {'profiles': householdProfiles, 'export': export, 'remote': remote},
        'profiles': {for (final e in profiles.entries) e.key: e.value.toJson()},
        'logos': {for (final e in logos.entries) e.key: base64.encode(e.value)},
        'server': ?server,
      };

  Map<String, Object?> toJson() => {
        'format': formatName,
        'version': version,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'reason': reason,
        'device': device,
        'subject': ?subject,
        'fingerprint': fingerprint,
        'summary': summary.toJson(),
        ..._content(),
      };

  Uint8List encode() => Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(toJson()))));

  /// Maps with their keys sorted, all the way down.
  static Object? _canonical(Object? json) => switch (json) {
        Map() => {for (final k in json.keys.map((k) => '$k').toList()..sort()) k: _canonical(json[k])},
        List() => [for (final v in json) _canonical(v)],
        _ => json,
      };

  // ---- Reading ---------------------------------------------------------------

  /// Gunzips [bytes], turning down anything over [cap] once uncompressed.
  static Uint8List gunzip(List<int> bytes, {int cap = maxBytes}) {
    final out = _CappedSink(cap);
    final input = gzip.decoder.startChunkedConversion(out);
    try {
      for (var i = 0; i < bytes.length; i += 64 * 1024) {
        input.add(bytes.sublist(i, i + 64 * 1024 > bytes.length ? bytes.length : i + 64 * 1024));
      }
      input.close();
    } on _TooBig {
      throw BackupException(tooBig);
    } on Object {
      throw BackupException(damaged);
    }
    return out.takeBytes();
  }

  /// Reads a backup's format, version and parts, without checking that each
  /// part loads (see [check]).
  static BackupArchive decode(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(gunzip(bytes)));
    } on BackupException {
      rethrow;
    } on Object {
      throw BackupException(damaged);
    }
    if (json is! Map<String, Object?> || json['format'] != formatName) throw BackupException(damaged);
    final version = json['version'];
    if (version is! int || version < 1) throw BackupException(damaged);
    if (version > currentVersion) throw BackupException(newer);
    try {
      final household = json['household'] as Map<String, Object?>;
      final parts = json['profiles'] as Map<String, Object?>? ?? const {};
      final logos = json['logos'] as Map<String, Object?>? ?? const {};
      return BackupArchive(
        version: version,
        createdAt: DateTime.parse(json['createdAt'] as String),
        reason: json['reason'] as String? ?? BackupReason.manual,
        device: json['device'] as String? ?? '',
        subject: json['subject'] as String?,
        householdProfiles: household['profiles'] as List<Object?>,
        export: household['export'],
        remote: household['remote'],
        profiles: {for (final e in parts.entries) e.key: ProfileBackup.fromJson(e.value)},
        logos: {for (final e in logos.entries) e.key: base64.decode(e.value as String)},
        server: json['server'] is Map<String, Object?> ? json['server'] as Map<String, Object?> : null,
      );
    } on Object {
      throw BackupException(damaged);
    }
  }

  /// Checks the whole backup before it's restored (D4): every part loads
  /// with the code that loads the app's saved state, the household is
  /// allowed, and every logo has a name the app makes and decodes. Turns it
  /// down with one plain sentence otherwise.
  static BackupArchive check(List<int> bytes) {
    final archive = decode(bytes);
    final List<Profile> household;
    try {
      household = [for (final p in archive.householdProfiles) Profile.fromJson(p as Map<String, Object?>)];
    } on Object {
      throw BackupException('This backup is damaged: its profiles can\'t be read.');
    }
    final ids = {for (final p in household) p.id};
    if (household.isEmpty || ids.length != household.length || !ids.every(profileId.hasMatch)) {
      throw BackupException('This backup is damaged: its profiles can\'t be read.');
    }
    if (Household.problemIn(household) case final problem?) {
      throw BackupException('This backup can\'t be restored. $problem');
    }
    for (final p in household) {
      final part = archive.profiles[p.id];
      if (part == null) continue;
      String what = 'settings';
      try {
        if (part.settings case final s?) {
          AppSettings.fromJson({...s, 'installId': AppSettings.fresh().installId});
        }
        what = 'channels';
        for (final c in part.channels ?? const []) {
          Channel.fromJson(c as Map<String, Object?>);
        }
        what = 'programming blocks';
        for (final b in part.blocks ?? const []) {
          ProgramBlock.fromJson(b as Map<String, Object?>);
        }
        what = 'Live TV sources';
        if (part.liveSources case final live?) {
          for (final s in live['sources'] as List? ?? const []) {
            LiveSource.fromJson(s as Map<String, Object?>);
          }
        }
        for (final name in part.liveFiles.keys) {
          if (!ProfileBackup.liveFileName.hasMatch(name)) throw const FormatException('live file');
        }
      } on Object {
        throw BackupException('This backup is damaged: ${p.name}\'s $what can\'t be read.');
      }
    }
    if (archive.export case final Map<String, Object?> export) {
      try {
        ExportSettings.fromJson(export);
      } on Object {
        throw BackupException('This backup is damaged: its Live TV export settings can\'t be read.');
      }
    }
    for (final e in archive.logos.entries) {
      if (!logoName.hasMatch(e.key) || !_logoDecodes(e.key, e.value)) {
        throw BackupException('This backup is damaged: one of its channel logos can\'t be read.');
      }
    }
    return archive;
  }

  static bool _logoDecodes(String name, Uint8List bytes) {
    if (name.endsWith('.svg')) return String.fromCharCodes(bytes.take(2048)).contains('<svg');
    try {
      return img.decodePng(bytes) != null;
    } on Object {
      return false;
    }
  }

  // ---- Building --------------------------------------------------------------

  /// Builds in the background (off in widget tests, whose fake clock
  /// doesn't wait for isolates).
  @visibleForTesting
  static bool useIsolate = true;

  /// A backup of the data folder [root] (D2): the household files, each
  /// profile's settings (without `installId`), channels, blocks and sign-in
  /// hint, and the logos. Never a token, a device id, the library index,
  /// analysis results, caches or logs. Pending writes must be flushed first.
  ///
  /// [server] is the server's account section (server mode only).
  static Future<BuiltBackup> build(Directory root,
      {required String reason, required String device, String? subject, DateTime? createdAt, Map<String, Object?>? server}) {
    final path = root.path;
    final at = (createdAt ?? DateTime.now()).toUtc();
    Future<BuiltBackup> work() async {
      final archive =
          await _read(Directory(path), reason: reason, device: device, subject: subject, createdAt: at, server: server);
      return BuiltBackup(archive.encode(), archive.fingerprint, archive.summary, at);
    }

    return useIsolate ? Isolate.run(work, debugName: 'backup') : work();
  }

  static Future<BackupArchive> _read(Directory root,
      {required String reason, required String device, String? subject, required DateTime createdAt, Map<String, Object?>? server}) async {
    final top = AppStorage.existing(root);
    final household = await top.readRaw('profiles.json');
    final list = household is List ? household.cast<Object?>() : const <Object?>[];
    final profiles = <String, ProfileBackup>{};
    for (final p in list) {
      final id = p is Map<String, Object?> ? p['id'] : null;
      if (id is! String || !profileId.hasMatch(id)) continue;
      final storage = AppStorage.existing(Directory('${root.path}/profiles/$id'));
      final settings = await storage.readRaw('settings.json');
      final channels = await storage.readRaw('channels.json');
      final blocks = await storage.readRaw('blocks.json');
      final live = await storage.readRaw(LiveSourceStore.fileName);
      final liveFiles = <String, String>{};
      if (live is Map<String, Object?>) {
        for (final s in live['sources'] as List? ?? const []) {
          if (s is! Map<String, Object?>) continue;
          for (final name in [s['playlistFile'], s['guideFile']]) {
            if (name is! String || !ProfileBackup.liveFileName.hasMatch(name)) continue;
            final f = File('${storage.root.path}/${LiveSourceStore.filesFolder}/$name');
            if (await f.exists()) liveFiles[name] = base64.encode(gzip.encode(await f.readAsBytes()));
          }
        }
      }
      profiles[id] = ProfileBackup(
        settings: settings is Map<String, Object?> ? ({...settings}..remove('installId')) : null,
        channels: channels is List ? channels.cast<Object?>() : null,
        blocks: blocks is List ? blocks.cast<Object?>() : null,
        signIn: ProfileBackup.hintFrom(await storage.readRaw('session.json')) ??
            ProfileBackup.hintFrom(await storage.readRaw(signInHintFile)),
        liveSources: live is Map<String, Object?> ? live : null,
        liveFiles: liveFiles,
      );
    }
    final logos = <String, Uint8List>{};
    final logosDir = Directory('${root.path}/logos');
    if (await logosDir.exists()) {
      await for (final f in logosDir.list()) {
        final name = f.uri.pathSegments.last;
        if (f is File && logoName.hasMatch(name)) logos[name] = await f.readAsBytes();
      }
    }
    return BackupArchive(
      createdAt: createdAt,
      reason: reason,
      device: device,
      subject: subject,
      householdProfiles: list,
      export: await top.readRaw('export.json'),
      remote: await top.readRaw('remote.json'),
      profiles: profiles,
      logos: logos,
      server: server,
    );
  }

  /// A restored profile's sign-in hint, until it signs in (D6).
  static const signInHintFile = 'sign_in_hint.json';
}

/// A backup just built: its file's bytes and what's in it.
class BuiltBackup {
  const BuiltBackup(this.bytes, this.fingerprint, this.summary, this.createdAt);

  final Uint8List bytes;
  final String fingerprint;
  final BackupSummary summary;
  final DateTime createdAt;
}

class _TooBig implements Exception {}

/// Collects gunzipped bytes, giving up past [cap].
class _CappedSink implements Sink<List<int>> {
  _CappedSink(this.cap);

  final int cap;
  final _bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> data) {
    if (_bytes.length + data.length > cap) throw _TooBig();
    _bytes.add(data);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _bytes.takeBytes();
}
