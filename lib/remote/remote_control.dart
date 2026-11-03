import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../playback/tuner.dart';
import '../profiles/household.dart';
import 'firewall_check.dart';
import 'key_dispatch.dart';
import 'remote_page.dart';

typedef KeyDispatcher = bool Function(LogicalKeyboardKey key, PhysicalKeyboardKey physical);

/// Whether a request came from this device itself (loopback or one of its
/// own addresses), which doesn't prove a phone can reach the remote.
typedef ThisDeviceCheck = Future<bool> Function(InternetAddress address);

/// Whether a phone can use the remote (remote-setup D1).
enum RemoteStatus { blocked, notConfirmed, working }

/// A phone paired with this TV. Only a hash of its key is kept.
class RemotePairing {
  RemotePairing({required this.id, required this.name, required this.keyHash, required this.paired, required this.lastUsed});

  factory RemotePairing.fromJson(Map<String, Object?> json) => RemotePairing(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Phone',
        keyHash: json['keyHash'] as String,
        paired: DateTime.tryParse(json['paired'] as String? ?? '') ?? DateTime.now(),
        lastUsed: DateTime.tryParse(json['lastUsed'] as String? ?? '') ?? DateTime.now(),
      );

  final String id;
  final String name;
  final String keyHash;
  final DateTime paired;
  DateTime lastUsed;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'keyHash': keyHash,
        'paired': paired.toIso8601String(),
        'lastUsed': lastUsed.toIso8601String(),
      };
}

/// The phone remote: a small web server on the home network whose page
/// works like the TV's remote. Off until turned on in the menu.
class RemoteControl extends ChangeNotifier {
  RemoteControl(this.household,
      {this._dispatch = dispatchKey, this._wake, FirewallCheck? firewallCheck, ThisDeviceCheck? isThisDevice})
      : _firewallCheck = firewallCheck ?? FirewallCheck(),
        _isThisDevice = isThisDevice ?? _ownAddress;

  static const _settingsFile = 'remote.json';

  /// Paired phones and the Working confirmation. Device-only: backups never
  /// copy it (remote-setup D6).
  static const pairingsFile = 'remote_pairings.json';
  static const defaultPort = 8642;
  static const maxPairings = 20;
  static const _wrongCodeLimit = 5;

  /// Every request but loading the page and pairing carries a paired
  /// phone's key in this header.
  static const keyHeader = 'x-nightingale-remote-key';

  static const pairingClosedMessage = 'Open Menu → Phone remote on the TV to pair';

  /// Requests that change something must carry this header. Browsers won't
  /// let other websites add it without permission, which this server never
  /// gives, so a web page can't drive the TV behind the user's back.
  static const actionHeader = 'x-nightingale-remote';

  final Household household;
  final KeyDispatcher _dispatch;

  /// Brings the TV window to the front, so key presses reach it.
  final Future<void> Function()? _wake;
  final FirewallCheck _firewallCheck;
  final ThisDeviceCheck _isThisDevice;

  /// The tuner of whoever is watching; attached by the UI.
  Tuner? tuner;

  bool enabled = false;
  HttpServer? _server;
  String? error;

  /// Where phones can reach the remote, while it's running.
  Uri? url;

  int? get port => _server?.port;

  /// Paired phones, most recently used first.
  List<RemotePairing> get pairings => [..._pairings]..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  final _pairings = <RemotePairing>[];

  /// Where a phone last reached the remote from another device.
  ({String address, int port})? confirmed;

  /// The firewall's last answer; null until checked.
  FirewallState? firewall;

  /// The code a phone pairs with, while the Phone remote screen is open.
  String? get pairingCode => _code;
  String? _code;
  int _wrongCodes = 0;

  RemoteStatus get status {
    if (firewall?.blocked ?? false) return RemoteStatus.blocked;
    final u = url, c = confirmed;
    if (u != null && c != null && c.address == u.host && c.port == u.port) return RemoteStatus.working;
    return RemoteStatus.notConfirmed;
  }

  /// The firewall command for the remote's port, when a firewall is on.
  String? get fixCommand {
    final p = port;
    return p == null ? null : firewall?.fixCommand(p);
  }

