import 'dart:io';
import 'dart:typed_data';

/// Answers mDNS questions for one SMB share's host, as a NAS does: PTR
/// `_smb._tcp.local`, its SRV and its address. For discovery checks on a
/// network (or an emulator) with no such host.
class MdnsResponder {
  MdnsResponder({required this.instance, required this.host, required this.address, this.port = 445});

  final String instance;
  final String host;
  final InternetAddress address;
  final int port;
  RawDatagramSocket? _socket;

  static final _group = InternetAddress('224.0.0.251');

  Future<void> start() async {
    final s = _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5353, reuseAddress: true, reusePort: !Platform.isAndroid);
    for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      try {
        s.joinMulticast(_group, i);
      } on SocketException {
        // Not a multicast network.
      }
    }
    s.multicastLoopback = true;
    s.listen((e) {
      if (e != RawSocketEvent.read) return;
      final d = s.receive();
      if (d == null || d.data.length < 12 || d.data[2] & 0x80 != 0) return;
      final asked = _questions(d.data);
      if (asked.any((q) => q.contains('_smb._tcp.local') || q == '$host.local')) {
        s.send(_answer(), _group, 5353);
      }
    });
  }

  void stop() => _socket?.close();

  static List<String> _questions(Uint8List m) {
    final count = m[4] << 8 | m[5];
    final out = <String>[];
    var at = 12;
    for (var i = 0; i < count && at < m.length; i++) {
      final labels = <String>[];
      while (at < m.length && m[at] != 0) {
        if (m[at] & 0xC0 == 0xC0) {
          at += 1;
          break;
        }
        labels.add(String.fromCharCodes(m.sublist(at + 1, at + 1 + m[at])));
        at += m[at] + 1;
      }
      at += 1 + 4;
      out.add(labels.join('.').toLowerCase());
    }
    return out;
  }

  static List<int> _name(String name) => [
        for (final label in name.split('.')) ...[label.length, ...label.codeUnits],
        0,
      ];

  List<int> _record(String name, int type, List<int> data) {
    final b = BytesBuilder()
      ..add(_name(name))
      ..add([type >> 8, type & 0xFF, 0x80, 0x01, 0, 0, 0x11, 0x94, data.length >> 8, data.length & 0xFF])
      ..add(data);
    return b.toBytes();
  }

  Uint8List _answer() {
    final service = '$instance._smb._tcp.local';
    final target = '$host.local';
    final b = BytesBuilder()
      ..add([0, 0, 0x84, 0, 0, 0, 0, 3, 0, 0, 0, 0])
      ..add(_record('_smb._tcp.local', 12, _name(service)))
      ..add(_record(service, 33, [0, 0, 0, 0, port >> 8, port & 0xFF, ..._name(target)]))
      ..add(_record(target, 1, address.rawAddress));
    return b.toBytes();
  }
}
