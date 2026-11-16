import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../playback/playback_diagnostics.dart';
import '../server/plex/plex_library.dart';
import 'library_index.dart';

/// Builds library indexes in a worker isolate (library-scan-anr D2): a
/// scan's index, a saved index read and re-keyed, and an index re-keyed. On
/// Android the main isolate is the main thread, and a large library on a
/// slow TV would otherwise freeze it past Android's ANR limit.
///
/// Handing the work over must not freeze it either: a message is copied on
/// the isolate that sends it, all at once. So a scan's items go to the
/// worker a chunk at a time, with the main isolate free to draw and take
/// input between chunks; a saved index goes as its file's path, and the
/// worker reads and decodes it. The worker hands the index back with
/// [Isolate.exit], which doesn't copy it. Every build is a static function,
/// so nothing but its plain-data input reaches the worker (never a client,
/// a connection or the app state). The build's diagnostics lines
/// ([LibraryIndex.scanNotes]) are written here, on the main isolate, where
/// [PlaybackDiagnostics] works.
abstract final class IndexBuilder {
  /// Builds in the background (off in widget tests, whose fake clock
  /// doesn't wait for isolates).
  @visibleForTesting
  static bool useIsolate = true;

  /// Items per message to the worker: small enough that copying one takes
  /// a few milliseconds on a slow TV.
  @visibleForTesting
  static int chunk = 1000;

  /// [LibraryIndex.fromJellyfinItems] (Jellyfin and Emby scans).
  static Future<LibraryIndex> jellyfin({
    required List<Map<String, Object?>> seriesItems,
    required List<Map<String, Object?>> episodeItems,
    required List<Map<String, Object?>> movieItems,
    List<Map<String, Object?>> commercialItems = const [],
    List<Map<String, Object?>> songItems = const [],
    List<Map<String, Object?>> musicVideoItems = const [],
    Map<String, List<String>> poolsByItem = const {},
  }) =>
      _noted(_inWorker('jellyfin index', {
        'series': seriesItems,
        'episodes': episodeItems,
        'movies': movieItems,
        'commercials': commercialItems,
        'songs': songItems,
        'musicVideos': musicVideoItems,
        'pools': [for (final e in poolsByItem.entries) [e.key, e.value]],
      }, _buildJellyfin));

  static LibraryIndex _buildJellyfin(Map<String, List<Object?>> l) => LibraryIndex.fromJellyfinItems(
        seriesItems: _maps(l['series']),
        episodeItems: _maps(l['episodes']),
        movieItems: _maps(l['movies']),
        commercialItems: _maps(l['commercials']),
        songItems: _maps(l['songs']),
        musicVideoItems: _maps(l['musicVideos']),
        poolsByItem: _pools(l['pools']),
      );

  /// [libraryIndexFromPlex] (Plex scans).
  static Future<LibraryIndex> plex({
    List<Map<String, Object?>> shows = const [],
    List<Map<String, Object?>> episodes = const [],
    List<Map<String, Object?>> movies = const [],
    List<Map<String, Object?>> commercials = const [],
    List<Map<String, Object?>> tracks = const [],
    List<Map<String, Object?>> musicVideos = const [],
    Map<String, List<String>> poolsByItem = const {},
  }) =>
      _noted(_inWorker('plex index', {
        'shows': shows,
        'episodes': episodes,
        'movies': movies,
        'commercials': commercials,
        'tracks': tracks,
        'musicVideos': musicVideos,
        'pools': [for (final e in poolsByItem.entries) [e.key, e.value]],
      }, _buildPlex));

  static LibraryIndex _buildPlex(Map<String, List<Object?>> l) => libraryIndexFromPlex(
        shows: _maps(l['shows']),
        episodes: _maps(l['episodes']),
        movies: _maps(l['movies']),
        commercials: _maps(l['commercials']),
        tracks: _maps(l['tracks']),
        musicVideos: _maps(l['musicVideos']),
        poolsByItem: _pools(l['pools']),
      );

  /// The index saved at [path] ([LibraryIndex.fromJson]), re-keyed when
  /// [rekey]; null when the file is missing or isn't an index. Read and
  /// decoded in the worker.
  static Future<LibraryIndex?> saved(String path, {bool rekey = false}) async {
    LibraryIndex? read() {
      final file = File(path);
      if (!file.existsSync()) return null;
      final Object? json;
      try {
        json = jsonDecode(file.readAsStringSync());
      } on FormatException {
        // A corrupt file is treated as missing, as AppStorage.readJson does.
        return null;
      }
      if (json is! Map<String, Object?>) return null;
      final index = LibraryIndex.fromJson(json);
      return rekey ? index.rekeyed() : index;
    }

    final index = useIsolate ? await Isolate.run(read, debugName: 'saved index') : read();
    if (index != null) _note(index.scanNotes);
    return index;
  }

