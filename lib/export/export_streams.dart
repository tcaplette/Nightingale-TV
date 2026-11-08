import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../channels/channel.dart';
import '../commercials/analysis/stream_proxy.dart';
import 'broadcast_art.dart';
import 'card_chunks.dart';
import 'channel_stream.dart';
import 'encode_args.dart';
import 'export_settings.dart';
import 'lineup_server.dart';

/// Everything a stream needs that the export service decides.
class StreamPolicy {
  const StreamPolicy({required this.limit, required this.quality, required this.encoder});

  /// Streams at once, across every profile.
  final int Function() limit;
  final ExportQuality Function() quality;
  final Future<VideoEncoder> Function() encoder;
}

/// The channels being streamed (design D7): one stream per channel of a
/// profile, shared by everyone watching it, within the stream limit.
class ExportStreams implements ChannelStreamer {
  ExportStreams({
    required this.policy,
    required this.chunks,
    required this.streaming,
    this.start = Process.start,
    this.clock = DateTime.now,
    this.proxyFor,
  });

  final StreamPolicy policy;
  final CardChunks chunks;

  /// True while any stream runs (the analyzer holds off).
  final ValueNotifier<bool> streaming;
  final Future<Process> Function(String executable, List<String> arguments) start;
  final DateTime Function() clock;

  /// Builds a profile's loopback proxy (tests); by default one reading the
  /// static stream with the profile's sign-in.
  final LoopbackStreamProxy Function(AppState app)? proxyFor;

  /// How long a stream outlives its last viewer.
  static Duration linger = const Duration(seconds: 15);

  /// A viewer this far behind is dropped.
  static const maxBehind = Duration(seconds: 10);

  final _sessions = <(String, String), _Session>{};
  final _proxies = <String, _Proxy>{};

  /// Cards encoded ahead, so a stream's first bytes don't wait on drawing
  /// and encoding its tuning card; and the profiles waiting for theirs.
  final _warmed = <String>{};
  final _toWarm = <AppState>{};
  bool _warming = false;
  Future<void>? _warmRun;

  /// Bumped by [stopAll] for everything: a warm run that started before
  /// stops at its next card.
  int _warmEpoch = 0;

  /// Encodes the black card and [app]'s channels' tuning cards ahead, one
  /// at a time, skipping those done before.
  void warm(AppState app) {
    _toWarm.add(app);
    if (!_warming) _warmRun = _warmQueued();
  }

  Future<void> _warmQueued() async {
    _warming = true;
    final epoch = _warmEpoch;
    try {
      while (_toWarm.isNotEmpty && epoch == _warmEpoch) {
        final app = _toWarm.first;
        _toWarm.remove(app);
        final quality = policy.quality();
        final encoder = await policy.encoder();
        for (final card in <BroadcastCard>[const BlackCard(), for (final c in [...app.channels]) if (!c.isLive) TuningCardSpec(c)]) {
          if (epoch != _warmEpoch) return;
          // Tried once: a card that can't be made is made when it plays.
          if (!_warmed.add('${card.key}|${quality.label}|${encoder.codec}')) continue;
          try {
            await chunks.chunkFor(card, app, quality, encoder);
          } on Object catch (e) {
            debugPrint('Live TV export: couldn\'t prepare a card ahead: $e');
          }
        }
      }
    } finally {
      _warming = false;
    }
  }

  /// Startup times of each profile's sources, newest last.
  final _startups = <String, List<Duration>>{};
  final _silent = <String>{};

  /// Called when streams start or stop (for the screen).
  void Function()? onChange;

  /// Told when a stream starts or stops (for the playback diagnostics log).
  void Function(String event)? onEvent;

  /// Running streams: profile id and channel.
  List<({String profileId, Channel channel, int viewers})> get running => [
        for (final e in _sessions.entries) (profileId: e.key.$1, channel: e.value.channel, viewers: e.value.clients.length),
      ];

  /// Whether a stream of [key] can be had now (design D1): one runs, one
  /// can start under the limit (a stream lingering with nobody watching
  /// counts as giving way), or every tuner is busy. GET and HEAD both ask
  /// this, so they can't disagree.
  _Admission _admission((String, String) key) {
    if (_sessions.containsKey(key)) return _Admission.join;
    if (_sessions.length < policy.limit()) return _Admission.start;
    if (_sessions.values.any((s) => s.clients.isEmpty)) return _Admission.start;
    return _Admission.full;
  }

