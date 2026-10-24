import '../live/live_data.dart';
import 'media_server.dart';

/// Whether a server's Live TV can be a source, and why not.
enum LiveTvAvailability {
  available,

  /// No tuner, no DVR, or no channels.
  noChannels,

  /// The signed-in user may not watch Live TV.
  noAccess;

  /// What Add source says, for [serverName].
  String reason(String serverName) => switch (this) {
        available => '$serverName Live TV',
        noChannels => '$serverName has no Live TV channels',
        noAccess => "Your $serverName account can't watch Live TV",
      };
}

/// Why a live stream didn't open or stopped (live-playback "Live stand-by
/// messages").
enum LiveFailure {
  /// The server has no free tuner.
  tunersBusy,

  /// The server or the provider couldn't be reached.
  unreachable,

  /// The server refused the user (401, 403).
  refused,

  /// An IPTV provider refused the stream (403, 458, 509: its connection
  /// limit, usually).
  providerRefused,

  /// Android can't play the channel's stream type.
  unsupportedScheme,

  /// The device can't decode the channel's video.
  cantDecode,

  /// No picture arrived in time, or anything else.
  other,
}

class LiveTvException implements Exception {
  const LiveTvException(this.failure, this.message);

  final LiveFailure failure;

  /// For logs; the TV shows the failure's own card.
  final String message;

  @override
  String toString() => 'LiveTvException(${failure.name}): $message';

  /// [e] from opening a server's live stream, as a failure.
  factory LiveTvException.fromServer(ServerException e) {
    final text = '${e.message} ${e.detail ?? ''}'.toLowerCase();
    if (e.unreachable) return LiveTvException(LiveFailure.unreachable, e.message);
    if (e.statusCode == 401 || e.statusCode == 403) return LiveTvException(LiveFailure.refused, e.message);
    if (_tunerBusy(text)) return LiveTvException(LiveFailure.tunersBusy, e.message);
    return LiveTvException(LiveFailure.other, e.message);
  }

  static bool _tunerBusy(String text) =>
      RegExp(r'tuners? (are |is )?(in use|busy|unavailable)|no (free|available) tuners?|all tuners|tuner limit|'
              r'tunerlimit|livetvconflict|no tuner')
          .hasMatch(text);

  /// A server's message about why a tune failed (Plex), as a failure.
  factory LiveTvException.fromMessage(String message) => LiveTvException(
      _tunerBusy(message.toLowerCase()) ? LiveFailure.tunersBusy : LiveFailure.other, message);
}

/// An open live stream: what the player opens, and what closing it needs.
class LiveStream {
  LiveStream({
    required this.channelId,
    required this.uri,
    this.headers = const {},
    this.method = PlayMethod.directPlay,
    this.playSessionId,
    this.liveStreamId,
    this.mediaSourceId,
    this.transcodeSession,
    this.extra = const {},
  });

  final String channelId;
  final Uri uri;
  final Map<String, String> headers;

  /// Direct, direct stream or transcode, as the server decided.
  final PlayMethod method;
  final String? playSessionId;

  /// Jellyfin and Emby: the live stream to close.
  final String? liveStreamId;
  final String? mediaSourceId;

  /// A transcode job to stop on close (Jellyfin and Emby: the play
  /// session; Plex: the transcoder session).
  final String? transcodeSession;

  /// What else a server needs to report on and close it (Plex: the tuned
  /// session's key).
  final Map<String, String> extra;

  bool closed = false;
}

/// A server's Live TV (live-tv-sources D3): its channels and guide, and live
/// streams opened and closed as the server's own web client does.
abstract interface class LiveTv {
  Future<LiveTvAvailability> availability();

  /// Every channel the user may watch, in the server's order.
  Future<List<LiveChannelInfo>> channels();

  /// Programmes of [channelIds] overlapping [from, to), by channel id.
  Future<Map<String, List<LiveProgramme>>> programs(List<String> channelIds, DateTime from, DateTime to);

  /// Opens [channelId]'s live stream under [maxBitrate] (bits per second;
  /// null for none) for a device described by [profile] (null: Linux).
  /// Throws [LiveTvException].
  Future<LiveStream> open(String channelId,
      {int? maxBitrate, bool forceTranscode = false, Map<String, Object?>? profile});

  /// Closes [stream] on the server; safe to call twice.
  Future<void> close(LiveStream stream);

  Future<void> reportStart(LiveStream stream);
  Future<void> reportProgress(LiveStream stream, Duration position);
  Future<void> reportStopped(LiveStream stream, Duration position);
}
