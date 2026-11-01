import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/channels/premieres.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/profiles/profile.dart';

Map<String, Object?> _audio(String id,
        {String? rating, List<String> artists = const ['Queen'], String? albumArtist, int year = 1980}) =>
    {
      'Id': id,
      'Name': 'Song $id',
      'Type': 'Audio',
      'RunTimeTicks': const Duration(minutes: 3, seconds: 30).inMicroseconds * 10,
      'ProductionYear': year,
      'Genres': ['Rock'],
      'Artists': artists,
      'AlbumArtist': ?albumArtist,
      'Album': 'The Game',
      'AlbumId': 'album-1',
      'OfficialRating': ?rating,
      'Etag': 'etag-$id',
      'Container': 'flac',
      'MediaSources': [
        {'Size': 31000000}
      ],
      'LocationType': 'FileSystem',
    };

LibraryIndex _episodes(Map<String, String?> added) => LibraryIndex.fromJellyfinItems(
      seriesItems: [
        {'Id': 's1', 'Name': 'Show', 'ProductionYear': 2020}
      ],
      episodeItems: [
        for (final (i, e) in added.entries.indexed)
          {
            'Id': e.key,
            'Name': 'Episode ${i + 1}',
            'SeriesId': 's1',
            'SeriesName': 'Show',
            'ParentIndexNumber': 1,
            'IndexNumber': i + 1,
            'RunTimeTicks': const Duration(minutes: 22).inMicroseconds * 10,
            'LocationType': 'FileSystem',
            'DateCreated': ?e.value,
          }
      ],
      movieItems: const [],
      fetchedAt: DateTime(2026),
    );

