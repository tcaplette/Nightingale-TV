// portrait-layout's no-overflow sweep: every screen and dialog an Android
// phone or tablet shows, drawn upright at 360×740, 412×915 and 800×1280
// with long names. A RenderFlex overflow, or a control cut off at a side of
// the screen, fails.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/ui/source_picker_screen.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/ui/backup_screen.dart';
import 'package:nightingale_tv/ui/blocks_screen.dart';
import 'package:nightingale_tv/ui/break_plan_editor_screen.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/channel_groups_screen.dart';
import 'package:nightingale_tv/ui/commercials_screen.dart';
import 'package:nightingale_tv/ui/folder_picker_screen.dart';
import 'package:nightingale_tv/ui/icon_picker_screen.dart';
import 'package:nightingale_tv/ui/login_screen.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/pin_dialog.dart';
import 'package:nightingale_tv/ui/playback_screen.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/ui/pool_editor_screen.dart';
import 'package:nightingale_tv/ui/profiles_screen.dart';
import 'package:nightingale_tv/ui/sync_screen.dart';
import 'package:nightingale_tv/ui/widgets/screen_layout.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'language_arb_support.dart';
import 'portrait_harness.dart';

/// Opens what's checked, in an app showing [PortraitHarness.show].
typedef Opener = Future<void> Function(WidgetTester tester, PortraitHarness h);

void main() => layoutSweep();

