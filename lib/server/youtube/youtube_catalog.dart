import 'dart:async';

import '../../library/library_index.dart';
import '../../playback/playback_diagnostics.dart';
import 'youtube_api.dart';

/// One picked channel's part of the catalog.
class CatalogChannel {
  CatalogChannel({
    required this.channelId,
    required this.title,
    this.avatar,
    List<YouTubeVideo>? videos,
    Map<String, DateTime>? leftOut,
    this.fetchedAt,
    this.uploadsOnly = false,
  })  : videos = videos ?? [],
        leftOut = leftOut ?? {};

  final String channelId;
  String title;
  String? avatar;

  /// Newest first, at most [YouTubeCatalog.maxVideos].
  List<YouTubeVideo> videos;

  /// Ids found and left out (Shorts, live, not embeddable…), with when, so
  /// a refresh doesn't ask about them again; forgotten after 30 days.
  final Map<String, DateTime> leftOut;

  /// When the channel's first fetch finished; null until it has.
  DateTime? fetchedAt;

  /// The channel has no long-form playlist: its uploads are read, Shorts
  /// left out by length (D6).
  bool uploadsOnly;

  Map<String, Object?> toJson() => {
        'title': title,
        'avatar': ?avatar,
        'videos': [for (final v in videos) v.toJson()],
        if (leftOut.isNotEmpty) 'leftOut': {for (final e in leftOut.entries) e.key: e.value.toUtc().toIso8601String()},
        if (fetchedAt != null) 'fetchedAt': fetchedAt!.toUtc().toIso8601String(),
        if (uploadsOnly) 'uploadsOnly': true,
      };

  static CatalogChannel fromJson(String id, Map j) => CatalogChannel(
        channelId: id,
        title: j['title'] as String? ?? '',
        avatar: j['avatar'] as String?,
        videos: [for (final v in (j['videos'] as List? ?? const [])) ?YouTubeVideo.fromJson(v)],
        leftOut: {
          for (final e in ((j['leftOut'] as Map?) ?? const {}).entries) '${e.key}': ?DateTime.tryParse('${e.value}'),
        },
        fetchedAt: DateTime.tryParse(j['fetchedAt'] as String? ?? ''),
        uploadsOnly: j['uploadsOnly'] == true,
      );
}

/// What a YouTube server knows of its picked channels' videos (D6), kept in
/// `youtube/<serverKey>/catalog.json` in the profile folder, with the
/// server's daily-limit and sign-in state (D11).
class YouTubeCatalog {
  YouTubeCatalog({Map<String, CatalogChannel>? channels, this.refreshedAt, this.quotaBlockedUntil, this.signInLostAt})
      : channels = channels ?? {};

  static String folderOf(String serverKey) => 'youtube/$serverKey';
  static String fileOf(String serverKey) => '${folderOf(serverKey)}/catalog.json';

  /// The newest videos kept per channel.
  static const maxVideos = 200;

  /// Playlist pages a first fetch reads at most.
  static const firstPages = 8;

  static const refreshEvery = Duration(hours: 6);
  static const recheckAfter = Duration(days: 25);

  /// YouTube's data is refreshed or deleted within this (D6).
  static const keepFor = Duration(days: 30);

  /// Revoked sign-ins' data is deleted after this (D11).
  static const signInGrace = Duration(days: 7);

  final Map<String, CatalogChannel> channels;
  DateTime? refreshedAt;

  /// No API request until then (YouTube's daily limit, D11).
  DateTime? quotaBlockedUntil;

  /// When the sign-in was found revoked or expired (Needs sign-in).
  DateTime? signInLostAt;

  /// Video ids the player refused (100, 101, 150): dropped at the next
  /// refresh (youtube-playback).
  final refused = <String>{};

  bool get isEmpty => channels.isEmpty && quotaBlockedUntil == null && signInLostAt == null;

  Map<String, Object?> toJson() => {
        'channels': {for (final c in channels.values) c.channelId: c.toJson()},
        if (refreshedAt != null) 'refreshedAt': refreshedAt!.toUtc().toIso8601String(),
        if (quotaBlockedUntil != null) 'quotaBlockedUntil': quotaBlockedUntil!.toUtc().toIso8601String(),
        if (signInLostAt != null) 'signInLostAt': signInLostAt!.toUtc().toIso8601String(),
        if (refused.isNotEmpty) 'refused': refused.toList(),
      };

  static YouTubeCatalog fromJson(Object? j) {
    if (j is! Map) return YouTubeCatalog();
    DateTime? time(Object? v) => DateTime.tryParse(v as String? ?? '');
    return YouTubeCatalog(
      channels: {
        for (final e in ((j['channels'] as Map?) ?? const {}).entries)
          if (e.value is Map) '${e.key}': CatalogChannel.fromJson('${e.key}', e.value as Map),
      },
      refreshedAt: time(j['refreshedAt']),
      quotaBlockedUntil: time(j['quotaBlockedUntil']),
      signInLostAt: time(j['signInLostAt']),
    )..refused.addAll([for (final id in (j['refused'] as List? ?? const [])) '$id']);
  }

  /// Whether the daily limit still holds at [now].
  bool blocked(DateTime now) => quotaBlockedUntil != null && now.isBefore(quotaBlockedUntil!);

  /// A refresh is due: never refreshed, 6 hours since, or a pick not
  /// fetched yet.
  bool due(DateTime now, Iterable<String> picks) =>
      refreshedAt == null ||
      !now.isBefore(refreshedAt!.add(refreshEvery)) ||
      picks.any((id) => channels[id]?.fetchedAt == null);

