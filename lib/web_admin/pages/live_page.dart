import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';
import '../../l10n/tr.dart';

/// Live TV sources: the server's Live TV, M3U playlists with XMLTV guides
/// by URL or uploaded file; refresh, edit, remove, choose channels.
class LivePage extends StatelessWidget {
  const LivePage({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final base = 'profiles/$profileId/live-sources';
    return DataView<Map<String, Object?>>(
      load: () async => (await context.api.get(base))! as Map<String, Object?>,
      builder: (context, data, reload) {
        final sources = (data['sources'] as List).cast<Map<String, Object?>>();
        final server = data['server'] as Map? ?? const {};
        Future<void> run(Future<Object?> Function() call, {String? done}) async {
          final r = await attempt(context, call, profileId: profileId, onConflict: reload);
          if (r != null) {
            if (done != null && context.mounted) showMessage(context, done);
            await reload();
          }
        }

        return PageBody(
          title: tr.liveTvSources,
          actions: [
            if (data['enabled'] == true)
              FilledButton.icon(
                icon: const Icon(Icons.playlist_add),
                label: Text(tr.m3uPlaylist),
                onPressed: () async {
                  final added = await showDialog<Map<String, Object?>>(
                      context: context, builder: (_) => _M3uDialog(profileId: profileId));
                  if (added != null && context.mounted) {
                    await reload();
                    if (context.mounted) context.go('/profiles/$profileId/live/${Uri.encodeComponent(added['id'] as String)}');
                  }
                },
              ),
            if (data['enabled'] == true && server['canAdd'] == true)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.settings_input_antenna),
                label: Text('${server['reason']}'),
                onPressed: () => run(() => context.api.post('$base/server'), done: 'Added.'),
              ),
          ],
          children: [
            if (data['message'] != null) Text(data['message'] as String),
            if (server['canAdd'] != true && server['reason'] != null) Text(server['reason'] as String),
            if (sources.isEmpty) Text(tr.noSourcesYet),
            for (final s in sources)
              _SourceCard(
                profileId: profileId,
                source: s,
                onRefresh: () => run(() => context.api.post('$base/${Uri.encodeComponent(s['id'] as String)}/refresh')),
                onRemove: () async {
                  final ok = await confirm(context,
                      title: tr.remove3('${s['name']}'),
                      message: tr.itsChannelsLeaveThe,
                      action: tr.remove);
                  if (ok && context.mounted) await run(() => context.api.delete('$base/${Uri.encodeComponent(s['id'] as String)}'));
                },
                onEdit: () async {
                  final saved = await showDialog<Map<String, Object?>>(
                      context: context, builder: (_) => _M3uDialog(profileId: profileId, editing: s));
                  if (saved != null) await reload();
                },
              ),
          ],
        );
      },
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard(
      {required this.profileId, required this.source, required this.onRefresh, required this.onRemove, required this.onEdit});

  final String profileId;
  final Map<String, Object?> source;
  final VoidCallback onRefresh, onRemove, onEdit;

  @override
  Widget build(BuildContext context) {
    final view = source['view'] as Map;
    final m3u = source['kind'] == 'm3u';
    final last = DateTime.tryParse(view['lastRefresh'] as String? ?? '')?.toLocal();
    final status = view['refreshing'] == true
        ? tr.refreshing
        : view['lastError'] != null
            ? tr.lastRefreshFailed('${view['lastError']}')
            : last != null
                ? tr.refreshed2(MaterialLocalizations.of(context).formatShortDate(last), TimeOfDay.fromDateTime(last).format(context))
                : tr.notRefreshedYet;
    return Section(title: source['name'] as String, children: [
      Text(tr.kindChosenChannels(m3u ? tr.m3uPlaylist : tr.serverLiveTv, '${view['chosen']}', '${view['channels']}')),
      if (m3u) Text(source['playlistUrl'] as String? ?? tr.playlistFile2('${source['playlistFile']}'), style: Theme.of(context).textTheme.bodySmall),
      if (m3u && (source['guideUrl'] ?? source['guideFile']) != null)
        Text(tr.guide3('${source['guideUrl'] ?? source['guideFile']}'), style: Theme.of(context).textTheme.bodySmall),
      Text(status),
      if (view['active'] == false) Text(tr.itsChannelsJoin),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonal(
          onPressed: () => context.go('/profiles/$profileId/live/${Uri.encodeComponent(source['id'] as String)}'),
          child: Text(tr.chooseChannels2),
        ),
        OutlinedButton(onPressed: view['refreshing'] == true ? null : onRefresh, child: Text(tr.refreshNow)),
        if (m3u) OutlinedButton(onPressed: onEdit, child: Text(tr.edit2)),
        TextButton(onPressed: onRemove, child: Text(tr.remove)),
      ]),
    ]);
  }
}