  Future<void> load() async {
    final json = await household.root.readJson(_settingsFile);
    enabled = json is Map<String, Object?> && json['enabled'] == true;
    final saved = await household.root.readJson(pairingsFile);
    _pairings.clear();
    confirmed = null;
    if (saved is Map<String, Object?>) {
      for (final p in saved['pairings'] as List? ?? const []) {
        if (p is Map<String, Object?> && p['id'] is String && p['keyHash'] is String) {
          _pairings.add(RemotePairing.fromJson(p));
        }
      }
      final c = saved['confirmed'];
      if (c is Map<String, Object?> && c['address'] is String && c['port'] is int) {
        confirmed = (address: c['address'] as String, port: c['port'] as int);
      }
    }
    if (enabled) await _start();
  }

  Future<void> _savePairings() => household.root.writeJson(
        pairingsFile,
        {
          'pairings': [for (final p in _pairings) p.toJson()],
          if (confirmed case final c?) 'confirmed': {'address': c.address, 'port': c.port},
        },
        private: true,
      );

  /// Lets phones pair while the Phone remote screen is open.
  void openPairing() {
    if (_code != null) return;
    _rotateCode();
    notifyListeners();
  }

  void closePairing() {
    if (_code == null) return;
    _code = null;
    _wrongCodes = 0;
    notifyListeners();
  }

  void _rotateCode() {
    _code = Random.secure().nextInt(1000000).toString().padLeft(6, '0');
    _wrongCodes = 0;
  }

  Future<void> removePairing(String id) async {
    _pairings.removeWhere((p) => p.id == id);
    await _savePairings();
    notifyListeners();
  }

  Future<void> removeAllPairings() async {
    _pairings.clear();
    await _savePairings();
    notifyListeners();
  }

