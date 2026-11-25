// portrait-layout's no-overflow sweep: every screen and dialog an Android
// phone or tablet shows, drawn upright at 360×740, 412×915 and 800×1280
// with long names. A RenderFlex overflow, or a control cut off at a side of
// the screen, fails.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/share_service.dart';
import 'package:nightingale_tv/ui/sharing_screen.dart';
import 'package:nightingale_tv/ui/source_picker_screen.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/ui/backup_screen.dart';
import 'package:nightingale_tv/ui/blocks_screen.dart';
import 'package:nightingale_tv/ui/break_plan_editor_screen.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/channel_groups_screen.dart';
import 'package:nightingale_tv/ui/commercials_screen.dart';
import 'package:nightingale_tv/ui/error_reports_screen.dart';
import 'package:nightingale_tv/reporting/error_reports.dart';
import 'package:nightingale_tv/reporting/session_record.dart';
import 'package:nightingale_tv/ui/folder_picker_screen.dart';
import 'package:nightingale_tv/ui/icon_picker_screen.dart';
import 'package:nightingale_tv/ui/login_screen.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/pin_dialog.dart';
import 'package:nightingale_tv/ui/playback_screen.dart';
import 'package:nightingale_tv/ui/quality_picker.dart';
import 'package:nightingale_tv/ui/tv_screen.dart' show TvToast;
import 'package:nightingale_tv/ui/widgets/transport_bar.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/ui/pool_editor_screen.dart';
import 'package:nightingale_tv/ui/profiles_screen.dart';
import 'package:nightingale_tv/ui/sync_screen.dart';
import 'package:nightingale_tv/ui/widgets/screen_layout.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'package:nightingale_tv/l10n/tr.dart';
import 'dart:async';
import 'dart:io';

import 'package:nightingale_tv/convert/convert_helper.dart';
import 'package:nightingale_tv/convert/ffmpeg_programs.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/server/smb/smb_discovery.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_profile.dart';
import 'package:nightingale_tv/server/smb/smb_server.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';
import 'package:nightingale_tv/ui/convert_screens.dart';
import 'package:nightingale_tv/ui/guide_color_screen.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/licenses_screen.dart';
import 'package:nightingale_tv/ui/portrait_watch_screen.dart';
import 'package:nightingale_tv/ui/servers_screen.dart';
import 'package:nightingale_tv/ui/smb_screens.dart';
import 'package:nightingale_tv/server/youtube/google_sign_in.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';
import 'package:nightingale_tv/ui/youtube_screens.dart';
import '../integration_test/fake_google.dart';
import 'language_arb_support.dart';
import 'portrait_harness.dart';
import 'sharing_fakes.dart';
import 'smb/smb_fakes.dart';

/// Opens what's checked, in an app showing [PortraitHarness.show].
typedef Opener = Future<void> Function(WidgetTester tester, PortraitHarness h);

void main() {
  layoutSweep();
  // A Linux window shows the sign-in steps as a TV does, and they scroll
  // there too (a share's many folders).
  group('Linux', () => layoutSweep(windows: const [Size(1920, 1080)], platform: TargetPlatform.linux, only: (name) => name.startsWith('SMB:')));
}