/// Adding or editing an M3U source: the playlist and guide by URL or file.
class _M3uDialog extends StatefulWidget {
  const _M3uDialog({required this.profileId, this.editing});
  final String profileId;
  final Map<String, Object?>? editing;

  @override
  State<_M3uDialog> createState() => _M3uDialogState();
}

class _M3uDialogState extends State<_M3uDialog> {
  late final _name = TextEditingController(text: widget.editing?['name'] as String? ?? '');
  late final _playlist = TextEditingController(text: widget.editing?['playlistUrl'] as String? ?? '');
  late final _guide = TextEditingController(text: widget.editing?['guideUrl'] as String? ?? '');
  String? _playlistUpload, _playlistFileName, _guideUpload, _guideFileName;
  bool _busy = false;
  String? _error;

  String get _base => 'profiles/${widget.profileId}/live-sources';

  Future<(String, String)?> _uploadFile(List<String> extensions) async {
    final file = await openFile(acceptedTypeGroups: [XTypeGroup(label: tr.files, extensions: extensions)]);
    if (file == null || !mounted) return null;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 32 << 20) throw ApiException(413, tr.thatFileIsToo);
      if (!mounted) return null;
      final r = (await context.api.upload('$_base/files', bytes, query: {'name': file.name}))! as Map;
      return (r['upload'] as String, file.name);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final editing = widget.editing;
    final keepPlaylist = editing?['playlistFile'] != null && _playlistUpload == null && _playlist.text.trim().isEmpty;
    if (!keepPlaylist && _playlistUpload == null && _playlist.text.trim().isEmpty) {
      setState(() => _error = tr.enterThePlaylists);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, Object?>{
      if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
      if (_playlistUpload != null) 'playlistUpload': _playlistUpload else if (!keepPlaylist) 'playlistUrl': _playlist.text.trim(),
      if (_guideUpload != null) 'guideUpload': _guideUpload else if (_guide.text.trim().isNotEmpty) 'guideUrl': _guide.text.trim(),
      if (editing != null && _guideUpload == null && _guide.text.trim().isEmpty && editing['guideFile'] == null) 'clearGuide': true,
    };
    try {
      final api = context.api;
      final r = editing == null
          ? await api.post(_base, body)
          : await api.put('$_base/${Uri.encodeComponent(editing['id'] as String)}', body);
      if (mounted) Navigator.of(context).pop(r as Map<String, Object?>);
    } on ApiException catch (e) {
      if (e.needs != null && mounted && await unlock(context, widget.profileId, grownUp: e.needs == 'grownUp')) {
        if (mounted) setState(() => _busy = false);
        return _save();
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.editing == null ? tr.addAnM3u : tr.edit('${widget.editing!['name']}')),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.editing != null)
              TextField(controller: _name, decoration: InputDecoration(labelText: tr.name)),
            TextField(
              controller: _playlist,
              enabled: _playlistUpload == null,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr.playlistAddress,
                hintText: tr.httpPlaylistM3u,
                helperText: widget.editing?['playlistFile'] != null ? tr.leaveEmptyToKeep : null,
              ),
            ),
            Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text(_playlistFileName ?? tr.orChooseAPlaylist),
                onPressed: _busy
                    ? null
                    : () async {
                        final up = await _uploadFile(['m3u', 'm3u8', 'txt']);
                        if (up != null) {
                          setState(() {
                            _playlistUpload = up.$1;
                            _playlistFileName = up.$2;
                          });
                        }
                      },
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _guide,
              enabled: _guideUpload == null,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                  labelText: tr.guideAddressXmltv, helperText: tr.emptyThePlaylists),
            ),
            Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text(_guideFileName ?? tr.orChooseA),
                onPressed: _busy
                    ? null
                    : () async {
                        final up = await _uploadFile(['xml', 'gz', 'xmltv']);
                        if (up != null) {
                          setState(() {
                            _guideUpload = up.$1;
                            _guideFileName = up.$2;
                          });
                        }
                      },
              ),
            ]),
            if (_busy) Padding(padding: EdgeInsets.only(top: 8), child: Busy(text: tr.readingThePlaylist)),
            ErrorText(_error),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr.cancel)),
          FilledButton(onPressed: _busy ? null : _save, child: Text(widget.editing == null ? tr.add : tr.save)),
        ],
      );
}

