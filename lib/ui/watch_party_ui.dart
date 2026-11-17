part of 'sharing_screen.dart';

/// The profile in front's watch parties, when this build has sharing.
WatchParty? partyOf(BuildContext context) =>
    context.getInheritedWidgetOfExactType<HouseholdScope>()?.notifier?.sharing?.party;

ShareService? _sharingOf(BuildContext context) => context.getInheritedWidgetOfExactType<HouseholdScope>()?.notifier?.sharing;

/// One of the six reactions, drawn from its image (the TV's fonts have no
/// emoji, and a desktop may have no emoji font at all).
class ReactionImage extends StatelessWidget {
  const ReactionImage(this.emoji, {super.key, this.size = 40});

  final String emoji;
  final double size;

  static const _files = {'😂': 'joy', '😮': 'wow', '❤️': 'heart', '👏': 'clap', '😱': 'scream', '🍿': 'popcorn'};

  @override
  Widget build(BuildContext context) => Semantics(
        label: emoji,
        excludeSemantics: true,
        child: Image.asset('assets/reactions/${_files[emoji] ?? 'joy'}.png',
            width: size, height: size, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => SizedBox(width: size, height: size)),
      );
}

/// The party's members (the host badged) and how this picture stands:
/// "In sync", "Catching up" or "Not on your servers" (D8). Never focused.
class PartyMembersChip extends StatelessWidget {
  const PartyMembersChip({super.key, required this.party, this.size = 44, this.compact = false});

  final WatchParty party;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final members = party.members;
    final sync = switch (party.sync) {
      PartySync.inSync => tr.partyInSync,
      PartySync.catchingUp => tr.partyCatchingUp,
      PartySync.missing => tr.partyNotOnServers,
    };
    final color = switch (party.sync) {
      PartySync.inSync => const Color(0xFF7BE07B),
      PartySync.catchingUp => g.accent,
      PartySync.missing => g.textDim,
    };
    return ExcludeFocus(
      child: Semantics(
        label: '${joinNames([for (final m in members) m.host ? '${m.profile.name} (${tr.partyHost})' : m.profile.name])}. $sync',
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 6 : 8),
          decoration: BoxDecoration(
            color: g.panel.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: g.cellBorder, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (i, m) in members.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Stack(clipBehavior: Clip.none, children: [
                ShareAvatar(avatar: m.profile.avatar, color: m.profile.avatarColor, size: size),
                if (m.host)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: g.accent, shape: BoxShape.circle, border: Border.all(color: g.panel, width: 2)),
                      child: Icon(Icons.star, size: size * 0.32, color: g.panel),
                    ),
                  ),
              ]),
            ],
            const SizedBox(width: 14),
            Icon(party.sync == PartySync.missing ? Icons.cloud_off : Icons.sync, size: compact ? 24 : 28, color: color),
            const SizedBox(width: 6),
            Text(sync, style: g.display(compact ? 22 : 26, weight: FontWeight.w700, color: color)),
          ]),
        ),
      ),
    );
  }
}

/// Reactions floating up the right side of the picture, each with its
/// sender's avatar, for 3 seconds (D8). Never focused, never in the way of
/// a tap.
class FloatingReactions extends StatefulWidget {
  const FloatingReactions({super.key, required this.party});

  final WatchParty party;

  @override
  State<FloatingReactions> createState() => _FloatingReactionsState();
}

class _FloatingReactionsState extends State<FloatingReactions> {
  final _shown = <FloatingReaction>[];
  StreamSubscription<FloatingReaction>? _sub;

  @override
  void initState() {
    super.initState();
    PlaybackDiagnostics.note('PARTY', 'reactions layer up');
    _sub = widget.party.reactions.listen((r) {
      if (!mounted) return;
      final size = context.size;
      PlaybackDiagnostics.note('PARTY', 'reaction ${r.emoji} drawn'
          '${size == null ? '' : ' in ${size.width.round()}x${size.height.round()}'}');
      setState(() {
        _shown.add(r);
        // Plenty on screen at once; the oldest go first.
        if (_shown.length > 16) _shown.removeAt(0);
      });
      Timer(FloatingReaction.shownFor, () {
        if (mounted) setState(() => _shown.remove(r));
      });
    });
  }