  @override
  Future<void> serve(HttpRequest request, LineupServer server, AppState app, Channel channel) async {
    final response = request.response;
    final key = (server.profileId, channel.id);
    final admission = _admission(key);
    if (admission == _Admission.full) {
      response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.set('X-HDHomeRun-Error', '805 All Tuners In Use');
      await response.close();
      return;
    }
    if (request.method == 'HEAD') {
      // A probe: never starts, joins, keeps or makes room for a stream.
      response.headers.contentType = ContentType('video', 'mp2t');
      response.headers.set('Cache-Control', 'no-store');
      await response.close();
      return;
    }
    var session = _sessions[key];
    if (session == null) {
      if (_sessions.length >= policy.limit()) {
        // A stream lingering with nobody watching gives way, so changing
        // channels on a one-tuner setup works at once.
        final idle = _sessions.values.where((s) => s.clients.isEmpty).firstOrNull;
        if (idle != null) await idle.stop();
      }
      if (_sessions.length >= policy.limit()) {
        response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.set('X-HDHomeRun-Error', '805 All Tuners In Use');
        await response.close();
        return;
      }
      session = _Session(this, key, channel);
      _sessions[key] = session;
      _changed();
      try {
        await session.open(app, server.profileId);
      } on Object catch (e) {
        debugPrint('Live TV export: couldn\'t start channel ${channel.number}: $e');
        await session.stop();
        response.statusCode = HttpStatus.serviceUnavailable;
        await response.close();
        return;
      }
    }
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.set('Cache-Control', 'no-store');
    // A plain stream until the connection closes, as tuners send it, on
    // the raw socket: an HttpResponse keeps accepting writes after the
    // viewer has gone, so a hang-up would never be noticed.
    response.headers.chunkedTransferEncoding = false;
    response.contentLength = -1;
    response.persistentConnection = false;
    final socket = await response.detachSocket();
    await session.attach(socket, socket);
  }

  /// Ends [profileId]'s streams (its export was turned off), or all.
  Future<void> stopAll({String? profileId}) async {
    // At once: each may wait up to 2 s for its ffmpeg to go.
    await Future.wait([
      for (final s in [..._sessions.values])
        if (profileId == null || s.key.$1 == profileId) s.stop(),
    ]);
    if (profileId == null) {
      // Cards still being made ahead stop too (the one in hand finishes).
      _warmEpoch++;
      _toWarm.clear();
      await _warmRun;
      for (final p in [..._proxies.values]) {
        await p.proxy.close();
      }
      _proxies.clear();
    }
  }

  /// Ends the stream of a channel that's no longer in the lineup.
  Future<void> stopChannel(String profileId, String channelId) async => _sessions[(profileId, channelId)]?.stop();

  void _ended(_Session s) {
    if (identical(_sessions[s.key], s)) _sessions.remove(s.key);
    _changed();
  }

  void _changed() {
    streaming.value = _sessions.isNotEmpty;
    onChange?.call();
  }

  Duration _expectedStartup(String profileId) {
    final list = _startups[profileId];
    if (list == null || list.isEmpty) return const Duration(seconds: 3);
    final sorted = [...list]..sort();
    final median = sorted[sorted.length ~/ 2];
    return median > const Duration(seconds: 15) ? const Duration(seconds: 15) : median;
  }

  void _recordStartup(String profileId, Duration d) {
    final list = _startups.putIfAbsent(profileId, () => []);
    list.add(d);
    if (list.length > 5) list.removeAt(0);
  }

  Future<_Proxy> _proxyOf(String profileId, AppState app) async {
    final existing = _proxies[profileId];
    if (existing != null && identical(existing.app, app)) return existing;
    if (existing != null) await existing.proxy.close();
    final proxy = proxyFor?.call(app) ??
        LoopbackStreamProxy(
            // From the copy that plays (multi-server); the one server's
            // client otherwise.
            upstream: (id) => app.streamOf(id).url,
            headers: () => app.client!.authHeaders,
            headersFor: (id) => app.streamOf(id).headers);
    await proxy.start();
    return _proxies[profileId] = _Proxy(app, proxy);
  }
}

enum _Admission { start, join, full }

class _Proxy {
  _Proxy(this.app, this.proxy);
  final AppState app;
  final LoopbackStreamProxy proxy;
  final users = <String, int>{};

