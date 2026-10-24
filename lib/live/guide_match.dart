import 'live_data.dart';

/// A name with case, spaces and punctuation removed: "WXYZ-7" and "wxyz 7"
/// are the same.
String normalizeChannelName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[\s\p{P}\p{S}]+', unicode: true), '');

/// Finds an M3U channel's guide channel (live-tv-sources "Guide matching"):
/// the one whose id is its `tvg-id`, else one whose display name equals its
/// `tvg-name` or name once normalized.
class GuideMatcher {
  GuideMatcher([Iterable<GuideChannel> channels = const []]) {
    channels.forEach(add);
  }

  final _ids = <String>{};
  final _byName = <String, String>{};

  void add(GuideChannel c) {
    _ids.add(c.id);
    for (final n in c.names) {
      // The first guide channel with a name keeps it.
      _byName.putIfAbsent(normalizeChannelName(n), () => c.id);
    }
  }

  bool get isEmpty => _ids.isEmpty;

  /// The guide channel id for a channel with [tvgId], [tvgName] and
  /// [name]; null when nothing matches.
  String? match({String? tvgId, String? tvgName, required String name}) {
    if (tvgId != null && _ids.contains(tvgId)) return tvgId;
    for (final n in [?tvgName, name]) {
      final id = _byName[normalizeChannelName(n)];
      if (id != null) return id;
    }
    return null;
  }

  String? matchChannel(LiveChannelInfo c) => match(tvgId: c.guideId, tvgName: c.tvgName, name: c.name);
}
