import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';

/// The server and its profiles' sign-ins: what the docker-server-core setup
/// page did (restore or start fresh, signing profiles in to Jellyfin, Emby
/// or Plex, signing out), refreshed every 3 seconds while it's open.
class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  Map<String, Object?>? _status;
  String? _error;
  Timer? _poll;
  bool _restoring = false;
  final _freshName = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = (await context.api.get('status'))! as Map<String, Object?>;
      if (mounted) setState(() => _status = status);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _restore() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Nightingale TV backups', extensions: ['ntvbackup']),
    ]);
    if (file == null || !mounted) return;
    final api = context.api;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final summary = await attempt(context, () => api.upload('restore', bytes));
    if (summary is! Map || !mounted) return;
    final profiles = (summary['profiles'] as List).join(', ');
    final ok = await confirm(context,
        title: 'Restore this backup?',
        message: 'From ${summary['when']} (${summary['device']}): $profiles. '
            '${summary['channels']} channels, ${summary['blocks']} programming blocks, ${summary['logos']} logos.'
            '${summary['backsUpFirst'] == true ? '\n\nA backup of what\'s here now is saved first.' : ''}',
        action: 'Restore');
    if (!ok || !mounted) return;
    setState(() => _restoring = true);
    final done = await attempt(context, () => api.post('restore/${summary['id']}/confirm'));
    if (!mounted) return;
    setState(() => _restoring = false);
    if (done != null) {
      showMessage(context, 'Restored the backup.');
      await context.session.refresh();
      await _load();
    }
  }

  Future<void> _startFresh() async {
    final api = context.api;
    final made = await attempt(context, () => api.post('profiles', {'name': _freshName.text.trim()}));
    if (made is! Map || !mounted) return;
    await context.session.refresh();
    if (!mounted) return;
    await signInDialog(context, made['id'] as String, made['name'] as String);
    if (mounted) await context.session.refresh();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final session = context.session;
    if (status == null) {
      return PageBody(title: 'Server and sign-in', children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final profiles = (status['profiles'] as List).cast<Map<String, Object?>>();
    return PageBody(title: 'Server and sign-in', children: [
      if (status['started'] != true) const Section(children: [Busy(text: 'The server is starting…')]),
      if (profiles.isEmpty) const Section(children: [Text('No profiles are assigned to you yet. Ask an admin.')]),
      for (final p in profiles) _ProfileSignIn(profile: p, onChanged: _load),
      if (session.isAdmin) ...[
        Section(title: 'Restore a backup', children: [
          const Text('Move a household here from a TV or another server: its profiles, channels, blocks, logos and '
              'export settings.'),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Choose a backup file…'),
              onPressed: _restoring ? null : _restore,
            ),
            if (_restoring) const Padding(padding: EdgeInsets.only(left: 12), child: Busy(text: 'Restoring…')),
          ]),
        ]),
        if (status['canStartFresh'] == true)
          Section(title: 'Start fresh', children: [
            const Text('Name a profile, sign it in to your media server, and its channels are made and exported.'),
            const SizedBox(height: 12),
            TextField(
              controller: _freshName,
              decoration: const InputDecoration(labelText: 'Profile name'),
              onSubmitted: (_) => _startFresh(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(onPressed: _startFresh, child: const Text('Start fresh')),
            ),
          ]),
      ],
      Section(children: [
        Text('${status['device']} · ${status['host']}', style: Theme.of(context).textTheme.bodySmall),
      ]),
    ]);
  }
}

class _ProfileSignIn extends StatelessWidget {
  const _ProfileSignIn({required this.profile, required this.onChanged});

