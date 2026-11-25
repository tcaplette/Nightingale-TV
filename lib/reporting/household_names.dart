import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../platform/platform_info.dart';
import '../server/media_server.dart';
import '../profiles/household.dart';
import 'error_reports.dart';

/// Keeps the names error reports leave out current (error-reporting D4):
/// profile names, each loaded profile's server names, server hosts and
/// usernames, its YouTube channels' and videos' titles, and this device's
/// name.
class HouseholdNames {
  HouseholdNames(this.household) {
    household.addListener(_householdChanged);
    _householdChanged();
  }

  final Household household;
  final _watched = <AppState>{};
  Set<String> _last = const {};

  /// The household's names right now.
  @visibleForTesting
  static Set<String> of(Household h) {
    final names = <String>{PlatformInfo.deviceName};
    for (final p in h.profiles) {
      names.add(p.name);
      final app = h.appFor(p.id);
      if (app == null) continue;
      for (final s in app.servers.all) {
        if (s.userName case final user?) names.add(user);
        // YouTube's own name and address aren't the household's.
        if (s.kind == ServerKind.youtube) continue;
        names.add(s.name);
        if (Uri.tryParse(s.serverUrl ?? '')?.host case final host? when host.isNotEmpty) names.add(host);
      }
      // YouTube: the picked channels' and their videos' titles never leave
      // the device (youtube-subscriptions D13).
      for (final c in app.youTubeChannels) {
        names.add(c.name);
      }
      for (final v in app.library.youtubeVideos) {
        names.add(v.title);
        if (v.seriesName case final channel?) names.add(channel);
      }
    }
    return names;
  }

  void _householdChanged() {
    // Sign-ins change on the profile's state, not the household. States
    // no longer loaded have been disposed with their listeners.
    final loaded = {for (final p in household.profiles) ?household.appFor(p.id)};
    _watched.retainWhere(loaded.contains);
    for (final p in household.profiles) {
      final app = household.appFor(p.id);
      if (app != null && _watched.add(app)) app.addListener(_update);
    }
    _update();
  }

  void _update() {
    final names = of(household);
    if (setEquals(names, _last)) return;
    _last = names;
    ErrorReports.setNames(names);
  }

  void dispose() {
    household.removeListener(_householdChanged);
    for (final app in _watched) {
      app.removeListener(_update);
    }
  }
}
