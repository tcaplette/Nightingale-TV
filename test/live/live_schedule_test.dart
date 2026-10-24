import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_schedule.dart';

// Runs in whatever time zone the test process has; tool runs it under
// several (TZ=America/New_York, Asia/Kolkata, UTC).
void main() {
  final eight = DateTime(2026, 10, 21, 20);
  LiveProgramme prog(DateTime start, int minutes, String title,
          {String? sub, int? season, int? episode, bool isNew = false, bool movie = false}) =>
      LiveProgramme(
          start: start,
          end: start.add(Duration(minutes: minutes)),
          title: title,
          subtitle: sub,
          season: season,
          episode: episode,
          isNew: isNew,
          isMovie: movie,
          description: '$title description');

  test('programmes as guide cells: show, episode code and title, a NEW tag', () {
    final s = LiveSchedule(channelId: 'live:s:k', channelName: 'WXYZ 7', programmes: [
      prog(eight, 30, 'The News', sub: 'Tonight', season: 3, episode: 5, isNew: true),
      prog(eight.add(const Duration(minutes: 30)), 120, 'Test Movie', movie: true),
    ]);
    final news = s.guideProgramAt(eight.add(const Duration(minutes: 12)));
    expect((news.title, news.subtitle, news.detail), ('The News', 'S3 · E5 · Tonight', 'Tonight'));
    expect(news.isPremiere, isTrue);
    expect(news.isLive, isTrue);
    expect(news.item!.overview, 'The News description');
    final movie = s.next(news);
    expect((movie.title, movie.start), ('Test Movie', eight.add(const Duration(minutes: 30))));
    expect(movie.isPremiere, isFalse);
  });

  test("no guide data: hour-long cells on the clock hour, titled with the channel's name", () {
    final s = LiveSchedule(channelId: 'live:s:k', channelName: 'WXYZ 7');
    final at = DateTime(2026, 10, 21, 20, 12);
    final cells = s.guideProgramsBetween(at, at.add(const Duration(hours: 3)));
    expect(cells, hasLength(4));
    for (final c in cells) {
      expect((c.title, c.detail), ('WXYZ 7', LiveSchedule.noGuide));
      expect(c.duration, const Duration(hours: 1));
      expect(c.start.minute, 0);
      expect(c.isLive, isTrue);
    }
    expect(cells.first.start, DateTime(2026, 10, 21, 20));
    expect(s.guideUntil, isNull);
  });

  test('gaps between programmes are cut at their edges', () {
    final s = LiveSchedule(channelId: 'c', channelName: 'C', programmes: [
      prog(eight, 30, 'A'),
      prog(eight.add(const Duration(minutes: 75)), 30, 'B'),
    ]);
    final cells = s.guideProgramsBetween(eight, eight.add(const Duration(hours: 2)));
    expect([for (final c in cells) (c.title, c.start.difference(eight).inMinutes, c.duration.inMinutes)], [
      ('A', 0, 30),
      ('C', 30, 30),
      ('C', 60, 15),
      ('B', 75, 30),
      ('C', 105, 15),
    ]);
    expect(s.guideUntil, eight.add(const Duration(minutes: 105)));
  });

  test('playback is the programme itself: one segment, no breaks, nothing after it in the slot', () {
    final s = LiveSchedule(channelId: 'c', channelName: 'C', programmes: [prog(eight, 30, 'A')]);
    final t = eight.add(const Duration(minutes: 10));
    final on = s.playbackAt(t);
    expect((on.title, on.isBreak, on.isCommercial, on.isOffAir), ('A', false, false, false));
    expect(s.isLastPart(s.programAt(t), on), isTrue);
    expect(s.hasBreaks, isFalse);
    expect(s.nextBlockAiring(t), isNull);
  });

  test('overlapping input is handled; empty programmes ignored', () {
    final s = LiveSchedule(channelId: 'c', channelName: 'C', programmes: [
      prog(eight.add(const Duration(minutes: 30)), 30, 'Second'),
      prog(eight, 30, 'First'),
      LiveProgramme(start: eight, end: eight, title: 'Empty'),
    ]);
    expect([for (final p in s.programsBetween(eight, eight.add(const Duration(hours: 1)))) p.title], ['First', 'Second']);
  });

  test('gap cells stay an hour long and on the clock hour across a DST change', () {
    // The night US clocks fall back (and Europe's a week before): in a zone
    // with DST one of these hours repeats; in others nothing changes.
    final s = LiveSchedule(channelId: 'c', channelName: 'C');
    final from = DateTime.utc(2026, 11, 1, 3).toLocal();
    final cells = s.guideProgramsBetween(from, from.add(const Duration(hours: 6)));
    expect(cells.length, inInclusiveRange(6, 7));
    for (final c in cells.skip(1)) {
      expect(c.duration, const Duration(hours: 1));
      expect(c.start.minute, 0);
    }
    for (var i = 1; i < cells.length; i++) {
      expect(cells[i].start, cells[i - 1].end);
    }
  });

  test('times are shown as the device keeps them: programme starts survive the zone', () {
    final utc = DateTime.utc(2026, 10, 22, 0);
    final s = LiveSchedule(channelId: 'c', channelName: 'C', programmes: [
      LiveProgramme(start: utc.toLocal(), end: utc.add(const Duration(minutes: 30)).toLocal(), title: 'The News'),
    ]);
    final p = s.programAt(utc.add(const Duration(minutes: 5)).toLocal());
    expect(p.title, 'The News');
    expect(p.start.toUtc(), utc);
    expect(p.start.isUtc, isFalse);
  });
}
