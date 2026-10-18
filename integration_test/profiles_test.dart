// Profiles UI test. Needs no server.
//
//   SNAP_DIR=/tmp/snaps flutter test integration_test/profiles_test.dart -d linux
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/ui/profiles_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

import '../test/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add a locked grown-up and a kid, switch between them', (tester) async {
    final shows = {'Bluey': 20, 'Arthur': 30, 'Seinfeld': 30, 'Sopranos': 20};
    const ratings = {'Bluey': 'TV-Y', 'Arthur': 'TV-Y7', 'Seinfeld': 'TV-PG', 'Sopranos': 'TV-MA'};
    final base = fakeLibrary(shows: shows, genres: {
      for (final s in shows.keys) s: [s == 'Bluey' || s == 'Arthur' ? 'Kids' : 'Comedy'],
    });
    final library = LibraryIndex(
      series: [
        for (final s in base.series)
          SeriesEntry(key: s.key, id: s.id, name: s.name, year: s.year, genres: s.genres, officialRating: ratings[s.name]),
      ],
      episodes: base.episodes,
      movies: base.movies,
      fetchedAt: DateTime.now(),
    );
    final h = await UiHarness.start(tester, library);
    final household = h.household;
    Future<void> typePin(String pin) async {
      for (final d in pin.split('')) {
        await h.press(LogicalKeyboardKey(0x30 + int.parse(d)), after: const Duration(milliseconds: 200));
      }
      await h.wait(const Duration(milliseconds: 600));
    }

    expect(household.profiles.single.name, 'Tester');

    // A kid profile needs the grown-up locked first.
    await h.openMenuItem('Profiles');
    await h.snap('p1-profiles');
    await h.tap('Add profile');
    await tester.enterText(find.byType(TextField), 'Sam');
    await h.tap('Kid');
    await h.tap('Young kids: TV-Y and TV-Y7');
    await h.tap('Save');
    expect(find.textContaining('Set a PIN on Tester'), findsOneWidget);
    await h.snap('p2-kid-needs-pin');
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));

    // Lock the grown-up with a PIN, typed on the keyboard.
    await h.tap('Tester');
    await h.tap('Set a PIN');
    await h.snap('p3-pin-pad');
    await typePin('1234');
    await typePin('1234');
    await h.tap('Save');
    expect(household.profiles.single.hasPin, isTrue);

    await h.tap('Add profile');
    await tester.enterText(find.byType(TextField), 'Sam');
    await h.tap('Kid');
    await h.tap('Young kids: TV-Y and TV-Y7');
    await h.tap('Save');
    expect(household.profiles.map((p) => p.name), ['Tester', 'Sam']);
    await h.snap('p4-two-profiles');

    // Seed Sam's library as if Sam had signed in (rated content, all ages).
    final sam = household.profiles.last;
    await tester.runAsync(() async {
      final storage = await household.storageFor(sam);
      await storage.writeJson('session.json', {
        'serverUrl': 'http://127.0.0.1:9',
        'userId': 'u2',
        'userName': 'sam',
        'accessToken': 'none',
        'deviceId': 'test',
      });
      await storage.writeJson('library.json', library.toJson());
      await storage.writeJson('channels.json', [
        for (final c in ChannelGenerator(library.restrictedTo(KidRating.young.maxRank)).generate()) c.toJson()
      ]);
    });

    // Switch profile → Who's watching?
    await h.press(LogicalKeyboardKey.escape, after: const Duration(seconds: 1));
    await h.tap('Switch profile');
    await h.wait(const Duration(seconds: 1));
    expect(find.byType(ProfilePickerScreen), findsOneWidget);
    await h.snap('p5-whos-watching');

    // The grown-up's PIN: wrong, then right.
    await h.tap('Tester');
    await typePin('0000');
    expect(find.text('That PIN isn\'t right. Try again.'), findsOneWidget);
    await h.snap('p6-wrong-pin');
    await typePin('1234');
    await h.wait(const Duration(seconds: 1));
    expect(household.current?.name, 'Tester');
    expect(find.byType(TvScreen), findsOneWidget);

    // Over to Sam: only shows rated TV-Y7 or younger, and a locked menu.
    await h.openMenuItem('Switch profile');
    await h.wait(const Duration(seconds: 1));
    await h.tap('Sam');
    await h.wait(const Duration(seconds: 1));
    expect(household.current?.name, 'Sam');
    expect(household.app!.phase, AppPhase.ready);
    expect({for (final s in household.app!.library.series) s.name}, {'Bluey', 'Arthur'});
    await h.press(LogicalKeyboardKey.keyM, after: const Duration(seconds: 1));
    expect(find.byIcon(Icons.lock), findsWidgets);
    await h.snap('p7-kid-menu-locked');
    await h.tap('Channels & icons');
    await typePin('1234');
    await h.wait(const Duration(seconds: 1));
    expect(find.text('CHANNELS & ICONS'), findsOneWidget);
    await h.snap('p8-unlocked-by-parent');

    await h.dispose();
  });
}
