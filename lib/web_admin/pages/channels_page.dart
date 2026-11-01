import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../channels/retro.dart';
import '../../channels/premiere_settings.dart';
import '../../commercials/break_plan.dart';
import '../../commercials/commercial_pool.dart';
import '../../ui/format.dart';
import '../app.dart';
import '../widgets/break_plan_editor.dart';
import '../widgets/channel_icon.dart';
import '../widgets/common.dart';
import '../widgets/source_editor.dart';

/// A profile's channels: search, open one to edit, add custom, block and
/// music channels, reset the lineup; the main logo mode and premieres.
class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key, required this.profileId});
  final String profileId;

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  final _search = TextEditingController();
  Map<String, Object?>? _data;
  String? _error;

  String get _base => 'profiles/${widget.profileId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = (await context.api.get('$_base/channels'))! as Map<String, Object?>;
      if (mounted) setState(() => _data = data);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _do(Future<Object?> Function() call) async {
    final r = await attempt(context, call, profileId: widget.profileId, onConflict: _load);
    if (r != null) await _load();
  }

  Future<void> _addCustom() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomChannelDialog(profileId: widget.profileId),
    );
    if (added == true) await _load();
  }

  Future<void> _addMusic() async {
    final body = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _MusicChannelDialog(profileId: widget.profileId),
    );
    if (body != null) await _do(() => context.api.post('$_base/channels', body));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return PageBody(title: 'Channels', children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final channels = (data['channels'] as List).cast<Map<String, Object?>>();
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final c in channels)
        if (query.isEmpty || '${c['number']} ${c['name']}'.toLowerCase().contains(query)) c,
    ];
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final header = <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(header: true, child: Text('Channels', style: Theme.of(context).textTheme.headlineSmall)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(icon: const Icon(Icons.add), label: const Text('New channel'), onPressed: _addCustom),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: const Text('Block channel'),
              onPressed: () async {
                final name = await askText(context, title: 'New block channel', label: 'Name', action: 'Add');
                if (name != null && mounted) {
                  await _do(() => context.api.post('$_base/channels', {'kind': 'block', 'name': name}));
                }
              },
            ),
            FilledButton.tonalIcon(icon: const Icon(Icons.music_note), label: const Text('Music channel'), onPressed: _addMusic),
            OutlinedButton(
              onPressed: () async {
                final ok = await confirm(context,
                    title: 'Reset channel lineup?',
                    message: 'Every channel edit is discarded and the default lineup is made again. Channels you added are '
                        'kept. A backup is saved first.',
                    action: 'Reset');
                if (ok && context.mounted) await _do(() => context.api.post('$_base/channels/reset'));
              },
              child: const Text('Reset lineup'),
            ),
          ]),
        ],
      ),
      const SizedBox(height: 12),
      _MainSettings(profileId: widget.profileId, data: data, onChanged: _load),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search channels'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Text('${shown.length} of ${channels.length} channels', style: Theme.of(context).textTheme.bodySmall),
    ];
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 24, 16, narrow ? 16 : 24, 48),
      itemCount: header.length + shown.length,
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        final c = shown[i - header.length];
        final view = c['view'] as Map? ?? const {};
        final now = view['now'] as Map?;
        final icon = ChannelIcon.fromJson((c['icon'] as Map).cast<String, Object?>());
        return Card(
          margin: const EdgeInsets.only(top: 8),
          child: ListTile(
            minVerticalPadding: 12,
            leading: ChannelIconView(
                icon: icon, profileId: widget.profileId, channelId: c['id'] as String, fallbackText: c['name'] as String),
            title: Text('${c['number']}  ${c['name']}', overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (now != null) now['title'] as String,
                if (view['live'] != null) 'Live · ${(view['live'] as Map)['source']}',
                if (c['blockOnly'] == true) 'Block channel',
                if (view['music'] == true) 'Music',
                if (c['hidden'] == true) 'Hidden',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: c['favorite'] == true ? const Icon(Icons.star, semanticLabel: 'Favorite') : null,
            onTap: () => context.go('/profiles/${widget.profileId}/channels/${Uri.encodeComponent(c['id'] as String)}'),
          ),
        );
      },
    );
  }
}

