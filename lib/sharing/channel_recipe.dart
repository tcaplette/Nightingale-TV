import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../channels/channel.dart';
import '../channels/program_block.dart';
import '../channels/retro.dart';
import '../commercials/break_plan.dart';
import '../library/library_index.dart';

/// A recipe from a newer app ("Update Nightingale TV to add this channel").
class RecipeTooNew implements Exception {
  const RecipeTooNew(this.version);

  final int version;
}

/// A channel with more than [ChannelRecipe.maxItems] programs can't be
/// shared.
class RecipeTooBig implements Exception {
  const RecipeTooBig(this.items);

  final int items;
}

/// A show a recipe's episodes belong to: its provider ids, name and year.
class RecipeShow {
  const RecipeShow({required this.ids, required this.name, this.year});

  final List<String> ids;
  final String name;
  final int? year;

  Map<String, Object?> toJson() => {'ids': ids, 'name': name, if (year != null) 'year': year};

  static RecipeShow fromJson(Map<String, Object?> j) => RecipeShow(
        ids: _strings(j['ids']),
        name: j['name'] as String? ?? '',
        year: _int(j['year']),
      );
}

/// One program of a recipe: an episode of [show] (an index into
/// [ChannelRecipe.shows]) or a movie.
class RecipeItem {
  const RecipeItem.episode({required int this.show, this.season, this.episode, required this.title, required this.runtime})
      : ids = const [],
        year = null;

  const RecipeItem.movie({required this.ids, required this.title, this.year, required this.runtime})
      : show = null,
        season = null,
        episode = null;

  /// The show's index; null for a movie.
  final int? show;
  final int? season;
  final int? episode;

  /// A movie's provider ids.
  final List<String> ids;
  final String title;

  /// A movie's year.
  final int? year;

  /// The sender's runtime. The receiver's copy plays its own.
  final Duration runtime;

  bool get isMovie => show == null;

  Map<String, Object?> toJson() => isMovie
      ? {
          'm': {'ids': ids, 't': title, if (year != null) 'y': year},
          'rt': runtime.inSeconds,
        }
      : {
          's': show,
          if (season != null) 'se': season,
          if (episode != null) 'ep': episode,
          't': title,
          'rt': runtime.inSeconds,
        };

  /// Null for an entry this version can't read (left out, as unknown
  /// fields are).
  static RecipeItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final runtime = Duration(seconds: _int(json['rt']) ?? 0);
    if (json['m'] case final Map m) {
      return RecipeItem.movie(ids: _strings(m['ids']), title: m['t'] as String? ?? '', year: _int(m['y']), runtime: runtime);
    }
    final show = _int(json['s']);
    if (show == null) return null;
    return RecipeItem.episode(
        show: show, season: _int(json['se']), episode: _int(json['ep']), title: json['t'] as String? ?? '', runtime: runtime);
  }
}

/// A programming block as a recipe holds it.
class RecipeBlock {
  const RecipeBlock({
    required this.title,
    required this.days,
    required this.startMinute,
    required this.endMinute,
    required this.order,
    required this.anchor,
    required this.items,
    this.seasonStart,
    this.seasonEnd,
    this.enabled = true,
    this.lineup = const [],
  });

  final String title;
  final Set<int> days;
  final int startMinute;
  final int endMinute;
  final MonthDay? seasonStart;
  final MonthDay? seasonEnd;
  final PlaybackOrder order;

  /// The local day its airings are counted from.
  final DateTime anchor;
  final bool enabled;

  /// A lineup block's shows (indexes into [ChannelRecipe.shows]) and counts.
  final List<({int show, int count})> lineup;
  final List<RecipeItem> items;

  Map<String, Object?> toJson() => {
        'name': title,
        'days': days.toList()..sort(),
        'start': startMinute,
        'end': endMinute,
        if (seasonStart != null) 'seasonStart': seasonStart!.toJson(),
        if (seasonEnd != null) 'seasonEnd': seasonEnd!.toJson(),
        'order': order.name,
        'anchor': _day(anchor),
        if (!enabled) 'enabled': false,
        if (lineup.isNotEmpty) 'lineup': [for (final l in lineup) {'s': l.show, 'n': l.count}],
        'items': [for (final i in items) i.toJson()],
      };

  static RecipeBlock? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = _int(json['start']), end = _int(json['end']);
    if (start == null || end == null) return null;
    MonthDay? md(Object? s) {
      try {
        return s is String ? MonthDay.parse(s) : null;
      } on FormatException {
        return null;
      }
    }

