import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/convert/conversion.dart';
import 'package:nightingale_tv/convert/device_fit.dart';
import 'package:nightingale_tv/playback/android_device_profile.dart';
import 'package:nightingale_tv/server/smb/smb_probe.dart';

SmbProbe _probe(String container, String video, String audio,
        {int bits = 8, int width = 1920, int height = 1080, double fps = 23.976, String profile = 'high', bool hdr = false}) =>
    SmbProbe(
      size: 1,
      modified: 1,
      duration: const Duration(minutes: 1),
      container: container,
      video: ProbeVideo(codec: video, profile: profile, width: width, height: height, fps: fps, bitDepth: bits, hdr: hdr),
      audio: [ProbeAudio(codec: audio, channels: 6)],
    );

void main() {
  const hevcMain = VideoDecoderCaps(codec: 'hevc', profiles: ['main'], bitDepth: 8, maxWidth: 3840, maxHeight: 2160, maxFps: 60);
  const avc = VideoDecoderCaps(codec: 'h264', profiles: ['high', 'main', 'baseline'], maxWidth: 1920, maxHeight: 1080, maxFps: 60);
  final tv = androidDeviceProfile(const DeviceCapabilities(video: [avc, hevcMain], audio: {'aac', 'ac3', 'mp3', 'pcm'}));

  test('as the device profile says', () {
    expect(DeviceFit.decide(_probe('mov,mp4,m4a,3gp,3g2,mj2', 'h264', 'aac'), 'mp4', tv), FitMethod.direct);
    expect(DeviceFit.decide(_probe('matroska,webm', 'h264', 'ac3'), 'mkv', tv), FitMethod.direct);
    // DTS the device doesn't decode: the picture stays, the sound converts.
    expect(DeviceFit.decide(_probe('matroska,webm', 'h264', 'dts'), 'mkv', tv), FitMethod.directStream);
    expect(DeviceFit.decide(_probe('matroska,webm', 'h264', 'dca'), 'mkv', tv), FitMethod.directStream);
    // A container ExoPlayer doesn't read, with a picture it decodes.
    expect(DeviceFit.decide(_probe('avi', 'h264', 'mp3'), 'avi', tv), FitMethod.directStream);
    // Pictures it can't decode.
    expect(DeviceFit.decide(_probe('asf', 'vc1', 'wmav2'), 'wmv', tv), FitMethod.transcode);
    expect(DeviceFit.decide(_probe('avi', 'mpeg4', 'mp3', profile: 'advanced simple profile'), 'avi', tv), FitMethod.transcode);
    expect(DeviceFit.decide(_probe('matroska,webm', 'hevc', 'aac', bits: 10, profile: 'main 10', hdr: true), 'mkv', tv), FitMethod.transcode);
    expect(DeviceFit.decide(_probe('matroska,webm', 'h264', 'aac', width: 3840, height: 2160), 'mkv', tv), FitMethod.transcode);
    expect(DeviceFit.decide(_probe('mpeg', 'mpeg2video', 'ac3'), 'mpg', tv), FitMethod.transcode);
  });

  test("the sound is kept when the device plays it in MPEG-TS", () {
    expect(DeviceFit.keepsAudio(_probe('avi', 'h264', 'ac3'), tv), isTrue);
    expect(DeviceFit.keepsAudio(_probe('avi', 'h264', 'dts'), tv), isFalse);
  });

  test('conversion URLs carry the whole job, and only sane values', () {
    const spec = ConversionSpec(copyVideo: true, copyAudio: false, videoBitrate: 4000000, channels: 6, startAt: Duration(seconds: 47), burn: 1, job: 'j');
    final back = ConversionSpec.fromQuery(spec.toQuery());
    expect((back.copyVideo, back.videoBitrate, back.channels, back.startAt, back.burn, back.job, back.convertsVideo),
        (true, 4000000, 6, const Duration(seconds: 47), 1, 'j', true));
    final odd = ConversionSpec.fromQuery({'VideoBitrate': '1', 'ac': '99', 'w': '-4', 'ss': '-5'});
    expect((odd.videoBitrate, odd.channels, odd.width, odd.startAt), (300000, 8, null, Duration.zero));
    // The input is the gateway's own address: no share, path or password.
    final args = spec.arguments('http://127.0.0.1:1/s/t/f/id', encoder: ConversionEncoder.x264);
    expect(args, containsAllInOrder(['-ss', '47.000', '-i', 'http://127.0.0.1:1/s/t/f/id']));
    expect(args.join(' '), contains('overlay'));
    expect(args.last, 'pipe:1');
  });
}
