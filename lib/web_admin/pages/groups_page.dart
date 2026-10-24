import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/common.dart';

/// Channel groups and the guide's tabs: make, rename, fill and delete
/// groups; move and hide tabs (All stays first and shown).
class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final base = 'profiles/$profileId';
    return DataView<(Map<String, Object?>, List<Map<String, Object?>>)>(
      load: () async {
        final api = context.api;
        final groups = (await api.get('$base/groups'))! as Map<String, Object?>;
        final channels = (await api.get('$base/channels'))! as Map<String, Object?>;
        return (groups, (channels['channels'] as List).cast<Map<String, Object?>>());
      },
      builder: (context, data, reload) {
        final (groupsData, channels) = data;
        final groups = (groupsData['groups'] as List).cast<Map<String, Object?>>();
        final tabs = (groupsData['tabs'] as List).cast<Map<String, Object?>>();
        Future<void> run(Future<Object?> Function() call) async {
          final r = await attempt(context, call, profileId: profileId, onConflict: reload);
          if (r != null) await reload();
        }

        Future<void> putTabs({List<String>? order, Set<String>? hidden}) => run(() => context.api.put('$base/tabs', {
              'order': ?order,
              if (hidden != null) 'hidden': hidden.toList(),
            }));
        final hidden = {for (final t in tabs) if (t['hidden'] == true) t['id'] as String};
        final order = [for (final t in tabs) t['id'] as String];
        return PageBody(
          title: 'Channel groups',
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New group'),
              onPressed: () async {
                final name = await askText(context, title: 'New group', label: 'Name', action: 'Make');
                if (name != null && context.mounted) await run(() => context.api.post('$base/groups', {'name': name}));
              },
            ),
          ],
          children: [
            Section(title: 'Guide tabs', children: [
              const Text('The order of the tabs in the guide, and which are shown.'),
              for (final (i, t) in tabs.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t['name'] as String),
                  subtitle: t['group'] == true ? const Text('Your group') : null,
                  leading: Checkbox(
                    value: t['hidden'] != true,
                    onChanged: t['id'] == 'all'
                        ? null
                        : (on) => putTabs(hidden: on == true ? ({...hidden}..remove(t['id'])) : {...hidden, t['id'] as String}),
                  ),
                  trailing: t['id'] == 'all'
                      ? null
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Move up',
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: i <= 1 ? null : () => putTabs(order: [...order]..insert(i - 1, order[i])..removeAt(i + 1)),
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: i >= order.length - 1
                                ? null
                                : () => putTabs(order: [...order]..insert(i + 2, order[i])..removeAt(i)),
                          ),
                        ]),
                ),
            ]),
            for (final g in groups)
              Section(
                title: g['name'] as String,
                trailing: PopupMenuButton<String>(
                  tooltip: 'Group actions',
                  onSelected: (action) async {
                    if (action == 'rename') {
                      final name = await askText(context, title: 'Rename group', label: 'Name', initial: g['name'] as String);
                      if (name != null && context.mounted) {
                        await run(() => context.api.put('$base/groups/${Uri.encodeComponent(g['id'] as String)}', {'name': name}));
                      }
                    } else {
                      final ok = await confirm(context,
                          title: 'Delete ${g['name']}?', message: 'Its channels stay in the lineup.', action: 'Delete');
                      if (ok && context.mounted) {
                        await run(() => context.api.delete('$base/groups/${Uri.encodeComponent(g['id'] as String)}'));
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                children: [
                  Text('${(g['channelIds'] as List?)?.length ?? 0} channels'),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await _pickChannels(context, channels, {...((g['channelIds'] as List?) ?? const []).cast<String>()});
                        if (picked != null && context.mounted) {
                          await run(() => context.api.put(
                              '$base/groups/${Uri.encodeComponent(g['id'] as String)}/channels', {'channelIds': picked}));
                        }
                      },
                      child: const Text('Choose channels…'),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// The channels in a group, in lineup order; null when cancelled.
  static Future<List<String>?> _pickChannels(
      BuildContext context, List<Map<String, Object?>> channels, Set<String> selected) {
    final chosen = {...selected};
    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Channels in this group'),
          content: SizedBox(
            width: 420,
            height: 480,
            child: ListView.builder(
              itemCount: channels.length,
              itemBuilder: (context, i) {
                final c = channels[i];
                final id = c['id'] as String;
                return CheckboxListTile(
                  value: chosen.contains(id),
                  title: Text('${c['number']}  ${c['name']}'),
                  onChanged: (on) => setState(() => on == true ? chosen.add(id) : chosen.remove(id)),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop([for (final c in channels) if (chosen.contains(c['id'])) c['id'] as String]),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