    return RecipeBlock(
      title: json['name'] as String? ?? '',
      days: {for (final d in json['days'] as List? ?? const []) if (d is int && d >= 1 && d <= 7) d},
      startMinute: start % (24 * 60),
      endMinute: end % (24 * 60),
      seasonStart: md(json['seasonStart']),
      seasonEnd: md(json['seasonEnd']),
      order: PlaybackOrder.parse(json['order']),
      anchor: _parseDay(json['anchor']),
      enabled: json['enabled'] as bool? ?? true,
      lineup: [
        for (final l in json['lineup'] as List? ?? const [])
          if (l is Map && _int(l['s']) != null) (show: _int(l['s'])!, count: (_int(l['n']) ?? 1).clamp(1, LineupSlot.maxCount)),
      ],
      items: [for (final i in json['items'] as List? ?? const []) ?RecipeItem.fromJson(i)],
    );
  }
}

/// A shared channel as it travels (channel-sharing D1, version 1): what it
/// plays, described by provider ids, titles and numbers, never by anything
/// of the sender's server.
///
/// Holds no server address or name, item id, file or stream path, token,
/// image, pool reference or play count: [fromChannel] builds it from the
/// library index field by field and never copies a channel's own JSON.
class ChannelRecipe {
  const ChannelRecipe({
    this.v = version,
    required this.name,
    this.icon,
    this.station = '',
    required this.order,
    required this.anchor,
    this.blockOnly = false,
    this.breaks,
    this.slot,
    this.retro = ChannelRetro.main,
    this.logoMode,
    required this.shows,
    required this.items,
    this.blocks = const [],
  });

  static const version = 1;

  /// Programs in all, the channel's and its blocks' together.
  static const maxItems = 20000;

  final int v;
  final String name;

  /// A built-in icon or text badge; null for one that was an image.
  final ChannelIcon? icon;
  final String station;
  final PlaybackOrder order;
  final DateTime anchor;
  final bool blockOnly;

  /// The channel's own break plan without its pools; null follows the
  /// receiver's main setting.
  final BreakPlan? breaks;

  /// Slot length and tail mode, without a pool or offline image.
  final SlotRule? slot;
  final ChannelRetro retro;
  final LogoMode? logoMode;
  final List<RecipeShow> shows;
  final List<RecipeItem> items;
  final List<RecipeBlock> blocks;

  /// How many programs it holds: what "Matched n of N" counts.
  int get total => items.length + blocks.fold<int>(0, (n, b) => n + b.items.length);

  /// [channel] (with its [blocks]) as a recipe, every program described
  /// from [library]. Programs the library no longer has are left out.
  /// Throws [RecipeTooBig] over [maxItems].
  static ChannelRecipe fromChannel(Channel channel, List<ProgramBlock> blocks, LibraryIndex library,
      {String station = ''}) {
    final shows = <RecipeShow>[];
    final showIndex = <String, int>{};
    int showOf(String key) => showIndex.putIfAbsent(key, () {
          final s = library.seriesByKey[key];
          shows.add(RecipeShow(ids: [...?s?.providerIds], name: s?.name ?? key.split('|').first, year: s?.year));
          return shows.length - 1;
        });
    RecipeItem? item(String id) {
      final e = library[id];
      if (e == null) return null;
      return switch (e.kind) {
        MediaKind.episode when e.seriesKey != null => RecipeItem.episode(
            show: showOf(e.seriesKey!), season: e.season, episode: e.episode, title: e.title, runtime: e.runtime),
        MediaKind.movie => RecipeItem.movie(ids: [...e.providerIds], title: e.title, year: e.year, runtime: e.runtime),
        _ => null,
      };
    }

    final items = channel.blockOnly ? const <RecipeItem>[] : [for (final id in channel.playlist) ?item(id)];
    final recipeBlocks = [
      for (final b in blocks)
        if (b.channelId == channel.id)
          RecipeBlock(
            title: b.title,
            days: {...b.days},
            startMinute: b.startMinute,
            endMinute: b.endMinute,
            seasonStart: b.seasonStart,
            seasonEnd: b.seasonEnd,
            order: b.order,
            anchor: b.anchor,
            enabled: b.enabled,
            lineup: [
              for (final l in b.lineup)
                if (library.seriesByKey[l.seriesKey] != null) (show: showOf(l.seriesKey), count: l.count),
            ],
            items: [for (final id in b.playlist) ?item(id)],
          ),
    ];
    final total = items.length + recipeBlocks.fold<int>(0, (n, b) => n + b.items.length);
    if (total > maxItems) throw RecipeTooBig(total);
    final plan = channel.commercialPlan;
    final rule = channel.slotRule;
    final retro = channel.retro;
    return ChannelRecipe(
      name: channel.displayName,
      icon: switch (channel.icon.kind) {
        ChannelIconKind.builtin || ChannelIconKind.badge => channel.icon,
        _ => null,
      },
      station: station,
      order: channel.order,
      anchor: channel.anchor,
      blockOnly: channel.blockOnly,
      breaks: plan == null ? null : BreakPlan(mode: plan.mode, roles: _withoutPools(plan.roles)),
      slot: rule == null ? null : SlotRule(length: rule.length, tail: rule.tail),
      // A surround picture is a file of the sender's: the receiver's main
      // setting instead.
      retro: retro.surround == Surround.image
          ? retro.copyWith(surround: () => null, surroundImage: () => null)
          : retro.copyWith(surroundImage: () => null),
      logoMode: channel.logoMode,
      shows: shows,
      items: items,
      blocks: recipeBlocks,
    );
  }

