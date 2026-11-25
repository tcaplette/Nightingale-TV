import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';
import 'server_page.dart' show SmbFolderRow;

/// Server colours in the guide (guide-server-colors): the setting and each
/// source's colour; shown with two or more sources.
class ColorsSection extends StatefulWidget {
  const ColorsSection({super.key, required this.profileId});
  final String profileId;

  @override
  State<ColorsSection> createState() => _ColorsSectionState();
}

class _ColorsSectionState extends State<ColorsSection> {
  Map<String, Object?>? _data;

  String get _path => 'profiles/${widget.profileId}/colors';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = (await context.api.get(_path))! as Map<String, Object?>;
      if (mounted) setState(() => _data = d);
    } on ApiException {
      // Shown once it loads.
    }
  }

  Future<void> _put(Map<String, Object?> body) async {
    final r = await attempt(context, () => context.api.put(_path, body), profileId: widget.profileId, onConflict: _load);
    if (r is Map<String, Object?> && mounted) setState(() => _data = r);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final sources = (d?['sources'] as List? ?? const []).cast<Map>();
    if (d == null || sources.length < 2) return const SizedBox.shrink();
    final palette = (d['palette'] as List).cast<Map>();
    return Section(title: tr.serverColorsSetting, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(tr.serverColorsSetting),
        subtitle: Text(tr.serverColorsHelp),
        value: d['on'] == true,
        onChanged: (v) => _put({'on': v}),
      ),
      if (d['on'] == true)
        for (final s in sources)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(width: 20, height: 20, decoration: BoxDecoration(color: hexColor(s['hex']), shape: BoxShape.circle)),
            title: Text('${s['name']}'),
            trailing: DropdownButton<String>(
              value: s['color'] as String?,
              items: [
                for (final c in palette)
                  DropdownMenuItem(
                    value: c['name'] as String,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 14, height: 14, color: hexColor(c['hex'])),
                      const SizedBox(width: 8),
                      Text('${c['label']}'),
                    ]),
                  ),
              ],
              onChanged: (v) => _put({
                'colors': {s['key']: v}
              }),
            ),
          ),
    ]);
  }
}

/// A share's settings in its server card: its name, folders, history, the
/// files still being read and Can't play.
class ShareSettings extends StatefulWidget {
  const ShareSettings({super.key, required this.profileId, required this.serverKey});
  final String profileId;
  final String serverKey;

  @override
  State<ShareSettings> createState() => _ShareSettingsState();
}

class _ShareSettingsState extends State<ShareSettings> {
  Map<String, Object?>? _data;
  final _name = TextEditingController();
  final _history = TextEditingController();
  Map<String, String> _folders = {};
  String _path = '';
  List<Map>? _listing;
  bool _editing = false;
  bool _checking = false;

