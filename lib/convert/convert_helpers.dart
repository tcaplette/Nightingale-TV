import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/app_storage.dart';
import '../server/smb/smb_gateway.dart';
import 'convert_helper.dart';

/// A Nightingale TV this device converts with (smb-conversion D9).
class PairedHelper {
  PairedHelper({required this.id, required this.name, required this.url, required this.key, this.seen = const {}});

  factory PairedHelper.fromJson(Map<String, Object?> j) => PairedHelper(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        url: Uri.parse(j['url'] as String),
        key: j['key'] as String,
        seen: {
          for (final e in ((j['seen'] as Map?) ?? const {}).entries)
            '${e.key}': DateTime.tryParse('${e.value}') ?? DateTime(0)
        },
      );

  final String id;
  final String name;
  final Uri url;

  /// This device's key there.
  final String key;

  /// When it last said it had each share.
  Map<String, DateTime> seen;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'url': '$url',
        'key': key,
        if (seen.isNotEmpty) 'seen': {for (final e in seen.entries) e.key: e.value.toIso8601String()},
      };
}

/// What a helper said of itself.
typedef HelperInfo = ({List<String> shares, double speed});

/// The helpers this device is paired with: finding, pairing, and choosing
/// one for a share's file (fastest that answers and has the share).
class ConvertHelpers extends ChangeNotifier {
  ConvertHelpers(this.root, {required this.deviceName});

  static const file = 'convert_helpers.json';

  /// How long a helper that stopped answering still counts for what may be
  /// scheduled.
  static const away = Duration(hours: 24);

  final AppStorage root;
  final String deviceName;
  final _helpers = <PairedHelper>[];
  List<PairedHelper> get helpers => List.unmodifiable(_helpers);
  final _info = <String, ({DateTime at, HelperInfo? info})>{};

  Future<void> load() async {
    final json = await root.readJson(file);
    if (json is List) {
      for (final h in json.whereType<Map<String, Object?>>()) {
        try {
          _helpers.add(PairedHelper.fromJson(h));
        } on Object {
          // An unreadable entry is dropped.
        }
      }
    }
    await _toGateway();
  }

  Future<void> _save() => root.writeJson(file, [for (final h in _helpers) h.toJson()], private: true);

  /// The gateway asks helpers by their id.
  Future<void> _toGateway() async {
    if (!SmbGateway.running) return;
    await SmbGateway.instance.setHelpers({for (final h in _helpers) h.id: (base: h.url, key: h.key)});
  }

  static Future<Map<String, Object?>?> _getJson(Uri uri, {String? key, Duration timeout = const Duration(seconds: 3)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final r = await client.getUrl(uri).timeout(timeout);
      if (key != null) r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      final a = await r.close().timeout(timeout);
      if (a.statusCode != 200) return null;
      final json = jsonDecode(await utf8.decodeStream(a).timeout(timeout));
      return json is Map<String, Object?> ? json : null;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Helpers on the network that answer an SSDP search, with their names.
  Future<List<({Uri url, String name, String id})>> find({Duration wait = const Duration(seconds: 3)}) async {
    final found = <String, Uri>{};
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    s.listen((e) {
      if (e != RawSocketEvent.read) return;
      final d = s.receive();
      final text = d == null ? '' : utf8.decode(d.data, allowMalformed: true);
      final location = RegExp(r'^LOCATION:\s*(\S+)', multiLine: true, caseSensitive: false).firstMatch(text)?[1];
      if (text.contains(helperService) && location != null) found[location] = Uri.parse(location);
    });
    final search = utf8.encode('M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 2\r\nST: $helperService\r\n\r\n');
    for (var i = 0; i < 2; i++) {
      s.send(search, InternetAddress('239.255.255.250'), 1900);
      await Future<void>.delayed(wait ~/ 2);
    }
    s.close();
    return [
      for (final url in found.values) ?await about(url),
    ];
  }

  /// What answers at [url], when it's a helper.
  Future<({Uri url, String name, String id})?> about(Uri url) async {
    final json = await _getJson(url.replace(path: '/about'));
    if (json == null || json['service'] != helperService) return null;
    return (url: url.replace(path: '/'), name: '${json['name'] ?? ''}', id: '${json['id'] ?? ''}');
  }

  /// A typed address: `host` or `host:port`.
  static Uri? parseAddress(String typed) {
    var t = typed.trim();
    if (t.isEmpty) return null;
    if (!t.contains('://')) t = 'http://$t';
    final u = Uri.tryParse(t);
    if (u == null || u.host.isEmpty) return null;
    return u.replace(port: u.hasPort ? u.port : ConvertHelper.defaultPort, path: '/');
  }

  /// Pairs with the helper at [url] using the [code] it shows. False when
  /// the code was wrong (or it didn't answer).
  Future<bool> pair(Uri url, String code) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final r = await client.postUrl(url.replace(path: '/pair'));
      final body = utf8.encode(jsonEncode({'code': code.trim(), 'name': deviceName}));
      r.headers.contentType = ContentType.json;
      r.contentLength = body.length;
      r.add(body);
      final a = await r.close();
      if (a.statusCode != 200) return false;
      final json = jsonDecode(await utf8.decodeStream(a)) as Map<String, Object?>;
      _helpers.removeWhere((h) => h.id == json['id']);
      _helpers.add(PairedHelper(id: '${json['id']}', name: '${json['name'] ?? ''}', url: url, key: '${json['key']}'));
      _info.clear();
      await _save();
      await _toGateway();
      notifyListeners();
      return true;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> remove(String id) async {
    _helpers.removeWhere((h) => h.id == id);
    await _save();
    await _toGateway();
    notifyListeners();
  }

  /// What [h] says of itself now (asked at most once a minute); null when
  /// it doesn't answer.
  Future<HelperInfo?> info(PairedHelper h, {bool fresh = false}) async {
    final cached = _info[h.id];
    if (!fresh && cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 1)) return cached.info;
    final json = await _getJson(h.url.replace(path: '/info'), key: h.key, timeout: const Duration(seconds: 2));
    final HelperInfo? info = json == null
        ? null
        : (shares: [for (final s in json['shares'] as List? ?? const []) '$s'], speed: (json['speed'] as num?)?.toDouble() ?? 0);
    _info[h.id] = (at: DateTime.now(), info: info);
    if (info != null) {
      final now = DateTime.now();
      h.seen = {...h.seen, for (final s in info.shares) s: now};
      unawaited(_save());
    }
    return info;
  }

  /// The helper to convert share [serverId]'s file with: of those that
  /// answer and have it, the fastest.
  Future<String?> helperFor(String serverId) async {
    PairedHelper? best;
    var speed = -1.0;
    for (final h in _helpers) {
      final i = await info(h);
      if (i == null || !i.shares.contains(serverId)) continue;
      if (i.speed > speed) (best, speed) = (h, i.speed);
    }
    if (best != null) await _toGateway();
    return best?.id;
  }

  /// Whether a helper had share [serverId] in the last 24 hours: what it
  /// converts stays on the schedule while it's away for a moment.
  bool knownFor(String serverId) =>
      _helpers.any((h) => DateTime.now().difference(h.seen[serverId] ?? DateTime(0)) < away);

  /// Shares [ids] a paired helper doesn't have, for "Add this share on…".
  Future<List<String>> missingOn(PairedHelper h, Iterable<String> ids) async {
    final i = await info(h);
    return i == null ? const [] : [for (final id in ids) if (!i.shares.contains(id)) id];
  }
}
