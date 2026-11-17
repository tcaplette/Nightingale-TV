import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../sharing/share_client.dart';
import 'share_avatar.dart';

/// The friends watching a shared channel (friend-presence D5): up to
/// [shown] overlapping avatars, then a "+n" pill. Used in the guide row, the
/// banner and the player's card. Never focusable, and it doesn't react to
/// the pointer, so the D-pad and hover work around it as before.
class FriendAvatarStack extends StatelessWidget {
  const FriendAvatarStack({super.key, required this.friends, this.size = 40, this.shown = 3});

  final List<ShareProfile> friends;
  final double size;

  /// How many avatars before "+n".
  final int shown;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) return const SizedBox.shrink();
    final faces = friends.take(shown).toList();
    final more = friends.length - faces.length;
    final step = size * 0.62;
    final ring = (size * 0.06).clamp(1.5, 4.0);
    return ExcludeFocus(
      child: IgnorePointer(
        child: Semantics(
          label: joinNames([for (final f in friends) f.name]),
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size + step * (faces.length - 1),
                height: size,
                child: Stack(
                  children: [
                    for (final (i, f) in faces.indexed)
                      Positioned(
                        left: step * i,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: ring),
                          ),
                          child: ShareAvatar(avatar: f.avatar, color: f.avatarColor, size: size - ring * 2),
                        ),
                      ),
                  ],
                ),
              ),
              if (more > 0) ...[
                SizedBox(width: size * 0.12),
                Container(
                  height: size * 0.8,
                  padding: EdgeInsets.symmetric(horizontal: size * 0.22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(size),
                    border: Border.all(color: Colors.white70, width: ring * 0.6),
                  ),
                  child: Text('+$more',
                      style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w800, height: 1)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Tyler is watching", "Tyler and 2 friends are watching" (the guide).
String watchingLabel(List<ShareProfile> friends) => friends.length == 1
    ? tr.presenceIsWatching(friends.first.name)
    : tr.presenceAndOthersWatching(friends.first.name, friends.length - 1);

/// "Tyler is watching too", "Tyler and 2 friends are watching too" (the player).
String watchingTooLabel(List<ShareProfile> friends) => friends.length == 1
    ? tr.presenceWatchingToo(friends.first.name)
    : tr.presenceAndOthersWatchingToo(friends.first.name, friends.length - 1);
