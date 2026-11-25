import 'dart:convert';
import 'dart:io';

import '../server/smb/smb_probe.dart';

/// How fast this device converts each kind of picture (design D8), kept for
/// the device in `convert_speed.json`.
class ConvertSpeeds {
  ConvertSpeeds(this.file);

  final File file;

  /// Fast enough: converted at this many times its speed or better.
  static const enough = 1.5;

  /// A kind whose picture stalls this many times within [stallWindow] is
  /// too slow.
  static const stalls = 2;
  static const stallWindow = Duration(minutes: 5);

  Map<String, double>? _speeds;
  final _stalls = <String, List<DateTime>>{};

  /// The kind of picture [video] is, converted with or without tone-mapping
  /// ([hdr]): codec, bit depth, size and frame rate.
  static String classOf(ProbeVideo video, {bool hdr = false}) {
    final size = switch (video.height) {
      <= 576 => 'sd',
      <= 720 => '720',
      <= 1088 => '1080',
      _ => '2160',
    };
    return '${video.codec}|${video.bitDepth}|$size|${video.fps > 31 ? 60 : 30}${hdr || video.hdr ? '|hdr' : ''}';
  }

  Future<Map<String, double>> _load() async => _speeds ??= await () async {
        try {
          final json = jsonDecode(await file.readAsString());
          return {for (final e in (json as Map).entries) '${e.key}': (e.value as num).toDouble()};
        } on Object {
          return <String, double>{};
        }
      }();

  /// Its speed, if it was tried.
  Future<double?> speedOf(String kind) async => (await _load())[kind];

  /// Whether it's known to be fast enough (true), too slow (false), or not
  /// tried yet (null).
  Future<bool?> fastEnough(String kind) async {
    final s = await speedOf(kind);
    return s == null ? null : s >= enough;
  }

  Future<void> record(String kind, double speed) async {
    final speeds = await _load();
    speeds[kind] = double.parse(speed.toStringAsFixed(2));
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(speeds), flush: true);
    await tmp.rename(file.path);
  }

  /// The picture of [kind] stalled; true when that made it too slow.
  Future<bool> stalled(String kind, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final list = _stalls.putIfAbsent(kind, () => [])
      ..removeWhere((t) => at.difference(t) > stallWindow)
      ..add(at);
    if (list.length < stalls) return false;
    list.clear();
    await record(kind, 0);
    return true;
  }

  /// Every kind tried, and its speed (the web admin and tests).
  Future<Map<String, double>> all() async => Map.of(await _load());
}
