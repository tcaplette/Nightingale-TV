import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:xml/xml_events.dart';

import 'guide_match.dart';
import 'live_data.dart';

class XmltvException implements Exception {
  const XmltvException(this.message);

  final String message;

  static const tooBig = XmltvException('The guide is too big (over 1 GB)');
  static const notXmltv = XmltvException("That isn't an XMLTV guide");

  @override
  String toString() => message;
}

/// A channel whose programmes are wanted, as the playlist describes it.
typedef GuideWant = ({String key, String? tvgId, String? tvgName, String name});

class XmltvResult {
  const XmltvResult({required this.channels, required this.programmes, required this.matches});

  /// Every channel the guide lists, in order.
  final List<GuideChannel> channels;

  /// Wanted channels' programmes from now on, by channel key, in order.
  final Map<String, List<LiveProgramme>> programmes;

  /// Which guide channel each wanted channel matched, by key.
  final Map<String, String> matches;
}

/// Guides bigger than this, uncompressed, are refused (gzip bombs).
const xmltvMaxBytes = 1 << 30;

/// Reads the XMLTV guide in [path] (plain or gzip, by content) off the UI
/// isolate, keeping programmes for [wanted] only, ending after [now] and
/// starting before [now] + [horizon].
Future<XmltvResult> parseXmltvFile(String path, List<GuideWant> wanted,
        {DateTime? now, Duration horizon = const Duration(hours: 48), int maxBytes = xmltvMaxBytes}) {
  final at = now ?? DateTime.now();
  return Isolate.run(() => readXmltv(File(path).openRead(), wanted, now: at, horizon: horizon, maxBytes: maxBytes));
}

/// What [parseXmltvFile] does, on the calling isolate, from [bytes].
Future<XmltvResult> readXmltv(Stream<List<int>> bytes, List<GuideWant> wanted,
    {required DateTime now, Duration horizon = const Duration(hours: 48), int maxBytes = xmltvMaxBytes}) async {
  final reader = _Reader(wanted, now, now.add(horizon));
  var size = 0;
  final counted = _sniffGzip(bytes).map((chunk) {
    size += chunk.length;
    if (size > maxBytes) throw XmltvException.tooBig;
    return chunk;
  });
  var sawTv = false;
  try {
    await for (final events in counted.transform(const Utf8Decoder(allowMalformed: true)).toXmlEvents()) {
      for (final e in events) {
        if (!sawTv && e is XmlStartElementEvent) {
          if (e.localName != 'tv') throw XmltvException.notXmltv;
          sawTv = true;
        }
        reader.on(e);
      }
    }
  } on FormatException {
    // XML errors are FormatExceptions too. A guide cut off or broken near
    // the end keeps what was read.
    if (!sawTv) throw XmltvException.notXmltv;
  }
  if (!sawTv) throw XmltvException.notXmltv;
  return reader.result();
}

/// [bytes], gunzipped when they start with the gzip magic number.
Stream<List<int>> _sniffGzip(Stream<List<int>> bytes) async* {
  final it = StreamIterator(bytes);
  if (!await it.moveNext()) return;
  final first = it.current;
  Stream<List<int>> all() async* {
    yield first;
    while (await it.moveNext()) {
      yield it.current;
    }
  }

  final gzipped = first.length >= 2 && first[0] == 0x1f && first[1] == 0x8b;
  yield* gzipped ? all().transform(gzip.decoder) : all();
}

/// Time as XMLTV writes it: `YYYYMMDDhhmmss ±hhmm`, seconds and offset
/// optional (no offset is UTC). Null when unreadable.
DateTime? parseXmltvTime(String? s) {
  final m = RegExp(r'^\s*(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-])?(\d{2})?:?(\d{2})?').firstMatch(s ?? '');
  if (m == null) return null;
  int n(int i) => int.parse(m[i]!);
  var t = DateTime.utc(n(1), n(2), n(3), n(4), n(5), m[6] == null ? 0 : n(6));
  if (m[7] != null && m[8] != null) {
    final offset = Duration(hours: n(8), minutes: m[9] == null ? 0 : n(9));
    t = m[7] == '+' ? t.subtract(offset) : t.add(offset);
  }
  return t.toLocal();
}

