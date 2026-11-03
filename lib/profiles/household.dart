import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../backup/backup_archive.dart';
import '../backup/backup_restorer.dart';
import '../backup/backup_scheduler.dart';
import '../backup/backup_store.dart';
import '../data/app_storage.dart';
import '../export/export_service.dart';
import '../platform/platform_info.dart';
import '../remote/remote_control.dart';
import 'analysis_queue.dart';
import 'profile.dart';
import '../server/media_server.dart';
import '../server/server_clients.dart';

/// Everyone who watches this TV: the profiles, which one is watching now,
/// and that profile's [AppState].
///
/// Each profile keeps its own Jellyfin sign-in, library, channels and blocks
/// under `profiles/<id>/`; custom logos are shared.
class Household extends ChangeNotifier {
  Household(this.root, {this.runAnalysis = true, this.serverMode = false});

  /// Analyze media in the background (off in some tests).
  final bool runAnalysis;

  /// Server mode (server-mode): nobody is ever on screen; exported profiles
  /// run off-screen and the setup page signs profiles in.
  final bool serverMode;

  static const _profilesFile = 'profiles.json';

  /// State files that lived at the top level before profiles existed.
  static const _legacyFiles = [
    'session.json',
    'settings.json',
    'library.json',
    'channels.json',
    'blocks.json',
  ];

  final AppStorage root;

  /// The phone remote, when the app runs one (not in most tests).
  RemoteControl? remote;

  /// Live TV export, when the app runs it (not in most tests).
  ExportService? export;

  /// Automatic and safety backups, when the app makes them (not in most
  /// tests).
  BackupScheduler? backups;

  /// A message for whatever screen is showing ("Restored the backup
  /// from…"), cleared once shown.
  final notice = ValueNotifier<String?>(null);

  /// The newest backup, offered on a first run that finds one (D14); null
  /// otherwise, and once Restore it or Start fresh is chosen.
  StoredBackup? welcomeBack;

  /// This start made the first profile from nothing: a new install, where
  /// sign-in also offers to restore a backup from a file or another device.
  bool firstRun = false;
  List<Profile> _profiles = [];
  Profile? _current;
  AppState? _app;
  bool _started = false;

  /// True while Live TV export is streaming anything (set by the export
  /// service); every profile's analysis holds off meanwhile.
  final exportStreaming = ValueNotifier(false);

  /// Profiles whose lineups Live TV export serves.
  Set<String> _exported = const {};

  /// The [AppState]s of exported profiles that aren't on screen. With the
  /// one on screen, there is never more than one per profile.
  final _offScreen = <String, AppState>{};

  /// Server mode: states the setup page opened for profiles that aren't
  /// exported (signing in, restoring), until [releaseSetup].
  final _setup = <String, AppState>{};

  /// Server mode: exported profiles analyze media one at a time.
  late final AnalysisQueue? analysisQueue = serverMode ? AnalysisQueue() : null;

  bool get started => _started;
  List<Profile> get profiles => _profiles;

  /// Who's watching, or null while choosing a profile.
  Profile? get current => _current;
  AppState? get app => _app;

  bool get hasKids => _profiles.any((p) => p.isKid);

  /// The server the last signed-in profile used, to pre-fill sign-in for
  /// new profiles.
  String? lastServerUrl;

  Future<void> start() async {
    // A restore cut short by a crash or power cut is finished, or a staged
    // one that never began swapping is thrown away.
    await BackupRestorer.recover(root.root);
    final json = await root.readJson(_profilesFile);
    if (json is List) {
      _profiles = [for (final p in json.cast<Map<String, Object?>>()) Profile.fromJson(p)];
    }
    if (_profiles.isEmpty && json == null && backups != null && !serverMode && !await _hasLegacySetup()) {
      // A first run with backups here (Android brought one back, or a copied
      // data folder): offer the newest before making a profile.
      final newest = await backups!.store.newest();
      if (newest != null) {
        welcomeBack = newest;
        _started = true;
        notifyListeners();
        return;
      }
    }
    await _finishStart();
  }

