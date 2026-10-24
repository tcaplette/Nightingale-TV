import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../app.dart';
import '../browser.dart';
import '../session.dart';

/// What a stale save shows (web-admin "Showing errors, conflicts and
/// progress").
const conflictText = 'Changed in another window. Showing the latest.';

/// A page: its title, then its content, scrolling, with phone-sized
/// gutters.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.title, required this.children, this.actions = const []});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    // Everything built, not a lazy list: Tab only reaches built widgets, and
    // a form's Save must be reachable from the keyboard.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 24, 16, narrow ? 16 : 24, 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
            if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }
}

/// A titled card of related settings.
class Section extends StatelessWidget {
  const Section({super.key, this.title, required this.children, this.trailing});

  final String? title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: Semantics(
                          header: true, child: Text(title!, style: Theme.of(context).textTheme.titleMedium)),
                    ),
                    ?trailing,
                  ]),
                ),
              ...children,
            ],
          ),
        ),
      );
}

/// Loads data with [load] and builds it; shows progress, and an error with
/// Try again. [reload] in the builder loads it again (after a change or a
/// conflict).
class DataView<T> extends StatefulWidget {
  const DataView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = _data == null);
    try {
      final data = await widget.load();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
          _loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) return widget.builder(context, data, _reload);
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _reload, child: const Text('Try again')),
        ]),
      ),
    );
  }
}

/// Runs [call] for a page. A refusal that a PIN would let through asks for
/// it and tries once more; a stale save shows [conflictText] and runs
/// [onConflict] (reload); any other refusal is shown. Null when it didn't
/// go through.
Future<T?> attempt<T>(BuildContext context, Future<T> Function() call,
    {String? profileId, Future<void> Function()? onConflict, bool quiet = false}) async {
  for (var tries = 0; tries < 2; tries++) {
    try {
      return await call();
    } on ApiConflict {
      if (context.mounted) showMessage(context, conflictText);
      await onConflict?.call();
      return null;
    } on ApiException catch (e) {
      final id = profileId;
      if (tries == 0 && id != null && e.needs != null && context.mounted) {
        if (await unlock(context, id, grownUp: e.needs == 'grownUp')) continue;
        return null;
      }
      if (!quiet && context.mounted) showMessage(context, e.message);
      return null;
    }
  }
  return null;
}

void showMessage(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

/// Asks for a profile's PIN (or with [grownUp], a grown-up's) and unlocks
/// it for this session. True when it worked.
Future<bool> unlock(BuildContext context, String profileId, {bool grownUp = false}) async {
  final session = context.session;
  final name = session.profileById(profileId)?.name ?? 'this profile';
  String? error;
  while (true) {
    if (!context.mounted) return false;
    final pin = await askPin(context,
        title: grownUp ? "A grown-up's PIN" : 'PIN for $name',
        message: grownUp
            ? "Changing a kid profile's settings needs the PIN of a grown-up profile."
            : '$name has a PIN.',
        error: error);
    if (pin == null || !context.mounted) return false;
    try {
      await context.api.post('profiles/$profileId/unlock', grownUp ? {'grownUp': pin} : {'pin': pin});
      await session.refresh();
      return true;
    } on ApiException catch (e) {
      error = e.message;
    }
  }
}

/// A 4-digit PIN, or null when cancelled (Esc).
Future<String?> askPin(BuildContext context, {required String title, String? message, String? error}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit() {
        if (RegExp(r'^\d{4}$').hasMatch(controller.text)) Navigator.of(context).pop(controller.text);
      }

      return AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (message != null) Text(message),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'PIN', errorText: error),
            onSubmitted: (_) => submit(),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: submit, child: const Text('OK')),
        ],
      );
    },
  );
}

/// Asks to go ahead with [action]; true when confirmed.
Future<bool> confirm(BuildContext context, {required String title, required String message, required String action}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// Asks for a line of text (a name), or null when cancelled.
Future<String?> askText(BuildContext context,
    {required String title, required String label, String initial = '', String action = 'Save'}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: Text(action)),
      ],
    ),
  );
}

