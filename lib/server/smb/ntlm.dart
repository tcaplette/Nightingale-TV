import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The parts of NTLM an SMB1 sign-in needs: NTLMv2 responses and the
/// messages of an NTLMSSP exchange.
abstract final class Ntlm {
  static const _signature = [0x4E, 0x54, 0x4C, 0x4D, 0x53, 0x53, 0x50, 0]; // NTLMSSP

  /// Unicode, request target, NTLM, always sign, extended session security,
  /// target info, 128-bit, 56-bit, sign.
  static const _flags = 0x00000001 | 0x00000004 | 0x00000010 | 0x00000200 | 0x00008000 | 0x00080000 | 0x00800000 | 0x20000000;
  static const _anonymous = 0x00000800;

  static Uint8List utf16(String s) {
    final out = Uint8List(s.length * 2);
    for (var i = 0; i < s.length; i++) {
      out[i * 2] = s.codeUnitAt(i) & 0xFF;
      out[i * 2 + 1] = s.codeUnitAt(i) >> 8;
    }
    return out;
  }

  static Uint8List _hmac(List<int> key, List<int> data) => Uint8List.fromList(Hmac(md5, key).convert(data).bytes);

  static Uint8List ntHash(String password) => md4(utf16(password));

  static Uint8List v2Hash(String user, String password, String domain) =>
      _hmac(ntHash(password), utf16(user.toUpperCase() + domain));