  final Map<String, Object?> profile;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final id = profile['id'] as String;
    final name = profile['name'] as String;
    final signedIn = profile['signedIn'] == true;
    final hint = profile['hint'] as Map?;
    final problem = profile['problem'] as String?;
    return Section(title: name, children: [
      if (signedIn)
        Text('Signed in to ${profile['server']} as ${profile['user']}.')
      else if (hint != null)
        Text('Was signed in to ${hint['serverName'] ?? hint['server']} as ${hint['user']}. Sign in again.')
      else
        const Text('Not signed in.'),
      if (profile['signingIn'] == true) const Padding(padding: EdgeInsets.only(top: 8), child: Busy(text: 'Signing in…')),
      if (problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(problem)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonal(
          onPressed: () async {
            await signInDialog(context, id, name);
            if (context.mounted) await context.session.refresh();
            await onChanged();
          },
          child: Text(signedIn ? 'Sign in again' : 'Sign in'),
        ),
        if (signedIn)
          OutlinedButton(
            onPressed: () async {
              final ok = await confirm(context,
                  title: 'Sign $name out?', message: 'Its channels stay; it needs signing in to play.', action: 'Sign out');
              if (!ok || !context.mounted) return;
              await attempt(context, () => context.api.delete('profiles/$id/session'), profileId: id);
              await onChanged();
            },
            child: const Text('Sign out'),
          ),
      ]),
    ]);
  }
}

/// Signs profile [id] in to Jellyfin, Emby or Plex, one step at a time as
/// the TV does, with the TV's wording.
Future<void> signInDialog(BuildContext context, String id, String name) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: _SignInFlow(id: id, name: name)),
      ),
    );

class _SignInFlow extends StatefulWidget {
  const _SignInFlow({required this.id, required this.name});
  final String id;
  final String name;

  @override
  State<_SignInFlow> createState() => _SignInFlowState();
}

class _SignInFlowState extends State<_SignInFlow> {
  Map<String, Object?>? _step;
  String? _error;
  bool _sending = false;
  Timer? _poll;
  final _address = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();

  String get _path => 'profiles/${widget.id}/sign-in';

