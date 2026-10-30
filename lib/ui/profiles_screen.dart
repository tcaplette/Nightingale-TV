import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../backup/backup_archive.dart';
import '../profiles/household.dart';
import '../profiles/profile.dart';
import '../theme/tv_theme.dart';
import 'menu_screen.dart';
import 'pin_dialog.dart';
import 'widgets/nightingale_mark.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

const avatarColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];

/// A profile's round initial, with a kid badge or lock where relevant.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.size = 160, this.showLock = true});

  final Profile profile;
  final double size;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final name = profile.name.trim();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: avatarColors[profile.color % avatarColors.length],
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                style: g.display(size * 0.5, weight: FontWeight.w800, color: Colors.white)),
          ),
          if (profile.isKid)
            Positioned(
              left: 0,
              bottom: 0,
              child: _Badge(icon: Icons.child_care, size: size * 0.3),
            ),
          if (showLock && profile.hasPin)
            Positioned(
              right: 0,
              bottom: 0,
              child: _Badge(icon: Icons.lock, size: size * 0.3),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: g.accent, shape: BoxShape.circle, border: Border.all(color: g.panel, width: 3)),
      child: Icon(icon, size: size * 0.6, color: g.onFocus),
    );
  }
}

/// Opens [p], asking for its PIN first if it has one.
Future<void> openProfile(BuildContext context, Profile p) async {
  final household = HouseholdScope.read(context);
  if (p.hasPin &&
      !await askPin(context, title: 'Enter ${p.name}\'s PIN', check: p.checkPin)) {
    return;
  }
  await household.select(p);
}

/// Grown-ups only, once there are kid profiles: asks for any grown-up's PIN.
Future<bool> grownUpCheck(BuildContext context, {String title = 'Grown-ups only'}) async {
  final household = HouseholdScope.read(context);
  if (!household.hasKids) return true;
  return askPin(context,
      title: title,
      message: 'Enter a grown-up\'s PIN.',
      check: (pin) => household.grownUpWithPin(pin) != null);
}

/// "Who's watching?" — shown at launch when there's more than one profile.
class ProfilePickerScreen extends StatelessWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final household = HouseholdScope.of(context);
    final g = context.guide;
    final layout = ScreenLayout.of(context);
    return TvPage(
      title: 'Nightingale TV',
      leading: NightingaleMark(height: layout.isPortrait ? 36 : 48, color: g.accent),
      hints: '◀▶ Move    OK Choose',
      child: Center(
        child: SingleChildScrollView(
          // Upright, the profiles wrap at the screen's width and scroll.
          padding: layout.isPortrait ? EdgeInsets.symmetric(horizontal: layout.gutter, vertical: 32) : null,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Who\'s watching?',
                textAlign: TextAlign.center, style: g.display(layout.isPortrait ? 56 : 80, weight: FontWeight.w800)),
            SizedBox(height: layout.isPortrait ? 40 : 64),
            FocusTraversalGroup(
              child: Wrap(
                spacing: 40,
                runSpacing: 40,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, p) in household.profiles.indexed)
                    _ProfileTile(
                      autofocus: i == 0,
                      label: p.name,
                      detail: p.isKid ? p.rating.label : null,
                      avatar: ProfileAvatar(profile: p),
                      onPressed: () => openProfile(context, p),
                    ),
                  _ProfileTile(
                    label: 'Add profile',
                    avatar: _AddAvatar(size: 160),
                    onPressed: () async {
                      if (!await grownUpCheck(context) || !context.mounted) return;
                      await Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const ProfileEditorScreen()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AddAvatar extends StatelessWidget {
  const _AddAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: g.cell,
        shape: BoxShape.circle,
        border: Border.all(color: g.cellBorder, width: 3),
      ),
      child: Icon(Icons.add, size: size * 0.5, color: g.textDim),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.avatar,
    required this.onPressed,
    this.detail,
    this.autofocus = false,
  });

  final String label;
  final String? detail;
  final Widget avatar;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: focused ? g.cellBorder : Colors.transparent,
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: focused ? g.focus : Colors.transparent, width: 4),
        ),
        child: Column(
          children: [
            avatar,
            const SizedBox(height: 20),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: g.display(36, weight: FontWeight.w700, color: focused ? g.text : g.textDim)),
            Text(detail ?? '', style: g.body(22, color: g.accent)),
          ],
        ),
      ),
    );
  }
}

