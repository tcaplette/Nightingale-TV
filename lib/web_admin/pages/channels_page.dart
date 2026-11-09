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
import '../../l10n/tr.dart';

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
      return PageBody(title: tr.channels5, children: [
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
          Semantics(header: true, child: Text(tr.channels5, style: Theme.of(context).textTheme.headlineSmall)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(icon: const Icon(Icons.add), label: Text(tr.newChannel), onPressed: _addCustom),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: Text(tr.blockChannel2),
              onPressed: () async {
                final name = await askText(context, title: tr.newBlockChannel, label: tr.name, action: tr.add);
                if (name != null && mounted) {
                  await _do(() => context.api.post('$_base/channels', {'kind': 'block', 'name': name}));
                }
              },
            ),
            FilledButton.tonalIcon(icon: const Icon(Icons.music_note), label: Text(tr.musicChannel), onPressed: _addMusic),
            OutlinedButton(
              onPressed: () async {
                final ok = await confirm(context,
                    title: tr.resetChannelLineup,
                    message: tr.everyChannelEdit,
                    action: tr.reset);
                if (ok && context.mounted) await _do(() => context.api.post('$_base/channels/reset'));
              },
              child: Text(tr.resetLineup),
            ),
          ]),
        ],
      ),
      const SizedBox(height: 12),
      _MainSettings(profileId: widget.profileId, data: data, onChanged: _load),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        decoration: InputDecoration(prefixIcon: Icon(Icons.search), labelText: tr.searchChannels),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Text(tr.ofChannels2(shown.length, channels.length), style: Theme.of(context).textTheme.bodySmall),
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
                if (view['live'] != null) tr.live3('${(view['live'] as Map)['source']}'),
                if (c['blockOnly'] == true) tr.blockChannel2,
                if (view['music'] == true) tr.music,
                if (c['hidden'] == true) tr.hidden,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: c['favorite'] == true ? Icon(Icons.star, semanticLabel: tr.favorite) : null,
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

