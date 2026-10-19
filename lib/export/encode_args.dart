import 'export_settings.dart';

/// The H.264 encoders exported streams can use, best first.
enum VideoEncoder {
  vaapi('h264_vaapi', 'Graphics card (VAAPI)'),
  nvenc('h264_nvenc', 'Graphics card (NVENC)'),
  x264('libx264', 'Processor');

  const VideoEncoder(this.codec, this.label);

  final String codec;
  final String label;

  bool get hardware => this != x264;
}

/// The device VAAPI encodes on.
const vaapiDevice = '/dev/dri/renderD128';

/// ffmpeg command lines for Live TV export (design D5). Each list is the
/// arguments to `nice`, so encoders run at low priority with signals going
/// to ffmpeg itself. Inputs are loopback proxy URLs or local files: no
/// token or Jellyfin address is ever on a command line.
abstract final class EncodeArgs {
  static const frameRate = '30000/1001';
  static const _fpsNum = 30000, _fpsDen = 1001;

  /// [d] in whole frames at 29.97 fps.
  static int framesIn(Duration d) => (d.inMicroseconds * _fpsNum / (_fpsDen * 1000000)).round();

  /// How long [frames] last.
  static Duration framesLength(int frames) => Duration(microseconds: (frames * _fpsDen * 1000000 / _fpsNum).round());

  static const _nice = ['-n', '10', 'ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error'];

  static List<String> _device(VideoEncoder e) => e == VideoEncoder.vaapi ? ['-vaapi_device', vaapiDevice] : const [];

  /// Scaled into the frame, at 29.97 fps from 0, exactly [frames] long: the
  /// cut is made in each track's own filter chain (`trim`, `atrim`), since
  /// an output-wide -frames:v or -t ends the file early or a frame short.
  static String _filters(ExportQuality q, VideoEncoder e, int frames) {
    final w = q.width, h = q.height;
    final f =
        'scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black,setsar=1,'
        'fps=$frameRate:start_time=0,trim=end_frame=$frames';
    return e == VideoEncoder.vaapi ? '$f,format=nv12,hwupload' : '$f,format=yuv420p';
  }

  static List<String> _video(ExportQuality q, VideoEncoder e) {
    final rate = '${q.mbps}M', buf = '${q.mbps * 2}M';
    return [
      '-c:v',
      e.codec,
      if (e == VideoEncoder.x264) ...['-preset', 'veryfast'],
      if (e == VideoEncoder.nvenc) ...['-preset', 'fast'],
      '-profile:v',
      'high',
      '-bf',
      '0',
      '-g',
      '60',
      '-keyint_min',
      '60',
      '-sc_threshold',
      '0',
      '-b:v',
      rate,
      '-maxrate',
      rate,
      '-bufsize',
      buf,
    ];
  }

  /// Audio as long as the video ([frames]), cut two AAC frames (2048
  /// samples) short. Audio starts one frame before the video (encoder
  /// priming) and its last frame is rounded up by as much as one more, so
  /// anything less can run into the next segment. What's left is 0–21 ms
  /// of silence at a boundary.
  static List<String> _audio(int frames) {
    final end = framesLength(frames).inMicroseconds / 1e6 - 2048 / 48000;
    return [
      '-c:a',
      'aac',
      '-ac',
      '2',
      '-ar',
      '48000',
      '-b:a',
      '192k',
      '-af',
      'aresample=async=1:first_pts=0,apad,atrim=end=${end.toStringAsFixed(6)}',
    ];
  }

  static const _out = ['-f', 'mpegts', '-muxdelay', '0', '-muxpreload', '0'];

  /// One program part or commercial: [frames] frames of [input] from
  /// [from], to stdout. [audio] false gives it silence.
  static List<String> segment({
    required Uri input,
    required Duration from,
    required int frames,
    required ExportQuality quality,
    required VideoEncoder encoder,
    bool audio = true,
  }) => [
    ..._nice,
    ..._device(encoder),
    '-ss',
    _seconds(from),
    '-i',
    '$input',
    if (!audio) ...['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo'],
    '-map',
    '0:v:0',
    '-map',
    audio ? '0:a:0?' : '1:a:0',
    '-vf',
    _filters(quality, encoder, frames),
    ..._video(quality, encoder),
    ..._audio(frames),
    '-progress',
    'pipe:2',
    ..._out,
    'pipe:1',
  ];

  /// A card's 1 s chunk (30 frames, one GOP, silent), written to [output].
  static List<String> cardChunk({
    required String png,
    required String output,
    required ExportQuality quality,
    required VideoEncoder encoder,
  }) => [
    ..._nice,
    '-y',
    ..._device(encoder),
    '-loop',
    '1',
    '-framerate',
    frameRate,
    '-i',
    png,
    '-f',
    'lavfi',
    '-i',
    'anullsrc=r=48000:cl=stereo',
    '-map',
    '0:v:0',
    '-map',
    '1:a:0',
    '-vf',
    _filters(quality, encoder, 30),
    ..._video(quality, encoder),
    ..._audio(30),
    ..._out,
    output,
  ];

  /// The copying muxer: real-time paced, from stdin to stdout.
  static const muxer = [
    '-nostdin',
    '-hide_banner',
    '-loglevel',
    'error',
    '-re',
    '-f',
    'mpegts',
    '-i',
    'pipe:0',
    '-map',
    '0',
    '-c',
    'copy',
    '-f',
    'mpegts',
    '-mpegts_flags',
    '+resend_headers',
    'pipe:1',
  ];

  /// Whether [encoder] works: a second of test pattern, thrown away.
  static List<String> probe(VideoEncoder encoder, ExportQuality quality) => [
    '-nostdin',
    '-hide_banner',
    '-loglevel',
    'error',
    ..._device(encoder),
    '-f',
    'lavfi',
    '-i',
    'testsrc2=s=${quality.width}x${quality.height}:r=$frameRate',
    '-t',
    '1',
    '-vf',
    _uploadOnly(encoder),
    ..._video(quality, encoder),
    '-f',
    'null',
    '-',
  ];

  static String _uploadOnly(VideoEncoder encoder) =>
      encoder == VideoEncoder.vaapi ? 'format=nv12,hwupload' : 'format=yuv420p';

  static String _seconds(Duration d) => (d.inMicroseconds / 1e6).toStringAsFixed(3);
}