/// One retro setting's choices: a [null] value is "Main setting".
class _RetroDropdown<T> extends StatelessWidget {
  const _RetroDropdown({required this.title, required this.values, required this.value, required this.label, required this.onChanged});

  final String title;
  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        key: ValueKey('$title $value'),
        initialValue: value,
        decoration: InputDecoration(labelText: title),
        items: [for (final v in values) DropdownMenuItem(value: v, child: Text(label(v)))],
        onChanged: (v) {
          if (v is T) onChanged(v);
        },
      ),
    );
  }
}

const _retroNote = "These settings apply on screens running the app. They don't apply to Live TV export.";

/// The main retro look and the Custom CRT style.
class _MainRetro extends StatelessWidget {
  const _MainRetro({required this.retro, required this.put, required this.onChooseImage});

  final RetroSettings retro;
  final Future<void> Function(Map<String, Object?> body) put;
  final VoidCallback onChooseImage;

  @override
  Widget build(BuildContext context) {
    final custom = retro.custom;
    Widget level(String title, CrtLevel value, String key) => _RetroDropdown<CrtLevel>(
          title: title,
          values: CrtLevel.values,
          value: value,
          label: (v) => v.label,
          onChanged: (v) => put({
            'custom': {key: v.name}
          }),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Retro look', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        const Text(_retroNote),
        const SizedBox(height: 12),
        _RetroDropdown<PictureShape>(
            title: 'Picture shape',
            values: PictureShape.values,
            value: retro.shape,
            label: (v) => v.label,
            onChanged: (v) => put({'shape': v.name})),
        _RetroDropdown<Surround>(
            title: 'Surround',
            values: [for (final s in Surround.values) if (s != Surround.image || retro.surroundImage != null) s],
            value: retro.surround,
            label: (v) => v.label,
            onChanged: (v) => put({'surround': v.name})),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onChooseImage, child: const Text('Choose surround image…')),
        ),
        _RetroDropdown<CrtStyle>(
            title: 'CRT effect',
            values: CrtStyle.values,
            value: retro.crt,
            label: (v) => v.label,
            onChanged: (v) => put({'crt': v.name})),
        _RetroDropdown<OverlayThemeName>(
            title: 'Overlay theme',
            values: OverlayThemeName.values,
            value: retro.overlay,
            label: (v) => v.label,
            onChanged: (v) => put({'overlay': v.name})),
        _RetroDropdown<OverlayAccent>(
            title: 'Accent (${retro.overlay.label})',
            values: OverlayAccent.values,
            value: retro.accentOf(retro.overlay),
            label: (v) => v.label,
            onChanged: (v) => put({
                  'accents': {retro.overlay.name: v.name}
                })),
        Text('Custom CRT style', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        level('Scanlines', custom.scanlines, 'scanlines'),
        _RetroDropdown<int>(
            title: 'Lines',
            values: CrtValues.lineCounts,
            value: custom.lines,
            label: (v) => '$v',
            onChanged: (v) => put({
                  'custom': {'lines': v}
                })),
        level('Mask', custom.mask, 'mask'),
        level('Vignette', custom.vignette, 'vignette'),
        level('Curvature', custom.curvature, 'curvature'),
        level('Glow', custom.glow, 'glow'),
        _RetroDropdown<CrtColor>(
            title: 'Color',
            values: CrtColor.values,
            value: custom.color,
            label: (v) => v.label,
            onChanged: (v) => put({
                  'custom': {'color': v.name}
                })),
      ],
    );
  }
}

/// The main logo mode and the premiere slot.
class _MainSettings extends StatelessWidget {
  const _MainSettings({required this.profileId, required this.data, required this.onChanged});

  final String profileId;
  final Map<String, Object?> data;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final mode = LogoMode.parse(data['logoMode']) ?? LogoMode.nowAndThen;
    final premieres = PremiereSettings.fromJson(data['premieres']);
    Future<void> put(String path, Object body) async {
      final r = await attempt(context, () => context.api.put('profiles/$profileId/$path', body),
          profileId: profileId, onConflict: onChanged);
      if (r != null) await onChanged();
    }