String get _retroNote => tr.theseSettingsApply;

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
        Text(tr.retroLook, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(_retroNote),
        const SizedBox(height: 12),
        _RetroDropdown<PictureShape>(
            title: tr.pictureShape2,
            values: PictureShape.values,
            value: retro.shape,
            label: (v) => v.label,
            onChanged: (v) => put({'shape': v.name})),
        _RetroDropdown<Surround>(
            title: tr.surround2,
            values: [for (final s in Surround.values) if (s != Surround.image || retro.surroundImage != null) s],
            value: retro.surround,
            label: (v) => v.label,
            onChanged: (v) => put({'surround': v.name})),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onChooseImage, child: Text(tr.chooseSurroundImage)),
        ),
        _RetroDropdown<CrtStyle>(
            title: tr.crtEffect2,
            values: CrtStyle.values,
            value: retro.crt,
            label: (v) => v.label,
            onChanged: (v) => put({'crt': v.name})),
        _RetroDropdown<OverlayThemeName>(
            title: tr.overlayTheme2,
            values: OverlayThemeName.values,
            value: retro.overlay,
            label: (v) => v.label,
            onChanged: (v) => put({'overlay': v.name})),
        _RetroDropdown<OverlayAccent>(
            title: tr.accent2(retro.overlay.label),
            values: OverlayAccent.values,
            value: retro.accentOf(retro.overlay),
            label: (v) => v.label,
            onChanged: (v) => put({
                  'accents': {retro.overlay.name: v.name}
                })),
        Text(tr.customCrtStyle2, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        level(tr.scanlines2, custom.scanlines, 'scanlines'),
        _RetroDropdown<int>(
            title: tr.lines2,
            values: CrtValues.lineCounts,
            value: custom.lines,
            label: (v) => '$v',
            onChanged: (v) => put({
                  'custom': {'lines': v}
                })),
        level(tr.mask2, custom.mask, 'mask'),
        level(tr.vignette2, custom.vignette, 'vignette'),
        level(tr.curvature2, custom.curvature, 'curvature'),
        level(tr.glow2, custom.glow, 'glow'),
        _RetroDropdown<CrtColor>(
            title: tr.color,
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
      title: Text(tr.mainSettings),
      subtitle: Text(tr.logoAndPremieres(mode.label.toLowerCase(), premieres.enabled ? formatClockMinute(premieres.startMinute) : tr.offLower)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.channelLogo2, style: Theme.of(context).textTheme.labelLarge),
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
          title: Text(tr.newEpisodePremieres),
          subtitle: Text(tr.aNightlySlot),
          value: premieres.enabled,
          onChanged: (on) => put('premieres', {'premieres': premieres.copyWith(enabled: on).toJson()}),
        ),
        if (premieres.enabled) ...[
          MinuteField(
            label: tr.starts,
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
  final _name = TextEditingController(text: tr.myChannel);
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
        title: Text(tr.newChannel),
        scrollable: true,
        content: SizedBox(
          width: 640,
          child: DataView<Map<String, Object?>>(
            load: () async => (await context.api.get('profiles/${widget.profileId}/library/catalog'))! as Map<String, Object?>,
            builder: (context, catalog, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _name, decoration: InputDecoration(labelText: tr.name)),
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr.cancel)),
          FilledButton(
            onPressed: !_source.hasPicks || _saving ? null : _add,
            child: Text(tr.add),
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
        title: Text(tr.newMusicChannel),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: DataView<Map<String, Object?>>(
            load: () async => (await context.api.get('profiles/${widget.profileId}/library/catalog'))! as Map<String, Object?>,
            builder: (context, catalog, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _name, autofocus: true, decoration: InputDecoration(labelText: tr.name)),
              CheckboxListTile(
                value: _songs,
                onChanged: (v) => setState(() => _songs = v ?? false),
                title: Text(tr.songs('${catalog['songs']}')),
              ),
              CheckboxListTile(
                value: _videos,
                onChanged: (v) => setState(() => _videos = v ?? false),
                title: Text(tr.musicVideos('${catalog['musicVideos']}')),
              ),
              if ((catalog['musicGenres'] as List).isNotEmpty) ...[
                Text(tr.genresNoneAny, style: Theme.of(context).textTheme.labelLarge),
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
                Text(tr.decadesNoneAny, style: Theme.of(context).textTheme.labelLarge),
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr.cancel)),
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
            child: Text(tr.add),
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
      return PageBody(title: tr.channel3, children: [
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
          label: Text(tr.channels5),
          onPressed: () => context.go('/profiles/${widget.profileId}/channels'),
        ),
      ],
      children: [
        if (isLive) Text([tr.liveFrom('${live['source']}'), if (live['number'] != null) '${live['number']}'].join(' · ')),
        Section(title: tr.nameAndNumber, children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: tr.name),
            onSubmitted: (v) => _put({'name': v}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: tr.number3, helperText: tr.aChannelAlready),
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
              child: Text(tr.saveNameAnd),
            ),
          ),
        ]),
        Section(title: tr.icon, children: [
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
                  child: Text(tr.chooseIcon),
                ),
                if (isLive && live['sourceIcon'] != null)
                  OutlinedButton(onPressed: () => _put({'icon': live['sourceIcon']}), child: Text(tr.sourcesLogo)),
              ]),
            ),
          ]),
        ]),
        Section(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr.favorite),
            value: c['favorite'] == true,
            onChanged: (v) => _put({'favorite': v}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr.hiddenFromThe),
            value: c['hidden'] == true,
            onChanged: (v) => _put({'hidden': v}),
          ),
          if (!blockOnly && !music && !isLive)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr.newEpisodePremieres),
              subtitle: Text(tr.canBeA),
              value: c['premieres'] != false,
              onChanged: (v) => _put({'premieres': v}),
            ),
        ]),
        if (view['custom'] == true && catalog != null)
          Section(title: tr.whatItPlays2, children: [
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
                child: Text(tr.saveWhatIt),
              ),
            ),
          ]),
        if (!blockOnly && !isLive)
          Section(title: tr.playOrder2, children: [
            if (music) Text(tr.musicChannelsOnlyShuffle),
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
                  label: Text(tr.reshuffle),
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
          Section(title: tr.commercials, children: [
            RadioGroup<String>(
              groupValue: ownPlan == null ? 'main' : ownPlan.mode.name,
              onChanged: (v) async {
                if (v == 'main') return _put({'commercialPlan': null});
                final mode = BreakMode.values.byName(v!);
                if (mode != BreakMode.custom) return _put({'commercialPlan': BreakPlan(mode: mode).toJson()});
                final roles = await editBreakPlan(context,
                    title: tr.breaksOn('${c['name']}'), initial: (ownPlan ?? mainPlan).roles, pools: pools);
                if (roles != null) await _put({'commercialPlan': BreakPlan(mode: BreakMode.custom, roles: roles).toJson()});
              },
              child: Column(children: [
                RadioListTile<String>(
                    contentPadding: EdgeInsets.zero, value: 'main', title: Text(tr.mainSetting(mainPlan.mode.label))),
                for (final mode in BreakMode.values)
                  RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: mode.name,
                      title: Text(mode == BreakMode.custom ? tr.custom2 : mode.label)),
              ]),
            ),
            if (ownPlan?.mode == BreakMode.custom)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final roles = await editBreakPlan(context,
                        title: tr.breaksOn('${c['name']}'), initial: ownPlan!.roles, pools: pools);
                    if (roles != null) await _put({'commercialPlan': BreakPlan(mode: BreakMode.custom, roles: roles).toJson()});
                  },
                  child: Text(tr.editCustomBreaks),
                ),
              ),
          ]),
        Section(title: tr.channelLogo2, children: [
          RadioGroup<String>(
            groupValue: logoMode?.name ?? 'main',
            onChanged: (v) => _put({'logoMode': v == 'main' ? null : v}),
            child: Column(children: [
              RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'main',
                  title: Text(tr.mainSetting(LogoMode.parse(view['logoMode'])?.label ?? ''))),
              for (final m in LogoMode.values)
                RadioListTile<String>(contentPadding: EdgeInsets.zero, value: m.name, title: Text(m.label)),
            ]),
          ),
        ]),
        Section(title: tr.retroLook, children: _retroRows(c, view)),
        if (view['auto'] == false && !isLive)
          Section(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(tr.removeThisChannel),
                onPressed: () async {
                  final ok = await confirm(context,
                      title: tr.remove3('${c['name']}'),
                      message: blockOnly ? tr.itsProgrammingBlocks : tr.itLeavesThe,
                      action: tr.remove);
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
    return Section(title: tr.slotLength2, children: [
      Text(tr.everyProgramStarts),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        key: ValueKey('slot-${rule?.length.inMinutes}'),
        initialValue: rule?.length.inMinutes ?? 0,
        decoration: InputDecoration(labelText: tr.slotLength2),
        items: [
          DropdownMenuItem(value: 0, child: Text(tr.off)),
          for (final l in SlotRule.lengths) DropdownMenuItem(value: l.inMinutes, child: Text(tr.minutes(l.inMinutes))),
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
          decoration: InputDecoration(labelText: tr.tail),
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
            decoration: InputDecoration(labelText: tr.fillerPool2),
            items: [
              DropdownMenuItem(value: '', child: Text(tr.allPools)),
              for (final p in fillers) DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String)),
            ],
            onChanged: (id) => set(rule.copyWith(poolId: () => id == null || id.isEmpty ? null : id)),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(
            onPressed: () => _uploadOffline(rule),
            child: Text(rule.offlineImage == null ? tr.chooseOfflineImage : tr.changeOfflineImage),
          ),
          if (rule.offlineImage != null)
            OutlinedButton(
              onPressed: () => set(rule.copyWith(offlineImage: () => null)),
              child: Text(tr.defaultCard),
            ),
        ]),
      ],
    ]);
  }

  /// A channel's four retro settings, each with its "Main setting" choice.
  List<Widget> _retroRows(Map<String, Object?> c, Map<dynamic, dynamic> view) {
    final own = ChannelRetro.fromJson(c['retro']);
    final used = ResolvedRetro.of(ChannelRetro.main, RetroSettings.fromJson(view['mainRetro']));
    String main(String value) => tr.mainSetting(value);
    Future<void> set(ChannelRetro retro) => _put({'retro': retro.toJson()});
    return [
      Text(_retroNote),
      const SizedBox(height: 12),
      _RetroDropdown<PictureShape?>(
          title: tr.pictureShape2,
          values: [null, ...PictureShape.values],
          value: own.shape,
          label: (v) => v?.label ?? main(used.shape.label),
          onChanged: (v) => set(own.copyWith(shape: () => v))),
      _RetroDropdown<Surround?>(
          title: tr.surround2,
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
        child: TextButton(onPressed: () => _uploadSurround(own), child: Text(tr.chooseSurroundImage)),
      ),
      _RetroDropdown<CrtStyle?>(
          title: tr.crtEffect2,
          values: [null, ...CrtStyle.values],
          value: own.crt,
          label: (v) => v?.label ?? main(used.crt.label),
          onChanged: (v) => set(own.copyWith(crt: () => v))),
      _RetroDropdown<OverlayThemeName?>(
          title: tr.overlayTheme2,
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
  final file = await openFile(acceptedTypeGroups: [
    XTypeGroup(label: tr.images, extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'], mimeTypes: ['image/*']),
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
