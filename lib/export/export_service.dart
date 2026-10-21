import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/household.dart';
import '../remote/remote_control.dart';
import 'broadcast_art.dart';
import 'card_chunks.dart';
import 'encode_args.dart';
import 'encoder_probe.dart';
import 'export_settings.dart';
import 'export_streams.dart';
import 'hdhomerun.dart';
import 'lineup_server.dart';
import 'ssdp_responder.dart';

/// Why an exported profile isn't being served.
enum ExportProblem {
  /// Its port is taken by another program.
  portInUse,

  /// It isn't signed in to Jellyfin (or the sign-in expired).
  signedOut,
}

/// Live TV export: serves each exported profile's lineup on its own port
/// while the app runs. Owned by [Household], like the phone remote.
class ExportService extends ChangeNotifier {
  ExportService(this.household,
      {this.serverFor, SsdpResponder Function()? ssdp, BroadcastArt? art, EncoderProbe? probe, ExportStreams? streams})
      : _newSsdp = ssdp ?? SsdpResponder.new,
        art = art ?? BroadcastArt(Directory('${household.root.root.path}/export_cache')),
        probe = probe ?? EncoderProbe() {
    this.streams = streams ??
        ExportStreams(
          policy: StreamPolicy(limit: () => streamLimit, quality: () => _settings.quality, encoder: _encoder),
          chunks: CardChunks(this.art),
          streaming: household.exportStreaming,
        );
    this.streams
      ..onChange = notifyListeners
      ..onEvent = (e) => PlaybackDiagnostics.active?.event('Live TV export: $e');
  }

  static const _settingsFile = 'export.json';

  final Household household;

  /// Cards and logos for streams and guides.
  final BroadcastArt art;

  final EncoderProbe probe;

  /// The channels being streamed.
  late final ExportStreams streams;

  /// The encoder in use (after the probe), for the screen.
  VideoEncoder? encoderInUse;

  Future<VideoEncoder> _encoder() async {
    final e = await probe.encoderFor(_settings.encoder);
    if (_settings.encoder == ExportEncoderChoice.automatic) hardwareEncoder = e.hardware;
    if (encoderInUse != e) {
      encoderInUse = e;
      notifyListeners();
    }
    return e;
  }

  /// Builds a profile's server; tests and later layers (streams, tuner
  /// endpoints) plug in here.
  final LineupServer Function(ExportService service, String profileId, ProfileExport export)? serverFor;

  ExportSettings _settings = ExportSettings.off;
  ExportSettings get settings => _settings;

  final _servers = <String, LineupServer>{};
  final _portErrors = <String, int>{};

  /// Whether a graphics-card encoder works (from the encoder probe); sets
  /// the Automatic stream limit.
  bool hardwareEncoder = true;

  /// Streams at once across every profile, as reported to tuner clients.
  int get streamLimit => _settings.effectiveStreamLimit(hardware: hardwareEncoder);

  final SsdpResponder Function() _newSsdp;
  SsdpResponder? _ssdp;

  /// UDP 1900 couldn't be opened; tuners can still be added by address.
  bool discoveryUnavailable = false;

  /// This PC's address on the home network, for showing URLs.
  String? lanHost;

  Future<void> load() async {
    _settings = ExportSettings.fromJson(await household.root.readJson(_settingsFile));
    household.addListener(_onHousehold);
    lanHost = await RemoteControl.lanAddress();
    await _apply();
  }

  /// Stops everything and lets go of the household, for a restore; [load]
  /// starts it again with the restored settings.
  Future<void> unload() async {
    household.removeListener(_onHousehold);
    for (final app in _watched) {
      app.removeListener(notifyListeners);
    }
    _watched.clear();
    _portErrors.clear();
    await stop();
    _settings = ExportSettings.off;
    notifyListeners();
  }

  @override
  void dispose() {
    household.removeListener(_onHousehold);
    unawaited(stop());
    super.dispose();
  }

  /// Stops every server (on exit, or when export is turned off).
  Future<void> stop() async {
    final servers = [..._servers.values];
    _servers.clear();
    await streams.stopAll();
    await _stopDiscovery();
    await Future.wait([for (final s in servers) s.stop()]);
  }

  // ---- Settings ------------------------------------------------------------

  Future<void> setEnabled(bool on) => _update(_settings.copyWith(enabled: on));
  Future<void> setQuality(ExportQuality q) => _update(_settings.copyWith(quality: q));
  Future<void> setStreamLimit(int? limit) => _update(_settings.copyWith(streamLimit: () => limit));
  Future<void> setEncoder(ExportEncoderChoice e) => _update(_settings.copyWith(encoder: e));
  Future<void> setDiscovery(bool on) => _update(_settings.copyWith(discovery: on));

  /// Turns [profileId]'s export on or off. PINs are checked by the caller.
  Future<void> setProfileExported(String profileId, bool on) async {
    var free = 0;
    if (on && !_settings.profiles.containsKey(profileId)) free = await _freePort();
    await _update(_settings.withExported(profileId, on, portFree: (p) => p == free));
  }

  /// Moves [profileId]'s export to [port]. Returns why not, if it can't.
  Future<String?> setPort(String profileId, int port) async {
    if (port < 1024 || port > 65535) return 'Pick a port between 1024 and 65535.';
    if (_settings.portTaken(port, except: profileId)) return 'Another profile already uses port $port.';
    await _update(_settings.withPort(profileId, port));
    return null;
  }

