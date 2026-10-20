import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../commercials/commercial_pool.dart';
import '../jellyfin/jellyfin_client.dart';
import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';

/// Pick the Jellyfin folders a pool draws from: libraries on the left, the
/// folders of the opened library (or folder) on the right.
///
/// Keys: ▲▼ move, OK ticks a folder, ▶ opens it, ◀ / ESC go back up. With a
/// pointer, the checkbox ticks and the name opens. Pops with the picked
/// folders on Done, or nothing (no change) on ESC from the libraries.
///
/// Only what any signed-in user can see is listed: libraries, and the
/// folders, shows, seasons and collections in them. No server paths.
class FolderPickerScreen extends StatefulWidget {
  const FolderPickerScreen({super.key, required this.initial, this.poolName});

  final List<PoolRoot> initial;
  final String? poolName;

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  late final Map<String, PoolRoot> _picked = {for (final r in widget.initial) r.itemId: r};
  late Future<List<JellyfinLibrary>> _libraries;
  final _trees = <String, Future<List<FolderNode>>>{};

  JellyfinLibrary? _library;

  /// Folders opened inside [_library], outermost first.
  final _path = <FolderNode>[];
  bool _inFolders = false;

  final _nodes = <String, FocusNode>{};
  FocusNode _nodeFor(String key) => _nodes.putIfAbsent(key, () => FocusNode(debugLabel: key));

  @override
  void initState() {
    super.initState();
    _libraries = _loadLibraries();
  }

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<List<JellyfinLibrary>> _loadLibraries() async {
    final client = AppScope.read(context).client;
    if (client == null) throw JellyfinException('Not signed in.');
    final libraries = (await client.libraries()).where((l) => l.isVideo).toList();
    if (libraries.isNotEmpty) _focusWhenBuilt(_nodeFor('lib:${libraries.first.id}'), onlyIfIdle: true);
    return libraries;
  }

  /// The page takes focus while things load, so autofocus on what's built
  /// later never happens: focus [node] once it's in the tree. With
  /// [onlyIfIdle], only if nothing but the page has focus by then.
  void _focusWhenBuilt(FocusNode node, {bool onlyIfIdle = false, int framesLeft = 30}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || node.hasFocus || framesLeft == 0) return;
      if (node.context == null) {
        _focusWhenBuilt(node, onlyIfIdle: onlyIfIdle, framesLeft: framesLeft - 1);
        return;
      }
      final current = FocusManager.instance.primaryFocus;
      final idle = current == null || current is FocusScopeNode || isTvPageFocus(current);
      if (!onlyIfIdle || idle) node.requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<List<FolderNode>> _treeOf(JellyfinLibrary lib) => _trees.putIfAbsent(lib.id, () async {
        final client = AppScope.read(context).client;
        if (client == null) throw JellyfinException('Not signed in.');
        return client.folderTree(lib.id);
      });

  void _retry() => setState(() {
        _libraries = _loadLibraries();
        _trees.clear();
      });

  String _label(JellyfinLibrary lib, [List<FolderNode> path = const []]) =>
      [lib.name, for (final n in path) n.name].join(' › ');

  void _toggle(String itemId, PoolRoot Function() root) => setState(() {
        if (_picked.remove(itemId) == null) _picked[itemId] = root();
      });

  /// Shows [lib]'s folders, focusing the first.
  void _openLibrary(JellyfinLibrary lib) {
    setState(() {
      _library = lib;
      _path.clear();
    });
    _focusFirstFolder();
  }

  void _openFolder(FolderNode node) {
    if (node.children.isEmpty) return;
    setState(() => _path.add(node));
    _focusFirstFolder();
  }

