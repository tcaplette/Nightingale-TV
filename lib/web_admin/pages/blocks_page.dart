import 'dart:async';

import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../channels/program_block.dart';
import '../../ui/format.dart';
import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';
import '../widgets/source_editor.dart';

/// A profile's programming blocks.
class BlocksPage extends StatelessWidget {
  const BlocksPage({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) => DataView<Map<String, Object?>>(
        load: () async => (await context.api.get('profiles/$profileId/blocks'))! as Map<String, Object?>,
        builder: (context, data, reload) {
          final blocks = (data['blocks'] as List).cast<Map<String, Object?>>();
          return PageBody(
            title: 'Programming blocks',
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New block'),
                onPressed: () => context.go('/profiles/$profileId/blocks/new'),
              ),
              // Kid profiles get no late-night shortcut (late-night-drift D6).
              if (data['kidProfile'] != true)
                OutlinedButton.icon(
                  icon: const Icon(Icons.nightlight_round),
                  label: const Text('New late-night block'),
                  onPressed: () => context.go('/profiles/$profileId/blocks/late-night'),
                ),
            ],
            children: [
              if (blocks.isEmpty)
                const Text('A block takes over a channel at set times: "Saturday Morning Cartoons", Saturdays 7 AM to noon.'),
              for (final b in blocks)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text((b['title'] as String).isEmpty ? 'Untitled block' : b['title'] as String),
                    subtitle: Text([
                      (b['view'] as Map)['describe'],
                      'on ${(b['view'] as Map)['channel'] ?? 'a channel that is gone'}',
                      if (b['enabled'] == false) 'Off',
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/profiles/$profileId/blocks/${Uri.encodeComponent(b['id'] as String)}'),
                  ),
                ),
            ],
          );
        },
      );
}

/// One block, with the same fields and rules as the TV's blocks screen.
/// `new` makes one; `late-night` makes one filled in by the late-night
/// shortcut (late-night-drift D4).
class BlockEditorPage extends StatefulWidget {
  const BlockEditorPage({super.key, required this.profileId, required this.blockId});

  final String profileId;
  final String blockId;

  @override
  State<BlockEditorPage> createState() => _BlockEditorPageState();
}

class _BlockEditorPageState extends State<BlockEditorPage> {
  ProgramBlock? _block;
  bool _lineupMode = false;
  bool _newChannel = false;
  bool _kidProfile = false;

  /// The late-night shortcut's source and order follow the chosen channel
  /// until the user changes either.
  bool _followChannel = false;
  List<Map<String, Object?>> _channels = const [];
  Map<String, Object?>? _catalog;
  Map<String, Object?>? _preview;
  String? _error;
  bool _saving = false;
  Timer? _previewSoon;
  final _title = TextEditingController();

  bool get _lateNight => widget.blockId == 'late-night';
  bool get _isNew => widget.blockId == 'new' || _lateNight;
  String get _base => 'profiles/${widget.profileId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _previewSoon?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.api;
      final blocks = (await api.get('$_base/blocks'))! as Map<String, Object?>;
      final channels = (await api.get('$_base/channels'))! as Map<String, Object?>;
      final catalog = (await api.get('$_base/library/catalog'))! as Map<String, Object?>;
      final json = _isNew
          ? (blocks['newBlock'] as Map).cast<String, Object?>()
          : (blocks['blocks'] as List)
              .cast<Map<String, Object?>>()
              .firstWhere((b) => b['id'] == widget.blockId, orElse: () => throw ApiException(404, 'No such block.'));
      if (!mounted) return;
      final block = ProgramBlock.fromJson({...json, 'playlist': const <String>[]});
      final shown = [
        for (final c in (channels['channels'] as List).cast<Map<String, Object?>>())
          if ((c['view'] as Map)['live'] == null) c,
      ];
      final kid = blocks['kidProfile'] == true;
      final follow = _lateNight && !kid;
      if (follow) lateNightDefaults(block);
      setState(() {
        _block = block;
        _channels = shown;
        _kidProfile = kid;
        _followChannel = follow;
        if (follow) _copyChannel(block, block.channelId);
        _title.text = block.title;
        _lineupMode = block.hasLineup;
        _catalog = catalog;
        _error = null;
      });
      _refreshPreview();
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// The late-night shortcut: channel [id]'s source and order, keeping the
  /// chosen minimum rating.
  void _copyChannel(ProgramBlock b, String id) {
    final json = _channels.where((c) => c['id'] == id).firstOrNull;
    if (json == null) return;
    final channel = Channel.fromJson(json);
    final floor = b.source.ratingFloor;
    b.source = lateNightSource(channel).copyWith(ratingFloor: () => floor);
    b.order = lateNightOrder(channel, PlaybackOrder.cyclic);
  }

  void _update(void Function(ProgramBlock b) change) {
    setState(() => change(_block!));
    _previewSoon?.cancel();
    _previewSoon = Timer(const Duration(milliseconds: 400), _refreshPreview);
  }