  /// [index] re-keyed ([LibraryIndex.rekeyed]): only its shows and
  /// episodes go to the worker.
  static Future<LibraryIndex> rekeyed(LibraryIndex index) async {
    final shows = await _inWorker('rekeyed index', {'series': index.series, 'episodes': index.episodes}, _rekey);
    _note(shows.notes);
    return index.withShows(shows.series, shows.episodes, scanNotes: shows.notes);
  }

  static ({List<SeriesEntry> series, List<MediaEntry> episodes, List<String> notes}) _rekey(
          Map<String, List<Object?>> l) =>
      LibraryIndex.rekeyShows(l['series']!.cast<SeriesEntry>(), l['episodes']!.cast<MediaEntry>());

  static List<Map<String, Object?>> _maps(List<Object?>? list) => (list ?? const []).cast<Map<String, Object?>>();

  static Map<String, List<String>> _pools(List<Object?>? list) => {
        for (final e in (list ?? const []).cast<List<Object?>>()) e[0]! as String: (e[1]! as List).cast<String>(),
      };

  static Future<LibraryIndex> _noted(Future<LibraryIndex> build) async {
    final index = await build;
    _note(index.scanNotes);
    return index;
  }

  static void _note(List<String> notes) {
    for (final note in notes) {
      PlaybackDiagnostics.note('SCAN', note);
    }
  }

  /// Runs [build] on [lists] in a worker isolate, sending the lists over a
  /// [chunk] at a time and letting the event loop run between chunks.
  static Future<R> _inWorker<R>(String name, Map<String, List<Object?>> lists, R Function(Map<String, List<Object?>>) build) async {
    if (!useIsolate) return build(lists);
    final port = ReceivePort(name);
    final worker = Completer<SendPort>();
    final result = Completer<R>();
    void fail(Object error) {
      if (!worker.isCompleted) worker.completeError(error);
      if (!result.isCompleted) result.completeError(error);
    }

    port.listen((message) {
      switch (message) {
        case SendPort to:
          worker.complete(to);
        case ('result', final value):
          result.complete(value as R);
        case [final error, final stack]:
          // An error in the worker (onError): its text and stack.
          fail(RemoteError('$error', '$stack'));
        case null:
          // The worker ended (onExit) without a result.
          fail(StateError('The $name worker stopped without a result.'));
      }
    });
    final clock = Stopwatch()..start();
    var items = 0, chunks = 0;
    var slowest = Duration.zero;
    try {
      await Isolate.spawn(_work<R>, (port.sendPort, build),
          debugName: name, onError: port.sendPort, onExit: port.sendPort, errorsAreFatal: true);
      final to = await worker.future;
      for (final MapEntry(:key, :value) in lists.entries) {
        for (var i = 0; i < value.length; i += chunk) {
          final sent = clock.elapsed;
          final part = value.sublist(i, min(value.length, i + chunk));
          to.send((key, part));
          if (clock.elapsed - sent > slowest) slowest = clock.elapsed - sent;
          items += part.length;
          chunks++;
          // Frames and input between chunks.
          await Future<void>.delayed(Duration.zero);
        }
      }
      to.send('done');
      final handedOver = clock.elapsed;
      final value = await result.future;
      PlaybackDiagnostics.note('SCAN', '$name: $items items in $chunks chunks handed over in ${handedOver.inMilliseconds} ms '
          '(slowest chunk ${slowest.inMilliseconds} ms), built ${(clock.elapsed - handedOver).inMilliseconds} ms later');
      return value;
    } finally {
      port.close();
    }
  }

  /// The worker: collects the lists, builds, and hands the result back
  /// without copying it.
  static Future<void> _work<R>((SendPort, R Function(Map<String, List<Object?>>)) start) async {
    final (reply, build) = start;
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    final lists = <String, List<Object?>>{};
    await for (final message in inbox) {
      if (message case (String key, List<Object?> part)) {
        (lists[key] ??= []).addAll(part);
      } else {
        break;
      }
    }
    inbox.close();
    Isolate.exit(reply, ('result', build(lists)));
  }
}
