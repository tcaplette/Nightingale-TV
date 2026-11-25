import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../commercials/commercial_pool.dart';
import '../../convert/conversion.dart';
import '../../convert/convert_speeds.dart';
import '../../convert/device_fit.dart';
import '../../data/app_storage.dart';
import '../../l10n/tr.dart';
import '../../library/index_builder.dart';
import '../../library/library_index.dart';
import '../../playback/playback_diagnostics.dart';
import '../live_tv.dart';
import '../media_server.dart';
import 'smb_connection.dart';
import 'smb_gateway.dart';
import 'smb_history.dart';
import 'smb_index.dart';
import 'smb_library.dart';
import 'smb_names.dart';
import 'smb_probe.dart';
import 'smb_share.dart';

/// What a profile keeps of one of its shares, besides its sign-in (in
/// `smb_shares.json`, by the share's server id).
class SmbShareConfig {
  SmbShareConfig({this.mappings = const [], this.historyName, this.keepLocal = false, this.smb1 = false});

  List<SmbMapping> mappings;

  /// The history name, when it isn't the profile's name.
  String? historyName;

  /// History stays on this device, even on a writable share.
  bool keepLocal;

  /// The host spoke SMB1 last time.
  bool smb1;

  Map<String, Object?> toJson() => {
        'folders': [for (final m in mappings) m.toJson()],
        'historyName': ?historyName,
        if (keepLocal) 'keepLocal': true,
        if (smb1) 'smb1': true,
      };

  factory SmbShareConfig.fromJson(Object? j) => j is! Map<String, Object?>
      ? SmbShareConfig()
      : SmbShareConfig(
          mappings: [for (final m in (j['folders'] as List? ?? const [])) ?SmbMapping.fromJson(m)],
          historyName: j['historyName'] as String?,
          keepLocal: j['keepLocal'] == true,
          smb1: j['smb1'] == true,
        );
}

/// Why a file is in Can't play (smb-conversion).
enum CantPlayReason {
  damaged,
  noVideo,

  /// Too much for this device, with no other Nightingale TV to convert it.
  tooMuch,
}

/// What a share's client needs of the profile it belongs to.
abstract interface class SmbProfileContext {
  AppStorage get storage;

  /// The share's settings; saved with [saveConfig].
  SmbShareConfig configOf(String serverId);
  Future<void> saveConfig(String serverId);

  /// The password [ref] stands for.
  Future<SmbCredentials?> credentials(String ref);
  Future<void> forget(String ref);

  /// The profile's name, the history name unless one is chosen.
  String get profileName;

  /// This profile's own file name on shares.
  String get historyFileId;

  /// Background reads hold off meanwhile (tuning, asleep).
  ValueListenable<bool> get hold;

  /// How fast this device converts.
  ConvertSpeeds get speeds;

  /// A paired Nightingale TV that has share [serverId] and answers, fastest
  /// first; null when there's none.
  Future<String?> helperFor(String serverId);

  /// Whether a helper had share [serverId] in the last 24 hours, so what it
  /// converts stays scheduled while it's away for a moment.
  bool helperSeen(String serverId);

  /// The library's files that are ready changed: build it again from the
  /// saved scans.
  void filesReady(SmbServer server, {required bool last});

  /// Something shown about the share changed.
  void changed();

  /// [work] is what a closed share still writes; the profile's close waits
  /// for it.
  void closing(Future<void> work);
}

/// A share as one of a profile's servers (design D1). One share is one
/// server, its address `smb://host[:port]/share`.
class SmbServer implements MediaServer {
  SmbServer(this._session, this._profile, {SmbOpener? open})
      : address = SmbAddress.parse(_session.serverUrl)!,
        target = SmbGateway.newTarget() {
    _connection = SmbConnection(address, _credentials, knownSmb1: config.smb1, open: open)
      ..onVersion = (smb1) {
        config.smb1 = smb1;
        unawaited(_profile.saveConfig(serverId));
        _profile.changed();
      };
    _ready = _load();
  }

  ServerSession _session;
  ServerSession get session => _session;

  /// It was renamed.
  void rename(String name) => _session = _session.withServerName(name);

  final SmbProfileContext _profile;
  final SmbAddress address;

  /// Its name at the gateway.
  final String target;
  late final SmbConnection _connection;
  late final Future<void> _ready;
  bool _closed = false;

  String get serverId => session.serverId!;
  SmbShareConfig get config => _profile.configOf(serverId);

  SmbGateway get _gateway => SmbGateway.instance;

  String get _key => smbIdOf(serverId);
  String get _scanFile => 'smb_scan/$_key.json';
  String get _probeFile => 'smb_probe/$_key.json';
  String get _cantPlayFile => 'smb_unplayable/$_key.json';

