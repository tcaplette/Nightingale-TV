import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/live/m3u_parser.dart';

void main() {
  test("the spec's typical entry", () {
    final p = parseM3u('#EXTM3U\n'
        '#EXTINF:-1 tvg-id="wxyz.us" tvg-logo="http://l/wxyz.png" tvg-chno="7" group-title="Locals",WXYZ 7\n'
        'http://s/7.ts|User-Agent=VLC\n');
    final c = p.channels.single;
    expect(c.name, 'WXYZ 7');
    expect(c.group, 'Locals');
    expect(c.guideId, 'wxyz.us');
    expect(c.key, 'wxyz.us');
    expect(c.logo, 'http://l/wxyz.png');
    expect(c.number, '7');
    expect(c.url, 'http://s/7.ts');
    expect(c.headers, {'User-Agent': 'VLC'});
  });

  test('a byte-order mark and CRLF line ends leave no stray characters', () {
    final p = parseM3u('﻿#EXTM3U\r\n#EXTINF:-1 tvg-name="One",One\r\nhttp://s/1.ts\r\n'
        '#EXTINF:-1,Two\r\nhttp://s/2.ts\r\n');
    expect([for (final c in p.channels) c.name], ['One', 'Two']);
    expect([for (final c in p.channels) c.url], ['http://s/1.ts', 'http://s/2.ts']);
  });

  test('the header names the guide, the first of several', () {
    final p = parseM3u('#EXTM3U x-tvg-url="http://e/epg.xml.gz,http://e/b.xml" url-tvg="http://e/c.xml"\n'
        '#EXTINF:-1,A\nhttp://s/a\n');
    expect(p.guideUrls, ['http://e/epg.xml.gz', 'http://e/b.xml', 'http://e/c.xml']);
    final q = parseM3u('#EXTM3U x-tvg-url="http://e/epg.xml.gz"\n#EXTINF:-1,A\nhttp://s/a\n');
    expect(q.guideUrls, ['http://e/epg.xml.gz']);
  });

  test('#EXTGRP is the group when group-title is missing', () {
    final p = parseM3u('#EXTM3U\n#EXTINF:-1,A\n#EXTGRP:News\nhttp://s/a\n'
        '#EXTINF:-1 group-title="Sports",B\n#EXTGRP:News\nhttp://s/b\n');
    expect([for (final c in p.channels) c.group], ['News', 'Sports']);
  });

  test('#EXTVLCOPT user agent and referrer, and Kodi headers', () {
    final p = parseM3u('#EXTM3U\n#EXTINF:-1,A\n#EXTVLCOPT:http-user-agent=TiviMate/4.7\n'
        '#EXTVLCOPT:http-referrer=http://r/\nhttp://s/a\n'
        '#EXTINF:-1,B\nhttp://s/b|User-Agent=Mozilla%2F5.0&Referer=http://r2/\n');
    expect(p.channels[0].headers, {'User-Agent': 'TiviMate/4.7', 'Referer': 'http://r/'});
    expect(p.channels[1].url, 'http://s/b');
    expect(p.channels[1].headers, {'User-Agent': 'Mozilla/5.0', 'Referer': 'http://r2/'});
    // Options don't carry over to the next entry.
    final q = parseM3u('#EXTM3U\n#EXTINF:-1,A\n#EXTVLCOPT:http-user-agent=X\nhttp://s/a\n#EXTINF:-1,B\nhttp://s/b\n');
    expect(q.channels[1].headers, isEmpty);
  });

  test('attribute names are case-insensitive, with aliases', () {
    final p = parseM3u('#EXTM3U\n#EXTINF:-1 TVG-ID="x.id" Group-Title="G" channel-number="12",X\nhttp://s/x\n'
        '#EXTINF:-1 channel-id="y.id",Y\nhttp://s/y\n');
    expect(p.channels[0].guideId, 'x.id');
    expect(p.channels[0].group, 'G');
    expect(p.channels[0].number, '12');
    expect(p.channels[1].guideId, 'y.id');
  });

  test('a comma inside a quoted attribute is not the name', () {
    final p = parseM3u('#EXTM3U\n#EXTINF:-1 group-title="News, Local",Channel A\nhttp://s/a\n');
    expect(p.channels.single.name, 'Channel A');
    expect(p.channels.single.group, 'News, Local');
  });

  test('radio and unsupported schemes are skipped; other schemes kept', () {
    final p = parseM3u('#EXTM3U\n#EXTINF:-1 radio="true",Radio\nhttp://s/r\n'
        '#EXTINF:-1,MMS\nmms://s/m\n#EXTINF:-1,File\nfile:///x.ts\n'
        '#EXTINF:-1,RTSP\nrtsp://s/1\n#EXTINF:-1,RTMP\nrtmp://s/2\n#EXTINF:-1,UDP\nudp://@239.0.0.1:1234\n'
        '#EXTINF:-1,TLS\nhttps://s/3.m3u8\n#UNKNOWN:thing\n');
    expect([for (final c in p.channels) c.name], ['RTSP', 'RTMP', 'UDP', 'TLS']);
  });

  test('keys: tvg-id, then tvg-name, then name, then URL, numbered when repeated', () {
    final p = parseM3u('#EXTM3U\n'
        '#EXTINF:-1 tvg-id="a.id" tvg-name="A",A\nhttp://s/1\n'
        '#EXTINF:-1 tvg-name="B name",B\nhttp://s/2\n'
        '#EXTINF:-1,C\nhttp://s/3\n'
        'http://s/4\n'
        '#EXTINF:-1 tvg-id="a.id",A HD\nhttp://s/5\n'
        '#EXTINF:-1 tvg-id="a.id",A 4K\nhttp://s/6\n');
    expect([for (final c in p.channels) c.key], ['a.id', 'B name', 'C', 'http://s/4', 'a.id#2', 'a.id#3']);
    expect(p.channels[3].name, 'http://s/4');
  });

  test('keys survive rotating stream URLs', () {
    final a = parseM3u('#EXTM3U\n#EXTINF:-1 tvg-id="x",X\nhttp://s/x?token=1\n');
    final b = parseM3u('#EXTM3U\n#EXTINF:-1 tvg-id="x",X\nhttp://s/x?token=2\n');
    expect(a.channels.single.key, b.channels.single.key);
  });

  test('an HTML page is not a playlist; a playlist without channels says so', () {
    expect(() => parseM3u('<!doctype html>\n<html><body>Login</body></html>\n'),
        throwsA(same(M3uException.notM3u)));
    expect(() => parseM3u('#EXTM3U\n'), throwsA(same(M3uException.empty)));
    expect(() => parseM3u('#EXTM3U\n#EXTINF:-1 radio="true",R\nhttp://s/r\n'), throwsA(same(M3uException.empty)));
  });

  test('an 8,000-entry playlist reads quickly in the background', () async {
    final b = StringBuffer('#EXTM3U x-tvg-url="http://e/g.xml.gz"\n');
    for (var i = 0; i < 8000; i++) {
      b
        ..write('#EXTINF:-1 tvg-id="c$i.id" tvg-name="Channel $i" tvg-logo="http://l/$i.png" ')
        ..write('group-title="${i % 2 == 0 ? 'US News' : 'Sports'}",Channel $i\n')
        ..write('http://provider/live/user/pass/$i.ts\n');
    }
    final watch = Stopwatch()..start();
    final p = await parseM3uInBackground(b.toString());
    expect(p.channels, hasLength(8000));
    expect(p.channels.where((c) => c.group == 'US News'), hasLength(4000));
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });
}