  @override
  void dispose() {
    PlaybackDiagnostics.note('PARTY', 'reactions layer down');
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeFocus(
        child: Stack(children: [
          for (final r in _shown)
            _Rising(key: ValueKey(r.id), reaction: r, lane: r.id % 3),
        ]),
      ),
    );
  }
}

class _Rising extends StatelessWidget {
  const _Rising({super.key, required this.reaction, required this.lane});

  final FloatingReaction reaction;
  final int lane;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: FloatingReaction.shownFor,
      builder: (context, t, child) => Positioned(
        right: 70.0 + lane * 70,
        bottom: 140 + t * 620,
        child: Opacity(opacity: t < 0.75 ? 1 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0), child: child),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ReactionImage(reaction.emoji, size: 84),
        if (reaction.from case final f?) ShareAvatar(avatar: f.avatar, color: f.avatarColor, size: 40),
      ]),
    );
  }
}

/// "Tyler invited you to watch The Office together", Join and Not now (D8):
/// a banner at the top that never takes focus by itself. The TV screen
/// gives it [focusNode] on the first Up; Left and Right move, Select
/// presses, Down gives the focus back ([onDone]), Back dismisses. Pointer
/// and touch tap its buttons.
class PartyInviteBanner extends StatefulWidget {
  const PartyInviteBanner({
    super.key,
    required this.invite,
    required this.focusNode,
    required this.onJoin,
    required this.onNotNow,
    required this.onDone,
  });

  final PartyInvite invite;
  final FocusNode focusNode;
  final VoidCallback onJoin;
  final VoidCallback onNotNow;

  /// The focus goes back where it was.
  final VoidCallback onDone;

  @override
  State<PartyInviteBanner> createState() => _PartyInviteBannerState();
}

class _PartyInviteBannerState extends State<PartyInviteBanner> {
  int _at = 0;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() => _at = 0);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      setState(() => _at = key == LogicalKeyboardKey.arrowRight ? 1 : 0);
    } else if (isSelectKey(key)) {
      if (event is KeyDownEvent) (_at == 0 ? widget.onJoin : widget.onNotNow)();
    } else if (isBackKey(key)) {
      if (event is KeyDownEvent) widget.onNotNow();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      widget.onDone();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      // The top of the screen.
    } else {
      // Channel keys and the rest act as usual.
      widget.onDone();
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final i = widget.invite;
    final focused = widget.focusNode.hasFocus;
    final text = i.title.isEmpty ? tr.partyInviteBannerNoTitle(i.host.name) : tr.partyInviteBanner(i.host.name, i.title);
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _key,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1400),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
        decoration: BoxDecoration(
          color: g.panel.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: focused ? Colors.white : g.cellBorder, width: focused ? 3 : 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ShareAvatar(avatar: i.host.avatar, color: i.host.avatarColor, size: 72),
          const SizedBox(width: 20),
          Flexible(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, style: g.display(30, weight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (i.channelName.isNotEmpty) Text(i.channelName, style: g.body(24, color: g.textDim), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 24),
          TvPointerButton(
            label: tr.partyJoin,
            icon: Icons.celebration,
            highlighted: focused && _at == 0,
            onHover: () => setState(() => _at = 0),
            onPressed: widget.onJoin,
          ),
          const SizedBox(width: 12),
          TvPointerButton(
            label: tr.partyNotNow,
            icon: Icons.close,
            highlighted: focused && _at == 1,
            onHover: () => setState(() => _at = 1),
            onPressed: widget.onNotNow,
          ),
        ]),
      ),
    );
  }
}

