/// What a Live TV source says about its channels and their guide
/// (live-tv-sources). Plain data, so it crosses isolates and goes into the
/// cache as JSON.
library;

/// One channel as its source lists it.
class LiveChannelInfo {
  const LiveChannelInfo({
    required this.key,
    required this.name,
    this.number,
    this.group,
    this.logo,
    this.guideId,
    this.tvgName,
    this.url,
    this.headers = const {},
    this.hasGuide = false,
  });

  /// Stable identity within the source (see "Stable live channel identity").
  final String key;
  final String name;

  /// The source's own number, as it writes it ("7", "2.1").
  final String? number;

  /// M3U `group-title`, the Plex DVR's lineup name; null for one group.
  final String? group;

  /// The logo's URL.
  final String? logo;

  /// M3U `tvg-id`; the server's channel id for server Live TV.
  final String? guideId;

  /// M3U `tvg-name`, for matching the guide by name.
  final String? tvgName;

  /// M3U only: the stream, and the headers to open it with.
  final String? url;
  final Map<String, String> headers;

  /// Whether the guide has data for it.
  final bool hasGuide;

  LiveChannelInfo copyWith({bool? hasGuide, String? logo, String? url}) => LiveChannelInfo(
        key: key,
        name: name,
        number: number,
        group: group,
        logo: logo ?? this.logo,
        guideId: guideId,
        tvgName: tvgName,
        url: url ?? this.url,
        headers: headers,
        hasGuide: hasGuide ?? this.hasGuide,
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'name': name,
        'number': ?number,
        'group': ?group,
        'logo': ?logo,
        'guideId': ?guideId,
        'tvgName': ?tvgName,
        'url': ?url,
        if (headers.isNotEmpty) 'headers': headers,
        if (hasGuide) 'hasGuide': true,
      };

  factory LiveChannelInfo.fromJson(Map<String, Object?> j) => LiveChannelInfo(
        key: j['key'] as String,
        name: j['name'] as String,
        number: j['number'] as String?,
        group: j['group'] as String?,
        logo: j['logo'] as String?,
        guideId: j['guideId'] as String?,
        tvgName: j['tvgName'] as String?,
        url: j['url'] as String?,
        headers: (j['headers'] as Map?)?.cast<String, String>() ?? const {},
        hasGuide: j['hasGuide'] == true,
      );

  /// [number] as major and minor parts for ordering (2.1 < 2.2 < 3.1 < 10);
  /// null when it isn't a number.
  (int, int)? get numberParts => parseSourceNumber(number);
}

/// "2.1" → (2, 1), "7" → (7, 0), "4-1" → (4, 1); null for anything else.
(int, int)? parseSourceNumber(String? number) {
  final m = RegExp(r'^\s*(\d+)(?:[.\-_](\d+))?\s*$').firstMatch(number ?? '');
  if (m == null) return null;
  return (int.parse(m[1]!), int.tryParse(m[2] ?? '') ?? 0);
}

/// Orders channels as the source does: by number (major.minor), numbered
/// ones first, then by name.
int compareSourceOrder(LiveChannelInfo a, LiveChannelInfo b) {
  final x = a.numberParts, y = b.numberParts;
  if (x != null && y != null) {
    final c = x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2);
    if (c != 0) return c;
  } else if (x != null || y != null) {
    return x != null ? -1 : 1;
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// A channel in an XMLTV guide, for matching and the picker.
class GuideChannel {
  const GuideChannel({required this.id, this.names = const [], this.icon});

  final String id;

  /// Its display names, in order.
  final List<String> names;
  final String? icon;

  Map<String, Object?> toJson() => {'id': id, if (names.isNotEmpty) 'names': names, 'icon': ?icon};

  factory GuideChannel.fromJson(Map<String, Object?> j) => GuideChannel(
        id: j['id'] as String,
        names: (j['names'] as List?)?.cast<String>() ?? const [],
        icon: j['icon'] as String?,
      );
}

/// One airing in a live channel's guide.
class LiveProgramme {
  const LiveProgramme({
    required this.start,
    required this.end,
    required this.title,
    this.subtitle,
    this.description,
    this.categories = const [],
    this.year,
    this.rating,
    this.season,
    this.episode,
    this.isNew = false,
    this.isMovie = false,
    this.icon,
  });

  final DateTime start;
  final DateTime end;
  final String title;

  /// The episode title (`sub-title`).
  final String? subtitle;
  final String? description;
  final List<String> categories;
  final int? year;
  final String? rating;

  /// One-based.
  final int? season;
  final int? episode;

  /// A new or premiere airing.
  final bool isNew;
  final bool isMovie;
  final String? icon;

  Duration get duration => end.difference(start);

  LiveProgramme withEnd(DateTime end) => LiveProgramme(
        start: start,
        end: end,
        title: title,
        subtitle: subtitle,
        description: description,
        categories: categories,
        year: year,
        rating: rating,
        season: season,
        episode: episode,
        isNew: isNew,
        isMovie: isMovie,
        icon: icon,
      );

  /// Compact: times in epoch seconds, empty fields left out.
  Map<String, Object?> toJson() => {
        's': start.millisecondsSinceEpoch ~/ 1000,
        'e': end.millisecondsSinceEpoch ~/ 1000,
        't': title,
        'st': ?subtitle,
        'd': ?description,
        if (categories.isNotEmpty) 'c': categories,
        'y': ?year,
        'r': ?rating,
        'sn': ?season,
        'ep': ?episode,
        if (isNew) 'n': 1,
        if (isMovie) 'm': 1,
        'i': ?icon,
      };

  factory LiveProgramme.fromJson(Map<String, Object?> j) => LiveProgramme(
        start: DateTime.fromMillisecondsSinceEpoch((j['s'] as int) * 1000),
        end: DateTime.fromMillisecondsSinceEpoch((j['e'] as int) * 1000),
        title: j['t'] as String,
        subtitle: j['st'] as String?,
        description: j['d'] as String?,
        categories: (j['c'] as List?)?.cast<String>() ?? const [],
        year: j['y'] as int?,
        rating: j['r'] as String?,
        season: j['sn'] as int?,
        episode: j['ep'] as int?,
        isNew: j['n'] == 1,
        isMovie: j['m'] == 1,
        icon: j['i'] as String?,
      );
}

/// Sorts [programmes] by start and cuts overlaps so the later one wins;
/// drops what ends by [now] or is empty.
List<LiveProgramme> tidyProgrammes(List<LiveProgramme> programmes, DateTime now) {
  final sorted = [...programmes]..sort((a, b) => a.start.compareTo(b.start));
  final out = <LiveProgramme>[];
  for (var i = 0; i < sorted.length; i++) {
    var p = sorted[i];
    if (i + 1 < sorted.length && sorted[i + 1].start.isBefore(p.end)) p = p.withEnd(sorted[i + 1].start);
    if (!p.end.isAfter(p.start) || !p.end.isAfter(now)) continue;
    out.add(p);
  }
  return out;
}