  SmbScan _scan = SmbScan.empty;
  Map<String, SmbProbe> _probes = {};
  final _cantPlay = <String, CantPlayReason>{};
  late final history = SmbHistory(_profile.storage, serverId: serverId, deviceFileId: _profile.historyFileId);
  SmbProber? _prober;

  /// Connected with SMB1 (old and not encrypted).
  bool get smb1 => config.smb1;

  /// Where its history went last; null before it was written.
  ValueListenable<HistoryPlace?> get historyPlace => history.placeShown;

  /// The history name in use.
  String get historyName => config.historyName ?? _profile.profileName;

  /// Files whose length isn't read yet.
  ValueListenable<int> get filesLeft => _prober?.left ?? _none;
  static final _none = ValueNotifier(0);

  /// The files no step can play, and why.
  Map<SmbItem, CantPlayReason> get cantPlay => {
        for (final e in _cantPlay.entries)
          if (_scan.byId[e.key] != null) _scan.byId[e.key]!: e.value
      };

  /// What the last scan found.
  SmbScan get scan => _scan;

  /// Tests: the speed class ([ConvertSpeeds.classOf]) of [itemId]'s
  /// picture, as decisions look it up; null before it's read.
  @visibleForTesting
  Future<String?> debugVideoKind(String itemId) async {
    final item = _scan.byId[itemId];
    final video = item == null ? null : (await _probeNow(item))?.video;
    return video == null ? null : ConvertSpeeds.classOf(video);
  }

  /// Tests: the files listed as unplayable, by id.
  @visibleForTesting
  Map<String, CantPlayReason> get cantPlayIds => _cantPlay;

  Future<SmbCredentials?> _credentials() => _profile.credentials(session.accessToken);

  Future<void> _load() async {
    final storage = _profile.storage;
    _scan = SmbScan.fromJson(await storage.readJson(_scanFile));
    final probes = await storage.readJson(_probeFile);
    if (probes is Map<String, Object?>) {
      _probes = {
        for (final e in probes.entries)
          if (e.value is Map<String, Object?>) e.key: SmbProbe.fromJson(e.value as Map<String, Object?>)
      };
    }
    final cant = await storage.readJson(_cantPlayFile);
    if (cant is Map<String, Object?>) {
      for (final e in cant.entries) {
        final reason = CantPlayReason.values.asNameMap()[e.value];
        if (reason != null) _cantPlay[e.key] = reason;
      }
    }
    await history.load();
    final credentials = await _credentials();
    if (_closed) return;
    final gateway = await SmbGateway.ensureStarted();
    if (credentials != null) {
      await gateway.register(
          target, GatewayTarget(address: address, credentials: credentials, smb1: config.smb1, serverId: serverId));
      await gateway.setFiles(target, _gatewayFiles());
    }
  }

  // ---- What the gateway serves -------------------------------------------------

  Map<String, GatewayFile> _gatewayFiles() {
    final files = <String, GatewayFile>{};
    void image(SmbImage? i) => switch (i) {
          final i? => files[i.id] = GatewayFile(path: i.path, size: i.size, modified: i.modified),
          null => null,
        };

    for (final i in _scan.items) {
      files[i.id] = GatewayFile(path: i.path, size: i.size, modified: i.modified);
      image(i.poster);
      for (final s in i.subtitles) {
        files[smbIdOf(s.path)] = GatewayFile(path: s.path, size: s.size, modified: s.modified);
      }
    }
    for (final s in _scan.shows) {
      image(s.poster);
      image(s.logo);
    }
    _scan.albums.values.forEach(image);
    return files;
  }

  /// Folders of the scan, by id: every folder an item is in, up to its
  /// mapped one.
  late Map<String, String> _folders = _foldersOf(_scan);

  Map<String, String> _foldersOf(SmbScan scan) {
    final folders = <String, String>{};
    for (final m in config.mappings) {
      folders[smbIdOf('${m.path}/')] = m.path;
    }
    for (final i in scan.items) {
      final root = config.mappings.where((m) => smbInside(i.path, m.path)).fold<String?>(
          null, (best, m) => best == null || m.path.length > best.length ? m.path : best);
      var f = i.folder;
      while (root != null && f.length > root.length && smbInside(f, root)) {
        folders[smbIdOf('$f/')] = f;
        f = f.contains('/') ? f.substring(0, f.lastIndexOf('/')) : '';
      }
    }
    return folders;
  }

  // ---- MediaServer ---------------------------------------------------------------

  @override
  ServerKind get kind => ServerKind.smb;

  @override
  String get serverUrl => session.serverUrl;

  @override
  String get deviceId => session.deviceId;

  @override
  Map<String, String> get authHeaders => const {};

