import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../jellyfin/jellyfin_client.dart';
import '../l10n/tr.dart';

/// One video codec as the device's hardware decoders take it, in Jellyfin's
/// names (android/app/src/main/kotlin/…/DeviceCapabilities.kt).
class VideoDecoderCaps {
  const VideoDecoderCaps({
    required this.codec,
    this.profiles = const [],
    this.bitDepth = 8,
    this.maxWidth = 0,
    this.maxHeight = 0,
    this.maxFps = 0,
    this.fps1080 = 0,
  });

  factory VideoDecoderCaps.fromMap(Map<Object?, Object?> m) => VideoDecoderCaps(
        codec: '${m['codec']}',
        profiles: [for (final p in m['profiles'] as List? ?? const []) '$p'],
        bitDepth: (m['bitDepth'] as num?)?.toInt() ?? 8,
        maxWidth: (m['maxWidth'] as num?)?.toInt() ?? 0,
        maxHeight: (m['maxHeight'] as num?)?.toInt() ?? 0,
        maxFps: (m['maxFps'] as num?)?.toInt() ?? 0,
        fps1080: (m['fps1080'] as num?)?.toInt() ?? 0,
      );

  /// Jellyfin's codec name (h264, hevc, av1…).
  final String codec;

  /// Jellyfin's profile names ("main", "main 10"…); empty when the decoders
  /// don't say.
  final List<String> profiles;
  final int bitDepth;

  /// The largest size decoded, and the frame rate at that size (0: unknown).
  final int maxWidth, maxHeight, maxFps;

  /// The frame rate at 1080p (0: unknown).
  final int fps1080;

  @override
  String toString() =>
      '$codec ${profiles.isEmpty ? '' : '[${profiles.join('/')}] '}${bitDepth}bit ${maxWidth}x$maxHeight@$maxFps 1080p@$fps1080';
}

/// What the Android device plays (design D3): its hardware video decoders,
/// the audio it decodes, and the audio its output takes as it is.
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.video,
    required this.audio,
    this.passthrough = const {},
    this.maxChannels = 2,
    this.decoders = const [],
  });

  factory DeviceCapabilities.fromMap(Map<Object?, Object?> m) => DeviceCapabilities(
        video: [
          for (final v in (m['video'] as List? ?? const []).cast<Map<Object?, Object?>>()) VideoDecoderCaps.fromMap(v)
        ],
        audio: {for (final a in m['audio'] as List? ?? const []) '$a'},
        passthrough: {for (final a in m['passthrough'] as List? ?? const []) '$a'},
        maxChannels: (m['maxChannels'] as num?)?.toInt() ?? 2,
        decoders: [for (final d in m['decoders'] as List? ?? const []) '$d'],
      );

  static const _channel = MethodChannel('nightingale_tv/player');

  /// When the device can't say: what every Android device decodes in
  /// hardware.
  static const fallback = DeviceCapabilities(
    video: [
      VideoDecoderCaps(
          codec: 'h264',
          profiles: ['baseline', 'constrained baseline', 'main', 'high'],
          maxWidth: 1920,
          maxHeight: 1080,
          maxFps: 30),
    ],
    audio: {'aac', 'mp3', 'pcm'},
  );

  /// Asks the device (Android only); null if it can't say.
  static Future<DeviceCapabilities?> query() async {
    try {
      final m = await _channel.invokeMethod<Map<Object?, Object?>>('capabilities');
      return m == null ? null : DeviceCapabilities.fromMap(m);
    } on Object catch (e) {
      // No platform side (tests), or the device wouldn't say.
      debugPrint('Device capabilities unavailable: $e');
    }
    return null;
  }

  final List<VideoDecoderCaps> video;

  /// Audio a decoder on the device takes.
  final Set<String> audio;

  /// Audio the output takes as it is (AC-3 over HDMI…).
  final Set<String> passthrough;

  /// The most channels the audio output plays.
  final int maxChannels;

  /// Every decoder, as "name type hardware|software" (diagnostics).
  final List<String> decoders;

  VideoDecoderCaps? videoCodec(String codec) => video.where((v) => v.codec == codec).firstOrNull;

  @override
  String toString() =>
      'video: ${video.join('; ')} | audio: ${audio.join(',')} | passthrough: ${passthrough.join(',')} | channels: $maxChannels';
}

/// A bitrate Jellyfin reads as "no limit" (its own default is 8 Mbps, which
/// would convert anything above it).
const unlimitedBitrate = 1000000000;

/// Codecs that need about twice the bitrate as H.264 for the same picture.
const _efficientCodecs = {'hevc', 'h265', 'vp9', 'av1'};

/// The lowest video bitrate [limitConversion] asks for, so a source whose
/// bitrate is misreported as tiny still converts watchably.
const _conversionFloor = 1500000;

/// [template], a transcode that re-encodes the video, asked with no cap, held
/// to what keeps the original picture: the source's video bitrate, or twice
/// it from a codec more efficient than H.264. With no cap Jellyfin would
/// encode at its own ceiling (8.6 Mbps for a 2.2 Mbps HEVC episode), more
/// than the picture needs and than many servers and connections keep up
/// with. The cap in Settings still lowers it further.
///
/// Unchanged when the source's bitrate isn't known. Never for a direct
/// stream: Jellyfin re-encodes a copied video whose bitrate is over what its
/// URL allows.
///
/// Plex's transcode URLs hold the limit as `maxVideoBitrate`, in kbps.
Uri limitConversion(Uri template, {required int? sourceBitrate, String? sourceCodec}) {
  if (sourceBitrate == null || sourceBitrate <= 0) return template;
  final factor = _efficientCodecs.contains(sourceCodec?.toLowerCase()) ? 2 : 1;
  final limit = max(sourceBitrate * factor, _conversionFloor);
  final query = {...template.queryParameters};
  final plex = template.path.contains('/transcode/universal/');
  final key = query.keys.firstWhere((k) => k.toLowerCase() == (plex ? 'maxvideobitrate' : 'videobitrate'),
      orElse: () => plex ? 'maxVideoBitrate' : 'VideoBitrate');
  final unit = plex ? 1000 : 1;
  final current = int.tryParse(query[key] ?? '');
  if (current != null && current * unit <= limit) return template;
  query[key] = '${limit ~/ unit}';
  return template.replace(queryParameters: query);
}