  /// Nothing set up yet, so a restore needs no backup first: no profiles,
  /// or a new install's first profile that hasn't signed in. In server mode
  /// the server may have restarted before it was set up, so that profile
  /// counts whatever the start, while it has no PIN.
  Future<bool> hasNothingToKeep() async {
    if (!await File('${root.root.path}/$_profilesFile').exists()) return true;
    if (_profiles.length != 1) return false;
    if (!firstRun && !(serverMode && !_profiles.single.hasPin)) return false;
    final storage = AppStorage.existing(Directory('${root.root.path}/profiles/${_profiles.single.id}'));
    return await storage.readRaw('session.json') == null && await storage.readRaw('channels.json') == null;
  }

  /// Nothing anyone set up: no profiles, or one that never signed in and
  /// has no channels, whether or not this is the first run (moving a setup
  /// to the other app, install-switching).
  Future<bool> hasNoSetup() async {
    if (!await File('${root.root.path}/$_profilesFile').exists()) return true;
    if (_profiles.length != 1) return false;
    final storage = AppStorage.existing(Directory('${root.root.path}/profiles/${_profiles.single.id}'));
    return await storage.readRaw('session.json') == null && await storage.readRaw('channels.json') == null;
  }

  Future<bool> _hasLegacySetup() async {
    for (final f in _legacyFiles) {
      if (await File('${root.root.path}/$f').exists()) return true;
    }
    return false;
  }

  /// Start fresh on the Welcome back screen: today's first run, with the
  /// backups kept for Backup & restore.
  Future<void> startFresh() async {
    welcomeBack = null;
    await _finishStart();
  }

  Future<void> _finishStart() async {
    firstRun = false;
    if (_profiles.isEmpty) {
      // First run, or an install from before profiles: the existing setup
      // becomes the first profile.
      firstRun = !await _hasLegacySetup();
      final session = await root.readJson('session.json');
      final userName = session is Map<String, Object?> ? session['userName'] as String? : null;
      final first = Profile(id: _newId(), name: _displayName(userName) ?? 'Me');
      final storage = await storageFor(first);
      for (final f in _legacyFiles) {
        await storage.adopt(root, f);
      }
      _profiles = [first];
      await _save();
    }
    _started = true;
    final only = _profiles.length == 1 ? _profiles.single : null;
    if (only != null && !only.hasPin && !serverMode) {
      await select(only);
    } else {
      notifyListeners();
    }
  }

  /// [p]'s state, on screen or kept for Live TV export; null when neither.
  AppState? appFor(String profileId) =>
      _current?.id == profileId ? _app : _offScreen[profileId];

  /// Server mode: [profileId]'s state for the setup page: the off-screen
  /// one when the profile is exported, otherwise a temporary background
  /// state, kept until [releaseSetup] (design D3).
  Future<AppState?> appForSetup(String profileId) async {
    final existing = appFor(profileId) ?? _setup[profileId];
    if (existing != null) {
      // An exported profile still loading: signing in needs it loaded.
      await _starting[existing];
      return existing;
    }
    final p = profileById(profileId);
    if (p == null) return null;
    final app = _setup[profileId] = await _newApp(p, background: true);
    await app.start();
    return app;
  }

  /// The setup page is done with [profileId]'s temporary state: closed,
  /// unless the profile is exported by now (then it's already off-screen).
  Future<void> releaseSetup(String profileId) async {
    final app = _setup.remove(profileId);
    if (app != null && !identical(_offScreen[profileId], app)) await app.close();
  }

  Profile? profileById(String id) => _profiles.where((p) => p.id == id).firstOrNull;

  /// Keeps the [AppState]s of the profiles in [ids] loaded, on screen or
  /// not, and lets go of the others' off-screen states.
  Future<void> setExportedProfiles(Set<String> ids) async {
    _exported = {...ids};
    for (final id in [..._offScreen.keys]) {
      if (!ids.contains(id)) await _offScreen.remove(id)!.close();
    }
    for (final id in ids) {
      final p = profileById(id);
      if (p == null || id == _current?.id || _offScreen.containsKey(id)) continue;
      if (_setup.remove(id) case final app?) {
        // Signed in on the setup page just now: that state is kept.
        _offScreen[id] = app;
        continue;
      }
      _startOffScreen(p, await _newApp(p, background: true));
    }
    _syncAnalysisQueue();
    notifyListeners();
  }

  void _syncAnalysisQueue() => analysisQueue?.setProfiles(
      [for (final p in _profiles) if (_exported.contains(p.id)) p.id], (id) => appFor(id)?.analysisState);

