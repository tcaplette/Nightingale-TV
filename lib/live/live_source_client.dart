import 'dart:io';

import '../server/live_tv.dart';
import '../server/media_server.dart';
import 'guide_match.dart';
import 'live_data.dart';
import 'live_download.dart';
import 'live_source.dart';
import 'live_source_files.dart';
import 'm3u_parser.dart';
import 'xmltv_parser.dart';
import '../l10n/tr.dart';

/// A refreshed guide: programmes by channel key, the guide's own channel
/// list (M3U), and which channels have guide data.
class LiveGuide {
  const LiveGuide({this.programmes = const {}, this.index, this.withGuide = const {}});

  final Map<String, List<LiveProgramme>> programmes;
  final List<GuideChannel>? index;

  /// Keys of every channel the guide has data for, chosen or not.
  final Set<String> withGuide;
}

/// The one thing the lineup and the tuner talk to for a source
/// (live-tv-sources D4).
abstract interface class LiveSourceClient {
  LiveSource get source;

  /// The source's channels now. Throws [LiveSourceException].
  Future<List<LiveChannelInfo>> fetchChannels();

  /// Guide data for the [chosen] keys of [channels] over [from, to).
  /// Throws [LiveSourceException].
  Future<LiveGuide> fetchGuide(List<LiveChannelInfo> channels, Set<String> chosen, DateTime from, DateTime to);

  /// Opens [channel]'s stream. Throws [LiveTvException].
  Future<LiveStream> open(LiveChannelInfo channel,
      {int? maxBitrate, bool forceTranscode = false, Map<String, Object?>? profile});

  /// Ends [stream] at the source (server Live TV closes it there; an M3U
  /// stream ends when the player stops).
  Future<void> close(LiveStream stream);

  /// Why [channel]'s stream failed to open in the player, when the player
  /// doesn't say (mpv only says it failed): null when it can't tell.
  Future<LiveFailure?> causeOfFailure(LiveChannelInfo channel);

  /// Server Live TV reports playing, progress and stopped; M3U doesn't.
  bool get reports;
  Future<void> reportStart(LiveStream stream);
  Future<void> reportProgress(LiveStream stream, Duration position);
  Future<void> reportStopped(LiveStream stream, Duration position);

  /// Keeps [stream] open without reporting it (reports off).
  Future<void> keepAlive(LiveStream stream);

  /// Its reports are needed to keep a stream open, so they're sent with
  /// "Update watch status" off too (see [LiveTv.needsReports]).
  bool get needsReports;
}

/// The profile's server's Live TV.
class ServerLiveSource implements LiveSourceClient {
  ServerLiveSource(this.source, this.tv);

  @override
  final LiveSource source;
  final LiveTv tv;

  /// Guide requests cover this much time each (design D6).
  static const guideWindow = Duration(hours: 6);

  @override
  Future<List<LiveChannelInfo>> fetchChannels() async {
    try {
      return await tv.channels();
    } on ServerException catch (e) {
      throw LiveSourceException(tr.couldntReach(source.name), detail: e.message);
    }
  }

  @override
  Future<LiveGuide> fetchGuide(List<LiveChannelInfo> channels, Set<String> chosen, DateTime from, DateTime to) async {
    final keys = [for (final c in channels) if (chosen.contains(c.key)) c.key];
    final out = <String, List<LiveProgramme>>{};
    try {
      for (var t = from; t.isBefore(to); t = t.add(guideWindow)) {
        final end = t.add(guideWindow).isAfter(to) ? to : t.add(guideWindow);
        final part = await tv.programs(keys, t, end);
        for (final e in part.entries) {
          out.putIfAbsent(e.key, () => []).addAll(e.value);
        }
      }
    } on ServerException catch (e) {
      throw LiveSourceException(tr.couldntReach(source.name), detail: e.message);
    }
    final programmes = {for (final e in out.entries) e.key: tidyProgrammes(e.value, from)};
    return LiveGuide(programmes: programmes, withGuide: {for (final e in programmes.entries) if (e.value.isNotEmpty) e.key});
  }

  @override
  Future<LiveStream> open(LiveChannelInfo channel,
          {int? maxBitrate, bool forceTranscode = false, Map<String, Object?>? profile}) =>
      tv.open(channel.key, maxBitrate: maxBitrate, forceTranscode: forceTranscode, profile: profile);

  @override
  Future<void> close(LiveStream stream) => tv.close(stream);

  @override
  Future<LiveFailure?> causeOfFailure(LiveChannelInfo channel) async => null;

  @override
  bool get reports => true;
  @override
  Future<void> reportStart(LiveStream stream) => tv.reportStart(stream);
  @override
  Future<void> reportProgress(LiveStream stream, Duration position) => tv.reportProgress(stream, position);
  @override
  Future<void> reportStopped(LiveStream stream, Duration position) => tv.reportStopped(stream, position);
  @override
  Future<void> keepAlive(LiveStream stream) => tv.keepAlive(stream);
  @override
  bool get needsReports => tv.needsReports;
}