/// The sweep at [windows]; `language_fit_test.dart` also runs it in every
/// language and on a TV. [platform]: Android unless given (a TV with
/// [television]; Linux is drawn as a TV); [only] picks the checks run.
void layoutSweep(
    {List<Size> windows = const [narrowPhone, pixel8, tabletUpright],
    bool television = false,
    TargetPlatform platform = TargetPlatform.android,
    bool Function(String name)? only}) {
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

  /// No whole translated message is cut short with an ellipsis
  /// (cjk-languages D8). The language fit test loads the app's real fonts
  /// (loadAppFonts), so text has its real width and a cut here is a cut on
  /// the screen. English runs elsewhere in the test font, which is far
  /// wider than Barlow, so it isn't checked this way.
  void expectNoMessageCutShort(WidgetTester tester) {
    if (currentLanguage == 'en') return;
    final messages = {
      for (final MapEntry(:key, :value) in readArb(currentLanguage).entries)
        if (!key.startsWith('@') && value is String && !value.contains('{')) value,
    };
    final cut = [
      for (final p in tester.allRenderObjects.whereType<RenderParagraph>())
        if (p.attached && p.didExceedMaxLines && messages.contains(p.text.toPlainText())) p.text.toPlainText(),
    ];
    expect(cut, isEmpty, reason: 'translated text cut short');
  }

  /// Sharing on the fake backend (share-accounts). [signedIn] links the
  /// profile; [linked] also gives it a share profile, a friend and a
  /// blocked account with long names. [asked]: Show what I'm watching was
  /// answered (friend-presence); if not, the question is the page.
  Opener sharing({bool signedIn = false, bool linked = false, bool asked = true}) => (tester, h) async {
        final backend = FakeShareBackend();
        if (linked) {
          backend.profile = {
            'user_id': FakeShareBackend.userId,
            if (asked) 'presence': 'friends',
            'display_name': 'Maximiliane Alexandra W',
            'handle': 'maximiliane_alexandr',
            'avatar': 'penguin',
            'avatar_color': 3,
            'station': 'Maximiliane\'s Late Night TV',
          };
          backend.friends.add(const ShareProfile(
              userId: 'user-long', name: 'Bartholomew Fitzgerald Jr', handle: 'bartholomew_fitzgera', avatar: 'whale'));
          backend.blocked.add(const ShareProfile(userId: 'user-blocked', name: 'Someone Blocked', handle: 'someone_blocked'));
        }
        // Real time: the sign-in's refresh timer isn't the test clock's.
        await tester.runAsync(() async {
          final service = h.household.sharing = ShareService(h.household, h.household.root,
              url: 'https://share.test',
              key: 'sb_publishable_test',
              host: 'coffeehauslabs.example',
              httpClient: backend.client,
              watchLifecycle: false);
          await service.load();
          if (signedIn || linked) {
            final client = await service.setUp(h.household.current!);
            await client!.verifyCode('sam@example.com', FakeShareBackend.otp);
          }
        });
        addTearDown(() => tester.runAsync(() async {
              h.household.sharing?.dispose();
              h.household.sharing = null;
            }));
        await screen((_) => const SharingScreen())(tester, h);
      };

  // SMB shares (smb-sources): a share and its host with long names, read
  // from a fake, with nothing reached on the network.
  const host = 'living-room-network-storage';
  const shareName = 'Family Videos and Movies';
  FakeShare share() => FakeShare({
        'Television Shows/A Show With a Long Title/Season 01/A Show With a Long Title S01E01.mkv': 10,
        'Feature Films and Documentaries/A Movie With a Very Long Title (1995).mkv': 10,
        'Home Videos From the Summer Holidays/Beach day.mp4': 10,
        'Vintage Commercials/Soap 1987.mpg': 1,
        'Backups/x.zip': 1,
      });
  setUpAll(() {
    SmbGateway.inIsolate = false;
    IndexBuilder.useIsolate = false;
    FfmpegPrograms.reset(const FfmpegPrograms(ffmpeg: '/nonexistent/ffmpeg', ffprobe: '/nonexistent/ffprobe'));
    SmbProfile.openOverride = (address, who, {knownSmb1 = false, workers = 2}) async => share();
  });
  tearDownAll(() async {
    FfmpegPrograms.reset();
    SmbProfile.openOverride = null;
    await SmbGateway.stop();
  });

  /// The sign-in flow on fakes: two hosts found; a guest opens [shareName],
  /// and "Private" wants a sign-in.
  SignInFlow fakeShares(SignInFlow flow) => flow
    ..newDiscovery = (() => _FixedHosts(const [
          SmbHost(address: '192.168.1.5', name: host),
          SmbHost(address: '192.168.1.6', name: 'office-computer-upstairs'),
        ]))
    ..openShare = (address, who) async {
      if (address.share == 'Private' && who.isGuest) throw const SmbException(SmbErrorKind.guestsRefused, 'no guests');
      return share();
    }
    ..listShares = (address, who) async =>
        (shares: const [SmbShareInfo(shareName), SmbShareInfo('Private'), SmbShareInfo('Music Collection and Radio')], smb1: true);

  /// The SMB sign-in screen after [then] on its flow.
  Opener smbSignIn(Future<void> Function(SignInFlow flow) then) => (tester, h) async {
        late SignInFlow flow;
        await h.show(tester, LoginScreen(adding: true, prepareFlow: (f) => fakeShares(flow = f)));
        await settle(tester);
        await tester.runAsync(() => then(flow));
        await settle(tester);
      };

  /// [shareName] added to the profile, its files read, then [open].
  Opener withShare(Opener Function(String key) open) => (tester, h) async {
        await tester.runAsync(() async {
          final flow = fakeShares(SignInFlow(h.app, adding: true));
          await flow.smbConnect('smb://$host/$shareName');
          flow
            ..mapSmbFolder('Television Shows', SmbFolderType.tvShows)
            ..mapSmbFolder('Feature Films and Documentaries', SmbFolderType.movies)
            ..mapSmbFolder('Home Videos From the Summer Holidays', SmbFolderType.homeVideos)
            ..mapSmbFolder('Vintage Commercials', SmbFolderType.commercials);
          await flow.finishSmb(historyName: 'Living room');
          flow.dispose();
          final server = h.app.servers.all.map((s) => s.client).whereType<SmbServer>().single;
          for (var i = 0; i < 100 && server.scan.items.isEmpty; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          for (final i in server.scan.items) {
            if (i.path.endsWith('.mkv')) server.cantPlayIds[i.id] = i.path.contains('Film') ? CantPlayReason.tooMuch : CantPlayReason.damaged;
          }
        });
        final key = h.app.servers.all.firstWhere((s) => s.session?.kind == ServerKind.smb).key;
        await open(key)(tester, h);
      };

  // YouTube (youtube-subscriptions): a fake Google with long names.
  late FakeGoogle google;
  const ownClient = GoogleClient(id: 'own-client', secret: 'own-client-secret', own: true);
  setUpAll(() async {
    google = await FakeGoogle.start();
    GoogleEndpoints.override = GoogleEndpoints(oauth: google.url, api: google.url);
    for (var i = 0; i < 14; i++) {
      final id = 'UClongname$i';
      google.channels[id] = FakeChannel(id, 'A Channel With a Really Rather Long YouTube Name Number $i',
          videos: [FakeVideo('v$i', title: 'A video with a long title about cooking and travel $i')]);
    }
    google.accounts['mom'] = FakeAccount('mom',
        title: 'Maximiliane Alexandra\'s Kitchen', subscriptions: [for (var i = 0; i < 14; i++) 'UClongname$i']);
  });
  tearDownAll(() async {
    GoogleEndpoints.override = null;
    await google.close();
  });

  /// Android's Keystore for the secret store: the bytes as they are.
  void keystore() {
    const channel = MethodChannel('nightingale_tv/smb');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        channel, (call) async => call.method == 'encrypt' || call.method == 'decrypt' ? call.arguments : null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  /// The sign-in screen after [then] on its flow, YouTube on the fake.
  Opener youTube(Future<void> Function(SignInFlow flow) then) => (tester, h) async {
        keystore();
        late SignInFlow flow;
        await h.show(tester, LoginScreen(adding: true, prepareFlow: (f) => flow = f..googleDelay = (_) async {}));
        await settle(tester);
        await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() => then(flow), _RealHttp()));
        await settle(tester);
      };

  Future<void> until(SignInFlow f, bool Function(SignInStep s) done) async {
    for (var i = 0; i < 300 && !done(f.step); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// YouTube added to the profile with 9 picks (5 on the app's shared
  /// client, its limit), then [open].
  /// [shared]: signed in with the app's shared client, not an own one.
  /// [sharedBuild]: the build has the shared client, whichever is used.
  Opener withYouTube(Opener Function(String key) open, {bool shared = false, bool sharedBuild = false}) =>
      (tester, h) async {
        keystore();
        if (shared || sharedBuild) {
          GoogleClient.sharedOverride = const GoogleClient(id: 'shared-client', secret: 'shared-client-secret');
          addTearDown(() => GoogleClient.sharedOverride = null);
        }
        await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() async {
          final flow = SignInFlow(h.app, adding: true)..googleDelay = (_) async {};
          google.approveAs = 'mom';
          await flow.startYouTube(client: shared ? null : ownClient);
          await until(flow, (s) => s.stage == SignInStage.youtubePicker);
          expect(flow.step.stage, SignInStage.youtubePicker, reason: '${flow.step.error}');
          await flow.youTubePicked(flow.step.youtube.subscriptions!.take(shared ? 5 : 9).toList());
          flow.dispose();
          for (var i = 0; i < 100 && h.app.refreshing; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        }, _RealHttp()));
        final key = h.app.servers.all.firstWhere((s) => s.session?.kind == ServerKind.youtube).key;
        await open(key)(tester, h);
      };

  final checks = <String, Opener>{
    'connect step': screen((_) => const LoginScreen(adding: true)),
    // A build with no client: the message on the connect step.
    'YouTube: no client': youTube((f) => f.startYouTube()),
    'YouTube: own client': youTube((f) async => f.showGoogleClient()),
    'YouTube: code': youTube((f) async {
      google.approveAs = null;
      await f.startYouTube(client: ownClient);
    }),
    'YouTube: picker': youTube((f) async {
      google.approveAs = 'mom';
      await f.startYouTube(client: ownClient);
      await until(f, (s) => s.stage == SignInStage.youtubePicker);
    }),
    'servers with YouTube': withYouTube((_) => screen((_) => const ServersScreen())),
    // Remove on a YouTube sign-in says its channels go, not that they stay.
    'YouTube: remove': withYouTube((_) => (tester, h) async {
          await screen((_) => const ServersScreen())(tester, h);
          final remove = find.byWidgetPredicate((w) => w is TvButton && w.label == tr.remove);
          await tester.dragUntilVisible(remove, find.byType(Scrollable).first, const Offset(0, -300));
          await settle(tester);
          await tester.ensureVisible(remove);
          await settle(tester);
          await tester.tap(remove);
          await settle(tester);
          expect(find.text(tr.youTubeRemoveBody), findsOneWidget);
          expect(find.text(tr.itsProgramsLeave), findsNothing);
        }),
    'YouTube channels': withYouTube((key) => screen((_) => YouTubeChannelsScreen(serverKey: key))),
    // At the shared client's limit: every unchecked row says where to go.
    'YouTube channels: shared limit': withYouTube(shared: true, (key) => (tester, h) async {
          await screen((_) => YouTubeChannelsScreen(serverKey: key))(tester, h);
          await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(
              () => Future<void>.delayed(const Duration(milliseconds: 500)), _RealHttp()));
          await settle(tester);
          expect(find.text(tr.youTubePickedOf(5, AppState.youTubeSharedLimit)), findsOneWidget);
          expect(find.text(tr.youTubeSharedLimit(AppState.youTubeSharedLimit)), findsWidgets);
        }),
    // Own client with 9 channels: Use Nightingale TV's client is greyed and says why.
    'YouTube: Google client, too many': withYouTube(sharedBuild: true, (key) => (tester, h) async {
          await screen((_) => LoginScreen(againKey: key, googleClient: true))(tester, h);
          await settle(tester);
          final button = find.byKey(const ValueKey('use-shared-client'));
          await reveal(tester, button);
          expect(tester.widget<TvButton>(button).onPressed, isNull);
          expect(find.text(tr.youTubeSharedTooMany(AppState.youTubeSharedLimit)), findsOneWidget);
        }),
    // Servers → YouTube → Google client: the client form stays up; the
    // server's own sign-in again (a new code) mustn't replace it.
    'YouTube: Google client': withYouTube(shared: true, (key) => (tester, h) async {
          late SignInFlow flow;
          await screen((_) => LoginScreen(againKey: key, googleClient: true, prepareFlow: (f) => flow = f))(tester, h);
          // Whatever the screen starts gets real time to run.
          await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(
              () => Future<void>.delayed(const Duration(milliseconds: 500)), _RealHttp()));
          await settle(tester);
          expect(find.byType(GoogleClientForm), findsOneWidget);
          expect((flow.step.stage, flow.step.busy, flow.step.youtube.code, flow.step.error),
              (SignInStage.youtubeClient, false, null, null),
              reason: 'the client form, with no new code asked for');
        }),
    'menu': screen((_) => const MenuScreen()),
    'sharing': sharing(),
    'sharing profile form': sharing(signedIn: true),
    'sharing linked': sharing(linked: true),
    'sharing show what I\'m watching': sharing(linked: true, asked: false),
    'sharing enter a code': (tester, h) async {
      await sharing(linked: true)(tester, h);
      await reveal(tester, find.text(translated('Enter a code')));
      await tester.tap(find.text(translated('Enter a code')).last);
      await settle(tester);
    },
    'sign-in': screen((_) => const LoginScreen(message: 'Couldn\'t reach the server at http://192.168.1.10:8096')),
    'sync': screen((_) => const SyncScreen()),
    'profile picker': screen((_) => const ProfilePickerScreen()),
    'profiles': screen((_) => const ProfilesScreen()),
    'profile editor': screen((h) => ProfileEditorScreen(profile: h.household.profiles.first)),
    'new profile': screen((_) => const ProfileEditorScreen()),
    'channels & icons': screen((_) => const ChannelEditorScreen()),
    'a channel\'s page': (tester, h) async {
      await screen((_) => const ChannelEditorScreen())(tester, h);
      await tester.tap(find.text(h.app.allChannels[1].displayName).first);
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
    // The player options in the transport bar, at the longest cap word, and
    // the toast a pick shows (player-options). The full bar shows only
    // sideways: phones held sideways are checked in player_options_test.
    if (television) 'player options': screen((h) => Stack(children: [
          Positioned(left: 0, right: 0, bottom: 0, child: TransportBar(tuner: h.tuner, onCaptions: () {}, onQuality: () {})),
          Positioned(
              left: 0,
              right: 0,
              top: 60,
              child: Center(child: TvToast(tr.playerQualityValue(tr.playerQualityMbps(40))))),
          Positioned(
              right: 90,
              top: 300,
              child: PlayerOptions(tuner: h.tuner, onCaptions: () {}, onQuality: () {})),
        ])),
    'quality picker': over((context, h) => showQualityPicker(context, h.tuner)),
    'backup & restore': (tester, h) async {
      await tester.runAsync(() async {
        await h.household.backups!.automaticCheck();
        await h.household.backups!.saveUndoPoint(BackupReason.beforeLineupCleanup);
      });
      await screen((_) => const BackupScreen())(tester, h);
    },
    'welcome back': (tester, h) async {
      final stored = await tester.runAsync(() async {
        await h.household.backups!.automaticCheck();
        return h.household.backups!.store.latest();
      });
      await screen((_) => WelcomeBackScreen(backup: stored!))(tester, h);
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
    'undo confirmation': (tester, h) async {
      await tester.runAsync(() async {
        await h.household.backups!.automaticCheck();
        await h.household.backups!.saveUndoPoint(BackupReason.beforeLineupCleanup);
      });
      await screen((_) => const BackupScreen())(tester, h);
      await reveal(tester, find.text(translated('Undo lineup cleanup')));
      await tester.tap(find.text(translated('Undo lineup cleanup')));
      await settle(tester);
      expect(find.text(translated('Restore')), findsOneWidget);
    },
    'transfer': push((_) => const _TransferHost()),
    // A full recent-reports list, every kind (crash-visibility D6).
    'SMB: find a share': smbSignIn((f) => f.startSmb()),
    'SMB: a host\'s shares': smbSignIn((f) async {
      await f.startSmb();
      await f.pickSmbHost(const SmbHost(address: '192.168.1.5', name: host));
    }),
    'SMB: sign in': smbSignIn((f) => f.smbConnect('smb://$host/Private')),
    'SMB: folders': smbSignIn((f) => f.smbConnect('smb://$host/$shareName')),
    'SMB: inside a folder': smbSignIn((f) async {
      await f.smbConnect('smb://$host/$shareName');
      await f.openSmbFolder('Television Shows');
    }),
    // Adding a share ends with its guide colour (server-color-on-add).
    'SMB: guide colour step': smbSignIn((f) async {
      await f.smbConnect('smb://$host/$shareName');
      f.mapSmbFolder('Television Shows', SmbFolderType.tvShows);
      await f.finishSmb(historyName: 'Living room');
      expect(f.step.stage, SignInStage.color);
    }),
    'servers with a share': withShare((_) => screen((_) => const ServersScreen())),
    'a share\'s folders': withShare((key) => screen((_) => SmbFoldersScreen(serverKey: key))),
    'can\'t play': withShare((key) => (tester, h) async {
          await screen((_) => SmbCantPlayScreen(serverKey: key))(tester, h);
          expect(find.textContaining(tr.smbReasonTooMuch), findsOneWidget);
          expect(find.textContaining(tr.smbReasonDamaged), findsOneWidget);
        }),
    'guide colour': withShare((key) => screen((_) => GuideColorScreen(sourceKey: key))),
    'guide in colour': withShare((_) => (tester, h) async {
          await (television
              ? screen((_) => GuideView(onWatch: (_) {}, onClose: () {}, onMenu: () {}))
              : screen((_) => PortraitWatchScreen(picture: const SizedBox(), onTune: (_) {}, onMenu: () {}, onFullScreen: () {})))(tester, h);
          expect(find.byType(GuideColorKey), findsOneWidget, reason: 'a share and a server: the guide has its key');
        }),
    'convert for other TVs': (tester, h) async {
      final helper = ConvertHelper(h.household.root, deviceName: 'Living room computer', port: 0);
      await tester.runAsync(() async {
        await h.household.root.writeJson(ConvertHelper.file, {
          'on': true,
          'id': 'helper01',
          'pairings': [
            {'id': 'p1', 'name': 'Bedroom television upstairs', 'keyHash': '0' * 64, 'paired': '2026-11-22T10:00:00.000'},
          ],
        });
        await helper.load();
      });
      addTearDown(() => helper.stop());
      await screen((_) => ConvertForOthersScreen(helper: helper))(tester, h);
    },
    'convert on other TVs': screen((_) => const ConvertHelpersScreen()),
    'licences': screen((_) => const LicensesScreen()),
    'error reports': (tester, h) async {
      ErrorReports.debugDsn = 'https://public@reports.invalid/2';
      final record = ErrorReports.debugSession = SessionRecord.start(version: 'v', platform: 'android-tv', recording: false);
      final now = DateTime.now();
      for (final (i, kind) in ['test', 'video', 'error', 'exit', 'slowStart'].indexed) {
        record.reports.add(RecentReport(kind: kind, at: now.subtract(Duration(days: 4 - i)), id: '${i}abc${i}def0000'));
      }
      addTearDown(() {
        ErrorReports.debugDsn = null;
        ErrorReports.debugSession = null;
      });
      await screen((_) => const ErrorReportsScreen())(tester, h);
      await reveal(tester, find.text(tr.recentReports));
      expect(find.text(tr.recentReports), findsOneWidget);
    },
  };

  for (final window in windows) {
    group('at ${window.width.toInt()}×${window.height.toInt()}', () {
      for (final MapEntry(key: name, value: open) in checks.entries) {
        if (only != null && !only(name)) continue;
        testWidgets(name, (tester) async {
          runAs(platform, television: television);
          setWindow(tester, window);
          final h = await PortraitHarness.start(tester);
          await open(tester, h);
          expect(ScreenLayout.of(tester.element(find.byType(Material).last)).isPortrait, platform == TargetPlatform.android && !television);
          expect(tester.takeException(), isNull, reason: 'nothing overflows');
          expectNothingCutOff(tester, window);
          expectNoMessageCutShort(tester);
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
          expectNoMessageCutShort(tester);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(minutes: 1));
          expect(PlatformInfo.isAndroid, platform == TargetPlatform.android);
        });
      }
    });
  }
}

/// Real sockets, for the fake Google on this machine (widget tests answer
/// every other request with 400).
class _RealHttp extends HttpOverrides {}

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

/// Hosts found at once, with no sockets.
class _FixedHosts extends SmbDiscovery {
  _FixedHosts(this._fixed);

  final List<SmbHost> _fixed;
  final _out = StreamController<List<SmbHost>>.broadcast();

  @override
  Stream<List<SmbHost>> get hosts => _out.stream;
  @override
  List<SmbHost> get current => _fixed;
  @override
  bool get running => false;
  @override
  Future<void> start() async => scheduleMicrotask(() => _out.add(_fixed));
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() => _out.close();
}
