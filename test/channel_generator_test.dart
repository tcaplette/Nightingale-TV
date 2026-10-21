import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'fixtures.dart';

void main() {
  List<Channel> generate(LibraryIndex library) => ChannelGenerator(library, anchor: DateTime(2026, 10, 20)).generate();
  List<String> music(List<Channel> channels) => [for (final c in channels) if (c.isMusic) c.name];

  group('music genres and decades', () {
    test('common spellings merge', () {
      expect(normalizeMusicGenre('Hip Hop'), 'Hip-Hop');
      expect(normalizeMusicGenre('Rap'), 'Hip-Hop');
      expect(normalizeMusicGenre('Hip Hop/Rap'), 'Hip-Hop');
      expect(normalizeMusicGenre('RnB'), 'R&B');
      expect(normalizeMusicGenre('R&B'), 'R&B');
      expect(normalizeMusicGenre('rock'), 'Rock');
      expect(normalizeMusicGenre('Synthwave'), 'Synthwave');
    });

    test('decades are named 50s to 90s, then 2000s', () {
      expect(decadeOf(1987), 1980);
      expect(decadeOf(1949), isNull);
      expect(decadeOf(2031), isNull);
      expect([for (final d in [1950, 1980, 1990, 2000, 2010, 2020]) decadeName(d)],
          ['50s', '80s', '90s', '2000s', '2010s', '2020s']);
    });
  });

  group('music channels', () {
    test('an 80s-heavy library: Music Radio, Rock Radio and 80s Radio, after the movies', () {
      final library = fakeLibrary(movies: 6, songs: [
        ...fakeMusic(300, prefix: 'rock80', year: 1984, genres: ['Rock']),
        ...fakeMusic(100, prefix: 'pop80', year: 1986, genres: ['Pop']),
        ...fakeMusic(500, prefix: 'pop90', year: 1995, genres: ['Pop']),
      ]);
      final channels = generate(library);
      expect(music(channels), ['Music Radio', 'Pop Radio', 'Rock Radio', '90s Radio', '80s Radio']);
      final movies = channels.indexWhere((c) => c.id == 'auto:movies');
      expect(channels.indexWhere((c) => c.isMusic), greaterThan(movies));
      final radio = channels.firstWhere((c) => c.name == '80s Radio');
      expect(radio.icon.value, 'radio');
      expect(radio.order, PlaybackOrder.random);
      expect(radio.commercialPlan, BreakPlan.off);
      expect(radio.source.decades, [1980]);
      expect(radio.playlist, hasLength(400));
      expect(channels.firstWhere((c) => c.name == 'Rock Radio').playlist, hasLength(300));
    });

    test('near-duplicates are skipped: a genre that is nearly the whole library', () {
      final library = fakeLibrary(songs: [
        ...fakeMusic(900, prefix: 'rock', genres: ['Rock']),
        ...fakeMusic(50, prefix: 'jazz', genres: ['Jazz'], year: 1962),
      ]);
      // Rock and the 80s are 95% of everything: only Music Radio.
      expect(music(generate(library)), ['Music Radio']);
    });

    test('music videos: Music Videos plus genre and decade channels of 40 or more', () {
      final library = fakeLibrary(musicVideos: [
        ...fakeMusic(35, prefix: 'mv-pop80', videos: true, genres: ['Pop'], year: 1984),
        ...fakeMusic(25, prefix: 'mv-pop90', videos: true, genres: ['Pop'], year: 1995),
        ...fakeMusic(25, prefix: 'mv-rap80', videos: true, genres: ['Rap'], year: 1988),
        ...fakeMusic(25, prefix: 'mv-rap90', videos: true, genres: ['Hip Hop'], year: 1999),
      ]);
      final channels = generate(library);
      expect(music(channels), ['Music Videos', 'Pop Music Videos', 'Hip-Hop Music Videos', '80s Music Videos', '90s Music Videos']);
      expect(channels.firstWhere((c) => c.name == 'Music Videos').icon.value, 'music_video');
    });

    test('a small collection: 10 music videos and 100 songs make the two all-music channels only', () {
      final library = fakeLibrary(
          musicVideos: fakeMusic(10, prefix: 'mv', videos: true, genres: ['Pop']), songs: fakeMusic(100));
      expect(music(generate(library)), ['Music Videos', 'Music Radio']);
      expect(music(generate(fakeLibrary(musicVideos: fakeMusic(1, prefix: 'mv', videos: true)))), ['Music Videos']);
      expect(music(generate(fakeLibrary())), isEmpty, reason: 'no music, no music channels');
    });

    test('a huge library: 3,000 songs, the same 3,000 every time', () {
      final songs = fakeMusic(8000, artists: 400);
      final first = generate(fakeLibrary(songs: songs)).firstWhere((c) => c.name == 'Music Radio');
      final again = generate(fakeLibrary(songs: songs)).firstWhere((c) => c.name == 'Music Radio');
      expect(first.playlist, hasLength(maxMusicPlaylist));
      expect(again.playlist, first.playlist);
      // Most of the sample survives a library that grows.
      final bigger = generate(fakeLibrary(songs: [...songs, ...fakeMusic(200, prefix: 'new')]))
          .firstWhere((c) => c.name == 'Music Radio');
      expect(bigger.playlist.toSet().intersection(first.playlist.toSet()).length, greaterThan(2800));
    });

    test('never the same artist twice in a row', () {
      for (final artists in [2, 3, 7, 40]) {
        final library = fakeLibrary(songs: fakeMusic(300, artists: artists));
        final ids = generate(library).firstWhere((c) => c.name == 'Music Radio').playlist;
        final names = [for (final id in ids) library[id]!.artist];
        for (var i = 1; i < names.length; i++) {
          expect(names[i], isNot(names[i - 1]), reason: '$artists artists, at $i');
        }
      }
    });

    test('a kid profile with unrated music gets no radio channels', () {
      final library = fakeLibrary(songs: fakeMusic(400)).restrictedTo(2);
      expect(music(generate(library)), isEmpty);
      expect(library.songs, isEmpty);
      final rated = fakeLibrary(songs: fakeMusic(400, rating: 'G')).restrictedTo(2);
      expect(music(generate(rated)), ['Music Radio']);
    });

    test('buildPlaylist honours songs, music videos and decades', () {
      final library = fakeLibrary(
        songs: [...fakeMusic(20, year: 1981), ...fakeMusic(20, prefix: 's90', year: 1992)],
        musicVideos: fakeMusic(10, prefix: 'mv', videos: true, year: 1983),
      );
      List<String> ids(ChannelSource s) => buildPlaylist(library, s, PlaybackOrder.random, seed: 1);
      expect(ids(const ChannelSource(includeEpisodes: false, includeSongs: true)), hasLength(40));
      expect(ids(const ChannelSource(includeEpisodes: false, includeMusicVideos: true)), hasLength(10));
      expect(ids(const ChannelSource(includeEpisodes: false, includeSongs: true, includeMusicVideos: true, decades: [1980])),
          hasLength(30));
      expect(ids(const ChannelSource()).any((id) => id.startsWith('song')), isFalse, reason: 'shows never get music');
    });
  });
}