  /// [e] as the rest of the app knows failures.
  ServerException _failure(SmbException e) => switch (e.kind) {
        SmbErrorKind.unreachable => ServerException(tr.couldNotReach(session.serverName)),
        SmbErrorKind.wrongSignIn => ServerException(tr.wrongUsernameOr, statusCode: 401),
        SmbErrorKind.guestsRefused => ServerException(tr.smbGuestsRefused, statusCode: 401),
        SmbErrorKind.noAccess => ServerException(tr.smbNoAccess, statusCode: 403),
        SmbErrorKind.gone => ServerException(tr.smbShareGone(session.serverName), statusCode: 404),
        SmbErrorKind.other => ServerException(tr.couldNotReach(session.serverName), statusCode: 500),
      };

  Future<T> _use<T>(Future<T> Function(SmbShare share) task) async {
    try {
      final result = await _connection.use(task);
      // A connection that works again: what waited for it goes now.
      if (history.due()) unawaited(_syncHistory());
      return result;
    } on SmbException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<ServerInfo> publicInfo() async {
    await _use((share) => share.stat(''));
    return ServerInfo(url: serverUrl, name: session.serverName, version: smb1 ? 'SMB1' : 'SMB', id: serverId, kind: ServerKind.smb);
  }

  @override
  Future<void> checkSession() => _use((share) => share.stat(''));

  /// Closes its connections and forgets its password; its history on the
  /// share stays.
  @override
  Future<void> logout() async {
    await _connection.close();
    await _profile.forget(session.accessToken);
  }

  @override
  Future<List<ServerLibrary>> libraries() async {
    await _ready;
    return [
      for (final m in config.mappings)
        ServerLibrary(
            id: smbIdOf('${m.path}/'),
            name: m.path.isEmpty ? session.serverName : m.path.split('/').last,
            collectionType: m.type.collectionType)
    ];
  }

  /// The share's folders at [path], for mapping them.
  Future<List<String>> foldersAt(String path) => _use((share) async => [
        for (final e in await share.list(path))
          if (e.isFolder && !SmbNames.skipsFolder(e.name, hidden: e.hidden)) e.name
      ]..sort(FolderNode.naturalCompare));

  @override
  Future<LibraryIndex> fetchLibraryIndex(
      {List<CommercialPool> pools = const [],
      Set<String> channelRoots = const {},
      bool providerIds = false,
      void Function(String status)? onStatus,
      void Function(List<ServerLibrary> libraries)? onLibraries}) async {
    await _ready;
    onLibraries?.call(await libraries());
    if (!_rebuildOnly) {
      onStatus?.call(tr.scanning(session.serverName));
      await _rescan(onStatus);
    }
    _rebuildOnly = false;
    // A first scan waits for a few files to be read, so the first lineup
    // has something on it; the rest are read in the background.
    final ready = _scan.items.where(_hasLength).length;
    if (ready == 0 && _scan.items.isNotEmpty) {
      onStatus?.call(tr.smbReadingFiles(session.serverName));
      await _probeFirst();
    }
    return _index(pools, channelRoots);
  }

  /// The next [fetchLibraryIndex] builds from the saved scan, without
  /// listing the share (files became ready).
  bool _rebuildOnly = false;
  void rebuildNext() => _rebuildOnly = true;

  bool _hasLength(SmbItem i) {
    final p = _probes[i.id];
    return p != null && p.matches(i.size, i.modified) ? p.duration != null : i.runtime != null;
  }

  Future<void> _rescan(void Function(String)? onStatus) async {
    final clock = Stopwatch()..start();
    final shared = await _sharedIds();
    final fresh = await _use((share) => SmbScanner(share, config.mappings, previous: _scan, sharedIds: shared, onFolder: (folders, files) {
          if (folders % 25 == 0) onStatus?.call(tr.smbScanningFolders(session.serverName, folders));
        }).scan());
    _scan = fresh;
    _folders = _foldersOf(fresh);
    PlaybackDiagnostics.note('SCAN', 'smb ${session.serverName}: ${fresh.items.length} files in ${clock.elapsedMilliseconds} ms');
    await _profile.storage.writeJson(_scanFile, fresh.toJson());
    await _gateway.setFiles(target, _gatewayFiles());
    if (fresh.ids.length != shared.length || !mapEquals(fresh.ids, shared)) unawaited(_saveSharedIds(fresh.ids));
    // What the files are like, read in the background: changed ones again.
    final known = {for (final i in fresh.items) i.id};
    _probes.removeWhere((id, _) => !known.contains(id));
    _cantPlay.removeWhere((id, _) => !known.contains(id));
    // Files of every show and folder in turn, so channels fill evenly.
    final waiting = [for (final i in fresh.items) if (!(_probes[i.id]?.matches(i.size, i.modified) ?? false)) i];
    final turn = <String, int>{};
    int place(SmbItem i) => turn.update(i.showId ?? i.folder, (n) => n + 1, ifAbsent: () => 0);
    final order = [for (final i in waiting) (place(i), i)]..sort((a, b) => a.$1.compareTo(b.$1));
    _proberOn().add([for (final (_, i) in order) i.id]);
    if (_profile.speeds case final _) unawaited(_trySpeeds());
    await _syncHistory(force: true);
  }

  // ---- Ids moved files keep, shared by every device ---------------------------

  static const _idsFile = '.nightingale/ids.json';

  Future<Map<String, String>> _sharedIds() async {
    try {
      final json = jsonDecode(utf8.decode(await _connection.use((s) => s.readAll(_idsFile))));
      return (json as Map).cast<String, String>();
    } on Object {
      return const {};
    }
  }

  Future<void> _saveSharedIds(Map<String, String> ids) async {
    if (config.keepLocal) return;
    try {
      await _connection.use((s) async {
        await s.makeFolder('.nightingale');
        final tmp = '$_idsFile.${Random().nextInt(1 << 30).toRadixString(36)}.tmp';
        await s.write(tmp, Uint8List.fromList(utf8.encode(jsonEncode(ids))));
        await s.rename(tmp, _idsFile);
      });
    } on SmbException {
      // A read-only share keeps them on the device, in the scan.
    }
  }

  // ---- Reading files ----------------------------------------------------------------

  SmbProber _proberOn() => _prober ??= SmbProber(
        probe: _probeOne,
        onProbed: (id, p) {
          _probes[id] = p;
          _saveProbesSoon();
        },
        onBatch: ({required bool last}) async {
          if (_closed) return;
          await _flushProbes();
          await _checkPlayable();
          if (!_closed) _profile.filesReady(this, last: last);
          _profile.changed();
        },
        hold: _profile.hold,
      );

  Future<SmbProbe?> _probeOne(String id) async {
    final item = _scan.byId[id];
    final programs = await FfmpegPrograms.find();
    if (item == null || programs == null) return null;
    final Map<String, Object?>? json;
    try {
      json = await programs.probe(_gateway.uri(target, 'b', id).toString());
    } on FfmpegMissing {
      return null;
    }
    if (json == null) {
      // Gone, or the share is: only a share that answers means a damaged
      // file.
      try {
        await _connection.use((s) => s.stat(item.path));
      } on SmbException catch (e) {
        if (e.kind == SmbErrorKind.unreachable) return null;
        return SmbProbe(size: item.size, modified: item.modified, damaged: true);
      }
    }
    return SmbProbe.parse(json, size: item.size, modified: item.modified);
  }

  /// The first lineup's files: up to 60 of them, or 20 s of reading.
  Future<void> _probeFirst() async {
    final prober = _proberOn();
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end) && _scan.items.where(_hasLength).length < 60 && prober.left.value > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await _flushProbes();
  }

