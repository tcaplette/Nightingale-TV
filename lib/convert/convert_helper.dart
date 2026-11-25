import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/app_storage.dart';
import '../server/media_server.dart';
import '../server/smb/secret_store.dart';
import '../server/smb/smb_gateway.dart';
import '../server/smb/smb_library.dart';
import '../server/smb/smb_server.dart';
import '../server/smb/smb_share.dart';
import 'conversion.dart';
import 'conversion_jobs.dart';
import 'convert_speeds.dart';

/// The SSDP service a helper answers to.
const helperService = 'urn:coffeehauslabs-com:service:ntv-convert:1';

/// A TV paired with this helper. Only a hash of its key is kept.
class HelperPairing {
  HelperPairing({required this.id, required this.name, required this.keyHash, required this.paired});

  factory HelperPairing.fromJson(Map<String, Object?> j) => HelperPairing(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      keyHash: j['keyHash'] as String,
      paired: DateTime.tryParse(j['paired'] as String? ?? '') ?? DateTime.now());

  final String id;
  final String name;
  final String keyHash;
  final DateTime paired;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'keyHash': keyHash, 'paired': paired.toIso8601String()};
}

/// "Convert for other TVs" (smb-conversion D9): the Linux app or the Docker
/// server converting share files for paired TVs that can't. Off by default.
/// It listens on [port], answers SSDP searches for [helperService], and
/// converts only files in folders mapped in one of its own profiles that
/// has the same share, reading them itself.
class ConvertHelper extends ChangeNotifier {
  ConvertHelper(this.root, {required this.deviceName, this.port = defaultPort, this.exportBusy, int? streams})
      : _streams = streams; // ignore: prefer_initializing_formals

  static const defaultPort = 8487;
  static const file = 'convert_helper.json';
  static const maxPairings = 20;
  static const _wrongLimit = 5;

  /// The household's folder (profiles are under `profiles/`).
  final AppStorage root;
  final String deviceName;
  final int port;

  /// Channels Live TV export streams now; they share the stream limit.
  final int Function()? exportBusy;
  final int? _streams;

  bool _on = false;
  bool get on => _on;
  final _pairings = <HelperPairing>[];
  List<HelperPairing> get pairings => List.unmodifiable(_pairings);
  late String id;

  String? _code;
  int _wrong = 0;

  /// The code a TV pairs with, while it's on.
  String? get code => _code;

  /// This device's conversion speed (frames of 720p H.264 a second), from a
  /// short benchmark at start; TVs prefer the fastest helper.
  double benchmark = 0;

  HttpServer? _server;
  RawDatagramSocket? _ssdp;
  ConversionJobs? _jobs;

  /// Conversions at once, by default; export streams count against it.
  int get streamLimit => _streams ?? 2;

  Future<void> load() async {
    final json = await root.readJson(file);
    if (json is Map<String, Object?>) {
      _on = json['on'] == true;
      id = json['id'] as String? ?? _random(8);
      for (final p in (json['pairings'] as List? ?? const []).whereType<Map<String, Object?>>()) {
        _pairings.add(HelperPairing.fromJson(p));
      }
    } else {
      id = _random(8);
    }
    if (_on) await _start();
  }

  Future<void> _save() => root.writeJson(file, {
        'on': _on,
        'id': id,
        'pairings': [for (final p in _pairings) p.toJson()],
      }, private: true);

  Future<void> setOn(bool value) async {
    _on = value;
    if (value) {
      await _start();
    } else {
      await stop();
    }
    await _save();
    notifyListeners();
  }

  void _newCode() {
    _code = Random.secure().nextInt(1000000).toString().padLeft(6, '0');
    _wrong = 0;
  }

  Future<void> removePairing(String pairingId) async {
    _pairings.removeWhere((p) => p.id == pairingId);
    await _save();
    notifyListeners();
  }

  static String _random(int bytes) {
    final r = Random.secure();
    return base64Url.encode([for (var i = 0; i < bytes; i++) r.nextInt(256)]).replaceAll('=', '');
  }

  static String _hash(String key) => sha256.convert(utf8.encode(key)).toString();

  Future<void> _start() async {
    if (_server != null) return;
    _newCode();
    final programs = await FfmpegPrograms.find();
    _jobs = ConversionJobs(programs, input: (target, file) => SmbGateway.instance.uri(target, 'b', file).toString(), low: true, most: 64);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server = server;
    server.listen((r) => unawaited(_handle(r)));
    await _startSsdp();
    if (programs != null) unawaited(_bench(programs));
  }

