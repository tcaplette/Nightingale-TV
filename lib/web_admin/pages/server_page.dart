import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';
import '../../l10n/tr.dart';

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
    final file = await openFile(acceptedTypeGroups: [
      XTypeGroup(label: tr.nightingaleTvBackups, extensions: ['ntvbackup']),
    ]);
    if (file == null || !mounted) return;
    final api = context.api;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final summary = await attempt(context, () => api.upload('restore', bytes));
    if (summary is! Map || !mounted) return;
    final profiles = (summary['profiles'] as List).join(', ');
    final ok = await confirm(context,
        title: tr.restoreThisBackup,
        message: tr.backupSummary('${summary['when']}', '${summary['device']}', profiles, '${summary['channels']}', '${summary['blocks']}',
                '${summary['logos']}') +
            (summary['backsUpFirst'] == true ? '\n\n${tr.backupSavedFirst}' : ''),
        action: tr.restore);
    if (!ok || !mounted) return;
    setState(() => _restoring = true);
    final done = await attempt(context, () => api.post('restore/${summary['id']}/confirm'));
    if (!mounted) return;
    setState(() => _restoring = false);
    if (done != null) {
      showMessage(context, tr.restoredTheBackup2);
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
      return PageBody(title: tr.serverAndSign, children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final profiles = (status['profiles'] as List).cast<Map<String, Object?>>();
    return PageBody(title: tr.serverAndSign, children: [
      if (status['started'] != true) Section(children: [Busy(text: tr.theServerIs)]),
      if (profiles.isEmpty) Section(children: [Text(tr.noProfilesAre)]),
      for (final p in profiles) _ProfileSignIn(profile: p, onChanged: _load),
      if (session.isAdmin) ...[
        Section(title: tr.restoreABackup, children: [
          Text(tr.moveAHousehold),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton.icon(
              icon: const Icon(Icons.restore),
              label: Text(tr.chooseABackup),
              onPressed: _restoring ? null : _restore,
            ),
            if (_restoring) Padding(padding: EdgeInsets.only(left: 12), child: Busy(text: tr.restoring)),
          ]),
        ]),
        if (status['canStartFresh'] == true)
          Section(title: tr.startFresh, children: [
            Text(tr.nameAProfile),
            const SizedBox(height: 12),
            TextField(
              controller: _freshName,
              decoration: InputDecoration(labelText: tr.profileName),
              onSubmitted: (_) => _startFresh(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(onPressed: _startFresh, child: Text(tr.startFresh)),
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
        Text(tr.signedInTo('${profile['server']}', '${profile['user']}'))
      else if (hint != null)
        Text(tr.wasSignedIn('${hint['serverName'] ?? hint['server']}', '${hint['user']}'))
      else
        Text(tr.notSignedIn),
      if (profile['signingIn'] == true) Padding(padding: EdgeInsets.only(top: 8), child: Busy(text: tr.signingIn)),
      if (problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(problem)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonal(
          onPressed: () async {
            await signInDialog(context, id, name);
            if (context.mounted) await context.session.refresh();
            await onChanged();
          },
          child: Text(signedIn ? tr.signInAgain : tr.signIn),
        ),
        if (signedIn)
          OutlinedButton(
            onPressed: () async {
              final ok = await confirm(context,
                  title: tr.signOut4(name), message: tr.itsChannelsStayIt, action: tr.signOut);
              if (!ok || !context.mounted) return;
              await attempt(context, () => context.api.delete('profiles/$id/session'), profileId: id);
              await onChanged();
            },
            child: Text(tr.signOut),
          ),
      ]),
    ]);
  }
}

/// Signs profile [id] in to Jellyfin, Emby or Plex, one step at a time as
/// the TV does, with the TV's wording. With [path] (multi-server): adding a
/// server (`profiles/{id}/servers`) or signing one in again
/// (`profiles/{id}/servers/{key}/sign-in`), titled [title].
Future<void> signInDialog(BuildContext context, String id, String name, {String? path, String? title}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _SignInFlow(id: id, name: name, path: path, title: title)),
      ),
    );

class _SignInFlow extends StatefulWidget {
  const _SignInFlow({required this.id, required this.name, this.path, this.title});
  final String id;
  final String name;
  final String? path;
  final String? title;

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

