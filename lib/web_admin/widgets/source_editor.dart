import 'dart:convert';

import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../channels/channel_generator.dart' show decadeName;
import '../../l10n/generated_names.dart';
import '../../commercials/commercial_pool.dart';
import '../app.dart';
import 'common.dart';
import 'folder_nodes.dart';
import '../../l10n/tr.dart';

/// What a channel or block plays: collections, folders and single movies
/// (dragged from the folder browser, or added with its Add buttons, for
/// keyboard and touch), shows, genres, decades, and every show or movie of
/// them (custom-channels D12, D13; genre-decade-channels D9).
/// The browser lists only movies as videos: nothing else plays as a program.
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

  /// `library/catalog`: shows, genres, video decades and the movie count.
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

  /// The Shows toggle: every show of the picked genres and decades. Picked
  /// shows play only themselves.
  late bool _everyShow = _everyShowOf(_s);

  /// The source this editor last sent; another one comes from outside (a
  /// block following its channel) and sets the Shows toggle again.
  ChannelSource? _sent;

  static bool _everyShowOf(ChannelSource s) => s.includeEpisodes && s.seriesKeys.isEmpty;

  @override
  void didUpdateWidget(SourceEditor old) {
    super.didUpdateWidget(old);
    if (identical(widget.source, old.source) || _sameAsSent(widget.source)) return;
    _everyShow = _everyShowOf(_s);
  }

  /// Whether [s] is what this editor sent, whatever minimum rating the page
  /// kept on it.
  bool _sameAsSent(ChannelSource s) {
    String picks(ChannelSource s) => jsonEncode(s.copyWith(ratingFloor: () => null).toJson());
    return _sent != null && picks(s) == picks(_sent!);
  }

  /// [_s] with these picks: episodes only for picked shows or with Shows
  /// on, so nothing picked means nothing, not "every show". Picking a
  /// genre or decade with Shows and Movies both off turns Shows on.
  void _change(
      {List<String>? shows, List<String>? genres, List<int>? decades, bool? everyShow, bool? movies, List<PoolRoot>? roots}) {
    final keys = shows ?? _s.seriesKeys, g = genres ?? _s.genres, d = decades ?? _s.decades;
    final picked = g.length > _s.genres.length || d.length > _s.decades.length;
    final withMovies = movies ?? _s.includeMovies;
    _everyShow = everyShow ?? (picked && !_everyShow && !withMovies ? true : _everyShow);
    widget.onChanged(_sent = _s.copyWith(
      seriesKeys: keys,
      genres: g,
      decades: d,
      includeEpisodes: keys.isNotEmpty || _everyShow,
      includeMovies: withMovies,
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
          ? tr.collection('${node['name']}')
          : [library['name'] as String, for (final n in [..._path, node]) n['name'] as String].join(' › '),
    );
  }

  /// One row of the browser: a handle to drag, an Add button, and the name,
  /// which opens it when it holds more (or adds it, for a movie).
  Widget _row(PoolRoot root, String name, {VoidCallback? onOpen, String? detail}) {
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
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator, semanticLabel: tr.dragToAdd)),
        ),
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: detail == null ? null : Text(detail),
      onTap: onOpen ?? (added ? null : () => _addRoot(root)),
      trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        TextButton(
          onPressed: added ? null : () => _addRoot(root),
          child: Text(added ? tr.added : tr.add, semanticsLabel: added ? tr.added2(name) : tr.add3(name)),
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
        final nodes = _path.isEmpty
            ? shownNodes(snapshot.data!, programsOnly: true)
            : shownChildren(_path.last, programsOnly: true);
        return ListView(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.arrow_upward),
            title: Text([library['name'] as String, for (final n in _path) n['name'] as String].join(' › '),
                overflow: TextOverflow.ellipsis),
            onTap: () => setState(() => _path.isEmpty ? _library = null : _path.removeLast()),
          ),
          if (nodes.isEmpty) ListTile(contentPadding: EdgeInsets.zero, title: Text(tr.nothingInside2)),
          for (final n in nodes)
            _row(_rootOf(n), n['name'] as String,
                detail: nodeDetail(n, programsOnly: true),
                onOpen: opensNode(n, programsOnly: true) ? () => setState(() => _path.add(n)) : null),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shows = (widget.catalog['shows'] as List).cast<Map<String, Object?>>();
    final genres = (widget.catalog['genres'] as List).cast<String>();
    final decades = {...((widget.catalog['videoDecades'] as List?) ?? const []).cast<int>(), ..._s.decades}.toList()
      ..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(tr.collectionsAndFolders, style: theme.textTheme.labelLarge),
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
              ? Text(tr.dragACollection)
              : Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final r in _s.roots)
                    InputChip(
                      label: Text(widget.missingRoots.contains(r.itemId) ? tr.notFoundOnThe(r.label) : r.label),
                      onDeleted: () => _change(roots: [for (final o in _s.roots) if (o.itemId != r.itemId) o]),
                      deleteButtonTooltipMessage: tr.remove4(r.label),
                    ),
                ]),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(height: 280, child: _browser()),
      const SizedBox(height: 12),
      Text(tr.shows3, style: theme.textTheme.labelLarge),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in shows)
          FilterChip(
            label: Text('${s['name']} (${s['episodes']})'),
            selected: _s.seriesKeys.contains(s['key']),
            onSelected: (on) => _change(shows: _toggled(_s.seriesKeys, s['key'] as String, on)),
          ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 16, children: [
        FilterChip(
          key: const ValueKey('every-show'),
          label: Text(tr.includeShows),
          selected: _everyShow,
          onSelected: (on) => _change(everyShow: on),
        ),
        FilterChip(
          key: const ValueKey('every-movie'),
          label: Text(tr.movies3('${widget.catalog['movies']}')),
          selected: _s.includeMovies,
          onSelected: (on) => _change(movies: on),
        ),
      ]),
      const SizedBox(height: 12),
      Text(tr.genres, style: theme.textTheme.labelLarge),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final g in genres)
          FilterChip(
            label: Text(displayGenre(g)),
            selected: _s.genres.contains(g),
            onSelected: (on) => _change(genres: _toggled(_s.genres, g, on)),
          ),
      ]),
      if (decades.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(tr.decades, style: theme.textTheme.labelLarge),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in decades)
            FilterChip(
              label: Text(decadeName(d)),
              selected: _s.decades.contains(d),
              onSelected: (on) => _change(
                  decades: ({..._s.decades}..removeWhere((v) => !on && v == d)..addAll([if (on) d])).toList()..sort()),
            ),
        ]),
      ],
    ]);
  }
}