  Timer? _probeSave;
  void _saveProbesSoon() => _closed ? null : _probeSave ??= Timer(const Duration(seconds: 10), () => unawaited(_flushProbes()));

  Future<void> _flushProbes() async {
    _probeSave?.cancel();
    _probeSave = null;
    await _profile.storage.writeJson(_probeFile, {for (final e in _probes.entries) e.key: e.value.toJson()});
  }

  SmbProbe? _probeOf(SmbItem item) {
    final p = _probes[item.id];
    return p != null && p.matches(item.size, item.modified) ? p : null;
  }

  /// [item]'s probe, read now when it isn't known yet.
  Future<SmbProbe?> _probeNow(SmbItem item) async {
    if (_probeOf(item) case final p?) return p;
    final p = await _probeOne(item.id);
    if (p != null) {
      _probes[item.id] = p;
      _saveProbesSoon();
    }
    return p;
  }

  // ---- Can't play (design D10) --------------------------------------------------------

  /// Works out which files nothing can play, after files are read or a
  /// helper is paired; [again]: the user asked to check every listed file.
  Future<void> _checkPlayable({bool again = false}) async {
    final before = Map.of(_cantPlay);
    if (again) _cantPlay.clear();
    final programs = await FfmpegPrograms.find();
    final helper = _profile.helperSeen(serverId) || await _profile.helperFor(serverId) != null;
    for (final i in _scan.items) {
      final p = _probeOf(i);
      if (p == null) continue;
      final reason = await _whyNot(i, p, programs: programs != null, helper: helper);
      if (reason == null) {
        // A helper offline for a moment doesn't take files off the air;
        // the 24-hour rule is the profile's (it checks again at refresh).
        _cantPlay.remove(i.id);
      } else {
        _cantPlay[i.id] = reason;
      }
    }
    if (!mapEquals(before, _cantPlay)) {
      await _profile.storage.writeJson(_cantPlayFile, {for (final e in _cantPlay.entries) e.key: e.value.name});
    }
  }

