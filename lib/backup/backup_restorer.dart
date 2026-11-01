import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../live/live_download.dart';
import '../live/live_source_files.dart';
import '../data/app_storage.dart';
import '../platform/platform_info.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/household.dart';
import '../ui/format.dart';
import 'backup_archive.dart';
import '../server/media_server.dart';
import '../server/server_set.dart';
import '../server/server_clients.dart';

/// What a restore will do, for its confirmation.
class RestorePlan {
  const RestorePlan({required this.needPassword, required this.exportMoves, this.backsUpFirst = true});

  /// Profiles that will ask for their Jellyfin password (D6).
  final List<String> needPassword;

  /// The backup has Live TV export on, and this device runs it (a PC): it
  /// moves here.
  final bool exportMoves;

  /// The current setup is backed up first (not on a first run, which has
  /// nothing to keep).
  final bool backsUpFirst;
}

/// Restores a backup over the household (D5): checked, a safety backup
/// first, then staged in `restore.tmp/` and swapped in under a journal, so
/// a crash at any moment leaves the old setup or the new one, never a mix.
class BackupRestorer {
  BackupRestorer(this.household, {@visibleForTesting Future<void> Function(ServerSession session)? signOut})
      : _signOut = signOut ?? _logout;

  final Household household;

  /// Signs a sign-in the restore drops out of its server, as deleting a
  /// profile does, so the server doesn't keep a device nobody uses.
  final Future<void> Function(ServerSession session) _signOut;

  static Future<void> _logout(ServerSession session) async {
    final client = sessionClient(session, deviceName: PlatformInfo.deviceName);
    try {
      await client.logout();
    } finally {
      client.close();
    }
  }

  /// Sign-ins on this device that the restore doesn't keep (D6).
  final _dropped = <ServerSession>[];

  static const _staging = 'restore.tmp';
  static const _journal = 'restore.json';
  static const _topFiles = ['profiles.json', 'export.json', 'remote.json'];

  Directory get _root => household.root.root;

  /// Which profiles keep their sign-in, and which ask for a password.
  Future<RestorePlan> plan(BackupArchive archive) async {
    await household.flushAll();
    final kept = await _keptSignIns(_root, archive);
    return RestorePlan(
      needPassword: [
        for (final p in archive.householdProfiles)
          if (p is Map<String, Object?> && !kept.contains(p['id'])) p['name'] as String,
      ],
      exportMoves: archive.exportOn && PlatformInfo.isDesktop,
      backsUpFirst: !await household.hasNothingToKeep(),
    );
  }

  /// Profiles that exist here, are signed in, and are on the server the
  /// backup has for them (same kind and id): they keep their sign-in and
  /// library (D6).
  static Future<Set<String>> _keptSignIns(Directory root, BackupArchive archive) async {
    final kept = <String>{};
    for (final e in archive.profiles.entries) {
      final backupServer = e.value.serverId;
      if (backupServer == null) continue;
      final backupKind = ServerKind.fromJson(e.value.signIn?['kind']);
      final session = await AppStorage.existing(Directory('${root.path}/profiles/${e.key}')).readRaw('session.json');
      if (session is Map<String, Object?> &&
          session['accessToken'] is String &&
          session['serverId'] == backupServer &&
          ServerKind.fromJson(session['kind']) == backupKind) {
        kept.add(e.key);
      }
    }
    return kept;
  }

  /// Checks [bytes] (D4), saves a "before-restore" backup, and replaces the
  /// household with the backup's, reloading it in place. Throws
  /// [BackupException] with nothing changed when the backup is turned down
  /// or the safety backup can't be saved. [beforeClosing] runs once both
  /// are done, just before everything closes (the screen stops playback).
  Future<void> restore(List<int> bytes, {Future<void> Function()? beforeClosing}) async {
    final archive = BackupArchive.check(bytes);
    final watch = Stopwatch()..start();
    // A first run (Welcome back, or sign-in on a new install) has nothing
    // to keep.
    if (!await household.hasNothingToKeep()) {
      await household.backups?.safetyBackup(BackupReason.beforeRestore);
    }
    PlaybackDiagnostics.note('BACKUP', 'restore: checked and backed up in ${watch.elapsedMilliseconds} ms');
    await beforeClosing?.call();
    try {
      await household.reload(() async {
        PlaybackDiagnostics.note('BACKUP', 'restore: closed in ${watch.elapsedMilliseconds} ms');
        await stage(archive);
        PlaybackDiagnostics.note('BACKUP', 'restore: staged in ${watch.elapsedMilliseconds} ms');
        await _swap(_root);
        PlaybackDiagnostics.note('BACKUP', 'restore: swapped in ${watch.elapsedMilliseconds} ms');
      });
    } on Object catch (e) {
      household.notice.value = 'Couldn\'t restore the backup: $e';
      rethrow;
    }
    PlaybackDiagnostics.note('BACKUP', 'restore: started again in ${watch.elapsedMilliseconds} ms');
    household.notice.value = 'Restored the backup from ${formatMoment(archive.createdAt.toLocal())}.';
    // In the background: an unreachable server never holds up a restore.
    for (final session in [..._dropped]) {
      unawaited(_signOut(session).then((_) {}, onError: (Object e) => debugPrint('Couldn\'t sign out a replaced profile: $e')));
    }
    _dropped.clear();
  }

