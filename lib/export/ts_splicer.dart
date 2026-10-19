import 'dart:typed_data';

/// Joins separately encoded MPEG-TS segments into one stream for the
/// copying muxer (design D3): each segment's PES timestamps and PCRs are
/// shifted so the stream's time keeps rising, and each PID's continuity
/// counter carries on across segments.
///
/// A segment's shift is fixed by its first video PTS, so the packets before
/// it (tables, PCRs, the first audio) are held until it's seen.
class TsSplicer {
  static const packetSize = 188;
  static const _wrap = 1 << 33;

  /// One frame at 29.97 fps, in 90 kHz ticks.
  static const frameTicks = 3003;

  /// Packets held while looking for a segment's first video PTS, at most.
  static const _maxHeld = 4 << 20;

  /// Where the next segment starts, in 90 kHz ticks from the first.
  int clock = 0;

  final _cc = <int, int>{};

  // The segment being written.
  final _carry = BytesBuilder(copy: false);
  final _held = BytesBuilder(copy: false);
  int? _shift;
  int? _firstVideoPts;
  int? _maxVideoRel;
  bool _sawAudio = false;
  bool _open = false;

  /// [clock] in seconds.
  double get clockSeconds => clock / 90000;

  /// Whether the segment being written (or the last one) had any audio.
  bool get sawAudio => _sawAudio;

  /// Starts a segment.
  void begin() {
    _carry.clear();
    _held.clear();
    _shift = null;
    _firstVideoPts = null;
    _maxVideoRel = null;
    _sawAudio = false;
    _open = true;
  }

  /// Rewrites [data] (the segment's next bytes, cut anywhere) and returns
  /// what can be written now: whole packets, once the shift is known.
  Uint8List add(List<int> data) {
    assert(_open, 'begin() first');
    _carry.add(data);
    final all = _carry.takeBytes();
    final whole = all.length - all.length % packetSize;
    if (whole < all.length) _carry.add(Uint8List.sublistView(all, whole));
    if (whole == 0) return Uint8List(0);
    final packets = Uint8List.sublistView(all, 0, whole);
    if (_shift == null) {
      final first = _findFirstVideoPts(packets);
      _held.add(packets);
      if (first == null && _held.length < _maxHeld) return Uint8List(0);
      _firstVideoPts = first;
      _shift = ((clock - (first ?? 0)) % _wrap + _wrap) % _wrap;
      final held = _held.takeBytes();
      _rewrite(held);
      return held;
    }
    final copy = Uint8List.fromList(packets);
    _rewrite(copy);
    return copy;
  }

  /// Ends the segment: returns any packets still held (a segment with no
  /// video), and moves [clock] past its last frame.
  Uint8List end() {
    var rest = Uint8List(0);
    if (_shift == null && _held.length > 0) {
      _shift = clock % _wrap;
      rest = _held.takeBytes();
      _rewrite(rest);
    }
    final rel = _maxVideoRel;
    if (rel != null) clock += rel + frameTicks;
    _open = false;
    return rest;
  }

  /// One whole segment (a card chunk) at once.
  Uint8List segment(Uint8List chunk) {
    begin();
    final out = BytesBuilder(copy: false)..add(add(chunk))..add(end());
    return out.takeBytes();
  }

  static int? _findFirstVideoPts(Uint8List b) {
    for (var o = 0; o + packetSize <= b.length; o += packetSize) {
      final pes = _pesAt(b, o);
      if (pes != null && pes.video && pes.hasPts) return _readTs(b, pes.offset + 9);
    }
    return null;
  }

  /// The PES header in the packet at [o], if it starts one.
  static ({int offset, bool video, bool audio, bool hasPts, bool hasDts})? _pesAt(Uint8List b, int o) {
    if (b[o + 1] & 0x40 == 0) return null;
    final afc = (b[o + 3] >> 4) & 3;
    if (afc & 1 == 0) return null;
    var p = o + 4;
    if (afc & 2 != 0) p += 1 + b[p];
    if (p + 14 > o + packetSize) return null;
    if (b[p] != 0 || b[p + 1] != 0 || b[p + 2] != 1) return null;
    final sid = b[p + 3];
    final flags = b[p + 7] >> 6;
    return (
      offset: p,
      video: sid >= 0xE0 && sid <= 0xEF,
      audio: (sid >= 0xC0 && sid <= 0xDF) || sid == 0xBD,
      hasPts: flags & 2 != 0,
      hasDts: flags == 3,
    );
  }

  void _rewrite(Uint8List b) {
    final shift = _shift!;
    for (var o = 0; o + packetSize <= b.length; o += packetSize) {
      if (b[o] != 0x47) throw const FormatException('Lost MPEG-TS sync');
      final pid = ((b[o + 1] & 0x1F) << 8) | b[o + 2];
      final afc = (b[o + 3] >> 4) & 3;
      if (afc & 1 != 0) {
        final c = _cc[pid] ?? 0;
        b[o + 3] = (b[o + 3] & 0xF0) | c;
        _cc[pid] = (c + 1) & 0xF;
      }
      if (afc & 2 != 0) {
        final len = b[o + 4];
        if (len > 0 && b[o + 5] & 0x10 != 0) _shiftPcr(b, o + 6, shift);
      }
      final pes = _pesAt(b, o);
      if (pes == null || !pes.hasPts) continue;
      final pts = _readTs(b, pes.offset + 9);
      if (pes.video) {
        final rel = ((pts - _firstVideoPts!) % _wrap + _wrap) % _wrap;
        // Ignore a wrapped-looking value from a frame before the first.
        if (rel < _wrap ~/ 2 && (_maxVideoRel == null || rel > _maxVideoRel!)) _maxVideoRel = rel;
      }
      if (pes.audio) _sawAudio = true;
      _writeTs(b, pes.offset + 9, pts + shift, pes.hasDts ? 3 : 2);
      if (pes.hasDts && pes.offset + 19 <= o + packetSize) {
        _writeTs(b, pes.offset + 14, _readTs(b, pes.offset + 14) + shift, 1);
      }
    }
  }

  static int _readTs(Uint8List b, int o) =>
      ((b[o] >> 1) & 7) << 30 | b[o + 1] << 22 | (b[o + 2] >> 1) << 15 | b[o + 3] << 7 | b[o + 4] >> 1;

  static void _writeTs(Uint8List b, int o, int value, int prefix) {
    final v = value % _wrap;
    b[o] = (prefix << 4) | (((v >> 30) & 7) << 1) | 1;
    b[o + 1] = (v >> 22) & 0xFF;
    b[o + 2] = (((v >> 15) & 0x7F) << 1) | 1;
    b[o + 3] = (v >> 7) & 0xFF;
    b[o + 4] = ((v & 0x7F) << 1) | 1;
  }

  static void _shiftPcr(Uint8List b, int q, int shift) {
    final base = (b[q] << 25 | b[q + 1] << 17 | b[q + 2] << 9 | b[q + 3] << 1 | b[q + 4] >> 7) + shift;
    final v = base % _wrap;
    final ext = ((b[q + 4] & 1) << 8) | b[q + 5];
    b[q] = (v >> 25) & 0xFF;
    b[q + 1] = (v >> 17) & 0xFF;
    b[q + 2] = (v >> 9) & 0xFF;
    b[q + 3] = (v >> 1) & 0xFF;
    b[q + 4] = ((v & 1) << 7) | 0x7E | (ext >> 8);
    b[q + 5] = ext & 0xFF;
  }
}
