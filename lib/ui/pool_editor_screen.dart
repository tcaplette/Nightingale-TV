import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../commercials/commercial_pool.dart';
import '../library/library_index.dart';
import '../theme/tv_theme.dart';
import 'folder_picker_screen.dart';
import 'menu_screen.dart' show confirm;
import 'widgets/tv_focus.dart';

/// Rename a commercial pool, choose its folders, or delete it.
class PoolEditorScreen extends StatefulWidget {
  const PoolEditorScreen({super.key, required this.pool});

  final CommercialPool pool;

  @override
  State<PoolEditorScreen> createState() => _PoolEditorScreenState();
}

class _PoolEditorScreenState extends State<PoolEditorScreen> {
  late final _name = TextEditingController(text: widget.pool.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CommercialPool get _pool => widget.pool;

  Future<void> _rename() async {
    await AppScope.read(context).renamePool(_pool, _name.text);
    if (mounted) setState(() => _name.text = _pool.name);
  }

  Future<void> _addFolders() async {
    final roots = await Navigator.of(context).push<List<PoolRoot>>(
      MaterialPageRoute(builder: (_) => FolderPickerScreen(initial: _pool.roots, poolName: _pool.name)),
    );
    if (roots == null || !mounted) return;
    await AppScope.read(context).setPoolRoots(_pool, roots);
  }

  Future<void> _remove(PoolRoot root) =>
      AppScope.read(context).setPoolRoots(_pool, [for (final r in _pool.roots) if (r.itemId != root.itemId) r]);

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Delete "${_pool.name}"?',
        message: 'Its videos go back to your regular channels. Breaks that drew from it use all pools instead.',
        action: 'Delete');
    if (!ok || !mounted) return;
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    await app.deletePool(_pool);
    await tuner.reschedule();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final clips = app.catalog.clipsFor(_pool.id);
    final items = [for (final c in app.library.commercials) if (c.poolIds.contains(_pool.id)) c];
    final reels = items.where((c) => c.runtime > LibraryIndex.maxClip).toList();
    final unsplit = reels.where((r) => !app.catalog.clipsFor(_pool.id).any((c) => c.sourceId == r.id)).length;

    return TvPage(
      title: 'Commercial pool',
      hints: '▲▼◀▶ Move    OK Select    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FocusTraversalGroup(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(100, 32, 40, 40),
                children: [
                  Row(
                    children: [
                      Expanded(child: TvTextField(controller: _name, label: 'Pool name', onSubmitted: (_) => _rename())),
                      const SizedBox(width: 16),
                      TvButton(label: 'Rename', icon: Icons.check, onPressed: _rename),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text('FOLDERS', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 6),
                  Text(
                    'Every video in these folders (and the folders inside them) fills breaks, '
                    'and never airs as a program.',
                    style: g.body(24, color: g.textDim),
                  ),
                  const SizedBox(height: 16),
                  if (_pool.roots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('No folders yet.', style: g.body(28)),
                    ),
                  for (final root in _pool.roots)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(root.isWholeLibrary ? Icons.video_library : Icons.folder, size: 36, color: g.accent),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(root.label.isEmpty ? 'Library' : root.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(30, weight: FontWeight.w600)),
                          ),
                          TvButton(label: 'Remove', icon: Icons.close, onPressed: () => _remove(root)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvButton(
                      label: 'Add folders…',
                      icon: Icons.create_new_folder,
                      autofocus: true,
                      onPressed: _addFolders,
                    ),
                  ),
                  // Apart, so ▼ through the folders never lands on it.
                  const SizedBox(height: 48),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvButton(label: 'Delete pool', icon: Icons.delete, danger: true, onPressed: _delete),
                  ),
                  const SizedBox(height: 24),
                  if (app.refreshing)
                    Text(app.syncStatus, style: g.body(26, weight: FontWeight.w600, color: g.accent))
                  else if (app.syncError != null)
                    Text('Last scan failed: ${app.syncError}', style: g.body(24, color: g.nowLine)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 640,
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 40, 80, 40),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: g.panel,
                borderRadius: BorderRadius.circular(g.radius * 2),
                border: Border.all(color: g.cellBorder, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_pool.name.toUpperCase(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(30, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 16),
                  Text('${clips.length} clip${clips.length == 1 ? '' : 's'}', style: g.display(56, weight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    [
                      '${items.length} video${items.length == 1 ? '' : 's'} in its folders',
                      if (reels.isNotEmpty) '${reels.length} long one${reels.length == 1 ? '' : 's'} split into clips',
                      if (unsplit > 0) '$unsplit still to split',
                    ].join(' · '),
                    style: g.body(24, color: g.textDim),
                  ),
                  const SizedBox(height: 24),
                  for (final line in const [
                    'Videos of 5 seconds to 3 minutes are one clip each.',
                    'Longer videos (ad compilations) are split into their ads, at chapters or where the '
                        'picture goes black and silent.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('•  $line', style: g.body(24, color: g.textDim)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