  /// Check again: every file listed is looked at once more.
  Future<void> checkAgain() async {
    for (final id in _cantPlay.keys.toList()) {
      _probes.remove(id);
    }
    _proberOn().add(_cantPlay.keys.toList());
    await _prober!.idle();
    await _checkPlayable(again: true);
    _profile.filesReady(this, last: true);
  }

  /// The device's profile, as the profile last gave it.
  static Map<String, Object?>? deviceProfileNow;

  Future<CantPlayReason?> _whyNot(SmbItem item, SmbProbe p, {required bool programs, required bool helper}) async {
    if (p.damaged) return CantPlayReason.damaged;
    final music = item.type == SmbFolderType.music;
    if (!music && p.video == null) return CantPlayReason.noVideo;
    final profile = deviceProfileNow;
    if (profile == null || music) return null;
    final method = DeviceFit.decide(p, item.container, profile);
    if (method == FitMethod.direct) return null;
    // What a conversion decodes must decode: a stream current decoders
    // refuse would leave the channel with no picture at every airing.
    if (programs && await _decodes(item, p, video: method == FitMethod.transcode) == false) return CantPlayReason.damaged;
    if (method == FitMethod.directStream) return programs || helper ? null : CantPlayReason.tooMuch;
    if (helper) return null;
    if (!programs) return CantPlayReason.tooMuch;
    final fast = await _profile.speeds.fastEnough(ConvertSpeeds.classOf(p.video!));
    return fast == false ? CantPlayReason.tooMuch : null;
  }

  /// Whether what converting [item] decodes does (its sound, and with
  /// [video] its picture), tried once per file and kept with its probe.
  Future<bool?> _decodes(SmbItem item, SmbProbe p, {required bool video}) async {
    if (p.decodes case final known?) return known;
    final programs = await FfmpegPrograms.find();
    if (programs == null || _closed) return null;
    final bool? result;
    try {
      result = await programs.decodes(_gateway.uri(target, 'b', item.id).toString(), video: video, audio: p.audio.isNotEmpty);
    } on FfmpegMissing {
      return null;
    }
    if (result == null || _closed) return null;
    if (!result) {
      // Only a share that answers means the file is at fault.
      try {
        await _connection.use((s) => s.stat(item.path));
      } on SmbException {
        return null;
      }
    }
    _probes[item.id] = p.withDecodes(result);
    _saveProbesSoon();
    return result;
  }

  /// Tries each kind of picture this device would convert, once, while
  /// nothing tunes (design D8).
  Future<void> _trySpeeds() async {
    final programs = await FfmpegPrograms.find();
    final profile = deviceProfileNow;
    if (programs == null || profile == null) return;
    final tried = <String>{};
    for (final i in _scan.items) {
      final p = _probeOf(i);
      final video = p?.video;
      if (p == null || video == null || DeviceFit.decide(p, i.container, profile) != FitMethod.transcode) continue;
      final kind = ConvertSpeeds.classOf(video);
      if (!tried.add(kind) || await _profile.speeds.speedOf(kind) != null) continue;
      while (_profile.hold.value && !_closed) {
        await Future<void>.delayed(const Duration(seconds: 5));
      }
      if (_closed) return;
      await trySpeed(i, p, programs);
    }
  }

  /// Converts 10 s of [item] to nowhere at a job's settings, and keeps how
  /// fast that went.
  Future<double> trySpeed(SmbItem item, SmbProbe p, FfmpegPrograms programs) async {
    final spec = _spec(p, item, transcode: true, startAt: Duration(seconds: min(60, (p.duration?.inSeconds ?? 0) ~/ 3)));
    const length = Duration(seconds: 10);
    final clock = Stopwatch()..start();
    var best = 0.0;
    for (final encoder in programs.android ? const [ConversionEncoder.mediacodec, ConversionEncoder.x264] : const [ConversionEncoder.x264]) {
      final args = spec.arguments(_gateway.uri(target, 'b', item.id).toString(), encoder: encoder, trial: length);
      clock.reset();
      final ok = await _runQuietly(programs, args, const Duration(seconds: 40));
      if (!ok) continue;
      best = max(best, length.inMilliseconds / max(1, clock.elapsedMilliseconds));
      if (best >= ConvertSpeeds.enough) break;
    }
    await _profile.speeds.record(ConvertSpeeds.classOf(p.video!), best);
    PlaybackDiagnostics.note('CONVERT', 'trial ${ConvertSpeeds.classOf(p.video!)}: ${best.toStringAsFixed(2)}x');
    return best;
  }

