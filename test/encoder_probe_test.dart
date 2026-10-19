import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/export/encode_args.dart';
import 'package:nightingale_tv/export/encoder_probe.dart';
import 'package:nightingale_tv/export/export_settings.dart';

void main() {
  /// A probe where only [working] encoders succeed; records what it tried.
  (EncoderProbe, List<String>) probeWith(Set<String> working, {bool device = true}) {
    final tried = <String>[];
    final probe = EncoderProbe(
      hasVaapiDevice: () async => device,
      run: (exe, args) async {
        final codec = args[args.indexOf('-c:v') + 1];
        tried.add(codec);
        return ProcessResult(1, working.contains(codec) ? 0 : 1, '', 'no device');
      },
    );
    return (probe, tried);
  }

  test('VAAPI first', () async {
    final (probe, tried) = probeWith({'h264_vaapi', 'h264_nvenc'});
    expect(await probe.encoderFor(ExportEncoderChoice.automatic), VideoEncoder.vaapi);
    expect(tried, ['h264_vaapi']);
  });

  test('NVENC when VAAPI fails, and the result is kept', () async {
    final (probe, tried) = probeWith({'h264_nvenc'});
    expect(await probe.encoderFor(ExportEncoderChoice.automatic), VideoEncoder.nvenc);
    expect(await probe.encoderFor(ExportEncoderChoice.automatic), VideoEncoder.nvenc);
    expect(tried, ['h264_vaapi', 'h264_nvenc']);
  });

  test('no VAAPI device skips VAAPI; nothing works means the processor', () async {
    final (probe, tried) = probeWith({}, device: false);
    expect(await probe.encoderFor(ExportEncoderChoice.automatic), VideoEncoder.x264);
    expect(tried, ['h264_nvenc']);
  });

  test('"Processor only" skips the probe', () async {
    final (probe, tried) = probeWith({'h264_vaapi'});
    expect(await probe.encoderFor(ExportEncoderChoice.processorOnly), VideoEncoder.x264);
    expect(tried, isEmpty);
  });
}