/// A source's channels: which join the lineup.
class LiveChannelsPage extends StatefulWidget {
  const LiveChannelsPage({super.key, required this.profileId, required this.sourceId});

  final String profileId;
  final String sourceId;

  @override
  State<LiveChannelsPage> createState() => _LiveChannelsPageState();
}

class _LiveChannelsPageState extends State<LiveChannelsPage> {
  Set<String>? _chosen;
  final _search = TextEditingController();

  String get _path => 'profiles/${widget.profileId}/live-sources/${Uri.encodeComponent(widget.sourceId)}/channels';

  @override
  Widget build(BuildContext context) => DataView<Map<String, Object?>>(
        load: () async => (await context.api.get(_path))! as Map<String, Object?>,
        builder: (context, data, reload) {
          final channels = (data['channels'] as List).cast<Map<String, Object?>>();
          final chosen = _chosen ??= {for (final c in channels) if (c['chosen'] == true) c['key'] as String};
          final q = _search.text.trim().toLowerCase();
          final shown = [
            for (final c in channels)
              if (q.isEmpty || '${c['number'] ?? ''} ${c['name']} ${c['group'] ?? ''}'.toLowerCase().contains(q)) c,
          ];
          return Column(children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: shown.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(tr.channels8('${(data['source'] as Map)['name']}'), style: Theme.of(context).textTheme.headlineSmall),
                      Text(tr.ofChosen(chosen.length, channels.length)),
                      TextButton(onPressed: () => setState(() => chosen.addAll(shown.map((c) => c['key'] as String))), child: Text(tr.allShown)),
                      TextButton(onPressed: () => setState(() => chosen.removeAll(shown.map((c) => c['key']))), child: Text(tr.noneShown)),
                    ]);
                  }
                  if (i == 1) {
                    return TextField(
                      controller: _search,
                      decoration: InputDecoration(prefixIcon: Icon(Icons.search), labelText: tr.search),
                      onChanged: (_) => setState(() {}),
                    );
                  }
                  final c = shown[i - 2];
                  final key = c['key'] as String;
                  return CheckboxListTile(
                    value: chosen.contains(key),
                    title: Text('${c['number'] == null ? '' : '${c['number']}  '}${c['name']}'),
                    subtitle: Text([if (c['group'] != null) c['group'], if (c['hasGuide'] != true) tr.noGuide].join(' · ')),
                    onChanged: (on) => setState(() => on == true ? chosen.add(key) : chosen.remove(key)),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  FilledButton(
                    onPressed: () async {
                      final r = await attempt(context, () => context.api.put(_path, {'keys': chosen.toList()}),
                          profileId: widget.profileId, onConflict: () async {
                        _chosen = null;
                        await reload();
                      });
                      if (r != null && context.mounted) context.go('/profiles/${widget.profileId}/live');
                    },
                    child: Text(tr.save),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => context.go('/profiles/${widget.profileId}/live'), child: Text(tr.cancel)),
                ]),
              ),
            ),
          ]);
        },
      );
}
