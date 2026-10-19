import 'dart:math';

/// The output format of exported streams.
enum ExportQuality {
  p1080('1080p', 1920, 1080, 8),
  p720('720p', 1280, 720, 4);

  const ExportQuality(this.label, this.width, this.height, this.mbps);

  final String label;
  final int width;
  final int height;

  /// Video bitrate (and maxrate), in megabits per second.
  final int mbps;

  static ExportQuality fromJson(Object? json) => values.where((q) => q.label == json).firstOrNull ?? p1080;
}

/// Which encoders exported streams may use.
enum ExportEncoderChoice {
  /// The graphics card when it can, else the processor.
  automatic('auto'),

  /// Always the processor (`libx264`).
  processorOnly('cpu');

  const ExportEncoderChoice(this.json);

  final String json;

  static ExportEncoderChoice fromJson(Object? json) =>
      values.where((e) => e.json == json).firstOrNull ?? automatic;
}

/// One profile's export: whether it's on, and the address and tuner identity
/// Plex and Jellyfin remember it by. Kept while export is off, so turning it
/// back on finds the same device in the same place.
class ProfileExport {
  const ProfileExport({required this.exported, required this.port, required this.deviceId, required this.deviceAuth});

  final bool exported;
  final int port;

  /// 8 hex digits passing the HDHomeRun checksum ([HdHomeRunId]).
  final String deviceId;
  final String deviceAuth;

  ProfileExport copyWith({bool? exported, int? port}) => ProfileExport(
        exported: exported ?? this.exported,
        port: port ?? this.port,
        deviceId: deviceId,
        deviceAuth: deviceAuth,
      );

  Map<String, Object?> toJson() => {'exported': exported, 'port': port, 'deviceId': deviceId, 'deviceAuth': deviceAuth};

  /// Null when the entry is unusable (hand-edited); the profile then counts
  /// as never exported.
  static ProfileExport? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final port = json['port'];
    final id = json['deviceId'];
    final auth = json['deviceAuth'];
    if (port is! int || port <= 0 || port > 65535) return null;
    if (id is! String || !HdHomeRunId.isValid(id) || auth is! String || auth.isEmpty) return null;
    return ProfileExport(exported: json['exported'] == true, port: port, deviceId: id, deviceAuth: auth);
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileExport &&
      other.exported == exported &&
      other.port == port &&
      other.deviceId == deviceId &&
      other.deviceAuth == deviceAuth;

  @override
  int get hashCode => Object.hash(exported, port, deviceId, deviceAuth);
}

/// Live TV export: off unless the user turns it on. Per PC (`export.json`
/// in the household root), with an entry per profile that was ever
/// exported.
class ExportSettings {
  const ExportSettings({
    this.enabled = false,
    this.quality = ExportQuality.p1080,
    this.streamLimit,
    this.encoder = ExportEncoderChoice.automatic,
    this.discovery = true,
    this.profiles = const {},
  });

  static const off = ExportSettings();

  /// The first profile's port; later ones get the lowest free port above.
  static const firstPort = 5004;

  final bool enabled;
  final ExportQuality quality;

  /// Streams at once across every profile; null is Automatic (2 with a
  /// graphics-card encoder, 1 without).
  final int? streamLimit;
  final ExportEncoderChoice encoder;

  /// Announce exported profiles over SSDP.
  final bool discovery;

  /// By profile id.
  final Map<String, ProfileExport> profiles;

  static const streamLimitChoices = [1, 2, 3, 4];

  /// The limit in effect, given whether a hardware encoder works.
  int effectiveStreamLimit({required bool hardware}) => streamLimit ?? (hardware ? 2 : 1);

  bool isExported(String profileId) => profiles[profileId]?.exported ?? false;

  /// Profiles whose lineups are being served (with export on).
  Iterable<String> get exportedProfileIds =>
      enabled ? [for (final e in profiles.entries) if (e.value.exported) e.key] : const [];

  ExportSettings copyWith({
    bool? enabled,
    ExportQuality? quality,
    int? Function()? streamLimit,
    ExportEncoderChoice? encoder,
    bool? discovery,
    Map<String, ProfileExport>? profiles,
  }) =>
      ExportSettings(
        enabled: enabled ?? this.enabled,
        quality: quality ?? this.quality,
        streamLimit: streamLimit == null ? this.streamLimit : streamLimit(),
        encoder: encoder ?? this.encoder,
        discovery: discovery ?? this.discovery,
        profiles: profiles ?? this.profiles,
      );

