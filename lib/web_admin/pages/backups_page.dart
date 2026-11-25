import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../browser.dart';
import '../widgets/common.dart';
import '../../backup/undo_label.dart';
import '../../l10n/tr.dart';

/// Backups (admin, backup-simplify D9): when the server last backed up,
/// download one now, upload one and restore it, and the undo point
/// (restore or download). No list of saved backups.
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
        message: tr.fromItReplaces('${summary['when']}', '${summary['device']}', (summary['profiles'] as List).join(tr.listSeparator)),
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
          final latest = data['latest'] as Map<String, Object?>?;
          final undo = data['undo'] as Map<String, Object?>?;
          return PageBody(title: tr.backups2, children: [
            Section(children: [
              Text(latest == null ? tr.notBackedUpYet : tr.lastBackedUp('${latest['when']}')),
              const SizedBox(height: 8),
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
            if (undo != null)
              Section(title: undoLabel('${undo['reason']}', undo['subject'] as String?), children: [
                Text(tr.undoPointSaved('${undo['when']}', (undo['profiles'] as List).join(tr.listSeparator))),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.undo),
                    label: Text(tr.restore),
                    onPressed: _restoring
                        ? null
                        : () async {
                            final ok = await confirm(context,
                                title: tr.undoTitle(undoLabel('${undo['reason']}', undo['subject'] as String?), '${undo['when']}'),
                                message: tr.itReplacesThe,
                                action: tr.restore);
                            if (ok && context.mounted) await _restoring_(() => context.api.post('backups/undo/restore'), reload);
                          },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: Text(tr.download),
                    onPressed: () => openDownload(context.api.href('backups/undo')),
                  ),
                ]),
              ]),
          ]);
        },
      );
}
