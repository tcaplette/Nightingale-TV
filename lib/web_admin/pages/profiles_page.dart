import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../profiles/profile.dart';
import '../api_client.dart';
import '../app.dart';
import '../session.dart';
import '../widgets/common.dart';

/// Profiles: the ones this account may use; admins add, edit (kind, rating
/// limit, PIN) and remove them.
class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => PageBody(
        title: 'Profiles',
        actions: [
          if (session.isAdmin)
            FilledButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add profile'),
              onPressed: () => _edit(context, null),
            ),
        ],
        children: [
          if (session.profiles.isEmpty) const Text('No profiles are assigned to you yet. Ask an admin.'),
          for (final p in session.profiles) _ProfileCard(profile: p, onEdit: () => _edit(context, p)),
        ],
      ),
    );
  }

  static Future<void> _edit(BuildContext context, ProfileInfo? profile) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ProfileDialog(profile: profile),
    );
    if (changed == true && context.mounted) await context.session.refresh();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit});

  final ProfileInfo profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final session = context.session;
    final p = profile;
    final rating = KidRating.values.asNameMap()[p.json['rating']];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              ProfileDot(profile: p, size: 40),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                Text([
                  p.isKid ? 'Kid · ${rating?.label ?? ''}' : 'Grown-up',
                  if (p.hasPin) 'PIN',
                  if (p.exported) 'Exported',
                ].join(' · ')),
              ]),
            ]),
            Wrap(spacing: 8, children: [
              TextButton(onPressed: () => context.go('/profiles/${p.id}/library'), child: const Text('Library')),
              OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
              if (session.isAdmin)
                TextButton(
                  onPressed: () async {
                    final ok = await confirm(context,
                        title: 'Remove ${p.name}?',
                        message: 'Its channels, blocks and settings are deleted. A backup is saved first.',
                        action: 'Remove');
                    if (!ok || !context.mounted) return;
                    final done = await attempt(context, () => context.api.delete('profiles/${p.id}'));
                    if (done != null && context.mounted) await context.session.refresh();
                  },
                  child: const Text('Remove'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Adding or editing a profile: name and colour for everyone; kind, rating
/// limit and PIN for admins.
class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.profile});
  final ProfileInfo? profile;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final _name = TextEditingController(text: widget.profile?.name ?? '');
  // A new profile takes the next colour, as on the TV.
  late int _color = widget.profile?.color ?? context.session.profiles.length % avatarColors.length;
  late ProfileKind _kind = widget.profile?.isKid == true ? ProfileKind.kid : ProfileKind.adult;
  late KidRating _rating = KidRating.values.asNameMap()[widget.profile?.json['rating']] ?? KidRating.kids;
  final _pin = TextEditingController();
  bool _removePin = false;
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    final admin = context.session.isAdmin;
    final p = widget.profile;
    final body = <String, Object?>{
      'name': _name.text.trim(),
      'color': _color,
      if (admin) 'kind': _kind.name,
      if (admin && _kind == ProfileKind.kid) 'rating': _rating.name,
      if (admin && _pin.text.isNotEmpty) 'pin': _pin.text,
      if (admin && _removePin && _pin.text.isEmpty) 'pin': null,
    };
    if (_pin.text.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'A PIN is 4 digits.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.api;
      await (p == null ? api.post('profiles', body) : api.put('profiles/${p.id}', body));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiConflict {
      if (mounted) setState(() => _error = conflictText);
    } on ApiException catch (e) {
      if (e.needs == 'grownUp' && p != null && mounted && await unlock(context, p.id, grownUp: true)) {
        if (mounted) setState(() => _busy = false);
        return _save();
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.session.isAdmin;
    final p = widget.profile;
    return AlertDialog(
      title: Text(p == null ? 'Add profile' : 'Edit ${p.name}'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 16),
          Text('Colour', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (var i = 0; i < avatarColors.length; i++)
              ChoiceChip(
                label: const Text(' '),
                avatar: CircleAvatar(backgroundColor: avatarColors[i]),
                selected: _color == i,
                onSelected: (_) => setState(() => _color = i),
                tooltip: 'Colour ${i + 1}',
              ),
          ]),
          if (admin) ...[
            const SizedBox(height: 16),
            SegmentedButton<ProfileKind>(
              segments: const [
                ButtonSegment(value: ProfileKind.adult, label: Text('Grown-up')),
                ButtonSegment(value: ProfileKind.kid, label: Text('Kid')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.single),
            ),
            if (_kind == ProfileKind.kid) ...[
              const SizedBox(height: 12),
              RadioGroup<KidRating>(
                groupValue: _rating,
                onChanged: (v) => setState(() => _rating = v!),
                child: Column(children: [
                  for (final r in KidRating.values)
                    RadioListTile<KidRating>(value: r, title: Text(r.label), subtitle: Text(r.description)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: p?.hasPin == true ? 'New PIN (leave empty to keep it)' : 'PIN (optional)',
              ),
            ),
            if (p?.hasPin == true)
              CheckboxListTile(
                value: _removePin,
                onChanged: (v) => setState(() => _removePin = v ?? false),
                title: const Text('Remove the PIN'),
              ),
          ],
          ErrorText(_error),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

/// A profile's library: what it holds and a refresh, with its progress.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.profileId});
  final String profileId;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  Map<String, Object?>? _summary;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = (await context.api.get('profiles/${widget.profileId}/library'))! as Map<String, Object?>;
      if (!mounted) return;
      setState(() => _summary = s);
      _poll?.cancel();
      // A refresh shows its progress until it's done.
      if (s['syncing'] == true) _poll = Timer(const Duration(seconds: 2), _load);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final name = context.session.profileById(widget.profileId)?.name ?? '';
    if (s == null) {
      return PageBody(title: 'Library', children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final fetched = DateTime.tryParse(s['fetchedAt'] as String? ?? '')?.toLocal();
    return PageBody(title: '$name: library', children: [
      Section(children: [
        Text(s['signedIn'] == true ? 'From ${s['server']} as ${s['user']}.' : 'Not signed in.'),
        const SizedBox(height: 8),
        Text('${s['series']} shows · ${s['episodes']} episodes · ${s['movies']} movies · ${s['songs']} songs · '
            '${s['musicVideos']} music videos · ${s['commercials']} commercial videos'),
        if (fetched != null) Text('Read ${MaterialLocalizations.of(context).formatMediumDate(fetched)} '
            '${TimeOfDay.fromDateTime(fetched).format(context)}.'),
        if (s['error'] != null) ErrorText(s['error'] as String),
        const SizedBox(height: 12),
        Row(children: [
          FilledButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('Refresh library'),
            onPressed: s['syncing'] == true || s['signedIn'] != true
                ? null
                : () async {
                    final r = await attempt(context, () => context.api.post('profiles/${widget.profileId}/library/refresh'),
                        profileId: widget.profileId);
                    if (r != null) await _load();
                  },
          ),
          if (s['syncing'] == true)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Busy(text: (s['status'] as String?)?.isNotEmpty == true ? s['status'] as String : 'Refreshing…'),
              ),
            ),
        ]),
      ]),
    ]);
  }
}