void main() {
  group('music in the library', () {
    test('Audio items become songs with artist, album and file details', () {
      final index = LibraryIndex.fromJellyfinItems(
        seriesItems: const [],
        episodeItems: const [],
        movieItems: const [],
        songItems: [
          _audio('a1'),
          _audio('a2', artists: const [], albumArtist: 'Various'),
        ],
      );
      expect(index.songs, hasLength(2));
      final song = index['a1']!;
      expect(song.kind, MediaKind.song);
      expect(song.isMusic, isTrue);
      expect(song.title, 'Song a1');
      expect(song.artist, 'Queen');
      expect(song.album, 'The Game');
      expect(song.albumId, 'album-1');
      expect(song.year, 1980);
      expect(song.genres, ['Rock']);
      expect(song.container, 'flac');
      expect(song.size, 31000000);
      expect(song.runtime, const Duration(minutes: 3, seconds: 30));
      expect(song.guideTitle, 'Queen – Song a1');
      expect(song.subtitle, 'The Game · 1980');
      expect(index['a2']!.artist, 'Various', reason: 'falls back to the album artist');
      expect(index.isEmpty, isFalse, reason: 'music counts');
    });

    test('MusicVideo items become music videos; pool contents stay commercials', () {
      final index = LibraryIndex.fromJellyfinItems(
        seriesItems: const [],
        episodeItems: const [],
        movieItems: const [],
        musicVideoItems: [
          {..._audio('mv1'), 'Type': 'MusicVideo', 'Album': null},
          {..._audio('mv2'), 'Type': 'MusicVideo'},
        ],
        commercialItems: [
          {..._audio('mv2'), 'Type': 'MusicVideo'},
        ],
        poolsByItem: const {
          'mv2': ['pool-1']
        },
      );
      expect(index.musicVideos.map((m) => m.id), ['mv1']);
      expect(index['mv1']!.kind, MediaKind.musicVideo);
      expect(index['mv1']!.subtitle, 'Music video · 1980');
      expect(index['mv2']!.kind, MediaKind.commercial);
    });

    test('untagged music videos: the artist and a clean title from "Artist - Title [id]"', () {
      final index = LibraryIndex.fromJellyfinItems(
        seriesItems: const [],
        episodeItems: const [],
        movieItems: const [],
        musicVideoItems: [
          {
            ..._audio('mv1', artists: const []),
            'Type': 'MusicVideo',
            'Name': 'The Chemical Brothers - Let Forever Be (Official Music Video) ft. Noel Gallagher [s5FyfQDO5g0]',
          },
          {..._audio('mv2', artists: const []), 'Type': 'MusicVideo', 'Name': 'Untitled clip'},
          {..._audio('mv3'), 'Type': 'MusicVideo', 'Name': 'Bohemian - Rhapsody'},
        ],
      );
      expect((index['mv1']!.artist, index['mv1']!.title), ('The Chemical Brothers', 'Let Forever Be ft. Noel Gallagher'));
      expect((index['mv2']!.artist, index['mv2']!.title), (null, 'Untitled clip'));
      expect((index['mv3']!.artist, index['mv3']!.title), ('Queen', 'Bohemian - Rhapsody'), reason: 'tags win');
      expect(LibraryIndex.splitMusicName('Red Hot Chili Peppers - Scar Tissue [Official Music Video] [HD UPGRADE] [mzJj5-lubeM]'),
          (artist: 'Red Hot Chili Peppers', title: 'Scar Tissue'));
      expect(LibraryIndex.splitMusicName("Silverchair - Ana's Song (Open Fire) (Official Video) [zNK_r2QAXAo]"),
          (artist: 'Silverchair', title: "Ana's Song (Open Fire)"));
    });

    test('kid profiles keep only music rated within their limit', () {
      final index = LibraryIndex.fromJellyfinItems(
        seriesItems: const [],
        episodeItems: const [],
        movieItems: const [],
        songItems: [_audio('unrated'), _audio('g', rating: 'G'), _audio('r', rating: 'R')],
        musicVideoItems: [
          {..._audio('mv-unrated'), 'Type': 'MusicVideo'},
          {..._audio('mv-pg', rating: 'PG'), 'Type': 'MusicVideo'},
        ],
      );
      final kid = index.restrictedTo(2);
      expect(kid.songs.map((s) => s.id), ['g']);
      expect(kid.musicVideos, isEmpty);
      expect(index.restrictedTo(3).musicVideos.map((s) => s.id), ['mv-pg']);
    });

    test('songs, music videos and the new fields round-trip through JSON', () {
      final index = LibraryIndex.fromJellyfinItems(
        seriesItems: const [],
        episodeItems: const [],
        movieItems: const [],
        songItems: [_audio('a1')],
        musicVideoItems: [
          {..._audio('mv1'), 'Type': 'MusicVideo'}
        ],
      );
      final copy = LibraryIndex.fromJson(index.toJson());
      expect(copy.songs.single.artist, 'Queen');
      expect(copy.songs.single.album, 'The Game');
      expect(copy.songs.single.albumId, 'album-1');
      expect(copy.musicVideos.single.kind, MediaKind.musicVideo);
      expect(copy['a1'], isNotNull);

      final entry = MediaEntry(
        id: 'e1',
        kind: MediaKind.episode,
        title: 'Pilot',
        runtime: const Duration(minutes: 22),
        added: DateTime(2026, 10, 13, 3),
        availableAt: DateTime(2026, 10, 13, 9),
      );
      final back = MediaEntry.fromJson(entry.toJson());
      expect(back.added, DateTime(2026, 10, 13, 3));
      expect(back.availableAt, DateTime(2026, 10, 13, 9));
    });

    test('a library.json from before music loads with no songs or music videos', () {
      final old = {
        'fetchedAt': '2026-10-01T12:00:00.000',
        'series': const [],
        'episodes': [
          {'id': 'e1', 'kind': 'episode', 'title': 'Pilot', 'runtimeMs': 1320000, 'seriesKey': 'show|'}
        ],
        'movies': const [],
      };
      final index = LibraryIndex.fromJson(old);
      expect(index.songs, isEmpty);
      expect(index.musicVideos, isEmpty);
      final e = index['e1']!;
      expect(e.added, isNull);
      expect(e.availableAt, isNull);
      expect(e.artist, isNull);
    });
  });

  group('availableAt', () {
    final tuesday3am = DateTime(2026, 10, 13, 3);
    final tuesday9am = DateTime(2026, 10, 13, 9);

    test('reads DateCreated as added', () {
      final index = _episodes({'e1': '2026-10-13T03:00:00.0000000Z'});
      expect(index['e1']!.added, DateTime.utc(2026, 10, 13, 3).toLocal());
    });

    test("a profile's first scan: when Jellyfin added it", () {
      final index = _episodes({'e1': tuesday3am.toUtc().toIso8601String()}).withAvailability(null, tuesday9am);
      expect(index['e1']!.availableAt, tuesday3am);
    });

    test('a later scan: known episodes keep theirs, new ones get the later of added and the scan', () {
      final first = _episodes({'e1': tuesday3am.toUtc().toIso8601String()}).withAvailability(null, tuesday3am);
      final later = _episodes({
        'e1': tuesday3am.toUtc().toIso8601String(),
        'e2': tuesday3am.toUtc().toIso8601String(),
        'e3': DateTime(2026, 10, 13, 10).toUtc().toIso8601String(),
      }).withAvailability(first, tuesday9am);
      expect(later['e1']!.availableAt, tuesday3am, reason: 'already known');
      expect(later['e2']!.availableAt, tuesday9am, reason: 'added before the scan that found it');
      expect(later['e3']!.availableAt, DateTime(2026, 10, 13, 10), reason: 'added "after" the scan (clock skew)');
    });

    test('a scan during an airing makes the episode available from the scan', () {
      final first = _episodes({}).withAvailability(null, DateTime(2026, 10, 13));
      final scan = DateTime(2026, 10, 13, 20, 10);
      final later = _episodes({'e1': DateTime(2026, 10, 13, 19).toUtc().toIso8601String()}).withAvailability(first, scan);
      expect(later['e1']!.availableAt, scan);
    });

    test('upgrading: a saved index without times gets the later of added and the scan', () {
      final saved = LibraryIndex.fromJson(_episodes({'e1': null}).toJson());
      final upgraded = _episodes({'e1': tuesday3am.toUtc().toIso8601String()}).withAvailability(saved, tuesday9am);
      expect(upgraded['e1']!.availableAt, tuesday9am);
    });
  });

  group('channel and settings fields', () {
    test('Channel and ChannelSource round-trip the new fields and default when missing', () {
      final ch = Channel(
        id: 'auto:radio',
        number: 40,
        name: 'Music Radio',
        icon: const ChannelIcon.builtin('radio'),
        source: const ChannelSource(includeEpisodes: false, includeSongs: true, includeMusicVideos: true, decades: [1980]),
        order: PlaybackOrder.random,
        playlist: const ['a1'],
        anchor: DateTime(2026, 10, 20),
        logoMode: LogoMode.always,
        premieres: false,
      );
      final back = Channel.fromJson(ch.toJson());
      expect(back.logoMode, LogoMode.always);
      expect(back.premieres, isFalse);
      expect(back.source.includeSongs, isTrue);
      expect(back.source.includeMusicVideos, isTrue);
      expect(back.source.decades, [1980]);
      expect(back.isMusic, isTrue);

      final old = Channel.fromJson({
        'id': 'auto:all-shows',
        'number': 2,
        'name': 'All Shows',
        'icon': {'kind': 'builtin', 'value': 'tv'},
        'source': {'episodes': true, 'movies': false},
        'order': 'random',
        'playlist': const <String>[],
        'anchor': '2026-10-01T00:00:00.000Z',
      });
      expect(old.logoMode, isNull, reason: 'follows the main setting');
      expect(old.premieres, isTrue);
      expect(old.source.includeSongs, isFalse);
      expect(old.source.includeMusicVideos, isFalse);
      expect(old.source.decades, isEmpty);
    });

    test('AppSettings round-trips logo, groups, tabs and premieres', () {
      final s = AppSettings.fresh()
        ..logoMode = LogoMode.off
        ..groups = [ChannelGroup(id: 'group:sat', name: 'Saturday', channelIds: ['c5', 'c9'])]
        ..guideTabs = ['all', 'favorites', 'group:sat', 'auto:movies', 'auto:music', 'auto:kids']
        ..hiddenTabs = {'auto:music'}
        ..guideTab = 'group:sat'
        ..premieres = const PremiereSettings(enabled: false, startMinute: 21 * 60, days: {1, 2, 3, 4, 5});
      final back = AppSettings.fromJson(s.toJson());
      expect(back.logoMode, LogoMode.off);
      expect(back.groups.single.name, 'Saturday');
      expect(back.groups.single.channelIds, ['c5', 'c9']);
      // Saved before the Live TV tab: it goes just before Movies.
      expect(back.guideTabs, ['all', 'favorites', 'group:sat', 'auto:live', 'auto:movies', 'auto:music', 'auto:kids']);
      expect(back.hiddenTabs, {'auto:music'});
      expect(back.guideTab, 'group:sat');
      expect(back.premieres, const PremiereSettings(enabled: false, startMinute: 21 * 60, days: {1, 2, 3, 4, 5}));
    });

    test('settings from before this change load the defaults', () {
      for (final old in [
        {'installId': 'nightingaletv-abc', 'commercialPlan': {'mode': 'off'}},
        {'installId': 'retrotv-abc', 'commercialsEnabled': false},
      ]) {
        final s = AppSettings.fromJson(old);
        expect(s.logoMode, LogoMode.nowAndThen);
        expect(s.groups, isEmpty);
        expect(s.guideTabs, GuideTabs.defaultOrder);
        expect(s.hiddenTabs, isEmpty);
        expect(s.guideTab, isNull);
        expect(s.premieres.enabled, isTrue);
        expect(s.premieres.startMinute, 20 * 60);
        expect(s.premieres.days, PremiereSettings.everyDay);
      }
    });
  });

  group('play counts and root membership', () {
    LibraryIndex index() => LibraryIndex.fromJellyfinItems(
          seriesItems: [
            {'Id': 's1', 'Name': 'Cheers', 'ProductionYear': 1982, 'OfficialRating': 'TV-PG'},
            {'Id': 's2', 'Name': 'Late', 'ProductionYear': 1990, 'OfficialRating': 'TV-MA'},
          ],
          episodeItems: [
            for (final (id, series) in [('e1', 's1'), ('e2', 's1'), ('e3', 's2')])
              {
                'Id': id,
                'Name': id,
                'SeriesId': series,
                'SeriesName': series == 's1' ? 'Cheers' : 'Late',
                'ParentIndexNumber': 1,
                'IndexNumber': int.parse(id.substring(1)),
                'RunTimeTicks': const Duration(minutes: 22).inMicroseconds * 10,
                if (id == 'e1') 'UserData': {'PlayCount': 4},
                if (id == 'e3') 'UserData': {'PlayCount': 0, 'Played': true},
              },
          ],
          movieItems: [
            {'Id': 'm1', 'Name': 'Movie', 'RunTimeTicks': const Duration(minutes: 90).inMicroseconds * 10, 'OfficialRating': 'PG'},
          ],
          commercialItems: [
            {'Id': 'ad', 'Name': 'Ad', 'RunTimeTicks': const Duration(seconds: 30).inMicroseconds * 10},
          ],
          poolsByItem: {'ad': ['p']},
        );

    test('play counts come from UserData, absent meaning 0', () {
      final i = index();
      expect(i['e1']!.playCount, 4);
      expect(i['e2']!.playCount, 0);
      expect(i['e3']!.playCount, 1, reason: 'marked played');
    });

    test('only episodes and movies join a root; commercials and unknown ids do not', () {
      final i = index().withRoots({
        'box': {'e1', 'm1', 'ad', 'home-video'},
        'gone': {},
      }, missing: {'gone'});
      expect(i.rootsByItem, {'e1': ['box'], 'm1': ['box']});
      expect(i.itemsByRoot['box'], {'e1', 'm1'});
      expect(i.roots, {'box', 'gone'});
      expect(i.missingRoots, {'gone'});
    });

    test('a root fetched again replaces its old membership', () {
      final i = index().withRoots({'box': {'e1', 'm1'}}).withRoots({'box': {'e2'}, 'other': {'m1'}});
      expect(i.itemsByRoot['box'], {'e2'});
      expect(i.itemsByRoot['other'], {'m1'});
    });

    test('they round-trip; an index saved before them loads with none', () {
      final i = index().withRoots({'box': {'e1', 'm1'}, 'gone': {}}, missing: {'gone'});
      final back = LibraryIndex.fromJson(jsonDecode(jsonEncode(i.toJson())) as Map<String, Object?>);
      expect(back['e1']!.playCount, 4);
      expect(back.rootsByItem, i.rootsByItem);
      expect(back.roots, {'box', 'gone'});
      expect(back.missingRoots, {'gone'});
      final old = index().toJson();
      expect(old.containsKey('rootsByItem'), isFalse);
      expect((old['episodes'] as List).where((e) => (e as Map).containsKey('plays')), hasLength(2),
          reason: 'only a non-zero count is written');
      final loaded = LibraryIndex.fromJson(jsonDecode(jsonEncode(old)) as Map<String, Object?>);
      expect(loaded.roots, isEmpty);
      expect(loaded.rootsByItem, isEmpty);
    });

    test('a kid profile keeps no root item over its limit', () {
      final i = index().withRoots({'box': {'e1', 'e3', 'm1'}}).restrictedTo(ratingRank('TV-PG')!);
      expect(i.itemsByRoot['box'], {'e1', 'm1'});
    });
  });
}
