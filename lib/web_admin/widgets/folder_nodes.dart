/// The web admin's view of `library/browse` nodes (`{id, name, type,
/// children}`), as the TV's folder picker shows them (jellyfin-folder-browse
/// D2, D3).
library;

import '../../l10n/tr.dart';

/// A movie or another video: picked, never opened.
bool isVideoNode(Map<String, Object?> node) => node['type'] == 'Movie' || node['type'] == 'Video';

List<Map<String, Object?>> _children(Map<String, Object?> node) =>
    (node['children'] as List? ?? const []).cast<Map<String, Object?>>();

/// What a picker lists of [nodes]: with [programsOnly] (channel and block
/// sources), the only videos are movies; otherwise every video (pools).
List<Map<String, Object?>> shownNodes(List<Map<String, Object?>> nodes, {required bool programsOnly}) =>
    [for (final n in nodes) if (!programsOnly || n['type'] != 'Video') n];

/// What [node]'s picker lists inside it.
List<Map<String, Object?>> shownChildren(Map<String, Object?> node, {required bool programsOnly}) =>
    shownNodes(_children(node), programsOnly: programsOnly);

/// Whether [node] opens: a folder with anything the picker lists in it.
bool opensNode(Map<String, Object?> node, {required bool programsOnly}) =>
    !isVideoNode(node) && shownChildren(node, programsOnly: programsOnly).isNotEmpty;

/// What a row says of [node]: a video's kind, or what a folder holds.
String nodeDetail(Map<String, Object?> node, {required bool programsOnly}) {
  if (isVideoNode(node)) return node['type'] == 'Movie' ? 'Movie' : 'Video';
  final shown = shownChildren(node, programsOnly: programsOnly).length;
  if (shown > 0) return tr.inside(shown);
  return _children(node).isEmpty ? tr.nothingInside : tr.noMovies;
}
