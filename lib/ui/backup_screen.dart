import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_scope.dart';
import '../backup/backup_archive.dart';
import '../backup/backup_restorer.dart';
import '../backup/backup_scheduler.dart';
import '../backup/backup_store.dart';
import '../backup/transfer_server.dart';
import '../platform/backup_files.dart';
import '../platform/install_info.dart';
import '../profiles/household.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'install_switching.dart';
import 'menu_screen.dart' show confirm, showMessage;
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// Menu → Backup & restore (backup-restore D11): Back up now, opening a
/// file, the phone or computer page, and every backup, newest first, each
/// with Restore, Save to file and Delete.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

enum _Action { restore, save, delete }

class _BackupScreenState extends State<BackupScreen> {
  late final Household _household = HouseholdScope.read(context);
  late final BackupScheduler _backups = _household.backups!;

  List<StoredBackup>? _list;
  bool _files = false;

  /// Android: About this install.
  InstallInfo? _install;
  bool _busy = false;
  String? _error;

  BackupStore get _store => _backups.store;

  @override
  void initState() {
    super.initState();
    _backups.addListener(_reload);
    unawaited(_reload());
    unawaited(BackupFiles.available().then((on) {
      if (mounted) setState(() => _files = on);
    }));
    unawaited(_loadInstall());
  }

  Future<void> _loadInstall() async {
    final info = await InstallSwitching.info();
    if (mounted) setState(() => _install = info);
  }

  @override
  void dispose() {
    _backups.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await _store.list();
    if (mounted) setState(() => _list = list);
  }

