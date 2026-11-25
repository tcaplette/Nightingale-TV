import 'dart:async';

import 'package:flutter/material.dart';

import '../app_exit.dart';
import '../app_scope.dart';
import '../l10n/tr.dart';
import '../profiles/household.dart';
import '../store/store.dart';
import '../store/unlock.dart';
import '../theme/tv_theme.dart';
import 'backup_screen.dart';
import 'menu_screen.dart' show showMessage;
import 'profiles_screen.dart' show grownUpCheck;
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// The Play version's free trial and unlock purchase on screen
/// (play-unlock D6).

/// The household's unlock state, or [UnlockState.notLocked] where there is
/// none (the free flavor, own builds, Linux, most tests).
UnlockState unlockStateOf(Household household) => household.unlock?.value ?? UnlockState.notLocked;

/// "Unlock" with Play's price once Play has given one.
String unlockLabel(UnlockState state) => switch (state.price) {
      final price? => tr.unlockForPrice(price),
      null => tr.unlock,
    };

/// A grown-up's PIN first on a kid profile, as for Backup & restore.
Future<bool> _grownUp(BuildContext context) async {
  final household = HouseholdScope.read(context);
  return !(household.current?.isKid ?? false) || await grownUpCheck(context, title: tr.parentalControls);
}

/// Buys the unlock: the PIN on a kid profile, then Google Play's purchase.
/// Owned unlocks at once with a thank-you; pending and failed purchases say
/// so; a cancelled one says nothing.
Future<void> buyUnlock(BuildContext context) async {
  final household = HouseholdScope.read(context);
  final unlock = household.unlock;
  if (unlock == null || !await _grownUp(context) || !context.mounted) return;
  // From the Unlock screen, an owned or pending purchase opens the TV.
  final fromUnlockScreen = unlock.value.blocked;
  final result = await unlock.buy();
  switch (result.outcome) {
    case BuyOutcome.owned:
      household.notice.value = tr.unlockedThankYou;
    case BuyOutcome.pending:
      // From the Unlock screen, the purchase has just opened the TV, whose
      // screen takes focus as it comes up: a dialog over it couldn't be
      // reached with a remote. The notice shows on any screen and needs no
      // focus.
      if (fromUnlockScreen || !context.mounted) {
        household.notice.value = tr.purchasePendingText;
      } else {
        await showMessage(context, title: tr.purchasePending, message: tr.purchasePendingText);
      }
    case BuyOutcome.error:
      // A failed purchase changes nothing, so the screen it came from is
      // still there.
      if (context.mounted) {
        await showMessage(context, title: tr.purchaseNotCompleted, message: tr.purchaseNotCompletedText);
      }
    case BuyOutcome.cancelled:
      break;
  }
}

/// Redeems a Play promo code (play-promo-codes D1): the PIN on a kid
/// profile, then Play's redeem page. Where nothing opens it (typical on a
/// TV), a message says to redeem on a phone or computer, then Check my
/// purchase again. The redeemed code arrives as a purchase and unlocks.
Future<void> redeemCode(BuildContext context) async {
  final unlock = HouseholdScope.read(context).unlock;
  if (unlock == null || !await _grownUp(context) || !context.mounted) return;
  if (await unlock.redeem() || !context.mounted) return;
  await showMessage(context, title: tr.redeemCodeTitle, message: tr.redeemCodeText);
}

/// Replaces the home screen (sign-in, profile picker or TV) while the trial
/// is over and nothing is bought. Playback stops first. When the state turns
/// unlocked or pending, the home screen comes back without a restart, and
/// the TV screen tunes the last channel as it does on every start.
class UnlockGate extends StatefulWidget {
  const UnlockGate({super.key, required this.household, required this.child});

  final Household household;
  final Widget child;

  @override
  State<UnlockGate> createState() => _UnlockGateState();
}

class _UnlockGateState extends State<UnlockGate> {
  Unlock? get _unlock => widget.household.unlock;

  /// Whether the Unlock screen was showing at the last change.
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    _unlock?.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(UnlockGate old) {
    super.didUpdateWidget(old);
    if (old.household.unlock != _unlock) {
      old.household.unlock?.removeListener(_changed);
      _unlock?.addListener(_changed);
      _sync();
    }
  }

