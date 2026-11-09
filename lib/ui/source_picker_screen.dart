import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../channels/channel.dart';
import '../channels/channel_generator.dart';
import '../commercials/commercial_pool.dart';
import '../l10n/generated_names.dart';
import '../library/library_index.dart';
import '../theme/tv_theme.dart';
import 'folder_picker_screen.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// "Plays 80s Sitcoms (collection), Cheers and every 80s or 90s comedy
/// movie.": each pick of [source], in one line.
String describeSource(ChannelSource source, LibraryIndex library) {
  String either(List<String> words) =>
      words.length <= 1 ? words.join() : tr.or(words.sublist(0, words.length - 1).join(', '), words.last);
  final genres = [for (final g in source.genres) displayGenre(g).toLowerCase()];
  final decades = [for (final d in [...source.decades]..sort()) decadeName(d)];
  final kind = [if (decades.isNotEmpty) either(decades), if (genres.isNotEmpty) either(genres)].join(' ');
  final picks = [
    for (final r in source.roots) r.label.split(' › ').last,
    for (final key in source.seriesKeys) library.seriesByKey[key]?.name ?? key.split('|').first,
    // With shows picked, genres only narrow down movies; roots alone with
    // no genre or decade add no shows (custom-channels D2).
    if (source.includeEpisodes && source.seriesKeys.isEmpty && (source.roots.isEmpty || kind.isNotEmpty))
      kind.isEmpty ? tr.everyShow2 : tr.everyShow(kind),
    if (source.includeMovies) kind.isEmpty ? tr.everyMovie2 : tr.everyMovie(kind),
  ];
  if (picks.isEmpty) return tr.pickSomethingTo;
  final last = picks.removeLast();
  return tr.playsList(picks.isEmpty ? last : tr.and(picks.join(', '), last));
}

/// Whether a saved [source] plays every show of its genres and decades:
/// the editors' Shows toggle (genre-decade-channels D9). Picked shows play
/// only themselves.
bool playsEveryShow(ChannelSource source) => source.includeEpisodes && source.seriesKeys.isEmpty;

/// Pick what a channel or block plays: collections and folders, shows,
/// genres, decades, and every show or movie of them (custom-channels D12). Pops with the new
/// [ChannelSource], or nothing on ESC.
///
/// With [onDone] (a channel being made or edited) Done calls it instead, and
/// shows the problem it answers, if any; [name] and [order] add those
/// controls, and it pops itself when it's done.
class SourcePickerScreen extends StatefulWidget {
  const SourcePickerScreen({
    super.key,
    required this.initial,
    this.title,
    this.name,
    this.order,
    this.onDone,
  });

  final ChannelSource initial;
  final String? title;

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
  late final Set<int> _decades = {...widget.initial.decades};
  late bool _everyShow = playsEveryShow(widget.initial);
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
        decades: _decades.toList()..sort(),
        // Nothing picked means nothing, not "every show".
        includeEpisodes: _shows.isNotEmpty || _everyShow,
        includeMovies: _movies,
        roots: _roots,
        ratingFloor: widget.initial.ratingFloor,
      );

  /// Picking a genre or decade with Shows and Movies both off turns Shows
  /// on, so the pick plays something.
  void _picked(bool on) {
    if (on && !_everyShow && !_movies) _everyShow = true;
  }

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
      for (final s in library.series) ...titleGenres(s.genres),
      for (final m in library.movies) ...titleGenres(m.genres),
    }.toList()
      ..sort();
    final decades = {
      for (final m in library.movies) ?decadeOf(m.year),
      for (final e in library.episodes) ?itemDecade(library, e),
      ..._decades,
    }.toList()
      ..sort();
    final count = buildPlaylist(library, _source, PlaybackOrder.cyclic, seed: 0).length;
    final layout = ScreenLayout.of(context);

    final shows = [
      Text(tr.shows2, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 12),
      for (final (i, s) in series.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CheckRow(
            autofocus: i == 0 && widget.name == null,
            label: s.year == null ? s.name : '${s.name} (${s.year})',
            detail: tr.episodes(library.episodesBySeries[s.key]?.length ?? 0),
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
        TvTextField(controller: _name, label: tr.channelName, autofocus: true),
        const SizedBox(height: 24),
      ],
      Text(tr.programs(count), style: g.display(44, weight: FontWeight.w800)),
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
              label: _busy ? tr.saving : tr.done,
              icon: Icons.check,
              focusNode: _doneNode,
              autofocus: widget.name == null && series.isEmpty,
              onPressed: _busy ? null : _done),
          if (_shows.isNotEmpty || _genres.isNotEmpty || _decades.isNotEmpty || _everyShow || _movies || _roots.isNotEmpty)
            TvButton(
              label: tr.clear,
              onPressed: () {
                setState(() {
                  _shows.clear();
                  _genres.clear();
                  _decades.clear();
                  _everyShow = false;
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
        Text(tr.playOrder, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
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
      Text(tr.collectionsFolders, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in _roots)
        Padding(
          key: ValueKey('root ${r.itemId}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: _CheckRow(
            label: app.rootLabel(r),
            detail: app.rootMissing(r) ? tr.notFoundOn : null,
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
        child: TvButton(label: tr.add2, icon: Icons.create_new_folder, focusNode: _addNode, onPressed: _addRoots),
      ),
      ]),
    ];
    final moviesAndGenres = [
      // Shows and Movies side by side, chosen the same way
      // (genre-decade-channels D9).
      Wrap(
        key: const ValueKey('kinds'),
        spacing: 12,
        runSpacing: 12,
        children: [
          TvToggle(
            label: tr.includeShows,
            on: _everyShow,
            onPressed: () => setState(() => _everyShow = !_everyShow),
          ),
          TvToggle(
            label: tr.includeMovies,
            on: _movies,
            onPressed: () => setState(() => _movies = !_movies),
          ),
        ],
      ),
      const SizedBox(height: 32),
      Text(tr.genres2, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 6),
      Text(tr.usedWhenNo,
          style: g.body(22, color: g.textDim)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final genre in genres)
            TvToggle(
              label: displayGenre(genre),
              on: _genres.contains(genre),
              onPressed: () => setState(() {
                final on = !_genres.remove(genre);
                if (on) _genres.add(genre);
                _picked(on);
              }),
            ),
        ],
      ),
      if (decades.isNotEmpty) ...[
        const SizedBox(height: 32),
        Text(tr.decadesHeading, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 12),
        Wrap(
          key: const ValueKey('decades'),
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final d in decades)
              TvToggle(
                label: decadeName(d),
                on: _decades.contains(d),
                onPressed: () => setState(() {
                  final on = !_decades.remove(d);
                  if (on) _decades.add(d);
                  _picked(on);
                }),
              ),
          ],
        ),
      ],
    ];

    return TvPage(
      title: widget.title ?? tr.chooseShowsMovies,
      hints: tr.moveOkToggle,
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
