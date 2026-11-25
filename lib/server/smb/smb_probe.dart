import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../languages.dart';

/// A file's picture, as read of it.
class ProbeVideo {
  const ProbeVideo({
    required this.codec,
    this.profile = '',
    this.width = 0,
    this.height = 0,
    this.fps = 0,
    this.bitDepth = 8,
    this.hdr = false,
    this.interlaced = false,
    this.level = 0,
  });

  final String codec;

  /// Lower case, as Jellyfin names profiles ("main 10").
  final String profile;
  final int width, height;
  final double fps;
  final int bitDepth;
  final bool hdr;
  final bool interlaced;
  final int level;

  Map<String, Object?> toJson() => {
        'codec': codec,
        if (profile.isNotEmpty) 'profile': profile,
        'w': width,
        'h': height,
        'fps': fps,
        if (bitDepth != 8) 'bits': bitDepth,
        if (hdr) 'hdr': true,
        if (interlaced) 'interlaced': true,
        if (level != 0) 'level': level,
      };

  factory ProbeVideo.fromJson(Map<String, Object?> j) => ProbeVideo(
        codec: j['codec'] as String,
        profile: j['profile'] as String? ?? '',
        width: j['w'] as int? ?? 0,
        height: j['h'] as int? ?? 0,
        fps: (j['fps'] as num?)?.toDouble() ?? 0,
        bitDepth: j['bits'] as int? ?? 8,
        hdr: j['hdr'] == true,
        interlaced: j['interlaced'] == true,
        level: j['level'] as int? ?? 0,
      );
}

class ProbeAudio {
  const ProbeAudio({required this.codec, this.channels = 2});

  final String codec;
  final int channels;
}

class ProbeSubtitle {
  const ProbeSubtitle({required this.codec, this.language, this.tag, this.title, this.isDefault = false, this.isForced = false});

  final String codec;
  final String? language;

  /// The language as the file wrote it.
  final String? tag;
  final String? title;
  final bool isDefault;
  final bool isForced;

  Map<String, Object?> toJson() => {
        'codec': codec,
        'lang': ?language,
        'tag': ?tag,
        'title': ?title,
        if (isDefault) 'default': true,
        if (isForced) 'forced': true,
      };

  factory ProbeSubtitle.fromJson(Map<String, Object?> j) => ProbeSubtitle(
        codec: j['codec'] as String,
        language: j['lang'] as String?,
        tag: j['tag'] as String?,
        title: j['title'] as String?,
        isDefault: j['default'] == true,
        isForced: j['forced'] == true,
      );
}

/// What was read of one file (design D5), kept until its size or modified
/// time changes.
class SmbProbe {
  const SmbProbe({
    required this.size,
    required this.modified,
    this.duration,
    this.container = '',
    this.bitrate = 0,
    this.video,
    this.audio = const [],
    this.subtitles = const [],
    this.chapters = const [],
    this.tags = const {},
    this.cover = false,
    this.damaged = false,
    this.decodes,
  });

  final int size;
  final int modified;

  /// Null for a damaged file.
  final Duration? duration;

  /// ffprobe's container name (`matroska,webm`).
  final String container;

  /// Bits per second, the whole file's.
  final int bitrate;
  final ProbeVideo? video;
  final List<ProbeAudio> audio;
  final List<ProbeSubtitle> subtitles;
  final List<Duration> chapters;

  /// Music tags: title, artist, album, album_artist, genre, date.
  final Map<String, String> tags;

  /// Holds a cover picture.
  final bool cover;

  /// It can't be read.
  final bool damaged;

  /// Whether a few seconds of what a conversion decodes did decode; null
  /// before that was tried (only files the device converts are tried).
  final bool? decodes;

  SmbProbe withDecodes(bool value) => SmbProbe(
        size: size,
        modified: modified,
        duration: duration,
        container: container,
        bitrate: bitrate,
        video: video,
        audio: audio,
        subtitles: subtitles,
        chapters: chapters,
        tags: tags,
        cover: cover,
        damaged: damaged,
        decodes: value,
      );

  bool matches(int size, int modified) => this.size == size && this.modified == modified;

  Map<String, Object?> toJson() => {
        'size': size,
        'm': modified,
        if (duration != null) 'ms': duration!.inMilliseconds,
        if (container.isNotEmpty) 'container': container,
        if (bitrate != 0) 'rate': bitrate,
        'video': ?video?.toJson(),
        if (audio.isNotEmpty) 'audio': [for (final a in audio) [a.codec, a.channels]],
        if (subtitles.isNotEmpty) 'subs': [for (final s in subtitles) s.toJson()],
        if (chapters.isNotEmpty) 'chapters': [for (final c in chapters) c.inMilliseconds],
        if (tags.isNotEmpty) 'tags': tags,
        if (cover) 'cover': true,
        if (damaged) 'damaged': true,
        'dec': ?decodes,
      };

