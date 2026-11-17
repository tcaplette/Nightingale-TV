import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../data/app_storage.dart';
import '../platform/install_info.dart';
import '../profiles/household.dart';
import '../profiles/profile.dart';
import 'channel_shares.dart';
import 'invite_code.dart';
import 'presence.dart';
import 'share_client.dart';
import 'share_session_store.dart';
import 'sharing.dart';
import 'watch_party.dart';

/// Sharing for the household (share-accounts): each profile's share
/// sign-in, and the client for the profile in front.
///
/// Only that profile's client runs, and only while the app is shown and not
/// asleep (requirement "Sharing traffic only when in use"). Kid profiles
/// are never linked: a profile that becomes one is signed out.
class ShareService extends ChangeNotifier {
  ShareService(this._household, AppStorage root,
      {this._url = Sharing.url, this._key = Sharing.key, this._host = Sharing.host, this._httpClient, bool watchLifecycle = true})
      : store = ShareSessionStore(root) {
    if (watchLifecycle) {
      _lifecycle = AppLifecycleListener(onHide: () => hidden = true, onShow: () => hidden = false);
    }
  }

  /// Sharing for [household] when this build has it; null otherwise, so
  /// nothing about sharing exists.
  static ShareService? forHousehold(Household household) =>
      Sharing.available && !household.serverMode ? ShareService(household, household.root) : null;

  final Household _household;
  final ShareSessionStore store;
  final String _url;
  final String _key;
  final String _host;

  /// The invite-link host: `https://<host>/ntv/i/<CODE>`.
  String get host => _host;
  final http.Client? _httpClient;
  AppLifecycleListener? _lifecycle;

  final _clients = <String, ShareClient>{};
  ShareClient? _active;
  bool _hidden = false;
  bool _asleep = false;
  bool _loaded = false;

  /// Channel sharing for the profile in front (channel-sharing).
  final channels = ChannelShares();

  /// Friend presence for the profile in front (friend-presence).
  final presence = Presence();

  /// Watch parties for the profile in front (watch-together).
  final party = WatchParty();

  /// Tests stand in for the party's backend (Realtime topics the fake HTTP
  /// backend can't answer).
  @visibleForTesting
  PartyBackend? debugPartyBackend;

  /// An invite code from a link, kept until an adult profile is in front
  /// and (if it isn't linked yet) through setup.
  final pendingCode = ValueNotifier<String?>(null);

  Future<void> load() async {
    await store.load();
    _loaded = true;
    _household.addListener(_householdChanged);
    InstallSwitching.inviteLink.addListener(_linkArrived);
    _linkArrived();
    await _householdChanged();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    _household.removeListener(_householdChanged);
    InstallSwitching.inviteLink.removeListener(_linkArrived);
    for (final c in _clients.values) {
      unawaited(c.dispose());
    }
    _clients.clear();
    channels.dispose();
    presence.dispose();
    party.dispose();
    pendingCode.dispose();
    super.dispose();
  }

  bool isLinked(Profile p) => store.isLinked(p.id);

  /// The client for [p]: made on first use (setup, or a linked profile in
  /// front). Null for kid profiles.
  ShareClient? clientFor(Profile p) {
    if (p.isKid) return null;
    return _clients[p.id] ??= ShareClient(profileId: p.id, store: store, url: _url, key: _key, httpClient: _httpClient)
      // One refresh on linking, so the first share has provider ids
      // (channel-sharing D2).
      ..onLinked = () {
        unawaited(_household.appFor(p.id)?.refreshLibrary(background: true));
        unawaited(attachChannels());
      };
  }

  /// The client of the profile in front, if it's an adult.
  ShareClient? get active => _active;

  set hidden(bool value) {
    if (_hidden == value) return;
    _hidden = value;
    unawaited(_apply());
  }

  /// The sleep timer has the app asleep.
  set asleep(bool value) {
    if (_asleep == value) return;
    _asleep = value;
    unawaited(_apply());
  }

  bool get _running => !_hidden && !_asleep;

  Future<void> _householdChanged() async {
    if (!_loaded || _disposed) return;
    // Before the profiles are read there's nothing to compare with.
    if (!_household.started) return _apply();
    final profiles = {for (final p in _household.profiles) p.id: p};
    // Kid profiles and deleted profiles keep no sign-in.
    for (final id in store.profileIds.toList()) {
      final p = profiles[id];
      if (p == null || p.isKid) {
        final client = _clients.remove(id);
        if (client != null) {
          await client.signOut();
          await client.dispose();
        } else {
          await store.remove(id);
        }
      }
    }
    for (final id in _clients.keys.toList()) {
      if (profiles[id]?.isKid ?? true) await _clients.remove(id)!.dispose();
    }
    await _apply();
  }

  /// Starts the profile in front's client and stops every other.
  /// Counts [_apply] calls: one that waited while a newer one ran gives up.
  int _applying = 0;

  Future<void> _apply() async {
    if (_disposed) return;
    final call = ++_applying;
    final current = _household.current;
    final wanted = current == null || current.isKid || !_running ? null : current;
    final next = wanted == null
        ? null
        : (store.isLinked(wanted.id) || _clients.containsKey(wanted.id) ? clientFor(wanted) : null);
    final changed = _active != next;
    // What's published comes down before its client stops (friend-presence:
    // background, sleep, another profile).
    if (changed && _active != null) {
      // Background and sleep leave the party (watch-together).
      await party.leaveBeforeStop();
      await presence.clearBeforeStop();
      // A newer change ran meanwhile and decided for itself.
      if (_disposed || call != _applying) return;
    }
    for (final c in _clients.values) {
      if (c != next) c.stop();
    }
    _active = next;
    if (changed) notifyListeners();
    // A sign-in being refreshed may take a while offline.
    if (next != null) await next.start();
    await attachChannels();
  }

  /// Channel sharing follows the started, linked client in front and its
  /// profile's state; each attach is a connect.
  Future<void> attachChannels() async {
    if (_disposed) return;
    final c = _active;
    final linked = c != null && c.started && store.isLinked(c.profileId);
    final app = _household.current?.id == c?.profileId ? _household.app : null;
    await channels.attach(linked ? c : null, linked ? app : null);
    await presence.attach(linked ? c : null, linked ? app : null);
    await party.attach(linked ? (debugPartyBackend ?? c) : null, linked ? app : null);
  }

  /// Unlinks [client]'s profile on this device; what it published comes
  /// down first.
  Future<void> signOut(ShareClient client) async {
    if (identical(client, _active)) {
      await party.leaveBeforeStop();
      await presence.clearBeforeStop();
    }
    await client.signOut();
    await attachChannels();
  }

  /// The client for setting up [p] (not linked yet): made and started now,
  /// since the user is on the Sharing screen.
  Future<ShareClient?> setUp(Profile p) async {
    final c = clientFor(p);
    if (c == null) return null;
    await _apply();
    if (_active != c && _running && _household.current?.id == p.id) {
      _active = c;
      await c.start();
      notifyListeners();
    }
    return c;
  }

  void _linkArrived() {
    final link = InstallSwitching.inviteLink.value;
    if (link == null) return;
    InstallSwitching.inviteLink.value = null;
    if (InviteCode.fromLink(link, host: _host) case final code?) pendingCode.value = code;
  }

}
