// The Android device profile (android-playback, "The device profile
// describes the device"), built from fixed capability inputs.
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/playback/android_device_profile.dart';

const _h264 = VideoDecoderCaps(
    codec: 'h264', profiles: ['baseline', 'main', 'high'], maxWidth: 3840, maxHeight: 2160, maxFps: 60, fps1080: 60);

DeviceCapabilities caps({
  bool main10 = true,
  List<VideoDecoderCaps> extra = const [],
  Set<String> audio = const {'aac', 'mp3', 'opus', 'flac', 'pcm'},
  Set<String> passthrough = const {},
}) =>
    DeviceCapabilities(
      video: [
        _h264,
        VideoDecoderCaps(
          codec: 'hevc',
          profiles: main10 ? const ['main', 'main 10'] : const ['main'],
          bitDepth: main10 ? 10 : 8,
          maxWidth: 3840,
          maxHeight: 2160,
          maxFps: 60,
          fps1080: 60,
        ),
        ...extra,
      ],
      audio: audio,
      passthrough: passthrough,
      maxChannels: 6,
    );

List<Map<String, Object?>> _list(Map<String, Object?> p, String key) => (p[key] as List).cast<Map<String, Object?>>();

Set<String> _codecs(Object? v) => {for (final c in '${v ?? ''}'.split(',')) if (c.isNotEmpty) c};

Map<String, Object?> _directPlay(Map<String, Object?> p, String container) =>
    _list(p, 'DirectPlayProfiles').firstWhere((d) => '${d['Container']}'.split(',').contains(container));

Map<String, Object?> _ts(Map<String, Object?> p) => _list(p, 'TranscodingProfiles').single;

String? _condition(Map<String, Object?> p, String codec, String property) {
  for (final c in _list(p, 'CodecProfiles').where((c) => c['Codec'] == codec && c['ApplyConditions'] == null)) {
    for (final cond in (c['Conditions'] as List).cast<Map<String, Object?>>()) {
      if (cond['Property'] == property) return '${cond['Condition']} ${cond['Value']}';
    }
  }
  return null;
}