/// Containers ExoPlayer reads, with the video codecs each can hold.
const _containers = {
  'mp4,m4v,mov': {'h264', 'hevc', 'av1', 'vp9', 'mpeg4', 'h263'},
  'mkv,webm': {'h264', 'hevc', 'av1', 'vp9', 'vp8', 'mpeg2video', 'mpeg4', 'vc1'},
  'ts,mpegts,m2ts': {'h264', 'hevc', 'mpeg2video'},
};

/// What Jellyfin may copy into its MPEG-TS stream (and the device then
/// plays from it).
const _tsVideo = ['hevc', 'mpeg2video'];
const _tsAudio = ['mp3', 'ac3', 'eac3', 'dts'];

/// The device profile sent with every `PlaybackInfo` on Android, built from
/// [caps]: Jellyfin direct-plays what the hardware decodes, direct-streams
/// (copies the video) when only the container or audio doesn't fit, and
/// converts the rest to H.264/AAC in MPEG-TS. [maxBitrate] (bits per
/// second) is the cap; null for none. With [leveling] (volume leveling on),
/// the audio is decoded on the device to be leveled, so audio only passed
/// through to the output is left out and Jellyfin converts it.
Map<String, Object?> androidDeviceProfile(DeviceCapabilities caps, {int? maxBitrate, bool leveling = false}) {
  // The conversion target always plays.
  final videoCodecs = {'h264', for (final v in caps.video) v.codec};
  final audioCodecs = {...caps.audio, if (!leveling) ...caps.passthrough};
  String list(Iterable<String> codecs) => codecs.join(',');
  final bitrate = maxBitrate ?? unlimitedBitrate;

  return {
    'Name': '${JellyfinClient.clientName} (Android)',
    'MaxStreamingBitrate': bitrate,
    'MaxStaticBitrate': bitrate,
    'DirectPlayProfiles': [
      for (final MapEntry(key: container, value: holds) in _containers.entries)
        {
          'Container': container,
          'Type': 'Video',
          'VideoCodec': list(videoCodecs.where(holds.contains)),
          'AudioCodec': list(audioCodecs),
        },
      {'Type': 'Audio', 'AudioCodec': list(audioCodecs)},
    ],
    'TranscodingProfiles': [
      {
        'Container': 'ts',
        'Type': 'Video',
        'VideoCodec': list(['h264', ..._tsVideo.where(videoCodecs.contains)]),
        'AudioCodec': list(['aac', ..._tsAudio.where(audioCodecs.contains)]),
        'Protocol': 'http',
        'Context': 'Streaming',
        'MaxAudioChannels': '${caps.maxChannels.clamp(2, 8)}',
        'BreakOnNonKeyFrames': false,
      },
    ],
    'ContainerProfiles': const [],
    'CodecProfiles': [for (final v in caps.video) ..._codecProfiles(v)],
    'SubtitleProfiles': [
      // ExoPlayer shows these from inside the file.
      for (final format in const ['srt', 'subrip', 'ass', 'ssa', 'vtt', 'webvtt', 'pgs', 'pgssub', 'dvdsub', 'dvbsub'])
        {'Format': format, 'Method': 'Embed'},
      for (final format in const ['srt', 'subrip', 'ass', 'ssa', 'vtt']) {'Format': format, 'Method': tr.externalLabel},
    ],
  };
}

Map<String, Object?> _condition(String condition, String property, Object value) =>
    {'Condition': condition, 'Property': property, 'Value': '$value', 'IsRequired': false};

/// What [v]'s decoders take: profiles, bit depth, size and frame rate. A
/// decoder that does 1080p faster than its largest size gets the faster rate
/// up to 1080p.
List<Map<String, Object?>> _codecProfiles(VideoDecoderCaps v) {
  final over1080 = v.maxWidth > 1920 || v.maxHeight > 1080;
  final baseFps = over1080 && v.fps1080 > v.maxFps ? v.fps1080 : v.maxFps;
  return [
    {
      'Type': 'Video',
      'Codec': v.codec,
      'Conditions': [
        if (v.profiles.isNotEmpty) _condition('EqualsAny', 'VideoProfile', v.profiles.join('|')),
        _condition('LessThanEqual', 'VideoBitDepth', v.bitDepth),
        if (v.maxWidth > 0) _condition('LessThanEqual', 'Width', v.maxWidth),
        if (v.maxHeight > 0) _condition('LessThanEqual', 'Height', v.maxHeight),
        if (baseFps > 0) _condition('LessThanEqual', 'VideoFramerate', baseFps),
      ],
    },
    if (over1080 && v.fps1080 > v.maxFps && v.maxFps > 0)
      {
        'Type': 'Video',
        'Codec': v.codec,
        'ApplyConditions': [_condition('GreaterThanEqual', 'Width', 1921)],
        'Conditions': [_condition('LessThanEqual', 'VideoFramerate', v.maxFps)],
      },
  ];
}