  /// Off-screen states' starts, until each has started.
  final _starting = <AppState, Future<void>>{};

  void _startOffScreen(Profile p, AppState app) {
    _offScreen[p.id] = app;
    final start = _starting[app] = () async {
      try {
        await app.start();
        if (p.needsRescan && identical(_offScreen[p.id], app)) {
          p.needsRescan = false;
          await _save();
          await app.refreshLibrary(background: true);
        }
      } on Object catch (e) {
        debugPrint('Couldn\'t load ${p.name} for Live TV export: $e');
      }
    }();
    unawaited(start.whenComplete(() => _starting.remove(app)));
  }

  Future<AppState> _newApp(Profile p, {bool background = false}) async => AppState(await storageFor(p),
      maxRatingRank: p.maxRatingRank,
      runAnalysis: runAnalysis,
      background: background,
      exportBusy: exportStreaming,
      analysisAllowed: analysisQueue?.allowedFor(p.id),
      safetyBackup: backups == null ? null : (reason) => backups!.safetyBackup(reason));

  /// Waits for every state file write asked for so far, the household's and
  /// each open profile's.
  Future<void> flushAll() async {
    await root.flush();
    for (final app in [?_app, ..._offScreen.values, ..._setup.values]) {
      await app.storage.flush();
    }
  }

  /// Closes every profile's state (stopping its analysis) and waits for
  /// every state file write: server mode's shutdown.
  Future<void> closeAll() async {
    for (final app in [?_app, ..._offScreen.values, ..._setup.values]) {
      await app.close();
    }
    await flushAll();
  }

  /// Closes everything (every profile's state, Live TV export, the phone
  /// remote), runs [whileClosed] with nothing reading or writing the data
  /// folder, then starts it all again from the files, without an app
  /// restart (D14). Back to "Who's watching?", or straight in with one
  /// profile and no PIN.
  Future<void> reload(Future<void> Function() whileClosed) async {
    final apps = [?_app, ..._offScreen.values, ..._setup.values];
    _app = null;
    _current = null;
    _offScreen.clear();
    _setup.clear();
    _syncAnalysisQueue();
    _exported = const {};
    _started = false;
    welcomeBack = null;
    notifyListeners();
    await export?.unload();
    await remote?.stop();
    for (final app in apps) {
      await app.close();
      await app.storage.flush();
    }
    await root.flush();
    try {
      await whileClosed();
    } finally {
      _profiles = [];
      await start();
      await remote?.load();
      await export?.load();
    }
  }

  /// [app] (of [p]) leaves the screen: kept for Live TV export, else closed.
  Future<void> _putAway(Profile p, AppState app) async {
    if (_exported.contains(p.id)) {
      _offScreen[p.id] = app;
      await app.setBackground(true);
    } else {
      await app.close();
    }
  }

  Future<AppStorage> storageFor(Profile p) =>
      AppStorage.at(Directory('${root.root.path}/profiles/${p.id}'),
          logosDir: root.logosDir, analysisDir: root.analysisDir);

  /// Switches to [p]. PINs are checked by the caller.
  Future<void> select(Profile p) async {
    final previous = _app;
    final previousProfile = _current;
    _app = null;
    _current = null;
    if (previous != null && previousProfile != null) await _putAway(previousProfile, previous);
    var app = _offScreen.remove(p.id);
    if (app != null && app.maxRatingRank != p.maxRatingRank) {
      // The rating limit changed: the library has to be filtered again.
      await app.close();
      app = null;
    }
    final reused = app != null;
    app ??= await _newApp(p);
    _current = p;
    _app = app;
    notifyListeners();
    if (reused) {
      await app.setBackground(false);
    } else {
      await app.start();
    }
    lastServerUrl = app.session?.serverUrl ?? lastServerUrl;
    if (p.needsRescan) {
      p.needsRescan = false;
      await _save();
      await app.refreshLibrary(background: true);
    }
  }

  /// Back to "Who's watching?".
  void leave() {
    final previous = _app;
    final previousProfile = _current;
    _app = null;
    _current = null;
    if (previous != null && previousProfile != null) unawaited(_putAway(previousProfile, previous));
    notifyListeners();
  }

  // ---- Managing profiles ---------------------------------------------------

  /// A new, unsaved profile for the profile editor.
  Profile newProfile() => Profile(id: _newId(), name: '', color: _profiles.length % avatarColorCount);

