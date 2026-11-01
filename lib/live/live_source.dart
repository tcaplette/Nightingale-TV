import 'dart:math';

import '../channels/channel.dart';
import '../channels/retro.dart';
import '../server/media_server.dart';

enum LiveSourceKind {
  /// The profile's own Jellyfin, Emby or Plex server's Live TV.
  server,

  /// An M3U playlist with an XMLTV guide.
  m3u;

  String get label => switch (this) {
        server => 'Server Live TV',
        m3u => 'M3U playlist',
      };
}

/// A chosen channel's own settings, saved with its source (live-tv-sources
/// D1): what the user changed, and its number.
class LiveChannelSettings {
  LiveChannelSettings({
    required this.number,
    this.name,
    this.icon,
    this.logoMode = LogoMode.off,
    this.retro = ChannelRetro.live,
    this.hidden = false,
    this.favorite = false,
  });

  int number;

  /// The user's name for it; null takes the source's.
  String? name;

  /// The user's icon; null takes the source's logo.
  ChannelIcon? icon;

  /// Its logo setting; null follows the main one. Live channels start Off
  /// (broadcasts carry their own logo).
  LogoMode? logoMode;

  /// Its retro look. Live channels start at Original and CRT Off (design
  /// D10), and those from before this setting read the same.
  ChannelRetro retro;
  bool hidden;
  bool favorite;

  Map<String, Object?> toJson() => {
        'number': number,
        'name': ?name,
        if (icon != null) 'icon': icon!.toJson(),
        'logoMode': logoMode?.name ?? 'main',
        'retro': retro.toJson(),
        if (hidden) 'hidden': true,
        if (favorite) 'favorite': true,
      };

  factory LiveChannelSettings.fromJson(Map<String, Object?> j) => LiveChannelSettings(
        number: j['number'] as int,
        name: j['name'] as String?,
        icon: j['icon'] is Map<String, Object?> ? ChannelIcon.fromJson(j['icon'] as Map<String, Object?>) : null,
        logoMode: j['logoMode'] == 'main' ? null : LogoMode.parse(j['logoMode']) ?? LogoMode.off,
        retro: j.containsKey('retro') ? ChannelRetro.fromJson(j['retro']) : ChannelRetro.live,
        hidden: j['hidden'] == true,
        favorite: j['favorite'] == true,
      );
}

/// A chosen channel that left its source at a refresh: what it had, to give
/// back if it returns within [LiveSource.departedMemory].
class DepartedChannel {
  DepartedChannel({required this.settings, required this.groupIds, required this.leftAt});

  final LiveChannelSettings settings;

  /// The user groups it was in.
  final List<String> groupIds;
  final DateTime leftAt;

  Map<String, Object?> toJson() => {
        'settings': settings.toJson(),
        if (groupIds.isNotEmpty) 'groups': groupIds,
        'leftAt': leftAt.toUtc().toIso8601String(),
      };

  factory DepartedChannel.fromJson(Map<String, Object?> j) => DepartedChannel(
        settings: LiveChannelSettings.fromJson(j['settings'] as Map<String, Object?>),
        groupIds: (j['groups'] as List?)?.cast<String>() ?? const [],
        leftAt: DateTime.parse(j['leftAt'] as String).toLocal(),
      );
}

/// One of a profile's Live TV sources.
class LiveSource {
  LiveSource({
    required this.id,
    required this.kind,
    required this.name,
    this.serverKind,
    this.serverId,
    this.playlistUrl,
    this.playlistFile,
    this.guideUrl,
    this.guideFile,
    this.guideFromPlaylist = false,
    Map<String, LiveChannelSettings>? chosen,
    Map<String, DepartedChannel>? departed,
  })  : chosen = chosen ?? {},
        departed = departed ?? {};

  /// How long a channel that left is remembered.
  static const departedMemory = Duration(days: 30);

  /// A source holding at most this many channels starts with all of them
  /// chosen; a bigger one with none.
  static const chooseAllUpTo = 150;

  final String id;
  final LiveSourceKind kind;
  String name;

  /// Server Live TV: the server it belongs to. Its channels only join while
  /// the profile is signed in to that server.
  final ServerKind? serverKind;
  final String? serverId;

  /// M3U: the playlist and the guide, each a URL or a file copied into the
  /// profile folder (`LiveSourceStore.filesDir`).
  String? playlistUrl;
  String? playlistFile;
  String? guideUrl;
  String? guideFile;

  /// [guideUrl] came from the playlist's header, since none was given; it
  /// follows the header at each refresh.
  bool guideFromPlaylist;

  /// The chosen channels, by key.
  final Map<String, LiveChannelSettings> chosen;

  /// Chosen channels that left the source, by key.
  final Map<String, DepartedChannel> departed;

  /// Forgets channels that left more than [departedMemory] before [now].
  void forgetDeparted(DateTime now) =>
      departed.removeWhere((_, d) => now.difference(d.leftAt) > departedMemory);

  static String newId() =>
      'src${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1296).toRadixString(36)}';

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        if (serverKind != null) 'serverKind': serverKind!.name,
        'serverId': ?serverId,
        'playlistUrl': ?playlistUrl,
        'playlistFile': ?playlistFile,
        'guideUrl': ?guideUrl,
        'guideFile': ?guideFile,
        if (guideFromPlaylist) 'guideFromPlaylist': true,
        'chosen': {for (final e in chosen.entries) e.key: e.value.toJson()},
        if (departed.isNotEmpty) 'departed': {for (final e in departed.entries) e.key: e.value.toJson()},
      };

  factory LiveSource.fromJson(Map<String, Object?> j) => LiveSource(
        id: j['id'] as String,
        kind: LiveSourceKind.values.byName(j['kind'] as String),
        name: j['name'] as String,
        serverKind: j['serverKind'] == null ? null : ServerKind.fromJson(j['serverKind']),
        serverId: j['serverId'] as String?,
        playlistUrl: j['playlistUrl'] as String?,
        playlistFile: j['playlistFile'] as String?,
        guideUrl: j['guideUrl'] as String?,
        guideFile: j['guideFile'] as String?,
        guideFromPlaylist: j['guideFromPlaylist'] == true,
        chosen: {
          for (final e in ((j['chosen'] as Map?) ?? const {}).entries)
            e.key as String: LiveChannelSettings.fromJson(e.value as Map<String, Object?>),
        },
        departed: {
          for (final e in ((j['departed'] as Map?) ?? const {}).entries)
            e.key as String: DepartedChannel.fromJson(e.value as Map<String, Object?>),
        },
      );
}
