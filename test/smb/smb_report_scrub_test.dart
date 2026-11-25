import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/reporting/report_scrubber.dart';
import 'package:nightingale_tv/server/server_log.dart';

void main() {
  final s = ReportScrubber(names: ['alice', 'Basement NAS', 'Family']);

  for (final (input, gone) in [
    (r'Failed to open \\NAS\media\Movies\Heat.mkv for alice', ['NAS', 'media', 'Movies', 'Heat', 'alice']),
    (r'Can not read \\192.168.1.5\Media Share\TV Shows\Show A (2001)\S01E01.mkv: access denied', ['192.168', 'Media Share', 'TV Shows', 'Show A', 'S01E01']),
    ('smb://nas.local:1445/media/Movies/Heat (1995)/Heat.mkv went away', ['nas.local', 'media', 'Movies', 'Heat']),
    ('Cannot connect to //nas.local:1445/media: Session setup failed', ['nas.local', 'media']),
    ('Stat failed for TV/Show A/Season 1/Show.A.S01E01.mkv', ['Show.A', 'S01E01']),
    ('ffmpeg: http://127.0.0.1:41234/0123456789abcdef0123456789abcdef01234567/t1/c/5f872b13c1ed9f13296d?ss=12: Invalid data', ['41234', '0123456789abcdef', '5f872b13c1ed9f13296d']),
    ('History name Family on Basement NAS', ['Family', 'Basement NAS']),
  ]) {
    test('scrubs: $input', () {
      final out = s.scrub(input);
      for (final g in gone) {
        expect(out, isNot(contains(g)), reason: out);
      }
    });
  }

  test('ordinary text stays', () {
    expect(s.scrub('Playback failed: decoder error at 12 s'), 'Playback failed: decoder error at 12 s');
  });

  test("the server log never shows a share's password", () {
    final lines = <String>[];
    ServerLog.output = lines.add;
    addTearDown(ServerLog.reset);
    ServerLog.secret('hunter2-pass');
    ServerLog.info('signing in with hunter2-pass');
    expect(lines.single, isNot(contains('hunter2-pass')));
  });
}
