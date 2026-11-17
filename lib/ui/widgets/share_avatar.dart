import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../profiles_screen.dart' show avatarColors;

/// The built-in share profile avatars (share-accounts D6), drawn white on a
/// circle in one of the profile colours. Share profiles store the id, so ids
/// must never be renamed.
const shareAvatarIds = [
  'fox', 'owl', 'cat', 'dog', 'bear', 'rabbit', 'penguin', 'frog', //
  'fish', 'bird', 'turtle', 'whale', 'star', 'moon', 'sun', 'cloud', //
  'rocket', 'ghost', 'robot', 'crown', 'heart', 'leaf', 'flower', 'mountain',
];

class ShareAvatar extends StatelessWidget {
  const ShareAvatar({super.key, required this.avatar, required this.color, this.size = 96});

  final String avatar;

  /// An index into [avatarColors].
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final id = shareAvatarIds.contains(avatar) ? avatar : shareAvatarIds.first;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(color: avatarColors[color % avatarColors.length], shape: BoxShape.circle),
      child: SvgPicture.asset('lib/icons/avatars/$id.svg'),
    );
  }
}
