import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/source_picker_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/web_admin/api_client.dart';
import 'package:nightingale_tv/web_admin/app.dart';
import 'package:nightingale_tv/web_admin/session.dart';
import 'package:nightingale_tv/web_admin/widgets/source_editor.dart';

import 'fake_playback.dart';
import 'fixtures.dart';
import 'genre_decade_channels_test.dart' show Show, films, lib;

/// The Decades chips and the Shows and Movies toggles in the TV's source
/// picker and the web admin's source editor (genre-decade-channels 5.2,
/// 5.3).
void main() {
  final library = lib([
    const Show('Cheers', ['Comedy'], year: 1982),
    const Show('Frasier', ['Comedy'], year: 1993),
    const Show('ER', ['Drama'], year: 1994),
  ], [
    ...films('die-hard', 4, ['Action'], [1988]),
    ...films('speed', 3, ['Action'], [1994]),
    ...films('clue', 2, ['Comedy'], [1985]),
  ]);

  group('TV source picker', () {
    late ChannelSource? saved;

    Future<AppState> show(WidgetTester tester, ChannelSource initial) async {
      saved = null;
      tester.view.physicalSize = TvCanvas.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late Directory dir;
      late AppState app;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('nightingale_tv_source_decades');
        app = await signedInApp(dir, library);
      });
      final tuner = Tuner(app, player: FakePlayer([]));
      await tester.pumpWidget(AppScope(
        app: app,
        tuner: tuner,
        child: MaterialApp(
          theme: GuideTheme.cableGuide.toThemeData(),
          builder: (context, child) => TvCanvas(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => SourcePickerScreen(
                      initial: initial,
                      name: 'Mine',
                      order: PlaybackOrder.random,
                      onDone: (source, name, order) async {
                        saved = source;
                        return null;
                      },
                    ),
                  )),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        tuner.dispose();
        await tester.runAsync(() async {
          await app.close();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await dir.delete(recursive: true);
        });
      });
      return app;
    }

    /// Scrolls the right-hand column (summary, toggles, genres, decades)
    /// until [label] is built, then onto the screen.
    Future<void> reveal(WidgetTester tester, String label) async {
      final column = Offset(TvCanvas.size.width - 360, TvCanvas.size.height / 2);
      for (final step in const [-300.0, 300.0]) {
        for (var i = 0; i < 20 && find.text(label).evaluate().isEmpty; i++) {
          await tester.dragFrom(column, Offset(0, step));
          await tester.pumpAndSettle();
        }
      }
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String label) async {
      await reveal(tester, label);
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    bool checked(WidgetTester tester, String label) {
      final row = find.ancestor(of: find.text(label).first, matching: find.byType(Row)).first;
      return find.descendant(of: row, matching: find.byIcon(Icons.check_box)).evaluate().isNotEmpty;
    }

    testWidgets('lists only the decades the library holds', (tester) async {
      await show(tester, const ChannelSource(includeEpisodes: false));
      await reveal(tester, '90s');
      for (final d in ['80s', '90s']) {
        expect(find.text(d), findsOneWidget, reason: d);
      }
      expect(find.text('70s'), findsNothing);
      expect(find.text('2000s'), findsNothing);
    });

    testWidgets('picking a genre turns Shows on: "Plays every drama show."', (tester) async {
      await show(tester, const ChannelSource(includeEpisodes: false));
      await reveal(tester, 'Include shows');
      expect(checked(tester, 'Include shows'), isFalse);
      await tap(tester, 'Drama');
      await reveal(tester, 'Include shows');
      expect(checked(tester, 'Include shows'), isTrue);
      await reveal(tester, 'Plays every drama show.');
    });

    testWidgets('80s Action Movies: Action and 80s, Shows off, Movies on', (tester) async {
      final app = await show(tester, const ChannelSource(includeEpisodes: false));
      await tap(tester, 'Action');
      await tap(tester, '80s');
      await tap(tester, 'Include shows');
      await tap(tester, 'Include movies');
      await reveal(tester, 'Plays every 80s action movie.');
      await tap(tester, 'Done');
      expect(saved!.genres, ['Action']);
      expect(saved!.decades, [1980]);
      expect(saved!.includeEpisodes, isFalse);
      expect(saved!.includeMovies, isTrue);
      expect(buildPlaylist(app.library, saved!, PlaybackOrder.random, seed: 1).toSet(),
          {for (var i = 1; i <= 4; i++) 'die-hard-$i'});
    });

    testWidgets('the decade chips work by D-pad', (tester) async {
      await show(tester, const ChannelSource(includeEpisodes: false));
      await reveal(tester, '90s');
      Focus.of(tester.element(find.text('90s'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      await reveal(tester, 'Plays every 90s show.');
      await tap(tester, 'Done');
      expect(saved!.decades, [1990]);
      expect(saved!.includeEpisodes, isTrue);
    });

    testWidgets('a channel saved before decades opens unchanged: Comedy with Shows and Movies on', (tester) async {
      const old = ChannelSource(genres: ['Comedy'], includeMovies: true);
      final app = await show(tester, old);
      await reveal(tester, 'Include shows');
      expect(checked(tester, 'Include shows'), isTrue);
      expect(checked(tester, 'Include movies'), isTrue);
      await tap(tester, 'Done');
      expect(buildPlaylist(app.library, saved!, PlaybackOrder.random, seed: 1).toSet(),
          buildPlaylist(app.library, old, PlaybackOrder.random, seed: 1).toSet());
    });
  });

  group('web admin source editor', () {
    Map<String, Object?> catalog() => {
          'shows': const [],
          'genres': const ['Action', 'Comedy', 'Drama'],
          'movies': 9,
          'videoDecades': const [1980, 1990],
          'decades': const [],
        };

    /// Replaces the editor's source from outside, as a block following its
    /// channel does.
    void Function(ChannelSource source)? replace;

    Future<List<ChannelSource>> show(WidgetTester tester, ChannelSource initial) async {
      final changes = <ChannelSource>[];
      final api = ApiClient(MockClient((r) async => http.Response(jsonEncode(const []), 200)),
          base: Uri.parse('http://nas.local:8484/'));
      final session = Session(api);
      var source = initial;
      replace = null;
      await tester.pumpWidget(AdminScope(
        api: api,
        session: session,
        router: WebRouter(session),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(builder: (context, setState) {
                replace = (s) => setState(() => source = s);
                return SourceEditor(
                  profileId: 'p1',
                  source: source,
                  catalog: catalog(),
                  // As the Blocks page does: the page keeps its own rating floor.
                  onChanged: (s) => setState(() {
                    source = s.copyWith(ratingFloor: () => source.ratingFloor);
                    changes.add(s);
                  }),
                );
              }),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return changes;
    }

    bool selected(WidgetTester tester, String label) =>
        tester.widget<FilterChip>(find.ancestor(of: find.text(label), matching: find.byType(FilterChip))).selected;

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('the Decades chips come from videoDecades', (tester) async {
      await show(tester, const ChannelSource(includeEpisodes: false));
      expect(find.text('Decades'), findsOneWidget);
      expect(find.text('80s'), findsOneWidget);
      expect(find.text('90s'), findsOneWidget);
    });

    testWidgets('90s Comedy TV: Comedy and 90s turn Shows on', (tester) async {
      final changes = await show(tester, const ChannelSource(includeEpisodes: false));
      await tap(tester, 'Comedy');
      expect(selected(tester, 'Include shows'), isTrue);
      await tap(tester, '90s');
      final s = changes.last;
      expect([s.genres, s.decades, s.includeEpisodes, s.includeMovies], [['Comedy'], [1990], true, false]);
      expect(buildPlaylist(library, s, PlaybackOrder.cyclic, seed: 1).map((id) => library[id]!.seriesKey).toSet(),
          {'Frasier'});
    });

    testWidgets('80s Action Movies: Shows off, Movies on', (tester) async {
      final changes = await show(tester, const ChannelSource(includeEpisodes: false));
      await tap(tester, 'Action');
      await tap(tester, '80s');
      await tap(tester, 'Include shows');
      await tap(tester, 'Movies (9)');
      final s = changes.last;
      expect([s.genres, s.decades, s.includeEpisodes, s.includeMovies], [['Action'], [1980], false, true]);
    });

    testWidgets('a source saved before decades opens with Shows on and keeps its rating floor', (tester) async {
      final changes = await show(
          tester, const ChannelSource(genres: ['Comedy'], includeMovies: true, ratingFloor: RatingFloor.mature));
      expect(selected(tester, 'Include shows'), isTrue);
      expect(selected(tester, 'Movies (9)'), isTrue);
      await tap(tester, '80s');
      expect((changes.last.includeEpisodes, changes.last.ratingFloor), (true, RatingFloor.mature));
    });

    testWidgets('Shows follows a source set from outside, and stays as picked otherwise', (tester) async {
      await show(tester, const ChannelSource(includeEpisodes: false));
      await tap(tester, 'Include shows');
      await tap(tester, 'Comedy');
      expect(selected(tester, 'Include shows'), isTrue, reason: 'kept across its own changes');
      replace!(const ChannelSource(includeEpisodes: false, includeMovies: true));
      await tester.pumpAndSettle();
      expect(selected(tester, 'Include shows'), isFalse);
      replace!(const ChannelSource(genres: ['Drama']));
      await tester.pumpAndSettle();
      expect(selected(tester, 'Include shows'), isTrue);
    });
  });
}