  /// Runs [task] with the busy line showing, and its [BackupException] (or
  /// any failure) as the error line. Presses meanwhile are ignored; the
  /// buttons stay enabled, so focus stays where the remote left it.
  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } on BackupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = tr.thatDidntWork(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backUpNow() => _run(() async {
        try {
          await _backups.backUp(BackupReason.manual);
        } on BackupException {
          rethrow;
        } on Object catch (e) {
          throw BackupException(tr.couldntSaveThe(e));
        }
        await _reload();
      });

  void _openFile() => _run(() async {
        final bytes = await BackupFiles.open(limit: TransferServer.maxUpload);
        if (bytes == null) return;
        if (bytes.length > TransferServer.maxUpload) throw BackupException(BackupArchive.tooBig);
        BackupArchive.check(bytes);
        final stored = await _store.save(bytes, kind: BackupReason.file);
        _backups.changed();
        if (mounted) await _restore(stored);
      });

  void _moveSetup(InstallInfo info) => _run(() => moveSetupTo(_household, info));

  void _bringSetup(InstallInfo info) => _run(() => bringSetupFrom(info));

  Future<void> _useOtherDevice() async {
    if (_busy) return;
    final uploaded = await showTransferDialog(context, _backups);
    if (uploaded != null && mounted) await _run(() => _restore(uploaded));
  }

  Future<void> _pick(StoredBackup b) async {
    if (_busy) return;
    final action = await _showActions(context, b, canSave: _files);
    if (!mounted) return;
    switch (action) {
      case _Action.restore:
        await _run(() => _restore(b));
      case _Action.save:
        await _run(() async {
          await BackupFiles.save(TransferServer.fileName(b.createdAt), await _store.read(b));
        });
      case _Action.delete:
        final ok = await confirm(context,
            title: tr.deleteThisBackup,
            message: tr.itCantBe(formatMoment(b.createdAt.toLocal()), b.kindLabel),
            action: tr.delete);
        if (!ok || !mounted) return;
        await _run(() async => _store.delete(b));
        _backups.changed();
      case null:
        break;
    }
  }

  /// Confirms, then restores [b]. The household reloads: this screen goes
  /// away, and "Who's watching?" shows the restored profiles.
  Future<void> _restore(StoredBackup b) async {
    final bytes = await _store.read(b);
    final archive = BackupArchive.check(bytes);
    final plan = await BackupRestorer(_household).plan(archive);
    if (!mounted) return;
    final ok = await confirmRestore(context, b, plan);
    if (!ok || !mounted) return;
    await BackupRestorer(_household).restore(bytes, beforeClosing: AppScope.tunerOf(context).stop);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final list = _list;
    final last = list == null ? null : BackupStore.newestOwn(list);
    final layout = ScreenLayout.of(context);
    final rows = [
      for (final b in list ?? const <StoredBackup>[])
        Padding(
          key: ValueKey(b.name),
          padding: const EdgeInsets.only(bottom: 12),
          child: _BackupRow(backup: b, onPressed: () => _pick(b)),
        ),
    ];
    final install = _install;
    final top = [
              if (install != null)
                AboutThisInstall(info: install, onMove: () => _moveSetup(install), onBring: () => _bringSetup(install)),
              Text(
                last == null
                    ? (list == null ? ' ' : tr.noBackupsYet)
                    : tr.lastBackup(formatRecent(last.createdAt.toLocal()), last.kindInSentence),
                style: g.body(30, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                tr.aBackupHolds,
                style: g.body(24, color: g.textDim),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  TvButton(label: tr.backUpNow, icon: Icons.backup, autofocus: true, onPressed: _backUpNow),
                  if (_files) TvButton(label: tr.openABackup, icon: Icons.file_open, onPressed: _openFile),
                  TvButton(label: tr.useYourPhone, icon: Icons.qr_code_2, onPressed: _useOtherDevice),
                ],
              ),
              SizedBox(
                height: 64,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _busy
                      ? SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: g.accent))
                      : _error == null
                          ? null
                          : Text(_error!, style: g.body(26, weight: FontWeight.w600, color: g.nowLine)),
                ),
              ),
              Text(tr.backups, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
              const SizedBox(height: 12),
    ];
    return TvPage(
      title: tr.backupRestore,
      hints: tr.moveOkSelectEsc,
      onBack: () => Navigator.of(context).pop(),
      // Upright, and below About this install, everything scrolls together.
      child: layout.isPortrait || install != null
          ? FocusTraversalGroup(
              child: ListView(
                  padding: layout.isPortrait
                      ? layout.pagePadding(EdgeInsets.zero)
                      : const EdgeInsets.fromLTRB(120, 40, 120, 32),
                  children: [...top, ...rows]),
            )
          : Padding(
        padding: const EdgeInsets.fromLTRB(120, 40, 120, 32),
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...top,
              Expanded(
                child: list == null
                    ? const SizedBox.shrink()
                    : ListView(children: rows),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// One backup in the list: when, what kind, what's in it.
class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.backup, required this.onPressed});

  final StoredBackup backup;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final b = backup;
    return TvFocusable(
      onPressed: onPressed,
      builder: (context, focused) {
        final fg = focused ? g.onFocus : g.text;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(
            color: focused ? g.focus : g.cell,
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
          ),
          // Upright: the date, then what kind and what's in it.
          child: ScreenLayout.of(context).isPortrait
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatMoment(b.createdAt.toLocal()), style: g.display(30, weight: FontWeight.w700, color: fg)),
                    Text('${b.kindLabel} · ${b.summary.line}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: g.body(24, color: focused ? g.onFocus : g.textDim)),
                  ],
                )
              : Row(
            children: [
              SizedBox(
                width: 380,
                child: Text(formatMoment(b.createdAt.toLocal()), style: g.display(30, weight: FontWeight.w700, color: fg)),
              ),
              SizedBox(
                width: 420,
                child: Text(b.kindLabel,
                    overflow: TextOverflow.ellipsis, style: g.body(26, weight: FontWeight.w600, color: fg)),
              ),
              Expanded(
                child: Text(b.summary.line,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: g.body(26, color: focused ? g.onFocus : g.textDim)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A picked backup's actions: Restore, Save to file (where the device can
/// save files) and Delete.
Future<_Action?> _showActions(BuildContext context, StoredBackup b, {required bool canSave}) => showDialog<_Action>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        final g = context.guide;
        return _Panel(
          children: [
            Text(formatMoment(b.createdAt.toLocal()), style: g.display(48, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${b.kindLabel} · ${b.summary.line}', style: g.body(28, color: g.textDim)),
            if (b.archive.device.isNotEmpty) Text(tr.madeOn(b.archive.device), style: g.body(24, color: g.textDim)),
            const SizedBox(height: 40),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                TvButton(
                    label: tr.restore,
                    icon: Icons.settings_backup_restore,
                    autofocus: true,
                    onPressed: () => Navigator.pop(context, _Action.restore)),
                if (canSave)
                  TvButton(label: tr.saveToFile, icon: Icons.save_alt, onPressed: () => Navigator.pop(context, _Action.save)),
                TvButton(
                    label: tr.delete, icon: Icons.delete, danger: true, onPressed: () => Navigator.pop(context, _Action.delete)),
                TvButton(label: tr.cancel, onPressed: () => Navigator.pop(context)),
              ],
            ),
          ],
        );
      },
    );

/// The restore confirmation (D11): what the backup holds, that the current
/// setup is backed up first, who will need their password, and that Live
/// TV export moves here. Cancel has focus.
Future<bool> confirmRestore(BuildContext context, StoredBackup b, RestorePlan plan) {
  final s = b.summary;
  final need = plan.needPassword;
  return confirm(
    context,
    title: tr.restoreTheBackup(formatMoment(b.createdAt.toLocal())),
    message: [
      tr.backupProfilesChannelsBlocks(s.profiles.join(', '), tr.countChannelsWord(s.channels), tr.countBlocksWord(s.blocks)),
      if (plan.backsUpFirst)
        tr.itReplacesEverything
      else
        tr.itSetsUp,
      if (need.isNotEmpty) tr.willNeedTo(_list(need)),
      if (plan.exportMoves) tr.liveTvExportMoves,
    ].join('\n\n'),
    action: tr.restore,
  );
}

String _list(List<String> names) =>
    names.length <= 1 ? names.join() : tr.and(names.sublist(0, names.length - 1).join(', '), names.last);

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.width = 980});

  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Dialog(
      backgroundColor: g.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(g.radius * 2),
        side: BorderSide(color: g.cellBorder, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(dialogPadding(context)),
        child: SizedBox(
          width: dialogWidth(context, width, padding: dialogPadding(context)),
          child: FocusTraversalGroup(
            child: dialogBody(context,
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children)),
          ),
        ),
      ),
    );
  }
}