  static CustomRoles _withoutPools(CustomRoles r) {
    var roles = r;
    for (final role in BreakRole.values) {
      roles = roles.withPool(role, null);
    }
    return roles.withBumpers(null, none: r.noBumpers);
  }

  Map<String, Object?> toJson() => {
        'v': v,
        'name': name,
        if (icon case final i?)
          'icon': {
            'kind': i.kind.name,
            'value': i.value,
            'color': i.color,
            if (i.kind == ChannelIconKind.badge) 'shape': i.shape.name,
          },
        if (station.isNotEmpty) 'station': station,
        'order': order.name,
        'anchor': anchor.toUtc().toIso8601String(),
        if (blockOnly) 'blockOnly': true,
        if (breaks case final b?) 'breaks': b.toJson(),
        if (slot case final s?) 'slot': {'lengthMin': s.length.inMinutes, 'tail': s.tail.name},
        if (!retro.followsMain) 'retro': retro.toJson(),
        if (logoMode case final l?) 'logoMode': l.name,
        'shows': [for (final s in shows) s.toJson()],
        'items': [for (final i in items) i.toJson()],
        if (blocks.isNotEmpty) 'blocks': [for (final b in blocks) b.toJson()],
      };

  /// A stable digest of what the recipe says: unchanged channels give the
  /// same one, so nothing is republished (D6).
  String get hash => sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  /// Reads a recipe. Unknown fields are ignored; throws [RecipeTooNew] for
  /// `v` above [version] and [FormatException] for something that isn't
  /// one.
  static ChannelRecipe fromJson(Object? json) {
    if (json is! Map) throw const FormatException('not a channel recipe');
    final v = _int(json['v']);
    if (v == null) throw const FormatException('not a channel recipe');
    if (v > version) throw RecipeTooNew(v);
    final icon = json['icon'];
    ChannelIcon? parsedIcon;
    if (icon is Map) {
      final kind = ChannelIconKind.values.asNameMap()[icon['kind']];
      if ((kind == ChannelIconKind.builtin || kind == ChannelIconKind.badge) && icon['value'] is String) {
        parsedIcon = ChannelIcon(
          kind: kind!,
          value: icon['value'] as String,
          color: _int(icon['color']) ?? 0xFFFFD23F,
          shape: BadgeShape.values.asNameMap()[icon['shape']] ?? BadgeShape.roundedSquare,
        );
      }
    }
    final slot = json['slot'];
    SlotRule? rule;
    if (slot is Map) {
      final length = Duration(minutes: _int(slot['lengthMin']) ?? 0);
      if (SlotRule.lengths.contains(length)) {
        final tail = TailMode.parse(slot['tail']) ?? TailMode.filler;
        rule = SlotRule(length: length, tail: tail);
      }
    }
    final breaks = json['breaks'];
    final retro = ChannelRetro.fromJson(json['retro']);
    return ChannelRecipe(
      v: v,
      name: (json['name'] as String?)?.trim() ?? '',
      icon: parsedIcon,
      station: json['station'] as String? ?? '',
      order: PlaybackOrder.parse(json['order']),
      anchor: DateTime.tryParse(json['anchor'] as String? ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      blockOnly: json['blockOnly'] as bool? ?? false,
      breaks: breaks is Map<String, Object?>
          ? (() {
              final p = BreakPlan.fromJson(breaks);
              return BreakPlan(mode: p.mode, roles: _withoutPools(p.roles));
            })()
          : null,
      slot: rule,
      retro: retro.copyWith(surroundImage: () => null, surround: retro.surround == Surround.image ? () => null : null),
      logoMode: LogoMode.parse(json['logoMode']),
      shows: [for (final s in json['shows'] as List? ?? const []) if (s is Map<String, Object?>) RecipeShow.fromJson(s)],
      items: [for (final i in json['items'] as List? ?? const []) ?RecipeItem.fromJson(i)],
      blocks: [for (final b in json['blocks'] as List? ?? const []) ?RecipeBlock.fromJson(b)],
    );
  }
}

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

List<String> _strings(Object? v) => [for (final s in v as List? ?? const []) if (s is String) s];

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseDay(Object? s) {
  final now = DateTime.now();
  if (s is String) {
    final parts = s.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
  }
  return DateTime(now.year, now.month, now.day);
}
