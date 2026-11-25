import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../theme/tv_theme.dart';
import '../../server/smb/smb_library.dart';
import 'tv_focus.dart';

/// What a folder type is called.
String folderTypeLabel(SmbFolderType? t) => switch (t) {
      null => tr.smbTypeNone,
      SmbFolderType.tvShows => tr.smbTypeTv,
      SmbFolderType.movies => tr.smbTypeMovies,
      SmbFolderType.music => tr.smbTypeMusic,
      SmbFolderType.musicVideos => tr.smbTypeMusicVideos,
      SmbFolderType.homeVideos => tr.smbTypeHome,
      SmbFolderType.commercials => tr.smbTypeCommercials,
      SmbFolderType.bumpers => tr.smbTypeBumpers,
    };

/// A folder on the mapping step: its name opens it; its type button steps
/// through the types (D-pad, air mouse and touch alike).
class FolderMapRow extends StatelessWidget {
  const FolderMapRow(
      {super.key,
      required this.name,
      required this.type,
      required this.inherited,
      required this.onType,
      this.onOpen,
      this.autofocus = false});

  final String name;
  final SmbFolderType? type;

  /// The type of the mapped folder around it.
  final SmbFolderType? inherited;
  final void Function(SmbFolderType?) onType;
  final VoidCallback? onOpen;
  final bool autofocus;

  static const _order = [null, ...SmbFolderType.values];

  /// The narrowest row with the name and the type side by side.
  static const _sideBySide = 720.0;

  @override
  Widget build(BuildContext context) {
    final shown = type ?? inherited;
    // The type around it is what it has with none of its own.
    var next = _order[(_order.indexOf(type) + 1) % _order.length];
    if (next != null && next == inherited) next = _order[(_order.indexOf(next) + 1) % _order.length];
    final open = TvButton(label: name, icon: Icons.folder, expand: true, autofocus: autofocus, onPressed: onOpen);
    final pick = TvButton(
      key: ValueKey('type-$name'),
      label: type == null && inherited != null ? tr.smbAsAbove(folderTypeLabel(inherited)) : folderTypeLabel(shown),
      icon: shown == null ? Icons.remove_circle_outline : Icons.check_circle,
      expand: true,
      onPressed: () => onType(next),
    );
    // Too narrow for both side by side (a phone upright): the type under
    // the name, so neither is cut short.
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < _sideBySide
          // One card per folder, so its type reads as its own.
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: context.guide.cell,
                borderRadius: BorderRadius.circular(context.guide.radius * 2),
                border: Border.all(color: context.guide.cellBorder, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [open, const SizedBox(height: 8), pick]),
              ),
            )
          : Row(
              children: [
                Expanded(flex: 3, child: open),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: pick),
              ],
            ),
    );
  }
}

