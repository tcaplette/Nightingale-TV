import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../browser.dart';
import '../widgets/common.dart';
import '../../l10n/tr.dart';

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
    final file = await openFile(acceptedTypeGroups: [
      XTypeGroup(label: tr.nightingaleTvBackups, extensions: ['ntvbackup']),
    ]);
    if (file == null || !mounted) return;
    final api = context.api;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final summary = await attempt(context, () => api.upload('restore', bytes));
    if (summary is! Map || !mounted) return;
    final ok = await confirm(context,
        title: tr.restoreThisBackup,
        message: tr.fromItReplaces('${summary['when']}', '${summary['device']}', (summary['profiles'] as List).join(', ')),
        action: tr.restore);
    if (!ok || !mounted) return;
    await _restoring_(() => api.post('restore/${summary['id']}/confirm'), reload);
  }

  Future<void> _restoring_(Future<Object?> Function() call, Future<void> Function() reload) async {
    setState(() => _restoring = true);
    final r = await attempt(context, call);
    if (!mounted) return;
    setState(() => _restoring = false);
    if (r != null) {
      showMessage(context, tr.restoredTheBackup2);
      await context.session.refresh();
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) => DataView<Map<String, Object?>>(
        load: () async => (await context.api.get('backups'))! as Map<String, Object?>,
        builder: (context, data, reload) {
          final backups = (data['backups'] as List).cast<Map<String, Object?>>();
          return PageBody(title: tr.backups2, children: [
            Section(children: [
              Text(tr.aBackupHoldsThe),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: Text(tr.downloadABackup),
                  onPressed: () => openDownload(context.api.href('backup')),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restore),
                  label: Text(tr.restoreFromAFile),
                  onPressed: _restoring ? null : () => _restoreFile(reload),
                ),
                if (_restoring) Busy(text: tr.restoring),
              ]),
            ]),
            Section(title: tr.savedOnThe, children: [
              if (backups.isEmpty) Text(tr.noneYetOne),
              for (final b in backups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${b['when']} · ${b['kind']}'),
                  subtitle: Text(tr.channels6((b['profiles'] as List).join(', '), '${b['channels']}', '${b['device']}')),
                  trailing: PopupMenuButton<String>(
                    tooltip: tr.backupActions,
                    onSelected: (action) async {
                      final name = Uri.encodeComponent(b['name'] as String);
                      switch (action) {
                        case 'restore':
                          final ok = await confirm(context,
                              title: tr.restoreThisBackup,
                              message: tr.itReplacesThe,
                              action: tr.restore);
                          if (ok && context.mounted) await _restoring_(() => context.api.post('backups/$name/restore'), reload);
                        case 'download':
                          openDownload(context.api.href('backups/$name'));
                        case 'delete':
                          final ok = await confirm(context, title: tr.deleteThisBackup, message: '${b['when']}', action: tr.delete);
                          if (ok && context.mounted) {
                            final r = await attempt(context, () => context.api.delete('backups/$name'));
                            if (r != null) await reload();
                          }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'restore', child: Text(tr.restore)),
                      PopupMenuItem(value: 'download', child: Text(tr.download)),
                      PopupMenuItem(value: 'delete', child: Text(tr.delete)),
                    ],
                  ),
                ),
            ]),
          ]);
        },
      );
}