  /// Deletes what is 30 days old even if no refresh could run (D6), and
  /// everything once a lost sign-in wasn't renewed for 7 days (D11).
  /// True when anything went.
  bool purge(DateTime now) {
    var changed = false;
    if (signInLostAt != null && !now.isBefore(signInLostAt!.add(signInGrace)) && channels.isNotEmpty) {
      channels.clear();
      refused.clear();
      return true;
    }
    final cutoff = now.subtract(keepFor);
    for (final c in channels.values) {
      final before = c.videos.length + c.leftOut.length;
      c.videos.removeWhere((v) => !v.fetchedAt.isAfter(cutoff));
      c.leftOut.removeWhere((_, when) => !when.isAfter(cutoff));
      if (c.videos.length + c.leftOut.length != before) changed = true;
    }
    return changed;
  }

  /// Brings the catalog up to date for [picks] (the server's picked
  /// channel ids) at [now]. Throws [YouTubeQuotaException] (the daily
  /// limit; what's fetched so far is kept) and sign-in failures; other
  /// failures leave a channel as it was.
  Future<void> refresh(YouTubeApi api, List<String> picks, DateTime now) async {
    channels.removeWhere((id, _) => !picks.contains(id));
    purge(now);
    if (picks.isEmpty) {
      refreshedAt = now;
      return;
    }
    // Names and avatars: one call for every pick (D6's 30-day rule).
    final infos = await api.channels(picks);
    for (final id in picks) {
      final info = infos[id];
      final c = channels.putIfAbsent(id, () => CatalogChannel(channelId: id, title: info?.title ?? id));
      if (info != null) {
        c.title = info.title;
        c.avatar = info.avatar ?? c.avatar;
      }
    }
    for (final id in picks) {
      final c = channels[id]!;
      try {
        if (c.fetchedAt == null) {
          await _firstFetch(api, c, now);
        } else {
          await _update(api, c, now);
        }
      } on YouTubeApiException catch (e) {
        PlaybackDiagnostics.note('YOUTUBE', 'channel $id not refreshed: $e');
      }
    }
    refused.clear();
    refreshedAt = now;
  }

  Future<({List<String> ids, String? next})?> _page(YouTubeApi api, CatalogChannel c, String? page) async {
    if (!c.uploadsOnly) {
      final longForm = await api.playlistPage(YouTubeApi.longFormPlaylist(c.channelId), page: page);
      if (longForm != null) return longForm;
      // No long-form playlist: the uploads, Shorts left out by length.
      c.uploadsOnly = true;
      if (page != null) return null;
    }
    return api.playlistPage(YouTubeApi.uploadsPlaylist(c.channelId), page: page);
  }

  Future<void> _firstFetch(YouTubeApi api, CatalogChannel c, DateTime now) async {
    final found = <YouTubeVideo>[];
    String? page;
    for (var n = 0; n < firstPages; n++) {
      final p = await _page(api, c, page);
      if (p == null) break;
      final checks = await api.videos(p.ids, now: now, dropShorts: c.uploadsOnly);
      for (final id in p.ids) {
        switch (checks[id]) {
          case VideoPlayable(:final video):
            found.add(video);
          case VideoLeftOut():
            c.leftOut[id] = now;
          case null:
        }
      }
      page = p.next;
      if (found.length >= maxVideos || page == null) break;
    }
    c.videos = _newestFirst(found);
    c.fetchedAt = now;
  }

  Future<void> _update(YouTubeApi api, CatalogChannel c, DateTime now) async {
    final known = {for (final v in c.videos) v.id};
    final p = await _page(api, c, null);
    final fresh = [
      for (final id in p?.ids ?? const <String>[])
        if (!known.contains(id) && !c.leftOut.containsKey(id)) id
    ];
    final due = [
      for (final v in c.videos)
        if (refused.contains(v.id) || !now.isBefore(v.fetchedAt.add(recheckAfter))) v.id
    ];
    final ask = [...fresh, ...due];
    final checks = ask.isEmpty ? const <String, VideoCheck>{} : await api.videos(ask, now: now, dropShorts: c.uploadsOnly);
    final byId = {for (final v in c.videos) v.id: v};
    for (final id in ask) {
      switch (checks[id]) {
        case VideoPlayable(:final video) when !refused.contains(id):
          byId[id] = video;
        case VideoPlayable() || VideoLeftOut() || null:
          byId.remove(id);
          c.leftOut[id] = now;
      }
    }
    c.videos = _newestFirst(byId.values);
    c.fetchedAt = now;
  }

  static List<YouTubeVideo> _newestFirst(Iterable<YouTubeVideo> videos) {
    final list = videos.toList()..sort((a, b) => b.published.compareTo(a.published));
    return list.length > maxVideos ? list.sublist(0, maxVideos) : list;
  }

  /// The videos as library entries under the server's own ids (D2).
  List<MediaEntry> entries() => [
        for (final c in channels.values)
          for (final v in c.videos)
            MediaEntry(
              id: v.id,
              kind: MediaKind.youtubeVideo,
              title: v.title,
              runtime: v.length,
              seriesKey: 'yt:${c.channelId}',
              seriesName: c.title,
              overview: v.description.isEmpty ? null : v.description,
              added: v.published,
            ),
      ];

  /// A video's thumbnail, for the guide's info panel.
  String? thumbnailOf(String videoId) {
    for (final c in channels.values) {
      for (final v in c.videos) {
        if (v.id == videoId) return v.thumbnail;
      }
    }
    return null;
  }
}
