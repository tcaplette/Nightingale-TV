import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../backup/backup_archive.dart';
import '../backup/backup_restorer.dart';
import '../backup/transfer_server.dart';
import '../platform/install_info.dart';
import '../profiles/household.dart';
import '../theme/tv_theme.dart';
import 'backup_screen.dart' show confirmRestore;
import 'menu_screen.dart' show confirm, showMessage;
import 'profiles_screen.dart' show grownUpCheck;
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// Moving a setup between the official app and the own build on one device
/// (install-switching D5, D6).

/// "Move my setup to …": backs up now, labelled "Moving to …", and hands
/// that backup to the other app, which opens on its restore confirmation.
/// Throws [BackupException] when there's nothing to move or it can't go.
Future<void> moveSetupTo(Household household, InstallInfo info) async {
  final backups = household.backups!;
  if (await household.hasNoSetup()) throw BackupException(_nothingToMove);
  final stored = await () async {
    try {
      return await backups.backUp(info.ownBuild ? BackupReason.movingToOfficial : BackupReason.movingToOwnBuild);
    } on BackupException {
      rethrow;
    } on Object catch (e) {
      throw BackupException(tr.couldntSaveThe(e));
    }
  }();
  if (stored == null) throw BackupException(_nothingToMove);
  if (!await InstallSwitching.moveSetup(await backups.store.read(stored))) {
    throw BackupException(tr.couldntOpen(info.counterpartName));
  }
  household.notice.value = tr.yourSetupIs(info.counterpartName);
}

String get _nothingToMove => tr.nothingIsSet;

/// "Bring my setup here from …": opens the other app on "Send your setup
/// to …?".
Future<void> bringSetupFrom(InstallInfo info) async {
  if (!await InstallSwitching.askForSetup()) throw BackupException(tr.couldntOpen(info.counterpartName));
}

/// A setup the other app handed over: checked like an opened backup file,
/// kept as "From …", then the normal restore confirmation. Throws
/// [BackupException] (nothing restored) when it isn't a backup.
Future<void> receiveSetup(BuildContext context, Household household, InstallInfo info, Uint8List bytes,
    {Future<void> Function()? beforeClosing}) async {
  final backups = household.backups!;
  if (bytes.length > TransferServer.maxUpload) throw BackupException(BackupArchive.tooBig);
  final archive = BackupArchive.check(bytes);
  final stored = await backups.store.save(bytes, kind: info.ownBuild ? BackupReason.fromOfficial : BackupReason.fromOwnBuild);
  backups.changed();
  final plan = await BackupRestorer(household).plan(archive);
  if (!context.mounted || !await confirmRestore(context, stored, plan) || !context.mounted) return;
  await BackupRestorer(household).restore(bytes, beforeClosing: beforeClosing);
}

/// Backup & restore → About this install (Android only): what this install
/// is, what switching means from here, the uninstall warning, and the move
/// buttons while the other app is installed.
class AboutThisInstall extends StatelessWidget {
  const AboutThisInstall({super.key, required this.info, required this.onMove, required this.onBring});

  final InstallInfo info;
  final VoidCallback onMove;
  final VoidCallback onBring;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.aboutThisInstall, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 12),
        Text(info.sourceLine, style: g.body(30, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(info.switching, style: g.body(24, color: g.textDim)),
        const SizedBox(height: 8),
        Text(InstallInfo.uninstallWarning, style: g.body(24, weight: FontWeight.w600, color: g.nowLine)),
        if (info.counterpartInstalled) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              TvButton(
                  label: tr.moveMySetup(info.counterpartName), icon: Icons.move_up, maxLines: 2, onPressed: onMove),
              TvButton(
                  label: tr.bringMySetup(info.counterpartName),
                  icon: Icons.move_down,
                  maxLines: 2,
                  onPressed: onBring),
            ],
          ),
        ],
        const SizedBox(height: 36),
      ],
    );
  }
}

enum _NoticeChoice { move, bring }

