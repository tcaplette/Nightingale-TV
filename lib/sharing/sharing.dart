import 'package:flutter/foundation.dart';

/// Whether this build has sharing (share-accounts D2).
///
/// Only release builds made with a `sharing.env` have it, and each talks only
/// to the backend named in its own file: the official builds use the official
/// backend, and builds from source can use a self-hosted one (SELF_HOSTING.md).
/// Debug and profile builds, release builds without a `sharing.env`, and
/// server mode show no sharing UI, make no request to any backend and ignore
/// invite links.
abstract final class Sharing {
  /// The sharing backend's address, from `sharing.env` at build time.
  static const url = String.fromEnvironment('NTV_SHARE_URL');

  /// The backend's publishable key. It's public by design: the backend's
  /// row-level security is the protection, not this key.
  static const key = String.fromEnvironment('NTV_SHARE_KEY');

  /// The invite-link host, as in `https://<host>/ntv/i/<CODE>`.
  static const host = String.fromEnvironment('NTV_SHARE_HOST');

  /// Set by server mode before anything else starts.
  static bool serverMode = false;

  /// Tests turn sharing on or off without a release build.
  @visibleForTesting
  static bool? debugAvailable;

  static bool get available =>
      debugAvailable ??
      (kReleaseMode && !serverMode && url.isNotEmpty && key.isNotEmpty && host.isNotEmpty);
}
