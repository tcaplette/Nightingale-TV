import '../library/library_index.dart';
import '../profiles/profile.dart';
import 'channel.dart';
import 'program_block.dart';

/// A profile's own named set of channels, shown as a guide tab.
class ChannelGroup {
  ChannelGroup({required this.id, required this.name, List<String>? channelIds})
      : channelIds = channelIds ?? [];

  /// `group:…`, never one of the built-in tab ids.
  final String id;
  String name;
  List<String> channelIds;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'channels': channelIds};

  factory ChannelGroup.fromJson(Map<String, Object?> j) => ChannelGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        channelIds: (j['channels'] as List?)?.cast<String>().toList() ?? [],
      );
}

/// The guide's built-in tabs.
abstract final class GuideTabs {
  static const all = 'all';
  static const favorites = 'favorites';
  static const live = 'auto:live';
  static const movies = 'auto:movies';
  static const music = 'auto:music';
  static const kids = 'auto:kids';

  /// The tabs worked out from the lineup (never stored).
  static const automatic = [live, movies, music, kids];

  /// For new profiles and profiles from before tabs.
  static const defaultOrder = [all, favorites, live, movies, music, kids];

  static bool isAutomatic(String id) => automatic.contains(id);

  static String? builtinName(String id) => switch (id) {
        all => 'All',
        favorites => 'Favorites',
        live => 'Live TV',
        movies => 'Movies',
        music => 'Music',
        kids => 'Kids',
        _ => null,
      };

  /// What an automatic tab holds, for the Channel groups screen.
  static String? rule(String id) => switch (id) {
        all => 'Every channel.',
        favorites => 'Channels you marked as favorites.',
        live => 'Channels from your Live TV sources.',
        movies => 'Channels that play movies and no episodes or music.',
        music => 'Music video and radio channels.',
        kids => 'Channels where everything that plays, blocks included, is rated TV-Y, TV-Y7, TV-G or G.',
        _ => null,
      };

  /// [order] with every built-in tab and every group in it once: missing
  /// built-ins go where the default order has them (Live TV, newer than the
  /// rest, just before Movies), missing groups after Favorites; ids of
  /// deleted groups are dropped. All always comes first.
  static List<String> normalize(List<String> order, Iterable<ChannelGroup> groups) {
    final groupIds = [for (final g in groups) g.id];
    final known = {...defaultOrder, ...groupIds};
    final result = <String>[all];
    for (final id in order) {
      if (known.contains(id) && !result.contains(id)) result.add(id);
    }
    for (final (i, id) in defaultOrder.indexed) {
      if (result.contains(id)) continue;
      if (id == live && result.contains(movies)) {
        result.insert(result.indexOf(movies), live);
        continue;
      }
      final before = defaultOrder.sublist(0, i).lastWhere(result.contains, orElse: () => all);
      result.insert(result.indexOf(before) + 1, id);
    }
    for (final id in groupIds) {
      if (!result.contains(id)) result.insert(result.indexOf(favorites) + 1, id);
    }
    return result;
  }
}

/// One tab as the guide shows it.
typedef GuideTab = ({String id, String name, List<Channel> channels});

/// Which automatic tabs a channel belongs to, worked out from the lineup.
class AutoGroups {
  AutoGroups(this.library, this.blocks, {required this.kidProfile});

  final LibraryIndex library;
  final List<ProgramBlock> blocks;

  /// Kid profiles have no Kids tab: their whole lineup is kid-safe.
  final bool kidProfile;

  /// Kid profiles have no live channels, and no Live TV tab.
  bool isLive(Channel c) => !kidProfile && c.isLive;

  bool isMovies(Channel c) =>
      !c.blockOnly && !c.isLive && c.source.includeMovies && !c.source.includeEpisodes && !c.isMusic;

  bool isMusic(Channel c) => !c.blockOnly && !c.isLive && c.isMusic;

  /// Every item [c] plays, in its loop and its blocks, is rated TV-G/G or
  /// younger. Unrated items (or none at all) keep it out; live channels
  /// can't be checked ahead of time, so they're never in it.
  bool isKids(Channel c) {
    if (kidProfile || c.isLive) return false;
    final ids = [
      if (!c.blockOnly) ...c.playlist,
      for (final b in blocks)
        if (b.channelId == c.id && b.enabled) ...b.playlist,
    ];
    var any = false;
    for (final id in ids) {
      final item = library[id];
      if (item == null || item.kind == MediaKind.commercial) continue;
      final rating = item.kind == MediaKind.episode ? library.seriesByKey[item.seriesKey]?.officialRating : item.officialRating;
      final rank = ratingRank(rating);
      if (rank == null || rank > 2) return false;
      any = true;
    }
    return any;
  }

  bool contains(String tabId, Channel c) => switch (tabId) {
        GuideTabs.all => true,
        GuideTabs.favorites => c.favorite,
        GuideTabs.live => isLive(c),
        GuideTabs.movies => isMovies(c),
        GuideTabs.music => isMusic(c),
        GuideTabs.kids => isKids(c),
        _ => false,
      };
}

/// The guide's tabs for a profile: in [order], without [hidden] ones or
/// ones with no channels among [visible] (the profile's visible channels,
/// in number order). Groups only ever list visible channels.
List<GuideTab> resolveGuideTabs({
  required List<Channel> visible,
  required List<ChannelGroup> groups,
  required List<String> order,
  required Set<String> hidden,
  required AutoGroups auto,
}) {
  final groupsById = {for (final g in groups) g.id: g};
  final tabs = <GuideTab>[];
  for (final id in GuideTabs.normalize(order, groups)) {
    if (id != GuideTabs.all && hidden.contains(id)) continue;
    final group = groupsById[id];
    final name = group?.name ?? GuideTabs.builtinName(id);
    if (name == null) continue;
    final members = group != null
        ? [for (final c in visible) if (group.channelIds.contains(c.id)) c]
        : [for (final c in visible) if (auto.contains(id, c)) c];
    if (members.isEmpty && id != GuideTabs.all) continue;
    tabs.add((id: id, name: name, channels: members));
  }
  return tabs;
}

/// An M3U entry's `group-title` (lineup-export): the first of the
/// profile's groups, in tab order, holding [c]; else its automatic group
/// (Movies, Music, Kids); else [fallback].
String m3uGroupFor(Channel c,
    {required List<ChannelGroup> groups, required List<String> order, required AutoGroups auto, required String fallback}) {
  final groupsById = {for (final g in groups) g.id: g};
  for (final id in GuideTabs.normalize(order, groups)) {
    if (groupsById[id] case final g? when g.channelIds.contains(c.id)) return g.name;
  }
  for (final id in GuideTabs.automatic) {
    if (auto.contains(id, c)) return GuideTabs.builtinName(id)!;
  }
  return fallback;
}
