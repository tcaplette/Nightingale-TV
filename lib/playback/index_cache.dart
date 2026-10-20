import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// A direct-played file's head and index, kept on disk so mpv's reads of
/// them cost no network at the next open (fast-tune spec, "Direct-play index
/// cache"): an MP4's `moov` box wherever it is, or Matroska's Cues element.
/// mpv reads these before it can seek to a join point; over a slow link the
/// `moov` of a 22-minute episode alone took 20–25 s.
///
/// Used by the playback proxy, in its isolate only.

/// The head kept for every file.
const indexCacheHead = 256 * 1024;

/// An MP4 with its index at the front may end with small boxes after its
/// media, which mpv reads before it starts: the file's last bytes are kept
/// too.
const indexCacheTail = 64 * 1024;

/// Indexes bigger than this aren't kept (a long movie's `moov` is a few MB).
const indexCacheMaxIndex = 16 * 1024 * 1024;

/// Where a file's index is, as far as its bytes show.
sealed class IndexLookup {
  const IndexLookup();
}

/// The index is the bytes [start] to [end] (exclusive); [kind] is `moov` or
/// `cues`.
class IndexFound extends IndexLookup {
  const IndexFound(this.kind, this.start, this.end);
  final String kind;
  final int start;
  final int end;

  @override
  String toString() => 'IndexFound($kind $start-$end)';
}

/// The bytes at [offset] are needed to go on.
class IndexNeeds extends IndexLookup {
  const IndexNeeds(this.offset);
  final int offset;

  @override
  String toString() => 'IndexNeeds($offset)';
}

/// Not a format with an index this cache knows (or a damaged one): only the
/// head is kept.
class IndexNone extends IndexLookup {
  const IndexNone();

  @override
  String toString() => 'IndexNone';
}

/// What to keep with [found] in a file of [size] bytes: the index and,
/// when it's at the front (media follows it), the first [indexCacheHead]
/// bytes of media after it, which mpv's probe reads before it seeks to a
/// join point.
(int, int) keptSpan(IndexFound found, int size) =>
    (found.start, found.start < indexCacheHead ? min(size, found.end + indexCacheHead) : found.end);

/// Reads [length] bytes at [offset] (fewer at the end of the file), or null
/// when they aren't available.
typedef ByteReader = FutureOr<Uint8List?> Function(int offset, int length);

/// Finds the index of the file of [size] bytes that [read] reads.
Future<IndexLookup> locateIndex(ByteReader read, int size) async {
  final magic = await read(0, 8);
  if (magic == null) return const IndexNeeds(0);
  if (magic.length >= 4 && magic[0] == 0x1A && magic[1] == 0x45 && magic[2] == 0xDF && magic[3] == 0xA3) {
    return _locateCues(read, size);
  }
  if (magic.length >= 8 && _mp4TopLevel.contains(String.fromCharCodes(magic, 4, 8))) {
    return _locateMoov(read, size);
  }
  return const IndexNone();
}

// ---- MP4 / MOV: walk the top-level boxes to `moov` -------------------------

const _mp4TopLevel = {'ftyp', 'styp', 'moov', 'mdat', 'free', 'skip', 'wide', 'pnot', 'uuid', 'meta', 'pdin'};

/// A short tail after `moov` (user data, padding) is kept with it, since
/// mpv reads on to the end of the file.
const _tailKept = 64 * 1024;

Future<IndexLookup> _locateMoov(ByteReader read, int size) async {
  var offset = 0;
  for (var boxes = 0; boxes < 64 && offset + 8 <= size; boxes++) {
    final header = await read(offset, 16);
    if (header == null) return IndexNeeds(offset);
    if (header.length < 8) return const IndexNone();
    final data = ByteData.sublistView(header);
    final type = String.fromCharCodes(header, 4, 8);
    var length = data.getUint32(0);
    if (length == 1) {
      if (header.length < 16) return IndexNeeds(offset);
      length = data.getUint64(8);
    } else if (length == 0) {
      length = size - offset;
    }
    if (length < 8 || offset + length > size + 8) return const IndexNone();
    if (type == 'moov') {
      final end = min(offset + length, size);
      return IndexFound('moov', offset, size - end <= _tailKept ? size : end);
    }
    offset += length;
  }
  return const IndexNone();
}

