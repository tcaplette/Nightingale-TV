import '../channels/logo_windows.dart';
import 'export_settings.dart';
import '../l10n/tr.dart';

/// The channel logo burned into a segment (channel-streaming): its PNG and
/// when it shows, relative to the segment's start. With [always], it shows
/// throughout with no fades.
class SegmentLogo {
  const SegmentLogo({required this.png, this.windows = const [], this.always = false});

  final String png;
  final List<({Duration start, Duration end})> windows;
  final bool always;

  /// Whether the segment needs the logo at all.
  bool get shows => always || windows.isNotEmpty;
}

/// The H.264 encoders exported streams can use, best first.
enum VideoEncoder {
  vaapi('h264_vaapi'),
  nvenc('h264_nvenc'),
  x264('libx264');

  const VideoEncoder(this.codec);

  final String codec;

  String get label => switch (this) {
        VideoEncoder.vaapi => tr.graphicsCardVaapi,
        VideoEncoder.nvenc => tr.graphicsCardNvenc,
        VideoEncoder.x264 => tr.processor,
      };

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
  /// With [hold], a source that ends sooner repeats its last picture up to
  /// [frames].
  static String _filters(ExportQuality q, VideoEncoder e, int frames, {bool hold = false}) =>
      '${_picture(q, frames, hold: hold)},${_uploadOnly(e)}';

  /// The picture before encoding: scaled, padded, 29.97 fps, [frames] long.
  static String _picture(ExportQuality q, int frames, {bool hold = false}) {
    final w = q.width, h = q.height;
    return 'scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black,setsar=1,'
        'fps=$frameRate:start_time=0,${hold ? 'tpad=stop=-1:stop_mode=clone,' : ''}trim=end_frame=$frames';
  }

  /// [_picture] of input 0 with [logo] (input [logoInput]) laid over it in
  /// the bottom-right box (see [logoBox]), at 70%, faded in and out over
  /// each window. Drawn on the CPU before the upload, so every encoder gets
  /// the same picture.
  static String _logoGraph(ExportQuality q, VideoEncoder e, int frames, SegmentLogo logo, int logoInput,
      {bool hold = false}) {
    final box = logoBox(q.width.toDouble(), q.height.toDouble());
    final bw = box.maxWidth.floor(), bh = box.height.round(), right = box.right.round(), bottom = box.bottom.round();
    // Right-aligned and centred in the box, as on the TV.
    final at = 'x=main_w-overlay_w-$right:y=main_h-$bottom-($bh+overlay_h)/2';
    final graph = [
      '[0:v]${_picture(q, frames, hold: hold)}[base]',
      '[$logoInput:v]scale=$bw:$bh:force_original_aspect_ratio=decrease,format=rgba,'
          'colorchannelmixer=aa=$logoOpacity[logo]',
    ];
    if (logo.always) {
      graph.add('[base][logo]overlay=$at:shortest=1,${_uploadOnly(e)}[v]');
      return graph.join(';');
    }
    final n = logo.windows.length;
    if (n > 1) graph.add('[logo]split=$n${[for (var i = 0; i < n; i++) '[l$i]'].join()}');
    var under = 'base';
    for (final (i, w) in logo.windows.indexed) {
      final start = _secondsExact(w.start), end = _secondsExact(w.end);
      final length = (w.end - w.start).inMicroseconds / 1e6;
      final fade = length < 2 * logoFade.inMicroseconds / 1e6 ? length / 2 : logoFade.inMicroseconds / 1e6;
      final source = n > 1 ? 'l$i' : 'logo';
      graph.add('[$source]fade=t=in:st=$start:d=${fade.toStringAsFixed(3)}:alpha=1,'
          'fade=t=out:st=${(w.end.inMicroseconds / 1e6 - fade).toStringAsFixed(3)}:d=${fade.toStringAsFixed(3)}:alpha=1[f$i]');
      final last = i == n - 1;
      graph.add("[$under][f$i]overlay=$at:shortest=1:enable='between(t,$start,$end)'"
          "${last ? ',${_uploadOnly(e)}[v]' : '[o$i]'}");
      under = 'o$i';
    }
    return graph.join(';');
  }

  static String _secondsExact(Duration d) => (d.inMicroseconds / 1e6).toStringAsFixed(3);

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
  /// [from], to stdout. [audio] false gives it silence. With [hold] (a
  /// commercial), a file that ends early holds its last picture, with
  /// silence, for the frames left. With a [logo] that shows, it's laid over
  /// the picture; without one, the logo isn't an input at all.
  static List<String> segment({
    required Uri input,
    required Duration from,
    required int frames,
    required ExportQuality quality,
    required VideoEncoder encoder,
    bool audio = true,
    bool hold = false,
    SegmentLogo? logo,
  }) {
    // Inputs, numbered as they're added: the source, then silence if
    // needed, then the logo.
    var inputs = 1;
    final silence = audio ? null : inputs++;
    final withLogo = logo != null && logo.shows ? logo : null;
    final logoInput = withLogo == null ? null : inputs++;
    return [
      ..._nice,
      ..._device(encoder),
      '-ss',
      _seconds(from),
      '-i',
      '$input',
      if (silence != null) ...['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo'],
      if (withLogo != null) ...['-loop', '1', '-framerate', frameRate, '-i', withLogo.png],
      if (withLogo != null) ...['-filter_complex', _logoGraph(quality, encoder, frames, withLogo, logoInput!, hold: hold)],
      '-map',
      withLogo == null ? '0:v:0' : '[v]',
      '-map',
      silence == null ? '0:a:0?' : '$silence:a:0',
      if (withLogo == null) ...['-vf', _filters(quality, encoder, frames, hold: hold)],
      ..._video(quality, encoder),
      ..._audio(frames),
      '-progress',
      'pipe:2',
      ..._out,
      'pipe:1',
    ];
  }

  /// A song (music-channels): [frames] frames of the looped [card] PNG (its
  /// Now Playing card) as the picture, with [input]'s audio from [from].
  static List<String> songSegment({
    required Uri input,
    required String card,
    required Duration from,
    required int frames,
    required ExportQuality quality,
    required VideoEncoder encoder,
  }) => [
    ..._nice,
    ..._device(encoder),
    '-loop',
    '1',
    '-framerate',
    frameRate,
    '-i',
    card,
    '-ss',
    _seconds(from),
    '-i',
    '$input',
    '-map',
    '0:v:0',
    '-map',
    '1:a:0?',
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

  /// The copying muxer: real-time paced, from stdin to stdout. It looks at
  /// half a second of input before its first output, not ffmpeg's default
  /// five, which a stream fed in real time would wait out; every chunk
  /// carries both streams from its start.
  static const muxer = [
    '-nostdin',
    '-hide_banner',
    '-loglevel',
    'error',
    '-re',
    '-analyzeduration',
    '500000',
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