  /// Writes the restored tree into `restore.tmp/`, then the journal.
  @visibleForTesting
  Future<void> stage(BackupArchive archive) async {
    final root = _root;
    final staging = Directory('${root.path}/$_staging');
    if (await staging.exists()) await staging.delete(recursive: true);
    final old = Directory('${root.path}/profiles.old');
    if (await old.exists()) await old.delete(recursive: true);
    await staging.create(recursive: true);
    final top = AppStorage.existing(staging);
    final present = <String>[];
    await top.writeJson('profiles.json', archive.householdProfiles);
    present.add('profiles.json');
    if (archive.export != null) {
      await top.writeJson('export.json', archive.export);
      present.add('export.json');
    }
    if (archive.remote != null) {
      await top.writeJson('remote.json', archive.remote);
      present.add('remote.json');
    }

    final kept = await _keptSignIns(root, archive);
    _dropped.clear();
    final profilesHere = Directory('${root.path}/profiles');
    if (await profilesHere.exists()) {
      await for (final dir in profilesHere.list()) {
        final id = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (dir is! Directory || kept.contains(id)) continue;
        final storage = AppStorage.existing(dir);
        final session = await storage.readRaw('session.json');
        if (session is! Map<String, Object?>) continue;
        try {
          _dropped.add(ServerSession.fromJson(session));
        } on Object {
          // Unreadable: nothing to sign out.
        }
        // Its added servers' sign-ins go with it (multi-server).
        _dropped.addAll(_addedSessions(await storage.readRaw(ServerSet.file)).values);
      }
    }
    await Directory('${staging.path}/profiles').create();
    for (final p in archive.householdProfiles.cast<Map<String, Object?>>()) {
      final id = p['id'] as String;
      final part = archive.profiles[id] ?? const ProfileBackup();
      final here = Directory('${root.path}/profiles/$id');
      final current = AppStorage.existing(here);
      final dir = Directory('${staging.path}/profiles/$id');
      await dir.create();
      final out = AppStorage.existing(dir);
      // This device's own device id, never the backup's (D7).
      final settingsHere = await current.readRaw('settings.json');
      final installId = settingsHere is Map<String, Object?> && settingsHere['installId'] is String
          ? settingsHere['installId'] as String
          : AppSettings.fresh().installId;
      if (part.settings case final settings?) {
        await out.writeJson('settings.json', {...settings, 'installId': installId});
      } else if (settingsHere != null) {
        await out.writeJson('settings.json', settingsHere);
      }
      if (part.channels case final channels?) await out.writeJson('channels.json', channels);
      if (part.blocks case final blocks?) await out.writeJson('blocks.json', blocks);
      // Live TV sources and their picked files; their channels and guide are
      // fetched again at the next start (live-tv-sources).
      if (part.liveSources case final live?) await out.writeJson(LiveSourceStore.fileName, live, private: true);
      if (part.liveFiles.isNotEmpty) {
        final files = Directory('${dir.path}/${LiveSourceStore.filesFolder}');
        await files.create();
        for (final e in part.liveFiles.entries) {
          // Checked against ProfileBackup.liveFileName: no path leaves the folder.
          await _unpack(e.value, File('${files.path}/${e.key}'));
        }
      }
      if (kept.contains(id)) {
        await out.writeJson('session.json', await current.readRaw('session.json'), private: true);
        final library = File('${here.path}/library.json');
        if (await library.exists()) await library.copy('${dir.path}/library.json');
      } else if (part.signIn case final hint?) {
        await out.writeJson(AppState.signInHintFile, hint);
      }
      await _restoreServers(part, current, out, here, dir, keptMain: kept.contains(id));
      await out.flush();
    }

    final logos = Directory('${staging.path}/logos');
    await logos.create();
    for (final e in archive.logos.entries) {
      // Checked against BackupArchive.logoName: no path leaves logos/.
      await File('${logos.path}/${e.key}').writeAsBytes(e.value, flush: true);
    }
    await top.flush();
    // From here on the restore is finished even after a crash.
    final journal = AppStorage.existing(root);
    await journal.writeJson(_journal, {'phase': 'swap', 'files': present});
    await journal.flush();
  }

  /// The added servers' sign-ins saved in [json] (`servers.json`), by key.
  static Map<String, ServerSession> _addedSessions(Object? json) {
    final out = <String, ServerSession>{};
    if (json is! Map<String, Object?>) return out;
    for (final s in (json['servers'] as List? ?? const []).whereType<Map<String, Object?>>()) {
      if (s['key'] case final String key when s['session'] is Map<String, Object?>) {
        try {
          out[key] = ServerSession.fromJson(s['session'] as Map<String, Object?>);
        } on Object {
          // Unreadable: nothing to sign out or keep.
        }
      }
    }
    return out;
  }