  Future<Uri> open(String sourceId) async {
    final n = users[sourceId] ?? 0;
    users[sourceId] = n + 1;
    if (n == 0) await proxy.allow(sourceId);
    return proxy.urlFor(sourceId);
  }

  void close(String sourceId) {
    final n = (users[sourceId] ?? 1) - 1;
    if (n > 0) {
      users[sourceId] = n;
      return;
    }
    users.remove(sourceId);
    unawaited(proxy.disallow(sourceId));
  }
}

/// One running stream and the clients watching it.
class _Session {
  _Session(this.owner, this.key, this.channel);

  final ExportStreams owner;
  final (String, String) key;
  final Channel channel;
  ChannelStream? stream;
  final clients = <ViewerQueue>[];
  Timer? _linger;
  bool _stopped = false;
  late int _maxQueued;

  // What a new client needs first: the tables, then video from a keyframe.
  final _carry = BytesBuilder(copy: false);
  Uint8List? _pat;
  Uint8List? _pmt;
  int? _pmtPid;
  int? _videoPid;
  final _sinceKeyframe = BytesBuilder(copy: false);
  static const _maxSinceKeyframe = 8 << 20;

  Future<void> open(AppState app, String profileId) async {
    final policy = owner.policy;
    final quality = policy.quality();
    final encoder = await policy.encoder();
    _maxQueued = quality.mbps * 1000000 ~/ 8 * ExportStreams.maxBehind.inSeconds * 3 ~/ 2;
    final proxy = await owner._proxyOf(profileId, app);
    final ctx = StreamContext(
      channel: channel,
      schedule: () => app.channels.any((c) => c.id == channel.id) ? app.scheduleFor(channel) : null,
      card: (c) => owner.chunks.chunkFor(c, app, quality, streamEncoder()),
      openSource: proxy.open,
      closeSource: proxy.close,
      quality: quality,
      encoder: encoder,
      start: owner.start,
      clock: owner.clock,
      expectedStartup: () => owner._expectedStartup(profileId),
      recordStartup: (d) => owner._recordStartup(profileId, d),
      isSilent: owner._silent.contains,
      markSilent: owner._silent.add,
      logoMode: () => app.logoModeFor(app.channelById(channel.id) ?? channel),
      logoPng: () async => (await owner.chunks.art.logoFile(app, app.channelById(channel.id) ?? channel))?.path,
      songCard: (segment) async {
        final schedule = app.scheduleFor(channel);
        final slot = schedule?.programAt(segment.start) ?? segment;
        final card = await owner.chunks.art
            .nowPlayingPng(app, app.channelById(channel.id) ?? channel, slot, schedule?.next(slot), quality.height);
        return card.path;
      },
      log: (line) => owner.onEvent?.call('channel ${channel.number}: $line'),
    );
    final s = stream = ChannelStream(ctx);
    await s.start();
    s.output.listen(_onData, onDone: stop, onError: (Object _) => stop());
    unawaited(s.done.then((_) => stop()));
    final started = 'channel ${channel.number} started (${encoder.codec}, ${quality.label})';
    debugPrint('Live TV export: $started.');
    owner.onEvent?.call(started);
  }

  VideoEncoder streamEncoder() => stream?.ctx.encoder ?? VideoEncoder.x264;

  /// Streams to a viewer until they hang up ([incoming] ends).
  Future<void> attach(IOSink sink, Stream<List<int>> incoming) async {
    _linger?.cancel();
    _linger = null;
    final client = ViewerQueue(sink, _maxQueued, incoming: incoming);
    clients.add(client);
    owner._changed();
    final start = BytesBuilder(copy: false);
    if (_pat case final pat?) start.add(pat);
    if (_pmt case final pmt?) start.add(pmt);
    start.add(_sinceKeyframe.toBytes());
    client.send(start.takeBytes());
    await client.done;
    clients.remove(client);
    owner._changed();
    _maybeLinger();
  }

  void _maybeLinger() {
    if (clients.isNotEmpty || _stopped) return;
    _linger?.cancel();
    _linger = Timer(ExportStreams.linger, () {
      if (clients.isEmpty) unawaited(stop());
    });
  }

  void _onData(List<int> data) {
    _carry.add(data);
    final all = _carry.takeBytes();
    final whole = all.length - all.length % 188;
    if (whole < all.length) _carry.add(Uint8List.sublistView(all, whole));
    if (whole == 0) return;
    final packets = Uint8List.sublistView(all, 0, whole);
    for (var o = 0; o < whole; o += 188) {
      _track(Uint8List.sublistView(packets, o, o + 188));
    }
    for (final c in [...clients]) {
      c.send(packets);
    }
  }