  void _focusFirstFolder() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lib = _library;
      if (!mounted || lib == null) return;
      final folders = _path.isEmpty ? await _treeOf(lib) : _path.last.children;
      if (!mounted) return;
      _focusWhenBuilt(folders.isNotEmpty ? _nodeFor('f:${folders.first.id}') : _nodeFor('lib:${lib.id}'));
    });
  }

  /// ◀ or ESC: up a folder, back to the libraries, or out (no change).
  void _back() {
    final lib = _library;
    if (_inFolders && _path.isNotEmpty) {
      final left = _path.removeLast();
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nodeFor('f:${left.id}').requestFocus();
      });
      return;
    }
    if (_inFolders && lib != null) {
      _nodeFor('lib:${lib.id}').requestFocus();
      return;
    }
    Navigator.of(context).pop();
  }

  void _done() => Navigator.of(context).pop(_picked.values.toList());

  /// Whether a folder above this one (or its library) is picked already.
  bool _coveredByParent(JellyfinLibrary lib, List<FolderNode> above) =>
      _picked.containsKey(lib.id) || above.any((n) => _picked.containsKey(n.id));

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvPage(
      title: widget.poolName == null ? 'Choose folders' : 'Folders for ${widget.poolName}',
      hints: '▲▼ Move    OK Tick    ▶ Open    ◀ Back up    ESC Cancel',
      onBack: _back,
      child: FutureBuilder<List<JellyfinLibrary>>(
        future: _libraries,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(g, snapshot.error!);
          final libraries = snapshot.data;
          if (libraries == null) {
            return Center(child: Text('Loading libraries…', style: g.body(30, color: g.textDim)));
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 640,
                child: FocusTraversalGroup(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(100, 32, 24, 32),
                    children: [
                      Text('LIBRARIES', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                      const SizedBox(height: 12),
                      for (final (i, lib) in libraries.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FolderRow(
                            focusNode: _nodeFor('lib:${lib.id}'),
                            autofocus: i == 0,
                            label: lib.name,
                            detail: 'Whole library',
                            ticked: _picked.containsKey(lib.id),
                            opened: _library?.id == lib.id,
                            canOpen: true,
                            onToggle: () =>
                                _toggle(lib.id, () => PoolRoot(itemId: lib.id, libraryId: lib.id, label: lib.name)),
                            onOpen: () => _openLibrary(lib),
                            onBack: _back,
                            onFocus: () => setState(() => _inFolders = false),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        _picked.isEmpty
                            ? 'Nothing ticked yet. Tick a library to use all of it, or ▶ to pick folders in it.'
                            : '${_picked.length} folder${_picked.length == 1 ? '' : 's'} ticked',
                        style: g.body(24, color: g.textDim),
                      ),
                      const SizedBox(height: 16),
                      // Done is what ▼ from the libraries lands on.
                      Row(
                        children: [
                          Expanded(child: TvButton(label: 'Done', icon: Icons.check, expand: true, onPressed: _done)),
                          const SizedBox(width: 16),
                          TvButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: FocusTraversalGroup(child: _folders(g))),
            ],
          );
        },
      ),
    );
  }

  Widget _folders(GuideTheme g) {
    final lib = _library;
    if (lib == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 100, 32),
        child: Text('Press ▶ on a library to see its folders.', style: g.body(26, color: g.textDim)),
      );
    }
    return FutureBuilder<List<FolderNode>>(
      future: _treeOf(lib),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(g, snapshot.error!);
        final top = snapshot.data;
        if (top == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 100, 32),
            child: Text('Loading folders…', style: g.body(26, color: g.textDim)),
          );
        }
        final folders = _path.isEmpty ? top : _path.last.children;
        final covered = _coveredByParent(lib, _path);
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 100, 32),
          children: [
            Text(_label(lib, _path).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: g.display(26, weight: FontWeight.w800, color: g.accent)),
            const SizedBox(height: 12),
            if (folders.isEmpty)
              Text('No folders inside. Tick the library to use its videos.', style: g.body(26, color: g.textDim)),
            for (final node in folders)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FolderRow(
                  focusNode: _nodeFor('f:${node.id}'),
                  label: node.name,
                  detail: covered && !_picked.containsKey(node.id)
                      ? 'Included'
                      : node.children.isEmpty
                          ? null
                          : '${node.children.length} inside',
                  ticked: _picked.containsKey(node.id) || covered,
                  dim: covered && !_picked.containsKey(node.id),
                  canOpen: node.children.isNotEmpty,
                  onToggle: () => _toggle(
                      node.id,
                      () => PoolRoot(
                            itemId: node.id,
                            libraryId: lib.id,
                            label: _label(lib, [..._path, node]),
                          )),
                  onOpen: () => _openFolder(node),
                  onBack: _back,
                  onFocus: () => setState(() => _inFolders = true),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _error(GuideTheme g, Object error) {
    _focusWhenBuilt(_nodeFor('try-again'), onlyIfIdle: true);
    return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 110, color: g.accent),
            const SizedBox(height: 20),
            Text('Couldn\'t reach the server', style: g.display(52, weight: FontWeight.w800)),
            const SizedBox(height: 10),
            SizedBox(
              width: 1000,
              child: Text('$error  The pool hasn\'t changed.',
                  textAlign: TextAlign.center, style: g.body(26, color: g.textDim)),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvButton(label: 'Try again', icon: Icons.refresh, focusNode: _nodeFor('try-again'), onPressed: _retry),
                const SizedBox(width: 16),
                TvButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ],
        ),
      );
  }
}

/// A library or folder: OK (or the checkbox) ticks it, ▶ (or the name)
/// opens it, ◀ goes back up.
class _FolderRow extends StatefulWidget {
  const _FolderRow({
    required this.focusNode,
    required this.label,
    required this.ticked,
    required this.onToggle,
    required this.onOpen,
    required this.onBack,
    required this.onFocus,
    this.canOpen = false,
    this.opened = false,
    this.dim = false,
    this.detail,
    this.autofocus = false,
  });

  final FocusNode focusNode;
  final String label;
  final String? detail;
  final bool ticked;
  final bool canOpen;
  final bool opened;

  /// Ticked because a folder around it is.
  final bool dim;
  final bool autofocus;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onBack;
  final VoidCallback onFocus;

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final w = widget;
    return Focus(
      focusNode: w.focusNode,
      autofocus: w.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) {
          w.onFocus();
          Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
        }
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (isSelectKey(key) && event is KeyDownEvent) {
          w.onToggle();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (w.canOpen) w.onOpen();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          w.onBack();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!w.focusNode.hasFocus) w.focusNode.requestFocus();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 80,
          decoration: BoxDecoration(
            color: _focused || w.opened ? g.cellBorder : g.cell,
            borderRadius: BorderRadius.circular(g.radius),
            border: Border.all(color: _focused ? g.focus : Colors.transparent, width: 4),
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  w.focusNode.requestFocus();
                  w.onToggle();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(w.ticked ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 38, color: w.ticked ? (w.dim ? g.textDim : g.accent) : g.textDim),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    w.focusNode.requestFocus();
                    if (w.canOpen) {
                      w.onOpen();
                    } else {
                      w.onToggle();
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(w.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: g.display(30, weight: FontWeight.w600, color: w.dim ? g.textDim : g.text)),
                      ),
                      if (w.detail != null) ...[
                        const SizedBox(width: 12),
                        Text(w.detail!, style: g.body(22, color: g.textDim)),
                      ],
                      SizedBox(
                        width: 64,
                        child: w.canOpen ? Icon(Icons.chevron_right, size: 40, color: g.textDim) : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
