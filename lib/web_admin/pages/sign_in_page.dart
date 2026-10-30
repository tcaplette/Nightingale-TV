import 'package:flutter/material.dart';

import '../../ui/widgets/nightingale_mark.dart';
import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';

/// A centred card for the pages before signing in.
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        NightingaleMark(height: 28, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Semantics(
                            header: true,
                            child: Text('Nightingale TV', style: Theme.of(context).textTheme.headlineSmall),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      ...children,
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Signing in with a user name and password. On a server with no accounts
/// yet, only the setup link works, and this says so.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool? _hasUsers;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final auth = (await context.api.get('auth'))! as Map;
      if (mounted) setState(() => _hasUsers = auth['password'] == true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.api.post('session', {'name': _name.text.trim(), 'password': _password.text});
      if (!mounted) return;
      await context.session.refresh();
      widget.onSignedIn();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasUsers == null) {
      return _Card(children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
        if (_error != null) TextButton(onPressed: _check, child: const Text('Try again')),
      ]);
    }
    if (_hasUsers == false) return const _Card(children: [Text("Open the setup link from the server's log.")]);
    return _Card(children: [
      TextField(
        controller: _name,
        autofocus: true,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(labelText: 'User name'),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (_) => _signIn(),
      ),
      ErrorText(_error),
      const SizedBox(height: 12),
      FilledButton(onPressed: _busy ? null : _signIn, child: const Text('Sign in')),
    ]);
  }
}

/// The setup link from the server's log: makes the first admin, or after
/// `NTV_RESET_PASSWORD=1` sets a new password for an admin chosen here.
class SetupLinkPage extends StatefulWidget {
  const SetupLinkPage({super.key, required this.token});

  final String token;

  @override
  State<SetupLinkPage> createState() => _SetupLinkPageState();
}

class _SetupLinkPageState extends State<SetupLinkPage> {
  final _name = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _again = TextEditingController();
  Map<String, Object?>? _auth;
  String? _admin;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = (await context.api.get('auth', {'token': widget.token}))! as Map<String, Object?>;
      if (!mounted) return;
      setState(() {
        _auth = auth;
        _admin = ((auth['admins'] as List?)?.firstOrNull as Map?)?['id'] as String?;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_password.text != _again.text) {
      setState(() => _error = "The passwords don't match.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final reset = _auth?['setup'] == 'reset';
    try {
      await context.api.post('password', {
        'token': widget.token,
        'password': _password.text,
        if (reset) 'user': _admin else 'name': _name.text.trim(),
      });
      if (!mounted) return;
      await context.session.refresh();
      if (mounted) context.go('/setup');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    if (auth == null) {
      return _Card(children: [if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error)]);
    }
    final setup = auth['setup'];
    if (setup == null) {
      return _Card(children: [
        const Text("This setup link has been used, or it's from an earlier start. Open the newest one from the "
            "server's log, or sign in."),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => context.go('/'), child: const Text('Sign in')),
      ]);
    }
    final reset = setup == 'reset';
    final admins = (auth['admins'] as List? ?? const []).cast<Map<String, Object?>>();
    return _Card(children: [
      Text(reset ? 'Set a new password for an admin account.' : 'Make the first admin account.',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      if (reset)
        DropdownButtonFormField<String>(
          initialValue: _admin,
          decoration: const InputDecoration(labelText: 'Admin account'),
          items: [for (final a in admins) DropdownMenuItem(value: a['id'] as String, child: Text(a['name'] as String))],
          onChanged: (v) => setState(() => _admin = v),
        )
      else
        TextField(
          controller: _name,
          autofocus: true,
          autofillHints: const [AutofillHints.newUsername],
          decoration: const InputDecoration(labelText: 'User name'),
          textInputAction: TextInputAction.next,
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: true,
        autofocus: reset,
        autofillHints: const [AutofillHints.newPassword],
        decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters.'),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _again,
        obscureText: true,
        autofillHints: const [AutofillHints.newPassword],
        decoration: const InputDecoration(labelText: 'Password again'),
        onSubmitted: (_) => _submit(),
      ),
      ErrorText(_error),
      const SizedBox(height: 12),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(reset ? 'Set password and sign in' : 'Make account and sign in')),
    ]);
  }
}