  String get _base => 'profiles/${widget.profileId}/servers/${widget.serverKey}/share';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = (await context.api.get(_base))! as Map<String, Object?>;
      if (!mounted) return;
      setState(() {
        _data = d;
        _name.text = '${d['name']}';
        _history.text = '${d['historyName']}';
        _folders = {for (final f in (d['folders'] as List).cast<Map>()) '${f['path']}': '${f['type']}'};
      });
    } on ApiException {
      // Shown once it loads.
    }
  }

  Future<void> _save(Map<String, Object?> body) async {
    final r = await attempt(context, () => context.api.put(_base, body), profileId: widget.profileId, onConflict: _load);
    if (r is Map<String, Object?> && mounted) setState(() => _data = r);
  }

  Future<void> _open(String path) async {
    final r = await attempt(context, () => context.api.get('$_base/folders', {'path': path}), profileId: widget.profileId);
    if (r is Map && mounted) {
      setState(() {
        _path = path;
        _listing = (r['folders'] as List).cast<Map>();
      });
    }
  }

  static String _reason(Map c) => '${c['folder'] == '' ? '' : '${'${c['folder']}'.replaceAll('/', ' › ')} · '}${c['label']}';

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return const LinearProgressIndicator();
    final cant = (d['cantPlay'] as List).cast<Map>();
    final place = switch (d['historyPlace']) {
      'device' => tr.smbHistoryOnDevice,
      'readOnly' => tr.smbHistoryReadOnly,
      _ => tr.smbHistoryOnShare('${d['historyName']}'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (d['smb1'] == true) Text(tr.smbOld, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if ((d['filesLeft'] as num? ?? 0) > 0) Text(tr.smbFilesLeft((d['filesLeft'] as num).toInt())),
      Text(place),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 260, child: TextField(controller: _name, decoration: InputDecoration(labelText: tr.name))),
        OutlinedButton(onPressed: () => _save({'name': _name.text.trim()}), child: Text(tr.rename)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 260, child: TextField(controller: _history, decoration: InputDecoration(labelText: tr.smbHistoryName))),
        OutlinedButton(onPressed: () => _save({'historyName': _history.text.trim()}), child: Text(tr.smbSave)),
      ]),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(tr.smbKeepLocal),
        value: d['keepLocal'] == true,
        onChanged: (v) => _save({'keepLocal': v == true}),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(tr.smbFolders),
        onExpansionChanged: (open) {
          if (open && _listing == null) unawaited(_open(''));
          setState(() => _editing = open);
        },
        children: [
          Text(tr.smbMapHelp, style: Theme.of(context).textTheme.bodySmall),
          if (_path.isNotEmpty)
            TextButton.icon(
                icon: const Icon(Icons.arrow_upward),
                label: Text(tr.smbUp),
                onPressed: () => _open(_path.contains('/') ? _path.substring(0, _path.lastIndexOf('/')) : '')),
          for (final f in _listing ?? const <Map>[])
            SmbFolderRow(
              name: '${f['name']}',
              type: _folders['${f['path']}'],
              onOpen: () => _open('${f['path']}'),
              onType: (t) => setState(() => t == null ? _folders.remove('${f['path']}') : _folders['${f['path']}'] = t),
            ),
          if (_editing)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => _save({
                  'folders': [for (final e in _folders.entries) {'path': e.key, 'type': e.value}]
                }),
                child: Text(tr.smbSave),
              ),
            ),
        ],
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(tr.smbCantPlay(cant.length)),
        children: [
          Text(tr.smbCantPlayHelp, style: Theme.of(context).textTheme.bodySmall),
          if (cant.isEmpty) Text(tr.smbCantPlayNone),
          for (final c in cant) ListTile(contentPadding: EdgeInsets.zero, title: Text('${c['name']}'), subtitle: Text(_reason(c))),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _checking
                  ? null
                  : () async {
                      setState(() => _checking = true);
                      final r = await attempt(context, () => context.api.post('$_base/check-again'), profileId: widget.profileId);
                      if (!mounted) return;
                      setState(() {
                        _checking = false;
                        if (r is Map<String, Object?>) _data = r;
                      });
                    },
              child: Text(tr.smbCheckAgain),
            ),
          ),
        ],
      ),
    ]);
  }
}

/// Convert for other TVs (admins): on or off, the pairing code and the
/// paired TVs.
class HelperSection extends StatefulWidget {
  const HelperSection({super.key});

  @override
  State<HelperSection> createState() => _HelperSectionState();
}

class _HelperSectionState extends State<HelperSection> {
  Map<String, Object?>? _data;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // The code changes when a TV pairs.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = (await context.api.get('convert-helper'))! as Map<String, Object?>;
      if (mounted) setState(() => _data = d);
    } on ApiException {
      // Not an admin, or not here: nothing shown.
    }
  }

  Future<void> _call(Future<Object?> Function() call) async {
    final r = await attempt(context, call);
    if (r is Map<String, Object?> && mounted) setState(() => _data = r);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null || d['available'] != true) return const SizedBox.shrink();
    final tvs = (d['tvs'] as List).cast<Map>();
    return Section(title: tr.convertForOthers, children: [
      Text(tr.convertForOthersHelp),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(tr.convertForOthers),
        value: d['on'] == true,
        onChanged: (v) => _call(() => context.api.put('convert-helper', {'on': v})),
      ),
      if (d['code'] case final String code)
        SelectableText(tr.convertCode(code), style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(tr.convertPairedTvs, style: Theme.of(context).textTheme.titleSmall),
      if (tvs.isEmpty) Text(tr.convertNoTvs),
      for (final t in tvs)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${t['name']}'),
          trailing: TextButton(
              onPressed: () => _call(() => context.api.delete('convert-helper/tvs/${t['id']}')), child: Text(tr.remove)),
        ),
    ]);
  }
}
