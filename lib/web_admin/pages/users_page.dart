import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';

/// Users (admin): add, change role and profiles, turn off, set a password,
/// remove. Accounts a restore added show "Needs a password".
class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) => DataView<(List<Map<String, Object?>>, List<Map<String, Object?>>)>(
        load: () async {
          final api = context.api;
          final users = ((await api.get('users'))! as List).cast<Map<String, Object?>>();
          final profiles = ((await api.get('profiles'))! as List).cast<Map<String, Object?>>();
          return (users, profiles);
        },
        builder: (context, data, reload) {
          final (users, profiles) = data;
          final names = {for (final p in profiles) p['id']: p['name']};
          final me = context.session.me?['id'];
          return PageBody(
            title: 'Users',
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add user'),
                onPressed: () async {
                  final ok = await showDialog<bool>(context: context, builder: (_) => _UserDialog(profiles: profiles));
                  if (ok == true) await reload();
                },
              ),
            ],
            children: [
              for (final u in users)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${u['name']}${u['id'] == me ? ' (you)' : ''}'),
                    subtitle: Text([
                      u['role'] == 'admin' ? 'Admin' : 'User',
                      if (u['role'] != 'admin')
                        (u['profiles'] as List).isEmpty
                            ? 'No profiles'
                            : (u['profiles'] as List).map((id) => names[id] ?? id).join(', '),
                      if (u['disabled'] == true) 'Turned off',
                      if (u['needsPassword'] == true) 'Needs a password',
                    ].join(' · ')),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                          context: context, builder: (_) => _UserDialog(profiles: profiles, user: u, isMe: u['id'] == me));
                      if (ok == true && context.mounted) {
                        await reload();
                        if (context.mounted) await context.session.refresh();
                      }
                    },
                  ),
                ),
            ],
          );
        },
      );
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.profiles, this.user, this.isMe = false});

  final List<Map<String, Object?>> profiles;
  final Map<String, Object?>? user;
  final bool isMe;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late final _name = TextEditingController(text: widget.user?['name'] as String? ?? '');
  final _password = TextEditingController();
  late String _role = widget.user?['role'] as String? ?? 'user';
  late bool _disabled = widget.user?['disabled'] == true;
  late final Set<String> _profiles = {...(widget.user?['profiles'] as List? ?? const []).cast<String>()};
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e is ApiConflict ? conflictText : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
        final api = context.api;
        final user = widget.user;
        if (user == null) {
          await api.post('users', {
            'name': _name.text.trim(),
            'role': _role,
            'password': _password.text,
            'profiles': _profiles.toList(),
          });
          return;
        }
        final path = 'users/${user['id']}';
        await api.put(path, {'name': _name.text.trim(), 'role': _role, 'disabled': _disabled, 'profiles': _profiles.toList()});
        if (_password.text.isNotEmpty) await api.put('$path/password', {'password': _password.text});
      });

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return AlertDialog(
      title: Text(user == null ? 'Add user' : 'Edit ${user['name']}'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _name, autofocus: user == null, decoration: const InputDecoration(labelText: 'User name')),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: user == null ? 'Password' : 'New password',
              helperText: user == null
                  ? 'At least 8 characters.'
                  : user['needsPassword'] == true
                      ? 'Needs a password before it can sign in.'
                      : 'Leave empty to keep it. Setting one signs them out elsewhere.',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'user', label: Text('User')),
              ButtonSegment(value: 'admin', label: Text('Admin')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.single),
          ),
          const SizedBox(height: 8),
          Text(_role == 'admin' ? 'Admins can do everything, on every profile.' : 'Users reach only the profiles below.'),
          if (_role == 'user') ...[
            const SizedBox(height: 8),
            for (final p in widget.profiles)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _profiles.contains(p['id']),
                title: Text(p['name'] as String),
                onChanged: (on) => setState(() => on == true ? _profiles.add(p['id'] as String) : _profiles.remove(p['id'])),
              ),
          ],
          if (user != null && !widget.isMe)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Turned off'),
              subtitle: const Text("Can't sign in; signed out everywhere."),
              value: _disabled,
              onChanged: (v) => setState(() => _disabled = v),
            ),
          ErrorText(_error),
        ]),
      ),
      actions: [
        if (user != null && !widget.isMe)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final ok = await confirm(context,
                        title: 'Remove ${user['name']}?', message: 'They are signed out and can\'t sign in again.', action: 'Remove');
                    if (ok && context.mounted) await _run(() => context.api.delete('users/${user['id']}'));
                  },
            child: const Text('Remove'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

/// Changing your own password, giving the current one. Your other browsers
/// are signed out.
class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _again = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    if (_password.text != _again.text) {
      setState(() => _error = "The new passwords don't match.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.api.put('me/password', {'current': _current.text, 'password': _password.text});
      if (!mounted) return;
      _current.clear();
      _password.clear();
      _again.clear();
      showMessage(context, 'Password changed. Your other browsers are signed out.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(title: 'Change password', children: [
        Section(children: [
          AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _current,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Current password'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters.'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _again,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'New password again'),
                onSubmitted: (_) => _save(),
              ),
              ErrorText(_error),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Change password')),
              ),
            ]),
          ),
        ]),
      ]);
}
