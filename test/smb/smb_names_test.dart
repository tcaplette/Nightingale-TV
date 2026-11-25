import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/server/smb/smb_names.dart';
import 'package:nightingale_tv/server/smb/smb_nfo.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

void main() {
  // path under the mapped folder TV → show, year, season, episode, title
  final episodes = <(String, String, int?, int?, int?, String)>[
    ('Show A (2001)/Season 2/Show A S02E03.mkv', 'Show A', 2001, 2, 3, 'Episode 3'),
    ('Show A (2001)/Season 2/Show A S02E04E05.mkv', 'Show A', 2001, 2, 4, 'Episode 4 / Episode 5'),
    ('Show A (2001)/Season 2/Show A - S02E04-E05 - Two of Them.mkv', 'Show A', 2001, 2, 4, 'Two of Them'),
    ('Show A (2001)/Season 2/Show A S02E04-05.mkv', 'Show A', 2001, 2, 4, 'Episode 4 / Episode 5'),
    ('Show A (2001)/Season 02/show.a.s02e06.720p.web.h264-grp.mkv', 'Show A', 2001, 2, 6, 'Episode 6'),
    ('Show A/show.a.s02e06.The.Long.Title.1080p.WEB-DL.AAC2.0.H.264.mkv', 'Show A', null, 2, 6, 'The Long Title'),
    ('Show A/Show.A.S01E01-2160p.mkv', 'Show A', null, 1, 1, 'Episode 1'),
    ('Show B/Show B - 1x02 - The Second.mkv', 'Show B', null, 1, 2, 'The Second'),
    ('Show B/Show B 10x110.mkv', 'Show B', null, 10, 110, 'Episode 110'),
    ('Show B/Show B 1920x1080 clip.mkv', 'Show B', null, null, null, '1920x1080 clip'),
    ('Daily Show [tvdbid-71256]/Daily Show - 2024-05-01 - Monday Guest.mkv', 'Daily Show', null, 2024, 501, 'Monday Guest'),
    ('Daily Show [tvdbid-71256]/Daily.Show.2024.05.02.mkv', 'Daily Show', null, 2024, 502, '2024-05-02'),
    ('Flat Show S01E01.mkv', 'Flat Show', null, 1, 1, 'Episode 1'),
    ('flat.show.s01e02.hdtv.x264.mkv', 'flat show', null, 1, 2, 'Episode 2'),
    ('Show C/Season 1/E01 - Pilot.mkv', 'Show C', null, 1, 1, 'Pilot'),
    ('Show C/Season 1/02.mkv', 'Show C', null, 1, 2, 'Episode 2'),
    ('Show C/Season 1/03 - A Third.mkv', 'Show C', null, 1, 3, 'A Third'),
    ('Show C/Season 3/Episode 12.mkv', 'Show C', null, 3, 12, 'Episode 12'),
    ('Show C/S04/Ep 7 Seven.mkv', 'Show C', null, 4, 7, 'Seven'),
    ('Show C/Specials/Show C S00E01 Extra Long.mkv', 'Show C', null, 0, 1, 'Extra Long'),
    ('Show C/Season 1 Episode 5.mkv', 'Show C', null, 1, 5, 'Episode 5'),
    ('Show C/Season 1/Disc 2/Show C S01E09.mkv', 'Show C', null, 1, 9, 'Episode 9'),
    ('Anime/Show D (1999) {tvdb-42}/Season 1/Show D S01E01.mkv', 'Show D', 1999, 1, 1, 'Episode 1'),
    ('Show E/A Special Without Numbers.mkv', 'Show E', null, null, null, 'A Special Without Numbers'),
    ('Staffel Show/Staffel 2/Staffel Show S02E01.mkv', 'Staffel Show', null, 2, 1, 'Episode 1'),
    ('Mr. Show/Mr. Show S01E01.mkv', 'Mr. Show', null, 1, 1, 'Episode 1'),
    ('Show 24/Season 1/Show 24 S01E24.mkv', 'Show 24', null, 1, 24, 'Episode 24'),
  ];
  for (final (path, show, year, season, number, title) in episodes) {
    test('episode: $path', () {
      final parts = path.split('/');
      final e = SmbNames.episode(parts.last, parts.sublist(0, parts.length - 1), root: 'TV');
      expect((e.show, e.showYear, e.season, e.episode, e.title), (show, year, season, number, title));
    });
  }

  test('a mapped folder that is a show itself', () {
    final e = SmbNames.episode('E03.mkv', ['Season 2'], root: 'The Show (1990)');
    expect((e.show, e.showYear, e.season, e.episode), ('The Show', 1990, 2, 3));
  });

  test('ids of a show', () {
    expect(SmbNames.episode('a S01E01.mkv', ['Daily Show [tvdbid-71256]'], root: 'TV').ids, ['tvdb:71256']);
    expect(SmbNames.idsIn('Heat (1995) {tmdb-949} {imdb-tt0113277}'), ['tmdb:949', 'imdb:tt0113277']);
  });

  // path under the mapped folder Movies, alone in its folder → title, year
  final movies = <(String, bool, String, int?)>[
    ('Heat (1995) {tmdb-949}/Heat.mkv', true, 'Heat', 1995),
    ('Alien.1979.1080p.BluRay.x264-GRP.mkv', false, 'Alien', 1979),
    ('1917.2019.2160p.WEB-DL.mkv', false, '1917', 2019),
    ('Blade.Runner.2049.2017.1080p.mkv', false, 'Blade Runner 2049', 2017),
    ('Wonder Woman 1984.mkv', false, 'Wonder Woman 1984', null),
    ('Wonder Woman 1984 (2020).mkv', false, 'Wonder Woman 1984', 2020),
    ('2001 A Space Odyssey (1968).mkv', false, '2001 A Space Odyssey', 1968),
    ('Yearless Movie.mkv', false, 'Yearless Movie', null),
    ('Action/Some Film (2001).mkv', false, 'Some Film', 2001),
    ('Action/Lonely.mkv', true, 'Lonely', null),
    ('The Great Film/movie.mkv', true, 'The Great Film', null),
    ('The Great Film (1960)/video.avi', true, 'The Great Film', 1960),
    ('The Web (1947).mkv', false, 'The Web', 1947),
    ('Some Movie (1999)/Some Movie (1999) CD1.avi', false, 'Some Movie', 1999),
    ('Mr. Smith Goes to Washington (1939).mp4', false, 'Mr. Smith Goes to Washington', 1939),
    ('Movie_With_Underscores_(2003).mkv', false, 'Movie With Underscores', 2003),
    ('Spider-Man (2002) [1080p].mkv', false, 'Spider-Man', 2002),
    ('300 (2006).mkv', false, '300', 2006),
    ('DivX Movie (2002).avi', false, 'DivX Movie', 2002),
    ('Lossless TrueHD (2012).mkv', false, 'Lossless TrueHD', 2012),
    ('HDTV Story.mkv', false, 'HDTV Story', null),
  ];
  for (final (path, alone, title, year) in movies) {
    test('movie: $path', () {
      final parts = path.split('/');
      final m = SmbNames.movie(parts.last, parts.sublist(0, parts.length - 1), alone: alone);
      expect((m.title, m.year), (title, year));
    });
  }

  test('what is skipped', () {
    for (final f in const ['@eaDir', '#recycle', r'$RECYCLE.BIN', '.nightingale', 'System Volume Information', '.hidden', 'VIDEO_TS']) {
      expect(SmbNames.skipsFolder(f), isTrue, reason: f);
    }
    expect(SmbNames.skipsFolder('Trailers', extras: true), isTrue);
    expect(SmbNames.skipsFolder('Trailers'), isFalse, reason: 'a commercials folder may be named so');
    expect(SmbNames.skipsFolder('Season 1', extras: true), isFalse);
    expect(SmbNames.skipsFolder('Kept', hidden: true), isTrue);
    for (final v in const ['sample.mkv', 'show.s01e01.sample.mkv', 'Movie-trailer.mp4', '._Movie.mkv']) {
      expect(SmbNames.skipsVideo(v), isTrue, reason: v);
    }
    for (final v in const ['Free Samples (2012).mkv', 'Trailer Park.mkv']) {
      expect(SmbNames.skipsVideo(v), isFalse, reason: v);
    }
  });

  test('songs', () {
    final s = SmbNames.song('03 - Third Song.mp3', ['The Band', 'First Album (1978)']);
    expect((s.artist, s.album, s.year, s.title), ('The Band', 'First Album', 1978, 'Third Song'));
    expect(SmbNames.song('Loose.mp3', const []).title, 'Loose');
  });

  test('subtitle files', () {
    final forced = SmbNames.subtitle('Movie.en.forced.srt', 'Movie.mkv')!;
    expect((forced.language, forced.forced, forced.isDefault, forced.codec), ('eng', true, false, 'subrip'));
    expect(SmbNames.subtitle('Movie.es.default.srt', 'Movie.mkv')!.isDefault, isTrue);
    expect(SmbNames.subtitle('Movie.pt-BR.ass', 'Movie.mkv')!.tag, 'pt-BR');
    expect(SmbNames.subtitle('Movie.srt', 'Movie.mkv')!.language, isNull);
    expect(SmbNames.subtitle('Movie.eng.Commentary.srt', 'Movie.mkv')!.title, 'Commentary');
    expect(SmbNames.subtitle('Movie 2.en.srt', 'Movie.mkv'), isNull);
    expect(SmbNames.subtitle('Movie.en.sub', 'Movie.mkv'), isNull);
  });

  test('addresses', () {
    String? at(String s) => SmbAddress.parse(s)?.url;
    expect(at('smb://nas.local/media'), 'smb://nas.local/media');
    expect(at('smb://nas.local:1445/media/sub/folder'), 'smb://nas.local:1445/media');
    expect(at(r'\\NAS\My Media'), 'smb://NAS/My Media');
    expect(at('smb://user@nas/media'), 'smb://nas/media');
    expect(at('SMB://nas/My%20Media'), 'smb://nas/My Media');
    expect(at('nas'), 'smb://nas');
    expect(at('192.168.1.5/media'), 'smb://192.168.1.5/media');
    expect(at('smb://[fe80::1]:1445/x'), 'smb://[fe80::1]:1445/x');
    expect(at(''), isNull);
    expect(at('smb://'), isNull);
    expect(at('smb://nas:99999/x'), isNull);
    expect(SmbAddress.parse('smb://NAS/Media'), SmbAddress.parse('smb://nas/media'));
    expect(SmbAddress.looksLike(r'\\nas\x'), isTrue);
    expect(SmbAddress.looksLike('https://nas'), isFalse);
  });

  group('.nfo', () {
    SmbNfo? read(String s) => SmbNfo.parse(utf8.encode(s));

    test('a movie', () {
      final n = read('''<?xml version="1.0"?><movie><title>A &amp; B</title><year>1988</year><plot>Words.</plot>
<genre>Comedy / Family</genre><mpaa>Rated PG-13 for language</mpaa><runtime>97 min</runtime>
<uniqueid type="imdb" default="true">tt0088763</uniqueid><uniqueid type="tmdb">105</uniqueid></movie>
https://www.themoviedb.org/movie/105''')!;
      expect((n.title, n.year, n.plot, n.rating, n.runtime), ('A & B', 1988, 'Words.', 'PG-13', const Duration(minutes: 97)));
      expect(n.genres, ['Comedy', 'Family']);
      expect(n.ids, ['imdb:tt0088763', 'tmdb:105']);
      expect(ratingRank(n.rating), 4);
    });

    test('two episodes in one file', () {
      final n = read('<episodedetails><title>One</title><season>1</season><episode>1</episode></episodedetails>\n'
          '<episodedetails><title>Two</title><season>1</season><episode>2</episode></episodedetails>')!;
      expect((n.title, n.season, n.episode, n.lastEpisode), ('One / Two', 1, 1, 2));
    });

    test('ratings', () {
      expect(SmbNfo.cleanRating('US:TV-14 / GB:15'), 'TV-14');
      expect(SmbNfo.cleanRating('GB:15'), '15');
      expect(SmbNfo.cleanRating('TV-PG'), 'TV-PG');
      expect(SmbNfo.cleanRating('Rated R'), 'R');
    });

    test('broken files say nothing', () {
      expect(read('<movie><title>Never closed'), isNull);
      expect(read('<movie><title>Bad</ttle></movie>'), isNull);
      expect(read('just a link: https://example.org'), isNull);
      expect(read(''), isNull);
      expect(SmbNfo.parse([0xFF, 0xD8, 0x00, 0x01]), isNull);
      expect(read('<movie></movie>')!.title, isNull);
    });

    test('older ids, and UTF-16', () {
      expect(read('<movie><id>tt123</id></movie>')!.ids, ['imdb:tt123']);
      const s = '<movie><title>Ünïcode</title></movie>';
      expect(SmbNfo.parse([0xFF, 0xFE, for (final c in s.codeUnits) ...[c & 0xFF, c >> 8]])!.title, 'Ünïcode');
    });
  });
}
