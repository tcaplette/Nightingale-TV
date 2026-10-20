import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../jellyfin/jellyfin_client.dart';
import '../platform/platform_info.dart';
import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';

enum _Step { server, method, password, quickConnect }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.message});

  /// Shown above the form, e.g. "Your session expired".
  final String? message;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();

  _Step _step = _Step.server;
  bool _busy = false;
  String? _error;
  JellyfinClient? _client;
  ServerInfo? _info;
  bool _quickConnectAvailable = false;
  QuickConnectRequest? _quickConnect;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _error = widget.message;
    // A new profile most likely uses the same server as the others.
    final known = HouseholdScope.read(context).lastServerUrl;
    if (known != null) _server.text = known;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _server.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } on JellyfinException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _connect() => _run(() async {
        if (_server.text.trim().isEmpty) throw JellyfinException('Enter your server address.');
        final client = AppScope.read(context).clientFor(_server.text);
        final info = await client.publicInfo();
        final qc = await client.quickConnectEnabled();
        setState(() {
          _client = client;
          _info = info;
          _quickConnectAvailable = qc;
          _step = _Step.method;
        });
      });

  void _signInWithPassword() => _run(() async {
        if (_user.text.trim().isEmpty) throw JellyfinException('Enter your username.');
        final session = await _client!
            .authenticateByName(_user.text.trim(), _password.text, serverName: _info!.name);
        _password.clear();
        if (!mounted) return;
        await AppScope.read(context).completeSignIn(session, _client!);
      });

  void _startQuickConnect() => _run(() async {
        final request = await _client!.quickConnectInitiate();
        setState(() {
          _quickConnect = request;
          _step = _Step.quickConnect;
        });
        _poll?.cancel();
        _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkQuickConnect());
      });

  Future<void> _checkQuickConnect() async {
    final request = _quickConnect;
    if (request == null || _busy) return;
    try {
      if (!await _client!.quickConnectAuthorized(request.secret)) return;
      _poll?.cancel();
      final session =
          await _client!.authenticateWithQuickConnect(request.secret, serverName: _info!.name);
      if (!mounted) return;
      await AppScope.read(context).completeSignIn(session, _client!);
    } on JellyfinException catch (e) {
      _poll?.cancel();
      if (mounted) setState(() => _error = 'Quick Connect stopped: ${e.message}');
    }
  }

  void _back() {
    _poll?.cancel();
    setState(() {
      _error = null;
      _step = switch (_step) {
        _Step.server || _Step.method => _Step.server,
        _Step.password || _Step.quickConnect => _Step.method,
      };
    });
  }

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
      onBack: _step != _Step.server ? _back : (shared ? household.leave : null),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _fitAboveKeyboard(Padding(
              padding: const EdgeInsets.fromLTRB(120, 80, 60, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.live_tv, size: 140, color: g.accent),
                  const SizedBox(height: 32),
                  Text('Your library.\nOn the air, 24/7.',
                      style: g.display(84, weight: FontWeight.w800)),
                  const SizedBox(height: 24),
                  Text(
                    'Nightingale TV turns your Jellyfin shows and movies into always-on '
                    'channels with a program guide. Flip around and catch whatever is on.',
                    style: g.body(28, color: g.textDim),
                  ),
                ],
              ),
            )),
          ),
          Expanded(
            flex: 4,
            child: _fitAboveKeyboard(Padding(
              padding: const EdgeInsets.fromLTRB(40, 80, 120, 80),
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._form(g),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 80,
                      child: _busy
                          ? Center(child: CircularProgressIndicator(color: g.accent))
                          : _error == null
                              ? null
                              : Text(_error!, style: g.body(26, color: g.nowLine)),
                    ),
                  ],
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

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

  List<Widget> _form(GuideTheme g) {
    switch (_step) {
      case _Step.server:
        return [
          Text('Connect to your server', style: g.display(44)),
          const SizedBox(height: 32),
          TvTextField(
            controller: _server,
            label: 'Server address',
            hint: 'https://jellyfin.example.org:8920',
            autofocus: true,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 28),
          TvButton(label: 'Connect', icon: Icons.arrow_forward, expand: true, onPressed: _busy ? null : _connect),
        ];
      case _Step.method:
        return [
          Text(_info!.name, style: g.display(44)),
          Text('Jellyfin ${_info!.version} · ${_info!.url}', style: g.body(24, color: g.textDim)),
          const SizedBox(height: 40),
          if (_quickConnectAvailable) ...[
            TvButton(
              label: 'Quick Connect (use your phone)',
              icon: Icons.phonelink_lock,
              expand: true,
              autofocus: true,
              onPressed: _busy ? null : _startQuickConnect,
            ),
            const SizedBox(height: 20),
          ],
          TvButton(
            label: 'Sign in with password',
            icon: Icons.password,
            expand: true,
            autofocus: !_quickConnectAvailable,
            onPressed: () => setState(() => _step = _Step.password),
          ),
          const SizedBox(height: 20),
          TvButton(label: 'Different server', icon: Icons.arrow_back, expand: true, onPressed: _back),
        ];
      case _Step.password:
        return [
          Text('Sign in to ${_info!.name}', style: g.display(44)),
          const SizedBox(height: 32),
          TvTextField(controller: _user, label: 'Username', autofocus: true),
          const SizedBox(height: 20),
          TvTextField(
            controller: _password,
            label: 'Password',
            obscure: true,
            onSubmitted: (_) => _signInWithPassword(),
          ),
          const SizedBox(height: 28),
          TvButton(
              label: 'Sign in', icon: Icons.login, expand: true, onPressed: _busy ? null : _signInWithPassword),
          const SizedBox(height: 20),
          TvButton(label: 'Back', icon: Icons.arrow_back, expand: true, onPressed: _back),
        ];
      case _Step.quickConnect:
        return [
          Text('Quick Connect', style: g.display(44)),
          const SizedBox(height: 16),
          Text(
            'On your phone or computer, open Jellyfin → your profile → Quick Connect, '
            'and enter this code:',
            style: g.body(26, color: g.textDim),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: g.header,
              borderRadius: BorderRadius.circular(g.radius * 2),
              border: Border.all(color: g.accent, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(_quickConnect!.code,
                style: g.display(96, weight: FontWeight.w800, color: g.accent)
                    .copyWith(letterSpacing: 18)),
          ),
          const SizedBox(height: 20),
          Text('Waiting for approval…', style: g.body(24, color: g.textDim)),
          const SizedBox(height: 28),
          TvButton(label: 'Cancel', icon: Icons.close, expand: true, autofocus: true, onPressed: _back),
        ];
    }
  }
}
