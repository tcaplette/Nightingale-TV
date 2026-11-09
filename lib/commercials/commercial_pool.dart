export '../library/pool_root.dart';

import '../library/pool_root.dart';
import '../l10n/tr.dart';

/// What a pool's clips are for: filling breaks, or framing them.
enum PoolKind {
  commercials,
  bumpers;

  String get label => switch (this) {
        commercials => tr.commercials,
        bumpers => tr.bumpers,
      };
}

/// A named set of Jellyfin folders whose videos fill commercial breaks
/// instead of airing as programs.
class CommercialPool {
  CommercialPool({required this.id, required this.name, this.roots = const [], this.kind = PoolKind.commercials});

  final String id;
  String name;
  List<PoolRoot> roots;
  PoolKind kind;

  static String get defaultName => tr.commercials;

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
        if (kind != PoolKind.commercials) 'kind': kind.name,
      };

  /// A missing or unknown `kind` loads as commercials.
  factory CommercialPool.fromJson(Map<String, Object?> j) => CommercialPool(
        id: j['id'] as String,
        name: j['name'] as String? ?? defaultName,
        roots: [for (final r in (j['roots'] as List? ?? const []).cast<Map<String, Object?>>()) PoolRoot.fromJson(r)],
        kind: PoolKind.values.asNameMap()[j['kind']] ?? PoolKind.commercials,
      );
}
