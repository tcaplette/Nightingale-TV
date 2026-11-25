import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/tr.dart';
import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';
import '../youtube_frame.dart';

/// Watch (youtube-web-player): a profile's YouTube channels with what's on
/// now and next. YouTube's terms allow them only in YouTube's own player,
/// so this is where the server's YouTube channels are watched.
class WatchPage extends StatefulWidget {
  const WatchPage({super.key, required this.profileId});
  final String profileId;

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  Map<String, Object?>? _data;
  String? _error;
  Timer? _poll;
  late final ApiClient _api = context.api;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // What's on moves on.
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(_load()));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = (await _api.get('profiles/${widget.profileId}/youtube/channels'))! as Map<String, Object?>;
      if (mounted) setState(() => _data = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _note(Map<String, Object?> n) {
    if (n['kind'] == 'dailyLimit' && n['until'] is String) {
      final until = DateTime.parse(n['until'] as String).toLocal();
      return tr.youTubeDailyLimit(TimeOfDay.fromDateTime(until).format(context));
    }
    return '${n['text']}';
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) {
      return PageBody(title: tr.watch, children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final channels = (d['channels'] as List).cast<Map<String, Object?>>();
    final notes = (d['notes'] as List? ?? const []).cast<Map<String, Object?>>();
    final scheme = Theme.of(context).colorScheme;
    return PageBody(title: tr.watch, children: [
      for (final n in notes)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(_note(n), key: ValueKey('note-${n['kind']}'), style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
        ),
      if (channels.isEmpty)
        Section(children: [Text(tr.watchNoChannels)])
      else
        Section(children: [
          for (final c in channels)
            ListTile(
              key: ValueKey('watch-${c['id']}'),
              contentPadding: EdgeInsets.zero,
              leading: _Logo(profileId: widget.profileId, channelId: '${c['id']}', name: '${c['name']}'),
              title: Text('${c['number']}  ${c['name']}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (c['now'] case final Map now) Text(tr.nowPlaying('${now['title']}'), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (c['next'] case final Map next) Text(tr.upNext('${next['title']}'), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (c['now'] == null) Text(tr.noVideosYet),
              ]),
              trailing: const Icon(Icons.play_circle_outline),
              onTap: () => context.go('/profiles/${widget.profileId}/watch/${Uri.encodeComponent('${c['id']}')}'),
            ),
        ]),
    ]);
  }
}

/// A channel's avatar, through the server.
class _Logo extends StatelessWidget {
  const _Logo({required this.profileId, required this.channelId, required this.name});
  final String profileId, channelId, name;

  @override
  Widget build(BuildContext context) {
    final initial = CircleAvatar(radius: 20, child: Text(name.isEmpty ? '?' : name.characters.first));
    return ClipOval(
      child: Image.network(context.api.href('profiles/$profileId/channels/${Uri.encodeComponent(channelId)}/logo'),
          width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => initial),
    );
  }
}

/// A YouTube channel playing in the whole window: YouTube's player at the
/// scheduled point, the next video when one ends, paused while the tab is
/// hidden. The channel's number and name sit in a bar above the player,
/// never over it. Esc, Back and the browser's back return to the list.
class WatchPlayerPage extends StatefulWidget {
  const WatchPlayerPage({super.key, required this.profileId, required this.channelId});
  final String profileId;
  final String channelId;

  @override
  State<WatchPlayerPage> createState() => _WatchPlayerPageState();
}

class _WatchPlayerPageState extends State<WatchPlayerPage> {
  late final ApiClient _api = context.api;
  final YouTubeFrame _frame = YouTubeFrame.create();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Map<String, Object?>? _on;
  String? _message;
  String? _channelLabel;

  /// The page's key focus, given back when the bar is clicked (after the
  /// viewer used YouTube's own controls).
  final _keys = FocusNode(debugLabel: 'watch');
  bool _left = false;

  /// Videos skipped in a row (won't play here); a stop after a few.
  int _skips = 0;
  int _tuning = 0;

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(_frame.events.listen(_onEvent))
      ..add(_frame.escapes.listen((_) => _back()))
      ..add(_frame.hiddenChanges.listen((hidden) {
        if (hidden) {
          _frame.pause();
        } else {
          unawaited(_tune());
        }
      }));
    unawaited(_tune());
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _frame.dispose();
    _keys.dispose();
    super.dispose();
  }

  /// Plays what the channel has on now (after [ended], when that video just
  /// ended), from the scheduled point.
  Future<void> _tune({String? ended}) async {
    final run = ++_tuning;
    try {
      final on = (await _api.get('profiles/${widget.profileId}/youtube/${Uri.encodeComponent(widget.channelId)}/now',
          {'ended': ?ended}))! as Map<String, Object?>;
      if (!mounted || run != _tuning) return;
      final channel = on['channel'] as Map?;
      setState(() {
        _on = on;
        _message = null;
        if (channel != null) _channelLabel = '${channel['number']}  ${channel['name']}';
      });
      if (_frame.hidden) return;
      await _frame.load('${on['videoId']}', Duration(seconds: (on['offsetSeconds'] as num).toInt()));
    } on ApiException catch (e) {
      if (mounted && run == _tuning) setState(() => _message = e.message);
    }
  }

  void _onEvent(YouTubeFrameEvent e) {
    final current = _on?['videoId'];
    switch (e) {
      case YouTubeFramePlaying():
        _skips = 0;
      case YouTubeFrameEnded(:final videoId) when videoId == current:
        unawaited(_tune(ended: videoId));
      case YouTubeFrameError(code: 153):
        setState(() => _message = tr.youTubeRefusedPlayer);
      case YouTubeFrameError(:final videoId) when videoId == null || videoId == current:
        // It won't play here: the channel goes on with the next one.
        if (++_skips > 5) {
          setState(() => _message = tr.youTubeRefusedPlayer);
          return;
        }
        unawaited(_tune(ended: '$current'));
      default:
        break;
    }
  }

  void _back() {
    // Esc from the page and from Flutter can both arrive: once is enough.
    if (_left || !mounted) return;
    _left = true;
    context.go('/profiles/${widget.profileId}/watch');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = _on?['title'] as String?;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
      child: Focus(
        focusNode: _keys,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(children: [
              Listener(
                onPointerDown: (_) => _keys.requestFocus(),
                  child: Material(
                  color: const Color(0xFF0F2263),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(children: [
                      TextButton.icon(
                        key: const ValueKey('watch-back'),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.arrow_back),
                        label: Text(tr.back),
                        onPressed: _back,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(_channelLabel ?? '',
                              key: const ValueKey('watch-channel'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                          if (_message ?? title case final line?)
                            Text(line,
                                key: const ValueKey('watch-line'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodyMedium?.copyWith(color: _message == null ? Colors.white70 : const Color(0xFFFFB4AB))),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
              // YouTube's frame, with nothing drawn over it.
              Expanded(
                child: Center(
                  child: AspectRatio(aspectRatio: 16 / 9, child: _frame.view()),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
