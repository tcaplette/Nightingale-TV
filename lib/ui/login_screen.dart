import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../platform/platform_info.dart';
import '../server/media_server.dart';
import '../server/plex/plex_account.dart';
import '../server/sign_in_flow.dart';
import '../theme/tv_theme.dart';
import 'backup_screen.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// What the address step found: a client for the server, and its info.
export '../server/sign_in_flow.dart' show IdentifiedServer;

class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key, this.message, this.identify, this.plexAccount, this.pickPlexConnection, this.completeSignIn});

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
    )..state.addListener(_onStep);
    // A new profile most likely uses the same server as the others.
    final known = HouseholdScope.read(context).lastServerUrl;
    if (known != null) _server.text = known;
    // A restored profile: its server and user name from the backup, so
    // only the password is asked (backup-restore D6), or a Plex link code.
    if (_flow.hint case final hint?) {
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
    return TvPage(
      title: shared && profile != null ? 'Sign in for ${profile.name}' : 'Welcome to Nightingale TV',
      hints: '▲▼ Move    OK Select    ESC Back',
      // On the first step, Back returns to "Who's watching?".
      onBack: _s.stage != SignInStage.server ? _flow.back : (shared ? household.leave : null),
      child: ScreenLayout.of(context).isPortrait ? _portrait(g) : Row(
        children: [
          Expanded(
            flex: 5,
            child: _fitAboveKeyboard(Padding(
              padding: const EdgeInsets.fromLTRB(120, 80, 60, 80),
              child: _intro(g),
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
          Icon(Icons.live_tv, size: compact ? 96 : 140, color: g.accent),
          SizedBox(height: compact ? 20 : 32),
          Text('Your library.\nOn the air, 24/7.', style: g.display(compact ? 56 : 84, weight: FontWeight.w800)),
          SizedBox(height: compact ? 16 : 24),
          Text(
            'Nightingale TV turns your Jellyfin, Emby or Plex library into always-on '
            'channels with a program guide. Flip around and catch whatever is on.',
            style: g.body(28, color: g.textDim),
          ),
        ],
      );

  /// Each step is its own focus scope, so its autofocus takes focus even
  /// when the step changes on its own (a code linked on a phone) and the
  /// focused button goes with the old step.
  Widget _formColumn(GuideTheme g) => FocusScope(
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

  /// Android: centered as usual, but scrollable when the on-screen keyboard
  /// leaves too little room, so the field being typed in stays in view.
  static Widget _fitAboveKeyboard(Widget child) {
    if (!PlatformInfo.isAndroid) return child;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: child),
      ),
    );
  }

  bool get _offerRestore {
    final household = HouseholdScope.read(context);
    return household.firstRun && household.backups != null && household.profiles.length == 1;
  }

  Widget _codeBox(GuideTheme g, String code) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
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
          Text('Connect to your server', style: g.display(44)),
          const SizedBox(height: 32),
          TvTextField(
            // Keyed by step, so a field never takes over another's focus.
            key: const ValueKey('server'),
            controller: _server,
            label: 'Server address',
            hint: 'https://media.example.org:8920',
            autofocus: true,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 28),
          TvButton(label: 'Connect', icon: Icons.arrow_forward, expand: true, onPressed: _s.busy ? null : _connect),
          const SizedBox(height: 20),
          TvButton(
            label: 'Sign in with Plex',
            icon: Icons.play_circle_outline,
            expand: true,
            onPressed: _s.busy ? null : () => _flow.startPlex(),
          ),
          // A new install can be set up from a backup instead.
          if (_offerRestore) ...[
            const SizedBox(height: 20),
            TvButton(
              label: 'Restore from a backup',
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
              label: 'Quick Connect (use your phone)',
              icon: Icons.phonelink_lock,
              expand: true,
              autofocus: true,
              onPressed: _s.busy ? null : _flow.startQuickConnect,
            ),
            const SizedBox(height: 20),
          ],
          TvButton(
            label: 'Sign in with password',
            icon: Icons.password,
            expand: true,
            autofocus: !_s.quickConnectAvailable,
            onPressed: _flow.choosePassword,
          ),
          const SizedBox(height: 20),
          TvButton(label: 'Different server', icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
        ];
      case SignInStage.password:
        return [
          Text('Sign in to ${_s.info!.name}', style: g.display(44)),
          if (!_s.quickConnectAvailable)
            Text('${_s.kind.label} ${_s.info!.version} · ${_s.info!.url}', style: g.body(24, color: g.textDim)),
          const SizedBox(height: 32),
          TvTextField(key: const ValueKey('user'), controller: _user, label: 'Username', autofocus: _user.text.isEmpty),
          const SizedBox(height: 20),
          TvTextField(
            key: const ValueKey('password'),
            controller: _password,
            label: 'Password',
            obscure: true,
            autofocus: _user.text.isNotEmpty,
            onSubmitted: (_) => _signInWithPassword(),
          ),
          const SizedBox(height: 28),
          TvButton(
              label: 'Sign in', icon: Icons.login, expand: true, onPressed: _s.busy ? null : _signInWithPassword),
          const SizedBox(height: 20),
          TvButton(label: 'Back', icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
        ];
      case SignInStage.quickConnect:
        return [
          Text('Quick Connect', style: g.display(44)),
          const SizedBox(height: 16),
          Text(
            'On your phone or computer, open ${_s.kind.label} → your profile → Quick Connect, '
            'and enter this code:',
            style: g.body(26, color: g.textDim),
          ),
          const SizedBox(height: 28),
          _codeBox(g, _s.quickConnectCode!),
          const SizedBox(height: 20),
          Text('Waiting for approval…', style: g.body(24, color: g.textDim)),
          const SizedBox(height: 28),
          TvButton(label: 'Cancel', icon: Icons.close, expand: true, autofocus: true, onPressed: _flow.back),
        ];
      case SignInStage.plexCode:
        return [
          Text('Sign in with Plex', style: g.display(44)),
          const SizedBox(height: 16),
          Text('Go to plex.tv/link on your phone or computer and enter this code.',
              style: g.body(26, color: g.textDim)),
          const SizedBox(height: 28),
          if (_s.plexCode != null) _codeBox(g, _s.plexCode!),
          const SizedBox(height: 20),
          Text('Waiting for the code to be linked…', style: g.body(24, color: g.textDim)),
          const SizedBox(height: 28),
          if (PlatformInfo.hasTouch) ...[
            TvButton(label: 'Open plex.tv/link', icon: Icons.open_in_new, expand: true, onPressed: _openLink),
            const SizedBox(height: 20),
          ],
          TvButton(label: 'Cancel', icon: Icons.close, expand: true, autofocus: true, onPressed: _flow.back),
        ];
      case SignInStage.plexUsers:
        return [
          Text("Who's signing in?", style: g.display(44)),
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
          TvButton(label: 'Back', icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
        ];
      case SignInStage.plexPin:
        return [
          Text('PIN for ${_s.homeUser?.title ?? ''}', style: g.display(44)),
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
          TvButton(label: 'Back', icon: Icons.arrow_back, expand: true, onPressed: _flow.back),
        ];
      case SignInStage.plexServers:
        final servers = _s.servers ?? const [];
        return [
          Text('Choose a server', style: g.display(44)),
          const SizedBox(height: 28),
          for (final (i, s) in servers.indexed) ...[
            _ServerRow(server: s, autofocus: i == 0, onPressed: _s.busy ? null : () => _flow.pickServer(s)),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 12),
          TvButton(label: 'Back', icon: Icons.arrow_back, expand: true, autofocus: servers.isEmpty, onPressed: _flow.back),
        ];
    }
  }
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
  const _ServerRow({required this.server, this.onPressed, this.autofocus = false});

  final PlexResource server;
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
              Text(server.online ? 'Online' : 'Offline',
                  style: g.body(22, color: focused ? g.onFocus : (server.online ? g.accent : g.textDim))),
            ],
          ),
        );
      },
    );
  }
}
