import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../commercials/commercial_pool.dart';
import '../app.dart';
import 'common.dart';

/// What a channel or block plays: collections and folders (dragged from the
/// folder browser, or added with its Add buttons, for keyboard and touch),
/// shows, genres and movies (custom-channels D12, D13).
class SourceEditor extends StatefulWidget {
  const SourceEditor({
    super.key,
    required this.profileId,
    required this.source,
    required this.catalog,
    required this.onChanged,
    this.missingRoots = const {},
  });

  final String profileId;
  final ChannelSource source;

  /// `library/catalog`: shows, genres and the movie count.
  final Map<String, Object?> catalog;
  final ValueChanged<ChannelSource> onChanged;

  /// Roots the server no longer has.
  final Set<String> missingRoots;

  @override
  State<SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<SourceEditor> {
  /// The library being browsed, and the folders opened in it.
  Map<String, Object?>? _library;
  final _path = <Map<String, Object?>>[];
  final _trees = <String, Future<List<Map<String, Object?>>>>{};
  late final Future<List<Object?>> _libraries = _loadLibraries();

  String get _browse => 'profiles/${widget.profileId}/library/browse';

  Future<List<Object?>> _loadLibraries() async => (await context.api.get(_browse))! as List<Object?>;

  Future<List<Map<String, Object?>>> _tree(String library) => _trees.putIfAbsent(
      library, () async => ((await context.api.get(_browse, {'library': library}))! as List).cast<Map<String, Object?>>());

  ChannelSource get _s => widget.source;

  /// [_s] with these picks: episodes only when shows or genres are picked,
  /// so nothing picked means nothing, not "every show".
  void _change({List<String>? shows, List<String>? genres, bool? movies, List<PoolRoot>? roots}) {
    final keys = shows ?? _s.seriesKeys, g = genres ?? _s.genres;
    widget.onChanged(ChannelSource(
      seriesKeys: keys,
      genres: g,
      includeEpisodes: keys.isNotEmpty || g.isNotEmpty,
      includeMovies: movies ?? _s.includeMovies,
      roots: roots ?? _s.roots,
    ));
  }

  void _addRoot(PoolRoot root) {
    if (_s.roots.any((r) => r.itemId == root.itemId)) return;
    _change(roots: [..._s.roots, root]);
  }

  List<String> _toggled(List<String> list, String value, bool on) =>
      ({...list}..removeWhere((v) => !on && v == value)..addAll([if (on) value])).toList()..sort();

  PoolRoot _rootOf(Map<String, Object?> node) {
    final library = _library!;
    return PoolRoot(
      itemId: node['id'] as String,
      libraryId: library['id'] as String,
      label: node['type'] == 'BoxSet'
          ? '${node['name']} (collection)'
          : [library['name'] as String, for (final n in [..._path, node]) n['name'] as String].join(' › '),
    );
  }

  /// One row of the browser: a handle to drag, an Add button, and the name,
  /// which opens it when it holds more.
  Widget _row(PoolRoot root, String name, {VoidCallback? onOpen}) {
    final added = _s.roots.any((r) => r.itemId == root.itemId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Draggable<PoolRoot>(
        data: root,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Padding(padding: const EdgeInsets.all(12), child: Text(name)),
        ),
        child: const MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator, semanticLabel: 'Drag to add')),
        ),
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      onTap: onOpen,
      trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        TextButton(
          onPressed: added ? null : () => _addRoot(root),
          child: Text(added ? 'Added' : 'Add', semanticsLabel: added ? '$name added' : 'Add $name'),
        ),
        if (onOpen != null) const Icon(Icons.chevron_right),
      ]),
    );
  }

  Widget _browser() {
    final library = _library;
    if (library == null) {
      return FutureBuilder<List<Object?>>(
        future: _libraries,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorText('${snapshot.error}');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(children: [
            for (final l in snapshot.data!.cast<Map<String, Object?>>())
              _row(PoolRoot(itemId: l['id'] as String, libraryId: l['id'] as String, label: l['name'] as String),
                  l['name'] as String,
                  onOpen: () => setState(() => _library = l)),
          ]);
        },
      );
    }
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _tree(library['id'] as String),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorText('${snapshot.error}');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final nodes = _path.isEmpty ? snapshot.data! : (_path.last['children'] as List).cast<Map<String, Object?>>();
        return ListView(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.arrow_upward),
            title: Text([library['name'] as String, for (final n in _path) n['name'] as String].join(' › '),
                overflow: TextOverflow.ellipsis),
            onTap: () => setState(() => _path.isEmpty ? _library = null : _path.removeLast()),
          ),
          for (final n in nodes)
            _row(_rootOf(n), n['name'] as String,
                onOpen: (n['children'] as List).isEmpty ? null : () => setState(() => _path.add(n))),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shows = (widget.catalog['shows'] as List).cast<Map<String, Object?>>();
    final genres = (widget.catalog['genres'] as List).cast<String>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Collections and folders', style: theme.textTheme.labelLarge),
      const SizedBox(height: 6),
      DragTarget<PoolRoot>(
        onAcceptWithDetails: (d) => _addRoot(d.data),
        builder: (context, candidates, _) => Container(
          key: const ValueKey('source-drop'),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: candidates.isEmpty ? theme.dividerColor : theme.colorScheme.primary, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _s.roots.isEmpty
              ? const Text('Drag a collection or folder here, or use its Add button.')
              : Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final r in _s.roots)
                    InputChip(
                      label: Text(widget.missingRoots.contains(r.itemId) ? '${r.label} · Not found on the server' : r.label),
                      onDeleted: () => _change(roots: [for (final o in _s.roots) if (o.itemId != r.itemId) o]),
                      deleteButtonTooltipMessage: 'Remove ${r.label}',
                    ),
                ]),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(height: 280, child: _browser()),
      const SizedBox(height: 12),
      Text('Shows', style: theme.textTheme.labelLarge),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in shows)
          FilterChip(
            label: Text('${s['name']} (${s['episodes']})'),
            selected: _s.seriesKeys.contains(s['key']),
            onSelected: (on) => _change(shows: _toggled(_s.seriesKeys, s['key'] as String, on)),
          ),
      ]),
      const SizedBox(height: 12),
      Text('Genres', style: theme.textTheme.labelLarge),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final g in genres)
          FilterChip(
            label: Text(g),
            selected: _s.genres.contains(g),
            onSelected: (on) => _change(genres: _toggled(_s.genres, g, on)),
          ),
      ]),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Movies (${widget.catalog['movies']})'),
        value: _s.includeMovies,
        onChanged: (v) => _change(movies: v ?? false),
      ),
    ]);
  }
}
