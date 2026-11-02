import '../library/library_index.dart';
import 'channel.dart';
import 'program_block.dart';

/// Saved show keys mapped to the keys of a new index (lineup-dedup D3): the
/// shows a scan merged keep their channels, sources and block lineups.
class ShowKeyRemap {
  ShowKeyRemap(this.library, {this.previous});

  /// The index the keys should be in.
  final LibraryIndex library;

  /// The index the keys were saved against, when known: its episodes say
  /// where each old show went.
  final LibraryIndex? previous;

  final _resolved = <String, String?>{};

  /// [key]'s show in [library], or null when it doesn't resolve (a removed
  /// show). Resolves by the show's episodes in [previous], else as an item
  /// named like the key would match ([ShowIdentity]).
  String? resolve(String key) => _resolved.putIfAbsent(key, () => _resolve(key));

  /// [key] mapped, or [key] itself when it doesn't resolve. Anything that
  /// isn't a show key (a movie id) is left alone.
  String map(String key) => key.contains('|') ? resolve(key) ?? key : key;

  String? _resolve(String key) {
    if (library.seriesByKey.containsKey(key)) return key;
    final votes = <String, int>{};
    for (final e in previous?.episodesBySeries[key] ?? const <MediaEntry>[]) {
      if (library[library.primaryIdOf(e.id)]?.seriesKey case final k?) votes[k] = (votes[k] ?? 0) + 1;
    }
    if (votes.isNotEmpty) return (votes.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final bar = key.lastIndexOf('|');
    if (bar < 0) return null;
    final saved = previous?.seriesByKey[key];
    final identity = ShowIdentity.of(saved?.name ?? key.substring(0, bar), year: int.tryParse(key.substring(bar + 1)));
    final named = [
      for (final s in library.series)
        if (s.key.substring(0, s.key.lastIndexOf('|')) == identity.key) s,
    ];
    final year = identity.year;
    if (year != null) {
      final exact = named.where((s) => s.year == year);
      if (exact.length == 1) return exact.single.key;
      final yearless = named.where((s) => s.year == null);
      return yearless.length == 1 ? yearless.single.key : null;
    }
    // A yearless key matching shows of several years is ambiguous.
    return named.length == 1 ? named.single.key : null;
  }

  /// Rewrites the show keys in [channels]' and [blocks]' sources and in the
  /// blocks' lineups. Returns the generated show channels whose id is now
  /// another (`auto:show:<old>` → `auto:show:<new>`), by old id; the caller
  /// renames them, or merges them into a channel that already has the id.
  Map<String, String> apply(List<Channel> channels, List<ProgramBlock> blocks) {
    List<String> mapAll(List<String> keys) => {for (final k in keys) map(k)}.toList();
    ChannelSource mapped(ChannelSource s) => s.seriesKeys.isEmpty && s.excluded.isEmpty
        ? s
        : s.copyWith(seriesKeys: mapAll(s.seriesKeys), excluded: mapAll(s.excluded));
    final renames = <String, String>{};
    for (final c in channels) {
      if (c.isLive) continue;
      c.source = mapped(c.source);
      const prefix = 'auto:show:';
      if (c.auto && c.id.startsWith(prefix)) {
        final key = map(c.id.substring(prefix.length));
        if ('$prefix$key' != c.id) renames[c.id] = '$prefix$key';
      }
    }
    for (final b in blocks) {
      b.source = mapped(b.source);
      if (b.lineup.any((s) => map(s.seriesKey) != s.seriesKey)) {
        b.lineup = [for (final s in b.lineup) LineupSlot(seriesKey: map(s.seriesKey), count: s.count)];
      }
    }
    return renames;
  }
}
