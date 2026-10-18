import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../data/app_storage.dart';
import '../jellyfin/jellyfin_client.dart';
import '../remote/remote_control.dart';
import 'profile.dart';

/// Everyone who watches this TV: the profiles, which one is watching now,
/// and that profile's [AppState].
///
/// Each profile keeps its own Jellyfin sign-in, library, channels and blocks
/// under `profiles/<id>/`; custom logos are shared.
class Household extends ChangeNotifier {
  Household(this.root, {this.runAnalysis = true});

  /// Analyze media in the background (off in some tests).
  final bool runAnalysis;

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
  List<Profile> _profiles = [];
  Profile? _current;
  AppState? _app;
  bool _started = false;

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
    final json = await root.readJson(_profilesFile);
    if (json is List) {
      _profiles = [for (final p in json.cast<Map<String, Object?>>()) Profile.fromJson(p)];
    }
    if (_profiles.isEmpty) {
      // First run, or an install from before profiles: the existing setup
      // becomes the first profile.
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
    if (only != null && !only.hasPin) {
      await select(only);
    } else {
      notifyListeners();
    }
  }

  Future<AppStorage> storageFor(Profile p) =>
      AppStorage.at(Directory('${root.root.path}/profiles/${p.id}'),
          logosDir: root.logosDir, analysisDir: root.analysisDir);

  /// Switches to [p]. PINs are checked by the caller.
  Future<void> select(Profile p) async {
    final previous = _app;
    if (previous != null) await previous.close();
    final app = AppState(await storageFor(p), maxRatingRank: p.maxRatingRank, runAnalysis: runAnalysis);
    _current = p;
    _app = app;
    notifyListeners();
    await app.start();
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
    if (previous != null) unawaited(previous.close());
    _app = null;
    _current = null;
    notifyListeners();
  }

  // ---- Managing profiles ---------------------------------------------------

  /// A new, unsaved profile for the profile editor.
  Profile newProfile() => Profile(id: _newId(), name: '', color: _profiles.length % avatarColorCount);

  bool isSaved(Profile p) => _profiles.any((x) => x.id == p.id);

  /// Why saving [draft] (new or edited) isn't allowed, if it isn't.
  String? problemWith(Profile draft) =>
      _problemIn([for (final p in _profiles) if (p.id != draft.id) p, draft]);

  /// Why deleting [p] isn't allowed, if it isn't.
  String? problemDeleting(Profile p) {
    if (p.id == _current?.id) return 'Switch to another profile before deleting this one.';
    return _problemIn([for (final x in _profiles) if (x.id != p.id) x]);
  }

  static String? _problemIn(List<Profile> profiles) {
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
    }
    notifyListeners();
  }

  /// Deletes [p] and everything it saved, signing its device out of Jellyfin.
  Future<void> deleteProfile(Profile p) async {
    final problem = problemDeleting(p);
    if (problem != null) throw StateError(problem);
    final storage = await storageFor(p);
    final session = await storage.readJson('session.json');
    if (session is Map<String, Object?>) {
      final client = JellyfinClient.fromSession(JellyfinSession.fromJson(session),
          deviceName: Platform.localHostname);
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
