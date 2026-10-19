import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../app_state.dart';
import '../commercials/analysis/ffmpeg_runner.dart';
import 'broadcast_art.dart';
import 'encode_args.dart';
import 'export_settings.dart';

/// Each card's 1 s MPEG-TS chunk, encoded once per format and encoder
/// (design D3), kept on disk and the most used in memory.
class CardChunks {
  CardChunks(this.art, {ProcessRunner? run}) : _run = run ?? Process.run;

  final BroadcastArt art;
  final ProcessRunner _run;
  final _memory = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List>>{};
  static const _memorySize = 64;

  Future<Uint8List> chunkFor(BroadcastCard card, AppState app, ExportQuality quality, VideoEncoder encoder) {
    final key = md5.convert(utf8.encode('${card.key}|${quality.label}|${encoder.codec}')).toString();
    final cached = _memory.remove(key);
    if (cached != null) return Future.value(_memory[key] = cached);
    // A block body: returning the removed future would make whenComplete
    // wait on itself.
    return _pending[key] ??= _make(key, card, app, quality, encoder).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<Uint8List> _make(String key, BroadcastCard card, AppState app, ExportQuality quality, VideoEncoder encoder) async {
    final file = File('${art.cacheDir.path}/chunk-$key.ts');
    if (!await file.exists()) {
      final png = await art.cardPng(card, app, quality.height);
      final tmp = '${file.path}.$pid.tmp';
      final r = await _run('nice', EncodeArgs.cardChunk(png: png.path, output: tmp, quality: quality, encoder: encoder));
      if (r.exitCode != 0) {
        throw ProcessException('ffmpeg', const [], 'Couldn\'t encode a card: ${'${r.stderr}'.trim()}', r.exitCode);
      }
      await File(tmp).rename(file.path);
    }
    final bytes = await file.readAsBytes();
    if (_memory.length >= _memorySize) _memory.remove(_memory.keys.first);
    return _memory[key] = bytes;
  }
}