/// "Leave the watch party?" (D8): Stay first and focused, Leave second, so
/// an accidental Back then Select doesn't leave.
Future<bool> confirmLeaveParty(BuildContext context, {required bool host}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final g = context.guide;
      return _dialog(
          context,
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr.partyLeaveQuestion, style: g.display(48, weight: FontWeight.w800)),
            const SizedBox(height: 16),
            Text(host ? tr.partyLeaveHostDetail : tr.partyLeaveGuestDetail, style: g.body(28, color: g.textDim)),
            const SizedBox(height: 40),
            ButtonRow(children: [
              TvButton(label: tr.partyStay, autofocus: true, onPressed: () => Navigator.pop(context, false)),
              TvButton(label: tr.partyLeave, icon: Icons.logout, danger: true, onPressed: () => Navigator.pop(context, true)),
            ]),
          ]));
    },
  );
  return result ?? false;
}

/// Joins [partyId], saying why when it can't; true once in it.
Future<bool> joinWatchParty(BuildContext context, WatchParty party, String partyId) async {
  PartyJoinStatus status;
  try {
    status = await party.join(partyId);
  } on Object catch (e) {
    debugPrint('Join watch party: $e');
    status = PartyJoinStatus.unavailable;
  }
  if (status == PartyJoinStatus.ok || !context.mounted) return status == PartyJoinStatus.ok;
  await showMessage(context,
      title: tr.watchTogether,
      message: switch (status) {
        PartyJoinStatus.full => tr.partyFull,
        PartyJoinStatus.ended || PartyJoinStatus.notAllowed => tr.partyOver,
        _ => tr.sharingUnavailable,
      });
  return false;
}

/// Watch together (D8): pick up to 7 friends, or Get a link, then Start. In
/// a party the host invites more the same way. Returns once the dialog is
/// closed.
Future<void> showWatchTogether(BuildContext context, {required String title}) async {
  final service = _sharingOf(context);
  final party = service?.party;
  final client = service?.active;
  if (service == null || party == null || client == null) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _WatchTogetherDialog(service: service, party: party, client: client, title: title),
  );
}

class _WatchTogetherDialog extends StatefulWidget {
  const _WatchTogetherDialog({required this.service, required this.party, required this.client, required this.title});

  final ShareService service;
  final WatchParty party;
  final ShareClient client;
  final String title;

  @override
  State<_WatchTogetherDialog> createState() => _WatchTogetherDialogState();
}

class _WatchTogetherDialogState extends State<_WatchTogetherDialog> {
  List<ShareProfile>? _friends;
  final _picked = <String>{};
  bool _busy = false;
  FriendInvite? _link;
  String? _error;

  bool get _more => widget.party.active;

  /// Friends already in the party can't be picked again.
  Set<String> get _inParty => {for (final m in widget.party.members) m.profile.userId};