/// "Use your phone or computer" (D12): a QR code and the address of the
/// transfer page, which runs while this is open. Returns a backup uploaded
/// from the page, to confirm on the TV.
Future<StoredBackup?> showTransferDialog(BuildContext context, BackupScheduler backups) =>
    showDialog<StoredBackup>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _TransferDialog(backups: backups),
    );

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.backups});

  final BackupScheduler backups;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late final TransferServer _server = TransferServer(
    widget.backups,
    onUpload: (b) {
      if (mounted) Navigator.of(context).pop(b);
    },
    onIdle: () {
      if (mounted) setState(() => _error = tr.thePageStopped);
    },
  );
  Uri? _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server.start().then((url) {
      if (mounted) setState(() => _url = url);
    }, onError: (Object e) {
      if (mounted) setState(() => _error = tr.couldntOpenANetwork);
    });
  }

  @override
  void dispose() {
    unawaited(_server.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final url = _url;
    final portrait = ScreenLayout.of(context).isPortrait;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.onAPhone,
          style: g.body(28, color: g.textDim),
        ),
        const SizedBox(height: 16),
        if (url != null) Text('$url', style: g.display(40, weight: FontWeight.w800)),
        const SizedBox(height: 16),
        Text(
          tr.thereYouCan,
          style: g.body(26, color: g.textDim),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: g.body(26, weight: FontWeight.w600, color: g.nowLine)),
        ],
        const SizedBox(height: 32),
        TvButton(label: tr.close, autofocus: true, onPressed: () => Navigator.pop(context)),
      ],
    );
    Widget code(double size) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(g.radius * 2)),
          child: QrImageView(data: '$url', size: size, backgroundColor: Colors.white),
        );
    return _Panel(
      width: 1300,
      children: [
        Text(tr.useYourPhone, style: g.display(48, weight: FontWeight.w800)),
        const SizedBox(height: 24),
        if (portrait) ...[
          // Upright: the code under the words.
          words,
          if (url != null) ...[const SizedBox(height: 32), Center(child: code(300))],
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: words),
              if (url != null) ...[const SizedBox(width: 48), code(360)],
            ],
          ),
      ],
    );
  }
}

/// "Restore from a backup" on a new install's sign-in (D14): a backup from
/// a file, where the device has a file picker, or from a phone or computer.
Future<void> restoreOnFirstRun(BuildContext context) async {
  final household = HouseholdScope.read(context);
  final backups = household.backups!;
  final files = await BackupFiles.available();
  if (!context.mounted) return;
  final source = await showDialog<String>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final g = context.guide;
      return _Panel(
        children: [
          Text(tr.restoreFromA, style: g.display(48, weight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(
            tr.setUpThis,
            style: g.body(28, color: g.textDim),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              if (files)
                TvButton(
                    label: tr.openABackup,
                    icon: Icons.file_open,
                    autofocus: true,
                    onPressed: () => Navigator.pop(context, 'file')),
              TvButton(
                  label: tr.useYourPhone,
                  icon: Icons.qr_code_2,
                  autofocus: !files,
                  onPressed: () => Navigator.pop(context, 'phone')),
              TvButton(label: tr.cancel, onPressed: () => Navigator.pop(context)),
            ],
          ),
        ],
      );
    },
  );
  if (source == null || !context.mounted) return;
  try {
    StoredBackup? stored;
    if (source == 'file') {
      final bytes = await BackupFiles.open(limit: TransferServer.maxUpload);
      if (bytes == null) return;
      if (bytes.length > TransferServer.maxUpload) throw BackupException(BackupArchive.tooBig);
      BackupArchive.check(bytes);
      stored = await backups.store.save(bytes, kind: BackupReason.file);
      backups.changed();
    } else {
      stored = await showTransferDialog(context, backups);
    }
    if (stored == null || !context.mounted) return;
    final bytes = await backups.store.read(stored);
    final plan = await BackupRestorer(household).plan(BackupArchive.check(bytes));
    if (!context.mounted || !await confirmRestore(context, stored, plan) || !context.mounted) return;
    await BackupRestorer(household).restore(bytes);
  } on BackupException catch (e) {
    if (context.mounted) await showMessage(context, title: tr.couldntRestore, message: e.message);
  }
}