  bool isSaved(Profile p) => _profiles.any((x) => x.id == p.id);

  /// Why saving [draft] (new or edited) isn't allowed, if it isn't.
  String? problemWith(Profile draft) =>
      problemIn([for (final p in _profiles) if (p.id != draft.id) p, draft]);

  /// Why deleting [p] isn't allowed, if it isn't.
  String? problemDeleting(Profile p) {
    if (p.id == _current?.id) return 'Switch to another profile before deleting this one.';
    return problemIn([for (final x in _profiles) if (x.id != p.id) x]);
  }

  /// Why [profiles] can't be a household, if they can't (also checked on a
  /// backup before it's restored).
  static String? problemIn(List<Profile> profiles) {
    final grownUps = profiles.where((p) => !p.isKid).toList();
    if (grownUps.isEmpty) return 'There has to be at least one grown-up profile.';
    if (profiles.any((p) => p.isKid)) {
      final open = grownUps.where((p) => !p.hasPin).map((p) => p.name).toList();
      if (open.isNotEmpty) {
        return 'While there are kid profiles, every grown-up profile needs a PIN so kids '
            'can\'t switch into it. Set a PIN on ${open.join(', ')}.';
      }
    }
    return null;
  }

  /// Adds or replaces [draft]. A kid's new rating limit applies right away;
  /// content a looser limit allows arrives with a library rescan.
  Future<void> saveProfile(Profile draft) async {
    final problem = problemWith(draft);
    if (problem != null) throw StateError(problem);
    final old = _profiles.where((p) => p.id == draft.id).firstOrNull;
    if (draft.name.trim().isEmpty) draft.name = draft.isKid ? 'Kids' : 'Guest';
    final limitChanged = old != null && old.maxRatingRank != draft.maxRatingRank;
    if (limitChanged) draft.needsRescan = true;
    _profiles = old == null
        ? [..._profiles, draft]
        : [for (final p in _profiles) p.id == draft.id ? draft : p];
    await _save();
    if (draft.id == _current?.id) {
      if (limitChanged) {
        await select(draft);
      } else {
        _current = draft;
      }
    } else if (_offScreen.remove(draft.id) case final app?) {
      // Kept for Live TV export: reload it under the new limit.
      await app.close();
      _startOffScreen(draft, await _newApp(draft, background: true));
      _syncAnalysisQueue();
    }
    notifyListeners();
  }

  /// Deletes [p] and everything it saved, signing its device out of Jellyfin.
  ///
  /// A safety backup is saved first; if it can't be, nothing is deleted and
  /// the [BackupException] is thrown.
  Future<void> deleteProfile(Profile p) async {
    final problem = problemDeleting(p);
    if (problem != null) throw StateError(problem);
    await backups?.safetyBackup(BackupReason.beforeDelete, subject: p.name);
    _exported = {..._exported}..remove(p.id);
    await _offScreen.remove(p.id)?.close();
    await _setup.remove(p.id)?.close();
    _syncAnalysisQueue();
    final storage = await storageFor(p);
    final session = await storage.readJson('session.json');
    if (session is Map<String, Object?>) {
      final client = sessionClient(ServerSession.fromJson(session),
          deviceName: PlatformInfo.deviceName);
      try {
        await client.logout();
      } on Object {
        // Deleting locally still works if the server is unreachable.
      } finally {
        client.close();
      }
    }
    if (await storage.root.exists()) await storage.root.delete(recursive: true);
    _profiles = _profiles.where((x) => x.id != p.id).toList();
    await _save();
    notifyListeners();
  }

  /// A grown-up profile whose PIN is [pin], for unlocking parental controls.
  Profile? grownUpWithPin(String pin) =>
      _profiles.where((p) => !p.isKid && p.checkPin(pin)).firstOrNull;

  Future<void> _save() => root.writeJson(_profilesFile, [for (final p in _profiles) p.toJson()]);

  static String _newId() {
    final rng = Random.secure();
    return List.generate(8, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static String? _displayName(String? userName) {
    final n = userName?.trim();
    if (n == null || n.isEmpty) return null;
    return n[0].toUpperCase() + n.substring(1);
  }
}

/// Number of avatar colors (see `avatarColors` in the UI).
const avatarColorCount = 6;