  /// Turns [profileId]'s export on or off. The first time it's turned on,
  /// the profile gets a port ([portFree] says whether one is free right
  /// now), a DeviceID and a DeviceAuth; after that it keeps them.
  ExportSettings withExported(String profileId, bool on, {required bool Function(int port) portFree, Random? random}) {
    final existing = profiles[profileId];
    if (existing != null) return _withProfile(profileId, existing.copyWith(exported: on));
    if (!on) return this;
    final rng = random ?? Random.secure();
    return _withProfile(
      profileId,
      ProfileExport(
        exported: true,
        port: _nextPort(portFree),
        deviceId: HdHomeRunId.generate(rng),
        deviceAuth: _randomAuth(rng),
      ),
    );
  }

  /// [profileId]'s export moved to [port] (edited on the screen).
  ExportSettings withPort(String profileId, int port) {
    final existing = profiles[profileId];
    return existing == null ? this : _withProfile(profileId, existing.copyWith(port: port));
  }

  /// Forgets [profileId] (the profile was deleted).
  ExportSettings without(String profileId) =>
      copyWith(profiles: {for (final e in profiles.entries) if (e.key != profileId) e.key: e.value});

  /// Whether another profile already has [port].
  bool portTaken(int port, {String? except}) =>
      profiles.entries.any((e) => e.key != except && e.value.port == port);

  ExportSettings _withProfile(String id, ProfileExport p) => copyWith(profiles: {...profiles, id: p});

  int _nextPort(bool Function(int port) portFree) {
    for (var p = firstPort; p <= 65535; p++) {
      if (!portTaken(p) && portFree(p)) return p;
    }
    throw StateError('No free port for Live TV export.');
  }

  static const _authChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String _randomAuth(Random rng) => String.fromCharCodes(
        List.generate(24, (_) => _authChars.codeUnitAt(rng.nextInt(_authChars.length))),
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'quality': quality.label,
        'streamLimit': streamLimit,
        'encoder': encoder.json,
        'discovery': discovery,
        'profiles': {for (final e in profiles.entries) e.key: e.value.toJson()},
      };

  /// A missing or unreadable file is off. Unusable values fall back to
  /// their defaults.
  factory ExportSettings.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return off;
    final limit = json['streamLimit'];
    final profiles = json['profiles'];
    return ExportSettings(
      enabled: json['enabled'] == true,
      quality: ExportQuality.fromJson(json['quality']),
      streamLimit: limit is int && streamLimitChoices.contains(limit) ? limit : null,
      encoder: ExportEncoderChoice.fromJson(json['encoder']),
      discovery: json['discovery'] != false,
      profiles: {
        if (profiles is Map<String, Object?>)
          for (final e in profiles.entries) e.key: ?ProfileExport.fromJson(e.value),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExportSettings &&
      other.enabled == enabled &&
      other.quality == quality &&
      other.streamLimit == streamLimit &&
      other.encoder == encoder &&
      other.discovery == discovery &&
      _mapEquals(other.profiles, profiles);

  @override
  int get hashCode => Object.hash(enabled, quality, streamLimit, encoder, discovery, Object.hashAllUnordered(profiles.entries.map((e) => Object.hash(e.key, e.value))));

  static bool _mapEquals(Map<String, ProfileExport> a, Map<String, ProfileExport> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

/// HDHomeRun DeviceIDs: 8 hex digits whose checksum (libhdhomerun's
/// `hdhomerun_discover_validate_device_id`) comes out to zero.
abstract final class HdHomeRunId {
  static const _table = [0xA, 0x5, 0xF, 0x6, 0x7, 0xC, 0x1, 0xB, 0x9, 0x2, 0x8, 0xD, 0x4, 0x3, 0xE, 0x0];

  static int _checksum(int id) {
    var c = 0;
    for (final shift in const [28, 20, 12, 4]) {
      c ^= _table[(id >> shift) & 0xF];
      c ^= (id >> (shift - 4)) & 0xF;
    }
    return c;
  }

  static bool isValid(String id) {
    if (id.length != 8) return false;
    final n = int.tryParse(id, radix: 16);
    return n != null && _checksum(n) == 0;
  }

  /// A random valid id: 7 random digits, then the one last digit that makes
  /// the checksum zero (the last digit is XORed in as is).
  static String generate(Random rng) {
    final high = rng.nextInt(1 << 28) << 4;
    final id = high | _checksum(high);
    return id.toRadixString(16).toUpperCase().padLeft(8, '0');
  }
}
