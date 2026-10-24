import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../browser.dart';
import '../widgets/common.dart';

/// Backups (admin): download one now, upload one and restore it, and the
/// server's saved backups (restore, download, delete).
class BackupsPage extends StatefulWidget {
  const BackupsPage({super.key});

  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  bool _restoring = false;

  Future<void> _restoreFile(Future<void> Function() reload) async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Nightingale TV backups', extensions: ['ntvbackup']),
    ]);
    if (file == null || !mounted) return;
    final api = context.api;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final summary = await attempt(context, () => api.upload('restore', bytes));
    if (summary is! Map || !mounted) return;
    final ok = await confirm(context,
        title: 'Restore this backup?',
        message: 'From ${summary['when']} (${summary['device']}): ${(summary['profiles'] as List).join(', ')}. '
            'It replaces the profiles, channels and settings here.',
        action: 'Restore');
    if (!ok || !mounted) return;
    await _restoring_(() => api.post('restore/${summary['id']}/confirm'), reload);
  }

  Future<void> _restoring_(Future<Object?> Function() call, Future<void> Function() reload) async {
    setState(() => _restoring = true);
    final r = await attempt(context, call);
    if (!mounted) return;
    setState(() => _restoring = false);
    if (r != null) {
      showMessage(context, 'Restored the backup.');
      await context.session.refresh();
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) => DataView<Map<String, Object?>>(
        load: () async => (await context.api.get('backups'))! as Map<String, Object?>,
        builder: (context, data, reload) {
          final backups = (data['backups'] as List).cast<Map<String, Object?>>();
          return PageBody(title: 'Backups', children: [
            Section(children: [
              const Text('A backup holds the profiles, channels, blocks, logos, export settings and user accounts '
                  '(never passwords or sign-in tokens).'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download a backup now'),
                  onPressed: () => openDownload(context.api.href('backup')),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore from a file…'),
                  onPressed: _restoring ? null : () => _restoreFile(reload),
                ),
                if (_restoring) const Busy(text: 'Restoring…'),
              ]),
            ]),
            Section(title: 'Saved on the server', children: [
              if (backups.isEmpty) const Text('None yet. One is saved each day the household changes.'),
              for (final b in backups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${b['when']} · ${b['kind']}'),
                  subtitle: Text('${(b['profiles'] as List).join(', ')} · ${b['channels']} channels · ${b['device']}'),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Backup actions',
                    onSelected: (action) async {
                      final name = Uri.encodeComponent(b['name'] as String);
                      switch (action) {
                        case 'restore':
                          final ok = await confirm(context,
                              title: 'Restore this backup?',
                              message: 'It replaces the profiles, channels and settings here.',
                              action: 'Restore');
                          if (ok && context.mounted) await _restoring_(() => context.api.post('backups/$name/restore'), reload);
                        case 'download':
                          openDownload(context.api.href('backups/$name'));
                        case 'delete':
                          final ok = await confirm(context, title: 'Delete this backup?', message: '${b['when']}', action: 'Delete');
                          if (ok && context.mounted) {
                            final r = await attempt(context, () => context.api.delete('backups/$name'));
                            if (r != null) await reload();
                          }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'restore', child: Text('Restore')),
                      PopupMenuItem(value: 'download', child: Text('Download')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
            ]),
          ]);
        },
      );
}