/// The both-installed notice (D5): the other app is here too, the setups
/// are separate, don't uninstall before moving. Not now has focus.
Future<_NoticeChoice?> _showBothInstalled(BuildContext context, InstallInfo info) => showDialog<_NoticeChoice>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
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
              width: dialogWidth(context, 1100, padding: dialogPadding(context)),
              child: FocusTraversalGroup(
                child: dialogBody(
                  context,
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.isAlsoOn(info.counterpartName), style: g.display(48, weight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      if (info.ownBuild) ...[
                        Text(tr.thankYouFor, style: g.body(28, weight: FontWeight.w600)),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        tr.andAreSeparate(info.appName, info.counterpartName),
                        style: g.body(28, color: g.textDim),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr.uninstallingEitherOne,
                        style: g.body(28, weight: FontWeight.w600, color: g.nowLine),
                      ),
                      const SizedBox(height: 40),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          TvButton(
                              label: tr.moveMySetup(info.counterpartName),
                              maxLines: 2,
                              icon: Icons.move_up,
                              onPressed: () => Navigator.pop(context, _NoticeChoice.move)),
                          TvButton(
                              label: tr.bringMySetup(info.counterpartName),
                              maxLines: 2,
                              icon: Icons.move_down,
                              onPressed: () => Navigator.pop(context, _NoticeChoice.bring)),
                          TvButton(label: tr.notNow, autofocus: true, onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

/// Above every screen (the app's [MaterialApp.builder]): shows the
/// both-installed notice once per install of the other app, and deals with
/// what the other app hands over (a setup, or a request for this one's).
class InstallSwitchingHost extends StatefulWidget {
  const InstallSwitchingHost({super.key, required this.household, required this.navigator, required this.child});

  final Household household;
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  /// Where the notice remembers the other app's install it was shown for:
  /// the app's data folder, beside the profiles, not in any backup.
  static const noticeFile = 'install_notice.json';

  @override
  State<InstallSwitchingHost> createState() => _InstallSwitchingHostState();
}

class _InstallSwitchingHostState extends State<InstallSwitchingHost> {
  /// The notice is looked at once per run, not per screen stack.
  static bool _noticeChecked = false;

  @visibleForTesting
  static void debugReset() => _noticeChecked = false;

  bool _busy = false;

  Household get _household => widget.household;

  @override
  void initState() {
    super.initState();
    InstallSwitching.listen();
    InstallSwitching.pending.addListener(_onPending);
    FocusManager.instance.addListener(_keepFocusOnTop);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    InstallSwitching.pending.removeListener(_onPending);
    FocusManager.instance.removeListener(_keepFocusOnTop);
    super.dispose();
  }

  /// This host's dialogs can open while the app is still starting: a screen
  /// that arrives under one afterwards (the TV screen, after syncing) takes
  /// focus with its autofocus. Focus goes back to the dialog on top.
  void _keepFocusOnTop() {
    final node = FocusManager.instance.primaryFocus;
    final focused = node?.context;
    if (!_busy || node == null || focused == null || !focused.mounted) return;
    if (ModalRoute.of(focused)?.isCurrent ?? true) {
      _onTop = node;
      return;
    }
    final back = _onCurrentRoute(_onTop) ? _onTop! : _topScope();
    if (back != null) {
      scheduleMicrotask(() {
        back.requestFocus();
        _hideKeyboard();
      });
    }
  }

  static bool _onCurrentRoute(FocusNode? node) {
    final context = node?.context;
    return context != null && context.mounted && (ModalRoute.of(context)?.isCurrent ?? false);
  }

  /// When the dialog's autofocus and a screen's under it land in the same
  /// frame, the dialog never shows as focused, so [_onTop] is unset. Its
  /// focus scope still remembers the control it focused: go back to that.
  static FocusScopeNode? _topScope() {
    for (final node in FocusManager.instance.rootScope.descendants) {
      if (node is FocusScopeNode && node.focusedChild != null && _onCurrentRoute(node)) return node;
    }
    return null;
  }

  /// A text field focused under one of this host's dialogs (a phone's
  /// sign-in) leaves its keyboard over the dialog: hidden.
  static void _hideKeyboard() => unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));

  /// The last control focused on the top route.
  FocusNode? _onTop;

  Future<void> _start() async {
    await _handlePending();
    if (!mounted || _noticeChecked) return;
    _noticeChecked = true;
    await _maybeNotice();
  }

  void _onPending() => unawaited(_handlePending());

  /// The overlay's context: under the navigator, the theme and the canvas.
  BuildContext? get _context => widget.navigator.currentState?.overlay?.context;

  /// Grown-ups only on a kid profile, as for Backup & restore.
  Future<bool> _unlocked(BuildContext context) async =>
      !(_household.current?.isKid ?? false) || await grownUpCheck(context, title: tr.parentalControls);

  Future<void> _handlePending() async {
    final handover = InstallSwitching.pending.value;
    final context = _context;
    if (handover == null || _busy || context == null || _household.backups == null) return;
    InstallSwitching.pending.value = null;
    // A profile watching stops playing before a restore closes it.
    final stopTuner = this.context.getInheritedWidgetOfExactType<AppScope>()?.tuner.stop;
    final info = await InstallSwitching.info();
    if (info == null || !context.mounted) return;
    _busy = true;
    _hideKeyboard();
    try {
      switch (handover) {
        case SetupReceived(:final bytes):
          if (!await _unlocked(context) || !context.mounted) return;
          await receiveSetup(context, _household, info, bytes,
              beforeClosing: stopTuner);
        case SetupRequested():
          if (!await _unlocked(context) || !context.mounted) return;
          final ok = await confirm(context,
              title: tr.sendYourSetup(info.counterpartName),
              message: tr.thisBacksUp(info.counterpartName),
              action: tr.send);
          if (ok) await moveSetupTo(_household, info);
      }
    } on BackupException catch (e) {
      final title = handover is SetupReceived ? tr.couldntRestore : tr.couldntMoveThe;
      if (context.mounted) await showMessage(context, title: title, message: e.message);
    } finally {
      _busy = false;
    }
  }

  Future<void> _maybeNotice() async {
    final info = await InstallSwitching.info();
    final installed = info?.counterpartFirstInstallTime;
    if (info == null || !info.counterpartInstalled || installed == null) return;
    final storage = _household.root;
    final seen = await storage.readJson(InstallSwitchingHost.noticeFile);
    if (seen is Map && seen['counterpartFirstInstallTime'] == installed) return;
    // Remembered before it shows: whatever the choice, once per install.
    await storage.writeJson(InstallSwitchingHost.noticeFile, {'counterpartFirstInstallTime': installed});
    final context = _context;
    if (context == null || !context.mounted || _busy) return;
    _busy = true;
    _hideKeyboard();
    try {
      final choice = await _showBothInstalled(context, info);
      if (choice == null || !context.mounted || !await _unlocked(context)) return;
      switch (choice) {
        case _NoticeChoice.move:
          await moveSetupTo(_household, info);
        case _NoticeChoice.bring:
          await bringSetupFrom(info);
      }
    } on BackupException catch (e) {
      if (context.mounted) await showMessage(context, title: tr.couldntMoveThe, message: e.message);
    } finally {
      _busy = false;
    }
    // A handover that came in meanwhile.
    if (mounted) await _handlePending();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Lets tests show the notice again.
@visibleForTesting
void debugResetInstallNotice() => _InstallSwitchingHostState.debugReset();