  factory SmbProbe.fromJson(Map<String, Object?> j) => SmbProbe(
        size: j['size'] as int,
        modified: j['m'] as int,
        duration: switch (j['ms']) { final int ms => Duration(milliseconds: ms), _ => null },
        container: j['container'] as String? ?? '',
        bitrate: j['rate'] as int? ?? 0,
        video: j['video'] is Map<String, Object?> ? ProbeVideo.fromJson(j['video'] as Map<String, Object?>) : null,
        audio: [
          for (final a in (j['audio'] as List? ?? const []).cast<List<Object?>>())
            ProbeAudio(codec: a[0] as String, channels: a[1] as int)
        ],
        subtitles: [
          for (final s in (j['subs'] as List? ?? const []).cast<Map<String, Object?>>()) ProbeSubtitle.fromJson(s)
        ],
        chapters: [for (final ms in (j['chapters'] as List? ?? const []).cast<int>()) Duration(milliseconds: ms)],
        tags: (j['tags'] as Map?)?.cast<String, String>() ?? const {},
        cover: j['cover'] == true,
        damaged: j['damaged'] == true,
        decodes: j['dec'] as bool?,
      );

  /// What ffprobe's [json] says ([json] null: it couldn't read the file).
  factory SmbProbe.parse(Map<String, Object?>? json, {required int size, required int modified}) {
    final format = json?['format'];
    final streams = (json?['streams'] as List? ?? const []).whereType<Map<String, Object?>>().toList();
    final seconds = format is Map<String, Object?> ? double.tryParse('${format['duration'] ?? ''}') : null;
    final lasts = seconds ??
        streams.map((s) => double.tryParse('${s['duration'] ?? ''}')).nonNulls.fold<double?>(null, (a, b) => max(a ?? 0, b));
    if (json == null || format is! Map<String, Object?> || lasts == null || lasts <= 0 || streams.isEmpty) {
      return SmbProbe(size: size, modified: modified, damaged: true);
    }
    bool flag(Map<String, Object?> s, String name) => (s['disposition'] as Map?)?[name] == 1;
    Map<String, Object?> tagsOf(Map<String, Object?> s) =>
        {for (final e in (s['tags'] as Map? ?? const {}).entries) '${e.key}'.toLowerCase(): e.value};
    final picture = streams.where((s) => s['codec_type'] == 'video' && !flag(s, 'attached_pic')).firstOrNull;
    final formatTags = tagsOf(format);
    return SmbProbe(
      size: size,
      modified: modified,
      duration: Duration(milliseconds: (lasts * 1000).round()),
      container: '${format['format_name'] ?? ''}',
      bitrate: int.tryParse('${format['bit_rate'] ?? ''}') ?? (size * 8 / lasts).round(),
      video: picture == null ? null : _video(picture),
      audio: [
        for (final s in streams)
          if (s['codec_type'] == 'audio')
            ProbeAudio(codec: '${s['codec_name'] ?? 'unknown'}', channels: (s['channels'] as num?)?.toInt() ?? 2)
      ],
      subtitles: [
        for (final s in streams)
          if (s['codec_type'] == 'subtitle')
            if (tagsOf(s) case final tags)
              ProbeSubtitle(
                codec: '${s['codec_name'] ?? 'unknown'}',
                language: normalizeLanguage(tags['language'] as String?),
                tag: tags['language'] as String?,
                title: switch ((tags['title'] as String?)?.trim()) { final t? when t.isNotEmpty => t, _ => null },
                isDefault: flag(s, 'default'),
                isForced: flag(s, 'forced'),
              )
      ],
      chapters: [
        for (final c in (json['chapters'] as List? ?? const []).whereType<Map<String, Object?>>())
          if (double.tryParse('${c['start_time'] ?? ''}') case final at?) Duration(milliseconds: (at * 1000).round())
      ]..sort(),
      tags: {
        for (final name in const ['title', 'artist', 'album', 'album_artist', 'genre', 'date'])
          if ('${formatTags[name] ?? streams.map((s) => tagsOf(s)[name]).nonNulls.firstOrNull ?? ''}'.trim() case final v when v.isNotEmpty)
            name: v
      },
      cover: streams.any((s) => s['codec_type'] == 'video' && flag(s, 'attached_pic')),
    );
  }

