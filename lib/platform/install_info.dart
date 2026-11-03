import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_info.dart';

/// Where an Android install came from (install-switching D4).
enum InstallSource { googlePlay, officialApk, ownBuild }

/// What kind of Android install this is, and whether the other Nightingale
/// TV app (the official one for an own build, the own build for the official
/// one) is on the device too.
class InstallInfo {
  const InstallInfo({
    required this.ownBuild,
    this.installer,
    this.counterpartInstalled = false,
    this.counterpartFirstInstallTime,
  });

  factory InstallInfo.fromMap(Map<Object?, Object?> m) => InstallInfo(
        ownBuild: m['ownBuild'] == true,
        installer: m['installer'] as String?,
        counterpartInstalled: m['counterpartInstalled'] == true,
        counterpartFirstInstallTime: (m['counterpartFirstInstallTime'] as num?)?.toInt(),
      );

  static const officialName = 'Nightingale TV';
  static const ownBuildName = 'Nightingale TV (own build)';

  static const googlePlayInstaller = 'com.android.vending';

  final bool ownBuild;

  /// The package that installed this app, if any (only a hint: the wording
  /// depends on it, nothing else does).
  final String? installer;

  final bool counterpartInstalled;

  /// When the other app was installed, in ms: the both-installed notice shows
  /// once per value.
  final int? counterpartFirstInstallTime;

  InstallSource get source => ownBuild
      ? InstallSource.ownBuild
      : switch (installer) {
          googlePlayInstaller => InstallSource.googlePlay,
          _ => InstallSource.officialApk,
        };

  String get appName => ownBuild ? ownBuildName : officialName;
  String get counterpartName => ownBuild ? officialName : ownBuildName;

  /// About this install's first line.
  String get sourceLine => switch (source) {
        InstallSource.googlePlay => 'Installed from Google Play',
        InstallSource.officialApk => 'Official Nightingale TV APK',
        InstallSource.ownBuild => 'Your own build',
      };

  /// What switching to another version means from this install.
  String get switching => switch (source) {
        InstallSource.googlePlay || InstallSource.officialApk =>
          'Updates from Google Play and official Nightingale TV APKs install over this one and keep your setup. '
              'A build of your own installs as a separate app, "$ownBuildName", and your setup can be moved to it from here.',
        InstallSource.ownBuild =>
          'The store version installs beside this one as a separate app, "$officialName", with its own setup. '
              'Buying it supports the project. Once it\'s installed, your setup can be moved to it from here.',
      };

  static const uninstallWarning =
      'Uninstalling this app deletes its profiles, channels and settings unless you back them up or move them first.';
}

/// What the other app sent: a setup to restore, or a request for this one's.
sealed class Handover {
  const Handover();
}

/// The other app asked for this app's setup ("Bring my setup here").
class SetupRequested extends Handover {
  const SetupRequested();
}

/// The other app sent its setup ("Move my setup to …"): a backup file,
/// unchecked, at most the size cap and one byte.
class SetupReceived extends Handover {
  const SetupReceived(this.bytes);

  final Uint8List bytes;
}

/// The official app and the own build side by side (InstallSwitching.kt).
/// Nothing on other platforms: [info] is null there.
abstract final class InstallSwitching {
  static const _channel = MethodChannel('nightingale_tv/install');

  /// Pretends to be this install, in tests.
  @visibleForTesting
  static InstallInfo? debugInfo;

  /// Takes the place of handing a setup over (moveSetup) or asking for one
  /// (askForSetup, with null), in tests.
  @visibleForTesting
  static Future<bool> Function(Uint8List? bytes)? debugSend;

  /// The handover waiting to be dealt with: from the start (see [listen])
  /// or later. Whoever handles it sets this back to null.
  static final pending = ValueNotifier<Handover?>(null);

  /// This install, or null off Android.
  static Future<InstallInfo?> info() async {
    if (debugInfo case final info?) return info;
    if (!PlatformInfo.isAndroid) return null;
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>('info');
      return m == null ? null : InstallInfo.fromMap(m);
    } on Object catch (e) {
      debugPrint('Install info unavailable: $e');
      return null;
    }
  }

  /// Hands [bytes] (a backup file) to the other app, which opens with it.
  /// False when it couldn't be started.
  static Future<bool> moveSetup(Uint8List bytes) async {
    if (debugSend case final send?) return send(bytes);
    return await _channel.invokeMethod<bool>('moveSetup', {'bytes': bytes}) ?? false;
  }

  /// Opens the other app on "Send your setup to …?".
  static Future<bool> askForSetup() async {
    if (debugSend case final send?) return send(null);
    return await _channel.invokeMethod<bool>('askForSetup') ?? false;
  }

  static bool _listening = false;

  /// Starts passing on handovers: one that started the app, and any later.
  static void listen() {
    if (_listening || !PlatformInfo.isAndroid) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'handoverArrived') await _take();
    });
    unawaited(_take());
  }

  static Future<void> _take() async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>('takeHandover');
      switch (m?['kind']) {
        case 'send':
          pending.value = const SetupRequested();
        case 'receive':
          pending.value = SetupReceived(m!['bytes'] as Uint8List? ?? Uint8List(0));
      }
    } on Object catch (e) {
      debugPrint('Handover unavailable: $e');
    }
  }

  @visibleForTesting
  static void debugReset() {
    debugInfo = null;
    debugSend = null;
    pending.value = null;
  }
}
