import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/playback/subtitles.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/server/media_server.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

const english = SubtitleTrack(id: '2', codec: 'subrip', language: 'eng', position: 0);
const spanish = SubtitleTrack(id: '3', codec: 'subrip', language: 'spa', position: 1);
const frenchFile = SubtitleTrack(id: '0', codec: 'srt', language: 'fre', isExternal: true);
const pgs = SubtitleTrack(id: '4', codec: 'pgssub', language: 'eng', position: 2, burnsWhenConverting: true);

void main() {
  late Directory dir;
  late AppState app;
  late List<String> log;
  late FakeClient client;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;

  final library = fakeLibrary(
    shows: {'Alpha': 20, 'Beta': 20, 'Gamma': 20, 'Delta': 20},
    genres: {
      'Alpha': ['Comedy'],
      'Beta': ['Comedy'],
      'Gamma': ['Drama'],
      'Delta': ['Drama'],
    },
    commercials: const [Duration(seconds: 30), Duration(seconds: 15)],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_subtitles');
    app = await signedInApp(dir, library);
    log = [];
    client = FakeClient(log, userId: 'u1');
    app.client = client;
    player = FakePlayer(log);
    now = DateTime.now();
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1)
      ..deviceLanguage = () => 'en';
  });

  tearDown(() async {
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  Future<void> settle() => pumpEventQueue();

  Future<void> captionsOn({String? language}) =>
      app.setPlayback(app.settings.playback.copyWith(captions: true, captionLanguage: () => language));

  ChannelSchedule scheduleOf(Channel ch) => app.scheduleFor(ch)! as ChannelSchedule;

  /// Tunes [ch] in the middle of a program part (not a break).
  Future<ScheduledProgram> tuneIntoPart(Channel ch) async {
    final s = scheduleOf(ch);
    var seg = s.playbackAt(now);
    for (var i = 0; i < 100 && (seg.isBreak || seg.isCommercial || seg.item == null || seg.duration < const Duration(minutes: 1)); i++) {
      seg = s.playbackAt(seg.end);
    }
    now = seg.start.add(const Duration(seconds: 20));
    await tuner.tune(ch);
    await settle();
    return seg;
  }

  test('captions off: channel surfing asks for no subtitles at all', () async {
    client.subtitlesFor = (_) => const [english];
    for (var i = 0; i < 10; i++) {
      await tuner.channelUp();
      await settle();
    }
    expect(player.opens, isNotEmpty);
    expect(client.subtitleRequests, isEmpty);
    expect(player.subtitles, isNull);
  });

  test("captions on: the picture doesn't wait for the track list; the track goes on when it arrives", () async {
    await captionsOn(language: 'spa');
    client.subtitlesFor = (_) => const [english, spanish];
    final hold = client.holdSubtitles = Completer<void>();
    final part = await tuneIntoPart(app.channels.first);
    expect(player.opens, hasLength(1), reason: 'opened without the list');
    expect(player.subtitles, isNull);
    hold.complete();
    await settle();
    expect(client.subtitleRequests, [part.item!.sourceId]);
    expect(player.subtitles, const EmbeddedSubtitle(1, language: 'spa'));
    expect(tuner.shownSubtitle, spanish);
  });

  test('one request per item per session, and a known list goes on with the open', () async {
    await captionsOn();
    client.subtitlesFor = (_) => const [english];
    final ch = app.channels.first;
    final part = await tuneIntoPart(ch);
    await tuner.channelUp();
    await settle();
    await tuner.tune(ch);
    await settle();
    expect(client.subtitleRequests.where((id) => id == part.item!.sourceId), hasLength(1));
    expect(player.openSubtitles.last, const EmbeddedSubtitle(0, language: 'eng'),
        reason: 'the second open knew the list');
  });

  test('an external track loads beside the stream from the server, auth in headers', () async {
    await captionsOn(language: 'fre');
    client.subtitlesFor = (_) => const [english, frenchFile];
    final part = await tuneIntoPart(app.channels.first);
    final side = player.subtitles! as SideLoadedSubtitle;
    final id = part.item!.sourceId;
    expect(side.uri.path, '/Videos/$id/$id/Subtitles/0/0/Stream.srt');
    expect(side.headers['Authorization'], contains('Token="t"'));
    expect(side.uri.queryParameters.keys.map((k) => k.toLowerCase()), isNot(contains('api_key')));
    expect(side.format, 'srt');
  });

  test('converting: a text track loads timed to the join; an image track is burned in', () async {
    await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000, captions: true));
    client.subtitlesFor = (_) => const [english];
    final part = await tuneIntoPart(app.channels.first);
    // Captions came on after the open (the list wasn't known).
    final side = player.subtitles! as SideLoadedSubtitle;
    final join = part.positionAt(now);
    expect(side.uri.path, endsWith('/Subtitles/2/${join.inMicroseconds * 10}/Stream.vtt'));
    expect(player.opens.last.url.queryParameters.containsKey('SubtitleStreamIndex'), isFalse);

    // An image track has to be drawn in by the server: the conversion opens
    // again where it is, burning it.
    client.subtitlesFor = (_) => const [pgs];
    await tuner.channelUp();
    await settle();
    final opens = player.opens.length;
    final burned = player.opens.last.url;
    expect(burned.queryParameters['SubtitleStreamIndex'], '4', reason: 'opened ${player.opens.length} times; $opens');
    expect(burned.queryParameters['SubtitleMethod'], 'Encode');
    expect(player.subtitles, isNull, reason: "it's in the picture");

    // Off: the burn goes, so the conversion opens again without it.
    await tuner.toggleCaptions();
    await settle();
    expect(player.opens.length, opens + 1);
    expect(player.opens.last.url.queryParameters.containsKey('SubtitleStreamIndex'), isFalse);
  });

  test('C / CC: on by the saved language, with the toast naming it; off', () async {
    client.subtitlesFor = (_) => const [english, spanish];
    await app.setPlayback(app.settings.playback.copyWith(captionLanguage: () => 'spa'));
    await tuneIntoPart(app.channels.first);
    expect(await tuner.toggleCaptions(), 'Captions on: Spanish');
    expect(player.subtitles, const EmbeddedSubtitle(1, language: 'spa'));
    expect(app.settings.playback.captions, isTrue);
    expect(await tuner.toggleCaptions(), 'Captions off');
    expect(player.subtitles, isNull);
    expect(app.settings.playback.captionLanguage, 'spa', reason: 'Off keeps the language');
  });

  test('C on a program without subtitles says so', () async {
    await tuneIntoPart(app.channels.first);
    expect(await tuner.toggleCaptions(), 'Captions on: no subtitles for this program');
    expect(player.subtitles, isNull);
  });

  test("the picker's track is saved as the language and carries to the next program", () async {
    client.subtitlesFor = (_) => const [english, spanish];
    await tuneIntoPart(app.channels.first);
    expect(await tuner.loadSubtitleTracks(), const [english, spanish]);
    await tuner.pickSubtitle(spanish);
    expect((app.settings.playback.captions, app.settings.playback.captionLanguage), (true, 'spa'));
    expect(player.subtitles, const EmbeddedSubtitle(1, language: 'spa'));

    // Another channel's program, its Spanish track listed first.
    client.subtitlesFor = (_) => const [
          SubtitleTrack(id: '5', codec: 'subrip', language: 'spa', position: 0),
          SubtitleTrack(id: '6', codec: 'subrip', language: 'eng', position: 1, isDefault: true),
        ];
    await tuner.channelUp();
    await settle();
    expect(player.subtitles, const EmbeddedSubtitle(0, language: 'spa'));

    await tuner.pickSubtitle(null);
    expect((app.settings.playback.captions, app.settings.playback.captionLanguage), (false, 'spa'));
    expect(player.subtitles, isNull);
  });

  test('the next segment is preloaded with its subtitles', () async {
    tuner.preload = true;
    await captionsOn();
    client.subtitlesFor = (_) => const [english];
    final ch = app.channels.first;
    final s = scheduleOf(ch);
    // Near the end of a segment whose next one plays from a file.
    var seg = s.playbackAt(now);
    for (var i = 0;
        i < 100 && (seg.item == null || s.playbackAt(seg.end).item == null || s.playbackAt(seg.end).duration < const Duration(seconds: 10));
        i++) {
      seg = s.playbackAt(seg.end);
    }
    final next = s.playbackAt(seg.end);
    // The next item's tracks known already (it was watched this session).
    now = next.start.add(const Duration(seconds: 2));
    await tuner.tune(ch);
    await settle();
    expect(client.subtitleRequests, contains(next.item!.sourceId));
    now = seg.end.subtract(const Duration(seconds: 20));
    await tuner.retune();
    await settle();
    expect(player.queued, isNotNull);
    expect(player.queuedSubtitles, isNotNull);
  });
}
