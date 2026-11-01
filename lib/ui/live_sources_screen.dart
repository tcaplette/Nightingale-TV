import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../channels/channel.dart';
import '../live/live_data.dart';
import '../live/live_download.dart';
import '../live/live_source.dart';
import '../live/live_source_files.dart';
import '../live/live_tv_manager.dart';
import '../live/url_privacy.dart';
import '../platform/backup_files.dart';
import '../platform/platform_info.dart';
import '../server/live_tv.dart';
import '../theme/tv_theme.dart';
import 'channel_groups_screen.dart' show askName;
import 'format.dart';
import 'menu_screen.dart' show confirm;
import 'widgets/adaptive.dart';
import 'widgets/channel_logo.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// Menu → Live TV sources (live-tv-sources): the profile's sources, each
/// with its channel count and last refresh, and adding, choosing channels,
/// refreshing, editing and removing them. Every control is a [TvButton]
/// (or built like one), so the D-pad, the air mouse and touch all work.
class LiveSourcesScreen extends StatelessWidget {
  const LiveSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final layout = ScreenLayout.of(context);
    return TvPage(
      title: 'Live TV sources',
      hints: '▲▼◀▶ Move    OK Select    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: ListenableBuilder(
        listenable: app.live,
        builder: (context, _) {
          final sources = app.live.sources;
          return FocusTraversalGroup(
            child: ListView(
              padding: layout.pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
              children: [
                Text(
                  'Real broadcasts and IPTV in your guide: your server\'s Live TV, or an M3U playlist with '
                  'an XMLTV guide. Their channels join the lineup after yours.',
                  style: g.body(24, color: g.textDim),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TvButton(
                    label: 'Add source',
                    icon: Icons.add,
                    autofocus: true,
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const AddLiveSourceScreen())),
                  ),
                ),
                const SizedBox(height: 28),
                if (sources.isEmpty) Text('No sources yet.', style: g.body(26, color: g.textDim)),
                for (final s in sources) _SourceRow(source: s),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "M3U playlist · 12 of 40 channels": how many of the source's [channels]
/// are in the lineup.
String sourceSummary(LiveSource s, List<LiveChannelInfo> channels) =>
    '${s.kind.label} · ${channels.where((c) => s.chosen.containsKey(c.key)).length} of ${channels.length} channels';

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final LiveSource source;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    final g = context.guide;
    final portrait = ScreenLayout.of(context).isPortrait;
    final entry = app.live.entryFor(source);
    final state = entry.state;
    final refreshing = app.live.isRefreshing(source);
    final status = refreshing
        ? 'Refreshing…'
        : state.lastError != null
            ? 'Last refresh failed: ${state.lastError}'
            : state.lastRefresh != null
                ? 'Refreshed ${formatRecent(state.lastRefresh!)}'
                : 'Not refreshed yet';
    final where = source.kind == LiveSourceKind.m3u
        ? source.playlistFile != null
            ? 'Playlist file'
            : maskUrl(source.playlistUrl ?? '')
        : null;
    final buttons = [
      TvButton(
        label: 'Choose channels',
        icon: Icons.checklist,
        onPressed: entry.channels.isEmpty
            ? null
            : () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => LiveChannelPickerScreen(source: source))),
      ),
      TvButton(label: 'Refresh now', icon: Icons.sync, onPressed: refreshing ? null : () => app.refreshLiveNow(source)),
      TvButton(label: 'Edit', icon: Icons.edit, onPressed: () => _edit(context)),
      TvButton(label: 'Remove', icon: Icons.delete, danger: true, onPressed: () => _remove(context)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Container(
        padding: EdgeInsets.all(portrait ? 24 : 28),
        decoration: BoxDecoration(
          color: g.panel,
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: g.cellBorder, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.name, style: g.display(40, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(sourceSummary(source, entry.channels), style: g.body(26, weight: FontWeight.w600, color: g.accent)),
            Text(status,
                style: g.body(24, color: state.lastError != null && !refreshing ? g.nowLine : g.textDim)),
            if (where != null)
              Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(22, color: g.textDim)),
            const SizedBox(height: 18),
            Wrap(spacing: 16, runSpacing: 14, children: buttons),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    if (source.kind == LiveSourceKind.m3u) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => M3uSourceScreen(editing: source)));
      return;
    }
    final name = await askName(context, title: 'Rename source', initial: source.name, action: 'Rename');
    if (name == null || !context.mounted) return;
    source.name = name;
    await AppScope.read(context).live.save();
  }

  Future<void> _remove(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Remove "${source.name}"?',
      message: 'Its channels leave the guide, their groups and favorites.',
      action: 'Remove',
    );
    if (!ok || !context.mounted) return;
    await AppScope.read(context).removeLiveSource(source);
  }
}

