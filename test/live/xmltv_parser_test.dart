import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/live/guide_match.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/xmltv_parser.dart';

GuideWant want(String key, {String? tvgId, String? tvgName, String? name}) =>
    (key: key, tvgId: tvgId, tvgName: tvgName, name: name ?? key);

Future<XmltvResult> read(String xml, List<GuideWant> wanted, {DateTime? now, bool gzipped = false}) {
  final bytes = utf8.encode(xml);
  return readXmltv(Stream.value(gzipped ? gzip.encode(bytes) : bytes), wanted,
      now: now ?? DateTime.utc(2026, 10, 21, 12));
}

const header = '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE tv SYSTEM "xmltv.dtd">\n<tv>\n';

void main() {
  test("the spec's programme with episode numbers", () async {
    final r = await read(
        '$header<channel id="wxyz.us"><display-name>WXYZ</display-name><icon src="http://l/w.png"/></channel>\n'
        '<programme start="20261021200000 -0400" stop="20261021203000 -0400" channel="wxyz.us">'
        '<title lang="en">The News</title><episode-num system="xmltv_ns">2.4.</episode-num><new/></programme>\n</tv>',
        [want('wxyz', tvgId: 'wxyz.us')]);
    final p = r.programmes['wxyz']!.single;
    expect(p.title, 'The News');
    expect(p.start.toUtc(), DateTime.utc(2026, 10, 22, 0));
    expect(p.end.toUtc(), DateTime.utc(2026, 10, 22, 0, 30));
    expect((p.season, p.episode), (3, 5));
    expect(p.isNew, isTrue);
    expect(r.channels.single.icon, 'http://l/w.png');
    expect(r.matches, {'wxyz': 'wxyz.us'});
  });

  test('times: seconds and offset optional, no offset is UTC', () {
    expect(parseXmltvTime('202610212000')!.toUtc(), DateTime.utc(2026, 10, 21, 20));
    expect(parseXmltvTime('20261021200000')!.toUtc(), DateTime.utc(2026, 10, 21, 20));
    expect(parseXmltvTime('20261021200000 +0130')!.toUtc(), DateTime.utc(2026, 10, 21, 18, 30));
    expect(parseXmltvTime('20261021200000-0500')!.toUtc(), DateTime.utc(2026, 10, 22, 1));
    expect(parseXmltvTime('soon'), isNull);
  });

  test('episode numbers in both systems', () {
    expect(parseEpisodeNum('xmltv_ns', '0.0.'), (season: 1, episode: 1));
    expect(parseEpisodeNum('xmltv_ns', '2/5.9/10.0/1'), (season: 3, episode: 10));
    expect(parseEpisodeNum('xmltv_ns', '.3.'), (season: null, episode: 4));
    expect(parseEpisodeNum('onscreen', 'S1E2'), (season: 1, episode: 2));
    expect(parseEpisodeNum('onscreen', 'S01 E12'), (season: 1, episode: 12));
    expect(parseEpisodeNum('onscreen', '4x07'), (season: 4, episode: 7));
  });

  test('a gzip guide with a plain name is read by its content', () async {
    final r = await read(
        '$header<programme start="20261021130000" stop="20261021140000" channel="a"><title>A1</title></programme></tv>',
        [want('a', tvgId: 'a')],
        gzipped: true);
    expect(r.programmes['a']!.single.title, 'A1');
  });

  test('only wanted channels are kept; past and far programmes dropped', () async {
    final r = await read(
        '$header<channel id="a"/><channel id="b"/>'
        '<programme start="20261021100000" stop="20261021110000" channel="a"><title>Past</title></programme>'
        '<programme start="20261021113000" stop="20261021123000" channel="a"><title>Now</title></programme>'
        '<programme start="20261024000000" stop="20261024010000" channel="a"><title>Far</title></programme>'
        '<programme start="20261021120000" stop="20261021130000" channel="b"><title>B</title></programme></tv>',
        [want('a', tvgId: 'a')]);
    expect(r.programmes.keys, ['a']);
    expect([for (final p in r.programmes['a']!) p.title], ['Now']);
    expect([for (final c in r.channels) c.id], ['a', 'b']);
  });

  test('a programme without stop ends at the next start; overlaps cut so the later wins', () async {
    final r = await read(
        '$header<programme start="20261021120000" channel="a"><title>One</title></programme>'
        '<programme start="20261021123000" stop="20261021133000" channel="a"><title>Two</title></programme>'
        '<programme start="20261021130000" stop="20261021140000" channel="a"><title>Three</title></programme>'
        '<programme start="20261021150000" channel="a"><title>Last, no stop</title></programme></tv>',
        [want('a', tvgId: 'a')]);
    final ps = r.programmes['a']!;
    expect([for (final p in ps) p.title], ['One', 'Two', 'Three']);
    expect(ps[0].end.toUtc(), DateTime.utc(2026, 10, 21, 12, 30));
    expect(ps[1].end.toUtc(), DateTime.utc(2026, 10, 21, 13));
  });

  test('the first language wins; details are read', () async {
    final r = await read(
        '$header<programme start="20261021120000" stop="20261021140000" channel="m">'
        '<title lang="fr">Le Film</title><title lang="en">The Film</title>'
        '<sub-title lang="fr">Partie</sub-title><desc lang="fr">Un film.</desc><desc lang="en">A film.</desc>'
        '<category lang="fr">Film</category><category lang="en">Movie</category><category lang="fr">Drame</category>'
        '<date>1999-04-01</date><rating system="MPAA"><value>PG-13</value></rating>'
        '<icon src="http://i/p.jpg"/><previously-shown/></programme>'
        '<programme start="20261021140000" stop="20261021143000" channel="m"><title>Ep</title>'
        '<episode-num system="onscreen">S2E3</episode-num><premiere/></programme></tv>',
        [want('m', tvgId: 'm')]);
    final [film, ep] = r.programmes['m']!;
    expect(film.title, 'Le Film');
    expect(film.subtitle, 'Partie');
    expect(film.description, 'Un film.');
    expect(film.categories, ['Film', 'Drame']);
    expect(film.year, 1999);
    expect(film.rating, 'PG-13');
    expect(film.icon, 'http://i/p.jpg');
    expect(film.isMovie, isTrue);
    expect(film.isNew, isFalse);
    expect((ep.season, ep.episode, ep.isNew, ep.isMovie), (2, 3, true, false));
  });

  test("guide matching: tvg-id, then the normalized name (the spec's WXYZ-7)", () async {
    final r = await read(
        '$header<channel id="w7"><display-name>wxyz 7</display-name></channel>'
        '<channel id="k"><display-name>KABC</display-name><display-name>7.1</display-name></channel>'
        '<programme start="20261021120000" stop="20261021130000" channel="w7"><title>W</title></programme>'
        '<programme start="20261021120000" stop="20261021130000" channel="k"><title>K</title></programme></tv>',
        [
          want('wxyz', name: 'WXYZ-7'),
          want('kabc', tvgId: 'nope', tvgName: 'K.A.B.C.', name: 'Channel 7'),
          want('none', tvgId: 'missing', name: 'Nothing'),
        ]);
    expect(r.matches, {'wxyz': 'w7', 'kabc': 'k'});
    expect(r.programmes['wxyz']!.single.title, 'W');
    expect(r.programmes['kabc']!.single.title, 'K');
    expect(r.programmes.containsKey('none'), isFalse);

    final m = GuideMatcher(r.channels);
    expect(m.match(tvgId: 'w7', name: 'anything'), 'w7');
    expect(m.match(name: 'WXYZ-7'), 'w7');
    expect(m.match(name: 'Wxyz_7!'), 'w7');
    expect(m.match(name: 'WXYZ 8'), isNull);
    expect(normalizeChannelName('WXYZ-7'), normalizeChannelName('wxyz 7'));
  });

  test('not a guide, and a guide over the size cap', () async {
    expect(read('<html><body>no</body></html>', []), throwsA(same(XmltvException.notXmltv)));
    expect(read('plain text', []), throwsA(same(XmltvException.notXmltv)));
    final big = '$header${'<channel id="x"><display-name>${'x' * 1000}</display-name></channel>' * 100}</tv>';
    expect(
        readXmltv(Stream.value(utf8.encode(big)), [], now: DateTime.utc(2026), maxBytes: 50000),
        throwsA(same(XmltvException.tooBig)));
  });

  test('a cut-off guide keeps what was read', () async {
    final r = await read(
        '$header<programme start="20261021120000" stop="20261021130000" channel="a"><title>A</title></programme>'
        '<programme start="20261021130000" stop="20261021140000" channel="a"><title>B</tit',
        [want('a', tvgId: 'a')]);
    expect([for (final p in r.programmes['a']!) p.title], ['A']);
  });

  test('a 150 MB guide for 2,000 channels reads in the background with flat memory', () async {
    final dir = await Directory.systemTemp.createTemp('xmltv_big');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/guide.xml');
    final sink = file.openWrite();
    sink.write(header);
    for (var c = 0; c < 2000; c++) {
      sink.write('<channel id="c$c.id"><display-name>Channel $c</display-name>'
          '<icon src="http://logos.example/c$c.png"/></channel>\n');
    }
    final start = DateTime.utc(2026, 10, 21);
    String t(DateTime d) =>
        '${d.year}${'${d.month}'.padLeft(2, '0')}${'${d.day}'.padLeft(2, '0')}'
        '${'${d.hour}'.padLeft(2, '0')}${'${d.minute}'.padLeft(2, '0')}00 +0000';
    final desc = 'A long description of this programme that goes on for a while. ' * 3;
    for (var c = 0; c < 2000; c++) {
      final b = StringBuffer();
      for (var i = 0; i < 168; i++) {
        final s = start.add(Duration(minutes: 30 * i)), e = s.add(const Duration(minutes: 30));
        b.write('<programme start="${t(s)}" stop="${t(e)}" channel="c$c.id"><title lang="en">Show $i</title>'
            '<sub-title lang="en">Episode $i</sub-title><desc lang="en">$desc</desc><category lang="en">News</category>'
            '<episode-num system="xmltv_ns">0.$i.</episode-num></programme>\n');
      }
      sink.write(b);
    }
    sink.write('</tv>\n');
    await sink.close();
    final size = await file.length();
    expect(size, greaterThan(140 << 20));

    final wanted = [for (var c = 0; c < 2000; c += 100) want('k$c', tvgId: 'c$c.id')];
    final rssBefore = ProcessInfo.currentRss;
    var rssPeak = rssBefore;
    final sampler = Stream.periodic(const Duration(milliseconds: 20)).listen((_) {
      if (ProcessInfo.currentRss > rssPeak) rssPeak = ProcessInfo.currentRss;
    });
    final watch = Stopwatch()..start();
    final r = await parseXmltvFile(file.path, wanted, now: start.add(const Duration(hours: 6)));
    final took = watch.elapsed;
    await sampler.cancel();
    final grew = rssPeak - rssBefore;
    // ignore: avoid_print
    print('150 MB guide: ${(size / (1 << 20)).toStringAsFixed(0)} MB in ${took.inMilliseconds} ms, '
        'peak memory +${grew >> 20} MB');
    expect(r.channels, hasLength(2000));
    expect(r.programmes, hasLength(20));
    // 48 hours from 06:00 of half-hour programmes, the one on now included.
    expect(r.programmes['k0'], hasLength(96));
    expect(grew, lessThan(200 << 20));
    expect(took, lessThan(const Duration(seconds: 90)));
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('programmes survive the cache round trip', () {
    final p = LiveProgramme(
        start: DateTime.utc(2026, 10, 21, 20).toLocal(),
        end: DateTime.utc(2026, 10, 21, 21).toLocal(),
        title: 'T',
        subtitle: 'S',
        season: 1,
        episode: 2,
        isNew: true,
        categories: const ['News']);
    final q = LiveProgramme.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>);
    expect((q.start, q.end, q.title, q.subtitle, q.season, q.episode, q.isNew),
        (p.start, p.end, p.title, p.subtitle, p.season, p.episode, p.isNew));
    expect(q.categories, p.categories);
  });
}
