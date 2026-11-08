import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/web_admin/widgets/folder_nodes.dart';

/// The web admin's pickers list `library/browse` nodes as the TV does
/// (jellyfin-folder-browse D2, D3).
void main() {
  Map<String, Object?> node(String name, String type, [List<Map<String, Object?>> children = const []]) =>
      {'id': name, 'name': name, 'type': type, 'children': children};

  final extras = node('Extras', 'Folder', [
    for (var i = 1; i <= 3; i++) node('Feature $i', 'Movie'),
    for (var i = 1; i <= 4; i++) node('Trailer $i', 'Video'),
  ]);
  final trailers = node('Trailers', 'Folder', [node('Teaser', 'Video')]);
  final empty = node('Empty', 'Folder');
  final movie = node('Die Hard', 'Movie');

  test('a channel picker lists only movies as videos; a pool picker every video', () {
    expect(shownChildren(extras, programsOnly: true).map((n) => n['name']), ['Feature 1', 'Feature 2', 'Feature 3']);
    expect(shownChildren(extras, programsOnly: false), hasLength(7));
    expect(shownNodes([extras, node('Teaser', 'Video'), movie], programsOnly: true).map((n) => n['name']),
        ['Extras', 'Die Hard']);
  });

  test('counts, opening and details', () {
    expect(nodeDetail(extras, programsOnly: true), '3 inside');
    expect(nodeDetail(extras, programsOnly: false), '7 inside');
    expect(nodeDetail(trailers, programsOnly: true), 'No movies');
    expect(nodeDetail(empty, programsOnly: false), 'Nothing inside');
    expect(nodeDetail(movie, programsOnly: true), 'Movie');
    expect(nodeDetail(node('Teaser', 'Video'), programsOnly: false), 'Video');
    expect(opensNode(extras, programsOnly: true), isTrue);
    expect(opensNode(trailers, programsOnly: true), isFalse);
    expect(opensNode(trailers, programsOnly: false), isTrue);
    expect(opensNode(movie, programsOnly: false), isFalse);
    expect(isVideoNode(movie), isTrue);
  });
}
