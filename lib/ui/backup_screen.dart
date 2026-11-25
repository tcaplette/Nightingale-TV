import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

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
import '../reporting/error_reports.dart';
import 'unlock_screen.dart' show unlockLine, unlockStateOf;

/// Menu → Backup & restore (backup-simplify D8): when the automatic backup
/// was last written, Save to a file, Open a backup file, the phone or
/// computer page, **Undo** (its action) when there is an undo point, and About this
/// install. No list of backups.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final Household _household = HouseholdScope.read(context);
  late final BackupScheduler _backups = _household.backups!;

  /// The automatic backup and the undo point, once read.
  ({StoredBackup? latest, StoredBackup? undo})? _stored;
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
    final latest = await _store.latest();
    final undo = await _store.undo();
    if (mounted) setState(() => _stored = (latest: latest, undo: undo));
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
    } on Object catch (e, stack) {
      ErrorReports.capture(e, stack, area: 'backup');
      if (mounted) setState(() => _error = tr.thatDidntWork(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A fresh backup with every picked file, through the save dialog.
  void _saveFile() => _run(() async {
        final BuiltBackup built;
        try {
          built = await _backups.build(BackupReason.manual, pickedFiles: PickedFiles.all);
        } on Object catch (e, stack) {
          ErrorReports.capture(e, stack, area: 'backup');
          throw BackupException(tr.couldntSaveThe(e));
        }
        await BackupFiles.save(TransferServer.fileName(built.createdAt), built.bytes);
      });

  /// A backup file, checked in memory and confirmed; never kept.
  void _openFile() => _run(() async {
        final bytes = await BackupFiles.open(limit: TransferServer.maxUpload);
        if (bytes == null) return;
        if (bytes.length > TransferServer.maxUpload) throw BackupException(BackupArchive.tooBig);
        if (mounted) await _restore(bytes);
      });

  void _moveSetup(InstallInfo info) => _run(() => moveSetupTo(_household, info));

  void _bringSetup(InstallInfo info) => _run(() => bringSetupFrom(info));

  Future<void> _useOtherDevice() async {
    if (_busy) return;
    final uploaded = await showTransferDialog(context, _backups);
    if (uploaded != null && mounted) await _run(() => _restore(uploaded));
  }

  void _undo(StoredBackup undo) => _run(() async {
        if (mounted) await _restore(await _store.read(undo), title: undoTitle(undo));
      });

  /// Confirms, then restores [bytes]. The household reloads: this screen
  /// goes away, and "Who's watching?" shows the restored profiles.
  Future<void> _restore(Uint8List bytes, {String? title}) async {
    final archive = BackupArchive.check(bytes);
    final plan = await BackupRestorer(_household).plan(archive);
    if (!mounted) return;
    final ok = await confirmRestore(context, archive, plan, title: title);
    if (!ok || !mounted) return;
    // A profile watching stops first; the Unlock screen may have none open.
    final tuner = context.getInheritedWidgetOfExactType<AppScope>()?.tuner;
    await BackupRestorer(_household).restore(bytes, beforeClosing: tuner?.stop);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final stored = _stored;
    final latest = stored?.latest;
    final undo = stored?.undo;
    final layout = ScreenLayout.of(context);
    final install = _install;
    final children = [
      Text(
        stored == null
            ? ' '
            : latest == null
                ? tr.notBackedUpYet
                : tr.lastBackedUp(formatRecent(latest.createdAt.toLocal())),
        style: g.body(30, weight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(tr.aBackupHolds, style: g.body(24, color: g.textDim)),
      const SizedBox(height: 28),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          if (_files) TvButton(label: tr.saveToFile, icon: Icons.save_alt, autofocus: true, onPressed: _saveFile),
          if (_files) TvButton(label: tr.openABackup, icon: Icons.file_open, onPressed: _openFile),
          TvButton(label: tr.useYourPhone, icon: Icons.qr_code_2, autofocus: !_files, onPressed: _useOtherDevice),
          if (undo != null)
            TvButton(
                key: const ValueKey('undo'),
                label: undo.undoLabel,
                icon: Icons.undo,
                onPressed: () => _undo(undo)),
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
      if (install != null)
        AboutThisInstall(
            info: install.withUnlockLine(unlockLine(unlockStateOf(_household))),
            onMove: () => _moveSetup(install),
            onBring: () => _bringSetup(install)),
    ];
    return TvPage(
      title: tr.backupRestore,
      hints: tr.moveOkSelectEsc,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
            padding:
                layout.isPortrait ? layout.pagePadding(EdgeInsets.zero) : const EdgeInsets.fromLTRB(120, 40, 120, 32),
            children: children),
      ),
    );
  }
}

/// The undo point's confirmation title: "Undo lineup reset (Nov 24, 3:05
/// PM)".
String undoTitle(StoredBackup undo) => tr.undoTitle(undo.undoLabel, formatMoment(undo.createdAt.toLocal()));

/// The restore confirmation: what the backup holds, that the current setup
/// is backed up first, who will need their password, and that Live TV
/// export moves here. Cancel has focus. [title] names an undo point.
Future<bool> confirmRestore(BuildContext context, BackupArchive archive, RestorePlan plan, {String? title}) {
  final s = archive.summary;
  final need = plan.needPassword;
  return confirm(
    context,
    title: title ?? tr.restoreTheBackup(formatMoment(archive.createdAt.toLocal())),
    message: [
      tr.backupProfilesChannelsBlocks(s.profiles.join(tr.listSeparator), tr.countChannelsWord(s.channels), tr.countBlocksWord(s.blocks)),
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

String _list(List<String> names) => joinNames(names);

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
/// from the page (checked, not kept), to confirm on the TV.
Future<Uint8List?> showTransferDialog(BuildContext context, BackupScheduler backups) =>
    showDialog<Uint8List>(
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
    final Uint8List? bytes;
    if (source == 'file') {
      bytes = await BackupFiles.open(limit: TransferServer.maxUpload);
      if (bytes != null && bytes.length > TransferServer.maxUpload) throw BackupException(BackupArchive.tooBig);
    } else {
      bytes = await showTransferDialog(context, backups);
    }
    if (bytes == null || !context.mounted) return;
    final archive = BackupArchive.check(bytes);
    final plan = await BackupRestorer(household).plan(archive);
    if (!context.mounted || !await confirmRestore(context, archive, plan) || !context.mounted) return;
    await BackupRestorer(household).restore(bytes);
  } on BackupException catch (e) {
    if (context.mounted) await showMessage(context, title: tr.couldntRestore, message: e.message);
  }
}

/// The first screen on a first run that finds the automatic backup:
/// restore it, or start fresh.
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
                  tr.channels(b.summary.profiles.join(tr.listSeparator), b.summary.channels),
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
    // Upright on a phone: below the status bar and inside the side margins.
    final layout = ScreenLayout.of(context);
    final side = layout.isPortrait ? layout.gutter : 0.0;
    return Stack(
      children: [
        widget.child,
        if (shown != null)
          // Where the TV screen's own messages show, clear of the banner.
          Positioned(
            left: side,
            right: side,
            top: 40 + MediaQuery.paddingOf(context).top,
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
