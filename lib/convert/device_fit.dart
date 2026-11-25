import '../server/smb/smb_probe.dart';

/// How a file from a share plays on this device (smb-conversion, "How a
/// file from a share plays").
enum FitMethod {
  /// As it is.
  direct,

  /// The picture as it is; the container and/or sound converted.
  directStream,

  /// The picture converted to H.264.
  transcode,
}

/// Decides [FitMethod] for a file from what was read of it ([SmbProbe])
/// and the same Jellyfin-style device profile Android sends media servers
/// (`androidDeviceProfile`), by that profile's own rules, so a file plays
/// the same way from a share as from a server.
abstract final class DeviceFit {
  /// ffprobe's container names, as profiles name containers.
  static Set<String> containersOf(String formatName, String extension) {
    final names = {for (final n in formatName.split(',')) n.trim().toLowerCase()};
    return {
      ...names,
      extension.toLowerCase(),
      if (names.contains('matroska')) ...{'mkv', 'webm'},
      if (names.contains('mov') || names.contains('mp4')) ...{'mp4', 'm4v', 'mov'},
      if (names.contains('mpegts')) ...{'ts', 'mpegts', 'm2ts'},
      if (names.contains('mpeg')) ...{'mpeg', 'mpg', 'vob'},
      if (names.contains('asf')) ...{'asf', 'wmv'},
    };
  }

  /// ffprobe's codec names as profiles name them.
  static String codecOf(String codec) => switch (codec) {
        'dca' => 'dts',
        'h265' => 'hevc',
        final c when c.startsWith('pcm_') => 'pcm',
        final c => c,
      };

  static List<String> _list(Object? value) => [
        for (final s in '${value ?? ''}'.split(','))
          if (s.trim().isNotEmpty) s.trim().toLowerCase()
      ];

  static bool _condition(Map<String, Object?> c, ProbeVideo v) {
    final value = '${c['Value'] ?? ''}';
    final number = double.tryParse(value);
    final double? actual = switch (c['Property']) {
      'VideoBitDepth' => v.bitDepth.toDouble(),
      'Width' => v.width.toDouble(),
      'Height' => v.height.toDouble(),
      'VideoFramerate' => v.fps,
      'VideoLevel' => v.level.toDouble(),
      _ => null,
    };
    switch (c['Condition']) {
      case 'EqualsAny' when c['Property'] == 'VideoProfile':
        return v.profile.isEmpty || value.toLowerCase().split('|').contains(v.profile);
      case 'LessThanEqual':
        return actual == null || number == null || actual == 0 || actual <= number;
      case 'GreaterThanEqual':
        return actual == null || number == null || actual >= number;
      case 'Equals':
        return actual == null || number == null || actual == number;
      case 'NotEquals':
        return actual == null || number == null || actual != number;
      default:
        return true;
    }
  }

  /// Whether the device's decoders take [video] (its codec profiles).
  static bool decodes(Map<String, Object?> profile, ProbeVideo video) {
    final codec = codecOf(video.codec);
    for (final p in (profile['CodecProfiles'] as List? ?? const []).whereType<Map<String, Object?>>()) {
      if (p['Type'] != 'Video' || !_list(p['Codec']).contains(codec)) continue;
      final applies = (p['ApplyConditions'] as List? ?? const []).whereType<Map<String, Object?>>();
      if (!applies.every((c) => _condition(c, video))) continue;
      if (!(p['Conditions'] as List? ?? const []).whereType<Map<String, Object?>>().every((c) => _condition(c, video))) {
        return false;
      }
    }
    return true;
  }

  /// How [probe] of a file named [extension] plays under [profile].
  static FitMethod decide(SmbProbe probe, String extension, Map<String, Object?> profile) {
    final video = probe.video;
    final audio = probe.audio.firstOrNull;
    final containers = containersOf(probe.container, extension);
    final videoCodec = video == null ? null : codecOf(video.codec);
    final audioCodec = audio == null ? null : codecOf(audio.codec);
    final direct = (profile['DirectPlayProfiles'] as List? ?? const []).whereType<Map<String, Object?>>();
    final decodable = video == null || decodes(profile, video);
    bool takesAudio(List<String> codecs) => audioCodec == null || codecs.isEmpty || codecs.contains(audioCodec);
    for (final p in direct) {
      if (p['Type'] != 'Video' || video == null) continue;
      final inContainer = p['Container'] == null || _list(p['Container']).any(containers.contains);
      final videoOk = _list(p['VideoCodec']).isEmpty || _list(p['VideoCodec']).contains(videoCodec);
      if (inContainer && videoOk && decodable && takesAudio(_list(p['AudioCodec']))) return FitMethod.direct;
    }
    // MPEG-TS holds the picture as it is when the device decodes it.
    final ts = (profile['TranscodingProfiles'] as List? ?? const []).whereType<Map<String, Object?>>().firstOrNull;
    final copies = ts != null && videoCodec != null && _list(ts['VideoCodec']).contains(videoCodec) && decodable;
    return copies ? FitMethod.directStream : FitMethod.transcode;
  }

  /// Whether the sound plays as it is inside a conversion's MPEG-TS.
  static bool keepsAudio(SmbProbe probe, Map<String, Object?> profile) {
    final codec = probe.audio.isEmpty ? null : codecOf(probe.audio.first.codec);
    final ts = (profile['TranscodingProfiles'] as List? ?? const []).whereType<Map<String, Object?>>().firstOrNull;
    return codec != null && ts != null && codec != 'aac' && _list(ts['AudioCodec']).contains(codec);
  }

  /// The most channels a conversion's sound has.
  static int channels(Map<String, Object?> profile) =>
      int.tryParse('${(profile['TranscodingProfiles'] as List? ?? const []).whereType<Map<String, Object?>>().firstOrNull?['MaxAudioChannels'] ?? 2}') ?? 2;
}
