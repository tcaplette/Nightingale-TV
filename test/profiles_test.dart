import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';

import 'fixtures.dart';

/// Shows rated for different ages, plus one with no rating.
LibraryIndex _ratedLibrary() {
  final base = fakeLibrary(shows: {'Bluey': 10, 'Simpsons': 10, 'Sopranos': 10, 'Mystery': 10});
  const ratings = {'Bluey': 'TV-Y', 'Simpsons': 'TV-PG', 'Sopranos': 'TV-MA'};
  return LibraryIndex(
    series: [
      for (final s in base.series)
        SeriesEntry(key: s.key, id: s.id, name: s.name, year: s.year, officialRating: ratings[s.name]),
    ],
    episodes: base.episodes,
    movies: base.movies,
    fetchedAt: DateTime.now(),
  );
}

void main() {
  late Directory dir;
  late AppStorage root;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_profiles');
    root = await AppStorage.at(dir);
  });

  tearDown(() => dir.delete(recursive: true));

  group('ratings', () {
    test('are ranked youngest to oldest', () {
      expect(ratingRank('TV-Y'), 0);
      expect(ratingRank('TV-Y7'), 1);
      expect(ratingRank('G'), ratingRank('TV-G'));
      expect(ratingRank('PG-13')!, greaterThan(ratingRank('PG')!));
      expect(ratingRank('TV-MA')!, greaterThan(ratingRank('TV-14')!));
      expect(ratingRank('us-tv-pg'), 3);
      expect(ratingRank('NR'), isNull);
      expect(ratingRank(null), isNull);
    });

    test('kid limits leave out anything older, and anything unrated', () {
      final lib = _ratedLibrary();
      List<String> shows(int rank) => [for (final s in lib.restrictedTo(rank).series) s.name];
      expect(shows(KidRating.young.maxRank), ['Bluey']);
      expect(shows(KidRating.older.maxRank), ['Bluey', 'Simpsons']);
      expect(lib.restrictedTo(KidRating.young.maxRank).episodes.every((e) => e.seriesName == 'Bluey'), isTrue);
    });
  });

  group('PINs', () {
    test('only a salted hash is stored', () {
      final p = Profile(id: 'a', name: 'Mom')..setPin('1234');
      final json = p.toJson();
      expect(json.toString(), isNot(contains('1234')));
      final reloaded = Profile.fromJson(json);
      expect(reloaded.checkPin('1234'), isTrue);
      expect(reloaded.checkPin('4321'), isFalse);
      final other = Profile(id: 'b', name: 'Dad')..setPin('1234');
      expect(other.toJson()['pinHash'], isNot(json['pinHash']));
      expect(Profile.isValidPin('12a4'), isFalse);
    });
  });

  test('an existing setup becomes the first profile, with its files moved in', () async {
    final legacy = await signedInApp(dir, fakeLibrary());
    final channelCount = legacy.allChannels.length;
    final household = Household(root);
    await household.start();

    expect(household.profiles, hasLength(1));
    expect(household.profiles.single.name, 'Tester');
    expect(household.app, isNotNull, reason: 'a single unlocked profile opens straight away');
    expect(household.app!.phase, AppPhase.ready);
    expect(household.app!.allChannels, hasLength(channelCount));
    expect(File('${dir.path}/channels.json').existsSync(), isFalse);
    expect(household.app!.storage.logosDir.path, root.logosDir.path);
  });

  test('a fresh install starts with one profile and the sign-in screen', () async {
    final household = Household(root);
    await household.start();
    expect(household.profiles.single.name, 'Me');
    expect(household.app!.phase, AppPhase.signedOut);
  });

  group('with a grown-up and a kid', () {
    late Household household;
    late Profile mom;
    late Profile kid;

    setUp(() async {
      household = Household(root);
      await household.start();
      mom = household.profiles.single.copy()
        ..name = 'Mom'
        ..setPin('1111');
      await household.saveProfile(mom);
      kid = household.newProfile()
        ..name = 'Sam'
        ..kind = ProfileKind.kid
        ..rating = KidRating.young;
      await household.saveProfile(kid);
    });

    test('kids need every grown-up locked', () async {
      final dad = household.newProfile()..name = 'Dad';
      expect(household.problemWith(dad), contains('Dad'));
      dad.setPin('2222');
      expect(household.problemWith(dad), isNull);
      final unlockedMom = mom.copy()..setPin(null);
      expect(household.problemWith(unlockedMom), contains('Mom'));
    });

    test('there is always a grown-up', () {
      final kidMom = mom.copy()..kind = ProfileKind.kid;
      expect(household.problemWith(kidMom), contains('grown-up'));
      expect(household.problemDeleting(mom), isNotNull);
    });

    test('grown-up PINs unlock parental controls; kid PINs do not', () {
      expect(household.grownUpWithPin('1111')?.name, 'Mom');
      expect(household.grownUpWithPin('9999'), isNull);
    });

    test('profiles are saved and reload', () async {
      final again = Household(root);
      await again.start();
      expect(again.profiles.map((p) => p.name), ['Mom', 'Sam']);
      expect(again.app, isNull, reason: 'more than one profile: ask who is watching');
      expect(again.profiles.last.isKid, isTrue);
      expect(again.profiles.last.rating, KidRating.young);
    });

    test('a kid profile only sees content within its limit', () async {
      final kidStorage = await household.storageFor(kid);
      // Seed the kid's cached library with everything; it's filtered on load.
      await kidStorage.writeJson('session.json', {
        'serverUrl': 'http://127.0.0.1:9',
        'userId': 'u2',
        'userName': 'sam',
        'accessToken': 'none',
        'deviceId': 'test',
      });
      await kidStorage.writeJson('library.json', _ratedLibrary().toJson());
      await kidStorage.writeJson('channels.json', const []);
      await household.select(kid);
      expect(household.app!.maxRatingRank, KidRating.young.maxRank);
      expect([for (final s in household.app!.library.series) s.name], ['Bluey']);
    });

    test('deleting a profile removes its folder', () async {
      final storage = await household.storageFor(kid);
      await storage.writeJson('channels.json', const []);
      await household.deleteProfile(kid);
      expect(household.profiles.map((p) => p.name), ['Mom']);
      expect(storage.root.existsSync(), isFalse);
    });
  });

  group('media analysis', () {
    test('runs for the profile watching, and stops on a profile switch or sign-out', () async {
      final household = Household(root);
      await household.start();
      final first = household.profiles.single;
      // A signed-in profile whose pool holds a reel to split.
      final seeded = await signedInApp((await household.storageFor(first)).root,
          fakeLibrary(commercials: const [Duration(hours: 2)]),
          serverId: 'srv-1');
      await seeded.close();
      await household.select(first);
      final app = household.app!;
      expect(app.analysisCache, isNotNull);
      expect(app.analyzing, isTrue);

      final second = household.newProfile()..name = 'Two';
      await household.saveProfile(second);
      await household.select(second);
      expect(app.analyzing, isFalse, reason: 'the first profile stopped analyzing');
      expect(household.app, isNot(app));

      // Back again: it starts over; signing out stops it.
      await household.select(first);
      final again = household.app!;
      expect(again.analyzing, isTrue);
      await again.signOut();
      expect(again.analyzing, isFalse);
      household.leave();
    });

    test('profiles on the same server share analysis results', () async {
      final household = Household(root);
      await household.start();
      final first = household.profiles.single;
      final firstStorage = await household.storageFor(first);
      final second = household.newProfile()..name = 'Two';
      await household.saveProfile(second);
      final secondStorage = await household.storageFor(second);
      expect(firstStorage.analysisDir.path, root.analysisDir.path);
      expect(secondStorage.analysisDir.path, root.analysisDir.path);
      household.leave();
    });
  });
}