  /// Asks this computer's firewall about the remote's port. Runs when the
  /// remote starts, when the screen opens and on Check again; never on a
  /// timer.
  Future<void> checkFirewall() async {
    final p = port, host = url?.host;
    if (p == null) return;
    String? interface;
    if (host != null) {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        if (i.addresses.any((a) => a.address == host)) interface = i.name;
      }
    }
    firewall = await _firewallCheck.check(p, interface: interface);
    notifyListeners();
  }

  /// Loopback, or one of this device's own addresses.
  static Future<bool> _ownAddress(InternetAddress address) async {
    if (address.isLoopback) return true;
    final interfaces = await NetworkInterface.list(includeLoopback: true, type: InternetAddressType.any);
    return interfaces.any((i) => i.addresses.any((a) => a.address == address.address));
  }

  /// A paired phone reached the remote: remember it for this address and
  /// port, unless the request came from this device itself (D2).
  Future<void> _confirmFrom(InternetAddress from) async {
    final u = url;
    if (u == null || status == RemoteStatus.working) return;
    if (await _isThisDevice(from)) return;
    confirmed = (address: u.host, port: u.port);
    await _savePairings();
    notifyListeners();
  }

  RemotePairing? _pairingFor(String? key) {
    if (key == null || key.isEmpty) return null;
    final hash = _hash(key);
    return _pairings.where((p) => p.keyHash == hash).firstOrNull;
  }

  static String _hash(String key) => sha256.convert(utf8.encode(key)).toString();

  static String _random(int bytes) {
    final r = Random.secure();
    return base64Url.encode([for (var i = 0; i < bytes; i++) r.nextInt(256)]).replaceAll('=', '');
  }

  Future<void> _pair(HttpRequest request, Map<String, Object?> body) async {
    final response = request.response;
    final code = _code;
    if (code == null) {
      response.statusCode = HttpStatus.forbidden;
      _json(response, {'error': pairingClosedMessage});
      return;
    }
    if ('${body['code'] ?? ''}'.replaceAll(RegExp(r'\s'), '') != code) {
      if (++_wrongCodes >= _wrongCodeLimit) {
        _rotateCode();
        notifyListeners();
      }
      response.statusCode = HttpStatus.forbidden;
      _json(response, {'error': 'That code doesn\'t match. Check the code on the TV.'});
      return;
    }
    final key = _random(32);
    var name = '${body['name'] ?? ''}'.trim();
    if (name.isEmpty) name = 'Phone';
    if (name.length > 40) name = name.substring(0, 40);
    final now = DateTime.now();
    while (_pairings.length >= maxPairings) {
      _pairings.remove(_pairings.reduce((a, b) => a.lastUsed.isBefore(b.lastUsed) ? a : b));
    }
    _pairings.add(RemotePairing(id: _random(9), name: name, keyHash: _hash(key), paired: now, lastUsed: now));
    _rotateCode();
    await _savePairings();
    notifyListeners();
    _json(response, {'key': key});
    await _confirmFrom(request.connectionInfo!.remoteAddress);
  }

  /// The paired phone sending [request], or null after answering 401.
  Future<RemotePairing?> _authorize(HttpRequest request) async {
    final pairing = _pairingFor(request.headers.value(keyHeader));
    if (pairing == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      _json(request.response, {'error': 'Not paired'});
      return null;
    }
    final now = DateTime.now();
    // Saved at most once a minute per phone, not on every key press.
    if (now.difference(pairing.lastUsed) >= const Duration(minutes: 1)) {
      pairing.lastUsed = now;
      await _savePairings();
      notifyListeners();
    }
    await _confirmFrom(request.connectionInfo!.remoteAddress);
    return pairing;
  }

  Future<void> setEnabled(bool on, {int port = defaultPort}) async {
    enabled = on;
    await household.root.writeJson(_settingsFile, {'enabled': on});
    if (on) {
      await _start(port: port);
    } else {
      await stop();
    }
    notifyListeners();
  }

  /// The port [_start] was last asked for.
  int _port = defaultPort;

  Future<void> _start({int port = defaultPort}) async {
    if (_server != null) return;
    _port = port;
    error = null;
    // Try a few ports in case something else is using ours.
    for (var p = port; p < port + 10; p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        break;
      } on SocketException {
        if (port == 0) break;
      }
    }
    final server = _server;
    if (server == null) {
      error = 'Couldn\'t open a network port for the remote.';
      notifyListeners();
      return;
    }
    server.listen(_handle);
    url = Uri(scheme: 'http', host: await lanAddress() ?? 'localhost', port: server.port);
    notifyListeners();
    unawaited(checkFirewall());
  }

  /// Starts the remote again after [stop] (the app coming back to the
  /// front on Android), if it's turned on.
  Future<void> resume() async {
    if (enabled) await _start(port: _port);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    url = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// This PC's address on the home network.
  static Future<String?> lanAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final candidates = [
      for (final i in interfaces)
        for (final a in i.addresses.where((a) => isPrivate(a) && !a.isLoopback)) (iface: i.name, address: a.address),
    ];
    if (candidates.length < 2) return candidates.firstOrNull?.address;
    final names = {for (final c in candidates) c.iface};
    return chooseLanAddress(
      candidates,
      defaultRoute: _defaultRouteInterfaces(),
      down: {
        for (final n in names)
          if (_readSys('/sys/class/net/$n/operstate')?.trim() == 'down') n,
      },
      tunnels: {
        // ARPHRD_NONE: VPN tunnels (tun, WireGuard).
        for (final n in names)
          if (_readSys('/sys/class/net/$n/type')?.trim() == '65534') n,
      },
    );
  }

  /// Interface names that look like containers, virtual machines or VPNs.
  static final _virtual = RegExp(r'^(docker|br-|virbr|veth|vnet|vmnet|vboxnet|tun|tap|wg|tailscale|zt|utun)');

  /// The address phones should use, of [candidates]: the interface with the
  /// default route first, then any that is up and not virtual (Docker,
  /// libvirt, VPN), with 192.168.x.x (what home routers hand out) breaking
  /// ties. A virtual machine bridge that's down is never picked over Wi-Fi.
  @visibleForTesting
  static String? chooseLanAddress(List<({String iface, String address})> candidates,
      {Set<String> defaultRoute = const {}, Set<String> down = const {}, Set<String> tunnels = const {}}) {
    int score(({String iface, String address}) c) {
      final tunnel = tunnels.contains(c.iface) || _virtual.hasMatch(c.iface);
      return (defaultRoute.contains(c.iface) && !tunnel ? 8 : 0) +
          (down.contains(c.iface) ? -16 : 0) +
          (tunnel ? -4 : 0) +
          (c.address.startsWith('192.168.') ? 1 : 0);
    }

    ({String iface, String address})? best;
    for (final c in candidates) {
      if (best == null || score(c) > score(best)) best = c;
    }
    return best?.address;
  }

  /// Interfaces holding a default route, from `/proc/net/route` (readable
  /// without root on Linux; empty where it isn't, such as newer Android).
  static Set<String> _defaultRouteInterfaces() {
    final table = _readSys('/proc/net/route');
    if (table == null) return const {};
    return {
      for (final line in table.split('\n').skip(1))
        if (line.trim().split(RegExp(r'\s+')) case [final iface, '00000000', ...]) iface,
    };
  }

  /// A small kernel file (`/proc`, `/sys`), read at once: they're generated
  /// in memory, so reading never waits on a disk.
  static String? _readSys(String path) {
    try {
      return File(path).readAsStringSync();
    } on Object {
      return null;
    }
  }

  /// Loopback, or a private (home network) address.
  static bool isPrivate(InternetAddress a) {
    if (a.isLoopback || a.isLinkLocal) return true;
    if (a.type != InternetAddressType.IPv4) return false;
    final b = a.rawAddress;
    return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] < 32) || (b[0] == 192 && b[1] == 168);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    try {
      if (!isPrivate(request.connectionInfo!.remoteAddress)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final path = request.uri.path;
      if (request.method == 'GET' && (path == '/' || path == '/index.html')) {
        response.headers.contentType = ContentType.html;
        response.write(remotePageHtml);
      } else if (request.method == 'GET' && path == '/api/state') {
        if (await _authorize(request) == null) return;
        _json(response, state());
      } else if (request.method == 'POST' && path.startsWith('/api/')) {
        if (request.headers.value(actionHeader) != '1') {
          response.statusCode = HttpStatus.forbidden;
          return;
        }
        final body = jsonDecode(await utf8.decodeStream(request));
        if (body is! Map<String, Object?>) throw const FormatException('Expected a JSON object');
        if (path == '/api/pair') {
          await _pair(request, body);
          return;
        }
        if (await _authorize(request) == null) return;
        switch (path) {
          case '/api/key':
            final key = remoteKeys[body['key']];
            if (key == null) throw FormatException('Unknown key ${body['key']}');
            await _wake?.call();
            _json(response, {'handled': _dispatch(key.$1, key.$2)});
          case '/api/tune':
            final number = body['number'];
            if (number is! int) throw const FormatException('Expected a channel number');
            await _wake?.call();
            _json(response, {'tuned': await tuner?.tuneNumber(number) ?? false});
          default:
            response.statusCode = HttpStatus.notFound;
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } on FormatException catch (e) {
      response.statusCode = HttpStatus.badRequest;
      _json(response, {'error': e.message});
    } on Object catch (e) {
      debugPrint('Remote request failed: $e');
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  static void _json(HttpResponse response, Object? data) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
  }

  /// What the remote page shows: who's watching, what's on, the lineup.
  Map<String, Object?> state() {
    final app = household.app;
    final profile = household.current;
    if (app == null || profile == null) return {'profile': null};
    final now = DateTime.now();
    final channel = tuner?.channel;
    Map<String, Object?>? program;
    final p = tuner?.program;
    if (p != null) {
      program = {
        'title': p.title,
        'subtitle': p.subtitle,
        'start': p.start.toIso8601String(),
        'end': p.end.toIso8601String(),
        if (p.blockTitle != null) 'block': p.blockTitle,
        'commercial': tuner?.inBreak ?? false,
      };
    }
    return {
      'profile': profile.name,
      'kid': profile.isKid,
      'now': now.toIso8601String(),
      if (channel != null) 'channel': {'number': channel.number, 'name': channel.name},
      'program': program,
      'channels': [
        for (final c in app.channels)
          {
            'number': c.number,
            'name': c.name,
            'now': app.scheduleFor(c)?.programAt(now).title,
          },
      ],
    };
  }
}
