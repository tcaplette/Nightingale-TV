import 'ffmpeg_programs.dart';
export 'ffmpeg_programs.dart';

class ConversionException implements Exception {
  const ConversionException(this.message);

  final String message;

  @override
  String toString() => 'ConversionException: $message';
}

/// The H.264 encoders a conversion can use.
enum ConversionEncoder {
  mediacodec('h264_mediacodec'),
  vaapi('h264_vaapi'),
  nvenc('h264_nvenc'),
  x264('libx264');

  const ConversionEncoder(this.codec);

  final String codec;

  static ConversionEncoder? fromName(String? name) => values.where((e) => e.name == name).firstOrNull;
}

/// One way of converting a file (smb-conversion): what becomes of its
/// picture and sound. It is carried whole in the conversion's URL, so a
/// decision's template is everything a job needs.
class ConversionSpec {
  const ConversionSpec({
    this.copyVideo = false,
    this.copyAudio = false,
    this.videoBitrate = 6000000,
    this.channels = 2,
    this.width,
    this.height,
    this.tonemap = false,
    this.deinterlace = false,
    this.startAt = Duration.zero,
    this.burn,
    this.job,
    this.helper,
    this.hasAudio = true,
  });

  /// The largest picture a device converts HDR to: tone-mapping is done in
  /// software, and costs by the pixel.
  static const hdrLimit = (width: 1280, height: 720);

  /// The picture as it is (a direct stream), else H.264.
  final bool copyVideo;

  /// The sound as it is, else AAC in [channels] channels.
  final bool copyAudio;

  /// Bits per second, of a converted picture.
  final int videoBitrate;
  final int channels;

  /// The converted picture's size; null for the source's.
  final int? width, height;

  /// The source is HDR and the picture is converted.
  final bool tonemap;
  final bool deinterlace;

  /// Where in the file it starts.
  final Duration startAt;

  /// The picture subtitle track (its place among the file's subtitle
  /// tracks) drawn into the picture.
  final int? burn;

  /// The play session it belongs to.
  final String? job;

  /// The paired Nightingale TV that does it; null for this device.
  final String? helper;
  final bool hasAudio;

  /// Holding a track drawn in, the picture has to be converted.
  bool get convertsVideo => !copyVideo || burn != null;

  ConversionSpec copyWith({int? videoBitrate, Duration? startAt, int? Function()? burn, String? job, String? Function()? helper}) =>
      ConversionSpec(
        copyVideo: copyVideo,
        copyAudio: copyAudio,
        videoBitrate: videoBitrate ?? this.videoBitrate,
        channels: channels,
        width: width,
        height: height,
        tonemap: tonemap,
        deinterlace: deinterlace,
        startAt: startAt ?? this.startAt,
        burn: burn == null ? this.burn : burn(),
        job: job ?? this.job,
        helper: helper == null ? this.helper : helper(),
        hasAudio: hasAudio,
      );

  /// `VideoBitrate` is named as Jellyfin's URLs name it, so the tuner's
  /// bitrate limit for a conversion applies to it (`limitConversion`).
  Map<String, String> toQuery() => {
        if (copyVideo) 'v': 'copy',
        if (copyAudio) 'a': 'copy',
        'VideoBitrate': '$videoBitrate',
        'ac': '$channels',
        if (width != null) 'w': '$width',
        if (height != null) 'h': '$height',
        if (tonemap) 'hdr': '1',
        if (deinterlace) 'di': '1',
        if (startAt > Duration.zero) 'ss': FfmpegPrograms.seconds(startAt),
        if (burn != null) 'burn': '$burn',
        'job': ?job,
        'helper': ?helper,
        if (!hasAudio) 'mute': '1',
      };

  factory ConversionSpec.fromQuery(Map<String, String> q) => ConversionSpec(
        copyVideo: q['v'] == 'copy',
        copyAudio: q['a'] == 'copy',
        videoBitrate: (int.tryParse(q['VideoBitrate'] ?? '') ?? 6000000).clamp(300000, 60000000),
        channels: (int.tryParse(q['ac'] ?? '') ?? 2).clamp(1, 8),
        width: _size(q['w']),
        height: _size(q['h']),
        tonemap: q['hdr'] == '1',
        deinterlace: q['di'] == '1',
        startAt: Duration(milliseconds: ((double.tryParse(q['ss'] ?? '') ?? 0).clamp(0, 1e6) * 1000).round()),
        burn: int.tryParse(q['burn'] ?? ''),
        job: q['job'],
        helper: q['helper'],
        hasAudio: q['mute'] != '1',
      );