  /// Keeps the tables, and the stream since the last video keyframe.
  void _track(Uint8List p) {
    if (p[0] != 0x47) return;
    final pid = ((p[1] & 0x1F) << 8) | p[2];
    final start = p[1] & 0x40 != 0;
    final afc = (p[3] >> 4) & 3;
    var payload = 4;
    if (afc & 2 != 0) payload += 1 + p[4];
    if (pid == 0 && start && payload + 13 < 188) {
      _pat = Uint8List.fromList(p);
      final s = payload + 1 + p[payload]; // pointer field
      if (s + 12 <= 188) _pmtPid = ((p[s + 10] & 0x1F) << 8) | p[s + 11];
    } else if (pid == _pmtPid && start) {
      _pmt = Uint8List.fromList(p);
      _videoPid ??= _videoPidIn(p, payload);
    }
    final keyframe = pid == _videoPid && start && afc & 2 != 0 && p[4] > 0 && p[5] & 0x40 != 0;
    if (keyframe || _sinceKeyframe.length > _maxSinceKeyframe) _sinceKeyframe.clear();
    if (_videoPid != null && (keyframe || _sinceKeyframe.length > 0)) _sinceKeyframe.add(p);
  }

  /// The H.264 stream's PID in a PMT packet.
  static int? _videoPidIn(Uint8List p, int payload) {
    final s = payload + 1 + p[payload];
    if (s + 12 > 188) return null;
    final sectionEnd = s + 3 + (((p[s + 1] & 0x0F) << 8) | p[s + 2]) - 4;
    final infoLength = ((p[s + 10] & 0x0F) << 8) | p[s + 11];
    for (var i = s + 12 + infoLength; i + 5 <= sectionEnd && i + 5 <= 188;) {
      final type = p[i];
      final pid = ((p[i + 1] & 0x1F) << 8) | p[i + 2];
      if (type == 0x1B) return pid;
      i += 5 + (((p[i + 3] & 0x0F) << 8) | p[i + 4]);
    }
    return null;
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _linger?.cancel();
    for (final c in [...clients]) {
      c.end();
    }
    await stream?.stop();
    debugPrint('Live TV export: channel ${channel.number} stopped.');
    owner.onEvent?.call('channel ${channel.number} stopped');
    owner._ended(this);
  }
}

/// One viewer's connection, with its own queue so a slow one can't hold up
/// the rest: past [maxQueued] bytes behind, it's disconnected.
@visibleForTesting
class ViewerQueue {
  /// [incoming] is what the viewer sends; when it ends, they've hung up.
  ViewerQueue(this.response, this.maxQueued, {Stream<List<int>>? incoming}) {
    unawaited(response.done.then((_) => end(), onError: (Object _) => end()));
    _incoming = incoming?.listen((_) {}, onDone: end, onError: (Object _) => end(), cancelOnError: true);
  }

  StreamSubscription<List<int>>? _incoming;

  final IOSink response;
  final int maxQueued;
  final _queue = Queue<Uint8List>();
  var _queued = 0;
  bool _pumping = false;
  bool _ended = false;
  final _done = Completer<void>();

  Future<void> get done => _done.future;

  void send(Uint8List data) {
    if (_ended || data.isEmpty) return;
    _queue.add(data);
    _queued += data.length;
    if (_queued > maxQueued) {
      debugPrint('Live TV export: a viewer fell too far behind and was disconnected.');
      end();
      return;
    }
    if (!_pumping) unawaited(_pump());
  }

  Future<void> _pump() async {
    _pumping = true;
    try {
      while (_queue.isNotEmpty && !_ended) {
        final data = _queue.removeFirst();
        response.add(data);
        await response.flush();
        _queued -= data.length;
      }
    } on Object {
      end();
    } finally {
      _pumping = false;
    }
  }

  void end() {
    if (_ended) return;
    _ended = true;
    _queue.clear();
    unawaited(_incoming?.cancel());
    final r = response;
    if (r is Socket) {
      r.destroy();
    } else {
      unawaited(r.close().then((_) {}, onError: (Object _) {}));
    }
    if (!_done.isCompleted) _done.complete();
  }
}
