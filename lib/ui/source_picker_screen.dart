import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../channels/channel.dart';
import '../channels/channel_generator.dart';
import '../commercials/commercial_pool.dart';
import '../library/library_index.dart';
import '../theme/tv_theme.dart';
import 'folder_picker_screen.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// "Plays 80s Sitcoms (collection), Cheers and every comedy movie.": each
/// pick of [source], in one line.
String describeSource(ChannelSource source, LibraryIndex library) {
  final genres = [for (final g in source.genres) g.toLowerCase()];
  final genreText = genres.length <= 1 ? genres.join() : '${genres.sublist(0, genres.length - 1).join(', ')} or ${genres.last}';
  final picks = [
    for (final r in source.roots) r.label.split(' › ').last,
    for (final key in source.seriesKeys) library.seriesByKey[key]?.name ?? key.split('|').first,
    // With shows picked, genres only narrow down movies.
    if (source.includeEpisodes && source.seriesKeys.isEmpty && genres.isNotEmpty) 'every $genreText show',
    if (source.includeMovies) genres.isEmpty ? 'every movie' : 'every $genreText movie',
  ];
  if (picks.isEmpty) return 'Pick something to play.';
  final last = picks.removeLast();
  return 'Plays ${picks.isEmpty ? last : '${picks.join(', ')} and $last'}.';
}

/// Pick what a channel or block plays: collections and folders, shows,
/// genres and movies (custom-channels D12). Pops with the new
/// [ChannelSource], or nothing on ESC.
///
/// With [onDone] (a channel being made or edited) Done calls it instead, and
/// shows the problem it answers, if any; [name] and [order] add those
/// controls, and it pops itself when it's done.
class SourcePickerScreen extends StatefulWidget {
  const SourcePickerScreen({
    super.key,
    required this.initial,
    this.title = 'Choose shows & movies',
    this.name,
    this.order,
    this.onDone,
  });

  final ChannelSource initial;
  final String title;

  /// A new channel's name field starts with this.
  final String? name;

  /// A new channel's order buttons start with this.
  final PlaybackOrder? order;
  final Future<String?> Function(ChannelSource source, String name, PlaybackOrder order)? onDone;

  @override
  State<SourcePickerScreen> createState() => _SourcePickerScreenState();
}

class _SourcePickerScreenState extends State<SourcePickerScreen> {
  late final Set<String> _shows = {...widget.initial.seriesKeys};
  late final Set<String> _genres = {...widget.initial.genres};
  late bool _movies = widget.initial.includeMovies;
  late List<PoolRoot> _roots = [...widget.initial.roots];
  late PlaybackOrder _order = widget.order ?? PlaybackOrder.random;
  late final _name = TextEditingController(text: widget.name);
  String? _error;
  bool _busy = false;
  final _addNode = FocusNode(debugLabel: 'add roots');
  final _doneNode = FocusNode(debugLabel: 'done');

  @override
  void dispose() {
    _name.dispose();
    _addNode.dispose();
    _doneNode.dispose();
    super.dispose();
  }

  ChannelSource get _source => ChannelSource(
        seriesKeys: _shows.toList()..sort(),
        genres: _genres.toList()..sort(),
        // Nothing picked means nothing, not "every show".
        includeEpisodes: _shows.isNotEmpty || _genres.isNotEmpty,
        includeMovies: _movies,
        roots: _roots,
      );