  static int? _size(String? s) => switch (int.tryParse(s ?? '')) {
        final n? when n >= 16 && n <= 8192 => n & ~1,
        _ => null,
      };

  /// HDR to SDR, as Jellyfin's own software path does it.
  static const _tonemap = 'zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,'
      'tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p';

  /// ffmpeg's arguments for reading [input] and writing MPEG-TS to its
  /// output, from 0 at [startAt]. [trial]: that long, converted to nowhere.
  List<String> arguments(String input, {required ConversionEncoder encoder, Duration? trial}) {
    final video = convertsVideo;
    final picture = [
      if (deinterlace) 'bwdif=deint=interlaced',
      if (tonemap) _tonemap,
      if (width != null && height != null) 'scale=$width:$height' else 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
    ].join(',');
    final upload = switch (encoder) {
      ConversionEncoder.vaapi => 'format=nv12,hwupload',
      ConversionEncoder.mediacodec => 'format=nv12',
      _ => 'format=yuv420p',
    };
    return [
      ...FfmpegPrograms.quiet,
      if (video && encoder == ConversionEncoder.vaapi) ...['-vaapi_device', '/dev/dri/renderD128'],
      '-fflags',
      '+genpts',
      '-analyzeduration',
      '5000000',
      '-probesize',
      '5000000',
      if (startAt > Duration.zero) ...['-ss', FfmpegPrograms.seconds(startAt)],
      if (trial != null) ...['-t', FfmpegPrograms.seconds(trial)],
      '-i',
      input,
      if (video && burn != null) ...[
        '-filter_complex',
        '[0:v:0]$picture[p];[0:s:$burn]scale=${width ?? 'iw'}:${height ?? 'ih'}[s];[p][s]overlay=eof_action=pass,$upload[v]',
        '-map',
        '[v]',
      ] else ...[
        '-map',
        '0:v:0',
        if (video) ...['-vf', '$picture,$upload'],
      ],
      if (hasAudio) ...['-map', '0:a:0?'],
      '-sn',
      '-dn',
      '-map_metadata',
      '-1',
      '-map_chapters',
      '-1',
      if (video) ..._videoArguments(encoder) else ...[
        '-c:v',
        'copy',
        // A copied picture starts at the keyframe before the join point.
        // What comes before the join is squeezed into its last moments, so
        // the player decodes through it at once and shows the join on time.
        if (startAt > Duration.zero) ...['-bsf:v', r'setts=pts=if(lt(PTS\,0)\,PTS*0.01\,PTS):dts=if(lt(DTS\,0)\,DTS*0.01\,DTS)'],
      ],
      if (hasAudio)
        if (copyAudio && startAt == Duration.zero) ...['-c:a', 'copy'] else if (copyAudio) ...[
          '-c:a',
          'copy',
          '-copypriorss:a',
          '0',
        ] else ...[
          '-c:a',
          'aac',
          '-ac',
          '$channels',
          '-ar',
          '48000',
          '-b:a',
          '${channels > 2 ? 384 : 192}k',
        ],
      if (trial != null) ...['-f', 'null', '-'] else ...[
        '-max_muxing_queue_size',
        '4096',
        '-muxdelay',
        '0',
        '-muxpreload',
        '0',
        '-flush_packets',
        '1',
        '-f',
        'mpegts',
        'pipe:1',
      ],
    ];
  }

  List<String> _videoArguments(ConversionEncoder encoder) {
    final rate = '$videoBitrate', buffer = '${videoBitrate * 2}';
    return [
      '-c:v',
      encoder.codec,
      ...switch (encoder) {
        ConversionEncoder.x264 => ['-preset', 'ultrafast', '-tune', 'fastdecode', '-profile:v', 'high', '-maxrate', rate, '-bufsize', buffer],
        ConversionEncoder.mediacodec => const <String>[],
        ConversionEncoder.vaapi => ['-profile:v', 'high', '-maxrate', rate, '-bufsize', buffer],
        ConversionEncoder.nvenc => ['-preset', 'fast', '-profile:v', 'high', '-maxrate', rate, '-bufsize', buffer],
      },
      '-b:v',
      rate,
      '-g',
      '60',
    ];
  }
}