// ---- Matroska / WebM: the SeekHead says where the Cues are -----------------

const _idSegment = 0x18538067;
const _idSeekHead = 0x114D9B74;
const _idSeek = 0x4DBB;
const _idSeekId = 0x53AB;
const _idSeekPosition = 0x53AC;
const _idCues = 0x1C53BB6B;
const _idCluster = 0x1F43B675;

/// An EBML variable-length number at [at] in [b]: its value and length, or
/// null when [b] ends first. [id]: keep the length marker (element IDs).
({int value, int length, bool unknown})? _vint(Uint8List b, int at, {bool id = false}) {
  if (at >= b.length) return null;
  final first = b[at];
  if (first == 0) return null;
  var length = 1;
  while (first & (0x80 >> (length - 1)) == 0) {
    length++;
  }
  if (at + length > b.length) return null;
  var value = id ? first : first & (0xFF >> length);
  var allOnes = value == (0xFF >> length);
  for (var i = 1; i < length; i++) {
    value = (value << 8) | b[at + i];
    if (b[at + i] != 0xFF) allOnes = false;
  }
  return (value: value, length: length, unknown: !id && allOnes);
}

/// The element header at [offset]: its ID, where its data starts, and its
/// size (null when unknown).
Future<({int id, int dataStart, int? size})?> _element(ByteReader read, int offset) async {
  final b = await read(offset, 12);
  if (b == null) return null;
  final id = _vint(b, 0, id: true);
  if (id == null) return null;
  final size = _vint(b, id.length);
  if (size == null) return null;
  return (id: id.value, dataStart: offset + id.length + size.length, size: size.unknown ? null : size.value);
}

Future<IndexLookup> _locateCues(ByteReader read, int size) async {
  // The EBML header, then the Segment.
  final ebml = await _element(read, 0);
  if (ebml == null || ebml.size == null) return const IndexNeeds(0);
  final segment = await _element(read, ebml.dataStart + ebml.size!);
  if (segment == null) return IndexNeeds(ebml.dataStart + ebml.size!);
  if (segment.id != _idSegment) return const IndexNone();
  final segmentStart = segment.dataStart;
  final seekHeads = <int>[];
  // The level-1 elements before the first Cluster.
  var offset = segmentStart;
  for (var elements = 0; elements < 32 && offset < size; elements++) {
    final e = await _element(read, offset);
    if (e == null) return IndexNeeds(offset);
    if (e.id == _idCues) return _cuesAt(read, offset, size);
    if (e.id == _idSeekHead) seekHeads.add(offset);
    if (e.id == _idCluster || e.size == null) break;
    offset = e.dataStart + e.size!;
  }
  final visited = <int>{};
  while (seekHeads.isNotEmpty) {
    final at = seekHeads.removeAt(0);
    if (!visited.add(at)) continue;
    final head = await _element(read, at);
    if (head == null) return IndexNeeds(at);
    if (head.id != _idSeekHead || head.size == null || head.size! > 64 * 1024) continue;
    final body = await read(head.dataStart, head.size!);
    if (body == null || body.length < head.size!) return IndexNeeds(head.dataStart);
    for (final (id, position) in _seeks(body)) {
      if (id == _idCues) return _cuesAt(read, segmentStart + position, size);
      if (id == _idSeekHead) seekHeads.add(segmentStart + position);
    }
  }
  return const IndexNone();
}

/// The (element ID, position) entries of a SeekHead's data.
Iterable<(int, int)> _seeks(Uint8List body) sync* {
  var at = 0;
  while (at < body.length) {
    final id = _vint(body, at, id: true);
    final size = id == null ? null : _vint(body, at + id.length);
    if (id == null || size == null) return;
    final start = at + id.length + size.length;
    final end = start + size.value;
    if (end > body.length) return;
    if (id.value == _idSeek) {
      int? target, position;
      var c = start;
      while (c < end) {
        final cid = _vint(body, c, id: true);
        final csize = cid == null ? null : _vint(body, c + cid.length);
        if (cid == null || csize == null) break;
        final cstart = c + cid.length + csize.length;
        if (cstart + csize.value > end) break;
        if (cid.value == _idSeekId) {
          target = _vint(body, cstart, id: true)?.value;
        } else if (cid.value == _idSeekPosition) {
          var v = 0;
          for (var i = 0; i < csize.value; i++) {
            v = (v << 8) | body[cstart + i];
          }
          position = v;
        }
        c = cstart + csize.value;
      }
      if (target != null && position != null) yield (target, position);
    }
    at = end;
  }
}