  static Future<bool> _runQuietly(FfmpegPrograms programs, List<String> args, Duration limit) async {
    try {
      final process = await Process.start(programs.ffmpeg, args, environment: programs.environment);
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      final code = await process.exitCode.timeout(limit, onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      });
      return code == 0;
    } on ProcessException {
      return false;
    }
  }

  // ---- The index -------------------------------------------------------------------------

  Future<LibraryIndex> _index(List<CommercialPool> pools, Set<String> channelRoots) async {
    final items = SmbIndexItems(_scan, _probes,
        serverId: serverId, unplayable: _cantPlay.keys.toSet(), plays: (i) => history.playsOf(_historyKey(i)));
    final poolsByItem = <String, List<String>>{};
    final commercials = <Map<String, Object?>>[];
    for (final pool in pools) {
      for (final root in pool.roots) {
        for (final id in _videosUnder(root.itemId)) {
          final map = items.byId[id];
          if (map == null) continue;
          final list = poolsByItem.putIfAbsent(id, () => []);
          if (list.isEmpty) commercials.add(map);
          if (!list.contains(pool.id)) list.add(pool.id);
        }
      }
    }
    final index = await IndexBuilder.jellyfin(
      seriesItems: items.series,
      episodeItems: items.episodes,
      movieItems: items.movies,
      commercialItems: commercials,
      songItems: items.songs,
      musicVideoItems: items.musicVideos,
      poolsByItem: poolsByItem,
    );
    if (channelRoots.isEmpty) return index;
    final roots = await fetchRoots(this, channelRoots);
    return index.withRoots(roots.found, missing: roots.missing);
  }

  String _historyKey(SmbItem i) => SmbHistory.keyOf(i, showName: _scan.showById[i.showId]?.name);

  /// Every video under [rootId]: a folder, a show, or a file itself.
  List<String> _videosUnder(String rootId) {
    if (_scan.byId[rootId] case final item?) return [item.id];
    final folder = _folders[rootId];
    if (folder != null) {
      return [for (final i in _scan.items) if (i.type != SmbFolderType.music && smbInside(i.path, folder)) i.id];
    }
    return [for (final i in _scan.items) if (i.showId == rootId) i.id];
  }

  @override
  Future<List<String>> idsUnder(String rootId) async {
    await _ready;
    final ids = [
      for (final id in _videosUnder(rootId))
        if (_scan.byId[id] case final i? when i.type == SmbFolderType.movies || i.type == SmbFolderType.tvShows || i.type == SmbFolderType.homeVideos) id
    ];
    if (ids.isEmpty && !_folders.containsKey(rootId) && _scan.byId[rootId] == null) {
      throw ServerException(tr.smbShareGone(session.serverName), statusCode: 404);
    }
    return ids;
  }

  @override
  Future<List<FolderNode>> folderTree(String libraryId) async {
    await _ready;
    final root = _folders[libraryId];
    final mapping = config.mappings.where((m) => m.path == root).firstOrNull;
    if (root == null || mapping == null) return const [];
    final nodes = <String, FolderNode>{};
    FolderNode folder(String path) => nodes.putIfAbsent(path, () {
          final name = path.split('/').last;
          final season = SmbNames.seasonOf(name);
          final show = _scan.showById[smbIdOf('$path/')];
          return FolderNode(
            id: smbIdOf('$path/'),
            name: show?.name ?? name,
            type: show != null && !show.home ? 'Series' : (season != null ? 'Season' : 'Folder'),
            index: season,
          );
        });
    final top = <FolderNode>[];
    void place(FolderNode node, String parent) {
      if (parent == root) {
        if (!top.contains(node)) top.add(node);
      } else {
        final p = folder(parent);
        if (!p.children.contains(node)) p.children.add(node);
        place(p, parent.contains('/') ? parent.substring(0, parent.lastIndexOf('/')) : '');
      }
    }

    for (final i in _scan.items) {
      if (!smbInside(i.path, root) || i.type == SmbFolderType.music || _mappingOf(i.path)?.path != root) continue;
      if (i.type == SmbFolderType.tvShows) {
        if (i.folder != root) place(folder(i.folder), i.folder.contains('/') ? i.folder.substring(0, i.folder.lastIndexOf('/')) : '');
        continue;
      }
      final leaf = FolderNode(id: i.id, name: i.title, type: i.type == SmbFolderType.movies ? FolderNode.movieType : FolderNode.videoType);
      place(leaf, i.folder);
    }
    void sortAll(List<FolderNode> list) {
      list.sort(FolderNode.compare);
      for (final n in list) {
        sortAll(n.children);
      }
    }

    sortAll(top);
    return top;
  }

  SmbMapping? _mappingOf(String path) {
    SmbMapping? best;
    for (final m in config.mappings) {
      if (smbInside(path, m.path) && (best == null || m.path.length > best.path.length)) best = m;
    }
    return best;
  }

  @override
  Future<List<MediaSegment>> commercialSegments(String itemId) async => const [];

  @override
  Uri streamUri(String sourceId) => _gateway.uri(target, 'f', sourceId);

  /// The same file for background work, which never holds up the picture.
  Uri backgroundUri(String sourceId) => _gateway.uri(target, 'b', sourceId);

  @override
  Uri get pingUri => _gateway.uri(target, 'p');

  // ---- Playing it -----------------------------------------------------------------------------

  /// What the conversion of [item] is, by [p] and the device.
  ConversionSpec _spec(SmbProbe p, SmbItem item,
      {required bool transcode, Map<String, Object?>? profile, int? maxBitrate, Duration startAt = Duration.zero, bool local = true}) {
    final video = p.video;
    final rate = maxBitrate ?? (p.bitrate > 0 ? min(p.bitrate, 20000000) : 8000000);
    var w = video?.width ?? 0, h = video?.height ?? 0;
    final hdr = video?.hdr == true && transcode;
    // Tone-mapping on the device is done in software: at most 720p.
    final (maxW, maxH) = hdr && local ? (ConversionSpec.hdrLimit.width, ConversionSpec.hdrLimit.height) : (1920, 1080);
    if (w > maxW || h > maxH) {
      final scale = min(maxW / w, maxH / h);
      w = (w * scale).round() & ~1;
      h = (h * scale).round() & ~1;
    }
    return ConversionSpec(
      copyVideo: !transcode,
      copyAudio: profile != null && DeviceFit.keepsAudio(p, profile),
      videoBitrate: rate,
      channels: profile == null ? 2 : min(DeviceFit.channels(profile), max(2, p.audio.firstOrNull?.channels ?? 2)),
      width: transcode && w > 0 ? w : null,
      height: transcode && h > 0 ? h : null,
      tonemap: hdr,
      deinterlace: transcode && video?.interlaced == true,
      startAt: startAt,
      hasAudio: p.audio.isNotEmpty,
    );
  }

  @override
  Future<PlaybackDecision> playbackDecision(String itemId,
      {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero, Map<String, Object?>? profile}) async {
    await _ready;
    final item = _scan.byId[itemId];
    if (item == null) throw ServerException(tr.theServerHas, statusCode: 404);
    if (profile != null) deviceProfileNow = profile;
    final p = await _probeNow(item);
    if (p == null) throw ServerException(tr.couldNotReach(session.serverName));
    if (p.damaged) throw ServerException(tr.theServerHas, statusCode: 404);
    final video = p.video;
    final sourceBitrate = p.bitrate > 0 ? p.bitrate : null;
    final overCap = maxBitrate != null && sourceBitrate != null && sourceBitrate > maxBitrate;
    // Linux plays everything as it is (smb-conversion); only a failed open
    // converts there.
    if (profile == null && !forceTranscode) return const PlaybackDecision.direct();
    final method = forceTranscode ? FitMethod.transcode : DeviceFit.decide(p, item.container, profile!);
    // A cap can only save the network when another TV does the work.
    final helper = await _profile.helperFor(serverId);
    if (method == FitMethod.direct && !(overCap && helper != null)) return const PlaybackDecision.direct();
    final programs = await FfmpegPrograms.find();
    var onHelper = false;
    if (method == FitMethod.transcode || method == FitMethod.direct) {
      final fast = video == null || programs == null ? false : await _profile.speeds.fastEnough(ConvertSpeeds.classOf(video));
      onHelper = helper != null && (overCap || fast == false || programs == null);
    } else if (programs == null) {
      onHelper = helper != null;
    }
    if (!onHelper && programs == null) throw ServerException(tr.theServerWould);
    final transcode = method != FitMethod.directStream || onHelper;
    var spec = _spec(p, item,
        transcode: transcode,
        profile: profile,
        maxBitrate: overCap || onHelper ? maxBitrate : null,
        local: !onHelper);
    if (onHelper) spec = spec.copyWith(helper: () => helper);
    final template = _gateway.uri(target, 'c', itemId, spec.toQuery());
    return PlaybackDecision.transcode(template,
        directStream: !transcode, sourceBitrate: sourceBitrate, sourceCodec: video?.codec);
  }

  @override
  Future<Uri> transcodeUri(Uri template,
      {required String playSessionId, required Duration startAt, SubtitleTrack? burn}) async {
    final spec = ConversionSpec.fromQuery(template.queryParameters)
        .copyWith(startAt: startAt, job: playSessionId, burn: () => burn?.position);
    return template.replace(queryParameters: spec.toQuery());
  }

  @override
  Future<List<SubtitleTrack>> subtitleTracks(String itemId) async {
    await _ready;
    final item = _scan.byId[itemId];
    if (item == null) return const [];
    final p = await _probeNow(item);
    return [
      for (final (i, s) in (p?.subtitles ?? const <ProbeSubtitle>[]).indexed)
        SubtitleTrack(
          id: 'e$i',
          codec: s.codec,
          language: s.language,
          languageTag: s.tag,
          title: s.title,
          isDefault: s.isDefault,
          isForced: s.isForced,
          position: i,
          source: itemId,
          burnsWhenConverting: SubtitleTrack.isImageCodec(s.codec),
        ),
      for (final s in item.subtitles)
        SubtitleTrack(
          id: smbIdOf(s.path),
          codec: s.name.codec,
          language: s.name.language,
          languageTag: s.name.tag,
          title: s.name.title,
          isDefault: s.name.isDefault,
          isForced: s.name.forced,
          isExternal: true,
          source: itemId,
        ),
    ];
  }

  @override
  Uri? subtitleUri(String itemId, SubtitleTrack track, {Duration startAt = Duration.zero, String? format}) {
    if (track.isImage) return null;
    final fmt = startAt > Duration.zero ? 'vtt' : (format ?? track.textFormat);
    final query = {'format': fmt, if (startAt > Duration.zero) 'start': FfmpegPrograms.seconds(startAt)};
    return track.isExternal
        ? _gateway.uri(target, 's', track.id, query)
        : _gateway.uri(target, 's', itemId, {...query, 'track': '${track.position ?? 0}'});
  }

  @override
  Future<void> stopTranscode(String playSessionId) => _gateway.stopJob(playSessionId);

  /// The job runs while it's read.
  @override
  Future<void> keepTranscodeAlive(String playSessionId) async {}

  @override
  bool get transcodeKeepsSourceTime => false;

  /// The picture of [itemId]'s conversion stalled (design D8).
  Future<void> conversionStalled(String itemId) async {
    final item = _scan.byId[itemId];
    final video = item == null ? null : _probeOf(item)?.video;
    if (video == null) return;
    if (await _profile.speeds.stalled(ConvertSpeeds.classOf(video))) {
      PlaybackDiagnostics.note('CONVERT', '${ConvertSpeeds.classOf(video)} stalled twice: too slow');
      await _checkPlayable();
      _profile.filesReady(this, last: true);
    }
  }

  @override
  Uri imageUri(String itemId, ImageKind kind, {int? maxHeight, String? tag}) {
    final show = _scan.showById[itemId];
    final item = _scan.byId[itemId];
    final SmbImage? image = kind == ImageKind.logo
        ? show?.logo ?? _scan.showById[item?.showId]?.logo
        : show?.poster ?? item?.poster ?? _scan.albums[itemId] ?? _scan.showById[item?.showId]?.poster;
    if (image != null) return _gateway.uri(target, 'i', image.id);
    // A song's own cover, inside it.
    if (kind == ImageKind.primary && item != null && (_probeOf(item)?.cover ?? false)) {
      return _gateway.uri(target, 'i', item.id, {'cover': '1'});
    }
    return _gateway.uri(target, 'i', 'none');
  }

  // ---- History (smb-history) ---------------------------------------------------------------

  @override
  Future<Duration> resumePoint(String itemId) async {
    await _ready;
    final item = _scan.byId[itemId];
    if (item == null) return Duration.zero;
    // Other devices' newest, read with a short limit that never delays the
    // picture.
    await _syncHistory().timeout(const Duration(seconds: 1), onTimeout: () {});
    return history.resumeOf(_historyKey(item));
  }

  @override
  Future<void> reportPlaybackStart(PlaybackReport report) async {}

  @override
  Future<void> reportPlaybackProgress(PlaybackReport report) async {
    final item = _scan.byId[report.itemId];
    if (item == null) return;
    // During a viewing the share hears of it at most once a minute.
    if (history.due()) unawaited(_syncHistory());
  }

  @override
  Future<void> reportPlaybackStopped(PlaybackReport report) async {
    await _ready;
    final item = _scan.byId[report.itemId];
    if (item == null) return;
    final runtime = report.runtime ?? _probeOf(item)?.duration ?? item.runtime ?? Duration.zero;
    await history.record(_historyKey(item), report.position, runtime);
    unawaited(_syncHistory(force: true));
  }

  Future<void>? _syncing;

  Future<void> _syncHistory({bool force = false}) => _syncing ??= () async {
        try {
          await _connection.use((share) => history.sync(share,
              historyName: config.historyName ?? _profile.profileName, keepLocal: config.keepLocal));
          _profile.changed();
        } on SmbException catch (e) {
          // Written when the share answers again.
          debugPrint('SMB history not written: ${e.kind.name}');
        }
      }().whenComplete(() => _syncing = null);

  @override
  LiveTv? get liveTv => null;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _prober?.close();
    _profile.closing(Future.wait([
      _flushProbes(),
      _connection.close(),
      if (SmbGateway.running) _gateway.unregister(target),
    ]).then((_) {}, onError: (Object e) => debugPrint('Closing share: $e')));
  }
}
