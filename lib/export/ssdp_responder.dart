import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../remote/remote_control.dart';
import 'hdhomerun.dart';

/// One device announced over SSDP.
typedef SsdpDevice = ({String deviceId, Uri location});

/// Sends one datagram.
typedef DatagramSend = void Function(List<int> data, InternetAddress address, int port);

/// Announces the exported tuners on the home network over SSDP (UDP 1900),
/// so Plex finds them without typing an address.
class SsdpResponder {
  SsdpResponder({Random? random}) : _random = random ?? Random();

  static final group = InternetAddress('239.255.255.250');
  static const port = 1900;
  static const maxAge = Duration(minutes: 30);
  static const aliveInterval = Duration(minutes: 15);
  static const _server = 'Linux/1.0 UPnP/1.0 NightingaleTV/1.0';
  static const deviceType = 'urn:schemas-upnp-org:device:MediaServer:1';

  final Random _random;
  RawDatagramSocket? _socket;
  Timer? _alive;
  List<SsdpDevice> _devices = const [];

  /// For tests: where datagrams go instead of a socket.
  @visibleForTesting
  DatagramSend? sendOverride;

  bool _started = false;

  bool get running => _started;

  /// Opens UDP 1900. Throws [SocketException] when it can't (the screen then
  /// says discovery is unavailable).
  Future<void> start() async {
    if (_socket != null || _started) return;
    _started = true;
    if (sendOverride != null) {
      _announce(_devices, alive: true);
      return;
    }
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true, reusePort: true);
      socket.joinMulticast(group);
    } on Object {
      socket?.close();
      _started = false;
      rethrow;
    }
    final bound = socket;
    bound.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = bound.receive();
      if (d != null) handle(d.data, d.address, d.port);
    });
    _socket = bound;
    _alive = Timer.periodic(aliveInterval, (_) => _announce(_devices, alive: true));
    _announce(_devices, alive: true);
  }

  /// Says goodbye for every device and closes the socket.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _announce(_devices, alive: false);
    _alive?.cancel();
    _alive = null;
    _socket?.close();
    _socket = null;
  }

  /// The devices to announce: new ones get an alive, gone ones a byebye.
  void setDevices(List<SsdpDevice> devices) {
    final ids = {for (final d in devices) d.deviceId};
    final oldIds = {for (final d in _devices) d.deviceId};
    final gone = [for (final d in _devices) if (!ids.contains(d.deviceId)) d];
    final added = [for (final d in devices) if (!oldIds.contains(d.deviceId)) d];
    _devices = [...devices];
    if (!running) return;
    _announce(gone, alive: false);
    _announce(added, alive: true);
  }

  void _send(String message, InternetAddress address, int port) {
    final data = utf8.encode(message);
    final send = sendOverride;
    if (send != null) {
      send(data, address, port);
    } else {
      _socket?.send(data, address, port);
    }
  }

  void _announce(List<SsdpDevice> devices, {required bool alive}) {
    for (final d in devices) {
      for (final (nt, usn) in _targets(d)) {
        _send(
          'NOTIFY * HTTP/1.1\r\n'
          'HOST: ${group.address}:$port\r\n'
          '${alive ? 'CACHE-CONTROL: max-age=${maxAge.inSeconds}\r\nLOCATION: ${d.location}\r\nSERVER: $_server\r\n' : ''}'
          'NT: $nt\r\n'
          'NTS: ssdp:${alive ? 'alive' : 'byebye'}\r\n'
          'USN: $usn\r\n'
          '\r\n',
          group,
          port,
        );
      }
    }
  }

  /// Search targets a device answers to, with its USN for each.
  static List<(String, String)> _targets(SsdpDevice d) {
    final uuid = 'uuid:${deviceUuid(d.deviceId)}';
    return [
      ('upnp:rootdevice', '$uuid::upnp:rootdevice'),
      (uuid, uuid),
      (deviceType, '$uuid::$deviceType'),
    ];
  }

  /// Answers an M-SEARCH from a home-network sender, after a random delay
  /// within its MX (at most 1 s).
  @visibleForTesting
  void handle(List<int> data, InternetAddress from, int fromPort, {Duration? delay}) {
    if (!RemoteControl.isPrivate(from)) return;
    final String text;
    try {
      text = utf8.decode(data);
    } on FormatException {
      return;
    }
    final lines = text.split(RegExp(r'\r?\n'));
    if (!lines.first.toUpperCase().startsWith('M-SEARCH')) return;
    final headers = <String, String>{
      for (final l in lines.skip(1))
        if (l.indexOf(':') case final i when i > 0) l.substring(0, i).trim().toUpperCase(): l.substring(i + 1).trim(),
    };
    if (headers['MAN']?.replaceAll('"', '') != 'ssdp:discover') return;
    final st = headers['ST'];
    if (st == null) return;
    final answers = [
      for (final d in _devices)
        for (final (nt, usn) in _targets(d))
          if (st == 'ssdp:all' || st == nt) (d, nt, usn),
    ];
    if (answers.isEmpty) return;
    final mx = int.tryParse(headers['MX'] ?? '') ?? 1;
    final wait = delay ?? Duration(milliseconds: _random.nextInt(max(1, min(mx, 1) * 1000)));
    Timer(wait, () {
      for (final (d, nt, usn) in answers) {
        _send(
          'HTTP/1.1 200 OK\r\n'
          'CACHE-CONTROL: max-age=${maxAge.inSeconds}\r\n'
          'EXT:\r\n'
          'LOCATION: ${d.location}\r\n'
          'SERVER: $_server\r\n'
          'ST: $nt\r\n'
          'USN: $usn\r\n'
          '\r\n',
          from,
          fromPort,
        );
      }
    });
  }
}