    return ExpansionTile(
      title: const Text('Main settings'),
      subtitle: Text('Logo ${mode.label.toLowerCase()} · Premieres ${premieres.enabled ? formatClockMinute(premieres.startMinute) : 'off'}'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Channel logo', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<LogoMode>(
          segments: [for (final m in LogoMode.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {mode},
          onSelectionChanged: (s) => put('logo', {'logoMode': s.single.name}),
        ),
        const SizedBox(height: 16),
        _MainRetro(
          retro: RetroSettings.fromJson(data['retro']),
          put: (body) => put('retro', body),
          onChooseImage: () async {
            final name = await _uploadFullScreenImage(context, profileId);
            if (name != null) await put('retro', {'surround': Surround.image.name, 'surroundImage': name});
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('New episode premieres'),
          subtitle: const Text("A nightly slot for shows' newest episodes, on each show's home channel."),
          value: premieres.enabled,
          onChanged: (on) => put('premieres', {'premieres': premieres.copyWith(enabled: on).toJson()}),
        ),
        if (premieres.enabled) ...[
          MinuteField(
            label: 'Starts',
            minute: premieres.startMinute,
            onChanged: (m) => put('premieres', {'premieres': premieres.copyWith(startMinute: m ~/ 15 * 15).toJson()}),
          ),
          const SizedBox(height: 8),
          DayPicker(
            days: premieres.days,
            onChanged: (d) {
              if (d.isNotEmpty) put('premieres', {'premieres': premieres.copyWith(days: d).toJson()});
            },
          ),
        ],
      ],
    );
  }
}

/// A custom channel: a name, what it plays and its order. Added on Add
/// with something picked; Cancel adds nothing.
class _CustomChannelDialog extends StatefulWidget {
  const _CustomChannelDialog({required this.profileId});
  final String profileId;

  @override
  State<_CustomChannelDialog> createState() => _CustomChannelDialogState();
}

class _CustomChannelDialogState extends State<_CustomChannelDialog> {
  final _name = TextEditingController(text: 'My Channel');
  ChannelSource _source = const ChannelSource(includeEpisodes: false);
  PlaybackOrder _order = PlaybackOrder.random;
  bool _saving = false;

