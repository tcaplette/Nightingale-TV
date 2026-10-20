import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/tune_timeline.dart';

/// mpv's log lines from two real opens (2026-10-19, Linux diagnostics
/// build), at their times since the tune, with the server's address
/// replaced. Lines the timeline ignores are kept in, as noise.
const _directMp4 = [
  (0, 'v demux: Detected file format: txt (Playlist file)'),
  (115, 'v ffmpeg: Opening https://jf.example/Videos/172c/stream?static=true&mediaSourceId=172c'),
  (1790, "v ffmpeg: Mime-type: 'video/mp4'"),
  (1790, 'v demux: Trying demuxers for level=normal.'),
  (1806, "v lavf: Found 'mov,mp4,m4a,3gp,3g2,mj2' at score=100 size=2048."),
  (1806, 'v ffmpeg: stream level seek from 3798 to 482764317'),
  (22013, "v lavf: Could not set AVOption seg_max_retry='5'"),
  (22013, 'v demux: Detected file format: mov,mp4,m4a,3gp,3g2,mj2 (libavformat)'),
  (22013, 'v cplayer: Opening done: https://jf.example/Videos/172c/stream?static=true&mediaSourceId=172c'),
  (22027, 'v cplayer: Starting playback...'),
  (22027, 'v lavf: execute seek (to 171.077000 flags 0)'),
  (22027, 'v ffmpeg: stream level seek from 483934071 to 61548581'),
  (23534, 'v af: [in] 48000Hz 5.1 6ch floatp'),
  (24582, 'v vd: Decoder format: 1920x1080 vaapi[p010] auto/auto/auto/limited/auto CL=mpeg2/4/h264'),
  (24668, 'v cplayer: first video frame after restart shown'),
  (25160, 'v cplayer: playback restart complete @ 167.292125, audio=playing, video=playing'),
];

const _transcodeTs = [
  (0, 'v demux: Detected file format: txt (Playlist file)'),
  (176, 'v ffmpeg: Opening https://jf.example/videos/172c/stream.ts?MediaSourceId=172c&VideoCodec=h264'),
  (5623, "v ffmpeg: Mime-type: 'video/mp2t'"),
  (5628, "v lavf: Found 'mpegts' at score=50 size=2048."),
  (6584, 'v lavf: avformat_find_stream_info() finished after 57144 bytes.'),
  (6584, 'v demux: Detected file format: mpegts (libavformat)'),
  (6586, 'v cplayer: Starting playback...'),
  (6589, 'info vd: Using hardware decoding (vaapi).'),
  (6800, 'v cplayer: first video frame after restart shown'),
];

TuneTimeline replay(String trigger, List<(int, String)> lines,
    {required int openAtMs, required int pictureAtMs, List<(String, int)> waits = const []}) {
  final t = TuneTimeline(trigger, 'ch=7', Duration.zero);
  for (final (name, ms) in waits) {
    t.waited(name, Duration(milliseconds: ms));
  }
  t.openCalled = Duration(milliseconds: openAtMs);
  for (final (ms, line) in lines) {
    t.mpvLine(line, Duration(milliseconds: openAtMs + ms));
  }
  t.finish('picture', Duration(milliseconds: pictureAtMs));
  return t;
}

void main() {
  group('direct play of an MP4 with its index at the end', () {
    final t = replay('launch', _directMp4, openAtMs: 0, pictureAtMs: 25345)..kind = 'direct';

    test('finds the index read as the slowest stage', () {
      expect(t.slowest!.$1, 'header+index-at-end');
      expect(t.slowest!.$2.inMilliseconds, closeTo(20223, 50));
      expect(t.problems, contains('index-at-end'));
    });

    test('measures the index: 1.17 MB between the jump to the end and the jump back', () {
      expect(t.indexAtEndBytes, 483934071 - 482764317);
      expect(t.indexAtEndTook!.inMilliseconds, closeTo(20221, 50));
      expect(t.summary(), contains('index-at-end=1.12 MB in 20.2s (0.46 Mbps)'));
    });

    test('times the stages in order and counts the range requests', () {
      final names = [for (final (n, _) in t.stages) n];
      expect(names, ['wait', 'player-setup', 'first-response', 'header+index-at-end', 'start', 'seek+decode', 'show', 'picture-moving']);
      expect(t.seeks, hasLength(2));
      expect(t.problems, containsAll(['slow-first-response', 'slow-header', 'reconnects=2']));
      expect(t.total, const Duration(milliseconds: 25345));
    });
  });

  group('a transcode', () {
    final t = replay('launch', _transcodeTs, openAtMs: 0, pictureAtMs: 6954)..kind = 'transcode@420kbps';

    test('the wait for the first response is the slowest stage', () {
      expect(t.slowest!.$1, 'first-response');
      expect(t.slowest!.$2.inMilliseconds, 5623 - 176);
      expect(t.problems, contains('slow-first-response'));
      expect(t.problems, isNot(contains('index-at-end')));
    });

    test('reports what the probe read', () {
      expect(t.probeBytes, 57144);
      expect(t.summary(), contains('probe=56 KB'));
    });
  });

  test("Matroska: mpv's own demuxer is recognized, and a small cues read at the end is no problem", () {
    final t = TuneTimeline('channel', 'ch=3', Duration.zero)..openCalled = Duration.zero;
    for (final (ms, line) in const [
      (100, 'v ffmpeg: Opening http://jf.example/Videos/x/stream?static=true'),
      (400, "v ffmpeg: Mime-type: 'video/x-matroska'"),
      (420, 'v demux: Detected file format: mkv (Matroska)'),
      (430, 'v ffmpeg: stream level seek from 4096 to 242495258'),
      (700, 'v ffmpeg: stream level seek from 242508570 to 953'),
      (720, 'v cplayer: Starting playback...'),
      (1300, 'v cplayer: first video frame after restart shown'),
    ]) {
      t.mpvLine(line, Duration(milliseconds: ms));
    }
    t.finish('picture', const Duration(milliseconds: 1500));
    expect(t.format, 'mkv (Matroska)');
    expect(t.problems, isNot(contains('index-at-end')));
    expect(t.problems, isNot(contains('slow-header')));
  });

  test('time the tuner waited before opening is its own stage and problem', () {
    final t = replay('channel', _transcodeTs,
        openAtMs: 2400, pictureAtMs: 9354, waits: [('stopped-report', 1900), ('playback-info', 500)]);
    expect(t.stages.first, ('wait', const Duration(milliseconds: 2400)));
    expect(t.problems, containsAll(['waited-for-stopped-report', 'waited-for-playback-info']));
  });

  test('other traffic during the open is counted', () {
    final t = TuneTimeline('launch', 'ch=7', Duration.zero)
      ..appRequest('GET /Users/u/Items', const Duration(seconds: 3), 2 << 20)
      ..analyzerBytes = 500000;
    t.finish('picture', const Duration(seconds: 4));
    expect(t.problems, containsAll(['app-http-during-open', 'app-download-during-open', 'analyzer-download-during-open']));
    // Nothing is added once it's over.
    t.appRequest('POST /Sessions/Playing', const Duration(milliseconds: 100), 0);
    expect(t.appRequests, hasLength(1));
  });
}