/// The first screen on a first run that finds a backup (D14): restore the
/// newest, or start fresh with the backups kept.
class WelcomeBackScreen extends StatefulWidget {
  const WelcomeBackScreen({super.key, required this.backup});

  final StoredBackup backup;

  @override
  State<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends State<WelcomeBackScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _go(Future<void> Function(Household h) task) async {
    // Buttons stay enabled (and focused) while busy; presses are ignored.
    if (_busy) return;
    final household = HouseholdScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task(household);
    } on BackupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final b = widget.backup;
    final device = b.archive.device;
    final layout = ScreenLayout.of(context);
    final portrait = layout.isPortrait;
    final restore = TvButton(
      label: tr.restoreIt,
      icon: Icons.settings_backup_restore,
      autofocus: true,
      onPressed: () => _go((h) async => BackupRestorer(h).restore(await h.backups!.store.read(b))),
    );
    final fresh = TvButton(label: tr.startFresh, onPressed: () => _go((h) => h.startFresh()));
    return TvPage(
      title: 'Nightingale TV',
      hints: tr.moveOkSelect,
      child: Center(
        child: SingleChildScrollView(
          // Upright, between the gutters, scrolling if it must.
          padding: portrait ? EdgeInsets.symmetric(horizontal: layout.gutter, vertical: 32) : null,
          child: SizedBox(
          width: portrait ? min(1200.0, layout.canvas.width - 2 * layout.gutter) : 1200,
          child: FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.welcomeBack, style: g.display(portrait ? 56 : 80, weight: FontWeight.w800)),
                const SizedBox(height: 24),
                Text(tr.theresABackup, style: g.body(30, color: g.textDim)),
                const SizedBox(height: 16),
                Text(
                  [if (device.isNotEmpty) device, formatMoment(b.createdAt.toLocal())].join(' · '),
                  style: g.display(44, weight: FontWeight.w700),
                ),
                Text(
                  tr.channels(b.summary.profiles.join(', '), b.summary.channels),
                  style: g.body(30),
                ),
                const SizedBox(height: 20),
                Text(
                  tr.restoringBringsBack,
                  style: g.body(26, color: g.textDim),
                ),
                const SizedBox(height: 40),
                if (portrait)
                  Wrap(spacing: 20, runSpacing: 16, children: [restore, fresh])
                else
                  Row(children: [restore, const SizedBox(width: 20), fresh]),
                SizedBox(
                  height: 72,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _busy
                        ? SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: g.accent))
                        : _error == null
                            ? null
                            : Text(_error!, style: g.body(26, weight: FontWeight.w600, color: g.nowLine)),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Shows the household's [Household.notice] ("Restored the backup
/// from…") over whatever screen is up, for a few seconds.
class HouseholdNotice extends StatefulWidget {
  const HouseholdNotice({super.key, required this.household, required this.child});

  final Household household;
  final Widget child;

  @override
  State<HouseholdNotice> createState() => _HouseholdNoticeState();
}

class _HouseholdNoticeState extends State<HouseholdNotice> {
  String? _shown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.household.notice.addListener(_onNotice);
    _onNotice();
  }

  @override
  void dispose() {
    widget.household.notice.removeListener(_onNotice);
    _timer?.cancel();
    super.dispose();
  }

  void _onNotice() {
    final message = widget.household.notice.value;
    if (message == null) return;
    // Shown once; the next screen doesn't show it again.
    scheduleMicrotask(() => widget.household.notice.value = null);
    _timer?.cancel();
    setState(() => _shown = message);
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _shown = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Stack(
      children: [
        widget.child,
        if (shown != null)
          // Where the TV screen's own messages show, clear of the banner.
          Positioned(
            left: 0,
            right: 0,
            top: 40,
            child: IgnorePointer(
              child: Center(child: _NoticeBox(message: shown)),
            ),
          ),
      ],
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(g.radius * 2),
        border: Border.all(color: g.accent, width: 3),
      ),
      child: Text(message, style: g.display(32, weight: FontWeight.w700)),
    );
  }
}
