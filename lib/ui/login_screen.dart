import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../platform/platform_info.dart';
import '../server/media_server.dart';
import '../server/plex/plex_account.dart';
import '../server/sign_in_flow.dart';
import '../server/youtube/youtube_client_config.dart';
import '../server/smb/smb_share.dart' show smbJoin;
import '../theme/tv_theme.dart';
import 'backup_screen.dart';
import 'guide_color_screen.dart' show GuideColorList;
import 'widgets/nightingale_mark.dart';
import 'widgets/folder_map_row.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import 'youtube_screens.dart';
import '../l10n/tr.dart';

/// What the address step found: a client for the server, and its info.
export '../server/sign_in_flow.dart' show IdentifiedServer;

class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key,
      this.message,
      this.identify,
      this.plexAccount,
      this.pickPlexConnection,
      this.completeSignIn,
      this.prepareFlow,
      this.adding = false,
      this.againKey,
      this.googleClient = false});

  /// Adds a server to the signed-in profile (Servers → Add a server); the
  /// screen closes once it's added.
  final bool adding;

  /// Signs the profile's server with this key in again (Servers → Sign in
  /// again); the screen closes once it's signed in.
  final String? againKey;

  bool get _forServers => adding || againKey != null;

  /// Opens at YouTube's own-client screen (Servers → YouTube → Google
  /// client), for the server [againKey].
  final bool googleClient;

  /// Shown above the form, e.g. "Your session expired".
  final String? message;

  /// Tests: what the address step asks instead of the network.
  @visibleForTesting
  final Future<IdentifiedServer> Function(String address)? identify;

  /// Tests: plex.tv, and how an address is picked for a Plex server.
  @visibleForTesting
  final PlexAccount? plexAccount;
  @visibleForTesting
  final Future<PlexConnection?> Function(PlexResource server)? pickPlexConnection;

  /// Tests: what's done with a finished sign-in instead of the app's
  /// (which checks a Plex sign-in, then scans the library).
  @visibleForTesting
  final Future<void> Function(ServerSession session, MediaServer client)? completeSignIn;

  /// Tests: sets up the screen's flow (how shares are found and opened)
  /// before it's used.
  @visibleForTesting
  final void Function(SignInFlow flow)? prepareFlow;

  /// How often a link code is checked.
  static const plexPoll = SignInFlow.plexPoll;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// The TV's sign-in screen: a view over [SignInFlow], which the server's