  @override
  void initState() {
    super.initState();
    _send({'action': 'start'});
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Polls while a code waits to be approved or a step is busy.
  Future<void> _refresh() async {
    final stage = _step?['stage'];
    if (_sending || (stage != 'quickConnect' && stage != 'plexCode' && _step?['busy'] != true)) return;
    try {
      final step = (await context.api.get(_path))! as Map<String, Object?>;
      if (mounted) setState(() => _step = step);
    } on ApiException {
      // The next poll tries again.
    }
  }

  Future<void> _send(Map<String, Object?> body) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final step = await attempt(context, () => context.api.post(_path, body), profileId: widget.id, quiet: true);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (step is Map<String, Object?>) {
        _step = step;
        final hint = step['hint'] as Map?;
        if (hint != null) {
          if (_address.text.isEmpty) _address.text = hint['server'] as String? ?? '';
          if (_user.text.isEmpty) _user.text = hint['user'] as String? ?? '';
        }
      } else {
        _error ??= "Couldn't do that. Try again.";
      }
    });
  }

  void _close() {
    if (_step?['finished'] != true) unawaited(context.api.post(_path, {'action': 'cancel'}).catchError((_) => null));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final text = Theme.of(context).textTheme;
    final busy = _sending || step?['busy'] == true;
    final server = step?['server'] as Map?;
    final kind = server?['kind'] as String? ?? 'Jellyfin';
    Widget code(String value) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SelectableText(value, style: text.displaySmall?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700)),
          ),
        );
    final children = <Widget>[];
    if (step == null) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else if (step['finished'] == true) {
      children.addAll([
        Text('${widget.name} is signed in.', style: text.titleMedium),
        const SizedBox(height: 8),
        const Text('Its library is being read and its channels made. This takes a minute or two.'),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ]);
    } else {
      switch (step['stage']) {
        case 'server':
          children.addAll([
            Text('Connect to your server', style: text.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Server address', hintText: 'https://media.example.org:8920'),
              onSubmitted: (_) => _send({'action': 'connect', 'address': _address.text.trim()}),
            ),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: busy ? null : () => _send({'action': 'connect', 'address': _address.text.trim()}),
                child: const Text('Connect')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: busy ? null : () => _send({'action': 'plex'}), child: const Text('Sign in with Plex')),
          ]);
        case 'method':
          children.addAll([
            Text('${server?['name']}', style: text.titleLarge),
            Text('$kind ${server?['version']} · ${server?['url']}', style: text.bodySmall),
            const SizedBox(height: 16),
            if (step['quickConnect'] == true) ...[
              FilledButton.tonal(
                  onPressed: busy ? null : () => _send({'action': 'quickConnect'}),
                  child: const Text('Quick Connect (use your phone)')),
              const SizedBox(height: 8),
            ],
            FilledButton(
                onPressed: busy ? null : () => _send({'action': 'choosePassword'}), child: const Text('Sign in with password')),
            const SizedBox(height: 8),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: const Text('Different server')),
          ]);
        case 'password':
          void signIn() => _send({'action': 'password', 'user': _user.text.trim(), 'password': _password.text});
          children.addAll([
            Text('Sign in to ${server?['name'] ?? kind}', style: text.titleLarge),
            if (server != null) Text('$kind ${server['version']} · ${server['url']}', style: text.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              autofocus: _user.text.isEmpty,
              decoration: const InputDecoration(labelText: 'Username'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              autofocus: _user.text.isNotEmpty,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (_) => signIn(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : signIn, child: const Text('Sign in')),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: const Text('Back')),
          ]);
        case 'quickConnect':
          children.addAll([
            Text('Quick Connect', style: text.titleLarge),
            const SizedBox(height: 8),
            Text('On your phone or computer, open $kind → your profile → Quick Connect, and enter this code:'),
            code('${step['quickConnectCode']}'),
            const Text('Waiting for approval…'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _send({'action': 'back'}), child: const Text('Cancel')),
          ]);
        case 'plexCode':
          children.addAll([
            Text('Sign in with Plex', style: text.titleLarge),
            const SizedBox(height: 8),
            const Text('Go to plex.tv/link on your phone or computer and enter this code.'),
            if (step['plexCode'] != null) code('${step['plexCode']}'),
            const Text('Waiting for the code to be linked…'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _send({'action': 'back'}), child: const Text('Cancel')),
          ]);
        case 'plexUsers':
          children.addAll([
            Text("Who's signing in?", style: text.titleLarge),
            const SizedBox(height: 12),
            for (final u in (step['homeUsers'] as List).cast<Map>())
              ListTile(
                leading: CircleAvatar(child: Text((u['title'] as String).isEmpty ? '?' : (u['title'] as String)[0])),
                title: Text(u['title'] as String),
                trailing: u['protected'] == true ? const Icon(Icons.lock_outline) : null,
                onTap: busy ? null : () => _send({'action': 'homeUser', 'id': u['id']}),
              ),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: const Text('Back')),
          ]);
        case 'plexPin':
          void enter() => _send({'action': 'homePin', 'pin': _pin.text});
          children.addAll([
            Text('PIN for ${step['homeUser'] ?? ''}', style: text.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'PIN'),
              onSubmitted: (_) => enter(),
            ),
            FilledButton(onPressed: busy ? null : enter, child: const Text('OK')),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: const Text('Back')),
          ]);
        case 'plexServers':
          final servers = (step['servers'] as List).cast<Map>();
          children.addAll([
            Text('Choose a server', style: text.titleLarge),
            const SizedBox(height: 12),
            for (final s in servers)
              ListTile(
                title: Text(s['label'] as String),
                trailing: Text(s['online'] == true ? 'Online' : 'Offline'),
                onTap: busy ? null : () => _send({'action': 'server', 'id': s['id']}),
              ),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: const Text('Back')),
          ]);
      }
      if (busy) children.add(const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()));
      children.add(ErrorText((step['error'] as String?) ?? _error));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Sign ${widget.name} in', style: text.labelLarge)),
            IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: _close),
          ]),
          ...children,
        ]),
      ),
    );
  }
}