/// Which profile the pages edit. Picking one with a PIN asks for it.
class ProfileSwitcher extends StatelessWidget {
  const ProfileSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final session = context.session;
    final profiles = session.profiles;
    if (profiles.isEmpty) {
      return compact ? const SizedBox.shrink() : const Text('No profiles are assigned to you yet. Ask an admin.');
    }
    return DropdownButton<String>(
      value: session.profileId,
      isExpanded: !compact,
      underline: const SizedBox.shrink(),
      hint: const Text('Profile'),
      items: [
        for (final p in profiles)
          DropdownMenuItem(
            value: p.id,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ProfileDot(profile: p),
              const SizedBox(width: 8),
              Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
              if (p.locked) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.lock_outline, size: 16)),
            ]),
          ),
      ],
      onChanged: (id) async {
        if (id == null) return;
        final p = session.profileById(id)!;
        if (p.locked && !await unlock(context, id)) return;
        if (!context.mounted) return;
        final location = AdminScope.of(context).router.location;
        final segments = location.pathSegments;
        // The same page for the other profile.
        final page = segments.length >= 3 && segments[0] == 'profiles' ? segments[2] : 'channels';
        session.select(id);
        context.go('/profiles/$id/$page');
      },
    );
  }
}

/// The avatar colours, as on the TV.
const avatarColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];

class ProfileDot extends StatelessWidget {
  const ProfileDot({super.key, required this.profile, this.size = 24});

  final ProfileInfo profile;
  final double size;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: size / 2,
        backgroundColor: avatarColors[profile.color % avatarColors.length],
        child: Text(profile.name.isEmpty ? '?' : profile.name.characters.first.toUpperCase(),
            style: TextStyle(fontSize: size * 0.5, color: Colors.white, fontWeight: FontWeight.w600)),
      );
}

/// A profile's pages: behind its PIN for a user who hasn't given it, and
/// with a note on a kid profile whose settings need a grown-up's PIN.
class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key, required this.profileId, required this.child});

  final String profileId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = context.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final p = session.profileById(profileId);
        if (p == null) return const NotFound(text: "That profile isn't yours, or it's gone.");
        if (p.locked) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text('${p.name} has a PIN.', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => unlock(context, profileId), child: const Text('Enter PIN')),
              ]),
            ),
          );
        }
        if (!p.needsGrownUp) return child;
        return Column(children: [
          MaterialBanner(
            content: const Text("This is a kid profile. Changing its settings needs a grown-up's PIN."),
            actions: [TextButton(onPressed: () => unlock(context, profileId, grownUp: true), child: const Text('Enter PIN'))],
          ),
          Expanded(child: child),
        ]);
      },
    );
  }
}

class NotFound extends StatelessWidget {
  const NotFound({super.key, this.text = 'There is no page here.'});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go('/'), child: const Text('Home')),
          ]),
        ),
      );
}

/// A URL shown as selectable text with a Copy button that also works on a
/// plain `http://` address ([copyText]).
class CopyField extends StatelessWidget {
  const CopyField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              SelectableText(value),
            ]),
          ),
          IconButton(
            tooltip: 'Copy $label',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final copied = await copyText(value);
              if (context.mounted) showMessage(context, copied ? 'Copied.' : "Couldn't copy. Select the text and copy it.");
            },
          ),
        ]),
      );
}

/// A small running note for a long action, beside what started it.
class Busy extends StatelessWidget {
  const Busy({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ]);
}

/// An error message under what caused it.
class ErrorText extends StatelessWidget {
  const ErrorText(this.text, {super.key});
  final String? text;

  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(text!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        );
}

/// "Mon", "Tue"… for [DateTime.weekday] 1–7.
const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Day chips for [DateTime.weekday] values.
class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.days, required this.onChanged});

  final Set<int> days;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (var d = 1; d <= 7; d++)
          FilterChip(
            label: Text(weekdayNames[d - 1]),
            selected: days.contains(d),
            onSelected: (on) => onChanged(on ? {...days, d} : ({...days}..remove(d))),
          ),
      ]);
}

/// A time of day in minutes after midnight, picked with the time picker.
class MinuteField extends StatelessWidget {
  const MinuteField({super.key, required this.label, required this.minute, required this.onChanged});

  final String label;
  final int minute;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
    return OutlinedButton.icon(
      icon: const Icon(Icons.schedule),
      label: Text('$label: ${t.format(context)}'),
      onPressed: () async {
        final picked = await showTimePicker(context: context, initialTime: t);
        if (picked != null) onChanged(picked.hour * 60 + picked.minute);
      },
    );
  }
}