Future<IndexLookup> _cuesAt(ByteReader read, int offset, int size) async {
  final e = await _element(read, offset);
  if (e == null) return IndexNeeds(offset);
  if (e.id != _idCues || e.size == null) return const IndexNone();
  return IndexFound('cues', offset, min(e.dataStart + e.size!, size));
}

// ---- The cache on disk ------------------------------------------------------

/// Which file a cache entry is for: the item's source id, plus what changes
/// when the file is replaced.
typedef IndexCacheKey = ({String source, String? etag, int? size});

/// The bytes kept for one file, in [regions] (start, end exclusive) sorted
/// by start, stored one after another in its data file.
class IndexCacheEntry {
  IndexCacheEntry({
    required this.source,
    required this.etag,
    required this.size,
    required this.contentType,
    required this.regions,
    required this.complete,
    required this.lastUsed,
  });

  final String source;
  final String? etag;

  /// The file's size, from the server's Content-Range.
  final int size;
  final String? contentType;
  final List<(int, int)> regions;

  /// The index was found and is kept (or the file has none); else only the
  /// head is, and a background fill may finish it.
  final bool complete;
  DateTime lastUsed;

  int get bytes => regions.fold(0, (a, r) => a + r.$2 - r.$1);

  /// The region holding byte [offset], if any.
  (int, int)? regionAt(int offset) {
    for (final r in regions) {
      if (offset >= r.$1 && offset < r.$2) return r;
    }
    return null;
  }

  /// Where [offset]'s byte is in the data file.
  int _dataOffset(int offset) {
    var at = 0;
    for (final r in regions) {
      if (offset >= r.$1 && offset < r.$2) return at + offset - r.$1;
      at += r.$2 - r.$1;
    }
    throw RangeError('$offset is not cached');
  }

  Map<String, Object?> toJson() => {
        'source': source,
        'etag': etag,
        'size': size,
        'contentType': contentType,
        'regions': [for (final r in regions) [r.$1, r.$2]],
        'complete': complete,
        'lastUsed': lastUsed.millisecondsSinceEpoch,
      };

  static IndexCacheEntry? fromJson(Object? j) {
    if (j is! Map<String, Object?>) return null;
    try {
      return IndexCacheEntry(
        source: j['source'] as String,
        etag: j['etag'] as String?,
        size: j['size'] as int,
        contentType: j['contentType'] as String?,
        regions: [for (final r in (j['regions'] as List).cast<List<Object?>>()) (r[0] as int, r[1] as int)],
        complete: j['complete'] == true,
        lastUsed: DateTime.fromMillisecondsSinceEpoch(j['lastUsed'] as int),
      );
    } on Object {
      return null;
    }
  }
}

/// Entries on disk under [dir]: `<name>.json` (what's kept) and `<name>.bin`
/// (the bytes). At most [maxBytes] in all, the least recently used going
/// first.
class IndexCache {
  IndexCache(this.dir, {this.maxBytes = 256 * 1024 * 1024});