  static ProbeVideo _video(Map<String, Object?> s) {
    double rate(Object? r) {
      final parts = '$r'.split('/');
      final n = double.tryParse(parts.first) ?? 0, d = parts.length > 1 ? double.tryParse(parts[1]) ?? 1 : 1.0;
      return d == 0 ? 0 : n / d;
    }

    final format = '${s['pix_fmt'] ?? ''}';
    final bits = int.tryParse('${s['bits_per_raw_sample'] ?? ''}') ??
        int.tryParse(RegExp(r'p(1[0-6])(?:le|be)?$').firstMatch(format)?[1] ?? '') ??
        8;
    final fps = rate(s['avg_frame_rate']);
    final order = '${s['field_order'] ?? ''}';
    return ProbeVideo(
      codec: '${s['codec_name'] ?? 'unknown'}',
      profile: '${s['profile'] ?? ''}'.toLowerCase(),
      width: (s['width'] as num?)?.toInt() ?? 0,
      height: (s['height'] as num?)?.toInt() ?? 0,
      fps: double.parse((fps > 0 && fps < 1000 ? fps : rate(s['r_frame_rate'])).toStringAsFixed(3)),
      bitDepth: bits == 0 ? 8 : bits,
      hdr: const {'smpte2084', 'arib-std-b67'}.contains(s['color_transfer']),
      interlaced: const {'tt', 'bb', 'tb', 'bt'}.contains(order),
      level: (s['level'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Reads files in the background, [atOnce] at a time, in the order given,
/// holding off while [hold] says so (tuning, asleep).
class SmbProber {
  SmbProber({required this.probe, required this.onProbed, required this.onBatch, this.hold, this.batchFiles = 500, this.batchTime = const Duration(seconds: 30)});

  /// Reads one file; null when its share can't be reached (it's read at
  /// the next scan).
  final Future<SmbProbe?> Function(String id) probe;
  final void Function(String id, SmbProbe probe) onProbed;

  /// Enough files became ready for the library to be built again (or, with
  /// [last], the rest of them).
  final Future<void> Function({required bool last}) onBatch;
  final ValueListenable<bool>? hold;
  final int batchFiles;
  final Duration batchTime;

  static const atOnce = 2;

  final _queue = <String>[];
  final _queued = <String>{};
  int _running = 0;
  int _ready = 0;
  bool _closed = false;
  bool _stopped = false;
  DateTime _lastBatch = DateTime.now();
  Completer<void>? _idle;

  /// Files still to be read.
  final left = ValueNotifier(0);

  /// Reads [ids] (those not already waiting), in this order.
  void add(Iterable<String> ids) {
    _stopped = false;
    for (final id in ids) {
      if (_queued.add(id)) _queue.add(id);
    }
    _lastBatch = DateTime.now();
    _count();
    _pump();
  }

  /// Forgets what's waiting.
  void clear() {
    _queued.removeAll(_queue);
    _queue.clear();
    _count();
  }

  void _count() => left.value = _queue.length + _running;

  bool get _held => hold?.value ?? false;

  void _pump() {
    while (!_closed && !_stopped && !_held && _running < atOnce && _queue.isNotEmpty) {
      unawaited(_one(_queue.removeAt(0)));
    }
    if (_held && _queue.isNotEmpty && !_closed) {
      hold!.removeListener(_onHold);
      hold!.addListener(_onHold);
    }
    if (_queue.isEmpty && _running == 0) {
      _idle?.complete();
      _idle = null;
    }
  }

  void _onHold() {
    if (_held) return;
    hold!.removeListener(_onHold);
    _pump();
  }

  Future<void> _one(String id) async {
    _running++;
    try {
      final result = await probe(id);
      if (_closed) return;
      if (result == null) {
        // Its share is gone: the rest would only time out too.
        _stopped = true;
        _queued.removeAll(_queue);
        _queue.clear();
      } else {
        onProbed(id, result);
        _ready++;
      }
    } on Object catch (e) {
      debugPrint('Reading a file failed: ${e.runtimeType}');
    } finally {
      _queued.remove(id);
      _running--;
      if (!_closed) {
        _count();
        final last = _queue.isEmpty && _running == 0;
        if (_ready > 0 && (last || _ready >= batchFiles && DateTime.now().difference(_lastBatch) >= batchTime)) {
          _ready = 0;
          _lastBatch = DateTime.now();
          unawaited(onBatch(last: last));
        }
        _pump();
      }
    }
  }

  /// Completes when nothing is waiting.
  Future<void> idle() => _queue.isEmpty && _running == 0 ? Future.value() : (_idle ??= Completer<void>()).future;

  void close() {
    _closed = true;
    hold?.removeListener(_onHold);
    _queue.clear();
    _idle?.complete();
    _idle = null;
  }
}
