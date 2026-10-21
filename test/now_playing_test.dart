import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/widgets/channel_logo.dart';
import 'package:nightingale_tv/ui/widgets/now_playing.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

void main() {
  final channel = Channel(
    id: 'auto:radio:decade:1980',
    number: 41,
    name: '80s Radio',
    icon: const ChannelIcon.builtin('radio'),
    source: const ChannelSource(includeEpisodes: false, includeSongs: true, decades: [1980]),
    order: PlaybackOrder.random,
    playlist: const [],
    anchor: DateTime(2026),
  );
  const song = MediaEntry(
      id: 's1',
      kind: MediaKind.song,
      title: 'Take On Me',
      runtime: Duration(minutes: 3, seconds: 48),
      artist: 'a-ha',
      album: 'Hunting High and Low',
      albumId: 'al1',
      year: 1985);
  const nextSong = MediaEntry(
      id: 's2', kind: MediaKind.song, title: "Don't You (Forget About Me)", runtime: Duration(minutes: 4), artist: 'Simple Minds');
  final start = DateTime(2026, 10, 20, 19, 3);
  final slot = ScheduledProgram(item: song, start: start, end: start.add(song.runtime));
  final next = ScheduledProgram(item: nextSong, start: slot.end, end: slot.end.add(nextSong.runtime));

  Future<void> show(WidgetTester tester, {List<ImageProvider> art = const [], required DateTime Function() clock}) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: TvCanvas(child: NowPlayingCard(channel: channel, song: slot, next: next, art: art, clock: clock)),
    ));
    await tester.pump();
  }

  testWidgets('the song, artist, album and year, progress, the channel and the next song', (tester) async {
    await show(tester, clock: () => start.add(const Duration(minutes: 1, seconds: 54)));
    expect(find.text('Take On Me'), findsOneWidget);
    expect(find.text('a-ha'), findsOneWidget);
    expect(find.text('Hunting High and Low · 1985'), findsOneWidget);
    expect(find.text('1:54'), findsOneWidget);
    expect(find.text('3:48'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, closeTo(0.5, 0.01));
    expect(find.text('NOW PLAYING ON 80S RADIO'), findsOneWidget);
    expect(find.byType(ChannelLogo), findsOneWidget);
    expect(find.text("Up next: Simple Minds – Don't You (Forget About Me)"), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing art: a music-note tile', (tester) async {
    await show(tester, clock: () => start);
    expect(find.byType(MusicNoteTile), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("art that won't load falls back to the next, then the tile", (tester) async {
    await show(tester, clock: () => start, art: [MemoryImage(Uint8List.fromList([1, 2, 3])), MemoryImage(Uint8List(4))]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.byType(MusicNoteTile), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the art and text drift a few pixels from minute to minute', (tester) async {
    var now = start;
    await show(tester, clock: () => now);
    Offset offset() {
      final t = tester.widget<Transform>(find.byType(Transform).first).transform.getTranslation();
      return Offset(t.x, t.y);
    }

    final first = offset();
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(offset(), isNot(first));
    final seen = {for (var m = 0; m < 600; m++) nowPlayingDrift(start.add(Duration(minutes: m)))};
    expect(seen.length, greaterThan(100));
    expect(seen.every((o) => o.dx.abs() <= 18 && o.dy.abs() <= 12), isTrue);
    expect(nowPlayingDrift(start), nowPlayingDrift(start.add(const Duration(seconds: 30))), reason: 'still within the minute');
    await tester.pumpWidget(const SizedBox());
  });
}
