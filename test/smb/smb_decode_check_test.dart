// A file the device would convert is only scheduled when what the
// conversion decodes does decode (smb-conversion "Can't play"): a sound
// stream current decoders refuse leaves its channel with no picture at
// every airing, so it's listed as damaged instead. ffprobe and ffmpeg are
// stand-in scripts here.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/convert/ffmpeg_programs.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/playback/android_device_profile.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_profile.dart';
import 'package:nightingale_tv/server/smb/smb_server.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

import 'smb_fakes.dart';

/// What ffprobe says of every file: H.264 with TrueHD sound in Matroska,
/// which an Android TV plays only with its sound converted.
const _probe = '''
{"streams":[{"index":0,"codec_type":"video","codec_name":"h264","profile":"High","width":1280,"height":720,"pix_fmt":"yuv420p","r_frame_rate":"30/1","level":31},
{"index":1,"codec_type":"audio","codec_name":"truehd","channels":6}],
"format":{"format_name":"matroska,webm","duration":"180.0","bit_rate":"2000000"}}
''';

void main() {
  late Directory dir;
  late File decodeExit;
  late List<String> decodeCalls;
  late File callLog;

  setUpAll(() async {
    SmbGateway.inIsolate = false;
    IndexBuilder.useIsolate = false;
    SmbServer.deviceProfileNow = androidDeviceProfile(DeviceCapabilities.fallback);
  });
  tearDownAll(() async {
    FfmpegPrograms.reset();
    SmbServer.deviceProfileNow = null;
    await SmbGateway.stop();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('smb_decode');
    decodeExit = File('${dir.path}/decode_exit')..writeAsStringSync('0');
    callLog = File('${dir.path}/calls');
    final probeJson = File('${dir.path}/probe.json')..writeAsStringSync(_probe);
    final ffprobe = File('${dir.path}/ffprobe')..writeAsStringSync('#!/bin/sh\ncat "${probeJson.path}"\n');
    // The decode check is the only ffmpeg run here (it writes to "null").
    final ffmpeg = File('${dir.path}/ffmpeg')
      ..writeAsStringSync('#!/bin/sh\necho "\$*" >> "${callLog.path}"\nexit \$(cat "${decodeExit.path}")\n');
    await Process.run('chmod', ['+x', ffprobe.path, ffmpeg.path]);
    FfmpegPrograms.reset(FfmpegPrograms(ffmpeg: ffmpeg.path, ffprobe: ffprobe.path));
  });
  tearDown(() => dir.delete(recursive: true));

  Future<(SmbServer, List<bool>)> start() async {
    final share = FakeShare({'Movies/Lossless (2012).mkv': 1000, 'Movies/Other (2013).mkv': 1000});
    final storage = await AppStorage.at(Directory('${dir.path}/p'), logosDir: Directory('${dir.path}/logos'));
    final ready = <bool>[];
    final profile = SmbProfile(storage,
        profileName: () => 'Mom',
        hold: ValueNotifier(false),
        onFilesReady: (_, {required last}) => ready.add(last),
        onChanged: () {},
        open: (address, who, {knownSmb1 = false, workers = 2}) async => share);
    profile.configOf('id1').mappings = const [SmbMapping('Movies', SmbFolderType.movies)];
    final ref = await profile.secrets.put(const SmbCredentials.guest());
    await SmbGateway.ensureStarted();
    final server = profile.client(ServerSession(
        kind: ServerKind.smb, serverUrl: 'smb://nas/media', serverName: 'media on nas', serverId: 'id1', userId: 'guest', userName: 'Guest', accessToken: ref, deviceId: 'd'));
    addTearDown(() async {
      server.close();
      await profile.settled();
    });
    await server.fetchLibraryIndex();
    for (var i = 0; i < 200 && !ready.contains(true); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return (server, ready);
  }

  test("sound that won't decode: damaged, listed, never scheduled", () async {
    decodeExit.writeAsStringSync('69');
    final (server, _) = await start();
    expect({for (final e in server.cantPlay.entries) e.key.title: e.value}, {'Lossless': CantPlayReason.damaged, 'Other': CantPlayReason.damaged});
    decodeCalls = callLog.readAsLinesSync();
    expect(decodeCalls, hasLength(2), reason: 'each file tried once');
    // The picture is copied, so only the sound is decoded.
    expect(decodeCalls.first, contains('-map 0:a:0?'));
    expect(decodeCalls.first, isNot(contains('-map 0:v:0')));
    server.rebuildNext();
    final index = await server.fetchLibraryIndex();
    expect(index.movies, isEmpty);
  });

  test('sound that decodes: scheduled, and the check is kept with the probe', () async {
    final (server, _) = await start();
    expect(server.cantPlay, isEmpty);
    server.rebuildNext();
    expect((await server.fetchLibraryIndex()).movies.map((m) => m.title).toSet(), {'Lossless', 'Other'});
    expect(callLog.readAsLinesSync(), hasLength(2));
    // Checked again only when asked.
    decodeExit.writeAsStringSync('69');
    server.rebuildNext();
    await server.fetchLibraryIndex();
    expect(callLog.readAsLinesSync(), hasLength(2));
    await server.checkAgain();
    expect(server.cantPlay, isEmpty, reason: 'only listed files are checked again');
  });
}