/// Add source: the profile's server's Live TV (offered when it has Live TV
/// this user may watch, otherwise shown with why not), or an M3U playlist.
class AddLiveSourceScreen extends StatefulWidget {
  const AddLiveSourceScreen({super.key});

  @override
  State<AddLiveSourceScreen> createState() => _AddLiveSourceScreenState();
}

class _AddLiveSourceScreenState extends State<AddLiveSourceScreen> {
  /// Each server's Live TV (multi-server: one option per server), by key.
  late final Map<String, Future<LiveTvAvailability?>> _availability = {
    for (final server in AppScope.read(context).servers.ordered)
      if (server.client != null) server.key: AppScope.read(context).liveTvAvailability(key: server.key),
  };

  /// The server whose channels are being read.
  String? _adding;

  /// Servers whose availability is known, and the first on offer (it takes
  /// focus; with none on offer, M3U does).
  final _answered = <String>{};
  String? _firstOffered;
  String? _error;
  final _m3u = FocusNode();
  bool _m3uFocused = false;

  @override
  void dispose() {
    _m3u.dispose();
    super.dispose();
  }

  Future<void> _addServer(String key) async {
    setState(() {
      _adding = key;
      _error = null;
    });
    final app = AppScope.read(context);
    try {
      final source = await app.addServerLiveSource(key: key);
      if (!mounted) return;
      await Navigator.of(context)
          .pushReplacement(MaterialPageRoute<void>(builder: (_) => LiveChannelPickerScreen(source: source)));
    } on LiveSourceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _adding = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final servers = [for (final s in app.servers.ordered) if (_availability.containsKey(s.key)) s];
    return TvPage(
      title: 'Add a Live TV source',
      hints: '▲▼ Move    OK Select    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            for (final s in servers) ...[
            FutureBuilder<LiveTvAvailability?>(
              future: _availability[s.key],
              builder: (context, snap) {
                final server = s.name;
                final already = app.live.serverSourceFor(s.serverId) != null ||
                    (!app.servers.multiple && app.live.serverSource != null);
                final offered = !already && snap.data == LiveTvAvailability.available;
                if (offered) _firstOffered ??= s.key;
                final autofocus = offered && _firstOffered == s.key;
                // With no server's Live TV on offer, focus goes to M3U.
                if (snap.connectionState == ConnectionState.done) _answered.add(s.key);
                if (_answered.length == servers.length && _firstOffered == null && !_m3uFocused) {
                  _m3uFocused = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _m3u.requestFocus();
                  });
                }
                // The button keeps a short label; why it can't be picked is
                // the line under it, so it isn't cut off on a phone.
                final a = snap.data;
                String? why;
                VoidCallback? action;
                if (already) {
                  why = '$server Live TV is already added';
                } else if (snap.connectionState != ConnectionState.done) {
                  why = 'Checking $server Live TV…';
                } else if (a == LiveTvAvailability.available) {
                  action = _adding != null ? null : () => _addServer(s.key);
                } else {
                  why = (a ?? LiveTvAvailability.noChannels).reason(server);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TvButton(
                      label: _adding == s.key ? 'Reading $server\'s channels…' : LiveTvAvailability.available.reason(server),
                      icon: Icons.settings_input_antenna,
                      expand: true,
                      autofocus: autofocus,
                      onPressed: action,
                    ),
                    if (why != null) ...[
                      const SizedBox(height: 8),
                      Text(why, style: g.body(24, weight: FontWeight.w700, color: g.accent)),
                    ],
                    const SizedBox(height: 8),
                    Text("The channels and guide of your server's tuner (an antenna, cable box or IPTV it has).",
                        style: g.body(22, color: g.textDim)),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            ],
            TvButton(
              label: 'M3U playlist',
              icon: Icons.playlist_add,
              expand: true,
              focusNode: _m3u,
              onPressed: () => Navigator.of(context)
                  .pushReplacement(MaterialPageRoute<void>(builder: (_) => const M3uSourceScreen())),
            ),
            const SizedBox(height: 8),
            Text('An IPTV playlist (a web address or a file), with an XMLTV guide if you have one.',
                style: g.body(22, color: g.textDim)),
            if (_error != null) ...[
              const SizedBox(height: 24),
              Text(_error!, style: g.body(26, weight: FontWeight.w600, color: g.nowLine)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A playlist or guide file picked on the device (desktop's file dialog,
/// Android's document picker), or null.
Future<PickedLiveFile?> pickLiveFile({required String label, required List<String> extensions}) async {
  final file = await openFile(
    acceptedTypeGroups: PlatformInfo.isAndroid ? const [] : [XTypeGroup(label: label, extensions: extensions)],
  );
  if (file == null) return null;
  final path = file.path;
  return (name: file.name, path: path.isEmpty ? null : path, bytes: path.isEmpty ? await file.readAsBytes() : null);
}

/// Adding (or with [editing], changing) an M3U playlist source: a name, the
/// playlist as a URL or a file, and an optional XMLTV guide. It's saved
/// only once the playlist reads with a channel; otherwise the screen says
/// why and keeps what was typed.
class M3uSourceScreen extends StatefulWidget {
  const M3uSourceScreen({super.key, this.editing});

  final LiveSource? editing;

  @override
  State<M3uSourceScreen> createState() => _M3uSourceScreenState();
}

class _M3uSourceScreenState extends State<M3uSourceScreen> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _playlist = TextEditingController(text: widget.editing?.playlistUrl ?? '');
  late final _guide = TextEditingController(
      text: widget.editing?.guideFromPlaylist == true ? '' : widget.editing?.guideUrl ?? '');
  PickedLiveFile? _playlistFile;
  PickedLiveFile? _guideFile;

  /// The source's files as they are (editing).
  late bool _keepPlaylistFile = widget.editing?.playlistFile != null;
  late bool _keepGuideFile = widget.editing?.guideFile != null;
  bool _saving = false;
  String? _error;
  late final Future<bool> _canPick = BackupFiles.available();

  @override
  void dispose() {
    _name.dispose();
    _playlist.dispose();
    _guide.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool guide}) async {
    final f = guide
        ? await pickLiveFile(label: 'XMLTV guides', extensions: const ['xml', 'gz', 'xmltv'])
        : await pickLiveFile(label: 'M3U playlists', extensions: const ['m3u', 'm3u8', 'txt']);
    if (f == null || !mounted) return;
    setState(() {
      if (guide) {
        _guideFile = f;
        _keepGuideFile = false;
      } else {
        _playlistFile = f;
        _keepPlaylistFile = false;
        if (_name.text.trim().isEmpty) _name.text = f.name.replaceFirst(RegExp(r'\.[^.]*$'), '');
      }
    });
  }

  /// A name from the playlist's address when none was typed.
  String _nameFor(String url) {
    if (_name.text.trim().isNotEmpty) return _name.text.trim();
    final host = Uri.tryParse(url.trim())?.host ?? '';
    return host.isEmpty ? 'M3U playlist' : host;
  }

  Future<void> _save() async {
    final url = _playlist.text.trim();
    if (_playlistFile == null && !_keepPlaylistFile && url.isEmpty) {
      setState(() => _error = 'Enter the playlist\'s address, or choose a playlist file');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final app = AppScope.read(context);
    final editing = widget.editing;
    try {
      if (editing == null) {
        final source = await app.addM3uSource(
          name: _nameFor(url),
          playlistUrl: url,
          playlist: _playlistFile,
          guideUrl: _guide.text,
          guide: _guideFile,
        );
        if (!mounted) return;
        await Navigator.of(context)
            .pushReplacement(MaterialPageRoute<void>(builder: (_) => LiveChannelPickerScreen(source: source)));
      } else {
        await app.editM3uSource(
          editing,
          name: _name.text,
          playlistUrl: _playlistFile != null || _keepPlaylistFile ? null : url,
          playlist: _playlistFile,
          guideUrl: _guideFile != null || _keepGuideFile ? null : _guide.text,
          guide: _guideFile,
          clearGuide: _guideFile == null && !_keepGuideFile && _guide.text.trim().isEmpty,
        );
        if (mounted) Navigator.of(context).pop();
      }
    } on LiveSourceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final editing = widget.editing;
    final playlistIsFile = _playlistFile != null || _keepPlaylistFile;
    final guideIsFile = _guideFile != null || _keepGuideFile;
    return TvPage(
      title: editing == null ? 'Add an M3U playlist' : 'Edit ${editing.name}',
      hints: '▲▼ Move    OK Select    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: FutureBuilder<bool>(
        future: _canPick,
        builder: (context, snap) {
          final canPick = snap.data ?? false;
          Widget fileRow({required bool guide}) {
            final picked = guide ? _guideFile : _playlistFile;
            final keep = guide ? _keepGuideFile : _keepPlaylistFile;
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (picked != null || keep)
                  Text('File: ${picked?.name ?? 'the one chosen before'}', style: g.body(26, weight: FontWeight.w600)),
                if (canPick)
                  TvButton(
                    label: picked != null || keep ? 'Choose another file' : 'Choose a file',
                    icon: Icons.folder_open,
                    onPressed: () => _pick(guide: guide),
                  ),
                if (picked != null || keep)
                  TvButton(
                    label: 'Use an address instead',
                    icon: Icons.link,
                    onPressed: () => setState(() {
                      if (guide) {
                        _guideFile = null;
                        _keepGuideFile = false;
                      } else {
                        _playlistFile = null;
                        _keepPlaylistFile = false;
                      }
                    }),
                  ),
              ],
            );
          }

          return FocusTraversalGroup(
            child: ListView(
              padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
              children: [
                TvTextField(controller: _name, label: 'Name', hint: 'My IPTV', autofocus: true),
                const SizedBox(height: 28),
                Text('PLAYLIST', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                const SizedBox(height: 10),
                if (!playlistIsFile)
                  TvTextField(
                    controller: _playlist,
                    label: 'Playlist address',
                    hint: 'http://provider.example/get.php?username=…&type=m3u_plus',
                    keyboardType: TextInputType.url,
                  ),
                const SizedBox(height: 12),
                fileRow(guide: false),
                const SizedBox(height: 28),
                Text('GUIDE (OPTIONAL)', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                const SizedBox(height: 10),
                if (!guideIsFile)
                  TvTextField(
                    controller: _guide,
                    label: 'XMLTV guide address',
                    hint: 'Leave empty to use the guide the playlist names',
                    keyboardType: TextInputType.url,
                  ),
                if (editing?.guideFromPlaylist == true && _guide.text.isEmpty && !guideIsFile)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Now: the playlist\'s guide, ${maskUrl(editing!.guideUrl ?? '')}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(22, color: g.textDim)),
                  ),
                const SizedBox(height: 12),
                fileRow(guide: true),
                const SizedBox(height: 36),
                if (_error != null) ...[
                  Text(_error!, style: g.body(28, weight: FontWeight.w700, color: g.nowLine)),
                  const SizedBox(height: 20),
                ],
                ButtonRow(children: [
                  TvButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                  TvButton(
                    label: _saving ? 'Reading the playlist…' : (editing == null ? 'Add' : 'Save'),
                    icon: Icons.check,
                    onPressed: _saving ? null : _save,
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Choose channels: a source's channels by group, a checkbox each and one
/// per group, with search. Only checked channels join the lineup. Built
/// lazily, so a playlist of 10,000 channels scrolls as smoothly as 10.
class LiveChannelPickerScreen extends StatefulWidget {
  const LiveChannelPickerScreen({super.key, required this.source});

  final LiveSource source;

  @override
  State<LiveChannelPickerScreen> createState() => _LiveChannelPickerScreenState();
}

/// A row in the picker: a group's header, or one of its channels.
typedef _Row = ({String group, LiveChannelInfo? channel});

class _LiveChannelPickerScreenState extends State<LiveChannelPickerScreen> {
  late final Set<String> _checked = {...widget.source.chosen.keys};
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  bool _saving = false;

  /// Every channel by group, in source order; groups in first-seen order.
  late final Map<String, List<LiveChannelInfo>> _groups = () {
    final groups = <String, List<LiveChannelInfo>>{};
    for (final c in AppScope.read(context).live.entryFor(widget.source).channels) {
      groups.putIfAbsent(c.group ?? widget.source.name, () => []).add(c);
    }
    return groups;
  }();

  late List<_Row> _rows = _filtered();

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      // The controller also tells of cursor moves: only new text filters.
      if (_search.text == _query) return;
      _query = _search.text;
      setState(() => _rows = _filtered());
      // New results start at the top.
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<_Row> _filtered() {
    final q = _search.text.trim().toLowerCase();
    final rows = <_Row>[];
    for (final e in _groups.entries) {
      final groupMatches = q.isEmpty || e.key.toLowerCase().contains(q);
      final channels = groupMatches
          ? e.value
          : [
              for (final c in e.value)
                if (c.name.toLowerCase().contains(q) || (c.number ?? '').contains(q)) c,
            ];
      if (channels.isEmpty) continue;
      rows.add((group: e.key, channel: null));
      for (final c in channels) {
        rows.add((group: e.key, channel: c));
      }
    }
    return rows;
  }

  void _toggleGroup(String group) {
    final keys = [for (final c in _groups[group]!) c.key];
    setState(() {
      if (keys.every(_checked.contains)) {
        _checked.removeAll(keys);
      } else {
        _checked.addAll(keys);
      }
    });
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    await AppScope.read(context).chooseLiveChannels(widget.source, _checked);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final layout = ScreenLayout.of(context);
    final total = _groups.values.fold(0, (n, l) => n + l.length);
    final padding = layout.pagePadding(const EdgeInsets.fromLTRB(100, 24, 100, 24));
    return TvPage(
      title: 'Choose channels: ${widget.source.name}',
      hints: '▲▼ Move    OK Check    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TvTextField(controller: _search, label: 'Search', hint: 'Channel or group name'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${_checked.length} of $total chosen', style: g.display(32, weight: FontWeight.w800)),
                      TvButton(
                        label: _saving ? 'Saving…' : 'Done',
                        icon: Icons.check,
                        autofocus: true,
                        onPressed: _saving ? null : _done,
                      ),
                      TvButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              // Guide markers arrive with the source's guide.
              child: ListenableBuilder(
                listenable: AppScope.read(context).live,
                builder: (context, _) {
                  final withGuide = {
                    for (final c in AppScope.read(context).live.entryFor(widget.source).channels)
                      if (c.hasGuide) c.key,
                  };
                  return ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, padding.bottom),
                itemCount: _rows.length,
                itemExtent: layout.isPortrait ? 96 : 84,
                itemBuilder: (context, i) {
                  final row = _rows[i];
                  final c = row.channel;
                  if (c == null) {
                    final keys = [for (final ch in _groups[row.group]!) ch.key];
                    final n = keys.where(_checked.contains).length;
                    return _PickerRow(
                      key: ValueKey('group:${row.group}'),
                      checkbox: n == keys.length
                          ? Icons.check_box
                          : n == 0
                              ? Icons.check_box_outline_blank
                              : Icons.indeterminate_check_box,
                      title: row.group.toUpperCase(),
                      trailing: '$n of ${keys.length}',
                      header: true,
                      onPressed: () => _toggleGroup(row.group),
                    );
                  }
                  return _PickerRow(
                    key: ValueKey('ch:${c.key}'),
                    checkbox: _checked.contains(c.key) ? Icons.check_box : Icons.check_box_outline_blank,
                    number: c.number,
                    logo: LiveTvManager.defaultIcon(c),
                    title: c.name,
                    trailing: withGuide.contains(c.key) ? 'GUIDE' : null,
                    onPressed: () => setState(() => _checked.contains(c.key) ? _checked.remove(c.key) : _checked.add(c.key)),
                  );
                },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    super.key,
    required this.checkbox,
    required this.title,
    required this.onPressed,
    this.number,
    this.logo,
    this.trailing,
    this.header = false,
  });

  final IconData checkbox;
  final String title;
  final String? number;
  final ChannelIcon? logo;
  final String? trailing;
  final bool header;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocusable(
        onPressed: onPressed,
        builder: (context, focused) {
          final fg = focused ? g.onFocus : g.text;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: focused ? g.focus : (header ? g.panel : g.cell),
              borderRadius: BorderRadius.circular(g.radius * 2),
              border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
            ),
            child: Row(
              children: [
                Icon(checkbox, size: 34, color: fg),
                const SizedBox(width: 16),
                if (!header) ...[
                  SizedBox(
                    width: 90,
                    child: Text(number ?? '', style: g.display(28, weight: FontWeight.w800, color: focused ? fg : g.accent)),
                  ),
                  if (logo != null) ...[
                    ChannelLogo(icon: logo!, size: 44, width: 70, fallbackText: title),
                    const SizedBox(width: 14),
                  ],
                ],
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: g.display(header ? 28 : 30, weight: header ? FontWeight.w800 : FontWeight.w600, color: fg)),
                ),
                if (trailing != null)
                  Text(trailing!, style: g.body(22, weight: FontWeight.w700, color: focused ? fg : g.textDim)),
              ],
            ),
          );
        },
      ),
    );
  }
}
