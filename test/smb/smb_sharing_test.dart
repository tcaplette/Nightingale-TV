import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/sharing/channel_recipe.dart';
import 'package:nightingale_tv/sharing/party_timeline.dart';
import 'package:nightingale_tv/sharing/presence.dart';
import 'package:nightingale_tv/sharing/recipe_matcher.dart';

MediaEntry _movie(String id, String title, int? year, int minutes, {List<String> ids = const []}) =>
    MediaEntry(id: id, kind: MediaKind.movie, title: title, year: year, runtime: Duration(minutes: minutes), providerIds: ids);

LibraryIndex _lib(List<MediaEntry> movies, {List<MediaEntry> episodes = const [], List<SeriesEntry> series = const []}) =>
    LibraryIndex(series: series, episodes: episodes, movies: movies, fetchedAt: DateTime(2026));

RecipeItem _wanted(String title, int? year, int minutes, {List<String> ids = const []}) =>
    RecipeItem.movie(ids: ids, title: title, year: year, runtime: Duration(minutes: minutes));

void main() {
  group('movies without a year', () {
    test("the sender's dated movie finds the receiver's yearless file", () {
      final m = RecipeMatcher(_lib([_movie('a', 'Heat', null, 170)]));
      expect(m.itemId(_wanted('Heat', 1995, 170), const []), 'a');
    });

    test("the sender's yearless file finds the receiver's dated movie", () {
      final m = RecipeMatcher(_lib([_movie('a', 'Heat', 1995, 171)]));
      expect(m.itemId(_wanted('Heat', null, 170), const []), 'a');
    });

    test('lengths must be close: 60 s, or 2% of a long one', () {
      final m = RecipeMatcher(_lib([_movie('a', 'Short', null, 92)]));
      expect(m.itemId(_wanted('Short', 1995, 90), const []), isNull, reason: '2% of 90 min is 1.8 min');
      final long = RecipeMatcher(_lib([_movie('b', 'Epic', null, 203)]));
      expect(long.itemId(_wanted('Epic', 1963, 200), const []), 'b', reason: '2% of 200 min is 4 min');
    });

    test('two candidates: neither', () {
      final m = RecipeMatcher(_lib([_movie('a', 'Heat', null, 170), _movie('b', 'Heat', null, 170)]));
      expect(m.itemId(_wanted('Heat', 1995, 170), const []), isNull);
    });

    test('a provider that says otherwise wins', () {
      final m = RecipeMatcher(_lib([_movie('a', 'Heat', null, 170, ids: ['tmdb:1'])]));
      expect(m.itemId(_wanted('Heat', 1995, 170, ids: ['tmdb:949']), const []), isNull);
    });

    test('both dated and different years stay apart', () {
      final m = RecipeMatcher(_lib([_movie('a', 'Heat', 1986, 170)]));
      expect(m.itemId(_wanted('Heat', 1995, 170), const []), isNull);
    });
  });

  group('home videos', () {
    const homeKey = '${LibraryIndex.homePrefix}srv:f1';
    final home = MediaEntry(
        id: 'h1', kind: MediaKind.episode, title: 'Beach day 1', runtime: const Duration(minutes: 3), seriesKey: homeKey, seriesName: 'Summer 2019');
    final lib = _lib([_movie('m', 'Heat', 1995, 170)],
        episodes: [home], series: [const SeriesEntry(key: homeKey, id: 'f1', name: 'Summer 2019')]);

    test('a recipe leaves them out', () {
      final channel = Channel.fromJson({
        'id': 'c', 'name': 'Family', 'number': 5, 'source': <String, Object?>{}, 'icon': {'kind': 'badge', 'value': ''}, 'playlist': ['h1', 'm'], 'anchor': DateTime(2026).toIso8601String(),
      });
      final recipe = ChannelRecipe.fromChannel(channel, const [], lib);
      expect(recipe.items.map((i) => i.title), ['Heat']);
      expect(recipe.toJson().toString(), isNot(contains('Summer 2019')));
      expect(recipe.toJson().toString(), isNot(contains('Beach')));
    });

    test('presence holds no title, a party sends "Home video" that matches nothing', () {
      final program = ScheduledProgram(start: DateTime(2026), end: DateTime(2026, 1, 1, 0, 3), item: home);
      expect(presenceTitle(program), isNull);
      final party = PartyItem.of(home, lib)!;
      expect(party.title, 'Home video');
      expect(party.toJson().toString(), isNot(contains('Summer')));
      expect(party.matchIn(RecipeMatcher(_lib([_movie('x', 'Home video', null, 3)]))), isNull);
    });
  });
}