  /// The block as the server takes it, with the editor's choices.
  Map<String, Object?> _requestBody() => {
        ..._block!.toJson(),
        'title': _title.text.trim(),
        'lineup': _lineupMode ? [for (final s in _block!.lineup) s.toJson()] : const <Object?>[],
        'newChannel': _newChannel,
        'lineupMode': _lineupMode,
      };

  Future<void> _refreshPreview() async {
    if (_block == null) return;
    try {
      final body = _requestBody();
      final r = (await context.api.post('$_base/blocks/preview',
          {'block': body, 'newChannel': _newChannel, 'lineupMode': _lineupMode}))! as Map<String, Object?>;
      if (mounted) setState(() => _preview = r);
    } on ApiException {
      // The preview is a help; saving says what's wrong.
    }
  }

  /// Saves under the server's rules (the TV's), showing why it can't.
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = context.api;
    final body = _requestBody();
    for (var tries = 0; tries < 2; tries++) {
      try {
        await (_isNew ? api.post('$_base/blocks', body) : api.put('$_base/blocks/${Uri.encodeComponent(widget.blockId)}', body));
        if (mounted) context.go('/profiles/${widget.profileId}/blocks');
        return;
      } on ApiConflict {
        if (mounted) showMessage(context, conflictText);
        await _load();
        break;
      } on ApiException catch (e) {
        if (tries == 0 && e.needs != null && mounted && await unlock(context, widget.profileId, grownUp: e.needs == 'grownUp')) {
          continue;
        }
        if (mounted) setState(() => _error = e.message);
        break;
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = _block;
    if (b == null) {
      return PageBody(title: 'Programming block', children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final catalog = _catalog!;
    final shows = (catalog['shows'] as List).cast<Map<String, Object?>>();
    final showName = {for (final s in shows) s['key']: s['name'] as String};
    final preview = _preview;
    final next = preview?['next'] as Map?;
    return PageBody(
      title: _lateNight ? 'New late-night block' : _isNew ? 'New block' : (b.title.isEmpty ? 'Untitled block' : b.title),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.arrow_back),
          label: const Text('Blocks'),
          onPressed: () => context.go('/profiles/${widget.profileId}/blocks'),
        ),
      ],
      children: [
        Section(children: [
          TextField(
            controller: _title,
            autofocus: _isNew,
            decoration: const InputDecoration(labelText: 'Title', hintText: 'Saturday Morning Cartoons'),
            onChanged: (_) => _update((_) {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _newChannel ? '' : (_channels.any((c) => c['id'] == b.channelId) ? b.channelId : null),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Channel'),
            items: [
              if (_isNew) const DropdownMenuItem(value: '', child: Text('A new channel for this block')),
              for (final c in _channels)
                DropdownMenuItem(value: c['id'] as String, child: Text('${c['number']}  ${c['name']}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (id) => _update((b) {
              _newChannel = id == '';
              if (id != null && id.isNotEmpty) {
                b.channelId = id;
                if (_followChannel) _copyChannel(b, id);
              }
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('On'),
            value: b.enabled,
            onChanged: (v) => _update((b) => b.enabled = v),
          ),
        ]),
        Section(title: 'When', children: [
          DayPicker(days: b.days, onChanged: (d) => _update((b) => b.days = d)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            MinuteField(label: 'Starts', minute: b.startMinute, onChanged: (m) => _update((b) => b.startMinute = m)),
            MinuteField(label: 'Ends', minute: b.endMinute, onChanged: (m) => _update((b) => b.endMinute = m)),
          ]),
          if (b.endMinute <= b.startMinute && b.endMinute != b.startMinute)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Runs past midnight into the next day.')),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Only part of the year'),
            subtitle: b.hasSeason ? Text('${b.seasonStart} – ${b.seasonEnd}') : null,
            value: b.hasSeason,
            onChanged: (on) => _update((b) {
              b.seasonStart = on ? const MonthDay(12, 1) : null;
              b.seasonEnd = on ? const MonthDay(12, 25) : null;
            }),
          ),
          if (b.hasSeason)
            Wrap(spacing: 16, runSpacing: 8, children: [
              _MonthDayField(label: 'From', value: b.seasonStart!, onChanged: (v) => _update((b) => b.seasonStart = v)),
              _MonthDayField(label: 'To', value: b.seasonEnd!, onChanged: (v) => _update((b) => b.seasonEnd = v)),
            ]),
        ]),
        Section(title: 'What it plays', children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('A mix')),
              ButtonSegment(value: true, label: Text('A lineup of shows')),
            ],
            selected: {_lineupMode},
            onSelectionChanged: (s) => _update((_) => _lineupMode = s.single),
          ),
          const SizedBox(height: 12),
          if (!_lineupMode) ...[
            SourceEditor(
              profileId: widget.profileId,
              source: b.source,
              catalog: catalog,
              // The source editor doesn't know the minimum rating; it stays.
              onChanged: (source) => _update((b) {
                b.source = source.copyWith(ratingFloor: () => b.source.ratingFloor);
                _followChannel = false;
              }),
            ),
            RadioGroup<PlaybackOrder>(
              groupValue: b.order,
              onChanged: (v) => _update((b) {
                b.order = v!;
                _followChannel = false;
              }),
              child: Column(children: [
                for (final o in PlaybackOrder.values)
                  RadioListTile<PlaybackOrder>(contentPadding: EdgeInsets.zero, value: o, title: Text(o.label)),
              ]),
            ),
            if (!_kidProfile) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<RatingFloor?>(
                key: ValueKey(b.source.ratingFloor),
                initialValue: b.source.ratingFloor,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Minimum rating',
                  helperText: b.source.ratingFloor == null
                      ? null
                      : 'Only shows and movies rated this or higher. Unrated ones are left out.',
                ),
                items: [
                  const DropdownMenuItem<RatingFloor?>(value: null, child: Text('Any rating')),
                  for (final f in RatingFloor.values) DropdownMenuItem<RatingFloor?>(value: f, child: Text(f.label)),
                ],
                onChanged: (f) => _update((b) => b.source = b.source.copyWith(ratingFloor: () => f)),
              ),
            ],
          ] else ...[
            const Text("Each airing plays every spot's next episodes in order, then starts over if time is left."),
            const SizedBox(height: 8),
            for (final (i, slot) in b.lineup.indexed)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                    Text('${i + 1}. ${showName[slot.seriesKey] ?? slot.seriesKey}'),
                    DropdownButton<int>(
                      value: slot.count,
                      items: [
                        for (var n = 1; n <= LineupSlot.maxCount; n++)
                          DropdownMenuItem(value: n, child: Text('$n episode${n == 1 ? '' : 's'}')),
                      ],
                      onChanged: (n) => _update((_) => slot.count = n!),
                    ),
                    IconButton(
                      tooltip: 'Earlier',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: i == 0 ? null : () => _update((b) => b.lineup.insert(i - 1, b.lineup.removeAt(i))),
                    ),
                    IconButton(
                      tooltip: 'Later',
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: i == b.lineup.length - 1 ? null : () => _update((b) => b.lineup.insert(i + 1, b.lineup.removeAt(i))),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close),
                      onPressed: () => _update((b) => b.lineup.removeAt(i)),
                    ),
                  ]),
                ),
              ),
            DropdownButtonFormField<String>(
              key: ValueKey(b.lineup.length),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Add a show'),
              items: [
                for (final s in shows) DropdownMenuItem(value: s['key'] as String, child: Text(s['name'] as String)),
              ],
              onChanged: (key) {
                if (key != null) _update((b) => b.lineup.add(LineupSlot(seriesKey: key)));
              },
            ),
          ],
        ]),
        Section(title: 'Preview', children: [
          if (preview == null)
            const Busy(text: 'Working out what it plays…')
          else ...[
            Text('${preview['total']} programs in its playlist.'),
            if (next != null) ...[
              const SizedBox(height: 8),
              Text('Next airing: ${formatDate(DateTime.parse(next['start'] as String).toLocal())} '
                  '${formatRange(DateTime.parse(next['start'] as String).toLocal(), DateTime.parse(next['end'] as String).toLocal())}'),
              for (final p in (next['programs'] as List).cast<Map>().take(8))
                Text('${formatTime(DateTime.parse(p['start'] as String).toLocal())}  ${p['title']}'
                    '${(p['detail'] as String?)?.isNotEmpty == true ? ' · ${p['detail']}' : ''}'),
            ],
            if (preview['problem'] != null) ErrorText(preview['problem'] as String),
          ],
        ]),
        ErrorText(_error),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(icon: const Icon(Icons.check), label: const Text('Save'), onPressed: _saving ? null : _save),
          if (!_isNew)
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              onPressed: () async {
                final ok = await confirm(context,
                    title: 'Delete "${b.title}"?',
                    message: 'The channel goes back to its regular programming at these times.',
                    action: 'Delete');
                if (!ok || !context.mounted) return;
                final r = await attempt(context, () => context.api.delete('$_base/blocks/${Uri.encodeComponent(widget.blockId)}'),
                    profileId: widget.profileId, onConflict: _load);
                if (r != null && context.mounted) context.go('/profiles/${widget.profileId}/blocks');
              },
            ),
        ]),
      ],
    );
  }
}

class _MonthDayField extends StatelessWidget {
  const _MonthDayField({required this.label, required this.value, required this.onChanged});

  final String label;
  final MonthDay value;
  final ValueChanged<MonthDay> onChanged;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label '),
        DropdownButton<int>(
          value: value.month,
          items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(_months[m - 1]))],
          onChanged: (m) => onChanged(MonthDay(m!, value.day.clamp(1, MonthDay.daysIn(m)))),
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: value.day,
          items: [for (var d = 1; d <= MonthDay.daysIn(value.month); d++) DropdownMenuItem(value: d, child: Text('$d'))],
          onChanged: (d) => onChanged(MonthDay(value.month, d!)),
        ),
      ]);
}