/// setup page drives too.
class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _domain = TextEditingController();
  final _smbAddress = TextEditingController();
  final _historyName = TextEditingController();

  late final SignInFlow _flow;
  SignInStep get _s => _flow.step;
  String _pinDigits = '';

  @override
  void initState() {
    super.initState();
    _flow = SignInFlow(
      AppScope.read(context),
      message: widget.message,
      identify: widget.identify,
      plexAccount: widget.plexAccount,
      pickPlexConnection: widget.pickPlexConnection,
      completeSignIn: widget.completeSignIn,
      adding: widget.adding,
      againKey: widget.againKey,
    )..state.addListener(_onStep);
    widget.prepareFlow?.call(_flow);
    if (widget.googleClient) _flow.showGoogleClient();
    // A new profile most likely uses the same server as the others (an
    // added server, another one).
    final known = HouseholdScope.read(context).lastServerUrl;
    if (known != null && !widget.adding) _server.text = known;
    // A restored profile: its server and user name from the backup, so
    // only the password is asked (backup-restore D6), or a Plex link code.
    // Not when the Google client screen was asked for: it stays up.
    if (_flow.hint case final hint? when !widget.googleClient) {
      _server.text = hint.server;
      if (hint.user case final user?) _user.text = user;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flow.startFromHint();
      });
    }
  }

  SignInStage _shown = SignInStage.server;

  void _onStep() {
    if (!mounted) return;
    // Added or signed in again: back to Servers.
    if (widget._forServers && _flow.finished) {
      Navigator.of(context).maybePop();
      return;
    }
    // The mapping step opens with the profile's name as the history name.
    if (_s.stage == SignInStage.smbFolders && _shown != SignInStage.smbFolders) _historyName.text = _s.smb.historyName;
    if (_s.stage == SignInStage.smbSignIn && _shown != SignInStage.smbSignIn && _user.text.isEmpty) _user.text = _s.smb.user;
    setState(() {
      // A PIN pad opens empty.
      if (_s.stage == SignInStage.plexPin && _shown != SignInStage.plexPin) _pinDigits = '';
      _shown = _s.stage;
    });
  }

  @override
  void dispose() {
    _flow.state.removeListener(_onStep);
    _flow.dispose();
    _server.dispose();
    _user.dispose();
    _password.dispose();
    _domain.dispose();
    _smbAddress.dispose();
    _historyName.dispose();
    super.dispose();
  }

  void _connect() => _flow.connect(_server.text);

  Future<void> _signInWithPassword() async {
    await _flow.signInWithPassword(_user.text, _password.text);
    if (mounted && _s.error == null) _password.clear();
  }

  void _pinKey(String digit) {
    if (_s.busy) return;
    if (digit == '⌫') {
      if (_pinDigits.isNotEmpty) setState(() => _pinDigits = _pinDigits.substring(0, _pinDigits.length - 1));
      return;
    }
    if (_pinDigits.length >= 4) return;
    setState(() => _pinDigits += digit);
    if (_pinDigits.length < 4) return;
    _flow.enterHomePin(_pinDigits).then((right) {
      if (!right && mounted) setState(() => _pinDigits = '');
    });
  }

  void _openLink() => unawaited(PlatformInfo.openUrl('https://plex.tv/link'));

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final household = HouseholdScope.of(context);
    final profile = household.current;
    final shared = household.profiles.length > 1;
    final again = widget.againKey == null ? null : AppScope.read(context).servers.byKey(widget.againKey!);
    return TvPage(
      title: widget.adding
          ? tr.addAServer
          : again != null
              ? tr.signInToAgain(again.name)
              : shared && profile != null
                  ? tr.signInFor(profile.name)
                  : tr.welcomeToNightingale,
      hints: tr.moveOkSelectEscBack,
      // On the first step, Back returns to "Who's watching?" (or Servers).
      onBack: _s.stage != SignInStage.server
          ? _flow.back
          : widget._forServers
              ? () => Navigator.of(context).maybePop()
              : (shared ? household.leave : null),
      child: _s.stage == SignInStage.color
          ? _colorStep(g)
          : _s.stage == SignInStage.youtubePicker
              ? _youTubePicker()
              : ScreenLayout.of(context).isPortrait ? _portrait(g) : Row(
        children: [
          Expanded(
            flex: 5,
            child: _fitAboveKeyboard(Padding(
              padding: const EdgeInsets.fromLTRB(120, 80, 60, 80),
              // Taller than its half of the screen (a long translation):
              // smaller, never cut.
              child: LayoutBuilder(
                builder: (context, box) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                      width: box.maxWidth,
                      child: _s.stage == SignInStage.youtubeCode ? const YouTubeConsent() : _intro(g)),
                ),
              ),
            )),
          ),
          Expanded(
            flex: 4,
            child: _fitAboveKeyboard(Padding(
              padding: const EdgeInsets.fromLTRB(40, 80, 120, 80),
              child: _formColumn(g),
            )),
          ),
        ],
      ),
    );
  }

  /// Adding a server, last: its guide colour (guide-server-colors), laid out
  /// like the server's Guide colour screen. Choosing one returns to Servers;
  /// Back keeps the one selected.
  Widget _colorStep(GuideTheme g) {
    final app = AppScope.of(context);
    final key = _s.colorKey!;
    return _StepScope(
      key: const ValueKey(SignInStage.color),
      // The heading stays put; the colours scroll under it (a focused colour
      // centres itself, which would carry a heading in the list away).
      child: FocusTraversalGroup(
        child: Padding(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)).copyWith(bottom: 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr.guideColorTitle(app.sourceName(key) ?? ''), style: g.display(44)),
            const SizedBox(height: 8),
            Text(tr.guideColorHelp, style: g.body(24, color: g.textDim)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: ScreenLayout.of(context).pagePadding(const EdgeInsets.only(bottom: 40)).bottom),
                children: [
                  GuideColorList(sourceKey: key, enabled: !_s.busy, onChosen: (name) => unawaited(_flow.chooseColor(name))),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Use Nightingale TV's client: offered when the build has it and the
  /// server being signed in again uses its own.
  bool get _sharedClientOffered {
    if (GoogleClient.shared == null) return false;
    final again = widget.againKey == null ? null : AppScope.read(context).servers.byKey(widget.againKey!);
    return again?.session?.clientId != null;
  }

  /// A first YouTube sign-in's subscriptions, on a page of their own.
  Widget _youTubePicker() {
    final app = AppScope.of(context);
    return _StepScope(
      key: const ValueKey(SignInStage.youtubePicker),
      child: FocusTraversalGroup(
        child: YouTubePicker(
          subscriptions: _s.youtube.subscriptions ?? const [],
          current: const [],
          others: _flow.youTubeOwnClient ? null : app.youTubeSharedCount(),
          busy: _s.busy,
          error: _s.error,
          onDone: (picks) => unawaited(_flow.youTubePicked(picks)),
        ),
      ),
    );
  }

  /// Upright: the welcome over the form, in one column that scrolls when
  /// the keyboard is up.
  Widget _portrait(GuideTheme g) {
    final layout = ScreenLayout.of(context);
    return _fitAboveKeyboard(Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.gutter, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_s.stage == SignInStage.server) ...[_intro(g, compact: true), const SizedBox(height: 40)],
              _formColumn(g),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _intro(GuideTheme g, {bool compact = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NightingaleTv(height: compact ? 96 : 140, swoosh: true),
          SizedBox(height: compact ? 20 : 32),
          Text(tr.yourLibraryOn, style: g.display(compact ? 56 : 84, weight: FontWeight.w800)),
          SizedBox(height: compact ? 16 : 24),
          Text(
            tr.nightingaleTvTurns,
            style: g.body(28, color: g.textDim),
          ),
        ],
      );

  /// Each step is its own focus scope, so its autofocus takes focus even
  /// when the step changes on its own (a code linked on a phone) and the
  /// focused button goes with the old step.
  Widget _formColumn(GuideTheme g) => _StepScope(
        key: ValueKey(_s.stage),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._form(g),
              const SizedBox(height: 28),
              ConstrainedBox(
                // Upright, a long error gets the lines it needs.
                constraints: ScreenLayout.of(context).isPortrait
                    ? const BoxConstraints(minHeight: 80)
                    : const BoxConstraints(minHeight: 80, maxHeight: 120),
                child: _s.busy
                    ? Center(child: CircularProgressIndicator(color: g.accent))
                    : _s.error == null
                        ? null
                        : Text(_s.error!, style: g.body(26, color: g.nowLine)),
              ),
            ],
          ),
        ),
      );

  /// Centered as usual, but scrollable when a step is taller than the room
  /// it has (a share's many folders; on Android, the on-screen keyboard), so
  /// the focused control or the field being typed in stays in view. On
  /// every platform: Linux windows are no taller than a TV's screen.
  static Widget _fitAboveKeyboard(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: child),
      ),
    );
  }

  bool get _offerRestore {
    final household = HouseholdScope.read(context);
    // Adding a server, or signing in to one again, never replaces the
    // household.
    return !widget._forServers && household.firstRun && household.backups != null && household.profiles.length == 1;
  }

  Widget _codeBox(GuideTheme g, String code) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: g.header,
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: g.accent, width: 3),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(code,
              key: const ValueKey('code'),
              style: g.display(96, weight: FontWeight.w800, color: g.accent).copyWith(letterSpacing: 18)),
        ),
      );

  List<Widget> _form(GuideTheme g) {
    switch (_s.stage) {
      case SignInStage.server:
        return [
          Text(tr.connectToYour, style: g.display(44)),
          const SizedBox(height: 32),
          TvTextField(
            // Keyed by step, so a field never takes over another's focus.
            key: const ValueKey('server'),
            controller: _server,
            label: tr.serverAddress,
            hint: 'https://media.example.org:8920',
            autofocus: true,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 28),
          TvButton(label: tr.connect, icon: Icons.arrow_forward, expand: true, onPressed: _s.busy ? null : _connect),
          const SizedBox(height: 20),
          TvButton(
            label: tr.signInWith,
            icon: Icons.play_circle_outline,
            expand: true,
            onPressed: _s.busy ? null : () => _flow.startPlex(),
          ),
          const SizedBox(height: 20),
          TvButton(
            key: const ValueKey('smb-share'),
            label: tr.smbShareButton,
            icon: Icons.folder_shared,
            expand: true,
            onPressed: _s.busy ? null : () => _flow.startSmb(),
          ),
          const SizedBox(height: 20),
          TvButton(
            key: const ValueKey('youtube'),
            label: tr.youTube,
            icon: Icons.smart_display,
            expand: true,
            onPressed: _s.busy ? null : () => _flow.startYouTube(),
          ),
          // A new install can be set up from a backup instead.
          if (_offerRestore) ...[
            const SizedBox(height: 20),
            TvButton(
              label: tr.restoreFromA,
              icon: Icons.settings_backup_restore,
              expand: true,
              onPressed: _s.busy ? null : () => restoreOnFirstRun(context),
            ),
          ],
        ];
      case SignInStage.method:
        return [
          Text(_s.info!.name, style: g.display(44)),
          Text('${_s.kind.label} ${_s.info!.version} · ${_s.info!.url}', style: g.body(24, color: g.textDim)),
          const SizedBox(height: 40),
          if (_s.quickConnectAvailable) ...[
            TvButton(
              label: tr.quickConnectUse,
              icon: Icons.phonelink_lock,
              expand: true,
              autofocus: true,
              onPressed: _s.busy ? null : _flow.startQuickConnect,
            ),
            const SizedBox(height: 20),
          ],
          TvButton(
            label: tr.signInWithPassword,
            icon: Icons.password,
            expand: true,
            autofocus: !_s.quickConnectAvailable,
            onPressed: _flow.choosePassword,
          ),
          const SizedBox(height: 20),
          TvButton(label: tr.differentServer, icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
        ];
      case SignInStage.password:
        return [
          Text(tr.signInTo2(_s.info!.name), style: g.display(44)),
          if (!_s.quickConnectAvailable)
            Text('${_s.kind.label} ${_s.info!.version} · ${_s.info!.url}', style: g.body(24, color: g.textDim)),
          const SizedBox(height: 32),
          TvTextField(key: const ValueKey('user'), controller: _user, label: tr.username, autofocus: _user.text.isEmpty),
          const SizedBox(height: 20),
          TvTextField(
            key: const ValueKey('password'),
            controller: _password,
            label: tr.password,
            obscure: true,
            autofocus: _user.text.isNotEmpty,
            onSubmitted: (_) => _signInWithPassword(),
          ),
          const SizedBox(height: 28),
          TvButton(
              label: tr.signIn, icon: Icons.login, expand: true, onPressed: _s.busy ? null : _signInWithPassword),
          const SizedBox(height: 20),
          TvButton(label: tr.back, icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
        ];
      case SignInStage.quickConnect:
        return [
          Text(tr.quickConnect, style: g.display(44)),
          const SizedBox(height: 16),
          Text(
            tr.onYourPhone(_s.kind.label),
            style: g.body(26, color: g.textDim),
          ),
          const SizedBox(height: 28),
          _codeBox(g, _s.quickConnectCode!),
          const SizedBox(height: 20),
          Text(tr.waitingForApproval, style: g.body(24, color: g.textDim)),
          const SizedBox(height: 28),
          TvButton(label: tr.cancel, icon: Icons.close, expand: true, autofocus: true, onPressed: _flow.back),
        ];
      case SignInStage.plexCode:
        return [
          Text(tr.signInWith, style: g.display(44)),
          const SizedBox(height: 16),
          Text(tr.goToPlex,
              style: g.body(26, color: g.textDim)),
          const SizedBox(height: 28),
          if (_s.plexCode != null) _codeBox(g, _s.plexCode!),
          const SizedBox(height: 20),
          Text(tr.waitingForThe, style: g.body(24, color: g.textDim)),
          const SizedBox(height: 28),
          if (PlatformInfo.hasTouch) ...[
            TvButton(label: tr.openPlexTv, icon: Icons.open_in_new, expand: true, onPressed: _openLink),
            const SizedBox(height: 20),
          ],
          TvButton(label: tr.cancel, icon: Icons.close, expand: true, autofocus: true, onPressed: _flow.back),
        ];
      case SignInStage.plexUsers:
        return [
          Text(tr.whosSigningIn, style: g.display(44)),
          const SizedBox(height: 28),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              for (final (i, u) in _s.homeUsers.indexed)
                _UserTile(user: u, autofocus: i == 0, onPressed: _s.busy ? null : () => _flow.pickUser(u)),
            ],
          ),
          const SizedBox(height: 28),
          TvButton(label: tr.back, icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
        ];
      case SignInStage.plexPin:
        return [
          Text(tr.pinFor(_s.homeUser?.title ?? ''), style: g.display(44)),
          const SizedBox(height: 20),
          Text(
            [for (var i = 0; i < 4; i++) i < _pinDigits.length ? '●' : '○'].join('  '),
            key: const ValueKey('pin-dots'),
            textAlign: TextAlign.center,
            style: g.display(56, color: g.accent),
          ),
          const SizedBox(height: 20),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['⌫', '0', ''],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: key.isEmpty
                            ? const SizedBox.shrink()
                            : TvButton(
                                key: ValueKey('pin-$key'),
                                label: key,
                                expand: true,
                                autofocus: key == '1',
                                onPressed: _s.busy ? null : () => _pinKey(key)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          TvButton(label: tr.back, icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
        ];
      case SignInStage.smbFind:
        return _smbFind(g);
      case SignInStage.smbShares:
        return _smbShares(g);
      case SignInStage.smbSignIn:
        return _smbSignIn(g);
      case SignInStage.smbFolders:
        return _smbFolders(g);
      // Drawn on its own page (_colorStep).
      case SignInStage.color:
        return const [];
      case SignInStage.youtubeCode:
        return [
          // Upright, the consent comes first; on a TV it's beside the form.
          if (ScreenLayout.of(context).isPortrait) ...[const YouTubeConsent(), const SizedBox(height: 32)],
          YouTubeCodeStep(code: _s.youtube.code, codeBox: (code) => _codeBox(g, code), onCancel: _flow.back),
        ];
      case SignInStage.youtubeClient:
        return [
          GoogleClientForm(
            busy: _s.busy,
            onUse: (client) => unawaited(_flow.startYouTube(client: client)),
            onUseShared: _sharedClientOffered ? () => unawaited(_flow.startYouTube(client: GoogleClient.shared)) : null,
            sharedTooMany: _sharedClientOffered && !AppScope.read(context).youTubeFitsSharedClient(widget.againKey!),
          ),
        ];
      // Drawn on its own page (_youTubePicker).
      case SignInStage.youtubePicker:
        return const [];
      case SignInStage.plexServers:
        final servers = _s.servers ?? const [];
        return [
          Text(tr.chooseAServer, style: g.display(44)),
          const SizedBox(height: 28),
          for (final s in servers) ...[
            // Servers already in the profile show as added (multi-server).
            _ServerRow(
                server: s,
                added: _s.added.contains(s.clientIdentifier) && widget.againKey == null,
                autofocus: identical(s, servers.where((o) => !_s.added.contains(o.clientIdentifier)).firstOrNull),
                onPressed: _s.busy || (_s.added.contains(s.clientIdentifier) && widget.againKey == null)
                    ? null
                    : () => _flow.pickServer(s)),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 12),
          TvButton(label: tr.back, icon: Icons.arrow_back, expand: true, autofocus: servers.isEmpty, onPressed: _flow.back),
        ];
    }
  }
}

extension on _LoginScreenState {
  // ---- SMB shares (smb-sources) ------------------------------------------------

  Widget _smbOldNote(GuideTheme g) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Icon(Icons.warning_amber, color: g.nowLine, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(tr.smbOld, style: g.body(24, color: g.nowLine))),
        ]),
      );

  List<Widget> _smbFind(GuideTheme g) {
    final smb = _s.smb;
    return [
      Text(tr.smbFindTitle, style: g.display(44)),
      const SizedBox(height: 8),
      Text(tr.smbFindHelp, style: g.body(24, color: g.textDim)),
      const SizedBox(height: 24),
      for (final (i, h) in smb.hosts.indexed) ...[
        TvButton(
          key: ValueKey('smb-host-${h.address}'),
          label: h.name.isEmpty || h.name == h.address ? h.address : '${h.label}  ·  ${h.address}',
          icon: Icons.computer,
          expand: true,
          autofocus: i == 0,
          onPressed: _s.busy ? null : () => _flow.pickSmbHost(h),
        ),
        const SizedBox(height: 14),
      ],
      if (smb.searching)
        Text(tr.smbSearching, style: g.body(24, color: g.textDim))
      else if (smb.hosts.isEmpty)
        Text(tr.smbNoneFound, style: g.body(24, color: g.textDim)),
      const SizedBox(height: 20),
      TvTextField(
        key: const ValueKey('smb-address'),
        controller: _smbAddress,
        label: tr.smbAddress,
        hint: 'smb://nas/media',
        autofocus: smb.hosts.isEmpty,
        keyboardType: TextInputType.url,
        onSubmitted: (_) => _flow.smbConnect(_smbAddress.text),
      ),
      const SizedBox(height: 20),
      TvButton(
          label: tr.connect,
          icon: Icons.arrow_forward,
          expand: true,
          onPressed: _s.busy ? null : () => _flow.smbConnect(_smbAddress.text)),
      const SizedBox(height: 14),
      TvButton(
          label: tr.smbSearchAgain,
          icon: Icons.refresh,
          expand: true,
          onPressed: smb.searching || _s.busy ? null : () => _flow.searchSmb()),
      const SizedBox(height: 14),
      TvButton(label: tr.back, icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
    ];
  }

  List<Widget> _smbShares(GuideTheme g) {
    final smb = _s.smb;
    final host = smb.host?.host ?? '';
    return [
      Text(tr.smbSharesOn(host), style: g.display(44)),
      if (smb.smb1) _smbOldNote(g),
      const SizedBox(height: 24),
      if (smb.shares.isEmpty) Text(tr.smbNoShares(host), style: g.body(26, color: g.textDim)),
      for (final (i, share) in smb.shares.indexed) ...[
        TvButton(
          key: ValueKey('smb-share-${share.name}'),
          label: share.comment.isEmpty ? share.name : '${share.name}  ·  ${share.comment}',
          icon: Icons.folder_shared,
          expand: true,
          autofocus: i == 0,
          onPressed: _s.busy ? null : () => _flow.pickSmbShare(share.name),
        ),
        const SizedBox(height: 14),
      ],
      const SizedBox(height: 14),
      TvButton(label: tr.back, icon: Icons.arrow_back, expand: true, autofocus: smb.shares.isEmpty, onPressed: _flow.back),
    ];
  }

  Future<void> _smbSignInPressed() async {
    await _flow.smbSignIn(_user.text, _password.text, domain: _domain.text);
    if (mounted && _s.error == null) _password.clear();
  }

  List<Widget> _smbSignIn(GuideTheme g) {
    final smb = _s.smb;
    return [
      Text(tr.smbSignInTo(smb.share == null ? smb.host?.host ?? '' : '${smb.share} · ${smb.host?.host ?? ''}'), style: g.display(44)),
      if (smb.smb1) _smbOldNote(g),
      const SizedBox(height: 28),
      TvTextField(key: const ValueKey('smb-user'), controller: _user, label: tr.username, autofocus: _user.text.isEmpty),
      const SizedBox(height: 18),
      TvTextField(
        key: const ValueKey('smb-password'),
        controller: _password,
        label: tr.password,
        obscure: true,
        autofocus: _user.text.isNotEmpty,
        onSubmitted: (_) => _smbSignInPressed(),
      ),
      const SizedBox(height: 18),
      TvTextField(key: const ValueKey('smb-domain'), controller: _domain, label: tr.smbDomain),
      const SizedBox(height: 24),
      TvButton(label: tr.signIn, icon: Icons.login, expand: true, onPressed: _s.busy ? null : _smbSignInPressed),
      const SizedBox(height: 14),
      TvButton(label: tr.smbAsGuest, icon: Icons.person_outline, expand: true, onPressed: _s.busy ? null : _flow.smbAsGuest),
      const SizedBox(height: 14),
      TvButton(label: tr.back, icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
    ];
  }

  List<Widget> _smbFolders(GuideTheme g) {
    final smb = _s.smb;
    final top = smb.folder.isEmpty;
    return [
      Text(tr.smbWhatsIn(top ? smb.share ?? '' : '${smb.share} › ${smb.folder.replaceAll('/', ' › ')}'), style: g.display(40)),
      if (smb.smb1) _smbOldNote(g),
      const SizedBox(height: 8),
      Text(tr.smbMapHelp, style: g.body(22, color: g.textDim)),
      const SizedBox(height: 20),
      if (!top) ...[
        TvButton(label: tr.smbUp, icon: Icons.arrow_upward, expand: true, onPressed: _s.busy ? null : _flow.back),
        const SizedBox(height: 12),
      ],
      for (final (i, f) in smb.folders.indexed) ...[
        FolderMapRow(
          key: ValueKey('smb-folder-$f'),
          name: f,
          type: smb.mappings[smbJoin(smb.folder, f)],
          inherited: smb.typeAt(smb.folder),
          autofocus: i == 0,
          onOpen: _s.busy ? null : () => _flow.openSmbFolder(smbJoin(smb.folder, f)),
          onType: (t) => _flow.mapSmbFolder(smbJoin(smb.folder, f), t),
        ),
        const SizedBox(height: 12),
      ],
      if (top) ...[
        const SizedBox(height: 16),
        if (smb.writable) ...[
          TvTextField(
            key: const ValueKey('smb-history'),
            controller: _historyName,
            label: tr.smbHistoryName,
          ),
          const SizedBox(height: 8),
          Text(tr.smbHistoryHelp, style: g.body(22, color: g.textDim)),
          const SizedBox(height: 12),
          TvToggle(
            label: tr.smbKeepLocal,
            on: smb.keepLocal,
            onPressed: () => _flow.setSmbHistory(keepLocal: !smb.keepLocal),
          ),
        ] else
          Text(tr.smbReadOnly, style: g.body(22, color: g.textDim)),
      ],
      const SizedBox(height: 20),
      TvButton(
          label: tr.smbFoldersDone,
          icon: Icons.check,
          expand: true,
          autofocus: smb.folders.isEmpty,
          onPressed: _s.busy ? null : () => _flow.finishSmb(historyName: _historyName.text)),
      const SizedBox(height: 14),
      if (top) TvButton(label: tr.back, icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
    ];
  }
}

/// One sign-in step's focus scope. The arrow keys can leave it for the back
/// button above it.
class _StepScope extends StatefulWidget {
  const _StepScope({super.key, required this.child});

  final Widget child;

  @override
  State<_StepScope> createState() => _StepScopeState();
}

class _StepScopeState extends State<_StepScope> {
  final _node = FocusScopeNode(
    debugLabel: 'sign-in step',
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
    // Only its controls are stops: Up from one low in the step would otherwise
    // land on the step itself, and so back on that control.
    skipTraversal: true,
  );

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(node: _node, child: widget.child);
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, this.onPressed, this.autofocus = false});

  final PlexHomeUser user;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final thumb = user.thumb;
    return TvFocusable(
      onPressed: onPressed,
      autofocus: autofocus,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: focused ? g.focus : g.cell,
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: g.header,
              foregroundImage: thumb != null && thumb.startsWith('http') ? NetworkImage(thumb) : null,
              child: Text(user.title.isEmpty ? '?' : user.title.characters.first.toUpperCase(),
                  style: g.display(40, color: focused ? g.onFocus : g.text)),
            ),
            const SizedBox(height: 12),
            Text(user.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: g.body(24, color: focused ? g.onFocus : g.text)),
            if (user.protected) Icon(Icons.lock, size: 22, color: focused ? g.onFocus : g.textDim),
          ],
        ),
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({required this.server, this.onPressed, this.autofocus = false, this.added = false});

  final PlexResource server;

  /// Already in the profile: shown, not pickable.
  final bool added;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvFocusable(
      onPressed: onPressed,
      autofocus: autofocus,
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
          child: Row(
            children: [
              Icon(Icons.dns, color: fg),
              const SizedBox(width: 20),
              Expanded(child: Text(server.label, style: g.body(28, color: fg))),
              const SizedBox(width: 16),
              Text(added ? tr.added : server.online ? tr.online : tr.offline,
                  style: g.body(22, color: focused ? g.onFocus : (server.online ? g.accent : g.textDim))),
            ],
          ),
        );
      },
    );
  }
}