  int get _room => _more ? WatchParty.maxMembers - widget.party.members.length : WatchParty.maxInvited;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final list = await widget.client.friends();
      if (mounted) setState(() => _friends = [for (final f in list.friends) if (!_inParty.contains(f.userId)) f]);
    } on Object catch (e) {
      debugPrint('Watch together friends: $e');
      if (mounted) setState(() => _friends = const []);
    }
  }

  void _toggle(ShareProfile f) {
    setState(() {
      if (!_picked.remove(f.userId) && _picked.length < _room) _picked.add(f.userId);
    });
  }

  Future<void> _go({required bool link}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = _more
          ? await widget.party.inviteMore(friends: _picked.toList(), link: link)
          : await widget.party.start(friends: _picked.toList(), link: link);
      if (!mounted) return;
      if (link && invite != null) {
        setState(() => _link = invite);
      } else {
        Navigator.pop(context);
      }
    } on Object catch (e) {
      debugPrint('Watch together: $e');
      if (mounted) setState(() => _error = tr.sharingUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final link = _link;
    final canSend = PlatformInfo.isAndroid && !PlatformInfo.isTelevision;
    if (link != null) {
      return _dialog(
          context,
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr.partyStartTitle(widget.title), style: g.display(44, weight: FontWeight.w800)),
            const SizedBox(height: 24),
            _InviteCard(invite: link, host: widget.service.host, help: tr.partyLinkHelp),
            const SizedBox(height: 32),
            ButtonRow(children: [
              TvButton(label: tr.done, icon: Icons.check, autofocus: true, onPressed: () => Navigator.pop(context)),
              if (canSend)
                TvButton(
                  label: tr.sharingSendInvite,
                  icon: Icons.share,
                  onPressed: () => PlatformInfo.shareText(tr.sharingInviteText(InviteCode.link(link.code, host: widget.service.host)),
                      title: tr.sharingSendInvite),
                ),
            ]),
          ]));
    }
    final friends = _friends;
    return _dialog(
        context,
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_more ? tr.partyInvite : tr.partyStartTitle(widget.title), style: g.display(44, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(tr.partyStartHelp, style: g.body(26, color: g.textDim)),
          const SizedBox(height: 24),
          if (friends == null)
            const _Loading()
          else if (friends.isEmpty)
            _Note(tr.partyNoFriends)
          else
            for (final f in friends)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TvFocusable(
                  autofocus: f == friends.first,
                  onPressed: _busy ? null : () => _toggle(f),
                  builder: (context, focused) {
                    final on = _picked.contains(f.userId);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: focused ? g.focus : g.cell,
                        borderRadius: BorderRadius.circular(g.radius * 2),
                        border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
                      ),
                      child: Row(children: [
                        Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 40, color: focused ? g.onFocus : (on ? g.accent : g.textDim)),
                        const SizedBox(width: 16),
                        ShareAvatar(avatar: f.avatar, color: f.avatarColor, size: 52),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: g.display(30, weight: FontWeight.w700, color: focused ? g.onFocus : g.text)),
                        ),
                      ]),
                    );
                  },
                ),
              ),
          if (_error case final e?) ...[const SizedBox(height: 12), Text(e, style: g.body(26, color: g.accent))],
          const SizedBox(height: 28),
          // Three buttons wrap rather than run off a narrow dialog.
          Wrap(alignment: WrapAlignment.end, spacing: 20, runSpacing: 16, children: [
            TvButton(label: tr.cancel, onPressed: () => Navigator.pop(context)),
            TvButton(label: tr.partyGetLink, icon: Icons.link, onPressed: _busy ? null : () => _go(link: true)),
            TvButton(
              label: _more ? tr.partyInvite : tr.partyStart,
              icon: _more ? Icons.person_add : Icons.celebration,
              autofocus: friends != null && friends.isEmpty,
              onPressed: _busy || (_more && _picked.isEmpty) ? null : () => _go(link: false),
            ),
          ]),
        ]),
        // Cancel, Get a link and Start side by side.
        width: 1200);
  }
}

/// Sharing → Watch parties: the open invites, each with Join, until their
/// parties end.
class _WatchPartiesSection extends StatelessWidget {
  const _WatchPartiesSection({required this.party, required this.onJoin});

  final WatchParty party;
  final void Function(PartyInvite invite) onJoin;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return ListenableBuilder(
      listenable: party,
      builder: (context, _) {
        final invites = party.invites;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Heading(tr.partyWatchParties),
          if (invites.isEmpty) _Note(tr.partyNoInvites),
          for (final i in invites)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                ShareAvatar(avatar: i.host.avatar, color: i.host.avatarColor, size: 64),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.host.name, style: g.display(30, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(i.title.isEmpty ? i.channelName : tr.partyOn(i.title, i.channelName),
                        style: g.body(24, color: g.textDim), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(width: 16),
                TvButton(label: tr.partyJoin, icon: Icons.celebration, onPressed: () => onJoin(i)),
              ]),
            ),
          const SizedBox(height: 48),
        ]);
      },
    );
  }
}
