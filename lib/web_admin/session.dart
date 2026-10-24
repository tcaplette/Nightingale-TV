import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// A profile as the web admin lists it.
class ProfileInfo {
  ProfileInfo(this.json);

  final Map<String, Object?> json;

  String get id => json['id'] as String;
  String get name => json['name'] as String;
  bool get isKid => json['kind'] == 'kid';
  int get color => json['color'] as int? ?? 0;
  bool get hasPin => json['hasPin'] == true;
  bool get exported => json['exported'] == true;

  /// Signed in to its media server.
  bool get signedIn => json['signedIn'] == true;

  /// A non-admin must give its PIN first.
  bool get locked => json['locked'] == true;

  /// A non-admin must give a grown-up's PIN to change its settings.
  bool get needsGrownUp => json['needsGrownUp'] == true;
}

/// Who's signed in, the profiles they may use and the one being edited
/// (design D8).
class Session extends ChangeNotifier {
  Session(this.api);

  final ApiClient api;

  /// `GET me`, or null when signed out.
  Map<String, Object?>? me;
  List<ProfileInfo> profiles = const [];

  /// The profile the pages edit.
  String? profileId;

  bool get signedIn => me != null;
  bool get isAdmin => me?['role'] == 'admin';
  String get userName => me?['name'] as String? ?? '';

  ProfileInfo? get profile => profiles.where((p) => p.id == profileId).firstOrNull;

  ProfileInfo? profileById(String id) => profiles.where((p) => p.id == id).firstOrNull;

  /// Reads who's signed in and their profiles; false when signed out.
  Future<bool> refresh() async {
    try {
      // The public sign-in state first, so a signed-out visit asks nothing
      // that would be refused.
      final auth = (await api.get('auth'))! as Map<String, Object?>;
      if (auth['signedIn'] != true) {
        clear();
        return false;
      }
      me = (await api.get('me'))! as Map<String, Object?>;
      profiles = [for (final p in (await api.get('profiles'))! as List) ProfileInfo(p as Map<String, Object?>)];
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
      clear();
      return false;
    }
    if (profileId == null || profile == null) profileId = profiles.firstOrNull?.id;
    notifyListeners();
    return true;
  }

  void select(String id) {
    if (profileId == id) return;
    profileId = id;
    notifyListeners();
  }

  void clear() {
    me = null;
    profiles = const [];
    profileId = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.delete('session');
    } on ApiException {
      // Signed out either way.
    }
    clear();
  }
}