  /// Adds the channel; on a refusal the dialog stays, with the picks in it.
  Future<void> _add() async {
    setState(() => _saving = true);
    final r = await attempt(
        context,
        () => context.api.post('profiles/${widget.profileId}/channels', {
              'kind': 'custom',
              'name': _name.text.trim(),
              'order': _order.name,
              'source': _source.toJson(),
            }),
        profileId: widget.profileId);
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New channel'),
        scrollable: true,
        content: SizedBox(
          width: 640,
          child: DataView<Map<String, Object?>>(
            load: () async => (await context.api.get('profiles/${widget.profileId}/library/catalog'))! as Map<String, Object?>,
            builder: (context, catalog, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              SourceEditor(
                profileId: widget.profileId,
                source: _source,
                catalog: catalog,
                onChanged: (s) => setState(() => _source = s),
              ),
              RadioGroup<PlaybackOrder>(
                groupValue: _order,
                onChanged: (v) => setState(() => _order = v!),
                child: Column(children: [
                  for (final o in PlaybackOrder.values)
                    RadioListTile<PlaybackOrder>(contentPadding: EdgeInsets.zero, value: o, title: Text(o.label)),
                ]),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: !_source.hasPicks || _saving ? null : _add,
            child: const Text('Add'),
          ),
        ],
      );
}

/// A music channel: songs or music videos, optionally only some genres and
/// decades.
class _MusicChannelDialog extends StatefulWidget {
  const _MusicChannelDialog({required this.profileId});
  final String profileId;

  @override
  State<_MusicChannelDialog> createState() => _MusicChannelDialogState();
}

class _MusicChannelDialogState extends State<_MusicChannelDialog> {
  final _name = TextEditingController();
  bool _songs = true, _videos = false;
  final _genres = <String>{};
  final _decades = <int>{};

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New music channel'),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: DataView<Map<String, Object?>>(
            load: () async => (await context.api.get('profiles/${widget.profileId}/library/catalog'))! as Map<String, Object?>,
            builder: (context, catalog, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
              CheckboxListTile(
                value: _songs,
                onChanged: (v) => setState(() => _songs = v ?? false),
                title: Text('Songs (${catalog['songs']})'),
              ),
              CheckboxListTile(
                value: _videos,
                onChanged: (v) => setState(() => _videos = v ?? false),
                title: Text('Music videos (${catalog['musicVideos']})'),
              ),
              if ((catalog['musicGenres'] as List).isNotEmpty) ...[
                Text('Genres (none: any)', style: Theme.of(context).textTheme.labelLarge),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final g in (catalog['musicGenres'] as List).cast<String>())
                    FilterChip(
                      label: Text(g),
                      selected: _genres.contains(g),
                      onSelected: (on) => setState(() => on ? _genres.add(g) : _genres.remove(g)),
                    ),
                ]),
              ],
              if ((catalog['decades'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Decades (none: any)', style: Theme.of(context).textTheme.labelLarge),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final d in (catalog['decades'] as List).cast<int>())
                    FilterChip(
                      label: Text("${d}s"),
                      selected: _decades.contains(d),
                      onSelected: (on) => setState(() => on ? _decades.add(d) : _decades.remove(d)),
                    ),
                ]),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: !_songs && !_videos
                ? null
                : () => Navigator.of(context).pop({
                      'kind': 'music',
                      'name': _name.text.trim(),
                      'source': ChannelSource(
                        includeEpisodes: false,
                        includeSongs: _songs,
                        includeMusicVideos: _videos,
                        genres: _genres.toList()..sort(),
                        decades: _decades.toList()..sort(),
                      ).toJson(),
                    }),
            child: const Text('Add'),
          ),
        ],
      );
}

/// One channel's settings, each saved as it changes (as on the TV).
class ChannelEditorPage extends StatefulWidget {
  const ChannelEditorPage({super.key, required this.profileId, required this.channelId});

  final String profileId;
  final String channelId;

  @override
  State<ChannelEditorPage> createState() => _ChannelEditorPageState();
}

class _ChannelEditorPageState extends State<ChannelEditorPage> {
  Map<String, Object?>? _c;
  String? _error;
  final _name = TextEditingController();
  final _number = TextEditingController();
  Map<String, Object?>? _commercials;
  Map<String, Object?>? _catalog;

  /// The source being edited on a custom channel, until it's saved.
  ChannelSource? _source;

