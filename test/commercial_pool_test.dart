import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';

void main() {
  test('new pools are named Commercials, then Commercials 2, 3, …', () {
    expect(CommercialPool.nextName(const []), 'Commercials');
    expect(CommercialPool.nextName(const ['Bumpers']), 'Commercials');
    expect(CommercialPool.nextName(const ['Commercials']), 'Commercials 2');
    expect(CommercialPool.nextName(const ['commercials ', 'Commercials 2']), 'Commercials 3');
    expect(CommercialPool.nextName(const ['Commercials', 'Commercials 3']), 'Commercials 2');
  });

  test('pools round-trip through JSON', () {
    final pool = CommercialPool(id: 'p1', name: 'Bumpers', roots: const [
      PoolRoot(itemId: 'lib', libraryId: 'lib', label: 'Commercials'),
      PoolRoot(itemId: 'folder', libraryId: 'movies', label: 'Movies › Trailers'),
    ]);
    final copy = CommercialPool.fromJson(pool.toJson());
    expect(copy.id, 'p1');
    expect(copy.name, 'Bumpers');
    expect(copy.roots, pool.roots);
    expect(copy.roots.first.isWholeLibrary, isTrue);
    expect(copy.roots.last.isWholeLibrary, isFalse);
    expect(copy.kind, PoolKind.commercials);
  });

  test('a pool\'s type: saved only for bumpers, and anything else loads as commercials', () {
    final plain = CommercialPool(id: 'p', name: 'Ads');
    expect(plain.toJson().containsKey('kind'), isFalse);
    final marked = CommercialPool(id: 'p', name: 'Idents', kind: PoolKind.bumpers);
    expect(marked.toJson()['kind'], 'bumpers');
    expect(CommercialPool.fromJson(marked.toJson()).kind, PoolKind.bumpers);
    expect(CommercialPool.fromJson({'id': 'p', 'name': 'Old'}).kind, PoolKind.commercials);
    expect(CommercialPool.fromJson({'id': 'p', 'kind': 'idents'}).kind, PoolKind.commercials);
  });
}