  String get _path => widget.path ?? 'profiles/${widget.id}/sign-in';

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
        _error ??= tr.couldntDoThat;
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
        Text(widget.path == null ? tr.isSignedIn(widget.name) : 'Done.', style: text.titleMedium),
        const SizedBox(height: 8),
        Text(widget.path == null
            ? tr.itsLibraryIs
            : tr.theLibraryIs),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr.done)),
      ]);
    } else {
      switch (step['stage']) {
        case 'server':
          children.addAll([
            Text(tr.connectToYour, style: text.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: tr.serverAddress, hintText: 'https://media.example.org:8920'),
              onSubmitted: (_) => _send({'action': 'connect', 'address': _address.text.trim()}),
            ),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: busy ? null : () => _send({'action': 'connect', 'address': _address.text.trim()}),
                child: Text(tr.connect)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: busy ? null : () => _send({'action': 'plex'}), child: Text(tr.signInWith)),
          ]);
        case 'method':
          children.addAll([
            Text('${server?['name']}', style: text.titleLarge),
            Text('$kind ${server?['version']} · ${server?['url']}', style: text.bodySmall),
            const SizedBox(height: 16),
            if (step['quickConnect'] == true) ...[
              FilledButton.tonal(
                  onPressed: busy ? null : () => _send({'action': 'quickConnect'}),
                  child: Text(tr.quickConnectUse)),
              const SizedBox(height: 8),
            ],
            FilledButton(
                onPressed: busy ? null : () => _send({'action': 'choosePassword'}), child: Text(tr.signInWithPassword)),
            const SizedBox(height: 8),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.differentServer)),
          ]);
        case 'password':
          void signIn() => _send({'action': 'password', 'user': _user.text.trim(), 'password': _password.text});
          children.addAll([
            Text(tr.signInTo2('${server?['name'] ?? kind}'), style: text.titleLarge),
            if (server != null) Text('$kind ${server['version']} · ${server['url']}', style: text.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              autofocus: _user.text.isEmpty,
              decoration: InputDecoration(labelText: tr.username),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              autofocus: _user.text.isNotEmpty,
              obscureText: true,
              decoration: InputDecoration(labelText: tr.password),
              onSubmitted: (_) => signIn(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : signIn, child: Text(tr.signIn)),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.back)),
          ]);
        case 'quickConnect':
          children.addAll([
            Text(tr.quickConnect, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(tr.onYourPhone(kind)),
            code('${step['quickConnectCode']}'),
            Text(tr.waitingForApproval),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _send({'action': 'back'}), child: Text(tr.cancel)),
          ]);
        case 'plexCode':
          children.addAll([
            Text(tr.signInWith, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(tr.goToPlex),
            if (step['plexCode'] != null) code('${step['plexCode']}'),
            Text(tr.waitingForThe),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _send({'action': 'back'}), child: Text(tr.cancel)),
          ]);
        case 'plexUsers':
          children.addAll([
            Text(tr.whosSigningIn, style: text.titleLarge),
            const SizedBox(height: 12),
            for (final u in (step['homeUsers'] as List).cast<Map>())
              ListTile(
                leading: CircleAvatar(child: Text((u['title'] as String).isEmpty ? '?' : (u['title'] as String)[0])),
                title: Text(u['title'] as String),
                trailing: u['protected'] == true ? const Icon(Icons.lock_outline) : null,
                onTap: busy ? null : () => _send({'action': 'homeUser', 'id': u['id']}),
              ),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.back)),
          ]);
        case 'plexPin':
          void enter() => _send({'action': 'homePin', 'pin': _pin.text});
          children.addAll([
            Text(tr.pinFor('${step['homeUser'] ?? ''}'), style: text.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(labelText: tr.pin),
              onSubmitted: (_) => enter(),
            ),
            FilledButton(onPressed: busy ? null : enter, child: Text(tr.ok)),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.back)),
          ]);
        case 'plexServers':
          final servers = (step['servers'] as List).cast<Map>();
          children.addAll([
            Text(tr.chooseAServer, style: text.titleLarge),
            const SizedBox(height: 12),
            for (final s in servers)
              ListTile(
                title: Text(s['label'] as String),
                // Already in the profile (adding a server): not pickable.
                trailing: Text(s['added'] == true ? tr.added : (s['online'] == true ? tr.online : tr.offline)),
                enabled: s['added'] != true,
                onTap: busy || s['added'] == true ? null : () => _send({'action': 'server', 'id': s['id']}),
              ),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.back)),
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
            Expanded(child: Text(widget.title ?? tr.signIn2(widget.name), style: text.labelLarge)),
            IconButton(tooltip: tr.close, icon: const Icon(Icons.close), onPressed: _close),
          ]),
          ...children,
        ]),
      ),
    );
  }
}
