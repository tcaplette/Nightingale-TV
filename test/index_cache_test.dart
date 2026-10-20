import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/index_cache.dart';

import 'media_files.dart';

void main() {
  late ({File mp4, File faststart, File mkv}) videos;

  setUpAll(() async => videos = await testVideos());

  Future<IndexLookup> locate(Uint8List bytes, {int? readable}) =>
      locateIndex((offset, length) {
        final end = (offset + length).clamp(0, bytes.length);
        if (readable != null && end > readable) return null;
        return Uint8List.sublistView(bytes, offset, end);
      }, bytes.length);

  group('finding the index', () {
    test('an MP4 with its moov at the end', () async {
      final bytes = videos.mp4.readAsBytesSync();
      final found = await locate(bytes) as IndexFound;
      expect(found.kind, 'moov');
      expect(String.fromCharCodes(bytes, found.start + 4, found.start + 8), 'moov');
      expect(found.start, greaterThan(bytes.length ~/ 2), reason: 'after the media');
      expect(found.end, bytes.length);
    });

    test('an MP4 written for streaming (moov first)', () async {
      final bytes = videos.faststart.readAsBytesSync();
      final found = await locate(bytes) as IndexFound;
      expect(String.fromCharCodes(bytes, found.start + 4, found.start + 8), 'moov');
      expect(found.start, lessThan(1024));
      expect(found.end - found.start, ByteData.sublistView(bytes).getUint32(found.start));
    });

    test('a Matroska file\'s Cues, through its SeekHead', () async {
      final bytes = videos.mkv.readAsBytesSync();
      final found = await locate(bytes) as IndexFound;
      expect(found.kind, 'cues');
      expect(bytes.sublist(found.start, found.start + 4), [0x1C, 0x53, 0xBB, 0x6B]);
      expect(found.start, greaterThan(bytes.length ~/ 2), reason: 'ffmpeg writes the Cues at the end');
      expect(found.end, lessThanOrEqualTo(bytes.length));
    });

    test('from the head alone, it says which bytes it needs next', () async {
      final bytes = videos.mp4.readAsBytesSync();
      final needs = await locate(bytes, readable: indexCacheHead) as IndexNeeds;
      expect(String.fromCharCodes(bytes, needs.offset + 4, needs.offset + 8), 'moov');
      final cues = await locate(videos.mkv.readAsBytesSync(), readable: indexCacheHead);
      expect(cues, isA<IndexNeeds>());
    });

    test('other formats have no index', () async {
      expect(await locate(Uint8List.fromList(List.filled(4096, 0x47))), isA<IndexNone>());
    });
  });

  group('the cache on disk', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_index_cache'));
    tearDown(() => dir.delete(recursive: true));

    Uint8List bytes(int n, int seed) => Uint8List.fromList([for (var i = 0; i < n; i++) (i * 7 + seed) & 0xFF]);

    test('keeps regions and reads them back, across a restart', () async {
      final cache = IndexCache(dir);
      final head = bytes(1000, 1), index = bytes(500, 2);
      await cache.put((source: 'a', etag: 'e1', size: 10000),
          size: 10000, contentType: 'video/mp4', regions: [(9000, index), (0, head)], complete: true);
      final again = IndexCache(dir);
      final entry = (await again.lookup((source: 'a', etag: 'e1', size: 10000)))!;
      expect(entry.regions, [(0, 1000), (9000, 9500)]);
      expect(await again.read(entry, 9100, 9200), index.sublist(100, 200));
      expect(await again.read(entry, 0, 10), head.sublist(0, 10));
      expect(entry.regionAt(5000), isNull);
    });

    test('a replaced file (new Etag or size) drops its entry', () async {
      final cache = IndexCache(dir);
      Future<void> put() => cache.put((source: 'a', etag: 'e1', size: 10000),
          size: 10000, contentType: null, regions: [(0, bytes(100, 1))], complete: true);
      await put();
      expect(await cache.lookup((source: 'a', etag: 'e2', size: 10000)), isNull);
      expect(await cache.lookup((source: 'a', etag: 'e1', size: 10000)), isNull, reason: 'dropped, not kept aside');
      await put();
      expect(await cache.lookup((source: 'a', etag: 'e1', size: 20000)), isNull);
      await put();
      expect(await cache.lookup((source: 'a', etag: 'e1', size: null)), isNotNull, reason: 'size not known: Etag only');
    });

    test('the least recently used go first past the size cap', () async {
      final cache = IndexCache(dir, maxBytes: 2500);
      for (final (i, id) in ['a', 'b', 'c'].indexed) {
        await cache.put((source: id, etag: null, size: 5000),
            size: 5000, contentType: null, regions: [(0, bytes(1000, i))], complete: true);
        cache.peek(id)!.lastUsed = DateTime(2026, 1, 1, 0, i);
      }
      expect(cache.peek('a'), isNull, reason: '3000 bytes over a 2500 cap: the oldest goes');
      expect(cache.peek('b'), isNotNull);
      expect(cache.peek('c'), isNotNull);
      expect(cache.totalBytes, lessThanOrEqualTo(2500));
      expect(File('${dir.path}/a.bin').existsSync(), isFalse);
    });
  });
}