  static Uint8List randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList([for (var i = 0; i < n; i++) r.nextInt(256)]);
  }

  /// The NTLMv2 and LMv2 answers to [challenge], and the session key.
  static ({Uint8List nt, Uint8List lm, Uint8List sessionKey}) respond({
    required String user,
    required String password,
    required String domain,
    required List<int> challenge,
    required List<int> targetInfo,
    Uint8List? clientChallenge,
    DateTime? now,
  }) {
    final mine = clientChallenge ?? randomBytes(8);
    final hash = v2Hash(user, password, domain);
    final time = ByteData(8);
    // 100 ns units since 1601.
    final ticks = ((now ?? DateTime.now()).toUtc().microsecondsSinceEpoch + 11644473600000000) * 10;
    time.setUint64(0, ticks, Endian.little);
    final temp = BytesBuilder()
      ..add(const [1, 1, 0, 0, 0, 0, 0, 0])
      ..add(_avTime(targetInfo) ?? time.buffer.asUint8List())
      ..add(mine)
      ..add(const [0, 0, 0, 0])
      ..add(targetInfo)
      ..add(const [0, 0, 0, 0]);
    final blob = temp.toBytes();
    final proof = _hmac(hash, [...challenge, ...blob]);
    return (
      nt: Uint8List.fromList([...proof, ...blob]),
      lm: Uint8List.fromList([..._hmac(hash, [...challenge, ...mine]), ...mine]),
      sessionKey: _hmac(hash, proof),
    );
  }

  /// The host's own time in its target info (MsvAvTimestamp), which the
  /// answer should carry.
  static Uint8List? _avTime(List<int> info) {
    var i = 0;
    while (i + 4 <= info.length) {
      final id = info[i] | info[i + 1] << 8, len = info[i + 2] | info[i + 3] << 8;
      if (id == 0) return null;
      if (id == 7 && len == 8 && i + 12 <= info.length) return Uint8List.fromList(info.sublist(i + 4, i + 12));
      i += 4 + len;
    }
    return null;
  }

  /// The first message.
  static Uint8List negotiate() {
    final b = ByteData(32);
    for (var i = 0; i < 8; i++) {
      b.setUint8(i, _signature[i]);
    }
    b.setUint32(8, 1, Endian.little);
    b.setUint32(12, _flags, Endian.little);
    return b.buffer.asUint8List();
  }

  /// The host's challenge message: its challenge and target info.
  static ({Uint8List challenge, Uint8List targetInfo, String target})? parseChallenge(Uint8List m) {
    if (m.length < 32) return null;
    for (var i = 0; i < 8; i++) {
      if (m[i] != _signature[i]) return null;
    }
    final d = ByteData.sublistView(m);
    if (d.getUint32(8, Endian.little) != 2) return null;
    Uint8List field(int at) {
      if (at + 8 > m.length) return Uint8List(0);
      final len = d.getUint16(at, Endian.little), off = d.getUint32(at + 4, Endian.little);
      return off + len > m.length ? Uint8List(0) : Uint8List.sublistView(m, off, off + len);
    }

    final target = field(12);
    return (
      challenge: Uint8List.sublistView(m, 24, 32),
      targetInfo: m.length >= 48 ? field(40) : Uint8List(0),
      target: String.fromCharCodes([for (var i = 0; i + 1 < target.length; i += 2) target[i] | target[i + 1] << 8]),
    );
  }

  /// The last message, answering [challenge] (see [parseChallenge]); a
  /// guest's has no name and no answer. Returns it and the session key.
  static ({Uint8List message, Uint8List? sessionKey}) authenticate({
    required String user,
    required String password,
    required String domain,
    required ({Uint8List challenge, Uint8List targetInfo, String target}) challenge,
  }) {
    final guest = user.isEmpty;
    final answer = guest
        ? null
        : respond(
            user: user,
            password: password,
            domain: domain,
            challenge: challenge.challenge,
            targetInfo: challenge.targetInfo);
    final parts = [
      answer?.lm ?? Uint8List(1),
      answer?.nt ?? Uint8List(0),
      utf16(domain),
      utf16(user),
      utf16('NIGHTINGALETV'),
      Uint8List(0),
    ];
    const header = 64;
    final out = BytesBuilder();
    final head = ByteData(header);
    for (var i = 0; i < 8; i++) {
      head.setUint8(i, _signature[i]);
    }
    head.setUint32(8, 3, Endian.little);
    var offset = header;
    for (final (i, p) in parts.indexed) {
      head.setUint16(12 + i * 8, p.length, Endian.little);
      head.setUint16(14 + i * 8, p.length, Endian.little);
      head.setUint32(16 + i * 8, offset, Endian.little);
      offset += p.length;
    }
    head.setUint32(60, _flags | (guest ? _anonymous : 0), Endian.little);
    out.add(head.buffer.asUint8List());
    parts.forEach(out.add);
    return (message: out.toBytes(), sessionKey: answer?.sessionKey);
  }

  /// MD4 (RFC 1320), which NTLM hashes passwords with.
  static Uint8List md4(List<int> message) {
    final length = message.length;
    final padded = Uint8List(((length + 8) ~/ 64 + 1) * 64)
      ..setRange(0, length, message)
      ..[length] = 0x80;
    ByteData.sublistView(padded).setUint64(padded.length - 8, length * 8, Endian.little);
    var a = 0x67452301, b = 0xefcdab89, c = 0x98badcfe, d = 0x10325476;
    int rotl(int x, int s) => ((x << s) | ((x & 0xFFFFFFFF) >> (32 - s))) & 0xFFFFFFFF;
    final words = ByteData.sublistView(padded);
    for (var o = 0; o < padded.length; o += 64) {
      int x(int i) => words.getUint32(o + i * 4, Endian.little);
      final aa = a, bb = b, cc = c, dd = d;
      void round(int Function(int, int, int) f, int add, List<int> order, List<int> shifts) {
        for (var i = 0; i < 16; i++) {
          final t = rotl((a + f(b, c, d) + x(order[i]) + add) & 0xFFFFFFFF, shifts[i % 4]);
          (a, d, c, b) = (d, c, b, t);
        }
      }

      round((x, y, z) => (x & y) | (~x & 0xFFFFFFFF & z), 0, [for (var i = 0; i < 16; i++) i], const [3, 7, 11, 19]);
      round((x, y, z) => (x & y) | (x & z) | (y & z), 0x5a827999,
          const [0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15], const [3, 5, 9, 13]);
      round((x, y, z) => x ^ y ^ z, 0x6ed9eba1,
          const [0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15], const [3, 9, 11, 15]);
      a = (a + aa) & 0xFFFFFFFF;
      b = (b + bb) & 0xFFFFFFFF;
      c = (c + cc) & 0xFFFFFFFF;
      d = (d + dd) & 0xFFFFFFFF;
    }
    final out = ByteData(16);
    for (final (i, v) in [a, b, c, d].indexed) {
      out.setUint32(i * 4, v, Endian.little);
    }
    return out.buffer.asUint8List();
  }
}
