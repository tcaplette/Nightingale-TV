import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../channels/channel.dart';
import '../l10n/tr.dart';
import 'channel_recipe.dart';
import 'recipe_matcher.dart';
import 'share_client.dart';

/// A share in Shared with you, with its recipe matched against the
/// profile's library.
class SharePreview {
  const SharePreview({required this.share, this.recipe, this.recipeJson, this.version = 0, this.match, this.tooNew = false});

  final IncomingShare share;
  final ChannelRecipe? recipe;
  final Map<String, Object?>? recipeJson;
  final int version;
  final RecipeMatch? match;

  /// From a newer app: "Update Nightingale TV to add this channel."
  final bool tooNew;

  /// Add can be offered: something matched.
  bool get canAdd => !tooNew && (match?.matched ?? 0) > 0;
}

/// A channel this profile shares, with the friends who have it.
class OutgoingChannel {
  const OutgoingChannel({required this.share, this.channel, required this.receivers});

  final OutgoingShare share;
  final Channel? channel;
  final List<ShareProfile> receivers;
}

/// What sending channels gave.
class SendResult {
  const SendResult({this.invite});

  /// The `channels` invite, for Get a link.
  final FriendInvite? invite;
}

/// Channel sharing for the profile in front (channel-sharing D4–D7):
/// sending, Shared with you, Keep updated in both directions, and stopping.
///
/// [attach] gives it the profile's started share client and its state; every
/// attach is a connect: copies fetch newer versions, the sender's changed
/// channels are published, waiting shares are counted for the menu badge
/// and the new-share notice.
class ChannelShares extends ChangeNotifier {
  ChannelShares();

  /// How long after a change the sender's channels are republished (D6).
  @visibleForTesting
  static Duration publishDelay = const Duration(seconds: 60);

  static const _stateFile = 'share_state.json';

  ShareClient? _client;
  AppState? _app;
  bool _disposed = false;

  /// Every share sent to this profile's account, as last fetched.
  List<IncomingShare> _incoming = const [];

  /// The share profile's station name, sent in recipes.
  String _station = '';

  /// Shares the new-share notice has been shown for, and shared channels
  /// whose Stop sharing is still to be sent (the channel was removed while
  /// offline). Kept in the profile's folder, outside backups.
  Set<String> _noticed = {};
  Set<String> _pendingStops = {};

  /// The profile's library was scanned once for provider ids since it was
  /// linked (D2): a profile linked before channel sharing has none yet.
  bool _idsScanned = false;

  /// The shared ids of this profile's shared channels at the last look,
  /// to notice one being removed.
  Set<String> _outIds = {};

  Timer? _publishTimer;
  Future<void>? _connecting;

  /// "Tyler shared 2 channels with you. …", once per new set of shares; the
  /// TV shows it over the picture without taking focus.
  final notice = ValueNotifier<String?>(null);

  ShareClient? get client => _client;

  /// Shares waiting in Shared with you: new, active, and not already a
  /// channel here.
  List<IncomingShare> get waiting => [
        for (final s in _incoming)
          if (s.waiting && _app?.copyOf(s.sharedChannelId) == null) s,
      ];

  /// Gives the profile in front's started, linked [client] and its [app];
  /// null for none (kid profile, unlinked, hidden or asleep).
  Future<void> attach(ShareClient? client, AppState? app) async {
    if (_disposed) return;
    if (!identical(app, _app)) {
      _app?.removeListener(_appChanged);
      _publishTimer?.cancel();
      _app = app;
      _app?.addListener(_appChanged);
      _incoming = const [];
      if (app != null) await _loadState(app);
      _outIds = _currentOutIds();
    }
    _client = client;
    _needsConnect = client != null && app != null;
    notifyListeners();
    if (_ready) await connect();
  }

  /// A connect is due once the profile's lineup is ready.
  bool _needsConnect = false;

