import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'conversion.dart';

/// Starts a program (replaceable in tests).
typedef ProgramStarter = Future<Process> Function(String program, List<String> arguments, {Map<String, String>? environment});

/// How a paired Nightingale TV is reached (see [ConversionJobs.helpers]).
class HelperRoute {
  const HelperRoute({required this.base, required this.key, required this.item});

  final Uri base;

  /// This device's key there, sent as a header.
  final String key;

  /// What identifies the file to it: the share's server id, the item, its
  /// size and modified time.
  final Map<String, String> item;

  Uri get uri => base.replace(path: '/convert');
}

/// The conversions running (design D7): each is one ffmpeg, writing to the
/// reader of its URL at that reader's pace, and ending with it.
class ConversionJobs {
  ConversionJobs(this._programs,
      {required this.input, this.most = 2, this.low = false, ProgramStarter? start, this.encoders})
      : _start = start ?? _process;

  static Future<Process> _process(String program, List<String> arguments, {Map<String, String>? environment}) =>
      Process.start(program, arguments, environment: environment);

  /// How long an encoder may take to give its first bytes before the next
  /// one is tried (a device's MediaCodec can hang in a process of its own).
  static Duration firstOutput = const Duration(seconds: 10);

  /// Encoders that gave nothing this launch, not tried again.
  final _failed = <ConversionEncoder>{};

  final FfmpegPrograms? _programs;

  /// Where ffmpeg reads [id] of [target] from.
  final String Function(String target, String id) input;

  /// How many run at once: what's on and what's preloaded. One more ends
  /// the oldest.
  final int most;

  /// At lowered priority (converting for other TVs).
  final bool low;
  final ProgramStarter _start;

  /// The encoders to try, best first; null for the platform's.
  final List<ConversionEncoder>? encoders;

  /// How to reach a helper by its id, for [target]'s [id]; null when it
  /// isn't paired any more.
  HelperRoute? Function(String helper, String target, String id)? helpers;

  final _running = <_Job>[];

  /// A job stopped before its stream was asked for.
  final _stopped = <String>{};

  int get running => _running.length;

  List<ConversionEncoder> get _encoders => [
        for (final e in encoders ??
            (_programs?.android == true ? const [ConversionEncoder.mediacodec, ConversionEncoder.x264] : const [ConversionEncoder.x264]))
          if (!_failed.contains(e)) e,
      ];

  /// Serves conversion [request] of file [id] of [target].
  Future<void> serve(HttpRequest request, String target, String id) async {
    final spec = ConversionSpec.fromQuery(request.uri.queryParameters);
    final response = request.response;
    if (spec.job != null && _stopped.remove(spec.job)) {
      response.statusCode = HttpStatus.gone;
      return;
    }
    if (request.method == 'HEAD') {
      response.headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t');
      return;
    }
    if (spec.helper case final helper?) {
      await _serveFromHelper(response, helper, target, id, spec);
    } else {
      await convert(response, input(target, id), spec);
    }
  }

  /// Converts [source] into [response] as [spec] says. Throws
  /// [ConversionException] when no encoder gives anything.
  Future<void> convert(HttpResponse response, String source, ConversionSpec spec) async {
    final programs = _programs;
    if (programs == null) throw const ConversionException('no ffmpeg');
    // The same job asked for again starts over.
    if (spec.job case final job?) await stop(job, remember: false);
    while (_running.length >= most) {
      await _running.first.end();
    }
    final all = _encoders;
    final tries = spec.convertsVideo ? all : [all.isEmpty ? ConversionEncoder.x264 : all.last];
    var error = '';
    for (final encoder in tries) {
      final args = spec.arguments(source, encoder: encoder);
      final job = _Job(spec.job);
      _running.add(job);
      try {
        final process = low && !programs.android
            ? await _start('nice', ['-n', '10', programs.ffmpeg, ...args])
            : await _start(programs.ffmpeg, args, environment: programs.environment);
        if (!job.started(process)) return;
        final stderr = job.stderr = _tail(process.stderr);
        final output = StreamIterator(process.stdout);
        final first = await output.moveNext().timeout(firstOutput, onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return false;
        });
        if (!first) {
          error = await stderr;
          if (job.ended) return;
          if (spec.convertsVideo) _failed.add(encoder);
          continue;
        }
        response.headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t');
        response.bufferOutput = false;
        Stream<List<int>> chunks() async* {
          yield output.current;
          while (await output.moveNext()) {
            yield output.current;
          }
        }

        await response.addStream(chunks());
        return;
      } on ProcessException catch (e) {
        throw ConversionException('ffmpeg did not start: ${e.message}');
      } finally {
        _running.remove(job);
        await job.end();
      }
    }
    throw ConversionException(error);
  }

  static Future<String> _tail(Stream<List<int>> stderr) async {
    final lines = <String>[];
    await for (final line in stderr.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter())) {
      lines.add(line);
      if (lines.length > 5) lines.removeAt(0);
    }
    return lines.join('\n');
  }

  /// Passes on what helper [helper] converts.
  Future<void> _serveFromHelper(HttpResponse response, String helper, String target, String id, ConversionSpec spec) async {
    final route = helpers?.call(helper, target, id);
    if (route == null) throw const ConversionException('that Nightingale TV is not paired');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    final job = _Job(spec.job, onEnd: () => client.close(force: true));
    _running.add(job);
    try {
      final ask = await client.getUrl(route.uri.replace(queryParameters: {...spec.copyWith(helper: () => null).toQuery(), ...route.item}));
      ask.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${route.key}');
      final answer = await ask.close();
      if (answer.statusCode != HttpStatus.ok) throw ConversionException('the other Nightingale TV answered ${answer.statusCode}');
      response.headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t');
      response.bufferOutput = false;
      await response.addStream(answer);
    } on SocketException catch (e) {
      throw ConversionException('the other Nightingale TV: ${e.message}');
    } finally {
      _running.remove(job);
      await job.end();
    }
  }

  /// Ends [job]; one not asked for yet never starts.
  Future<void> stop(String job, {bool remember = true}) async {
    final mine = [for (final j in _running) if (j.id == job) j];
    if (mine.isEmpty) {
      if (remember) {
        _stopped.add(job);
        if (_stopped.length > 50) _stopped.remove(_stopped.first);
      }
      return;
    }
    for (final j in mine) {
      await j.end();
    }
  }

  Future<void> stopAll() => Future.wait([for (final j in [..._running]) j.end()]);
}

class _Job {
  _Job(this.id, {this.onEnd});

  final String? id;
  final void Function()? onEnd;
  Process? _process;
  Future<String>? stderr;
  bool ended = false;

  /// False when it was ended before it started.
  bool started(Process process) {
    _process = process;
    if (ended) process.kill(ProcessSignal.sigkill);
    return !ended;
  }

  /// Ends it and waits until its program is gone.
  Future<void> end() async {
    ended = true;
    onEnd?.call();
    final process = _process;
    if (process == null) return;
    // Nothing it holds needs saving.
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
  }
}