  @override
  void dispose() {
    _unlock?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(_sync);
  }

  /// On turning blocked (only then, so Backup & restore opened from the
  /// Unlock screen stays open): playback stops, and the screens over the
  /// home screen close.
  void _sync() {
    final blocked = unlockStateOf(widget.household).blocked;
    if (blocked && !_blocked) {
      final tuner = context.getInheritedWidgetOfExactType<AppScope>()?.tuner;
      if (tuner != null) unawaited(tuner.stop());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.maybeOf(context)?.popUntil((r) => r.isFirst);
      });
    }
    _blocked = blocked;
  }

  @override
  Widget build(BuildContext context) =>
      _blocked ? const UnlockScreen(key: ValueKey('unlock')) : widget.child;
}

/// The Unlock screen (play-unlock D6): the trial has ended, buy or check
/// again, or take the setup out with Backup & restore. Back is Exit.
class UnlockScreen extends StatelessWidget {
  const UnlockScreen({super.key});

  static const buyKey = ValueKey('unlock-buy');
  static const redeemKey = ValueKey('unlock-redeem');
  static const checkKey = ValueKey('unlock-check');
  static const backupKey = ValueKey('unlock-backup');
  static const exitKey = ValueKey('unlock-exit');

  static final _notLocked = ValueNotifier(UnlockState.notLocked);

  Future<void> _exit(BuildContext context) async {
    final tuner = context.getInheritedWidgetOfExactType<AppScope>()?.tuner;
    await quitApp(beforeClosing: tuner?.stop);
  }

  Future<void> _check(BuildContext context) async {
    final unlock = HouseholdScope.read(context).unlock;
    if (unlock == null) return;
    await unlock.refresh();
    if (context.mounted && unlock.value.blocked) {
      await showMessage(context, title: tr.noPurchaseFound, message: tr.noPurchaseFoundText);
    }
  }