  String get _path => 'profiles/${widget.profileId}/channels/${Uri.encodeComponent(widget.channelId)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.api;
      final c = (await api.get(_path))! as Map<String, Object?>;
      final commercials = (await api.get('profiles/${widget.profileId}/commercials'))! as Map<String, Object?>;
      final catalog = (c['view'] as Map)['custom'] == true
          ? (await api.get('profiles/${widget.profileId}/library/catalog'))! as Map<String, Object?>
          : null;
      if (!mounted) return;
      setState(() {
        _c = c;
        _catalog = catalog;
        _source = null;
        _commercials = commercials;
        _name.text = c['name'] as String;
        _number.text = '${c['number']}';
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _put(Map<String, Object?> change) async {
    final r = await attempt(context, () => context.api.put(_path, change), profileId: widget.profileId, onConflict: _load);
    if (r is Map<String, Object?> && mounted) {
      setState(() {
        _c = r;
        _name.text = r['name'] as String;
        _number.text = '${r['number']}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return PageBody(title: 'Channel', children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final view = (c['view'] as Map).cast<String, Object?>();
    final live = view['live'] as Map?;
    final isLive = live != null;
    final music = view['music'] == true;
    final blockOnly = c['blockOnly'] == true;
    final icon = ChannelIcon.fromJson((c['icon'] as Map).cast<String, Object?>());
    final order = PlaybackOrder.values.byName(c['order'] as String);
    final ownPlan = c['commercialPlan'] == null ? null : BreakPlan.fromJson((c['commercialPlan'] as Map).cast<String, Object?>());
    final mainPlan = BreakPlan.fromJson(((_commercials?['plan'] as Map?) ?? const {}).cast<String, Object?>());
    final logoMode = LogoMode.parse(c['logoMode']);
    final pools = ((_commercials?['pools'] as List?) ?? const []).cast<Map<String, Object?>>();
    final saved = ChannelSource.fromJson((c['source'] as Map).cast<String, Object?>());
    final catalog = _catalog;
    return PageBody(
      title: '${c['number']}  ${c['name']}',
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.arrow_back),
          label: const Text('Channels'),
          onPressed: () => context.go('/profiles/${widget.profileId}/channels'),
        ),
      ],
      children: [
        if (isLive) Text('Live from ${live['source']}${live['number'] == null ? '' : ' · ${live['number']}'}'),
        Section(title: 'Name and number', children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (v) => _put({'name': v}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Number', helperText: 'A channel already on that number swaps into this one\'s place.'),
            onSubmitted: (v) {
              final n = int.tryParse(v.trim());
              if (n != null) _put({'number': n});
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () {
                final n = int.tryParse(_number.text.trim());
                _put({'name': _name.text, 'number': ?n});
              },
              child: const Text('Save name and number'),
            ),
          ),
        ]),
        Section(title: 'Icon', children: [
          Row(children: [
            ChannelIconView(
                icon: icon, profileId: widget.profileId, channelId: widget.channelId, size: 64, fallbackText: c['name'] as String),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonal(
                  onPressed: () async {
                    final chosen = await pickIcon(context, profileId: widget.profileId, current: icon);
                    if (chosen != null) await _put({'icon': chosen.toJson()});
                  },
                  child: const Text('Choose icon…'),
                ),
                if (isLive && live['sourceIcon'] != null)
                  OutlinedButton(onPressed: () => _put({'icon': live['sourceIcon']}), child: const Text("Source's logo")),
              ]),
            ),
          ]),
        ]),
        Section(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Favorite'),
            value: c['favorite'] == true,
            onChanged: (v) => _put({'favorite': v}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hidden from the guide'),
            value: c['hidden'] == true,
            onChanged: (v) => _put({'hidden': v}),
          ),
          if (!blockOnly && !music && !isLive)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('New episode premieres'),
              subtitle: const Text("Can be a show's home channel for its newest episodes."),
              value: c['premieres'] != false,
              onChanged: (v) => _put({'premieres': v}),
            ),
        ]),
        if (view['custom'] == true && catalog != null)
          Section(title: 'What it plays', children: [
            SourceEditor(
              profileId: widget.profileId,
              source: _source ?? saved,
              catalog: catalog,
              missingRoots: {...((view['missingRoots'] as List?) ?? const []).cast<String>()},
              onChanged: (s) => setState(() => _source = s),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _source == null || !_source!.hasPicks
                    ? null
                    : () async {
                        await _put({'source': _source!.toJson()});
                        if (mounted) setState(() => _source = null);
                      },
                child: const Text('Save what it plays'),
              ),
            ),
          ]),
        if (!blockOnly && !isLive)
          Section(title: 'Play order', children: [
            if (music) const Text('Music channels only shuffle, never the same artist twice in a row.'),
            RadioGroup<PlaybackOrder>(
              groupValue: order,
              onChanged: (v) => _put({'order': v!.name}),
              child: Column(children: [
                for (final o in PlaybackOrder.values)
                  if (!music || o == PlaybackOrder.random)
                    RadioListTile<PlaybackOrder>(contentPadding: EdgeInsets.zero, value: o, title: Text(o.label)),
              ]),
            ),
            if (view['canReshuffle'] == true)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Reshuffle'),
                  onPressed: () async {
                    final r = await attempt(context, () => context.api.post('$_path/reshuffle'),
                        profileId: widget.profileId, onConflict: _load);
                    if (r is Map<String, Object?> && mounted) setState(() => _c = r);
                  },
                ),
              ),
          ]),
        if (view['playsPrograms'] == true) _slotSection(c, pools),
        if (!isLive)
          Section(title: 'Commercials', children: [
            RadioGroup<String>(
              groupValue: ownPlan == null ? 'main' : ownPlan.mode.name,
              onChanged: (v) async {
                if (v == 'main') return _put({'commercialPlan': null});
                final mode = BreakMode.values.byName(v!);
                if (mode != BreakMode.custom) return _put({'commercialPlan': BreakPlan(mode: mode).toJson()});
                final roles = await editBreakPlan(context,
                    title: 'Breaks on ${c['name']}', initial: (ownPlan ?? mainPlan).roles, pools: pools);
                if (roles != null) await _put({'commercialPlan': BreakPlan(mode: BreakMode.custom, roles: roles).toJson()});
              },
              child: Column(children: [
                RadioListTile<String>(
                    contentPadding: EdgeInsets.zero, value: 'main', title: Text('Main setting (${mainPlan.mode.label})')),
                for (final mode in BreakMode.values)
                  RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: mode.name,
                      title: Text(mode == BreakMode.custom ? 'Custom…' : mode.label)),
              ]),
            ),
            if (ownPlan?.mode == BreakMode.custom)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final roles = await editBreakPlan(context,
                        title: 'Breaks on ${c['name']}', initial: ownPlan!.roles, pools: pools);
                    if (roles != null) await _put({'commercialPlan': BreakPlan(mode: BreakMode.custom, roles: roles).toJson()});
                  },
                  child: const Text('Edit custom breaks…'),
                ),
              ),
          ]),
        Section(title: 'Channel logo', children: [
          RadioGroup<String>(
            groupValue: logoMode?.name ?? 'main',
            onChanged: (v) => _put({'logoMode': v == 'main' ? null : v}),
            child: Column(children: [
              RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'main',
                  title: Text('Main setting (${LogoMode.parse(view['logoMode'])?.label ?? ''})')),
              for (final m in LogoMode.values)
                RadioListTile<String>(contentPadding: EdgeInsets.zero, value: m.name, title: Text(m.label)),
            ]),
          ),
        ]),
        Section(title: 'Retro look', children: _retroRows(c, view)),
        if (view['auto'] == false && !isLive)
          Section(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove this channel'),
                onPressed: () async {
                  final ok = await confirm(context,
                      title: 'Remove ${c['name']}?',
                      message: blockOnly ? 'Its programming blocks are removed too.' : 'It leaves the lineup.',
                      action: 'Remove');
                  if (!ok || !context.mounted) return;
                  final r = await attempt(context, () => context.api.delete(_path), profileId: widget.profileId);
                  if (r != null && context.mounted) context.go('/profiles/${widget.profileId}/channels');
                },
              ),
            ),
          ]),
      ],
    );
  }

  /// The slot length, tail mode, filler pool and offline image.
  Widget _slotSection(Map<String, Object?> c, List<Map<String, Object?>> pools) {
    final rule = SlotRule.fromJson(c['slot']);
    final fillers = [for (final p in pools) if (p['kind'] != PoolKind.bumpers.name) p];
    Future<void> set(SlotRule? r) => _put({'slot': r?.toJson()});
    return Section(title: 'Slot length', children: [
      const Text('Every program starts on the clock. The tail fills the rest of each slot.'),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        key: ValueKey('slot-${rule?.length.inMinutes}'),
        initialValue: rule?.length.inMinutes ?? 0,
        decoration: const InputDecoration(labelText: 'Slot length'),
        items: [
          const DropdownMenuItem(value: 0, child: Text('Off')),
          for (final l in SlotRule.lengths) DropdownMenuItem(value: l.inMinutes, child: Text('${l.inMinutes} minutes')),
        ],
        onChanged: (m) {
          if (m == null) return;
          final length = Duration(minutes: m);
          set(m == 0 ? null : rule?.copyWith(length: length) ?? SlotRule(length: length));
        },
      ),
      if (rule != null) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<TailMode>(
          key: ValueKey('tail-${rule.tail.name}'),
          initialValue: rule.tail,
          decoration: const InputDecoration(labelText: 'Tail'),
          items: [for (final t in TailMode.values) DropdownMenuItem(value: t, child: Text(t.label))],
          onChanged: (t) {
            if (t != null) set(rule.copyWith(tail: t));
          },
        ),
        if (rule.tail != TailMode.offline) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('pool-${rule.poolId}'),
            initialValue: fillers.any((p) => p['id'] == rule.poolId) ? rule.poolId : '',
            decoration: const InputDecoration(labelText: 'Filler pool'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All pools')),
              for (final p in fillers) DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String)),
            ],
            onChanged: (id) => set(rule.copyWith(poolId: () => id == null || id.isEmpty ? null : id)),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(
            onPressed: () => _uploadOffline(rule),
            child: Text(rule.offlineImage == null ? 'Choose offline image…' : 'Change offline image…'),
          ),
          if (rule.offlineImage != null)
            OutlinedButton(
              onPressed: () => set(rule.copyWith(offlineImage: () => null)),
              child: const Text('Default card'),
            ),
        ]),
      ],
    ]);
  }

  /// A channel's four retro settings, each with its "Main setting" choice.
  List<Widget> _retroRows(Map<String, Object?> c, Map<dynamic, dynamic> view) {
    final own = ChannelRetro.fromJson(c['retro']);
    final used = ResolvedRetro.of(ChannelRetro.main, RetroSettings.fromJson(view['mainRetro']));
    String main(String value) => 'Main setting ($value)';
    Future<void> set(ChannelRetro retro) => _put({'retro': retro.toJson()});
    return [
      const Text(_retroNote),
      const SizedBox(height: 12),
      _RetroDropdown<PictureShape?>(
          title: 'Picture shape',
          values: [null, ...PictureShape.values],
          value: own.shape,
          label: (v) => v?.label ?? main(used.shape.label),
          onChanged: (v) => set(own.copyWith(shape: () => v))),
      _RetroDropdown<Surround?>(
          title: 'Surround',
          values: [
            null,
            for (final s in Surround.values)
              if (s != Surround.image || own.surroundImage != null) s
          ],
          value: own.surround,
          label: (v) => v?.label ?? main(used.surround.label),
          onChanged: (v) => set(own.copyWith(surround: () => v))),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: () => _uploadSurround(own), child: const Text('Choose surround image…')),
      ),
      _RetroDropdown<CrtStyle?>(
          title: 'CRT effect',
          values: [null, ...CrtStyle.values],
          value: own.crt,
          label: (v) => v?.label ?? main(used.crt.label),
          onChanged: (v) => set(own.copyWith(crt: () => v))),
      _RetroDropdown<OverlayThemeName?>(
          title: 'Overlay theme',
          values: [null, ...OverlayThemeName.values],
          value: own.overlay,
          label: (v) => v?.label ?? main(used.overlay.label),
          onChanged: (v) => set(own.copyWith(overlay: () => v))),
    ];
  }

  Future<void> _uploadSurround(ChannelRetro own) async {
    final name = await _uploadFullScreenImage(context, widget.profileId);
    if (name != null && mounted) {
      await _put({'retro': own.copyWith(surround: () => Surround.image, surroundImage: () => name).toJson()});
    }
  }

  Future<void> _uploadOffline(SlotRule rule) async {
    final name = await _uploadFullScreenImage(context, widget.profileId);
    if (name != null && mounted) await _put({'slot': rule.copyWith(offlineImage: () => name).toJson()});
  }
}

/// A picture chosen and stored for a full-screen use; its name, or null.
Future<String?> _uploadFullScreenImage(BuildContext context, String profileId) async {
  final file = await openFile(acceptedTypeGroups: const [
    XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'], mimeTypes: ['image/*']),
  ]);
  if (file == null || !context.mounted) return null;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;
  final r = await attempt(
      context,
      () => context.api.upload('profiles/$profileId/icons', bytes, query: {'name': file.name, 'kind': 'offline'}),
      profileId: profileId);
  return r is Map ? r['name'] as String : null;
}
