import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../../platform/platform_info.dart';
import '../../platform/smb_platform.dart';

/// An SMB host found on the network.
class SmbHost {
  const SmbHost({required this.address, required this.name, this.port = 445});

  final String address;
  final String name;
  final int port;

  String get label => name.isEmpty ? address : name;
}

/// Looks for SMB hosts while the Add share step is open (design D12): mDNS
/// (`_smb._tcp`, `_adisk._tcp`), WS-Discovery (Windows) and NetBIOS name
/// queries, together for [duration], each host once by its address.
class SmbDiscovery {
  SmbDiscovery({this.duration = const Duration(seconds: 8), this.mdnsPort = 5353, this.wsdPort = 3702, this.netbiosPort = 137});

  final Duration duration;
  final int mdnsPort, wsdPort, netbiosPort;

  final _hosts = <String, SmbHost>{};
  final _found = StreamController<List<SmbHost>>.broadcast();
  final _sockets = <RawDatagramSocket>[];
  MDnsClient? _mdns;
  Timer? _end;
  bool _running = false;

  /// Every host so far, sorted by name, each time one is found.
  Stream<List<SmbHost>> get hosts => _found.stream;
  List<SmbHost> get current => _sorted();
  bool get running => _running;

  List<SmbHost> _sorted() => _hosts.values.toList()..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  void _add(String address, String name, {int port = 445}) {
    if (!_running) return;
    final known = _hosts[address];
    // A real name wins over an address, and over a NetBIOS name in capitals.
    if (known != null && (name.isEmpty || known.name.isNotEmpty && known.name != known.name.toUpperCase())) return;
    _hosts[address] = SmbHost(address: address, name: name, port: port);
    _found.add(_sorted());
  }

  /// Looks again from the start; the search ends by itself after
  /// [duration], or with [stop].
  Future<void> start() async {
    await stop();
    _hosts.clear();
    _running = true;
    _found.add(const []);
    if (PlatformInfo.isAndroid) await SmbPlatform.holdMulticast(true);
    _end = Timer(duration, () => unawaited(stop()));
    await Future.wait([_mdnsSearch(), _wsdSearch(), _netbiosSearch()].map((f) => f.catchError((Object e) {
          debugPrint('SMB discovery: ${e.runtimeType}');
        })));
  }

  Future<void> stop() async {
    _end?.cancel();
    _end = null;
    if (!_running) return;
    _running = false;
    _mdns?.stop();
    _mdns = null;
    for (final s in _sockets) {
      s.close();
    }
    _sockets.clear();
    if (PlatformInfo.isAndroid) await SmbPlatform.holdMulticast(false);
    _found.add(_sorted());
  }

  Future<void> dispose() async {
    await stop();
    await _found.close();
  }

  // ---- mDNS ------------------------------------------------------------------------

