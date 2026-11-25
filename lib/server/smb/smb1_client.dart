import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'ntlm.dart';
import 'smb_share.dart';

/// One connection to a host that only speaks SMB1 (design D2): sign-in,
/// the requests a share needs, and the share list. Many requests can be
/// under way at once. Everything throws [SmbException].
class Smb1Client {
  Smb1Client._(this._socket, this.host);

  /// Connects to [address]'s host and asks what it speaks. [smb2] is true
  /// when it speaks SMB 2 or 3 (the connection is closed then): SMB1 is
  /// only for hosts that speak nothing newer.
  static Future<({Smb1Client? client, bool smb2})> negotiate(SmbAddress address) async {
    final Socket socket;
    try {
      socket = await Socket.connect(address.host, address.port, timeout: connectTimeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
    } on SocketException catch (e) {
      throw SmbException(SmbErrorKind.unreachable, e.message);
    }
    final client = Smb1Client._(socket, address.host);
    client._listen();
    try {
      final smb2 = await client._negotiate();
      if (smb2) {
        await client.close();
        return (client: null, smb2: true);
      }
      return (client: client, smb2: false);
    } on Object {
      await client.close();
      rethrow;
    }
  }

  static const connectTimeout = Duration(seconds: 8);
  static const requestTimeout = Duration(seconds: 12);

  final Socket _socket;
  final String host;

  // Commands.
  static const _createFolder = 0x00, _close = 0x04, _deleteFile = 0x06, _renameFile = 0x07;
  static const _readAndX = 0x2E, _writeAndX = 0x2F, _transaction = 0x25, _trans2 = 0x32;
  static const _negotiateCmd = 0x72, _sessionSetup = 0x73, _logoff = 0x74, _treeConnect = 0x75, _ntCreate = 0xA2;

  /// Long names, signatures allowed, extended security, NT status, Unicode.
  static const _flags2Base = 0x0001 | 0x4000 | 0x8000;
  static const _extendedSecurity = 0x0800;
  static const _signaturesFlag = 0x0004;

  static const _moreProcessing = 0xC0000016;

  // What the host said.
  bool _hostExtended = false;
  bool _signingRequired = false;
  int _maxBuffer = 4356;
  int _capabilities = 0;
  int _sessionId = 0;
  Uint8List _challenge = Uint8List(0);
  int _uid = 0;
  final int _pid = pid & 0xFFFF;

  Uint8List? _signKey;
  int _sequence = 0;

  int _mid = 1;
  final _waiting = <int, _Pending>{};
  bool _closed = false;
  SmbException? _lost;

  // ---- Transport -------------------------------------------------------------

  final _buffer = BytesBuilder(copy: false);
  Uint8List _rest = Uint8List(0);

  void _listen() {
    _socket.listen((data) {
      _buffer.add(_rest);
      _buffer.add(data);
      _rest = _buffer.takeBytes();
      _drain();
    }, onError: (Object e) => _fail(SmbException(SmbErrorKind.unreachable, 'connection lost: $e')), onDone: () {
      _fail(const SmbException(SmbErrorKind.unreachable, 'the host closed the connection'));
    });
    // Write errors come here as well as to the stream.
    _socket.done.then((_) {}, onError: (Object _) {});
  }

  void _drain() {
    var at = 0;
    while (_rest.length - at >= 4) {
      final type = _rest[at];
      final length = _rest[at + 1] << 16 | _rest[at + 2] << 8 | _rest[at + 3];
      if (_rest.length - at - 4 < length) break;
      final message = Uint8List.sublistView(_rest, at + 4, at + 4 + length);
      at += 4 + length;
      // Keep-alives and other NetBIOS messages hold nothing.
      if (type == 0 && length > 0) _receive(message);
    }
    if (at > 0) _rest = Uint8List.sublistView(_rest, at);
  }

  void _receive(Uint8List m) {
    if (m.length >= 4 && m[0] == 0xFE) {
      // An SMB 2 answer to the negotiate request.
      final pending = _waiting.remove(_waiting.keys.firstOrNull);
      pending?.done.completeError(const _SpeaksSmb2());
      return;
    }
    if (m.length < 35 || m[0] != 0xFF || m[1] != 0x53 || m[2] != 0x4D || m[3] != 0x42) {
      _fail(const SmbException(SmbErrorKind.other, 'not an SMB answer'));
      return;
    }
    final d = ByteData.sublistView(m);
    final mid = d.getUint16(30, Endian.little);
    final pending = _waiting[mid];
    if (pending == null) return;
    final key = _signKey;
    if (key != null && pending.sequence >= 0 && !_verify(key, m, pending.sequence + 1)) {
      _fail(const SmbException(SmbErrorKind.other, 'an answer was not signed as agreed'));
      return;
    }
    final answer = _Answer(m);
    // A transaction's answer can come in several messages.
    if (pending.collect case final collect?) {
      try {
        if (!collect(answer)) return;
      } on Object catch (e, s) {
        _waiting.remove(mid);
        pending.done.completeError(e, s);
        return;
      }
    }
    _waiting.remove(mid);
    pending.done.complete(answer);
  }

  void _fail(SmbException e) {
    _lost ??= e;
    final waiting = [..._waiting.values];
    _waiting.clear();
    for (final p in waiting) {
      if (!p.done.isCompleted) p.done.completeError(e);
    }
    _socket.destroy();
  }

  bool get isOpen => !_closed && _lost == null;

  Future<void> close() async {
    if (_closed) return;
    if (_lost == null && _uid != 0) {
      try {
        await _send(_logoff, _Words()..andX(), const []).timeout(const Duration(seconds: 1));
      } on Object {
        // Closing anyway.
      }
    }
    _closed = true;
    _fail(const SmbException(SmbErrorKind.unreachable, 'closed'));
  }

  static bool _verify(Uint8List key, Uint8List m, int sequence) {
    final copy = Uint8List.fromList(m);
    final mine = _mac(key, copy, sequence);
    for (var i = 0; i < 8; i++) {
      if (m[14 + i] != mine[i]) return false;
    }
    return true;
  }

  /// The signature of [m] (whose signature field is overwritten).
  static List<int> _mac(Uint8List key, Uint8List m, int sequence) {
    final d = ByteData.sublistView(m);
    d.setUint32(14, sequence, Endian.little);
    d.setUint32(18, 0, Endian.little);
    return md5.convert([...key, ...m]).bytes.sublist(0, 8);
  }

  Future<_Answer> _send(int command, _Words words, List<int> data,
      {int tree = 0, int flags2 = 0, bool Function(_Answer answer)? collect, Duration timeout = requestTimeout}) {
    if (_lost case final e?) return Future.error(e);
    do {
      _mid = _mid % 0xFFF0 + 1;
    } while (_waiting.containsKey(_mid));
    final mid = _mid;
    final w = words.bytes;
    final m = Uint8List(32 + 1 + w.length + 2 + data.length);
    final d = ByteData.sublistView(m);
    m.setAll(0, const [0xFF, 0x53, 0x4D, 0x42]);
    m[4] = command;
    m[9] = 0x18; // Case-insensitive, canonical paths.
    d.setUint16(10, _flags2Base | (_hostExtended ? _extendedSecurity : 0) | (_signKey != null ? _signaturesFlag : 0) | flags2,
        Endian.little);
    d.setUint16(24, tree, Endian.little);
    d.setUint16(26, _pid, Endian.little);
    d.setUint16(28, _uid, Endian.little);
    d.setUint16(30, mid, Endian.little);
    m[32] = w.length ~/ 2;
    m.setAll(33, w);
    d.setUint16(33 + w.length, data.length, Endian.little);
    m.setAll(35 + w.length, data);
    var sequence = -1;
    if (_signKey case final key?) {
      sequence = _sequence;
      _sequence += 2;
      m.setAll(14, _mac(key, m, sequence));
    }
    final pending = _Pending(sequence, collect);
    _waiting[mid] = pending;
    _socket.add([0, m.length >> 16 & 0xFF, m.length >> 8 & 0xFF, m.length & 0xFF]);
    _socket.add(m);
    return pending.done.future.timeout(timeout, onTimeout: () {
      _waiting.remove(mid);
      // Answers out of step can't be told apart any more.
      const e = SmbException(SmbErrorKind.unreachable, 'the host took too long to answer');
      _fail(e);
      throw e;
    });
  }

  static Never _throw(int status, {bool guest = false}) {
    final kind = switch (status) {
      0xC000006D || 0xC000006A || 0xC0000064 || 0xC0000234 || 0xC0000072 || 0xC000006E || 0xC000015B || 0xC0000071 ||
      0xC0000193 || 0xC0000224 =>
        guest ? SmbErrorKind.guestsRefused : SmbErrorKind.wrongSignIn,
      0xC0000022 => guest ? SmbErrorKind.guestsRefused : SmbErrorKind.noAccess,
      0xC00000A2 || 0xC0000061 => SmbErrorKind.noAccess,
      0xC0000034 || 0xC000003A || 0xC000000F || 0xC00000CC || 0xC0000033 || 0xC0000103 || 0xC00000BA || 0xC0000039 =>
        SmbErrorKind.gone,
      _ => SmbErrorKind.other,
    };
    throw SmbException(kind, 'SMB1 status 0x${status.toRadixString(16)}');
  }

  // ---- Sign-in ---------------------------------------------------------------

  Future<bool> _negotiate() async {
    final dialects = BytesBuilder();
    for (final name in const ['NT LM 0.12', 'SMB 2.002', 'SMB 2.???']) {
      dialects
        ..addByte(2)
        ..add(name.codeUnits)
        ..addByte(0);
    }
    final _Answer a;
    try {
      a = await _send(_negotiateCmd, _Words(), dialects.toBytes(), flags2: _extendedSecurity, timeout: connectTimeout);
    } on _SpeaksSmb2 {
      return true;
    }
    if (a.status != 0) _throw(a.status);
    if (a.words.length < 34 || a.word(0) != 0) throw const SmbException(SmbErrorKind.other, 'no SMB dialect in common');
    final d = ByteData.sublistView(a.words);
    _signingRequired = a.words[2] & 0x08 != 0;
    _maxBuffer = d.getUint32(7, Endian.little);
    _sessionId = d.getUint32(15, Endian.little);
    _capabilities = d.getUint32(19, Endian.little);
    _hostExtended = _capabilities & 0x80000000 != 0;
    if (!_hostExtended) {
      final length = a.words[33];
      _challenge = Uint8List.fromList(a.data.sublist(0, length.clamp(0, a.data.length)));
    }
    return false;
  }

  Future<void> signIn(SmbCredentials who) async {
    if (who.isGuest && _signingRequired) {
      throw const SmbException(SmbErrorKind.guestsRefused, 'the host requires signing, which a guest cannot');
    }
    final key = _hostExtended ? await _extendedSignIn(who) : await _plainSignIn(who);
    if (key != null && _signingRequired) {
      _signKey = key;
      // The session setup took the first two numbers.
      _sequence = 2;
    }
  }

  _Words _setupWords() => _Words()
    ..andX()
    ..u16(_maxBuffer.clamp(1024, 0xFFFF))
    ..u16(50)
    ..u16(0)
    ..u32(_sessionId);

  /// Unicode, large files, NT SMBs, RPC, NT status, large reads and writes,
  /// extended security.
  static const _clientCapabilities = 0x00000004 | 0x00000008 | 0x00000010 | 0x00000020 | 0x00000040 | 0x00004000 | 0x00008000;

  static Uint8List _names(int dataStart, List<String> names) {
    final out = BytesBuilder();
    // Unicode strings start on an even offset of the message.
    if (dataStart.isOdd) out.addByte(0);
    for (final n in names) {
      out
        ..add(Ntlm.utf16(n))
        ..add(const [0, 0]);
    }
    return out.toBytes();
  }

  Future<Uint8List?> _extendedSignIn(SmbCredentials who) async {
    Future<_Answer> step(Uint8List blob) {
      final words = _setupWords()
        ..u16(blob.length)
        ..u32(0)
        ..u32(_clientCapabilities | 0x80000000);
      final start = 35 + words.bytes.length + blob.length;
      return _send(_sessionSetup, words, [...blob, ..._names(start, const ['Nightingale TV', 'Nightingale TV'])]);
    }

    final first = await step(Ntlm.negotiate());
    if (first.status != _moreProcessing) _throw(first.status == 0 ? 0xC000006D : first.status, guest: who.isGuest);
    _uid = first.uid;
    final length = first.word(3);
    final challenge =
        length > first.data.length ? null : Ntlm.parseChallenge(Uint8List.fromList(_unwrap(first.data.sublist(0, length))));
    if (challenge == null) throw const SmbException(SmbErrorKind.other, 'no NTLM challenge');
    final auth = Ntlm.authenticate(user: who.user, password: who.password, domain: who.domain, challenge: challenge);
    final second = await step(auth.message);
    if (second.status != 0) _throw(second.status, guest: who.isGuest);
    _uid = second.uid;
    _rejectGuest(second, who);
    return auth.sessionKey;
  }

  /// The NTLM message inside [blob] (some hosts answer in SPNEGO).
  static List<int> _unwrap(List<int> blob) {
    for (var i = 0; i + 8 <= blob.length; i++) {
      if (blob[i] == 0x4E && blob[i + 1] == 0x54 && blob[i + 2] == 0x4C && blob[i + 3] == 0x4D && blob[i + 4] == 0x53) {
        return blob.sublist(i);
      }
    }
    return blob;
  }

  Future<Uint8List?> _plainSignIn(SmbCredentials who) async {
    final answer = who.isGuest
        ? null
        : Ntlm.respond(
            user: who.user, password: who.password, domain: who.domain, challenge: _challenge, targetInfo: const []);
    final lm = answer?.lm ?? Uint8List(1), nt = answer?.nt ?? Uint8List(0);
    final words = _setupWords()
      ..u16(lm.length)
      ..u16(nt.length)
      ..u32(0)
      ..u32(_clientCapabilities);
    final start = 35 + words.bytes.length + lm.length + nt.length;
    final a = await _send(_sessionSetup, words,
        [...lm, ...nt, ..._names(start, [who.user, who.domain, 'Nightingale TV', 'Nightingale TV'])]);
    if (a.status != 0) _throw(a.status, guest: who.isGuest);
    _uid = a.uid;
    _rejectGuest(a, who);
    return answer?.sessionKey;
  }

  /// A host that lets a wrong name in as a guest hasn't signed anyone in.
  void _rejectGuest(_Answer a, SmbCredentials who) {
    if (!who.isGuest && a.word(2) & 1 != 0) {
      throw const SmbException(SmbErrorKind.wrongSignIn, 'signed in as a guest instead');
    }
  }

  // ---- Requests --------------------------------------------------------------

  Future<int> connectTree(String share, {required bool guest}) async {
    final words = _Words()
      ..andX()
      ..u16(0)
      ..u16(1);
    final start = 35 + words.bytes.length + 1;
    final path = _names(start, ['\\\\$host\\$share']);
    final a = await _send(_treeConnect, words, [0, ...path, ...'?????'.codeUnits, 0]);
    if (a.status != 0) _throw(a.status, guest: guest);
    return a.tree;
  }

  /// [path] as a request's data holds it, starting at [dataStart].
  static Uint8List _path(int dataStart, String path) => _names(dataStart, ['\\${path.replaceAll('/', r'\')}']);

  static const readAccess = 0x00020089, writeAccess = 0x0012019F, listAccess = 0x00100081;

  Future<({int fid, SmbEntry entry})> openFile(int tree, String path,
      {int access = readAccess, int disposition = 1, int options = 0x40, String? pipe}) async {
    final name = Ntlm.utf16(pipe ?? path.replaceAll('/', r'\'));
    final words = _Words()
      ..andX()
      ..u8(0)
      ..u16(name.length)
      ..u32(0)
      ..u32(0)
      ..u32(access)
      ..u64(0)
      ..u32(0x80)
      ..u32(0x07)
      ..u32(disposition)
      ..u32(options)
      ..u32(2)
      ..u8(0);
    final start = 35 + words.bytes.length;
    final a = await _send(_ntCreate, words, [if (start.isOdd) 0, ...name, 0, 0], tree: tree);
    if (a.status != 0) _throw(a.status);
    final d = ByteData.sublistView(a.words);
    final attributes = d.getUint32(43, Endian.little);
    return (
      fid: d.getUint16(5, Endian.little),
      entry: SmbEntry(
        name: path.split('/').last,
        isFolder: attributes & 0x10 != 0,
        size: d.getUint64(55, Endian.little),
        created: _time(d.getInt64(11, Endian.little)),
        modified: _time(d.getInt64(27, Endian.little)),
        hidden: attributes & 0x6 != 0,
      ),
    );
  }

  Future<void> closeFile(int tree, int fid) async {
    final a = await _send(_close, _Words()..u16(fid)..u32(0xFFFFFFFF), const [], tree: tree);
    if (a.status != 0) _throw(a.status);
  }

  /// The most one read asks for.
  int get _readSize => _capabilities & 0x4000 != 0 ? 0xF000 : (_maxBuffer - 64).clamp(512, 0xF000);
  int get _writeSize => _capabilities & 0x8000 != 0 ? 0xF000 : (_maxBuffer - 96).clamp(512, 0xF000);

  /// [length] bytes at [offset], in several requests at once.
  Future<Uint8List> read(int tree, int fid, int offset, int length) async {
    if (length <= 0) return Uint8List(0);
    final out = Uint8List(length);
    final size = _readSize;
    final got = <int, int>{};
    const atOnce = 8;
    for (var start = 0; start < length; start += size * atOnce) {
      await Future.wait([
        for (var at = start; at < length && at < start + size * atOnce; at += size)
          _readOnce(tree, fid, offset + at, (length - at).clamp(0, size)).then((data) {
            out.setAll(at, data);
            got[at] = data.length;
          }),
      ], eagerError: true);
    }
    // The bytes up to the first short read (the end of the file).
    var total = 0;
    for (var at = 0; at < length; at += size) {
      final n = got[at] ?? 0;
      total += n;
      if (n < (length - at).clamp(0, size)) break;
    }
    return total == length ? out : Uint8List.sublistView(out, 0, total);
  }

  Future<Uint8List> _readOnce(int tree, int fid, int offset, int length) async {
    final words = _Words()
      ..andX()
      ..u16(fid)
      ..u32(offset & 0xFFFFFFFF)
      ..u16(length)
      ..u16(length)
      ..u32(0)
      ..u16(0)
      ..u32(offset >> 32);
    final a = await _send(_readAndX, words, const [], tree: tree);
    if (a.status == 0xC0000011) return Uint8List(0); // End of file.
    if (a.status != 0) _throw(a.status);
    final count = a.word(5) | a.word(7) << 16, at = a.word(6);
    return Uint8List.sublistView(a.message, at, at + count);
  }

  Future<void> write(int tree, int fid, Uint8List data) async {
    final size = _writeSize;
    for (var at = 0; at < data.length; at += size) {
      final part = Uint8List.sublistView(data, at, (at + size).clamp(0, data.length));
      const start = 32 + 1 + 28 + 2;
      final words = _Words()
        ..andX()
        ..u16(fid)
        ..u32(at & 0xFFFFFFFF)
        ..u32(0)
        ..u16(1) // Through to the disk.
        ..u16(0)
        ..u16(part.length >> 16)
        ..u16(part.length & 0xFFFF)
        ..u16(start + 1)
        ..u32(at >> 32);
      final a = await _send(_writeAndX, words, [0, ...part], tree: tree);
      if (a.status != 0) _throw(a.status);
    }
  }

  Future<void> makeFolder(int tree, String path) async {
    final a = await _send(_createFolder, _Words(), [4, ..._path(36, path)], tree: tree);
    // Already there.
    if (a.status != 0 && a.status != 0xC0000035) _throw(a.status);
  }

  Future<void> delete(int tree, String path) async {
    final words = _Words()..u16(0x06);
    final a = await _send(_deleteFile, words, [4, ..._path(35 + 2 + 1, path)], tree: tree);
    if (a.status != 0) _throw(a.status);
  }

  Future<void> rename(int tree, String from, String to) async {
    final words = _Words()..u16(0x16);
    final first = [4, ..._path(35 + 2 + 1, from)];
    final second = [4, ..._path(35 + 2 + first.length + 1, to)];
    final a = await _send(_renameFile, words, [...first, ...second], tree: tree);
    if (a.status != 0) _throw(a.status);
  }

  /// A Trans2 request's answer: its parameters and data.
  Future<({Uint8List params, Uint8List data})> _transact2(int tree, int function, List<int> params) =>
      _transact(_trans2, tree, [function], params, const [], name: null);

  Future<({Uint8List params, Uint8List data})> _transact(int command, int tree, List<int> setup, List<int> params, List<int> data,
      {required String? name}) async {
    final nameBytes = name == null ? const [0, 0, 0] : [0, ...Ntlm.utf16(name), 0, 0];
    final words = 14 + setup.length;
    var paramsAt = 32 + 1 + words * 2 + 2 + nameBytes.length;
    final pad = (4 - paramsAt % 4) % 4;
    paramsAt += pad;
    final pad2 = (4 - (paramsAt + params.length) % 4) % 4;
    final dataAt = paramsAt + params.length + pad2;
    final w = _Words()
      ..u16(params.length)
      ..u16(data.length)
      ..u16(10)
      ..u16((_maxBuffer - 80).clamp(1024, 0xFF00))
      ..u8(0)
      ..u8(0)
      ..u16(0)
      ..u32(0)
      ..u16(0)
      ..u16(params.length)
      ..u16(paramsAt)
      ..u16(data.length)
      ..u16(dataAt)
      ..u8(setup.length)
      ..u8(0);
    setup.forEach(w.u16);
    Uint8List? outParams, outData;
    var gotParams = 0, gotData = 0;
    final a = await _send(
        command, w, [...nameBytes, ...List.filled(pad, 0), ...params, ...List.filled(pad2, 0), ...data], tree: tree,
        collect: (part) {
      if (part.status != 0 && part.status != 0x80000005 || part.words.length < 20) return true;
      final totalParams = part.word(0), totalData = part.word(1);
      outParams ??= Uint8List(totalParams);
      outData ??= Uint8List(totalData);
      final pCount = part.word(3), pAt = part.word(4), pTo = part.word(5);
      final dCount = part.word(6), dAt = part.word(7), dTo = part.word(8);
      outParams!.setAll(pTo, Uint8List.sublistView(part.message, pAt, pAt + pCount));
      outData!.setAll(dTo, Uint8List.sublistView(part.message, dAt, dAt + dCount));
      gotParams += pCount;
      gotData += dCount;
      return gotParams >= totalParams && gotData >= totalData;
    });
    if (a.status != 0 && a.status != 0x80000005) _throw(a.status);
    return (params: outParams ?? Uint8List(0), data: outData ?? Uint8List(0));
  }

  static DateTime? _time(int ticks) => ticks <= 0
      ? null
      : DateTime.fromMicrosecondsSinceEpoch(ticks ~/ 10 - 11644473600000000, isUtc: true);

  /// The host refused file ids (an old device): listings and stats go
  /// without them.
  bool _noIds = false;

  Future<List<SmbEntry>> list(int tree, String path) async {
    if (!_noIds) {
      try {
        return await _list(tree, path, ids: true);
      } on SmbException catch (e) {
        if (e.kind != SmbErrorKind.other) rethrow;
        _noIds = true;
      }
    }
    return _list(tree, path, ids: false);
  }

  /// FIND_FIRST2 at SMB_FIND_FILE_ID_FULL_DIRECTORY_INFO (with each file's
  /// id, which stays the same across renames), or with [ids] false
  /// SMB_FIND_FILE_BOTH_DIRECTORY_INFO.
  Future<List<SmbEntry>> _list(int tree, String path, {required bool ids}) async {
    final out = <SmbEntry>[];
    final nameAt = ids ? 80 : 94;
    void collect(Uint8List data, int count) {
      var at = 0;
      for (var i = 0; i < count && at + nameAt <= data.length; i++) {
        final d = ByteData.sublistView(data, at);
        final next = d.getUint32(0, Endian.little);
        final attributes = d.getUint32(56, Endian.little);
        final length = d.getUint32(60, Endian.little);
        final raw = Uint8List.sublistView(data, at + nameAt, (at + nameAt + length).clamp(0, data.length));
        final name = _unicode(raw);
        if (name != '.' && name != '..') {
          out.add(SmbEntry(
            name: name,
            isFolder: attributes & 0x10 != 0,
            size: d.getUint64(40, Endian.little),
            created: _time(d.getInt64(8, Endian.little)),
            modified: _time(d.getInt64(24, Endian.little)),
            hidden: attributes & 0x6 != 0,
            fileId: ids ? d.getUint64(72, Endian.little) : 0,
          ));
        }
        if (next == 0) break;
        at += next;
      }
    }

    const perAnswer = 500;
    final level = ids ? 0x0105 : 0x0104;
    final pattern = path.isEmpty ? r'\*' : '\\${path.replaceAll('/', r'\')}\\*';
    final first = await _transact2(tree, 1, [
      ...(_Words()..u16(0x16)..u16(perAnswer)..u16(0x0002)..u16(level)..u32(0)).bytes,
      ...Ntlm.utf16(pattern),
      0,
      0,
    ]);
    final p = ByteData.sublistView(first.params);
    final search = p.getUint16(0, Endian.little);
    collect(first.data, p.getUint16(2, Endian.little));
    var end = p.getUint16(4, Endian.little) != 0;
    while (!end) {
      final lastName = out.isEmpty ? '' : out.last.name;
      final next = await _transact2(tree, 2, [
        // Continue where the last one ended, close at the end.
        ...(_Words()..u16(search)..u16(perAnswer)..u16(level)..u32(0)..u16(0x000A)).bytes,
        ...Ntlm.utf16(lastName),
        0,
        0,
      ]);
      final n = ByteData.sublistView(next.params);
      final count = n.getUint16(0, Endian.little);
      collect(next.data, count);
      end = n.getUint16(2, Endian.little) != 0 || count == 0;
    }
    return out;
  }

  static String _unicode(Uint8List raw) =>
      String.fromCharCodes([for (var i = 0; i + 1 < raw.length; i += 2) raw[i] | raw[i + 1] << 8]);

  Future<SmbEntry> stat(int tree, String path) async {
    final full = path.isEmpty ? r'\' : '\\${path.replaceAll('/', r'\')}';
    // SMB_QUERY_FILE_ALL_INFO.
    final r = await _transact2(tree, 5, [...(_Words()..u16(0x0107)..u32(0)).bytes, ...Ntlm.utf16(full), 0, 0]);
    final d = ByteData.sublistView(r.data);
    final attributes = d.getUint32(32, Endian.little);
    var fileId = 0;
    // Only from a host that takes pass-through levels (CAP_INFOLEVEL_PASSTHRU).
    if (!_noIds && _capabilities & 0x2000 != 0) {
      try {
        // FileInternalInformation, passed through: the file's id.
        final i = await _transact2(tree, 5, [...(_Words()..u16(1000 + 6)..u32(0)).bytes, ...Ntlm.utf16(full), 0, 0]);
        if (i.data.length >= 8) fileId = ByteData.sublistView(i.data).getUint64(0, Endian.little);
      } on SmbException catch (e) {
        if (e.kind != SmbErrorKind.other) rethrow;
        _noIds = true;
      }
    }
    return SmbEntry(
      name: path.split('/').last,
      isFolder: attributes & 0x10 != 0,
      created: _time(d.getInt64(0, Endian.little)),
      modified: _time(d.getInt64(16, Endian.little)),
      size: d.getUint64(48, Endian.little),
      hidden: attributes & 0x6 != 0,
      fileId: fileId,
    );
  }

  // ---- The share list (srvsvc over a named pipe) -------------------------------

  Future<List<SmbShareInfo>> listShares({required bool guest}) async {
    final tree = await connectTree(r'IPC$', guest: guest);
    final pipe = await openFile(tree, 'srvsvc', access: 0x0002019F, pipe: r'\srvsvc');
    try {
      Future<Uint8List> call(List<int> message) async =>
          (await _transact(_transaction, tree, [0x26, pipe.fid], const [], message, name: r'\PIPE\')).data;
      final bound = await call(_bind);
      if (bound.length < 4 || bound[2] != 12) throw const SmbException(SmbErrorKind.other, 'no share list');
      var answer = await call(_shareEnum(host));
      // The rest of a long answer is read from the pipe.
      final total = answer.length >= 10 ? answer[8] | answer[9] << 8 : 0;
      final whole = BytesBuilder()..add(answer);
      while (whole.length < total) {
        final more = await read(tree, pipe.fid, 0, total - whole.length);
        if (more.isEmpty) break;
        whole.add(more);
      }
      return parseShareEnum(whole.toBytes());
    } finally {
      try {
        await closeFile(tree, pipe.fid);
      } on SmbException {
        // The list is what counts.
      }
    }
  }

  /// A DCE/RPC bind to srvsvc 3.0 over NDR.
  static final _bind = <int>[
    5, 0, 11, 3, 0x10, 0, 0, 0, 72, 0, 0, 0, 1, 0, 0, 0, //
    0xB8, 0x10, 0xB8, 0x10, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, //
    0xC8, 0x4F, 0x32, 0x4B, 0x70, 0x16, 0xD3, 0x01, 0x12, 0x78, 0x5A, 0x47, 0xBF, 0x6E, 0xE1, 0x88, 3, 0, 0, 0, //
    0x04, 0x5D, 0x88, 0x8A, 0xEB, 0x1C, 0xC9, 0x11, 0x9F, 0xE8, 0x08, 0x00, 0x2B, 0x10, 0x48, 0x60, 2, 0, 0, 0, //
  ];

  /// NetrShareEnum, level 1.
  static List<int> _shareEnum(String host) {
    final name = Ntlm.utf16('\\\\$host');
    final chars = name.length ~/ 2 + 1;
    final stub = _Words()
      ..u32(0x00020000)
      ..u32(chars)
      ..u32(0)
      ..u32(chars)
      ..raw(name)
      ..u16(0);
    if (chars.isOdd) stub.u16(0);
    stub
      ..u32(1)
      ..u32(1)
      ..u32(0x00020004)
      ..u32(0)
      ..u32(0)
      ..u32(0xFFFFFFFF)
      ..u32(0);
    final body = stub.bytes;
    final head = _Words()
      ..u8(5)
      ..u8(0)
      ..u8(0)
      ..u8(3)
      ..u32(0x10)
      ..u16(24 + body.length)
      ..u16(0)
      ..u32(2)
      ..u32(body.length)
      ..u16(0)
      ..u16(15);
    return [...head.bytes, ...body];
  }

  /// The disk shares in a NetrShareEnum answer, hidden ones left out.
  static List<SmbShareInfo> parseShareEnum(Uint8List m) {
    if (m.length < 48 || m[2] != 2) throw const SmbException(SmbErrorKind.other, 'the host gave no share list');
    final d = ByteData.sublistView(m);
    var at = 24 + 12;
    final count = d.getUint32(at, Endian.little);
    at += 8;
    if (count == 0) return const [];
    at += 4;
    final types = <int>[];
    for (var i = 0; i < count; i++) {
      types.add(d.getUint32(at + 4, Endian.little));
      at += 12;
    }
    String text() {
      final length = d.getUint32(at + 8, Endian.little);
      at += 12;
      final s = _unicode(Uint8List.sublistView(m, at, at + length * 2));
      at += length * 2;
      at += (4 - at % 4) % 4;
      return s.replaceAll('\u0000', '');
    }

    return [
      for (var i = 0; i < count; i++)
        if ((text(), text()) case (final name, final comment))
          if (types[i] & 0xFFFF == 0 && types[i] & 0x80000000 == 0 && !name.endsWith(r'$')) SmbShareInfo(name, comment: comment)
    ];
  }
}

class _SpeaksSmb2 implements Exception {
  const _SpeaksSmb2();
}

class _Pending {
  _Pending(this.sequence, this.collect);

  /// The request's signing number; -1 when it isn't signed.
  final int sequence;

  /// Takes one message of the answer; true when it was the last.
  final bool Function(_Answer answer)? collect;
  final done = Completer<_Answer>();
}

class _Answer {
  _Answer(this.message) : _d = ByteData.sublistView(message);

  final Uint8List message;
  final ByteData _d;

  int get status => _d.getUint32(5, Endian.little);
  int get tree => _d.getUint16(24, Endian.little);
  int get uid => _d.getUint16(28, Endian.little);

  late final Uint8List words = Uint8List.sublistView(message, 33, 33 + message[32] * 2);
  int word(int i) => i * 2 + 2 > words.length ? 0 : _d.getUint16(33 + i * 2, Endian.little);

  late final Uint8List data = () {
    final at = 33 + words.length;
    if (at + 2 > message.length) return Uint8List(0);
    final length = _d.getUint16(at, Endian.little);
    return Uint8List.sublistView(message, at + 2, (at + 2 + length).clamp(0, message.length));
  }();
}

/// Little-endian fields.
class _Words {
  final _b = BytesBuilder();

  Uint8List get bytes => _b.toBytes();

  /// No command follows in the same message.
  void andX() => u32(0x000000FF);
  void u8(int v) => _b.addByte(v & 0xFF);
  void u16(int v) => _b.add([v & 0xFF, v >> 8 & 0xFF]);
  void u32(int v) => _b.add([v & 0xFF, v >> 8 & 0xFF, v >> 16 & 0xFF, v >> 24 & 0xFF]);
  void u64(int v) {
    u32(v & 0xFFFFFFFF);
    u32(v >> 32);
  }

  void raw(List<int> b) => _b.add(b);
}
