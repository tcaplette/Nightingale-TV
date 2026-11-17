import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../channels/channel.dart';
import '../../sharing/presence.dart';
import '../../theme/tv_theme.dart';
import 'friend_avatar_stack.dart';

/// The player's corner card (friend-presence D5): tuning to a shared channel
/// friends are on shows their avatars and "Tyler is watching too" for
/// [showFor]; a friend starting to watch the channel shows it again. It
/// never takes focus or pointer input.
class FriendsWatchingCard extends StatefulWidget {
  const FriendsWatchingCard({super.key, required this.channel});

  static const showFor = Duration(seconds: 5);

  /// The channel on now.
  final Channel? channel;

  @override
  State<FriendsWatchingCard> createState() => _FriendsWatchingCardState();
}

class _FriendsWatchingCardState extends State<FriendsWatchingCard> {
  Presence? _presence;
  Timer? _hide;
  bool _shown = false;

  /// The channel and the friends the card last came up for.
  String? _channelId;
  Set<String> _seen = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final presence = context.getInheritedWidgetOfExactType<HouseholdScope>()?.notifier?.sharing?.presence;
    if (!identical(presence, _presence)) {
      _presence?.removeListener(_check);
      _presence = presence?..addListener(_check);
      _check(building: true);
    }
  }

  @override
  void didUpdateWidget(FriendsWatchingCard old) {
    super.didUpdateWidget(old);
    if (old.channel?.id != widget.channel?.id) _check(building: true);
  }

  @override
  void dispose() {
    _presence?.removeListener(_check);
    _hide?.cancel();
    super.dispose();
  }

  /// [building]: called from a lifecycle method, with a build to follow.
  void _check({bool building = false}) {
    final ch = widget.channel;
    final friends = _presence?.onChannel(ch) ?? const [];
    final ids = {for (final f in friends) f.userId};
    final newChannel = ch?.id != _channelId;
    final arrived = ids.difference(_seen).isNotEmpty;
    _channelId = ch?.id;
    _seen = newChannel ? ids : {..._seen.intersection(ids), ...ids};
    var shown = _shown;
    if (friends.isEmpty) {
      shown = false;
      _hide?.cancel();
    } else if (newChannel || arrived) {
      shown = true;
      _hide?.cancel();
      _hide = Timer(FriendsWatchingCard.showFor, () {
        if (mounted) setState(() => _shown = false);
      });
    }
    if (building || !mounted) {
      _shown = shown;
    } else {
      setState(() => _shown = shown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = _presence?.onChannel(widget.channel) ?? const [];
    final g = context.guide;
    return ExcludeFocus(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _shown && friends.isNotEmpty ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: friends.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 28, 14),
                  decoration: BoxDecoration(
                    color: g.panel.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(g.radius * 2),
                    border: Border.all(color: g.accent, width: 2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    FriendAvatarStack(friends: friends, size: 56),
                    const SizedBox(width: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(watchingTooLabel(friends),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: g.display(30, weight: FontWeight.w700)),
                    ),
                  ]),
                ),
        ),
      ),
    );
  }
}