/// The sweep at [windows]; `language_fit_test.dart` also runs it in every
/// language and on a TV.
void layoutSweep({List<Size> windows = const [narrowPhone, pixel8, tabletUpright], bool television = false}) {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Lets real work (files, the fake server) and timers move on.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scrolls the page until [target] is built and in view.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.scrollUntilVisible(target, 300, scrollable: page);
    await tester.pump();
  }

  /// Shows [screen] as the app's home.
  Opener screen(Widget Function(PortraitHarness h) screen) => (tester, h) async {
        await h.show(tester, screen(h));
        await settle(tester);
      };

  /// Shows a button that runs [open] (a dialog, or a pushed screen), and
  /// taps it.
  Opener over(void Function(BuildContext context, PortraitHarness h) open) => (tester, h) async {
        await h.show(
          tester,
          Builder(
            builder: (context) => Center(
              child: TextButton(onPressed: () => open(context, h), child: const Text('open')),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await settle(tester);
      };

  /// [first], then taps [label] (scrolled into view) on what it shows.
  Opener thenTap(Opener first, String label) => (tester, h) async {
        await first(tester, h);
        await reveal(tester, find.text(translated(label)));
        await tester.tap(find.text(translated(label)).last);
        await settle(tester);
      };

  Opener push(Widget Function(PortraitHarness h) screen) =>
      over((context, h) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen(h))));

  /// No control has a side off the screen (ones in a list that scrolls
  /// sideways can).
  void expectNothingCutOff(WidgetTester tester, Size window) {
    for (final element in find.byType(TvFocusable).evaluate()) {
      final scrollsSideways = element.findAncestorStateOfType<ScrollableState>()?.position.axis == Axis.horizontal;
      if (scrollsSideways) continue;
      final box = element.renderObject! as RenderBox;
      if (!box.hasSize || !box.attached) continue;
      final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
      final label = element.findAncestorWidgetOfExactType<TvButton>()?.label ?? element.widget.toStringShort();
      expect(rect.left, greaterThanOrEqualTo(-0.5), reason: '$label starts off the left of the screen');
      expect(rect.right, lessThanOrEqualTo(window.width + 0.5), reason: '$label ends off the right of the screen');
    }
  }

  final checks = <String, Opener>{
    'menu': screen((_) => const MenuScreen()),
    'sign-in': screen((_) => const LoginScreen(message: 'Couldn\'t reach the server at http://192.168.1.10:8096')),
    'sync': screen((_) => const SyncScreen()),
    'profile picker': screen((_) => const ProfilePickerScreen()),
    'profiles': screen((_) => const ProfilesScreen()),
    'profile editor': screen((h) => ProfileEditorScreen(profile: h.household.profiles.first)),
    'new profile': screen((_) => const ProfileEditorScreen()),
    'channels & icons': screen((_) => const ChannelEditorScreen()),
    'a channel\'s page': (tester, h) async {
      await screen((_) => const ChannelEditorScreen())(tester, h);
      await tester.tap(find.text(h.app.allChannels[1].name).first);
      await settle(tester);
      expect(find.byType(TvTextField), findsOneWidget, reason: 'the channel\'s page is open');
    },
    'channel groups': screen((_) => const ChannelGroupsScreen()),
    'group editor': (tester, h) async {
      await tester.runAsync(() => h.app.createGroup('My extremely long group name for testing'));
      await screen((h) => GroupEditorScreen(group: h.app.settings.groups.first))(tester, h);
    },
    'programming blocks': screen((_) => const BlocksScreen()),
    'block editor': screen((h) => BlockEditorScreen(block: h.app.blocks.firstOrNull)),
    'new block': screen((_) => const BlockEditorScreen()),
    'late-night block': screen((_) => const BlockEditorScreen(lateNight: true)),
    'lineup': thenTap(screen((_) => const BlockEditorScreen()), 'A lineup'),
    'show picker': thenTap(thenTap(screen((_) => const BlockEditorScreen()), 'A lineup'), 'Add a show'),
    'channel picker': (tester, h) async {
      await screen((_) => const BlockEditorScreen())(tester, h);
      await tester.tap(find.byIcon(Icons.tv).first);
      await settle(tester);
      expect(find.text(translated('Choose a channel').toUpperCase()), findsOneWidget, reason: 'the picker is open');
    },
    'new channel': screen((_) => const SourcePickerScreen(
        title: 'New channel', initial: ChannelSource(includeEpisodes: false), name: 'My Channel', order: PlaybackOrder.random)),
    'content picker': thenTap(screen((_) => const BlockEditorScreen()), 'Choose shows & movies'),
    'premieres': screen((_) => const PremiereEditorScreen()),
    'commercials': screen((_) => const CommercialsScreen()),
    'pool editor': (tester, h) async {
      final pool = await tester.runAsync(() => h.app.createPool());
      await screen((_) => PoolEditorScreen(pool: pool!))(tester, h);
    },
    'bumper pool editor': (tester, h) async {
      final pool = await tester.runAsync(() async {
        final pool = await h.app.createPool();
        await h.app.setPoolKind(pool, PoolKind.bumpers);
        return pool;
      });
      await screen((_) => PoolEditorScreen(pool: pool!))(tester, h);
    },
    'break plan editor': screen((h) =>
        BreakPlanEditorScreen(initial: h.app.settings.commercialPlan.roles, title: 'Breaks on Star Trek: Deep Space Nine')),
    'playback': screen((_) => const PlaybackScreen()),
    'backup & restore': (tester, h) async {
      await tester.runAsync(() => h.household.backups!.backUp(BackupReason.manual));
      await screen((_) => const BackupScreen())(tester, h);
    },
    'welcome back': (tester, h) async {
      await tester.runAsync(() => h.household.backups!.backUp(BackupReason.manual));
      final stored = await tester.runAsync(() => h.household.backups!.store.list());
      await screen((_) => WelcomeBackScreen(backup: stored!.first))(tester, h);
    },
    'folder picker': screen((_) => const FolderPickerScreen(initial: [], poolName: 'Commercials and bumpers')),
    'icon picker': screen((h) => IconPickerScreen(channel: h.app.allChannels.first)),
    'message': over((context, _) => showMessage(context,
        title: 'Couldn\'t restore',
        message: 'The backup file is damaged or isn\'t a Nightingale TV backup. Try another one.')),
    'confirm': over((context, _) => confirm(context,
        title: 'Reset channel lineup?',
        message: 'Rebuilds the default channels from your library. Names, icons and numbers you changed are reset.',
        action: 'Reset')),
    'PIN': over((context, _) => askPin(context, title: 'Parental controls', message: 'Enter a grown-up\'s PIN.', check: (_) => false)),
    'group name': over((context, _) => askName(context, title: 'New channel group', action: 'Create')),
    'restore from a backup': over((context, _) => restoreOnFirstRun(context)),
    'backup actions': (tester, h) async {
      await tester.runAsync(() => h.household.backups!.backUp(BackupReason.manual));
      await screen((_) => const BackupScreen())(tester, h);
      await reveal(tester, find.textContaining(translated('Made by you')).first);
      await tester.tap(find.textContaining(translated('Made by you')).first);
      await settle(tester);
      expect(find.text(translated('Restore')), findsOneWidget);
    },
    'transfer': push((_) => const _TransferHost()),
  };

  for (final window in windows) {
    group('at ${window.width.toInt()}×${window.height.toInt()}', () {
      for (final MapEntry(key: name, value: open) in checks.entries) {
        testWidgets(name, (tester) async {
          runAs(TargetPlatform.android, television: television);
          setWindow(tester, window);
          final h = await PortraitHarness.start(tester);
          await open(tester, h);
          expect(ScreenLayout.of(tester.element(find.byType(Material).last)).isPortrait, !television);
          expect(tester.takeException(), isNull, reason: 'nothing overflows');
          expectNothingCutOff(tester, window);
          // Scrolled to the end, nothing overflows either.
          for (final s in find.byType(Scrollable).evaluate().toList()) {
            final state = (s as StatefulElement).state as ScrollableState;
            if (state.position.axis == Axis.vertical && state.position.hasContentDimensions) {
              state.position.jumpTo(state.position.maxScrollExtent);
            }
          }
          await settle(tester);
          expect(tester.takeException(), isNull, reason: 'nothing overflows further down');
          expectNothingCutOff(tester, window);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(minutes: 1));
          expect(PlatformInfo.isAndroid, isTrue);
        });
      }
    });
  }
}

/// Opens the phone-or-computer dialog at once.
class _TransferHost extends StatefulWidget {
  const _TransferHost();

  @override
  State<_TransferHost> createState() => _TransferHostState();
}

class _TransferHostState extends State<_TransferHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showTransferDialog(context, HouseholdScope.read(context).backups!);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