  /// Work still under way when the profile goes says nothing.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _publishTimer?.cancel();
    _app?.removeListener(_appChanged);
    notice.dispose();
    super.dispose();
  }

  Future<void> _loadState(AppState app) async {
    try {
      final j = await app.storage.readJson(_stateFile);
      if (j is Map) {
        _noticed = {for (final s in j['noticed'] as List? ?? const []) if (s is String) s};
        _pendingStops = {for (final s in j['stops'] as List? ?? const []) if (s is String) s};
        _idsScanned = j['idsScanned'] == true;
      } else {
        _noticed = {};
        _pendingStops = {};
        _idsScanned = false;
      }
    } on Object {
      _noticed = {};
      _pendingStops = {};
      _idsScanned = false;
    }
  }

  Future<void> _saveState() async =>
      _app?.storage.writeJson(_stateFile,
          {'noticed': _noticed.toList(), 'stops': _pendingStops.toList(), if (_idsScanned) 'idsScanned': true});

  bool get _ready => _client != null && _app != null && _app!.phase == AppPhase.ready && _client!.started;

  /// Connect (D6, D7): send pending stops, publish changed channels, fetch
  /// Shared with you, update copies and end the ones whose shares ended.
  Future<void> connect() => _connecting ??= _connect().whenComplete(() => _connecting = null);

  Future<void> _connect() async {
    final client = _client, app = _app;
    if (_disposed || client == null || app == null || !client.started) return;
    if (app.phase != AppPhase.ready) return;
    _needsConnect = false;
    _scanForIdsOnce(app);
    try {
      _station = (await client.profile())?.station ?? '';
      for (final id in _pendingStops.toList()) {
        await client.stopSharing(id);
        _pendingStops.remove(id);
        await _saveState();
      }
      await _syncOutgoing(client, app);
      await _publish();
      await refreshIncoming();
    } on ShareUnavailable catch (e) {
      debugPrint('Channel sharing unavailable: $e');
    } on ShareSignedOut {
      // The Sharing screen asks to set up again.
    } on StateError catch (e) {
      // Stopped mid-way (hidden or asleep): the next connect goes on.
      debugPrint('Channel sharing stopped: $e');
    } on Object catch (e) {
      // Whatever the backend answered, watching TV goes on; the next
      // connect tries again.
      debugPrint('Channel sharing: $e');
    }
  }

  /// A profile linked before channel sharing scanned without provider ids:
  /// one refresh asks for them, as linking does (D2). Once, even when its
  /// servers have none to give.
  void _scanForIdsOnce(AppState app) {
    if (_idsScanned) return;
    _idsScanned = true;
    unawaited(_saveState());
    final library = app.library;
    final withIds = [...library.episodes, ...library.movies].any((e) => e.providerIds.isNotEmpty);
    if (!withIds && (library.episodes.isNotEmpty || library.movies.isNotEmpty)) {
      unawaited(app.refreshLibrary(background: true));
    }
  }

  /// Channels this profile shares that were stopped elsewhere lose their
  /// link here too.
  Future<void> _syncOutgoing(ShareClient client, AppState app) async {
    final out = app.sharedOut;
    if (out.isEmpty) return;
    final mine = {for (final s in await client.myShares()) s.id: s};
    for (final ch in out) {
      final s = mine[ch.share!.id];
      if (s == null || s.stopped) await app.setShareLink(ch, null);
    }
    _outIds = _currentOutIds();
  }

  /// Fetches Shared with you, applies newer versions to copies with Keep
  /// updated on, and marks ended copies "No longer updated".
  Future<void> refreshIncoming() async {
    final client = _client, app = _app;
    if (client == null || app == null) return;
    final rows = await client.channelShares();
    _incoming = rows;
    final bySharedId = {for (final r in rows) r.sharedChannelId: r};
    for (final copy in app.sharedCopies) {
      final link = copy.share!;
      final row = bySharedId[link.id];
      if (row == null || row.ended) {
        if (!link.ended) await app.endShare(copy);
        continue;
      }
      final from = row.from;
      if (from != null && (from.name != link.ownerName || from.handle != link.ownerHandle)) {
        await app.setShareLink(copy, link.copyWith(ownerName: from.name, ownerHandle: from.handle));
      }
      if (!copy.share!.followsRecipe) continue;
      final newer = copy.share!.keepUpdated && row.version > copy.share!.version;
      if (!newer && await app.recipeCache.has(link.id)) continue;
      // A newer version, or the cache is gone (a restore): fetch it.
      final fetched = await client.sharedRecipe(link.id);
      if (fetched == null) continue;
      final ChannelRecipe recipe;
      try {
        recipe = ChannelRecipe.fromJson(fetched.recipe);
      } on RecipeTooNew {
        continue;
      } on FormatException {
        continue;
      }
      if (newer && fetched.version > copy.share!.version) {
        await app.applySharedRecipe(copy, recipe, recipeJson: fetched.recipe, version: fetched.version);
      } else {
        await app.recipeCache.put(link.id, fetched.recipe);
      }
    }
    // A share added on this profile before (another device, a restore).
    for (final r in rows) {
      if (r.state == 'new' && !r.ended && app.copyOf(r.sharedChannelId) != null) {
        await client.setShareState(r.id, 'added');
      }
    }
    _noticeNew();
    notifyListeners();
  }

  void _noticeNew() {
    if (_disposed) return;
    final fresh = [for (final s in waiting) if (!_noticed.contains(s.id)) s];
    if (fresh.isEmpty) return;
    final senders = {for (final s in fresh) s.from?.name ?? ''}.where((n) => n.isNotEmpty).toList();
    notice.value = senders.length == 1
        ? tr.sharingNewShares(senders.single, fresh.length)
        : tr.sharingNewSharesMany(fresh.length);
    _noticed.addAll(fresh.map((s) => s.id));
    unawaited(_saveState());
  }

  // ---- Receiving ---------------------------------------------------------------

  /// [share]'s recipe matched against the profile's library.
  Future<SharePreview> preview(IncomingShare share) async {
    final client = _client!, app = _app!;
    final fetched = await client.sharedRecipe(share.sharedChannelId);
    if (fetched == null) return SharePreview(share: share);
    try {
      final recipe = ChannelRecipe.fromJson(fetched.recipe);
      return SharePreview(
        share: share,
        recipe: recipe,
        recipeJson: fetched.recipe,
        version: fetched.version,
        match: await app.matchRecipe(recipe),
      );
    } on RecipeTooNew {
      return SharePreview(share: share, tooNew: true);
    } on FormatException {
      return SharePreview(share: share);
    }
  }

  /// Add: [preview]'s channel joins the lineup, and leaves Shared with you.
  Future<Channel> add(SharePreview preview) async {
    final client = _client!, app = _app!;
    final s = preview.share;
    final ch = await app.addSharedCopy(
      preview.recipe!,
      preview.recipeJson!,
      ShareLink(
        id: s.sharedChannelId,
        role: ShareRole.incoming,
        owner: s.from?.userId,
        ownerName: s.from?.name,
        ownerHandle: s.from?.handle,
        station: preview.recipe!.station.isNotEmpty ? preview.recipe!.station : s.from?.station,
        version: preview.version,
      ),
      match: preview.match,
    );
    await client.setShareState(s.id, 'added');
    _incoming = [
      for (final r in _incoming) r.id == s.id ? IncomingShare.fromJson(_rowOf(r, state: 'added')) : r,
    ];
    notifyListeners();
    return ch;
  }

  /// Decline: the share leaves Shared with you.
  Future<void> decline(IncomingShare share) async {
    await _client!.setShareState(share.id, 'declined');
    _incoming = [
      for (final r in _incoming) r.id == share.id ? IncomingShare.fromJson(_rowOf(r, state: 'declined')) : r,
    ];
    notifyListeners();
  }

  static Map<String, dynamic> _rowOf(IncomingShare r, {required String state}) => {
        'id': r.id,
        'shared_channel_id': r.sharedChannelId,
        'state': state,
        'ended_at': r.ended ? DateTime.now().toIso8601String() : null,
        'name': r.name,
        'version': r.version,
        'created_at': r.createdAt.toIso8601String(),
        if (r.from case final f?)
          'from': {
            'user_id': f.userId,
            'name': f.name,
            'handle': f.handle,
            'avatar': f.avatar,
            'avatar_color': f.avatarColor,
            'station': f.station,
          },
      };

  // ---- Sending -----------------------------------------------------------------

  static String newShareId() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Shares [channels] with the friends [to], or with [link] makes a
  /// `channels` invite. Throws [RecipeTooBig] for a channel over the limit.
  Future<SendResult> send(List<Channel> channels, {List<ShareProfile> to = const [], bool link = false}) async {
    final client = _client!, app = _app!;
    final recipes = <(Channel, String, ChannelRecipe)>[
      for (final ch in channels)
        (ch, ch.share?.role == ShareRole.out ? ch.share!.id : newShareId(), app.recipeOf(ch, station: _station)),
    ];
    final r = await client.shareChannels(
      [for (final (ch, id, recipe) in recipes) (id: id, name: recipe.name.isEmpty ? ch.displayName : recipe.name, recipe: recipe.toJson())],
      to: [for (final f in to) f.userId],
      link: link,
    );
    for (final (ch, id, recipe) in recipes) {
      await app.setShareLink(
          ch, ShareLink(id: id, role: ShareRole.out, version: r.versions[id] ?? 1, hash: recipe.hash));
    }
    _outIds = _currentOutIds();
    return SendResult(invite: r.invite);
  }

  /// Channels you share, each with the friends who have it.
  Future<List<OutgoingChannel>> outgoing() async {
    final client = _client!, app = _app!;
    final shares = await client.myShares();
    final friends = {for (final f in (await client.friends()).friends) f.userId: f};
    return [
      for (final s in shares)
        if (!s.stopped)
          OutgoingChannel(
            share: s,
            channel: app.sharedOut.where((c) => c.share!.id == s.id).firstOrNull,
            receivers: [for (final id in s.receivers) ?friends[id]],
          ),
    ];
  }

  /// Stop sharing: ends the share for every friend. Receivers keep copies.
  Future<void> stop(String sharedId) async {
    final client = _client!, app = _app!;
    await client.stopSharing(sharedId);
    for (final ch in app.sharedOut) {
      if (ch.share!.id == sharedId) await app.setShareLink(ch, null);
    }
    _outIds = _currentOutIds();
    notifyListeners();
  }

  // ---- Keep updated (sender) -----------------------------------------------------

  Set<String> _currentOutIds() => {for (final c in _app?.sharedOut ?? const <Channel>[]) c.share!.id};

  void _appChanged() {
    final app = _app;
    if (app == null || _disposed) return;
    // A shared channel removed (or retired by a scan): its shares end.
    final now = _currentOutIds();
    final gone = _outIds.difference(now);
    _outIds = now;
    if (gone.isNotEmpty) {
      _pendingStops.addAll(gone);
      unawaited(_saveState());
      if (_ready) unawaited(connect());
    }
    // Attached before the lineup was ready: connect now.
    if (_needsConnect && _ready) unawaited(connect());
    if (now.isEmpty) return;
    // Republished within a minute of a change (D6).
    _publishTimer ??= Timer(publishDelay, () {
      _publishTimer = null;
      if (_ready) unawaited(_publish().catchError((Object e) => debugPrint('Publishing shared channels: $e')));
    });
  }

  /// Republishes every shared channel whose recipe changed, as version + 1.
  Future<void> _publish() async {
    final client = _client, app = _app;
    if (client == null || app == null) return;
    final changed = <(Channel, ChannelRecipe)>[];
    for (final ch in app.sharedOut) {
      final ChannelRecipe recipe;
      try {
        recipe = app.recipeOf(ch, station: _station);
      } on RecipeTooBig {
        continue;
      }
      if (recipe.hash != ch.share!.hash) changed.add((ch, recipe));
    }
    if (changed.isEmpty) return;
    final r = await client.shareChannels([
      for (final (ch, recipe) in changed)
        (id: ch.share!.id, name: recipe.name.isEmpty ? ch.displayName : recipe.name, recipe: recipe.toJson()),
    ]);
    for (final (ch, recipe) in changed) {
      final link = ch.share;
      if (link == null) continue;
      await app.setShareLink(ch, link.copyWith(version: r.versions[link.id] ?? link.version, hash: () => recipe.hash));
    }
  }
}