/// Menu → Profiles: add, edit or delete profiles.
class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final household = HouseholdScope.of(context);
    final g = context.guide;
    final current = household.current;
    final portrait = ScreenLayout.of(context).isPortrait;

    Future<void> edit(Profile? p) async {
      // Someone else's locked profile: prove you're them first.
      if (p != null &&
          p.id != current?.id &&
          p.hasPin &&
          !await askPin(context, title: 'Enter ${p.name}\'s PIN', check: p.checkPin)) {
        return;
      }
      if (!context.mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => ProfileEditorScreen(profile: p)));
    }

    return TvPage(
      title: 'Profiles',
      hints: '▲▼ Move    OK Edit    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(120, 40, 120, 40)),
          children: [
            Text(
              'Everyone gets their own server sign-in, channels and programming blocks. '
              'Kid profiles only see shows and movies rated for their age.',
              style: g.body(28, color: g.textDim),
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: TvButton(label: 'Add profile', icon: Icons.person_add, onPressed: () => edit(null)),
            ),
            const SizedBox(height: 28),
            for (final (i, p) in household.profiles.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TvFocusable(
                  autofocus: i == 0,
                  onPressed: () => edit(p),
                  builder: (context, focused) => AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      color: focused ? g.cellBorder : g.cell,
                      borderRadius: BorderRadius.circular(g.radius),
                      border: Border.all(color: focused ? g.focus : Colors.transparent, width: 4),
                    ),
                    child: Row(
                      children: [
                        ProfileAvatar(profile: p, size: 80),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(38, weight: FontWeight.w800)),
                              Text(
                                [
                                  if (p.isKid) 'Kid · ${p.rating.label} (${p.rating.description})' else 'Grown-up',
                                  p.hasPin ? 'PIN locked' : 'No PIN',
                                ].join('  ·  '),
                                style: g.body(24, color: g.textDim),
                              ),
                              // Upright, under the name: there's no room beside it.
                              if (p.id == current?.id && portrait)
                                Text('Watching now', style: g.body(24, weight: FontWeight.w600, color: g.accent)),
                            ],
                          ),
                        ),
                        if (p.id == current?.id && !portrait)
                          Text('Watching now', style: g.body(24, weight: FontWeight.w600, color: g.accent)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Create or edit a profile.
class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key, this.profile});

  /// The profile to edit; null to create one.
  final Profile? profile;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final Household _household = HouseholdScope.read(context);
  late final Profile _draft = widget.profile?.copy() ?? _household.newProfile();
  late final _name = TextEditingController(text: _draft.name);
  String? _error;

  bool get _isNew => widget.profile == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _update(void Function() change) => setState(() {
        change();
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final household = HouseholdScope.of(context);
    final g = context.guide;
    final isCurrent = _draft.id == household.current?.id;

    return TvPage(
      title: _isNew ? 'New profile' : 'Edit profile',
      hints: '▲▼◀▶ Move    OK Select    ESC Cancel',
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(120, 36, 120, 40)),
          children: [
            Row(
              children: [
                ProfileAvatar(profile: _draft, size: 120),
                const SizedBox(width: 36),
                Expanded(
                  child: TvTextField(
                    controller: _name,
                    label: 'Name',
                    autofocus: _isNew,
                    onSubmitted: (v) => _update(() => _draft.name = v),
                  ),
                ),
              ],
            ),
            _section(g, 'COLOR'),
            Wrap(
              spacing: 16,
              children: [
                for (var i = 0; i < avatarColors.length; i++)
                  TvFocusable(
                    onPressed: () => _update(() => _draft.color = i),
                    builder: (context, focused) => Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: avatarColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: focused ? g.focus : (_draft.color == i ? Colors.white : Colors.transparent),
                          width: 5,
                        ),
                      ),
                      child: _draft.color == i ? const Icon(Icons.check, color: Colors.white, size: 36) : null,
                    ),
                  ),
              ],
            ),
            _section(g, 'WHO IT\'S FOR'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TvToggle(
                  label: 'Grown-up',
                  radio: true,
                  autofocus: !_isNew,
                  on: !_draft.isKid,
                  onPressed: () => _update(() => _draft.kind = ProfileKind.adult),
                ),
                TvToggle(
                  label: 'Kid',
                  radio: true,
                  on: _draft.isKid,
                  onPressed: () => _update(() => _draft.kind = ProfileKind.kid),
                ),
              ],
            ),
            if (_draft.isKid) ...[
              _section(g, 'ALLOWED TO WATCH'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final r in KidRating.values)
                    TvToggle(
                      label: '${r.label}: ${r.description}',
                      radio: true,
                      on: _draft.rating == r,
                      onPressed: () => _update(() => _draft.rating = r),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Shows and movies with no rating are left out.', style: g.body(22, color: g.textDim)),
            ],
            _section(g, 'PIN'),
            Text(
              _draft.hasPin
                  ? 'Locked. The PIN is needed to open this profile.'
                  : 'No PIN. Anyone can open this profile.',
              style: g.body(26, color: g.textDim),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TvButton(
                  label: _draft.hasPin ? 'Change PIN' : 'Set a PIN',
                  icon: Icons.pin,
                  onPressed: () async {
                    final pin = await chooseNewPin(context, title: '${_name.text.trim().isEmpty ? 'New' : _name.text.trim()} PIN');
                    if (pin != null) _update(() => _draft.setPin(pin));
                  },
                ),
                if (_draft.hasPin)
                  TvButton(label: 'Remove PIN', icon: Icons.lock_open, onPressed: () => _update(() => _draft.setPin(null))),
              ],
            ),
            const SizedBox(height: 40),
            if (_error != null) ...[
              Text(_error!, style: g.body(28, weight: FontWeight.w600, color: g.nowLine)),
              const SizedBox(height: 20),
            ],
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TvButton(label: 'Save', icon: Icons.check, onPressed: _save),
                TvButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                if (!_isNew && !isCurrent)
                  TvButton(label: 'Delete profile', icon: Icons.delete, danger: true, onPressed: _delete),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _section(GuideTheme g, String title) => Padding(
        padding: const EdgeInsets.only(top: 36, bottom: 14),
        child: Text(title, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      );

  Future<void> _save() async {
    _draft.name = _name.text.trim();
    if (_draft.name.isEmpty) {
      setState(() => _error = 'Give the profile a name.');
      return;
    }
    final problem = _household.problemWith(_draft);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await _household.saveProfile(_draft);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final problem = _household.problemDeleting(_draft);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final ok = await confirm(context,
        title: 'Delete ${widget.profile!.name}?',
        message: 'Their channels, programming blocks and settings are deleted, and this TV is '
            'signed out of their server.',
        action: 'Delete');
    if (!ok || !mounted) return;
    try {
      await _household.deleteProfile(widget.profile!);
    } on BackupException catch (e) {
      // No backup could be saved first: nothing was deleted.
      if (mounted) setState(() => _error = e.message);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }
}
