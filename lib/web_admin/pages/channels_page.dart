import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../channels/premiere_settings.dart';
import '../../commercials/break_plan.dart';
import '../../ui/format.dart';
import '../app.dart';
import '../widgets/break_plan_editor.dart';
import '../widgets/channel_icon.dart';
import '../widgets/common.dart';

/// A profile's channels: search, open one to edit, add block and music
/// channels, reset the lineup; the main logo mode and premieres.
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
                    message: 'Every channel edit is discarded and the default lineup is made again. Block channels are '
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
      if (!mounted) return;
      setState(() {
        _c = c;
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
          ]),
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
}