  final Directory dir;
  final int maxBytes;
  final _entries = <String, IndexCacheEntry>{};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await dir.create(recursive: true);
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final entry = IndexCacheEntry.fromJson(jsonDecode(await f.readAsString()));
        final data = File(_dataPath(f.path));
        if (entry != null && data.existsSync() && data.lengthSync() == entry.bytes) {
          _entries[entry.source] = entry;
        } else {
          await _deleteFiles(f.path);
        }
      } on Object {
        await _deleteFiles(f.path);
      }
    }
  }

  static String _dataPath(String jsonPath) => '${jsonPath.substring(0, jsonPath.length - 5)}.bin';

  Future<void> _deleteFiles(String jsonPath) async {
    for (final p in [jsonPath, _dataPath(jsonPath)]) {
      try {
        await File(p).delete();
      } on Object {
        // Already gone.
      }
    }
  }

  /// A file name for [source] (ids are GUIDs, but stay safe).
  String _name(String source) => source.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  String _jsonPath(String source) => '${dir.path}/${_name(source)}.json';

  /// The entry for [key], or null. One kept for a different version of the
  /// file (Etag or size) is dropped.
  Future<IndexCacheEntry?> lookup(IndexCacheKey key) async {
    await load();
    final entry = _entries[key.source];
    if (entry == null) return null;
    if ((key.etag != null && entry.etag != null && key.etag != entry.etag) ||
        (key.size != null && key.size != entry.size)) {
      await drop(key.source);
      return null;
    }
    return entry;
  }

  /// The entry for [source] whatever its version (for "is it kept?").
  IndexCacheEntry? peek(String source) => _entries[source];

  Future<void> drop(String source) async {
    _entries.remove(source);
    await _deleteFiles(_jsonPath(source));
  }

  /// Bytes [from] to [to] (exclusive) of [entry], all within one region.
  Future<Uint8List> read(IndexCacheEntry entry, int from, int to) async {
    final raf = await File(_dataPath(_jsonPath(entry.source))).open();
    try {
      await raf.setPosition(entry._dataOffset(from));
      return await raf.read(to - from);
    } finally {
      await raf.close();
    }
  }

  /// Marks [entry] used now (for LRU), saving it now and then.
  Future<void> touch(IndexCacheEntry entry) async {
    final now = DateTime.now();
    if (now.difference(entry.lastUsed) < const Duration(minutes: 1)) return;
    entry.lastUsed = now;
    await File(_jsonPath(entry.source)).writeAsString(jsonEncode(entry.toJson()));
  }

  /// Keeps [regions] of the file [key] (each a start and its bytes).
  Future<IndexCacheEntry?> put(IndexCacheKey key,
      {required int size, required String? contentType, required List<(int, Uint8List)> regions, required bool complete}) async {
    await load();
    final sorted = [...regions]..sort((a, b) => a.$1.compareTo(b.$1));
    // Overlapping or touching regions become one.
    final merged = <(int, BytesBuilder)>[];
    for (final (start, bytes) in sorted) {
      if (bytes.isEmpty) continue;
      final last = merged.lastOrNull;
      final lastEnd = last == null ? -1 : last.$1 + last.$2.length;
      if (last != null && start <= lastEnd) {
        final skip = lastEnd - start;
        if (skip < bytes.length) last.$2.add(Uint8List.sublistView(bytes, skip));
      } else {
        merged.add((start, BytesBuilder(copy: false)..add(bytes)));
      }
    }
    final total = merged.fold(0, (a, r) => a + r.$2.length);
    if (merged.isEmpty || total > maxBytes) return null;
    final entry = IndexCacheEntry(
      source: key.source,
      etag: key.etag,
      size: size,
      contentType: contentType,
      regions: [for (final (start, b) in merged) (start, start + b.length)],
      complete: complete,
      lastUsed: DateTime.now(),
    );
    final json = _jsonPath(key.source);
    final data = BytesBuilder(copy: false);
    for (final (_, b) in merged) {
      data.add(b.takeBytes());
    }
    // Data first, so a crash never leaves an entry without its bytes.
    await File('${_dataPath(json)}.part').writeAsBytes(data.takeBytes(), flush: true);
    await File('${_dataPath(json)}.part').rename(_dataPath(json));
    await File(json).writeAsString(jsonEncode(entry.toJson()));
    _entries[key.source] = entry;
    await _evict();
    return entry;
  }

  int get totalBytes => _entries.values.fold(0, (a, e) => a + e.bytes);

  Future<void> _evict() async {
    var total = totalBytes;
    if (total <= maxBytes) return;
    final oldest = _entries.values.toList()..sort((a, b) => a.lastUsed.compareTo(b.lastUsed));
    for (final e in oldest) {
      if (total <= maxBytes) break;
      total -= e.bytes;
      await drop(e.source);
    }
  }
}
