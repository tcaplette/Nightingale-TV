import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;
  late Household household;
  late Profile a;
  late Profile b;

  /// Signs [p] in with a cached library, as if it had been used before.
  Future<void> seed(Profile p, {String? serverId}) async {
    final app = await signedInApp((await household.storageFor(p)).root, fakeLibrary(), serverId: serverId);
    await app.close();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_household_export');
    household = Household(await AppStorage.at(dir), runAnalysis: false);
    await household.start();
    // Start at "Who's watching?", with nobody on screen.
    household.leave();
    a = household.profiles.single..name = 'A';
    b = household.newProfile()..name = 'B';
    await household.saveProfile(b);
    await seed(a, serverId: 'srv');
    await seed(b, serverId: 'srv');
  });

  tearDown(() async {
    for (final p in household.profiles) {
      if (household.appFor(p.id) case final app?) await _ready(app);
    }
    household.leave();
    await household.setExportedProfiles({});
    await dir.delete(recursive: true);
  });

  test('an exported profile keeps one AppState, on screen or off', () async {
    await household.setExportedProfiles({a.id});
    final offScreen = household.appFor(a.id)!;
    expect(offScreen.background, isTrue);
    expect(household.appFor(b.id), isNull);

    await household.select(b);
    expect(household.appFor(a.id), same(offScreen));

    await household.select(a);
    expect(household.app, same(offScreen));
    expect(offScreen.background, isFalse);

    household.leave();
    await pumpEventQueue();
    expect(household.appFor(a.id), same(offScreen));
    expect(offScreen.background, isTrue);

    await household.select(a);
    expect(household.app, same(offScreen));
  });

  test('a profile that is not exported is closed when it leaves the screen', () async {
    await household.select(b);
    final app = household.app!;
    await household.select(a);
    expect(household.appFor(b.id), isNull);
    expect(identical(household.app, app), isFalse);
  });

  test('an edit made on the TV is what the export sees', () async {
    await household.setExportedProfiles({a.id});
    await household.select(a);
    final app = household.app!;
    await _ready(app);
    final channel = app.channels.first;
    await app.updateChannel(channel, name: 'Renamed');
    household.leave();
    await pumpEventQueue();
    expect(household.appFor(a.id)!.channels.first.name, 'Renamed');
  });

  test('turning export off closes the off-screen state', () async {
    await household.setExportedProfiles({a.id, b.id});
    expect(household.appFor(a.id), isNotNull);
    expect(household.appFor(b.id), isNotNull);
    await household.setExportedProfiles({b.id});
    expect(household.appFor(a.id), isNull);
    expect(household.appFor(b.id), isNotNull);
  });

  test('profiles on one server share one analysis cache', () async {
    await household.setExportedProfiles({a.id, b.id});
    await pumpEventQueue();
    final offA = household.appFor(a.id)!;
    final offB = household.appFor(b.id)!;
    await _ready(offA);
    await _ready(offB);
    expect(offA.analysisCache, isNotNull);
    expect(offA.analysisCache, same(offB.analysisCache));
  });

  test('analysis holds off while export streams', () async {
    await household.select(a);
    final app = household.app!;
    expect(app.analysisBusy.value, isFalse);
    household.exportStreaming.value = true;
    expect(app.analysisBusy.value, isTrue);
    household.exportStreaming.value = false;
    expect(app.analysisBusy.value, isFalse);
    app.playbackBusy.value = true;
    expect(app.analysisBusy.value, isTrue);
    app.playbackBusy.value = false;
  });

  test('a kid limit change reloads an off-screen kid profile under the new limit', () async {
    final kid = household.newProfile()
      ..name = 'Kid'
      ..kind = ProfileKind.kid
      ..rating = KidRating.young;
    a.setPin('1234');
    b.setPin('5678');
    await household.saveProfile(a);
    await household.saveProfile(b);
    await household.saveProfile(kid);
    await seed(kid);
    await household.setExportedProfiles({kid.id});
    final before = household.appFor(kid.id)!;
    kid.rating = KidRating.older;
    await household.saveProfile(kid);
    final after = household.appFor(kid.id)!;
    expect(identical(before, after), isFalse);
    expect(after.maxRatingRank, KidRating.older.maxRank);
  });

  test('deleting an exported profile lets go of its state', () async {
    await household.setExportedProfiles({a.id, b.id});
    await household.select(a);
    await household.deleteProfile(b);
    expect(household.appFor(b.id), isNull);
  });

  test('an off-screen profile refreshes a stale library on a timer', () async {
    // Fresh enough at start, stale 300 ms later: only the timer can notice.
    final storage = await household.storageFor(a);
    final library = LibraryIndex.fromJson((await storage.readJson('library.json'))! as Map<String, Object?>);
    final soonStale = DateTime.now().subtract(AppState.libraryMaxAge).add(const Duration(milliseconds: 300));
    await storage.writeJson(
        'library.json',
        LibraryIndex(series: library.series, episodes: library.episodes, movies: library.movies, fetchedAt: soonStale)
            .toJson());
    final interval = AppState.staleCheckInterval;
    AppState.staleCheckInterval = const Duration(milliseconds: 50);
    addTearDown(() => AppState.staleCheckInterval = interval);
    await household.setExportedProfiles({a.id});
    final app = household.appFor(a.id)!;
    // The server (127.0.0.1:9) refuses connections, so a refresh attempt
    // shows up as a sync error.
    for (var i = 0; i < 100 && app.syncError == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(app.syncError, isNotNull);
  });
}

Future<void> _ready(AppState app) async {
  for (var i = 0; i < 100 && app.phase != AppPhase.ready; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