void main() {
  test('HEVC Main 10 in hardware: direct play takes it, up to 10-bit, and the conversion may copy it', () {
    final p = androidDeviceProfile(caps());
    for (final container in ['mkv', 'mp4', 'ts']) {
      expect(_codecs(_directPlay(p, container)['VideoCodec']), containsAll(['h264', 'hevc']), reason: container);
    }
    expect(_condition(p, 'hevc', 'VideoProfile'), 'EqualsAny main|main 10');
    expect(_condition(p, 'hevc', 'VideoBitDepth'), 'LessThanEqual 10');
    expect(_condition(p, 'hevc', 'Width'), 'LessThanEqual 3840');
    expect(_condition(p, 'hevc', 'Height'), 'LessThanEqual 2160');
    expect(_condition(p, 'hevc', 'VideoFramerate'), 'LessThanEqual 60');
    final ts = _ts(p);
    expect(ts['Container'], 'ts');
    expect('${ts['VideoCodec']}'.split(',').first, 'h264', reason: 'H.264 is the conversion target');
    expect(_codecs(ts['VideoCodec']), contains('hevc'), reason: 'the video may be copied');
    expect('${ts['AudioCodec']}'.split(',').first, 'aac');
  });

  test('HEVC without Main 10: 10-bit HEVC is converted', () {
    final p = androidDeviceProfile(caps(main10: false));
    expect(_condition(p, 'hevc', 'VideoProfile'), 'EqualsAny main');
    expect(_condition(p, 'hevc', 'VideoBitDepth'), 'LessThanEqual 8');
  });

  test('no hardware AV1 decoder: AV1 never direct-plays or gets copied', () {
    final p = androidDeviceProfile(caps());
    for (final d in _list(p, 'DirectPlayProfiles')) {
      expect(_codecs(d['VideoCodec']), isNot(contains('av1')));
    }
    expect(_codecs(_ts(p)['VideoCodec']), isNot(contains('av1')));
    expect(_list(p, 'CodecProfiles').where((c) => c['Codec'] == 'av1'), isEmpty);
  });

  test('a hardware AV1 decoder plays AV1 in MKV and MP4, never copied into MPEG-TS', () {
    final p = androidDeviceProfile(caps(extra: [
      const VideoDecoderCaps(codec: 'av1', profiles: ['main'], bitDepth: 10, maxWidth: 3840, maxHeight: 2160, maxFps: 60)
    ]));
    expect(_codecs(_directPlay(p, 'mkv')['VideoCodec']), contains('av1'));
    expect(_codecs(_directPlay(p, 'mp4')['VideoCodec']), contains('av1'));
    expect(_codecs(_directPlay(p, 'ts')['VideoCodec']), isNot(contains('av1')));
    expect(_codecs(_ts(p)['VideoCodec']), isNot(contains('av1')));
  });

  test('no DTS decoder or passthrough: DTS audio is converted, the video kept', () {
    final p = androidDeviceProfile(caps());
    for (final d in _list(p, 'DirectPlayProfiles')) {
      expect(_codecs(d['AudioCodec']), isNot(contains('dts')));
    }
    expect(_codecs(_ts(p)['AudioCodec']), isNot(contains('dts')));
    expect(_codecs(_directPlay(p, 'mkv')['AudioCodec']), containsAll(['aac', 'opus', 'flac']));
  });

  test('AC-3 passed through over HDMI: AC-3 direct-plays and may be copied', () {
    final p = androidDeviceProfile(caps(passthrough: {'ac3', 'eac3'}));
    expect(_codecs(_directPlay(p, 'mkv')['AudioCodec']), containsAll(['ac3', 'eac3']));
    expect(_codecs(_ts(p)['AudioCodec']), containsAll(['aac', 'ac3', 'eac3']));
    expect(_ts(p)['MaxAudioChannels'], '6');
  });

  test('a decoder faster at 1080p than at 4K gets both frame rates', () {
    const v = VideoDecoderCaps(codec: 'vp9', profiles: ['profile 0'], maxWidth: 3840, maxHeight: 2160, maxFps: 30, fps1080: 60);
    final p = androidDeviceProfile(DeviceCapabilities(video: const [_h264, v], audio: const {'aac'}));
    final vp9 = _list(p, 'CodecProfiles').where((c) => c['Codec'] == 'vp9').toList();
    expect(_condition(p, 'vp9', 'VideoFramerate'), 'LessThanEqual 60');
    final over1080 = vp9.singleWhere((c) => c['ApplyConditions'] != null);
    expect((over1080['ApplyConditions'] as List).single, containsPair('Value', '1921'));
    expect((over1080['Conditions'] as List).single, containsPair('Value', '30'));
  });

  test('the cap sets the streaming bitrate; with none, Jellyfin is told there is no limit', () {
    expect(androidDeviceProfile(caps())['MaxStreamingBitrate'], unlimitedBitrate);
    expect(androidDeviceProfile(caps())['MaxStaticBitrate'], unlimitedBitrate);
    expect(androidDeviceProfile(caps(), maxBitrate: 8000000)['MaxStreamingBitrate'], 8000000);
  });

  test('H.264 always plays, even when the device reports no decoders', () {
    final p = androidDeviceProfile(const DeviceCapabilities(video: [], audio: {}));
    expect(_codecs(_directPlay(p, 'mp4')['VideoCodec']), {'h264'});
  });

  test('reads what DeviceCapabilities.kt reports', () {
    final c = DeviceCapabilities.fromMap({
      'sdk': 34,
      'video': [
        {'codec': 'hevc', 'profiles': ['main', 'main 10'], 'bitDepth': 10, 'maxWidth': 3840, 'maxHeight': 2160, 'maxFps': 60, 'fps1080': 120},
      ],
      'audio': ['aac', 'opus'],
      'passthrough': ['ac3'],
      'maxChannels': 8,
      'decoders': ['c2.x.hevc.decoder video/hevc hardware'],
    });
    expect(c.videoCodec('hevc')!.profiles, ['main', 'main 10']);
    expect(c.videoCodec('hevc')!.fps1080, 120);
    expect(c.audio, {'aac', 'opus'});
    expect(c.passthrough, {'ac3'});
    expect(c.maxChannels, 8);
    expect(c.decoders, hasLength(1));
  });

  group('a conversion with no cap', () {
    Uri jellyfins(String extra) => Uri.parse(
        'https://jf.example/videos/x/stream.ts?VideoCodec=h264&VideoBitrate=999776000&AudioBitrate=224000$extra');

    test('asks for twice the source from HEVC, VP9 or AV1, and the source itself otherwise', () {
      expect(limitConversion(jellyfins(''), sourceBitrate: 2200000, sourceCodec: 'hevc').queryParameters['VideoBitrate'],
          '4400000');
      expect(limitConversion(jellyfins(''), sourceBitrate: 3000000, sourceCodec: 'AV1').queryParameters['VideoBitrate'],
          '6000000');
      expect(
          limitConversion(jellyfins(''), sourceBitrate: 8000000, sourceCodec: 'mpeg2video').queryParameters['VideoBitrate'],
          '8000000');
    });

    test('keeps the rest of the URL, and a lower bitrate Jellyfin chose', () {
      final t = limitConversion(jellyfins('&TranscodeReasons=VideoProfileNotSupported'),
          sourceBitrate: 2200000, sourceCodec: 'hevc');
      expect(t.queryParameters['VideoCodec'], 'h264');
      expect(t.queryParameters['AudioBitrate'], '224000');
      expect(t.queryParameters['TranscodeReasons'], 'VideoProfileNotSupported');
      final low = Uri.parse('https://jf.example/videos/x/stream.ts?videoBitrate=3000000');
      expect(limitConversion(low, sourceBitrate: 2200000, sourceCodec: 'hevc'), low);
    });

    test('never below 1.5 Mbps, and unchanged when the source bitrate is unknown', () {
      expect(limitConversion(jellyfins(''), sourceBitrate: 300000, sourceCodec: 'h264').queryParameters['VideoBitrate'],
          '1500000');
      expect(limitConversion(jellyfins(''), sourceBitrate: null), jellyfins(''));
    });
  });

  group('the decision', () {
    Uri template(String reasons) =>
        Uri.parse('https://jf.example/videos/x/stream.ts?VideoCodec=h264,hevc&TranscodeReasons=$reasons');

    test('only container or audio reasons: a direct stream (the video is copied)', () {
      expect(JellyfinClient.keepsVideo(template('ContainerNotSupported'), const {}), isTrue);
      expect(JellyfinClient.keepsVideo(template('AudioCodecNotSupported,ContainerNotSupported'), const {}), isTrue);
    });

    test('any video reason, or a bitrate over the limit: a transcode', () {
      expect(JellyfinClient.keepsVideo(template('VideoCodecNotSupported'), const {}), isFalse);
      expect(JellyfinClient.keepsVideo(template('AudioCodecNotSupported,VideoBitDepthNotSupported'), const {}), isFalse);
      expect(JellyfinClient.keepsVideo(template('ContainerBitrateExceedsLimit'), const {}), isFalse);
      expect(JellyfinClient.keepsVideo(Uri.parse('https://jf.example/videos/x/stream.ts'), const {}), isFalse);
    });

    test('reasons from the media source when the URL has none', () {
      expect(
          JellyfinClient.keepsVideo(Uri.parse('https://jf.example/videos/x/stream.ts'), const {
            'TranscodeReasons': ['AudioCodecNotSupported']
          }),
          isTrue);
    });
  });
}
