import 'dart:io';

import 'package:flutter/foundation.dart';

import '../commercials/analysis/ffmpeg_runner.dart';
import 'encode_args.dart';
import 'export_settings.dart';

/// Finds the best H.264 encoder that works on this PC (design D8): VAAPI,
/// then NVENC, then the processor. Checked once per run.
class EncoderProbe {
  EncoderProbe({ProcessRunner? run, Future<bool> Function()? hasVaapiDevice})
      : _run = run ?? Process.run,
        _hasVaapiDevice = hasVaapiDevice ?? (() => File(vaapiDevice).exists());

  final ProcessRunner _run;
  final Future<bool> Function() _hasVaapiDevice;
  Future<VideoEncoder>? _result;

  /// The encoder to use for [choice]; the probe runs the first time.
  Future<VideoEncoder> encoderFor(ExportEncoderChoice choice) async =>
      choice == ExportEncoderChoice.processorOnly ? VideoEncoder.x264 : await (_result ??= _probe());

  Future<VideoEncoder> _probe() async {
    for (final e in [VideoEncoder.vaapi, VideoEncoder.nvenc]) {
      if (e == VideoEncoder.vaapi && !await _hasVaapiDevice()) continue;
      try {
        final r = await _run('ffmpeg', EncodeArgs.probe(e, ExportQuality.p720)).timeout(const Duration(seconds: 15));
        if (r.exitCode == 0) return e;
        debugPrint('Live TV export: ${e.codec} unavailable: ${'${r.stderr}'.trim().split('\n').last}');
      } on Object catch (error) {
        debugPrint('Live TV export: ${e.codec} unavailable: $error');
      }
    }
    return VideoEncoder.x264;
  }
}
