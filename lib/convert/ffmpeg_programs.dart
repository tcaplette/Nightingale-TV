import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../platform/platform_info.dart';
import '../platform/smb_platform.dart';

/// The ffmpeg and ffprobe programs files of a share are read and converted
/// with: the system's on Linux, the app's own on Android (built by
/// tool/build_ffmpeg_android.sh; a build without them has none).
class FfmpegPrograms {
  const FfmpegPrograms({required this.ffmpeg, required this.ffprobe, this.android = false, this.libraries});

  final String ffmpeg;
  final String ffprobe;
  final bool android;

  /// Where the programs' own libraries are (Android); null for the system's.
  final String? libraries;

  /// What the programs are started with.
  Map<String, String>? get environment => libraries == null ? null : {'LD_LIBRARY_PATH': libraries!};

  static Future<FfmpegPrograms?>? _found;

  /// The programs, looked for once per launch; null when there are none.
  static Future<FfmpegPrograms?> find() => _found ??= _find();

  /// Looks again next time (tests).
  static void reset([FfmpegPrograms? use]) => _found = use == null ? null : Future.value(use);

  static Future<FfmpegPrograms?> _find() async {
    if (PlatformInfo.isAndroid) {
      final folder = await SmbPlatform.nativeLibraryDir();
      if (folder == null) return null;
      final programs =
          FfmpegPrograms(ffmpeg: '$folder/libffmpeg.so', ffprobe: '$folder/libffprobe.so', android: true, libraries: folder);
      return await File(programs.ffmpeg).exists() && await File(programs.ffprobe).exists() ? programs : null;
    }
    try {
      for (final program in const ['ffmpeg', 'ffprobe']) {
        if ((await Process.run(program, const ['-version'])).exitCode != 0) return null;
      }
      return const FfmpegPrograms(ffmpeg: 'ffmpeg', ffprobe: 'ffprobe');
    } on ProcessException {
      return null;
    }
  }

  /// Runs [program] on [arguments], returning what it wrote, or null when it
  /// failed or took longer than [timeout].
  Future<Uint8List?> _run(String program, List<String> arguments,
      {Duration timeout = const Duration(seconds: 30), int limit = 32 << 20, bool low = false}) async {
    final Process process;
    try {
      process = low && !android
          ? await Process.start('nice', ['-n', '10', program, ...arguments])
          : await Process.start(program, arguments, environment: environment);
    } on ProcessException catch (e) {
      // Not a broken file: the program isn't there to read it.
      throw FfmpegMissing(e.message);
    }
    final timer = Timer(timeout, () => process.kill(ProcessSignal.sigkill));
    final out = BytesBuilder(copy: false);
    try {
      process.stderr.drain<void>().ignore();
      await for (final data in process.stdout) {
        out.add(data);
        if (out.length > limit) {
          process.kill(ProcessSignal.sigkill);
          return null;
        }
      }
      final code = await process.exitCode;
      // nice couldn't find or run it.
      if (code == 127 || code == 126) throw FfmpegMissing('$program exited $code');
      return code == 0 ? out.takeBytes() : null;
    } finally {
      timer.cancel();
    }
  }

  /// What ffprobe says of [input]; null when it can't be read.
  Future<Map<String, Object?>?> probe(String input, {Duration timeout = const Duration(seconds: 45)}) async {
    final out = await _run(
        ffprobe,
        ['-v', 'error', '-show_format', '-show_streams', '-show_chapters', '-of', 'json', '-i', input],
        timeout: timeout,
        low: true);
    if (out == null) return null;
    try {
      final json = jsonDecode(utf8.decode(out, allowMalformed: true));
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  /// Whether [seconds] of [input]'s picture ([video]) and sound
  /// ([audio]) decode: false when ffmpeg gives up on them (a stream current
  /// decoders refuse), null when it couldn't tell in time.
  Future<bool?> decodes(String input, {required bool video, required bool audio, int seconds = 4, Duration timeout = const Duration(seconds: 60)}) async {
    final arguments = [
      ...quiet, '-t', '$seconds', '-i', input, //
      if (video) ...['-map', '0:v:0'],
      if (audio) ...['-map', '0:a:0?'],
      '-sn', '-dn', '-f', 'null', '-',
    ];
    final Process process;
    try {
      process = !android
          ? await Process.start('nice', ['-n', '10', ffmpeg, ...arguments])
          : await Process.start(ffmpeg, arguments, environment: environment);
    } on ProcessException catch (e) {
      throw FfmpegMissing(e.message);
    }
    process.stdout.drain<void>().ignore();
    process.stderr.drain<void>().ignore();
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      process.kill(ProcessSignal.sigkill);
    });
    final code = await process.exitCode;
    timer.cancel();
    if (code == 127 || code == 126) throw FfmpegMissing('$ffmpeg exited $code');
    return timedOut ? null : code == 0;
  }

  /// The picture inside [input] (an album cover), as it is.
  Future<Uint8List?> cover(String input) => _run(ffmpeg, [
        ...quiet, '-i', input, '-map', '0:v:0', '-frames:v', '1', '-c', 'copy', '-f', 'image2pipe', 'pipe:1', //
      ], limit: 16 << 20, low: true);

  /// Subtitle track [track] of [input] (its only one when null), as [format]
  /// (`srt`, `vtt` or `ass`), its cues timed from [start].
  Future<Uint8List?> subtitle(String input, {int? track, required String format, Duration start = Duration.zero}) =>
      _run(ffmpeg, subtitleArguments(input, track: track, format: format, start: start),
          timeout: const Duration(minutes: 3), low: true);

  static List<String> subtitleArguments(String input, {int? track, required String format, Duration start = Duration.zero}) => [
        ...quiet,
        if (start > Duration.zero) ...['-ss', seconds(start)],
        '-i',
        input,
        '-map',
        '0:s:${track ?? 0}',
        '-vn',
        '-an',
        '-f',
        switch (format) { 'vtt' => 'webvtt', 'ass' => 'ass', _ => 'srt' },
        'pipe:1',
      ];

  static const quiet = ['-nostdin', '-hide_banner', '-loglevel', 'error'];

  static String seconds(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(3);
}

/// ffmpeg or ffprobe couldn't be started.
class FfmpegMissing implements Exception {
  const FfmpegMissing(this.message);

  final String message;

  @override
  String toString() => 'FfmpegMissing: $message';
}