/// An M3U playlist with an XMLTV guide.
class M3uSource implements LiveSourceClient {
  M3uSource(this.source, {required this.store, required this.downloader, required this.tempDir});

  @override
  final LiveSource source;
  final LiveSourceStore store;
  final LiveDownloader downloader;
  final Directory tempDir;

  /// The guide is read this far ahead.
  static const guideHorizon = Duration(hours: 48);

  /// Reads the playlist (URL or copied file). When the source has no guide
  /// of its own, the header's first one becomes its guide.
  @override
  Future<List<LiveChannelInfo>> fetchChannels() async {
    final playlist = await readPlaylist(source, store: store, downloader: downloader);
    if ((source.guideUrl == null && source.guideFile == null) || source.guideFromPlaylist) {
      final header = playlist.guideUrls.firstOrNull;
      source.guideUrl = header;
      source.guideFromPlaylist = header != null;
    }
    return playlist.channels;
  }

  /// [source]'s playlist, read. Throws [LiveSourceException] with what Add
  /// source shows.
  static Future<M3uPlaylist> readPlaylist(LiveSource source,
      {required LiveSourceStore store, required LiveDownloader downloader}) async {
    final String text;
    if (source.playlistFile case final name?) {
      try {
        text = await store.fileFor(name).readAsString();
      } on FileSystemException {
        throw LiveSourceException(tr.couldntReadThePlaylist);
      } on FormatException {
        throw LiveSourceException(M3uException.notM3u.message);
      }
    } else if (source.playlistUrl case final url?) {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.hasScheme) throw LiveSourceException(tr.couldntReachThePlaylist);
      text = await downloader.text(uri);
    } else {
      throw LiveSourceException(tr.theSourceHas);
    }
    try {
      return await parseM3uInBackground(text);
    } on M3uException catch (e) {
      throw LiveSourceException(e.message);
    }
  }

  @override
  Future<LiveGuide> fetchGuide(List<LiveChannelInfo> channels, Set<String> chosen, DateTime from, DateTime to) async {
    File? file;
    var temp = false;
    if (source.guideFile case final name?) {
      file = store.fileFor(name);
    } else if (source.guideUrl case final url?) {
      final uri = Uri.tryParse(url.trim());
      if (uri == null) throw LiveSourceException(tr.couldntReachTheGuide);
      await tempDir.create(recursive: true);
      file = File('${tempDir.path}/guide-${source.id}-${DateTime.now().microsecondsSinceEpoch}.xml');
      temp = true;
      await downloader.toFile(uri, file);
    }
    if (file == null) return const LiveGuide();
    try {
      final wanted = <GuideWant>[
        for (final c in channels)
          if (chosen.contains(c.key)) (key: c.key, tvgId: c.guideId, tvgName: c.tvgName, name: c.name),
      ];
      final result = await parseXmltvFile(file.path, wanted, now: from, horizon: to.difference(from));
      final matcher = GuideMatcher(result.channels);
      return LiveGuide(
        programmes: result.programmes,
        index: result.channels,
        withGuide: {for (final c in channels) if (matcher.matchChannel(c) != null) c.key},
      );
    } on XmltvException catch (e) {
      throw LiveSourceException(e.message);
    } on FileSystemException {
      throw LiveSourceException(tr.couldntReadThe);
    } finally {
      if (temp && await file.exists()) await file.delete();
    }
  }

  @override
  Future<LiveStream> open(LiveChannelInfo channel,
      {int? maxBitrate, bool forceTranscode = false, Map<String, Object?>? profile}) async {
    final url = Uri.tryParse(channel.url ?? '');
    if (url == null) throw LiveTvException(LiveFailure.other, tr.theChannelHas);
    return LiveStream(channelId: channel.key, uri: url, headers: channel.headers);
  }

  @override
  Future<void> close(LiveStream stream) async => stream.closed = true;

  /// Asks the provider once for the stream, with its headers, and lets go
  /// at once: its answer names the cause (live-playback "Live stand-by
  /// messages").
  @override
  Future<LiveFailure?> causeOfFailure(LiveChannelInfo channel) async {
    final url = Uri.tryParse(channel.url ?? '');
    if (url == null || (url.scheme != 'http' && url.scheme != 'https')) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(url).timeout(const Duration(seconds: 5));
      channel.headers.forEach(request.headers.set);
      final response = await request.close().timeout(const Duration(seconds: 5));
      final status = response.statusCode;
      (await response.detachSocket()).destroy();
      if (const {403, 458, 509}.contains(status) || status == 429) return LiveFailure.providerRefused;
      if (status >= 500) return LiveFailure.unreachable;
      return null;
    } on Object {
      return LiveFailure.unreachable;
    } finally {
      client.close(force: true);
    }
  }

  @override
  bool get reports => false;
  @override
  Future<void> reportStart(LiveStream stream) async {}
  @override
  Future<void> reportProgress(LiveStream stream, Duration position) async {}
  @override
  Future<void> reportStopped(LiveStream stream, Duration position) async {}
  @override
  Future<void> keepAlive(LiveStream stream) async {}
  @override
  bool get needsReports => false;
}