  /// The backup's added servers (multi-server D10). With the main server
  /// kept, an added server signed in here to the same server under the same
  /// key stays signed in (with its library part); every other one comes back
  /// needing sign-in, with its key, order and quality limit. Sign-ins here
  /// that aren't kept are signed out.
  Future<void> _restoreServers(ProfileBackup part, AppStorage current, AppStorage out, Directory here, Directory dir,
      {required bool keptMain}) async {
    final sessionsHere = keptMain ? _addedSessions(await current.readRaw(ServerSet.file)) : const <String, ServerSession>{};
    final backup = part.servers;
    final kept = <String>{};
    final servers = <Map<String, Object?>>[];
    for (final s in (backup?['servers'] as List? ?? const []).whereType<Map<String, Object?>>()) {
      final key = s['key'];
      if (key is! String) continue;
      final session = sessionsHere[key];
      final limit = s['qualityLimit'];
      if (session != null && session.serverId != null && session.serverId == s['serverId']) {
        kept.add(key);
        servers.add({'key': key, 'session': session.toJson(), 'qualityLimit': ?limit});
      } else {
        servers.add({
          'key': key,
          'hint': {for (final e in s.entries) if (e.key != 'key' && e.key != 'qualityLimit') e.key: e.value},
          'qualityLimit': ?limit,
        });
      }
    }
    // Signed in here, but not to what the backup has under that key.
    for (final MapEntry(:key, value: session) in sessionsHere.entries) {
      if (!kept.contains(key)) _dropped.add(session);
    }
    if (servers.isEmpty) return;
    await out.writeJson(
        ServerSet.file,
        {
          'servers': servers,
          'order': backup?['order'],
          'nextKey': ?backup?['nextKey'],
          'mainQualityLimit': backup?['mainQualityLimit'],
        },
        private: true);
    if (!keptMain) return;
    // The kept servers' last scans, so their programs stay on the air.
    for (final key in [ServerSet.mainKey, ...kept]) {
      final file = File('${here.path}/library_parts/$key.json');
      if (!await file.exists()) continue;
      await Directory('${dir.path}/library_parts').create(recursive: true);
      await file.copy('${dir.path}/library_parts/$key.json');
    }
  }

  /// A backed-up live file ([ProfileBackup.liveFiles]) written to [to],
  /// refusing more than a guide may hold.
  static Future<void> _unpack(String encoded, File to) async {
    final sink = to.openWrite();
    var size = 0;
    try {
      await for (final chunk in Stream<List<int>>.value(base64.decode(encoded)).transform(gzip.decoder)) {
        size += chunk.length;
        if (size > LiveDownloader.maxGuideBytes) throw BackupException(BackupArchive.tooBig);
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
  }

  /// Finishes a restore whose journal says it's swapping, or throws away a
  /// staged one that never got that far. Run at the top of
  /// [Household.start].
  static Future<void> recover(Directory root) async {
    final journal = File('${root.path}/$_journal');
    if (await journal.exists()) {
      final Object? json;
      try {
        json = jsonDecode(await journal.readAsString());
      } on FormatException {
        // Never written whole (it's written atomically): nothing to finish.
        await journal.delete();
        return recover(root);
      }
      if (json is Map<String, Object?> && json['phase'] == 'swap') {
        PlaybackDiagnostics.note('BACKUP', 'finishing a restore cut short');
        await _swap(root);
        return;
      }
      await journal.delete();
    }
    final staging = Directory('${root.path}/$_staging');
    if (await staging.exists()) await staging.delete(recursive: true);
  }

  /// Renames the staged tree into place (D5 steps 5 and 6). Each step can
  /// be run again after a crash.
  static Future<void> _swap(Directory root) async {
    final journal = File('${root.path}/$_journal');
    final json = jsonDecode(await journal.readAsString()) as Map<String, Object?>;
    final present = (json['files'] as List? ?? const []).cast<String>();
    final staging = Directory('${root.path}/$_staging');
    final staged = Directory('${staging.path}/profiles');
    final profiles = Directory('${root.path}/profiles');
    final old = Directory('${root.path}/profiles.old');
    if (await staged.exists()) {
      if (await profiles.exists()) {
        if (await old.exists()) await old.delete(recursive: true);
        await profiles.rename(old.path);
      }
      await staged.rename(profiles.path);
    }
    for (final name in _topFiles) {
      final from = File('${staging.path}/$name');
      final to = File('${root.path}/$name');
      if (present.contains(name)) {
        if (await from.exists()) await from.rename(to.path);
      } else if (await to.exists()) {
        await to.delete();
      }
    }
    final logos = Directory('${staging.path}/logos');
    if (await logos.exists()) {
      final into = Directory('${root.path}/logos');
      await into.create(recursive: true);
      await for (final f in logos.list()) {
        if (f is! File) continue;
        final target = File('${into.path}/${f.uri.pathSegments.last}');
        // Logos already here are kept; the names are content hashes.
        if (await target.exists()) {
          await f.delete();
        } else {
          await f.rename(target.path);
        }
      }
    }
    if (await old.exists()) await old.delete(recursive: true);
    if (await staging.exists()) await staging.delete(recursive: true);
    await journal.delete();
  }
}