/// `xmltv_ns` (`season.episode.part`, zero-based, `x/total` allowed) or
/// `onscreen` (`S1E2`, `S01 E02`, `1x02`) episode numbers, one-based.
({int? season, int? episode}) parseEpisodeNum(String? system, String text) {
  final t = text.trim();
  if (system == 'xmltv_ns') {
    final parts = t.split('.');
    int? part(int i) {
      if (i >= parts.length) return null;
      final v = int.tryParse(parts[i].split('/').first.trim());
      return v == null ? null : v + 1;
    }

    return (season: part(0), episode: part(1));
  }
  final m = RegExp(r'S\s*(\d+)\s*[\.:]?\s*E\s*(\d+)', caseSensitive: false).firstMatch(t) ??
      RegExp(r'^(\d+)\s*x\s*(\d+)$', caseSensitive: false).firstMatch(t);
  if (m != null) return (season: int.parse(m[1]!), episode: int.parse(m[2]!));
  final e = RegExp(r'^E\s*(\d+)$', caseSensitive: false).firstMatch(t);
  return (season: null, episode: e == null ? null : int.parse(e[1]!));
}

class _Programme {
  _Programme(this.start, this.stop);

  final DateTime start;
  final DateTime? stop;
  String? title, subtitle, desc, date, rating, icon;
  String? titleLang, categoryLang;
  final categories = <String>[];
  int? season, episode;
  String? onscreen;
  bool isNew = false;
}

class _Reader {
  _Reader(this.wanted, this.now, this.until)
      : _byId = {
          for (final w in wanted)
            if (w.tvgId != null) w.tvgId!: [],
        };

  final List<GuideWant> wanted;
  final DateTime now;
  final DateTime until;

  final channels = <GuideChannel>[];
  final _matcher = GuideMatcher();
  bool _matchStale = true;

  /// Guide channel id → wanted keys, worked out from the channels read so
  /// far (they normally all come before the programmes).
  Map<String, List<String>> _byId;
  final matches = <String, String>{};

  final _programmes = <String, List<_Programme>>{};

  // Where the reader is.
  final _path = <String>[];
  String? _channelId;
  List<String>? _channelNames;
  String? _channelIcon;
  _Programme? _programme;
  List<String>? _programmeKeys;
  bool _skipping = false;
  int _skipDepth = 0;
  String? _textFor;
  String? _textLang;
  String? _episodeSystem;
  final _text = StringBuffer();

  void _rematch() {
    _matchStale = false;
    final byId = <String, List<String>>{};
    for (final w in wanted) {
      final id = _matcher.match(tvgId: w.tvgId, tvgName: w.tvgName, name: w.name) ??
          (_matcher.isEmpty ? w.tvgId : null);
      if (id == null) continue;
      matches[w.key] = id;
      byId.putIfAbsent(id, () => []).add(w.key);
    }
    _byId = byId;
  }

  void on(XmlEvent e) {
    if (_skipping) {
      if (e is XmlStartElementEvent && !e.isSelfClosing) _skipDepth++;
      if (e is XmlEndElementEvent && _skipDepth-- == 0) _skipping = false;
      return;
    }
    switch (e) {
      case XmlStartElementEvent():
        _start(e);
        if (!e.isSelfClosing && !_skipping) _path.add(e.localName);
        if (e.isSelfClosing) _end(e.localName);
      case XmlEndElementEvent():
        if (_path.isNotEmpty) _path.removeLast();
        _end(e.localName);
      case XmlTextEvent():
        if (_textFor != null) _text.write(e.value);
      case XmlCDATAEvent():
        if (_textFor != null) _text.write(e.value);
      default:
    }
  }

  String? _attr(XmlStartElementEvent e, String name) {
    for (final a in e.attributes) {
      if (a.localName == name) return a.value;
    }
    return null;
  }

  void _collect(String element, XmlStartElementEvent e) {
    _textFor = element;
    _textLang = _attr(e, 'lang');
    _text.clear();
  }