  /// Focuses [node] after this change's frame: the row or button that had
  /// focus is gone.
  void _focusAfterBuild(FocusNode node) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) node.requestFocus();
      });

  Future<void> _addRoots() async {
    final app = AppScope.read(context);
    final roots = await Navigator.of(context).push<List<PoolRoot>>(
      MaterialPageRoute(builder: (_) => FolderPickerScreen(initial: _roots, forChannel: true)),
    );
    if (roots == null || !mounted) return;
    setState(() => _roots = roots);
    // The count fills in without waiting for a scan.
    await app.resolveRoots(roots);
    if (mounted) setState(() {});
  }

  Future<void> _done() async {
    final onDone = widget.onDone;
    if (onDone == null) {
      Navigator.of(context).pop(_source);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem = await onDone(_source, _name.text, _order);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final library = app.library;
    final series = [...library.series]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final genres = {
      for (final s in library.series) ...s.genres.map(normalizeGenre),
      for (final m in library.movies) ...m.genres.map(normalizeGenre),
    }.toList()
      ..sort();
    final count = buildPlaylist(library, _source, PlaybackOrder.cyclic, seed: 0).length;
    final layout = ScreenLayout.of(context);

    final shows = [
      Text('SHOWS', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 12),
      for (final (i, s) in series.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CheckRow(
            autofocus: i == 0 && widget.name == null,
            label: s.year == null ? s.name : '${s.name} (${s.year})',
            detail: '${library.episodesBySeries[s.key]?.length ?? 0} episodes',
            on: _shows.contains(s.key),
            onPressed: () => setState(() {
              if (!_shows.remove(s.key)) _shows.add(s.key);
            }),
          ),
        ),
    ];
    // Each part is one list item, keyed inside, so a line appearing doesn't
    // rebuild the buttons after it and lose their focus.
    final summary = <Widget>[
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.name != null) ...[
        TvTextField(controller: _name, label: 'Channel name', autofocus: true),
        const SizedBox(height: 24),
      ],
      Text('$count programs', style: g.display(44, weight: FontWeight.w800)),
      Text(describeSource(_source, library), style: g.body(24, color: g.textDim)),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: g.body(26, weight: FontWeight.w600, color: g.nowLine)),
      ],
      const SizedBox(height: 24),
      Wrap(
        key: const ValueKey('actions'),
        spacing: 16,
        runSpacing: 16,
        children: [
          TvButton(
              label: _busy ? 'Saving…' : 'Done',
              icon: Icons.check,
              focusNode: _doneNode,
              autofocus: widget.name == null && series.isEmpty,
              onPressed: _busy ? null : _done),
          if (_shows.isNotEmpty || _genres.isNotEmpty || _movies || _roots.isNotEmpty)
            TvButton(
              label: 'Clear',
              onPressed: () {
                setState(() {
                  _shows.clear();
                  _genres.clear();
                  _movies = false;
                  _roots = [];
                });
                _focusAfterBuild(_doneNode);
              },
            ),
        ],
      ),
      if (widget.order != null) ...[
        const SizedBox(height: 32, key: ValueKey('order')),
        Text('PLAY ORDER', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final order in PlaybackOrder.values)
              TvToggle(
                label: order.label,
                radio: true,
                on: _order == order,
                onPressed: () => setState(() => _order = order),
              ),
          ],
        ),
      ],
      ]),
    ];
    final roots = <Widget>[
      Text('COLLECTIONS & FOLDERS', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in _roots)
        Padding(
          key: ValueKey('root ${r.itemId}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: _CheckRow(
            label: app.rootLabel(r),
            detail: app.rootMissing(r) ? 'Not found on the server' : null,
            on: true,
            onPressed: () {
              setState(() => _roots = [for (final o in _roots) if (o.itemId != r.itemId) o]);
              _focusAfterBuild(_addNode);
            },
          ),
        ),
      Align(
        key: const ValueKey('add'),
        alignment: Alignment.centerLeft,
        child: TvButton(label: 'Add…', icon: Icons.create_new_folder, focusNode: _addNode, onPressed: _addRoots),
      ),
      ]),
    ];
    final moviesAndGenres = [
      _CheckRow(
        label: 'Include movies',
        on: _movies,
        onPressed: () => setState(() => _movies = !_movies),
      ),
      const SizedBox(height: 32),
      Text('GENRES', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 6),
      Text('Used when no shows are picked. Also narrows down movies.',
          style: g.body(22, color: g.textDim)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final genre in genres)
            TvToggle(
              label: genre,
              on: _genres.contains(genre),
              onPressed: () => setState(() {
                if (!_genres.remove(genre)) _genres.add(genre);
              }),
            ),
        ],
      ),
    ];

    return TvPage(
      title: widget.title,
      hints: '▲▼◀▶ Move    OK Toggle    ESC Cancel',
      onBack: () => Navigator.of(context).pop(),
      // Upright, one list: the count and Done, the collections, the shows,
      // then movies and genres.
      child: layout.isPortrait
          ? FocusTraversalGroup(
              child: ListView(
                padding: layout.pagePadding(EdgeInsets.zero),
                children: [
                  ...summary,
                  const SizedBox(height: 32),
                  ...roots,
                  const SizedBox(height: 32),
                  ...shows,
                  const SizedBox(height: 32),
                  ...moviesAndGenres,
                ],
              ),
            )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FocusTraversalGroup(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(100, 32, 24, 32),
                children: shows,
              ),
            ),
          ),
          SizedBox(
            width: 720,
            child: FocusTraversalGroup(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 100, 32),
                children: [
                  ...summary,
                  const SizedBox(height: 32),
                  ...roots,
                  const SizedBox(height: 32),
                  ...moviesAndGenres,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.on, required this.onPressed, this.detail, this.autofocus = false});

  final String label;
  final String? detail;
  final bool on;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: focused ? g.cellBorder : g.cell,
          borderRadius: BorderRadius.circular(g.radius),
          border: Border.all(color: focused ? g.focus : Colors.transparent, width: 4),
        ),
        child: Row(
          children: [
            Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
                size: 36, color: on ? g.accent : g.textDim),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(30, weight: FontWeight.w600)),
            ),
            if (detail != null) Text(detail!, style: g.body(22, color: g.textDim)),
          ],
        ),
      ),
    );
  }
}
