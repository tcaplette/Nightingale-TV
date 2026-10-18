/// One Jellyfin folder in a pool. A whole library is its own top folder
/// ([itemId] == [libraryId]).
class PoolRoot {
  const PoolRoot({required this.itemId, required this.libraryId, required this.label});

  /// The folder's Jellyfin id; everything under it, recursively, is in the pool.
  final String itemId;
  final String libraryId;

  /// Shown in the pool editor, e.g. "Commercials › 80s-2000s-commercial-compilation".
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

/// A named set of Jellyfin folders whose videos fill commercial breaks
/// instead of airing as programs.
class CommercialPool {
  CommercialPool({required this.id, required this.name, this.roots = const []});

  final String id;
  String name;
  List<PoolRoot> roots;

  static const defaultName = 'Commercials';

  /// "Commercials", or "Commercials 2", "Commercials 3", … when taken.
  static String nextName(Iterable<String> taken) {
    final names = {for (final n in taken) n.trim().toLowerCase()};
    if (!names.contains(defaultName.toLowerCase())) return defaultName;
    for (var i = 2;; i++) {
      final candidate = '$defaultName $i';
      if (!names.contains(candidate.toLowerCase())) return candidate;
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'roots': [for (final r in roots) r.toJson()],
      };

  factory CommercialPool.fromJson(Map<String, Object?> j) => CommercialPool(
        id: j['id'] as String,
        name: j['name'] as String? ?? defaultName,
        roots: [for (final r in (j['roots'] as List? ?? const []).cast<Map<String, Object?>>()) PoolRoot.fromJson(r)],
      );
}
