/// A server-side root: a whole library, a folder, a show, a season or a
/// collection, by id, with a label and never a server path. Commercial pools
/// and channel and block sources ([ChannelSource.roots]) both use it. A
/// whole library is its own top folder ([itemId] == [libraryId]).
class PoolRoot {
  const PoolRoot({required this.itemId, required this.libraryId, required this.label});

  /// The root's server id; everything under it, recursively, belongs to it.
  final String itemId;
  final String libraryId;

  /// Shown in the pool and source editors, e.g. "Commercials › 80s-2000s-commercial-compilation".
  /// Never a server file-system path.
  final String label;

  bool get isWholeLibrary => itemId == libraryId;

  PoolRoot withLabel(String l) => PoolRoot(itemId: itemId, libraryId: libraryId, label: l);

  Map<String, Object?> toJson() => {'itemId': itemId, 'libraryId': libraryId, 'label': label};

  factory PoolRoot.fromJson(Map<String, Object?> j) => PoolRoot(
        itemId: j['itemId'] as String,
        libraryId: j['libraryId'] as String? ?? j['itemId'] as String,
        label: j['label'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is PoolRoot && other.itemId == itemId && other.libraryId == libraryId && other.label == label;

  @override
  int get hashCode => Object.hash(itemId, libraryId, label);
}

