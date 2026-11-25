import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';
import 'youtube_setup.dart';
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
    final profiles = (summary['profiles'] as List).join(tr.listSeparator);
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
  final _smbAddress = TextEditingController();
  final _domain = TextEditingController();
  final _historyName = TextEditingController();

  /// The colour step's selection; the server's colour until one is picked.
  String? _color;

  /// YouTube chosen (or the profile's restored sign-in is YouTube's): its
  /// own steps take over the dialog (docker-youtube).
  bool _youTube = false;

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
    final searching = (_step?['smb'] as Map?)?['searching'] == true;
    if (_sending || (stage != 'quickConnect' && stage != 'plexCode' && _step?['busy'] != true && !searching)) return;
    try {
      // A profile's sign-in has its step at a GET; adding a server or
      // signing in to one again asks for it.
      final api = context.api;
      final step = (widget.path == null ? await api.get(_path) : await api.post(_path, {'action': 'step'}))! as Map<String, Object?>;
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

  /// YouTube's own steps, in place of the server ones.
  void _openYouTube() {
    unawaited(context.api.post(_path, {'action': 'cancel'}).then((_) {}, onError: (Object _) {}));
    _poll?.cancel();
    setState(() => _youTube = true);
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    // A restored profile whose sign-in was YouTube: the server asks for the
    // user's own client.
    if (!_youTube && const {'youtubeClient', 'youtubeCode', 'youtubePicker'}.contains(step?['stage'])) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_youTube) _openYouTube();
      });
    }
    if (_youTube) {
      return YouTubeSetup(
          profileId: widget.id, title: widget.title ?? tr.signIn2(widget.name), onClose: () => Navigator.of(context).pop());
    }
    final text = Theme.of(context).textTheme;
    final busy = _sending || step?['busy'] == true;
    final server = step?['server'] as Map?;
    final kind = server?['kind'] as String? ?? 'Jellyfin';
    Widget code(String value) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            // Screen readers read the code too.
            child: SelectableText(value,
                semanticsLabel: value, style: text.displaySmall?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700)),
          ),
        );
    final children = <Widget>[];
    if (step == null) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else if (step['finished'] == true) {
      children.addAll([
        Text(widget.path == null ? tr.isSignedIn(widget.name) : tr.done, style: text.titleMedium),
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
          void connect() => _send({'action': 'connect', 'address': _address.text.trim()});
          children.addAll([
            Text(tr.connectToYour, style: text.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: tr.serverAddress, hintText: 'https://media.example.org:8920'),
              onSubmitted: (_) => connect(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : connect, child: Text(tr.connect)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: busy ? null : () => _send({'action': 'plex'}), child: Text(tr.signInWith)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: busy ? null : () => _send({'action': 'smb'}), child: Text(tr.smbShareButton)),
            const SizedBox(height: 8),
            OutlinedButton(key: const ValueKey('add-youtube'), onPressed: busy ? null : _openYouTube, child: Text(tr.youTube)),
          ]);
        // SMB shares (smb-sources).
        case 'smbFind':
          final smb = step['smb'] as Map? ?? const {};
          void go() => _send({'action': 'smbAddress', 'address': _smbAddress.text.trim()});
          children.addAll([
            Text(tr.smbFindTitle, style: text.titleLarge),
            Text(tr.smbFindHelp, style: text.bodySmall),
            const SizedBox(height: 12),
            for (final h in (smb['hosts'] as List? ?? const []).cast<Map>())
              ListTile(
                leading: const Icon(Icons.computer),
                title: Text('${h['name']}'),
                subtitle: Text('${h['address']}'),
                onTap: busy ? null : () => _send({'action': 'smbHost', 'address': h['address']}),
              ),
            Text(smb['searching'] == true ? tr.smbSearching : ((smb['hosts'] as List?)?.isEmpty ?? true ? tr.smbNoneFound : ''),
                style: text.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _smbAddress,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: tr.smbAddress, hintText: 'smb://192.168.1.5/media'),
              onSubmitted: (_) => go(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : go, child: Text(tr.connect)),
            TextButton(
                onPressed: busy || smb['searching'] == true ? null : () => _send({'action': 'smbSearch'}),
                child: Text(tr.smbSearchAgain)),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.back)),
          ]);
        case 'smbShares':
          final smb = step['smb'] as Map? ?? const {};
          children.addAll([
            Text(tr.smbSharesOn('${smb['host'] ?? ''}'), style: text.titleLarge),
            if (smb['smb1'] == true) Text(tr.smbOld, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            for (final s in (smb['shares'] as List? ?? const []).cast<Map>())
              ListTile(
                leading: const Icon(Icons.folder_shared),
                title: Text('${s['name']}'),
                subtitle: '${s['comment']}'.isEmpty ? null : Text('${s['comment']}'),
                onTap: busy ? null : () => _send({'action': 'smbShare', 'share': s['name']}),
              ),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.back)),
          ]);
        case 'smbSignIn':
          final smb = step['smb'] as Map? ?? const {};
          if (_user.text.isEmpty && '${smb['user'] ?? ''}'.isNotEmpty) _user.text = '${smb['user']}';
          void signIn() => _send({'action': 'smbSignIn', 'user': _user.text.trim(), 'password': _password.text, 'domain': _domain.text.trim()});
          children.addAll([
            Text(tr.smbSignInTo('${smb['share'] ?? smb['host'] ?? ''}'), style: text.titleLarge),
            if (smb['smb1'] == true) Text(tr.smbOld, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            TextField(controller: _user, autofocus: true, decoration: InputDecoration(labelText: tr.username), textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: tr.password),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => signIn()),
            const SizedBox(height: 12),
            TextField(controller: _domain, decoration: InputDecoration(labelText: tr.smbDomain), onSubmitted: (_) => signIn()),
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : signIn, child: Text(tr.signIn)),
            OutlinedButton(onPressed: busy ? null : () => _send({'action': 'smbGuest'}), child: Text(tr.smbAsGuest)),
            TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.back)),
          ]);
        case 'smbFolders':
          final smb = step['smb'] as Map? ?? const {};
          final folder = '${smb['folder'] ?? ''}';
          final mappings = (smb['mappings'] as Map? ?? const {}).cast<String, Object?>();
          if (_historyName.text.isEmpty) _historyName.text = '${smb['historyName'] ?? ''}';
          children.addAll([
            Text(tr.smbWhatsIn(folder.isEmpty ? '${smb['share']}' : '${smb['share']} › ${folder.replaceAll('/', ' › ')}'),
                style: text.titleLarge),
            Text(tr.smbMapHelp, style: text.bodySmall),
            const SizedBox(height: 12),
            if (folder.isNotEmpty) TextButton.icon(icon: const Icon(Icons.arrow_upward), label: Text(tr.smbUp), onPressed: busy ? null : () => _send({'action': 'back'})),
            for (final f in (smb['folders'] as List? ?? const []).cast<String>())
              SmbFolderRow(
                name: f,
                type: mappings[folder.isEmpty ? f : '$folder/$f'] as String?,
                onOpen: busy ? null : () => _send({'action': 'smbFolder', 'path': folder.isEmpty ? f : '$folder/$f'}),
                onType: (t) => _send({'action': 'smbMap', 'path': folder.isEmpty ? f : '$folder/$f', 'type': t}),
              ),
            if (folder.isEmpty) ...[
              const SizedBox(height: 12),
              if (smb['writable'] != false) ...[
                TextField(controller: _historyName, decoration: InputDecoration(labelText: tr.smbHistoryName, helperText: tr.smbHistoryHelp, helperMaxLines: 4)),
                CheckboxListTile(
                  value: smb['keepLocal'] == true,
                  title: Text(tr.smbKeepLocal),
                  onChanged: busy ? null : (v) => _send({'action': 'smbHistory', 'keepLocal': v == true}),
                ),
              ] else
                Text(tr.smbReadOnly, style: text.bodySmall),
            ],
            const SizedBox(height: 12),
            FilledButton(
                onPressed: busy ? null : () => _send({'action': 'smbDone', 'historyName': _historyName.text.trim()}),
                child: Text(tr.smbFoldersDone)),
            if (folder.isEmpty) TextButton(onPressed: busy ? null : () => _send({'action': 'back'}), child: Text(tr.back)),
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
        // Adding a server, last: its guide colour (guide-server-colors).
        case 'color':
          final color = step['color'] as Map? ?? const {};
          final palette = (color['palette'] as List? ?? const []).cast<Map>();
          final selected = _color ?? color['selected'] as String?;
          children.addAll([
            Text(tr.guideColorTitle('${color['name'] ?? ''}'), style: text.titleLarge),
            Text(tr.guideColorHelp, style: text.bodySmall),
            const SizedBox(height: 12),
            RadioGroup<String>(
              key: const ValueKey('guide-colors'),
              groupValue: selected,
              onChanged: (v) {
                if (!busy) setState(() => _color = v);
              },
              child: Column(children: [
                for (final c in palette)
                  RadioListTile<String>(
                    key: ValueKey('color-${c['name']}'),
                    contentPadding: EdgeInsets.zero,
                    value: c['name'] as String,
                    secondary: Container(
                        width: 24, height: 24, decoration: BoxDecoration(color: hexColor(c['hex']), shape: BoxShape.circle)),
                    title: Text(c['usedBy'] == null ? '${c['label']}' : tr.guideColorUsedBy('${c['label']}', '${c['usedBy']}')),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            FilledButton(
                key: const ValueKey('color-done'),
                onPressed: busy || selected == null ? null : () => _send({'action': 'color', 'name': selected}),
                child: Text(tr.done)),
          ]);
      }
      if (busy) children.add(const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()));
      children.add(ErrorText((step['error'] as String?) ?? _error));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        // Each step opens at its top, not where the last one was scrolled to.
        key: ValueKey('step-${step?['stage']}-${step?['finished']}'),
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

/// The content types a share's folder can hold, by their API names.
const smbFolderTypes = ['tvShows', 'movies', 'music', 'musicVideos', 'homeVideos', 'commercials', 'bumpers'];

String smbFolderTypeLabel(String? type) => switch (type) {
      'tvShows' => tr.smbTypeTv,
      'movies' => tr.smbTypeMovies,
      'music' => tr.smbTypeMusic,
      'musicVideos' => tr.smbTypeMusicVideos,
      'homeVideos' => tr.smbTypeHome,
      'commercials' => tr.smbTypeCommercials,
      'bumpers' => tr.smbTypeBumpers,
      _ => tr.smbTypeNone,
    };

/// A share's folder: its name opens it, the menu picks what it holds.
class SmbFolderRow extends StatelessWidget {
  const SmbFolderRow({super.key, required this.name, required this.type, required this.onType, this.onOpen});

  final String name;
  final String? type;
  final VoidCallback? onOpen;
  final ValueChanged<String?> onType;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.folder),
        title: Text(name),
        onTap: onOpen,
        trailing: DropdownButton<String?>(
          value: type,
          items: [
            DropdownMenuItem<String?>(child: Text(smbFolderTypeLabel(null))),
            for (final t in smbFolderTypes) DropdownMenuItem<String?>(value: t, child: Text(smbFolderTypeLabel(t))),
          ],
          onChanged: onType,
        ),
      );
}