  Future<void> _backup(BuildContext context) async {
    if (!await _grownUp(context) || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BackupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final household = HouseholdScope.of(context);
    final g = context.guide;
    final portrait = ScreenLayout.of(context).isPortrait;
    return ValueListenableBuilder<UnlockState>(
      valueListenable: household.unlock ?? _notLocked,
      builder: (context, state, _) {
        final buttons = [
          TvButton(
              key: buyKey,
              label: unlockLabel(state),
              icon: Icons.lock_open,
              expand: true,
              autofocus: true,
              onPressed: () => unawaited(buyUnlock(context))),
          TvButton(
              key: redeemKey,
              label: tr.redeemPlayCode,
              icon: Icons.redeem,
              expand: true,
              onPressed: () => unawaited(redeemCode(context))),
          TvButton(
              key: checkKey,
              label: tr.checkMyPurchaseAgain,
              icon: Icons.refresh,
              expand: true,
              maxLines: 2,
              onPressed: () => unawaited(_check(context))),
          if (household.backups != null)
            TvButton(
                key: backupKey,
                label: tr.backupRestore,
                icon: Icons.settings_backup_restore,
                expand: true,
                onPressed: () => unawaited(_backup(context))),
          TvButton(
              key: exitKey,
              label: tr.exitNightingaleTv,
              icon: Icons.power_settings_new,
              expand: true,
              danger: true,
              onPressed: () => unawaited(_exit(context))),
        ];
        return TvPage(
          title: tr.unlockNightingaleTv,
          hints: tr.moveOkSelectEscBack,
          onBack: () => unawaited(_exit(context)),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: ScreenLayout.of(context).gutter, vertical: portrait ? 32 : 56),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr.freeTrialEnded, style: g.display(portrait ? 44 : 56, weight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    Text(tr.unlockScreenText, style: g.body(30, color: g.textDim)),
                    const SizedBox(height: 48),
                    FocusTraversalGroup(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, b) in buttons.indexed) ...[
                              if (i > 0) const SizedBox(height: 18),
                              b,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The menu's **Unlock Nightingale TV** (play-unlock D6), after Error
/// reports, with **Redeem a Play code** under it (play-promo-codes D2): the
/// days left, or Purchase pending (then no Redeem). Outside the kid
/// profile's menu lock; buying and redeeming ask for the PIN there. Nothing
/// when unlocked or not a locked install.
class UnlockMenuItem extends StatelessWidget {
  const UnlockMenuItem({super.key});

  static const buttonKey = ValueKey('menu-unlock');
  static const redeemKey = ValueKey('menu-redeem');

  @override
  Widget build(BuildContext context) {
    final unlock = HouseholdScope.of(context).unlock;
    if (unlock == null) return const SizedBox.shrink();
    return ValueListenableBuilder<UnlockState>(
      valueListenable: unlock,
      builder: (context, state, _) {
        if (!state.offersUnlock) return const SizedBox.shrink();
        final g = context.guide;
        final pending = state.status == UnlockStatus.pending;
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TvButton(
                key: buttonKey,
                label: tr.unlockNightingaleTv,
                icon: pending ? Icons.hourglass_top : Icons.lock_open,
                expand: true,
                // A pending purchase is on its way: nothing to buy.
                onPressed: pending ? null : () => unawaited(buyUnlock(context)),
              ),
              if (!pending) ...[
                const SizedBox(height: 18),
                TvButton(
                  key: redeemKey,
                  label: tr.redeemPlayCode,
                  icon: Icons.redeem,
                  expand: true,
                  onPressed: () => unawaited(redeemCode(context)),
                ),
              ],
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  pending ? tr.purchasePending : tr.trialDaysLeftMenu(state.daysLeft),
                  style: g.body(24, color: g.textDim),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// About this install's unlock line, or null when the install isn't locked.
String? unlockLine(UnlockState state) => switch (state.status) {
      UnlockStatus.unlocked => tr.unlockedThankYou,
      UnlockStatus.trial => tr.freeTrialDaysLeftAbout(state.daysLeft),
      UnlockStatus.expired => tr.freeTrialEnded,
      UnlockStatus.pending => tr.purchasePending,
      UnlockStatus.notLocked => null,
    };

/// The welcome notice and the reminders, each once (play-unlock D6), the
/// first time the TV screen comes up in a run. Unlock now buys.
abstract final class UnlockNotices {
  static bool _checked = false;

  @visibleForTesting
  static void debugReset() => _checked = false;

  static const unlockNowKey = ValueKey('notice-unlock');
  static const dismissKey = ValueKey('notice-dismiss');

  /// Shows the notice that's due, if any; once per run.
  static Future<void> maybeShow(BuildContext context) async {
    final unlock = HouseholdScope.read(context).unlock;
    if (unlock == null || _checked) return;
    _checked = true;
    final notice = await unlock.takeNotice();
    if (notice == null || !context.mounted) return;
    final state = unlock.value;
    final price = state.price;
    final (title, message, dismiss) = switch (notice) {
      UnlockNotice.welcome => (
          tr.freeForDaysTitle,
          price != null ? tr.welcomeTrialPrice(price) : tr.welcomeTrial,
          tr.startMyFreeTrial,
        ),
      UnlockNotice.threeDaysLeft => (
          tr.trialDaysLeftMenu(state.daysLeft),
          price != null ? tr.reminderPrice(price) : tr.reminder,
          tr.notNow,
        ),
      UnlockNotice.lastDay => (
          tr.lastDayOfTrial,
          price != null ? tr.reminderPrice(price) : tr.reminder,
          tr.notNow,
        ),
    };
    final buy = await showDialog<bool>(
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
              width: dialogWidth(context, 1000, padding: dialogPadding(context)),
              child: FocusTraversalGroup(
                child: dialogBody(
                  context,
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: g.display(48, weight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      Text(message, style: g.body(28, color: g.textDim)),
                      const SizedBox(height: 40),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          TvButton(
                              key: unlockNowKey,
                              label: tr.unlockNow,
                              icon: Icons.lock_open,
                              onPressed: () => Navigator.pop(context, true)),
                          // Not pushy: the trial's own choice has focus.
                          TvButton(
                              key: dismissKey,
                              label: dismiss,
                              autofocus: true,
                              onPressed: () => Navigator.pop(context, false)),
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
    if (buy == true && context.mounted) await buyUnlock(context);
  }
}