  Future<int> _freePort() async {
    for (var p = ExportSettings.firstPort; p <= 65535; p++) {
      if (_settings.portTaken(p)) continue;
      if (await portFree(p)) return p;
    }
    throw StateError('No free port for Live TV export.');
  }

  /// Whether nothing is listening on [port] right now.
  static Future<bool> portFree(int port) async {
    try {
      final probe = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await probe.close();
      return true;
    } on SocketException {
      return false;
    }
  }

  Future<void> _update(ExportSettings next) async {
    if (next == _settings) return;
    _settings = next;
    await household.root.writeJson(_settingsFile, next.toJson());
    await _apply();
  }

  // ---- Servers -------------------------------------------------------------

  /// Runs a server for each exported profile and stops the rest.
  Future<void> _apply() async {
    final wanted = {
      for (final id in _settings.exportedProfileIds)
        if (household.profileById(id) != null) id,
    };
    for (final id in [..._servers.keys]) {
      final server = _servers[id]!;
      if (!wanted.contains(id) || server.export.port != _settings.profiles[id]!.port) {
        _servers.remove(id);
        if (!wanted.contains(id)) await streams.stopAll(profileId: id);
        await server.stop();
      }
    }
    if (wanted.isNotEmpty) unawaited(_encoder());
    _portErrors.removeWhere((id, _) => !wanted.contains(id));
    await household.setExportedProfiles(wanted);
    for (final id in wanted) {
      final export = _settings.profiles[id]!;
      final existing = _servers[id];
      if (existing != null) {
        existing.export = export;
        continue;
      }
      final server = serverFor?.call(this, id, export) ?? defaultServer(id, export);
      try {
        await server.start();
        _servers[id] = server;
        _portErrors.remove(id);
      } on SocketException catch (e) {
        debugPrint('Live TV export: port ${export.port} is in use ($e).');
        _portErrors[id] = export.port;
      }
    }
    await _syncDiscovery();
    _watchApps();
    notifyListeners();
  }

  /// The exported profiles' states, so the screen follows sign-ins and
  /// sign-outs.
  final _watched = <AppState>{};

  void _watchApps() {
    final now = {
      for (final id in _settings.exportedProfileIds) ?household.appFor(id),
    };
    for (final app in _watched.difference(now)) {
      app.removeListener(notifyListeners);
    }
    for (final app in now.difference(_watched)) {
      app.addListener(notifyListeners);
    }
    _watched
      ..clear()
      ..addAll(now);
  }

  /// SSDP runs while discovery is on and something is exported.
  Future<void> _syncDiscovery() async {
    if (!_settings.enabled || !_settings.discovery || _servers.isEmpty) {
      await _stopDiscovery();
      return;
    }
    final ssdp = _ssdp ??= _newSsdp();
    ssdp.setDevices([
      for (final e in _servers.entries)
        (
          deviceId: e.value.export.deviceId,
          location: addressOf(e.key)!.replace(path: '/device.xml'),
        ),
    ]);
    try {
      await ssdp.start();
      discoveryUnavailable = false;
    } on Object catch (e) {
      debugPrint('Live TV export: SSDP discovery unavailable ($e).');
      discoveryUnavailable = true;
      _ssdp = null;
    }
  }

  Future<void> _stopDiscovery() async {
    final ssdp = _ssdp;
    _ssdp = null;
    discoveryUnavailable = false;
    await ssdp?.stop();
  }

  /// A profile's server with only the lineup, guide and images.
  LineupServer defaultServer(String id, ProfileExport export) => LineupServer(
        profileId: id,
        appFor: () => household.appFor(id),
        profileName: () => household.profileById(id)?.name ?? '',
        export: export,
        device: hdHomeRunEndpoints(tunerCount: () => streamLimit),
        logos: art,
        streamer: streams,
      );

  /// A deleted profile is forgotten; a sign-in or out changes its status.
  void _onHousehold() {
    _watchApps();
    final gone = [for (final id in _settings.profiles.keys) if (household.profileById(id) == null) id];
    if (gone.isEmpty) {
      notifyListeners();
      return;
    }
    var next = _settings;
    for (final id in gone) {
      next = next.without(id);
    }
    unawaited(_update(next));
  }

  // ---- Status --------------------------------------------------------------

  LineupServer? serverOf(String profileId) => _servers[profileId];

  /// Why [profileId]'s export isn't working, if it's exported and isn't.
  ExportProblem? problemOf(String profileId) {
    if (!_settings.exportedProfileIds.contains(profileId)) return null;
    if (_portErrors.containsKey(profileId)) return ExportProblem.portInUse;
    final app = household.appFor(profileId);
    // While a profile's state is still loading, it has no client yet; that
    // isn't a problem.
    if (app != null && app.phase == AppPhase.signedOut) return ExportProblem.signedOut;
    return null;
  }

  /// The message the screen shows for [problemOf].
  String? problemText(String profileId) => switch (problemOf(profileId)) {
        ExportProblem.portInUse => 'Port ${_settings.profiles[profileId]!.port} is in use by another program. '
            'Pick another port, then update it in Plex or Jellyfin.',
        ExportProblem.signedOut => 'Sign in to this profile on the TV to export its channels.',
        null => null,
      };

  /// Where clients reach [profileId]'s lineup, e.g. `http://192.168.1.20:5004`.
  Uri? addressOf(String profileId) {
    final export = _settings.profiles[profileId];
    if (export == null) return null;
    return Uri(scheme: 'http', host: lanHost ?? 'localhost', port: _servers[profileId]?.port ?? export.port);
  }
}
