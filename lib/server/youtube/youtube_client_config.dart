import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A Google OAuth client of the type "TVs and Limited Input devices"
/// (youtube-subscriptions D4). Its secret isn't confidential by Google's own
/// definition for this type; it stays out of the repository so forks don't
/// spend the app's quota.
class GoogleClient {
  const GoogleClient({required this.id, required this.secret, this.own = false});

  final String id;
  final String secret;

  /// The user's own client (D10), not the app's shared one.
  final bool own;

  /// The app's shared client, read at start-up by [loadShared] from the
  /// git-ignored asset [sharedAsset] (youtube-shared-client D1); null in a
  /// build without that file, whose YouTube button then says so.
  static GoogleClient? get shared => sharedOverride ?? _shared;

  static GoogleClient? _shared;

  /// Tests: a shared client where the build has none.
  @visibleForTesting
  static GoogleClient? sharedOverride;

  /// Google's downloaded client file, as the app bundles it.
  static const sharedAsset = 'assets/youtube/client/nightingale-tv-youtube.json';

  /// Server mode (docker-youtube): every YouTube sign-in uses the user's own
  /// client, so none has the shared client's channel limit, and a sign-in
  /// without a client is refused.
  static bool get ownOnly => ownOnlyOverride ?? _ownOnly;
  static bool _ownOnly = false;

  /// Tests: server mode's rule without loading anything.
  @visibleForTesting
  static bool? ownOnlyOverride;

  /// Reads [sharedAsset] into [shared]. A missing or unreadable file leaves
  /// it null. Server mode never loads it (D7): there YouTube uses only the
  /// user's own client ([ownOnly]).
  static Future<void> loadShared({bool serverMode = false, AssetBundle? bundle}) async {
    _shared = null;
    _ownOnly = serverMode;
    if (serverMode) return;
    try {
      _shared = fromDownload(jsonDecode(await (bundle ?? rootBundle).loadString(sharedAsset, cache: false)), own: false);
    } catch (_) {
      // No file in this build, or not a client file.
    }
  }

  /// Reads Google's downloaded client file ({"installed": {"client_id",
  /// "client_secret"}}); null when it isn't one.
  static GoogleClient? fromDownload(Object? json, {bool own = true}) {
    if (json is! Map) return null;
    for (final section in json.values) {
      if (section is Map && section['client_id'] is String && section['client_secret'] is String) {
        final id = (section['client_id'] as String).trim(), secret = (section['client_secret'] as String).trim();
        if (id.isNotEmpty && secret.isNotEmpty) return GoogleClient(id: id, secret: secret, own: own);
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is GoogleClient && other.id == id && other.secret == secret;

  @override
  int get hashCode => Object.hash(id, secret);
}