  void _start(XmlStartElementEvent e) {
    final name = e.localName;
    final parent = _path.isEmpty ? null : _path.last;
    if (parent == 'tv') {
      if (name == 'channel') {
        _channelId = _attr(e, 'id');
        _channelNames = [];
        _channelIcon = null;
      } else if (name == 'programme') {
        if (_matchStale) _rematch();
        final keys = _byId[_attr(e, 'channel')];
        final start = parseXmltvTime(_attr(e, 'start'));
        final stop = parseXmltvTime(_attr(e, 'stop'));
        if (keys == null || keys.isEmpty || start == null || !start.isBefore(until) ||
            (stop != null && !stop.isAfter(now))) {
          if (!e.isSelfClosing) {
            _skipping = true;
            _skipDepth = 0;
          }
          return;
        }
        _programme = _Programme(start, stop);
        _programmeKeys = keys;
      }
      return;
    }
    if (parent == 'channel' && _channelId != null) {
      if (name == 'display-name') _collect(name, e);
      if (name == 'icon') _channelIcon ??= _attr(e, 'src');
      return;
    }
    final p = _programme;
    if (p == null) return;
    if (parent == 'programme') {
      switch (name) {
        case 'title' || 'sub-title' || 'desc' || 'category' || 'date':
          _collect(name, e);
        case 'episode-num':
          _episodeSystem = _attr(e, 'system');
          _collect(name, e);
        case 'icon':
          p.icon ??= _attr(e, 'src');
        case 'new' || 'premiere':
          p.isNew = true;
      }
    } else if (parent == 'rating' && name == 'value' && p.rating == null) {
      _collect('rating', e);
    }
  }

  void _end(String name) {
    if (_textFor == name || (_textFor == 'rating' && name == 'value')) {
      _finishText();
      return;
    }
    if (name == 'channel' && _channelId != null && _path.length == 1) {
      final c = GuideChannel(id: _channelId!, names: _channelNames ?? const [], icon: _channelIcon);
      channels.add(c);
      _matcher.add(c);
      _matchStale = true;
      _channelId = null;
    } else if (name == 'programme' && _programme != null && _path.length == 1) {
      for (final k in _programmeKeys!) {
        _programmes.putIfAbsent(k, () => []).add(_programme!);
      }
      _programme = null;
    }
  }

  void _finishText() {
    final what = _textFor;
    final text = _text.toString().trim();
    final lang = _textLang;
    _textFor = null;
    _text.clear();
    if (what == 'display-name') {
      if (text.isNotEmpty) _channelNames?.add(text);
      return;
    }
    final p = _programme;
    if (p == null || text.isEmpty) return;
    switch (what) {
      case 'title':
        if (p.title == null) {
          p.title = text;
          p.titleLang = lang;
        }
      case 'sub-title':
        p.subtitle ??= text;
      case 'desc':
        p.desc ??= text;
      case 'category':
        if (p.categories.isEmpty) p.categoryLang = lang;
        if (lang == p.categoryLang && !p.categories.contains(text)) p.categories.add(text);
      case 'date':
        p.date ??= text;
      case 'rating':
        p.rating ??= text;
      case 'episode-num':
        final n = parseEpisodeNum(_episodeSystem, text);
        // xmltv_ns wins over onscreen when both are given.
        if (_episodeSystem == 'xmltv_ns' || p.episode == null) {
          if (n.season != null || n.episode != null) {
            p.season = n.season ?? p.season;
            p.episode = n.episode ?? p.episode;
          }
        }
    }
  }

  XmltvResult result() {
    if (_matchStale) _rematch();
    final out = <String, List<LiveProgramme>>{};
    for (final e in _programmes.entries) {
      final list = [...e.value]..sort((a, b) => a.start.compareTo(b.start));
      final programmes = <LiveProgramme>[];
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        // Without a stop, it ends where the next one starts.
        final end = p.stop ?? (i + 1 < list.length ? list[i + 1].start : null);
        if (end == null || p.title == null) continue;
        final year = int.tryParse(RegExp(r'^\d{4}').firstMatch(p.date ?? '')?[0] ?? '');
        final movie = p.categories.any((c) => RegExp(r'\b(movie|film)s?\b', caseSensitive: false).hasMatch(c));
        programmes.add(LiveProgramme(
          start: p.start,
          end: end,
          title: p.title!,
          subtitle: p.subtitle,
          description: p.desc,
          categories: p.categories,
          year: year,
          rating: p.rating,
          season: p.season,
          episode: p.episode,
          isNew: p.isNew,
          isMovie: movie,
          icon: p.icon,
        ));
      }
      final tidy = tidyProgrammes(programmes, now);
      if (tidy.isNotEmpty) out[e.key] = tidy;
    }
    return XmltvResult(channels: channels, programmes: out, matches: matches);
  }
}
