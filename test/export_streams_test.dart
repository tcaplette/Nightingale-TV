import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';
import 'package:nightingale_tv/export/broadcast_art.dart';
import 'package:nightingale_tv/export/card_chunks.dart';
import 'package:nightingale_tv/export/encode_args.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/export_streams.dart';
import 'package:nightingale_tv/export/lineup_server.dart';

import 'fixtures.dart';

Uint8List _packet(int pid, List<int> payload, {bool start = true, bool keyframe = false, int? pts}) {
  final b = Uint8List(188)..fillRange(0, 188, 0xFF);
  b[0] = 0x47;
  b[1] = (start ? 0x40 : 0) | (pid >> 8);
  b[2] = pid & 0xFF;
  var p = 4;
  if (keyframe) {
    b[3] = 0x30;
    b[4] = 1;
    b[5] = 0x40;
    p = 6;
  } else {
    b[3] = 0x10;
  }
  if (pts != null) {
    final v = pts % (1 << 33);
    payload = [
      0, 0, 1, pid == 0x100 ? 0xE0 : 0xC0, 0, 0, 0x80, 0x80, 5,
      0x21 | (((v >> 30) & 7) << 1), (v >> 22) & 0xFF, (((v >> 15) & 0x7F) << 1) | 1, (v >> 7) & 0xFF, ((v & 0x7F) << 1) | 1,
    ];
  }
  b.setAll(p, payload);
  return b;
}

final _pat = _packet(0, [0, 0x00, 0xB0, 0x0D, 0x00, 0x01, 0xC1, 0x00, 0x00, 0x00, 0x01, 0xF0, 0x00, 0, 0, 0, 0]);
final _pmt = _packet(0x1000, [
  0, 0x02, 0xB0, 23, 0x00, 0x01, 0xC1, 0x00, 0x00, 0xE1, 0x00, 0xF0, 0x00, //
  0x1B, 0xE1, 0x00, 0xF0, 0x00, 0x0F, 0xE1, 0x01, 0xF0, 0x00, 0, 0, 0, 0,
]);

/// A second of stream: tables, then 30 frames, the first a keyframe.
Uint8List _second() => Uint8List.fromList([
      ..._pat,
      ..._pmt,
      for (var i = 0; i < 30; i++) ...[
        ..._packet(0x100, const [], keyframe: i == 0, pts: 126000 + i * 3003),
        ..._packet(0x101, const [], pts: 126000 + i * 3003),
      ],
    ]);

class _Chunks extends CardChunks {
  _Chunks(Directory dir) : super(BroadcastArt(dir));
  @override
  Future<Uint8List> chunkFor(BroadcastCard card, AppState app, ExportQuality quality, VideoEncoder encoder) async =>
      _second();
}

/// Echoes what it's given, paced like -re (a frame per 1/30 s).
class _EchoMuxer implements StreamConsumer<List<int>> {
  final out = StreamController<List<int>>();

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      out.add(data);
      var frames = 0;
      for (var o = 0; o + 188 <= data.length; o += 188) {
        if (((data[o + 1] & 0x1F) << 8 | data[o + 2]) == 0x100 && data[o + 1] & 0x40 != 0) frames++;
      }
      await Future<void>.delayed(Duration(milliseconds: frames * 33));
    }
  }

  @override
  Future<void> close() async => out.close();
}

class _Process implements Process {
  _Process(this.arguments, {_EchoMuxer? muxer})
      : _muxer = muxer,
        stdin = IOSink(muxer ?? _Sink());

  final List<String> arguments;
  final _EchoMuxer? _muxer;
  final _out = StreamController<List<int>>();
  final err = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;

  @override
  final IOSink stdin;
  @override
  Stream<List<int>> get stdout => _muxer?.out.stream ?? _out.stream;
  @override
  Stream<List<int>> get stderr => err.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 1;

  void finish(int code) {
    if (_exit.isCompleted) return;
    if (_muxer == null) unawaited(_out.close());
    unawaited(err.close());
    _exit.complete(code);
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (_muxer != null) unawaited(_muxer.out.close());
    finish(-15);
    return true;
  }
}

class _Sink implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<void> close() async {}
}