  Future<void> _mdnsSearch() async {
    final client = _mdns = MDnsClient(rawDatagramSocketFactory: (host, port, {reuseAddress = true, reusePort = false, ttl = 255}) =>
        RawDatagramSocket.bind(host, port, reuseAddress: true, reusePort: !Platform.isAndroid && reusePort, ttl: ttl));
    await client.start(mDnsPort: mdnsPort);
    Future<void> service(String type) async {
      await for (final ptr in client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(type), timeout: duration)) {
        if (!_running) return;
        final instance = ptr.domainName.split('.$type').first;
        await for (final srv in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName), timeout: const Duration(seconds: 3))) {
          await for (final ip in client.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target), timeout: const Duration(seconds: 3))) {
            _add(ip.address.address, instance, port: type.startsWith('_smb') ? srv.port : 445);
          }
        }
      }
    }

    await Future.wait([service('_smb._tcp.local'), service('_adisk._tcp.local')]);
  }

  // ---- WS-Discovery ------------------------------------------------------------------

  static String probe(String id) => '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:wsd="http://schemas.xmlsoap.org/ws/2005/04/discovery" xmlns:wsdp="http://schemas.xmlsoap.org/ws/2006/02/devprof" xmlns:pub="http://schemas.microsoft.com/windows/pub/2005/07"><soap:Header><wsa:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</wsa:To><wsa:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</wsa:Action><wsa:MessageID>urn:uuid:$id</wsa:MessageID></soap:Header><soap:Body><wsd:Probe><wsd:Types>wsdp:Device</wsd:Types></wsd:Probe></soap:Body></soap:Envelope>''';

  static String _get(String to, String id) => '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing"><soap:Header><wsa:To>$to</wsa:To><wsa:Action>http://schemas.xmlsoap.org/ws/2004/09/transfer/Get</wsa:Action><wsa:MessageID>urn:uuid:$id</wsa:MessageID><wsa:ReplyTo><wsa:Address>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:Address></wsa:ReplyTo></soap:Header><soap:Body/></soap:Envelope>''';

  static String _uuid() {
    final r = Random.secure();
    final b = [for (var i = 0; i < 16; i++) r.nextInt(256)];
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// A ProbeMatches answer: the device's endpoint and where to ask its name.
  /// An answer without XAddrs is asked at the address it came from, on
  /// the port Windows uses ([from]: that address).
  static ({String endpoint, List<Uri> addresses})? parseProbeMatch(String xml, {String? from}) {
    if (!xml.contains('ProbeMatches')) return null;
    final endpoint = RegExp(r'<(?:\w+:)?Address>\s*([^<\s]+)\s*</').firstMatch(xml)?[1];
    if (endpoint == null) return null;
    final xaddrs = RegExp(r'<(?:\w+:)?XAddrs>\s*([^<]+?)\s*</').firstMatch(xml)?[1];
    final addresses = [for (final a in (xaddrs ?? '').split(RegExp(r'\s+'))) if (a.isNotEmpty) ?Uri.tryParse(a)];
    if (addresses.isEmpty && from != null) {
      addresses.add(Uri(scheme: 'http', host: from, port: 5357, path: endpoint.replaceFirst('urn:uuid:', '')));
    }
    return addresses.isEmpty ? null : (endpoint: endpoint, addresses: addresses);
  }

  /// A computer's name in its WS-Transfer Get answer (`NAME/Workgroup:…`).
  static String? parseComputerName(String xml) {
    final m = RegExp(r'<(?:\w+:)?Computer>\s*([^<]+?)\s*</').firstMatch(xml);
    if (m == null) return null;
    return m[1]!.split('/').first.trim();
  }

  /// Linux's and Android's `IPPROTO_IP` and `IP_MULTICAST_IF`.
  static const _ipLevel = 0, _multicastIf = 32;

  Future<void> _wsdSearch() async {
    final asked = <String>{};
    final message = utf8.encode(probe(_uuid()));
    final group = InternetAddress('239.255.255.250');
    // A probe goes out on every network the device is on, not only the
    // one its default route takes.
    final interfaces = [
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4))
        for (final a in i.addresses)
          if (!a.isLoopback) a
    ];
    final sockets = <RawDatagramSocket>[];
    for (final local in interfaces.isEmpty ? [InternetAddress.anyIPv4] : interfaces) {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _sockets.add(socket);
      sockets.add(socket);
      socket.multicastLoopback = true;
      if (local != InternetAddress.anyIPv4) {
        try {
          socket.setRawOption(RawSocketOption(_ipLevel, _multicastIf, local.rawAddress));
        } on SocketException {
          // The default route's network, then.
        }
      }
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = socket.receive();
        if (d == null) return;
        final match = parseProbeMatch(utf8.decode(d.data, allowMalformed: true), from: d.address.address);
        if (match == null || !asked.add(match.endpoint)) return;
        unawaited(_askName(d.address.address, match));
      });
    }
    for (var i = 0; i < 2 && _running; i++) {
      for (final socket in sockets) {
        try {
          socket.send(message, group, wsdPort);
        } on SocketException {
          // A network that doesn't take multicast.
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  Future<void> _askName(String from, ({String endpoint, List<Uri> addresses}) match) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      for (final uri in match.addresses) {
        try {
          final request = await client.postUrl(uri).timeout(const Duration(seconds: 3));
          request.headers.contentType = ContentType('application', 'soap+xml', charset: 'utf-8');
          final body = utf8.encode(_get(match.endpoint, _uuid()));
          request.contentLength = body.length;
          request.add(body);
          final answer = await request.close().timeout(const Duration(seconds: 3));
          final name = parseComputerName(await answer.transform(utf8.decoder).join().timeout(const Duration(seconds: 3)));
          _add(uri.host.isEmpty ? from : uri.host, name ?? '');
          return;
        } on Object {
          // The next address, or the one it answered from.
        }
      }
      _add(from, '');
    } finally {
      client.close(force: true);
    }
  }

  // ---- NetBIOS ---------------------------------------------------------------------

  /// A node status request for `*`, which every NetBIOS host answers with
  /// its names.
  static Uint8List nodeStatus(int id) {
    final b = BytesBuilder()
      ..add([id >> 8 & 0xFF, id & 0xFF, 0x00, 0x10, 0, 1, 0, 0, 0, 0, 0, 0])
      ..addByte(0x20)
      ..add([0x43, 0x4B])
      ..add(List.filled(30, 0x41))
      ..add([0, 0, 0x21, 0, 1]);
    return b.toBytes();
  }

  /// The file server name in a node status answer (the `<20>` name), else
  /// its first unique name.
  static String? parseNodeStatus(Uint8List m) {
    if (m.length < 57) return null;
    var at = 12;
    // The name the answer is about.
    while (at < m.length && m[at] != 0) {
      at += m[at] + 1;
    }
    at += 1 + 2 + 2 + 4 + 2;
    if (at >= m.length) return null;
    final count = m[at++];
    String? any;
    for (var i = 0; i < count && at + 18 <= m.length; i++, at += 18) {
      final name = String.fromCharCodes(m.sublist(at, at + 15)).trim();
      final suffix = m[at + 15], group = m[at + 16] & 0x80 != 0;
      if (group || name.isEmpty) continue;
      if (suffix == 0x20) return name;
      any ??= name;
    }
    return any;
  }

  Future<void> _netbiosSearch() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _sockets.add(socket);
    socket.broadcastEnabled = true;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = socket.receive();
      if (d == null) return;
      final name = parseNodeStatus(d.data);
      if (name != null) _add(d.address.address, name);
    });
    final targets = await _broadcastAddresses();
    final message = nodeStatus(Random().nextInt(1 << 16));
    for (var i = 0; i < 2 && _running; i++) {
      for (final t in targets) {
        try {
          socket.send(message, InternetAddress(t), netbiosPort);
        } on SocketException {
          // An address this network won't send to.
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
  }

  /// Each network's broadcast address.
  static Future<List<String>> _broadcastAddresses() async {
    if (PlatformInfo.isAndroid) return SmbPlatform.broadcastAddresses();
    try {
      final r = await Process.run('ip', ['-4', '-o', 'addr', 'show']);
      final found = [
        for (final m in RegExp(r'brd (\d+\.\d+\.\d+\.\d+)').allMatches('${r.stdout}')) m[1]!,
      ];
      if (found.isNotEmpty) return found.toSet().toList();
    } on ProcessException {
      // Worked out from the addresses below.
    }
    return [
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4))
        for (final a in i.addresses)
          if (!a.isLoopback) '${a.address.substring(0, a.address.lastIndexOf('.'))}.255'
    ];
  }
}
