import 'package:flutter/widgets.dart';

import '../channels/channel.dart';
import 'menu_screen.dart' show showMessage;

/// After a content edit of shared copy [ch] (channel-sharing): "This channel
/// won't follow Tyler's changes any more.", when [notice] (taken from
/// `AppState.shareStopNotice` before the edit) says it followed them and the
/// edit took it off them.
Future<void> afterShareEdit(BuildContext context, Channel? ch, String? notice) async {
  if (notice == null || ch == null || !(ch.share?.edited ?? false) || !context.mounted) return;
  await showMessage(context, title: ch.displayName, message: notice);
}
