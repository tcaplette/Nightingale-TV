part of 'sharing_screen.dart';

enum _ShareStep { channels, recipients, link }

/// Sharing → Share channels (channel-sharing D8): check channels (live and
/// music ones listed with the reason they can't be), then friends or Get a
/// link. A channel's Share… opens it with that channel checked. D-pad, air
/// mouse and touch, upright too.
class ShareChannelsScreen extends StatefulWidget {
  const ShareChannelsScreen({super.key, this.initial = const {}});

  /// Channel ids checked to start with.
  final Set<String> initial;

  @override
  State<ShareChannelsScreen> createState() => _ShareChannelsScreenState();
}

class _ShareChannelsScreenState extends State<ShareChannelsScreen> {
  late final Household _household = HouseholdScope.read(context);
  late final ShareService _service = _household.sharing!;
  late final AppState _app = AppScope.read(context);
  late final Set<String> _checked = {...widget.initial};
  final _picked = <String>{};

  _ShareStep _step = _ShareStep.channels;
  List<ShareProfile>? _friends;
  FriendInvite? _invite;
  bool _busy = false;
  bool _unavailable = false;
  String? _error;

  /// The step's first control, focused as each step opens.
  final _first = FocusNode(debugLabel: 'share step');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _first.requestFocus());
  }

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  /// Why [ch] can't be shared, or null.
  String? _problem(Channel ch) {
    if (ch.isSharedCopy) return tr.sharingCopyCantShare;
    final p = _app.shareProblem(ch);
    if (p != null) return p;
    try {
      _app.recipeOf(ch);
    } on RecipeTooBig {
      return tr.sharingTooBig;
    }
    return null;
  }

  void _goTo(_ShareStep step) {
    setState(() {
      _step = step;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _first.requestFocus();
    });
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
      if (mounted) setState(() => _unavailable = false);
    } on ShareUnavailable {
      if (mounted) setState(() => _unavailable = true);
    } on ShareSignedOut {
      if (mounted) Navigator.of(context).pop();
    } on StateError {
      if (mounted) setState(() => _unavailable = true);
    } on ShareRefused catch (e) {
      if (mounted) setState(() => _error = e.status == 'too_big' ? tr.sharingTooBig : tr.sharingUnavailable);
    } on RecipeTooBig {
      if (mounted) setState(() => _error = tr.sharingTooBig);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_checked.isEmpty) {
      setState(() => _error = tr.sharingPickChannel);
      return;
    }
    await _run(() async {
      final client = _service.channels.client ?? _service.active;
      final friends = await client!.friends();
      if (!mounted) return;
      _friends = friends.friends;
      _goTo(_ShareStep.recipients);
    });
  }

  List<Channel> get _channels => [for (final c in _app.allChannels) if (_checked.contains(c.id)) c];

  Future<void> _share() async {
    final to = [for (final f in _friends ?? const <ShareProfile>[]) if (_picked.contains(f.userId)) f];
    if (to.isEmpty) {
      setState(() => _error = tr.sharingPickFriend);
      return;
    }
    var sent = false;
    await _run(() async {
      await _service.channels.send(_channels, to: to);
      sent = true;
    });
    if (!sent || !mounted) return;
    final names = joinNames([for (final f in to) f.name]);
    await showMessage(context, title: tr.sharingShareChannels, message: tr.sharingSharedWith(names));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _getLink() => _run(() async {
        final r = await _service.channels.send(_channels, link: true);
        if (!mounted) return;
        _invite = r.invite;
        _goTo(_ShareStep.link);
      });

  void _back() {
    switch (_step) {
      case _ShareStep.channels || _ShareStep.link:
        Navigator.of(context).pop();
      case _ShareStep.recipients:
        _goTo(_ShareStep.channels);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = ScreenLayout.of(context);
    return TvPage(
      title: tr.sharingShareChannels,
      hints: tr.moveOkSelectEsc,
      onBack: _back,
      child: FocusTraversalGroup(
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: switch (_step) {
            _ShareStep.channels => _channelList(layout),
            _ShareStep.recipients => _recipients(layout),
            _ShareStep.link => _linkView(layout),
          },
        ),
      ),
    );
  }

  List<Widget> _status() => [
        if (_unavailable) ...[_Note(tr.sharingUnavailable, error: true), const SizedBox(height: 20)],
        if (_error != null) ...[_Note(_error!, error: true), const SizedBox(height: 20)],
        if (_busy) const LinearProgressIndicator(),
      ];

  Widget _channelList(ScreenLayout layout) {
    final g = context.guide;
    final channels = _app.allChannels;
    final problems = {for (final c in channels) c.id: _problem(c)};
    return ListView.builder(
      padding: layout.pagePadding(const EdgeInsets.fromLTRB(120, 40, 120, 48)),
      itemCount: channels.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr.sharingShareChannelsHelp, style: g.body(28, color: g.textDim)),
            const SizedBox(height: 24),
            ..._status(),
            ButtonRow(children: [
              TvButton(
                  label: tr.sharingShareWith,
                  icon: Icons.arrow_forward,
                  focusNode: _first,
                  onPressed: _busy ? null : _next),
              TvButton(label: tr.cancel, onPressed: () => Navigator.of(context).pop()),
            ]),
            const SizedBox(height: 32),
          ]);
        }
        final ch = channels[i - 1];
        final problem = problems[ch.id];
        return _CheckRow(
          leading: (focused) => SizedBox(
            width: 120,
            child: Text('${ch.number}',
                style: g.display(30, weight: FontWeight.w800, color: focused ? g.onFocus : g.accent)),
          ),
          title: ch.displayName,
          subtitle: problem,
          checked: problem == null && _checked.contains(ch.id),
          onPressed: problem == null
              ? () => setState(() => _checked.contains(ch.id) ? _checked.remove(ch.id) : _checked.add(ch.id))
              : null,
        );
      },
    );
  }

  Widget _recipients(ScreenLayout layout) {
    final friends = _friends ?? const <ShareProfile>[];
    return ListView(
      padding: layout.pagePadding(const EdgeInsets.fromLTRB(120, 40, 120, 48)),
      children: [
        _Heading(tr.sharingShareWith),
        ..._status(),
        if (friends.isEmpty) ...[_Note(tr.sharingNoFriendsToShare), const SizedBox(height: 24)],
        ButtonRow(children: [
          if (friends.isNotEmpty)
            TvButton(label: tr.sharingShare, icon: Icons.send, focusNode: _first, onPressed: _busy ? null : _share),
          TvButton(
              label: tr.sharingGetLink,
              icon: Icons.link,
              focusNode: friends.isEmpty ? _first : null,
              onPressed: _busy ? null : _getLink),
        ]),
        const SizedBox(height: 32),
        for (final f in friends)
          _CheckRow(
            leading: (_) => ShareAvatar(avatar: f.avatar, color: f.avatarColor, size: 64),
            title: f.name,
            subtitle: '@${f.handle}',
            checked: _picked.contains(f.userId),
            onPressed: () => setState(() => _picked.contains(f.userId) ? _picked.remove(f.userId) : _picked.add(f.userId)),
          ),
      ],
    );
  }

  Widget _linkView(ScreenLayout layout) {
    final g = context.guide;
    final invite = _invite;
    final canSend = PlatformInfo.isAndroid && !PlatformInfo.isTelevision;
    return ListView(
      padding: layout.pagePadding(const EdgeInsets.fromLTRB(120, 40, 120, 48)),
      children: [
        _Heading(tr.sharingGetLink),
        if (invite != null) _InviteCard(invite: invite, host: _service.host, help: tr.sharingLinkHelp),
        const SizedBox(height: 24),
        Text(joinNames([for (final c in _channels) c.displayName]), style: g.body(26, color: g.textDim)),
        const SizedBox(height: 24),
        ButtonRow(children: [
          TvButton(label: tr.done, icon: Icons.check, focusNode: _first, onPressed: () => Navigator.of(context).pop()),
          if (canSend && invite != null)
            TvButton(
              label: tr.sharingSendInvite,
              icon: Icons.share,
              onPressed: () => PlatformInfo.shareText(
                  tr.sharingChannelsInviteText(InviteCode.link(invite.code, host: _service.host)),
                  title: tr.sharingSendInvite),
            ),
        ]),
      ],
    );
  }
}

/// A row with a check box; without [onPressed] it has none and can't take
/// focus (a channel that can't be shared, with [subtitle] saying why).
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.leading, required this.title, this.subtitle, required this.checked, this.onPressed});

  /// What comes before the title, drawn for the row's focus.
  final Widget Function(bool focused) leading;
  final String title;
  final String? subtitle;
  final bool checked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final enabled = onPressed != null;
    Widget body(bool focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: focused ? g.focus : g.cell,
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
          ),
          child: Row(children: [
            if (enabled)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 20),
                child: Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 40, color: focused ? g.onFocus : g.accent),
              )
            else
              const SizedBox(width: 60),
            leading(focused),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.display(30, weight: FontWeight.w700, color: focused ? g.onFocus : (enabled ? g.text : g.textDim))),
                if (subtitle != null)
                  Text(subtitle!, style: g.body(24, color: focused ? g.onFocus : g.textDim)),
              ]),
            ),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: enabled ? TvFocusable(onPressed: onPressed, builder: (context, focused) => body(focused)) : body(false),
    );
  }
}
