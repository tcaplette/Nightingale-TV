import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/tr.dart';
import '../server/media_server.dart';
import '../server/smb/smb_library.dart';
import '../server/smb/smb_server.dart';
import '../server/smb/smb_share.dart' show smbJoin;
import '../theme/tv_theme.dart';
import 'widgets/folder_map_row.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// Servers → a share → Folders: what its folders hold, and where its
/// history is kept (smb-sources "Mapping folders to content types").
class SmbFoldersScreen extends StatefulWidget {
  const SmbFoldersScreen({super.key, required this.serverKey});

  final String serverKey;

  @override
  State<SmbFoldersScreen> createState() => _SmbFoldersScreenState();
}

class _SmbFoldersScreenState extends State<SmbFoldersScreen> {
  late final SmbServer _server;
  late Map<String, SmbFolderType> _mappings;
  final _historyName = TextEditingController();
  late bool _keepLocal;
  String _folder = '';
  List<String>? _folders;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _server = AppScope.read(context).servers.byKey(widget.serverKey)!.client! as SmbServer;
    _mappings = {for (final m in _server.config.mappings) m.path: m.type};
    _historyName.text = _server.historyName;
    _keepLocal = _server.config.keepLocal;
    _open('');
  }

  @override
  void dispose() {
    _historyName.dispose();
    super.dispose();
  }

  Future<void> _open(String path) async {
    setState(() {
      _folders = null;
      _error = null;
    });
    try {
      final folders = await _server.foldersAt(path);
      if (mounted) {
        setState(() {
          _folder = path;
          _folders = folders;
        });
      }
    } on ServerException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _folders = const [];
        });
      }
    }
  }

  SmbFolderType? _typeAt(String path) {
    String? best;
    for (final p in _mappings.keys) {
      if (smbInside(path, p) && (best == null || p.length > best.length)) best = p;
    }
    return best == null ? null : _mappings[best];
  }

  void _back() {
    if (_folder.isEmpty) {
      Navigator.of(context).pop();
    } else {
      _open(_folder.contains('/') ? _folder.substring(0, _folder.lastIndexOf('/')) : '');
    }
  }

  Future<void> _save() async {
    if (_mappings.isEmpty) {
      setState(() => _error = tr.smbMapOne);
      return;
    }
    setState(() => _busy = true);
    final app = AppScope.read(context);
    final name = _historyName.text.trim();
    await app.setSmbHistory(widget.serverKey, name: () => name == app.smb.profileName ? null : name, keepLocal: _keepLocal);
    await app.setSmbMappings(widget.serverKey, [for (final e in _mappings.entries) SmbMapping(e.key, e.value)]);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final folders = _folders;
    final top = _folder.isEmpty;
    return TvPage(
      title: tr.smbFoldersTitle(_server.session.serverName),
      hints: tr.moveOkSelectEscBack,
      onBack: _back,
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            if (!top) Text(_folder.replaceAll('/', ' › '), style: g.display(34)),
            Text(tr.smbMapHelp, style: g.body(22, color: g.textDim)),
            const SizedBox(height: 20),
            if (!top) ...[
              TvButton(label: tr.smbUp, icon: Icons.arrow_upward, expand: true, onPressed: _back),
              const SizedBox(height: 12),
            ],
            if (folders == null) Center(child: CircularProgressIndicator(color: g.accent)),
            for (final (i, f) in (folders ?? const <String>[]).indexed) ...[
              FolderMapRow(
                key: ValueKey('folder-$_folder/$f'),
                name: f,
                type: _mappings[smbJoin(_folder, f)],
                inherited: _typeAt(_folder),
                autofocus: i == 0,
                onOpen: () => _open(smbJoin(_folder, f)),
                onType: (t) => setState(() {
                  final path = smbJoin(_folder, f);
                  t == null ? _mappings.remove(path) : _mappings[path] = t;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
            ],
            if (top) ...[
              const SizedBox(height: 16),
              TvTextField(key: const ValueKey('history-name'), controller: _historyName, label: tr.smbHistoryName),
              const SizedBox(height: 8),
              Text(tr.smbHistoryHelp, style: g.body(22, color: g.textDim)),
              const SizedBox(height: 12),
              TvToggle(label: tr.smbKeepLocal, on: _keepLocal, onPressed: () => setState(() => _keepLocal = !_keepLocal)),
            ],
            if (_error case final e?) ...[
              const SizedBox(height: 16),
              Text(e, style: g.body(24, color: g.nowLine)),
            ],
            const SizedBox(height: 20),
            TvButton(label: tr.smbSave, icon: Icons.check, expand: true, autofocus: folders?.isEmpty ?? false, onPressed: _busy ? null : _save),
          ],
        ),
      ),
    );
  }
}

/// Servers → a share → Can't play: the files nothing can play, and why.
class SmbCantPlayScreen extends StatefulWidget {
  const SmbCantPlayScreen({super.key, required this.serverKey});

  final String serverKey;

  @override
  State<SmbCantPlayScreen> createState() => _SmbCantPlayScreenState();
}

class _SmbCantPlayScreenState extends State<SmbCantPlayScreen> {
  bool _checking = false;

  static String reasonLabel(CantPlayReason r) => switch (r) {
        CantPlayReason.damaged => tr.smbReasonDamaged,
        CantPlayReason.noVideo => tr.smbReasonNoVideo,
        CantPlayReason.tooMuch => tr.smbReasonTooMuch,
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final server = app.servers.byKey(widget.serverKey)?.client;
    if (server is! SmbServer) return const SizedBox.shrink();
    final list = server.cantPlay.entries.toList()..sort((a, b) => a.key.path.compareTo(b.key.path));
    return TvPage(
      title: tr.smbCantPlayTitle(server.session.serverName),
      hints: tr.moveOkSelectEscBack,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            Text(tr.smbCantPlayHelp, style: g.body(22, color: g.textDim)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: TvButton(
                label: tr.smbCheckAgain,
                icon: Icons.refresh,
                autofocus: true,
                onPressed: _checking
                    ? null
                    : () async {
                        setState(() => _checking = true);
                        try {
                          await server.checkAgain();
                        } finally {
                          if (mounted) setState(() => _checking = false);
                        }
                      },
              ),
            ),
            const SizedBox(height: 24),
            if (_checking) Center(child: CircularProgressIndicator(color: g.accent)),
            if (list.isEmpty) Text(tr.smbCantPlayNone, style: g.body(26, color: g.textDim)),
            for (final e in list)
              // Focusable, so the list scrolls with the D-pad.
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TvFocusable(
                  onPressed: () {},
                  builder: (context, focused) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: focused ? g.focus : g.cell,
                      borderRadius: BorderRadius.circular(g.radius * 2),
                      border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.key.name, style: g.body(26, weight: FontWeight.w600, color: focused ? g.onFocus : g.text)),
                      Text('${e.key.folder.isEmpty ? '' : '${e.key.folder.replaceAll('/', ' › ')} · '}${reasonLabel(e.value)}',
                          style: g.body(22, color: focused ? g.onFocus : g.textDim)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