/// An IOSink that never finishes a flush: a viewer that stopped reading.
class _StuckSink implements IOSink {
  final added = <List<int>>[];
  final _done = Completer<void>();
  bool closed = false;
  @override
  void add(List<int> data) => added.add(data);
  @override
  Future<void> flush() => Completer<void>().future;
  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FastSink extends _StuckSink {
  @override
  Future<void> flush() async {}
}

void main() {
  late Directory dir;
  late AppState app;
  late ExportStreams streams;
  late List<LineupServer> servers;
  final muxers = <_Process>[];
  final encoders = <_Process>[];
  var limit = 2;
  final streaming = ValueNotifier(false);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_streams');
    app = await signedInApp(
        dir,
        fakeLibrary(shows: {'Alpha': 10, 'Beta': 10}, movies: 6));
    expect(app.channels.length, greaterThan(1));
    muxers.clear();
    encoders.clear();
    limit = 2;
    ExportStreams.linger = const Duration(milliseconds: 300);
    streams = ExportStreams(
      policy: StreamPolicy(
          limit: () => limit, quality: () => ExportQuality.p720, encoder: () async => VideoEncoder.x264),
      chunks: _Chunks(dir),
      streaming: streaming,
      proxyFor: (app) => LoopbackStreamProxy(
          upstream: (id) => Uri.parse('http://jellyfin.invalid/$id'),
          headers: () => const {},
          httpClient: () => MockClient((_) async => http.Response('', 404))),
      start: (exe, args) async {
        if (exe == 'ffmpeg') {
          final m = _Process(args, muxer: _EchoMuxer());
          muxers.add(m);
          return m;
        }
        // Encoders never get going: the stream stays on its tuning card.
        final e = _Process(args);
        encoders.add(e);
        return e;
      },
    );
    servers = [];
    for (final id in ['p1', 'p2']) {
      final s = LineupServer(
        profileId: id,
        appFor: () => app,
        profileName: () => id,
        export: const ProfileExport(exported: true, port: 1, deviceId: '7B8AF336', deviceAuth: 'x'),
        streamer: streams,
      );
      await s.start(port: 0);
      servers.add(s);
    }
  });

  tearDown(() async {
    await streams.stopAll();
    for (final s in servers) {
      await s.stop();
    }
    await app.close();
    await dir.delete(recursive: true);
  });

  /// Each request on its own client, so ending it really drops the
  /// connection.
  final clients = <HttpClientResponse, HttpClient>{};
  Future<HttpClientResponse> open(int server, int channel) async {
    final c = HttpClient();
    final r = await (await c.getUrl(Uri.parse('http://127.0.0.1:${servers[server].port}/stream/$channel.ts'))).close();
    clients[r] = c;
    return r;
  }

  /// Hangs up on [r].
  void hangUp(HttpClientResponse r) => clients.remove(r)?.close(force: true);

  /// Reads at least [n] bytes from [r], keeping the connection.
  Future<(Uint8List, StreamSubscription<List<int>>)> read(HttpClientResponse r, int n) async {
    final got = BytesBuilder();
    final enough = Completer<void>();
    final sub = r.listen((b) {
      got.add(b);
      if (got.length >= n && !enough.isCompleted) enough.complete();
    });
    await enough.future.timeout(const Duration(seconds: 10));
    return (got.toBytes(), sub);
  }

  int number(int i) => app.channels[i].number;

  test('two viewers of a channel share one stream', () async {
    final (_, a) = await read(await open(0, number(0)), 188 * 10);
    final (_, b) = await read(await open(0, number(0)), 188 * 10);
    expect(muxers, hasLength(1));
    expect(streams.running.single.viewers, 2);
    expect(streaming.value, isTrue);
    await a.cancel();
    await b.cancel();
  });

  test('a new viewer starts with the tables and a keyframe', () async {
    final (_, first) = await read(await open(0, number(0)), 188 * 100);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final (bytes, second) = await read(await open(0, number(0)), 188 * 3);
    int pid(int o) => ((bytes[o + 1] & 0x1F) << 8) | bytes[o + 2];
    expect(pid(0), 0);
    expect(pid(188), 0x1000);
    expect(pid(376), 0x100);
    expect(bytes[376 + 5] & 0x40, 0x40, reason: 'random access');
    await first.cancel();
    await second.cancel();
  });

  test('over the limit, tuners are busy', () async {
    limit = 1;
    final (_, a) = await read(await open(0, number(0)), 188);
    final busy = await open(0, number(1));
    expect(busy.statusCode, 503);
    expect(busy.headers.value('X-HDHomeRun-Error'), '805 All Tuners In Use');
    await busy.drain<void>();
    // Another profile's channel counts against the same limit.
    final other = await open(1, number(0));
    expect(other.statusCode, 503);
    await other.drain<void>();
    // The channel already streaming can still be joined.
    final (_, b) = await read(await open(0, number(0)), 188);
    await a.cancel();
    await b.cancel();
  });

  test('a viewer back within the linger rejoins; then the stream stops', () async {
    final ra = await open(0, number(0));
    final (_, a) = await read(ra, 188 * 10);
    await a.cancel();
    hangUp(ra);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final rb = await open(0, number(0));
    final (_, b) = await read(rb, 188 * 10);
    expect(muxers, hasLength(1), reason: 'same stream');
    await b.cancel();
    hangUp(rb);
    for (var i = 0; i < 300 && streams.running.isNotEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(streams.running, isEmpty);
    expect(muxers.single.killed, isTrue);
    expect(encoders.every((e) => e.killed), isTrue);
    expect(streaming.value, isFalse);
  });

  test('a channel no longer in the lineup is a 404', () async {
    final r = await open(0, 999);
    expect(r.statusCode, 404);
    await r.drain<void>();
  });

  test('a viewer that stops reading is dropped without holding up the others', () async {
    final stuck = _StuckSink(), fast = _FastSink();
    final slow = ViewerQueue(stuck, 1000), ok = ViewerQueue(fast, 1000000);
    for (var i = 0; i < 20; i++) {
      final chunk = Uint8List(188);
      slow.send(chunk);
      ok.send(chunk);
      await Future<void>.delayed(Duration.zero);
    }
    await slow.done.timeout(const Duration(seconds: 1));
    expect(stuck.closed, isTrue);
    expect(fast.closed, isFalse);
    expect(fast.added.length, 20);
  });

  test('requests go out with the right headers', () async {
    final r = await open(0, number(0));
    expect(r.statusCode, 200);
    expect(r.headers.contentType?.mimeType, 'video/mp2t');
    expect(r.headers.value('cache-control'), 'no-store');
    final (_, sub) = await read(r, 188);
    await sub.cancel();
    expect(utf8.decode(utf8.encode('ok')), 'ok');
  });
}