  Future<void> stop() async {
    _code = null;
    await _jobs?.stopAll();
    await _server?.close(force: true);
    _server = null;
    _ssdp?.close();
    _ssdp = null;
  }

  /// Encodes 4 s of a 720p test picture, the way conversions do.
  Future<void> _bench(FfmpegPrograms programs) async {
    try {
      final w = Stopwatch()..start();
      final r = await Process.run(programs.ffmpeg, [
        ...FfmpegPrograms.quiet, '-f', 'lavfi', '-i', 'testsrc2=s=1280x720:r=30:d=4', //
        '-c:v', 'libx264', '-preset', 'ultrafast', '-f', 'null', '-',
      ]);
      if (r.exitCode == 0) benchmark = 120 / (w.elapsedMilliseconds / 1000);
    } on ProcessException {
      // No ffmpeg: it converts nothing, and says so.
    }
  }

  Future<void> _startSsdp() async {
    try {
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 1900, reuseAddress: true, reusePort: true);
      s.joinMulticast(InternetAddress('239.255.255.250'));
      s.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null) return;
        final text = utf8.decode(d.data, allowMalformed: true);
        if (!text.startsWith('M-SEARCH') || !(text.contains(helperService) || text.contains('ssdp:all'))) return;
        unawaited(_answer(s, d.address, d.port));
      });
      _ssdp = s;
    } on SocketException catch (e) {
      // Found by its typed address only.
      debugPrint('Convert for other TVs: no SSDP (${e.message})');
    }
  }

  Future<void> _answer(RawDatagramSocket s, InternetAddress to, int toPort) async {
    final here = await _localAddressFor(to) ?? '127.0.0.1';
    s.send(
        utf8.encode('HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\nEXT:\r\nLOCATION: http://$here:$port/\r\n'
            'SERVER: Linux/1.0 UPnP/1.0 NightingaleTV/1.0\r\nST: $helperService\r\nUSN: uuid:$id::$helperService\r\n\r\n'),
        to,
        toPort);
  }

  /// This device's address on [to]'s network.
  static Future<String?> _localAddressFor(InternetAddress to) async {
    try {
      final s = await Socket.connect(to, 9, timeout: const Duration(milliseconds: 300));
      final a = s.address.address;
      s.destroy();
      return a;
    } on Object {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (!a.isLoopback) return a.address;
        }
      }
      return null;
    }
  }

  // ---- Requests ---------------------------------------------------------------------

  HelperPairing? _paired(HttpRequest r) {
    final auth = r.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!auth.startsWith('Bearer ')) return null;
    final hash = _hash(auth.substring(7).trim());
    return _pairings.where((p) => p.keyHash == hash).firstOrNull;
  }

  static void _json(HttpResponse r, Object body, [int status = 200]) {
    r.statusCode = status;
    r.headers.contentType = ContentType.json;
    r.write(jsonEncode(body));
  }

  Future<void> _handle(HttpRequest r) async {
    final response = r.response;
    try {
      switch ((r.method, r.uri.path)) {
        case ('GET', '/' || '/about'):
          // Only what it is: nothing of its library.
          _json(response, {'service': helperService, 'name': deviceName, 'id': id});
        case ('POST', '/pair'):
          await _pair(r);
        case ('GET', '/info'):
          if (_paired(r) == null) return _refuse(response);
          _json(response, {'id': id, 'name': deviceName, 'shares': await _shareIds(), 'speed': benchmark});
        case ('GET', '/convert'):
          if (_paired(r) == null) return _refuse(response);
          await _convert(r);
        default:
          response.statusCode = HttpStatus.notFound;
      }
    } on Object catch (e) {
      debugPrint('Convert for other TVs: ${e.runtimeType}');
      try {
        response.statusCode = HttpStatus.internalServerError;
      } on Object {
        // Already streaming.
      }
    } finally {
      try {
        await response.close();
      } on Object {
        // The TV left.
      }
    }
  }

  /// No key, or not this helper's: nothing, not even why.
  static void _refuse(HttpResponse r) => r.statusCode = HttpStatus.unauthorized;

  Future<void> _pair(HttpRequest r) async {
    final body = jsonDecode(await utf8.decodeStream(r).timeout(const Duration(seconds: 5)));
    final code = _code;
    if (code == null || body is! Map || '${body['code'] ?? ''}'.trim() != code) {
      if (++_wrong >= _wrongLimit) _newCode();
      notifyListeners();
      return _json(r.response, {'error': 'wrong code'}, HttpStatus.forbidden);
    }
    final key = _random(24);
    while (_pairings.length >= maxPairings) {
      _pairings.removeAt(0);
    }
    final name = '${body['name'] ?? ''}'.trim();
    _pairings.add(HelperPairing(id: _random(6), name: name.length > 60 ? name.substring(0, 60) : name, keyHash: _hash(key), paired: DateTime.now()));
    _newCode();
    await _save();
    notifyListeners();
    _json(r.response, {'key': key, 'id': id, 'name': deviceName});
  }

  // ---- The shares it has ------------------------------------------------------------

  final _known = <String, ({DateTime at, _Share? share})>{};

  /// Every share id in a profile here.
  Future<List<String>> _shareIds() async {
    final out = <String>{};
    final profiles = Directory('${root.root.path}/profiles');
    if (!await profiles.exists()) return const [];
    await for (final dir in profiles.list()) {
      if (dir is! Directory) continue;
      final json = await AppStorage.existing(dir).readRaw('smb_shares.json');
      if (json is Map<String, Object?>) out.addAll((json['shares'] as Map? ?? const {}).keys.map((k) => '$k'));
    }
    return out.toList();
  }

  /// Share [serverId] as a profile here has it: its address, sign-in and
  /// scan. Looked up at most once a minute.
  Future<_Share?> _share(String serverId) async {
    final known = _known[serverId];
    if (known != null && DateTime.now().difference(known.at) < const Duration(minutes: 1)) return known.share;
    _Share? found;
    final profiles = Directory('${root.root.path}/profiles');
    if (await profiles.exists()) {
      await for (final dir in profiles.list()) {
        if (dir is! Directory || found != null) continue;
        final storage = AppStorage.existing(dir);
        final shares = await storage.readRaw('smb_shares.json');
        final all = shares is Map<String, Object?> ? shares['shares'] as Map? : null;
        final config = all?[serverId];
        if (config == null) continue;
        final sessions = [
          await storage.readRaw('session.json'),
          for (final s in ((await storage.readRaw('servers.json')) as Map?)?['servers'] as List? ?? const []) (s as Map)['session'],
        ];
        for (final raw in sessions.whereType<Map<String, Object?>>()) {
          final session = ServerSession.fromJson(raw);
          if (session.kind != ServerKind.smb || session.serverId != serverId) continue;
          final credentials = await SecretStore(storage, cipher: SecretStore.cipherFor(root)).get(session.accessToken);
          final address = SmbAddress.parse(session.serverUrl);
          if (credentials == null || address == null) continue;
          final scan = SmbScan.fromJson(await storage.readRaw('smb_scan/${smbIdOf(serverId)}.json'));
          found = _Share(address, credentials, SmbShareConfig.fromJson(config), scan);
          break;
        }
      }
    }
    _known[serverId] = (at: DateTime.now(), share: found);
    return found;
  }

  final _targets = <String, String>{};
  int get running => _jobs?.running ?? 0;

  Future<void> _convert(HttpRequest r) async {
    final q = r.uri.queryParameters;
    final response = r.response;
    final share = await _share(q['share'] ?? '');
    final item = share?.scan.byId[q['item'] ?? ''];
    // Only a file of a folder mapped here, as the TV knows it.
    final mapped = item != null && share!.config.mappings.any((m) => smbInside(item.path, m.path));
    if (share == null || item == null || !mapped || '${item.size}' != q['size'] || '${item.modified}' != q['modified']) {
      response.statusCode = HttpStatus.forbidden;
      return;
    }
    if (running + (exportBusy?.call() ?? 0) >= streamLimit) {
      response.statusCode = HttpStatus.serviceUnavailable;
      return;
    }
    final gateway = await SmbGateway.ensureStarted();
    final target = _targets[q['share']!] ??= 'h${SmbGateway.newTarget()}';
    await gateway.register(target, GatewayTarget(address: share.address, credentials: share.credentials, serverId: q['share']!));
    await gateway.setFiles(target, {item.id: GatewayFile(path: item.path, size: item.size, modified: item.modified)});
    await _jobs!.convert(response, gateway.uri(target, 'b', item.id).toString(), ConversionSpec.fromQuery(q));
  }

  /// What this helper converts at, for the TVs' choice.
  ConvertSpeeds? speeds;
}

class _Share {
  _Share(this.address, this.credentials, this.config, this.scan);

  final SmbAddress address;
  final SmbCredentials credentials;
  final SmbShareConfig config;
  final SmbScan scan;
}
