import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase/supabase.dart' show AuthApiException;

import '../app_scope.dart';
import '../app_state.dart';
import '../channels/channel.dart';
import '../l10n/tr.dart';
import '../platform/platform_info.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/household.dart';
import '../profiles/profile.dart';
import '../sharing/channel_recipe.dart';
import '../sharing/channel_shares.dart';
import '../sharing/invite_code.dart';
import '../sharing/party_reactions.dart';
import '../sharing/presence.dart';
import '../sharing/share_client.dart';
import '../sharing/share_service.dart';
import '../sharing/watch_party.dart';
import '../theme/tv_theme.dart';
import 'menu_screen.dart' show confirm, showMessage;
import 'profiles_screen.dart' show avatarColors;
import 'widgets/adaptive.dart';
import 'widgets/channel_logo.dart';
import 'widgets/keep_focus_on_top.dart';
import 'widgets/screen_layout.dart';
import 'widgets/share_avatar.dart';
import 'widgets/tv_focus.dart';

part 'share_channels_screen.dart';
part 'watch_party_ui.dart';

enum _Step { intro, email, code, profile, presence, linked }

/// Menu → Sharing (share-accounts D12): set up, the share profile, Add
/// friend, friends and blocked accounts. Adult profiles only, in builds
/// with sharing. Works with the D-pad, an air mouse and touch, upright too.
class SharingScreen extends StatefulWidget {
  const SharingScreen({super.key});

  /// Open, so an invite link goes to this screen instead of a new one.
  static int _open = 0;
  static bool get isOpen => _open > 0;

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  late final Household _household = HouseholdScope.read(context);
  late final ShareService _service = _household.sharing!;
  late final Profile _profile = _household.current!;
  ShareClient? _client;

  _Step _step = _Step.intro;
  bool _busy = false;
  bool _unavailable = false;

  /// Shown under the current step.
  String? _error;

  SignInAttempt? _attempt;
  Timer? _ticker;
  final _email = TextEditingController();
  final _code = TextEditingController();

  ShareProfile? _me;
  FriendInvite? _invite;
  FriendsList? _friends;

  /// Shared with you, each matched against this profile's library.
  List<SharePreview>? _waiting;

  /// Channels you share.
  List<OutgoingChannel>? _outgoing;

  /// The first Add in Shared with you, where focus starts when shares wait.
  final _firstShareFocus = FocusNode(debugLabel: 'first share');

  /// Share channels: where focus goes once Shared with you is empty after
  /// an Add, Decline or Stop sharing, so the page stays where it was.
  final _shareChannelsFocus = FocusNode(debugLabel: 'share channels');

  /// Editing an existing share profile (not first setup).
  bool _editing = false;

  /// Where focus starts once the linked view has loaded.
  final _enterCodeFocus = FocusNode(debugLabel: 'enter a code');

  /// Holds the current step's controls, to find the first one.
  final _stepFocus = FocusNode(debugLabel: 'sharing step', skipTraversal: true, canRequestFocus: false);

  /// The step (and editing) last given focus.
  Object? _focusedStep;

  @override
  void initState() {
    super.initState();
    SharingScreen._open++;
    _service.pendingCode.addListener(_pendingChanged);
    if (_service.isLinked(_profile)) {
      _client = _service.clientFor(_profile);
      _step = _Step.linked;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLinked());
    }
  }

  @override
  void dispose() {
    SharingScreen._open--;
    _service.pendingCode.removeListener(_pendingChanged);
    _ticker?.cancel();
    _email.dispose();
    _code.dispose();
    _enterCodeFocus.dispose();
    _firstShareFocus.dispose();
    _shareChannelsFocus.dispose();
    _stepFocus.dispose();
    super.dispose();
  }

  /// A remote always needs a control to start on. When a step replaces the
  /// last one, the page takes the focus its control left (often before the
  /// new step's autofocus, or while a dialog is up), so once the step is
  /// shown and nothing on it has focus, its first control (on the linked
  /// view, Enter a code) takes it. Also run when the linked view's data
  /// arrives, and when a dialog over the step closes.
  void _focusStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final focus = FocusManager.instance.primaryFocus;
      if (focus != null && !isTvPageFocus(focus) && focus is! FocusScopeNode) return;
      if (_step == _Step.linked && !_editing && _me != null) {
        (_waiting?.isNotEmpty ?? false) && _firstShareFocus.context != null
            ? _firstShareFocus.requestFocus()
            : _enterCodeFocus.requestFocus();
        return;
      }
      _stepFocus.descendants.where((n) => n.canRequestFocus && !n.skipTraversal).firstOrNull?.requestFocus();
    });
  }

  // ---- Steps ----------------------------------------------------------------

  /// Runs [work] with the screen busy; turns the backend's failures into the
  /// screen's states.
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
      if (mounted) {
        setState(() {
          _step = _Step.intro;
          _me = null;
        });
      }
    } on StateError {
      // Stopped (hidden or asleep) mid-way: nothing was sent.
      if (mounted) setState(() => _unavailable = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadLinked() => _run(() async {
        final client = _client!;
        final me = await client.profile();
        if (!mounted) return;
        if (me == null) {
          setState(() => _step = _Step.profile);
          return;
        }
        // Show what I'm watching is asked once, before anything else: the
        // last step of setup, or the first visit after this update.
        if (me.presence == null) {
          setState(() {
            _me = me;
            _step = _Step.presence;
          });
          return;
        }
        final results = await Future.wait([client.friendInvite(), client.friends()]);
        if (!mounted) return;
        // The channel sections are their own: friends still show without them.
        try {
          await _loadChannels();
        } on ShareUnavailable {
          if (mounted) setState(() => _unavailable = true);
        }
        if (!mounted) return;
        setState(() {
          _me = me;
          _invite = results[0] as FriendInvite;
          _friends = results[1] as FriendsList;
          _step = _Step.linked;
        });
        _service.presence.friendsChanged(_friends!.friends);
        _focusStep();
        WidgetsBinding.instance.addPostFrameCallback((_) => _pendingChanged());
      });

  /// Shared with you and Channels you share (channel-sharing).
  Future<void> _loadChannels() async {
    final channels = _service.channels;
    if (channels.client == null) await _service.attachChannels();
    if (channels.client == null) return;
    await channels.refreshIncoming();
    final previews = [for (final s in channels.waiting) await channels.preview(s)];
    final outgoing = await channels.outgoing();
    if (!mounted) return;
    setState(() {
      _waiting = previews;
      _outgoing = outgoing;
    });
  }

  /// After an Add, Decline or Stop sharing: the next waiting share, else
  /// Share channels.
  void _focusChannels() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ((_waiting?.isNotEmpty ?? false) && _firstShareFocus.context != null ? _firstShareFocus : _shareChannelsFocus)
          .requestFocus();
    });
  }

  Future<void> _add(SharePreview preview) async {
    Channel? added;
    String? failure;
    await _run(() async {
      try {
        added = await _service.channels.add(preview);
      } on StateError catch (e) {
        failure = e.message;
      }
    });
    if (!mounted) return;
    if (added != null || failure != null) {
      await showMessage(context,
          title: preview.share.name, message: failure ?? tr.sharingAddedAs(added!.number));
    }
    await _run(_loadChannels);
    _focusChannels();
  }

  Future<void> _decline(SharePreview preview) async {
    await _run(() async {
      await _service.channels.decline(preview.share);
      await _loadChannels();
    });
    _focusChannels();
  }

  Future<void> _stopSharing(OutgoingChannel out) async {
    final name = out.channel?.displayName ?? out.share.name;
    if (!await confirm(context,
        title: tr.sharingStopSharing, message: tr.sharingStopSharingConfirm(name), action: tr.sharingStopSharing)) {
      return;
    }
    await _run(() async {
      await _service.channels.stop(out.share.id);
      await _loadChannels();
    });
    _focusChannels();
  }

  Future<void> _openShareChannels() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const ShareChannelsScreen()));
    if (mounted) await _run(_loadChannels);
  }

  Future<void> _setUp() => _run(() async {
        _client = await _service.setUp(_profile);
        if (mounted) setState(() => _step = _Step.email);
      });

  Future<void> _sendCode() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!SignInAttempt.looksLikeEmail(email)) {
      setState(() => _error = tr.sharingNotAnEmail);
      return;
    }
    await _run(() async {
      try {
        await _client!.sendCode(email);
      } on AuthApiException catch (e) {
        if (!mounted) return;
        setState(() => _error = e.statusCode == '429' ? tr.sharingTooManyTries : tr.sharingUnavailable);
        return;
      }
      if (!mounted) return;
      _code.clear();
      setState(() {
        _attempt = (_attempt?.email == email ? _attempt : SignInAttempt(email))!..sent();
        _step = _Step.code;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || (_attempt?.canResend ?? true)) t.cancel();
        if (mounted) setState(() {});
      });
    });
  }

  Future<void> _verify() async {
    if (_busy) return;
    final attempt = _attempt!;
    if (attempt.needsNewCode) return;
    final code = _code.text.replaceAll(RegExp(r'\s'), '');
    await _run(() async {
      final ok = RegExp(r'^\d{6}$').hasMatch(code) && await _client!.verifyCode(attempt.email, code);
      if (!mounted) return;
      if (!ok) {
        final check = attempt.wrongCode();
        setState(() => _error = check == CodeCheck.newCodeNeeded ? tr.sharingTooManyWrong : tr.sharingWrongCode);
        return;
      }
      _ticker?.cancel();
    });
    if (mounted && _client?.linked.value == true && _step == _Step.code) await _loadLinked();
  }

  Future<void> _saveProfile(ShareProfile draft) async {
    String? handleError;
    await _run(() async {
      try {
        final me = await _client!.saveProfile(draft);
        if (!mounted) return;
        setState(() {
          _me = me;
          _editing = false;
        });
      } on HandleTaken {
        handleError = tr.sharingHandleTaken;
      }
    });
    if (handleError != null) {
      if (mounted) setState(() => _error = handleError);
      return;
    }
    if (mounted && _me != null && _step == _Step.profile) await _loadLinked();
  }

  // ---- Invites ----------------------------------------------------------------

  /// An invite link's code, once this profile is set up.
  void _pendingChanged() {
    final code = _service.pendingCode.value;
    if (code == null || !mounted || _step != _Step.linked || _me == null || _busy) return;
    _service.pendingCode.value = null;
    unawaited(_offer(code));
  }

  Future<void> _newCode() => _run(() async {
        final invite = await _client!.friendInvite(fresh: true);
        if (mounted) setState(() => _invite = invite);
      });

  Future<void> _enterCode() async {
    if (_busy) return;
    final code = await _askForCode(context);
    if (code != null && mounted) await _offer(code);
  }

  /// "Add {name} (@handle) as a friend?", then the friendship.
  Future<void> _offer(String code) async {
    InviteResult? peek;
    await _run(() async => peek = await _client!.peek(code));
    if (!mounted || peek == null) return;
    if (peek!.status != InviteStatus.ok) {
      await _refused(peek!.status);
      return;
    }
    final from = peek!.from!;
    if (peek!.kind == 'watch') {
      await _offerParty(code, from, peek!.showTitle);
      return;
    }
    final channelsInvite = peek!.kind == 'channels';
    final add = await _ask(context,
        title: tr.sharingAddFriend,
        message: channelsInvite
            ? tr.sharingChannelsOffer(from.name, from.handle, joinNames(peek!.channels))
            : tr.sharingAddFriendQuestion(from.name, from.handle),
        action: tr.add,
        avatar: from);
    if (!add || !mounted) return;
    InviteResult? redeemed;
    await _run(() async {
      redeemed = await _client!.redeem(code);
      if (redeemed!.status == InviteStatus.ok) {
        final friends = await _client!.friends();
        if (mounted) setState(() => _friends = friends);
        if (channelsInvite) await _loadChannels();
      }
    });
    if (!mounted || redeemed == null) return;
    if (redeemed!.status == InviteStatus.ok) {
      final name = redeemed!.from?.name ?? from.name;
      await showMessage(context,
          title: tr.sharingAddFriend,
          message: channelsInvite ? tr.sharingNowFriendsChannels(name) : tr.sharingNowFriends(name));
    } else {
      await _refused(redeemed!.status);
    }
  }

  /// A `watch` link: the two become friends, then "Join Tyler's watch
  /// party?" (watch-together). Not now leaves it in Watch parties.
  Future<void> _offerParty(String code, ShareProfile from, String? title) async {
    InviteResult? redeemed;
    await _run(() async {
      redeemed = await _client!.redeem(code);
      if (redeemed!.status == InviteStatus.ok) {
        final friends = await _client!.friends();
        if (mounted) setState(() => _friends = friends);
      }
    });
    if (!mounted || redeemed == null) return;
    if (redeemed!.status != InviteStatus.ok || redeemed!.party == null) {
      await _refused(redeemed!.status);
      return;
    }
    final name = redeemed!.from?.name ?? from.name;
    final show = redeemed!.showTitle ?? title;
    final join = await _ask(context,
        title: tr.watchTogether,
        message: show == null || show.isEmpty ? tr.partyJoinQuestion(name) : '${tr.partyJoinQuestion(name)}\n$show',
        action: tr.partyJoin,
        icon: Icons.celebration,
        avatar: redeemed!.from ?? from);
    if (join && mounted) await _joinParty(redeemed!.party!);
  }

  /// Joins [partyId] and goes back to the TV, where it plays.
  Future<void> _joinParty(String partyId) async {
    if (await joinWatchParty(context, _service.party, partyId) && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _refused(InviteStatus status) => showMessage(context,
      title: tr.sharingAddFriend,
      message: switch (status) {
        InviteStatus.own => tr.sharingOwnCode,
        InviteStatus.limited => tr.sharingTooManyTries,
        _ => tr.sharingInviteGone,
      });

  // ---- Friends ----------------------------------------------------------------

  Future<void> _friendChosen(ShareProfile friend) async {
    if (_busy) return;
    final choice = await _choose(context, title: '${friend.name} (@${friend.handle})', avatar: friend, options: [
      tr.sharingRemoveFriend,
      tr.sharingBlock,
    ]);
    if (!mounted || choice == null) return;
    if (choice == 0) {
      if (!await confirm(context,
          title: tr.sharingRemoveFriend, message: tr.sharingRemoveFriendConfirm(friend.name), action: tr.remove)) {
        return;
      }
      await _run(() => _client!.removeFriend(friend.userId));
    } else {
      if (!await confirm(context, title: tr.sharingBlock, message: tr.sharingBlockConfirm(friend.name), action: tr.sharingBlock)) {
        return;
      }
      await _run(() => _client!.block(friend.userId));
    }
    await _refreshFriends();
  }

  Future<void> _blockedChosen(ShareProfile blocked) async {
    if (_busy) return;
    if (!await confirm(context,
        title: tr.sharingUnblock, message: tr.sharingUnblockConfirm(blocked.name), action: tr.sharingUnblock)) {
      return;
    }
    await _run(() => _client!.unblock(blocked.userId));
    await _refreshFriends();
  }

  Future<void> _refreshFriends() => _run(() async {
        final friends = await _client!.friends();
        _service.presence.friendsChanged(friends.friends);
        if (mounted) setState(() => _friends = friends);
      });

  // ---- Show what I'm watching (friend-presence) ----------------------------------

  /// The answer to the question (setup, or the first visit after the update).
  Future<void> _answerPresence(PresenceSetting value) async {
    await _run(() async {
      await _service.presence.setSetting(value, client: _client);
      if (mounted) setState(() => _me = _me?.withPresence(value.name));
    });
    if (mounted && _me?.presence != null && _step == _Step.presence) await _loadLinked();
  }

  /// The Sharing row: Friends or Off, the current one focused.
  Future<void> _changePresence() async {
    if (_busy) return;
    final current = PresenceSetting.parse(_me?.presence) ?? PresenceSetting.friends;
    final picked = await showDialog<PresenceSetting>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        final g = context.guide;
        return _dialog(
            context,
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr.presenceSetting, style: g.display(44, weight: FontWeight.w800)),
              const SizedBox(height: 20),
              Text(tr.presenceExplain, style: g.body(28, color: g.textDim)),
              const SizedBox(height: 32),
              for (final v in PresenceSetting.values) ...[
                TvButton(
                    label: _presenceLabel(v),
                    icon: v == current ? Icons.check : null,
                    expand: true,
                    autofocus: v == current,
                    onPressed: () => Navigator.pop(context, v)),
                const SizedBox(height: 16),
              ],
              TvButton(label: tr.cancel, expand: true, onPressed: () => Navigator.pop(context)),
            ]));
      },
    );
    if (picked == null || picked == current || !mounted) return;
    await _run(() async {
      await _service.presence.setSetting(picked, client: _client);
      if (mounted) setState(() => _me = _me?.withPresence(picked.name));
    });
  }

  Future<void> _signOut() async {
    if (_busy) return;
    if (!await confirm(context, title: tr.signOut, message: tr.sharingSignOutConfirm, action: tr.signOut)) return;
    await _service.signOut(_client!);
    if (mounted) _reset();
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    if (!await confirm(context,
        title: tr.sharingDeleteAccount, message: tr.sharingDeleteConfirm(_me?.handle ?? ''), action: tr.delete)) {
      return;
    }
    var deleted = false;
    await _run(() async {
      await _client!.deleteAccount();
      deleted = true;
    });
    if (!mounted || !deleted) return;
    _reset();
    await showMessage(context, title: tr.sharingDeleteAccount, message: tr.sharingDeleted);
    _focusStep();
  }

  void _reset() => setState(() {
        _step = _Step.intro;
        _me = null;
        _invite = null;
        _friends = null;
        _attempt = null;
        _error = null;
        _email.clear();
        _code.clear();
      });

  // ---- Layout -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final layout = ScreenLayout.of(context);
    if (_focusedStep != (_step, _editing)) {
      _focusedStep = (_step, _editing);
      _focusStep();
    }
    return TvPage(
      title: tr.sharing,
      hints: tr.moveOkSelectEsc,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: layout.pagePadding(const EdgeInsets.fromLTRB(120, 40, 120, 48)),
          children: [
            if (_unavailable) ...[
              _Note(tr.sharingUnavailable, error: true),
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TvButton(
                  label: tr.tryAgain,
                  icon: Icons.refresh,
                  autofocus: true,
                  onPressed: (_step == _Step.linked || _step == _Step.profile ? _loadLinked : () => setState(() => _unavailable = false)),
                ),
              ),
              const SizedBox(height: 40),
            ],
            // A new subtree per step, so its own field or button takes
            // focus, not whatever stood in the same place before.
            KeyedSubtree(
              key: ValueKey((_step, _editing)),
              child: Focus(
                focusNode: _stepFocus,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: switch (_step) {
                  _Step.intro => _intro(),
                  _Step.email => _emailStep(),
                  _Step.code => _codeStep(),
                  _Step.profile => [_profileForm()],
                  _Step.presence => _presenceStep(),
                  _Step.linked => _linked(),
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _intro() {
    final g = context.guide;
    return [
      Text(tr.sharingIntroTitle, style: g.display(44, weight: FontWeight.w800)),
      const SizedBox(height: 20),
      Text(tr.sharingIntroWhat, style: g.body(30)),
      const SizedBox(height: 16),
      Text(tr.sharingIntroStored, style: g.body(28, color: g.textDim)),
      const SizedBox(height: 16),
      Text(tr.sharingIntroNoVideo, style: g.body(28, weight: FontWeight.w700, color: g.accent)),
      const SizedBox(height: 40),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TvButton(
            label: tr.sharingSetUp, icon: Icons.person_add, autofocus: !_unavailable, onPressed: _setUp),
      ),
    ];
  }

  List<Widget> _emailStep() {
    final g = context.guide;
    return [
      Text(tr.sharingEmailPrompt, style: g.body(30)),
      const SizedBox(height: 24),
      TvTextField(
        controller: _email,
        label: tr.sharingEmailLabel,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        onSubmitted: (_) => _sendCode(),
      ),
      if (_error != null) ...[const SizedBox(height: 16), _Note(_error!, error: true)],
      const SizedBox(height: 28),
      ButtonRow(children: [
        TvButton(label: tr.sharingSendCode, icon: Icons.send, onPressed: _sendCode),
        TvButton(label: tr.cancel, onPressed: _reset),
      ]),
    ];
  }

  List<Widget> _codeStep() {
    final g = context.guide;
    final attempt = _attempt!;
    final wait = attempt.resendIn.inSeconds;
    return [
      Text(tr.sharingCodeSent(attempt.email), style: g.body(30)),
      const SizedBox(height: 24),
      if (!attempt.needsNewCode)
        TvTextField(
          controller: _code,
          label: tr.sharingCodeLabel,
          keyboardType: TextInputType.number,
          autofocus: true,
          onSubmitted: (_) => _verify(),
        ),
      if (_error != null) ...[const SizedBox(height: 16), _Note(_error!, error: true)],
      const SizedBox(height: 28),
      ButtonRow(children: [
        if (!attempt.needsNewCode) TvButton(label: tr.signIn, icon: Icons.login, onPressed: _verify),
        TvButton(
          label: attempt.canResend ? tr.sharingSendNewCode : tr.sharingSendNewCodeIn(wait),
          icon: Icons.refresh,
          autofocus: attempt.needsNewCode,
          onPressed: attempt.canResend ? _sendCode : null,
        ),
        TvButton(
            label: tr.sharingOtherEmail,
            onPressed: _busy
                ? null
                : () => setState(() {
                      _step = _Step.email;
                      _error = null;
                    })),
      ]),
    ];
  }

  /// Show what I'm watching? Friends is focused first.
  List<Widget> _presenceStep() {
    final g = context.guide;
    return [
      Text(tr.presenceQuestion, style: g.display(44, weight: FontWeight.w800)),
      const SizedBox(height: 20),
      Text(tr.presenceExplain, style: g.body(30)),
      const SizedBox(height: 40),
      ButtonRow(children: [
        TvButton(
            label: _presenceLabel(PresenceSetting.friends),
            icon: Icons.group,
            autofocus: !_unavailable,
            onPressed: _busy ? null : () => _answerPresence(PresenceSetting.friends)),
        TvButton(
            label: _presenceLabel(PresenceSetting.off),
            icon: Icons.visibility_off,
            onPressed: _busy ? null : () => _answerPresence(PresenceSetting.off)),
      ]),
    ];
  }

  Widget _profileForm() => _ProfileForm(
        key: ValueKey(_me?.userId ?? 'new'),
        initial: _me,
        suggestedName: _profile.name,
        userId: _client?.userId ?? '',
        busy: _busy,
        error: _error,
        checkHandle: (h) => _client!.handleAvailable(h),
        onSave: _saveProfile,
        onCancel: _me == null
            ? null
            : () => setState(() {
                  _editing = false;
                  _step = _Step.linked;
                  _error = null;
                }),
      );

  List<Widget> _linked() {
    final g = context.guide;
    final me = _me;
    if (_editing && me != null) return [_profileForm()];
    if (me == null) return [if (_busy) const _Loading()];
    final invite = _invite;
    final friends = _friends;
    final portrait = ScreenLayout.of(context).isPortrait;
    final canSend = PlatformInfo.isAndroid && !PlatformInfo.isTelevision;
    return [
      // The share profile.
      Row(children: [
        ShareAvatar(avatar: me.avatar, color: me.avatarColor, size: 120),
        const SizedBox(width: 32),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.name, style: g.display(44, weight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('@${me.handle}', style: g.body(30, color: g.accent)),
            if (me.station.isNotEmpty) Text(tr.sharingStation(me.station), style: g.body(26, color: g.textDim)),
          ]),
        ),
        if (!portrait)
          TvButton(
              label: tr.sharingEditProfile,
              icon: Icons.edit,
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _editing = true;
                        _error = null;
                      })),
      ]),
      if (portrait) ...[
        const SizedBox(height: 20),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TvButton(
              label: tr.sharingEditProfile,
              icon: Icons.edit,
              onPressed: () => setState(() => _editing = true)),
        ),
      ],
      const SizedBox(height: 32),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TvButton(
          label: tr.presenceSettingValue(_presenceLabel(PresenceSetting.parse(me.presence) ?? PresenceSetting.friends)),
          icon: Icons.visibility,
          onPressed: _busy ? null : _changePresence,
        ),
      ),
      const SizedBox(height: 48),
      // Open invites to watch together (watch-together).
      _WatchPartiesSection(party: _service.party, onJoin: (i) => unawaited(_joinParty(i.party))),
      ..._channelSections(),
      // Add friend.
      _Heading(tr.sharingAddFriend),
      if (invite != null) _InviteCard(invite: invite, host: _service.host),
      const SizedBox(height: 24),
      ButtonRow(children: [
        TvButton(
            label: tr.sharingEnterCode,
            icon: Icons.keyboard,
            autofocus: true,
            focusNode: _enterCodeFocus,
            onPressed: _enterCode),
        if (canSend && invite != null)
          TvButton(
            label: tr.sharingSendInvite,
            icon: Icons.share,
            onPressed: () => PlatformInfo.shareText(tr.sharingInviteText(InviteCode.link(invite.code, host: _service.host)),
                title: tr.sharingSendInvite),
          ),
        TvButton(label: tr.sharingNewCode, icon: Icons.autorenew, onPressed: _newCode),
      ]),
      const SizedBox(height: 48),
      // Friends.
      _Heading(tr.sharingFriends),
      if (friends != null && friends.friends.isEmpty) _Note(tr.sharingNoFriends),
      for (final f in friends?.friends ?? const <ShareProfile>[])
        ListenableBuilder(
          listenable: _service.presence,
          builder: (context, _) =>
              _PersonRow(person: f, watching: _service.presence.of(f.userId)?.line, onPressed: () => _friendChosen(f)),
        ),
      if (friends != null && friends.blocked.isNotEmpty) ...[
        const SizedBox(height: 40),
        _Heading(tr.sharingBlocked),
        for (final b in friends.blocked) _PersonRow(person: b, onPressed: () => _blockedChosen(b)),
      ],
      const SizedBox(height: 56),
      ButtonRow(children: [
        TvButton(label: tr.signOut, icon: Icons.logout, onPressed: _signOut),
        TvButton(label: tr.sharingDeleteAccount, icon: Icons.delete_forever, danger: true, onPressed: _deleteAccount),
      ]),
    ];
  }
}

extension on _SharingScreenState {
  /// Shared with you, Share channels and Channels you share.
  List<Widget> _channelSections() {
    final g = context.guide;
    final waiting = _waiting;
    final outgoing = _outgoing;
    return [
      _Heading(tr.sharingSharedWithYou),
      if (waiting != null && waiting.isEmpty) _Note(tr.sharingNothingShared),
      for (final (i, p) in (waiting ?? const <SharePreview>[]).indexed)
        _ShareCard(
          preview: p,
          firstFocus: i == 0 ? _firstShareFocus : null,
          onAdd: _busy || !p.canAdd ? null : () => _add(p),
          onDecline: _busy ? null : () => _decline(p),
        ),
      const SizedBox(height: 48),
      _Heading(tr.sharingChannelsYouShare),
      if (outgoing != null && outgoing.isEmpty) ...[_Note(tr.sharingNoChannelsShared), const SizedBox(height: 16)],
      for (final o in outgoing ?? const <OutgoingChannel>[])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.channel == null ? o.share.name : '${o.channel!.number}  ${o.channel!.displayName}',
                    style: g.display(30, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (o.receivers.isNotEmpty)
                  Text(tr.sharingWith(joinNames([for (final r in o.receivers) r.name])), style: g.body(24, color: g.textDim)),
              ]),
            ),
            const SizedBox(width: 16),
            TvButton(label: tr.sharingStopSharing, icon: Icons.stop_circle, onPressed: _busy ? null : () => _stopSharing(o)),
          ]),
        ),
      const SizedBox(height: 16),
      // On the right like the page's other buttons, so Up and Down reach it.
      ButtonRow(children: [
        TvButton(
            label: tr.sharingShareChannels,
            icon: Icons.ios_share,
            focusNode: _shareChannelsFocus,
            onPressed: _busy ? null : _openShareChannels),
      ]),
      const SizedBox(height: 48),
    ];
  }
}

/// One share in Shared with you: who sent it, the channel, how much of it
/// this profile's servers have, Add and Decline.
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.preview, this.firstFocus, required this.onAdd, required this.onDecline});

  final SharePreview preview;
  final FocusNode? firstFocus;
  final VoidCallback? onAdd;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final s = preview.share;
    final from = s.from;
    final m = preview.match;
    final portrait = ScreenLayout.of(context).isPortrait;
    final status = preview.tooNew
        ? tr.sharingUpdateApp
        : m == null
            ? null
            : m.none
                ? tr.sharingNoneMatch
                : tr.sharingMatched(m.matched, m.total);
    final canAdd = preview.canAdd;
    final recipeStation = preview.recipe?.station ?? '';
    final station = recipeStation.isNotEmpty ? recipeStation : (from?.station ?? '');
    final buttons = ButtonRow(children: [
      if (canAdd) TvButton(label: tr.add, icon: Icons.add, focusNode: firstFocus, onPressed: onAdd),
      TvButton(label: tr.sharingDecline, icon: Icons.close, focusNode: canAdd ? null : firstFocus, onPressed: onDecline),
    ]);
    final info = Row(children: [
      if (from != null) ...[
        ShareAvatar(avatar: from.avatar, color: from.avatarColor, size: 80),
        const SizedBox(width: 24),
      ],
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (preview.recipe?.icon case final icon?) ...[
              ChannelLogo(icon: icon, size: 44),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(s.name,
                  style: g.display(32, weight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
          if (from != null)
            Text(['${from.name}  @${from.handle}', if (station.isNotEmpty) station].join(' · '),
                style: g.body(24, color: g.textDim)),
          if (status != null)
            Text(status, style: g.body(26, weight: FontWeight.w600, color: canAdd ? g.accent : g.nowLine)),
        ]),
      ),
    ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: g.cell,
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: g.cellBorder, width: 2),
        ),
        child: portrait
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 16), buttons])
            : Row(children: [Expanded(child: info), const SizedBox(width: 24), buttons]),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text, style: g.display(34, weight: FontWeight.w800, color: g.accent)),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Text(text, style: g.body(28, weight: error ? FontWeight.w600 : FontWeight.w500, color: error ? g.nowLine : g.textDim));
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: context.guide.accent)),
      );
}

/// The live code three ways: `AB3K·9Q`, the link and a QR code of the link.
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite, required this.host, this.help});

  final FriendInvite invite;
  final String host;

  /// What the code does; a friend code's by default.
  final String? help;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final link = InviteCode.link(invite.code, host: host);
    final portrait = ScreenLayout.of(context).isPortrait;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(InviteCode.display(invite.code), style: g.display(80, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 8),
      Text(link, style: g.body(28)),
      const SizedBox(height: 12),
      Text(help ?? tr.sharingCodeHelp, style: g.body(24, color: g.textDim)),
    ]);
    final qr = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(g.radius)),
      child: QrImageView(data: link, size: 220, padding: EdgeInsets.zero, backgroundColor: Colors.white),
    );
    if (portrait) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 20), qr]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: text), const SizedBox(width: 40), qr]);
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onPressed, this.watching});

  final ShareProfile person;
  final VoidCallback? onPressed;

  /// "Watching The Office on 90s Sitcoms" while the friend's presence is live.
  final String? watching;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvFocusable(
        onPressed: onPressed,
        builder: (context, focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: focused ? g.focus : g.cell,
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
          ),
          child: Row(children: [
            ShareAvatar(avatar: person.avatar, color: person.avatarColor, size: 64),
            const SizedBox(width: 24),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: person.name, style: g.display(30, weight: FontWeight.w700, color: focused ? g.onFocus : g.text)),
                    TextSpan(text: '  @${person.handle}', style: g.body(26, color: focused ? g.onFocus : g.textDim)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (watching case final line?)
                  Text(line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: g.body(24, weight: FontWeight.w600, color: focused ? g.onFocus : g.accent)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The share profile form: name, handle (checked as it's typed), avatar,
/// colour and station.
class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    super.key,
    required this.initial,
    required this.suggestedName,
    required this.userId,
    required this.busy,
    required this.error,
    required this.checkHandle,
    required this.onSave,
    required this.onCancel,
  });

  final ShareProfile? initial;
  final String suggestedName;
  final String userId;
  final bool busy;
  final String? error;
  final Future<bool> Function(String handle) checkHandle;
  final Future<void> Function(ShareProfile draft) onSave;
  final VoidCallback? onCancel;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? widget.suggestedName);
  late final _handle = TextEditingController(text: widget.initial?.handle ?? _suggestHandle(widget.suggestedName));
  late final _station = TextEditingController(text: widget.initial?.station ?? '');
  late String _avatar = widget.initial?.avatar ?? shareAvatarIds.first;
  late int _color = widget.initial?.avatarColor ?? 0;
  String? _nameError;
  String? _handleError;
  Timer? _check;

  static String _suggestHandle(String name) {
    final h = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return h.length > 20 ? h.substring(0, 20) : h;
  }

  @override
  void initState() {
    super.initState();
    _handle.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _check?.cancel();
    _name.dispose();
    _handle.dispose();
    _station.dispose();
    super.dispose();
  }

  String? _handleRule(String h) => ShareProfile.handlePattern.hasMatch(h) ? null : tr.sharingHandleRules;

  void _handleChanged() {
    _check?.cancel();
    final h = ShareProfile.cleanHandle(_handle.text);
    final rule = h.isEmpty ? null : _handleRule(h);
    if (rule != null || h.isEmpty || h == widget.initial?.handle) {
      setState(() => _handleError = rule);
      return;
    }
    _check = Timer(const Duration(milliseconds: 500), () async {
      try {
        final free = await widget.checkHandle(h);
        if (mounted && ShareProfile.cleanHandle(_handle.text) == h) {
          setState(() => _handleError = free ? null : tr.sharingHandleTaken);
        }
      } on Object {
        // Checked again when saved.
      }
    });
  }

  Future<void> _save() async {
    if (widget.busy) return;
    final name = _name.text.trim();
    final handle = ShareProfile.cleanHandle(_handle.text);
    setState(() {
      _nameError = name.isEmpty ? tr.sharingNameRequired : null;
      _handleError = _handleRule(handle);
    });
    if (_nameError != null || _handleError != null) return;
    await widget.onSave(ShareProfile(
      userId: widget.userId,
      name: name.length > ShareProfile.nameMax ? name.substring(0, ShareProfile.nameMax) : name,
      handle: handle,
      avatar: _avatar,
      avatarColor: _color,
      station: _station.text.trim().length > ShareProfile.stationMax
          ? _station.text.trim().substring(0, ShareProfile.stationMax)
          : _station.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final handleError = _handleError ?? (widget.error == tr.sharingHandleTaken ? widget.error : null);
    final otherError = widget.error == tr.sharingHandleTaken ? null : widget.error;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr.sharingProfileTitle, style: g.display(44, weight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(tr.sharingProfileIntro, style: g.body(28, color: g.textDim)),
      const SizedBox(height: 28),
      TvTextField(controller: _name, label: tr.sharingNameLabel, autofocus: widget.initial == null),
      if (_nameError != null) ...[const SizedBox(height: 8), _Note(_nameError!, error: true)],
      const SizedBox(height: 20),
      TvTextField(controller: _handle, label: tr.sharingHandleLabel, hint: tr.sharingHandleRules),
      if (handleError != null) ...[const SizedBox(height: 8), _Note(handleError, error: true)],
      const SizedBox(height: 20),
      TvTextField(controller: _station, label: tr.sharingStationLabel),
      const SizedBox(height: 32),
      Text(tr.sharingAvatar, style: g.display(30, weight: FontWeight.w700)),
      const SizedBox(height: 16),
      FocusTraversalGroup(
        child: Wrap(spacing: 16, runSpacing: 16, children: [
          for (final id in shareAvatarIds)
            _Pick(
              selected: id == _avatar,
              onPressed: () => setState(() => _avatar = id),
              child: ShareAvatar(avatar: id, color: _color, size: 88),
            ),
        ]),
      ),
      const SizedBox(height: 28),
      Text(tr.color, style: g.display(30, weight: FontWeight.w700)),
      const SizedBox(height: 16),
      FocusTraversalGroup(
        child: Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < avatarColors.length; i++)
            _Pick(
              selected: i == _color,
              label: tr.colour(i + 1),
              onPressed: () => setState(() => _color = i),
              child: Container(width: 72, height: 72, decoration: BoxDecoration(color: avatarColors[i], shape: BoxShape.circle)),
            ),
        ]),
      ),
      if (otherError != null) ...[const SizedBox(height: 20), _Note(otherError, error: true)],
      const SizedBox(height: 36),
      ButtonRow(children: [
        TvButton(label: tr.save, icon: Icons.check, onPressed: _save),
        if (widget.onCancel != null) TvButton(label: tr.cancel, onPressed: widget.onCancel),
      ]),
    ]);
  }
}

/// A choice in a grid (avatar or colour): a ring when chosen, the focus
/// highlight when focused.
class _Pick extends StatelessWidget {
  const _Pick({required this.selected, required this.onPressed, required this.child, this.label});

  final bool selected;
  final VoidCallback onPressed;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: TvFocusable(
        onPressed: onPressed,
        builder: (context, focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: focused ? g.focus : (selected ? Colors.white : Colors.transparent), width: focused ? 6 : 4),
            boxShadow: focused ? [BoxShadow(color: g.focus.withValues(alpha: 0.45), blurRadius: 18)] : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---- Dialogs --------------------------------------------------------------------

Widget _dialog(BuildContext context, Widget child, {double width = 900}) {
  final g = context.guide;
  return Dialog(
    backgroundColor: g.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(g.radius * 2),
      side: BorderSide(color: g.cellBorder, width: 2),
    ),
    child: Padding(
      padding: EdgeInsets.all(dialogPadding(context)),
      child: SizedBox(width: dialogWidth(context, width, padding: dialogPadding(context)), child: dialogBody(context, child)),
    ),
  );
}

/// A yes/no question whose yes isn't destructive (Add a friend). Focus
/// starts on Cancel, so pressing OK twice never adds anyone by accident.
Future<bool> _ask(BuildContext context,
    {required String title,
    required String message,
    required String action,
    IconData icon = Icons.person_add,
    ShareProfile? avatar}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final g = context.guide;
      return _dialog(
          context,
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: g.display(48, weight: FontWeight.w800)),
            const SizedBox(height: 20),
            Row(children: [
              if (avatar != null) ...[
                ShareAvatar(avatar: avatar.avatar, color: avatar.avatarColor, size: 96),
                const SizedBox(width: 24),
              ],
              Expanded(child: Text(message, style: g.body(32))),
            ]),
            const SizedBox(height: 40),
            ButtonRow(children: [
              TvButton(label: tr.cancel, autofocus: true, onPressed: () => Navigator.pop(context, false)),
              TvButton(label: action, icon: icon, onPressed: () => Navigator.pop(context, true)),
            ]),
          ]));
    },
  );
  return result ?? false;
}

/// One of [options], or null for Cancel.
Future<int?> _choose(BuildContext context,
    {required String title, required List<String> options, ShareProfile? avatar}) {
  return showDialog<int>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final g = context.guide;
      return _dialog(
          context,
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (avatar != null) ...[
                ShareAvatar(avatar: avatar.avatar, color: avatar.avatarColor, size: 96),
                const SizedBox(width: 24),
              ],
              Expanded(child: Text(title, style: g.display(40, weight: FontWeight.w800))),
            ]),
            const SizedBox(height: 32),
            // One under another: long labels in any language fit.
            for (final (i, o) in options.indexed) ...[
              TvButton(label: o, expand: true, danger: i > 0, onPressed: () => Navigator.pop(context, i)),
              const SizedBox(height: 16),
            ],
            TvButton(label: tr.cancel, expand: true, autofocus: true, onPressed: () => Navigator.pop(context)),
          ]));
    },
  );
}

/// "Enter a code": the cleaned code, or null. Returns once the dialog has
/// fully closed, so the confirmation that follows keeps the focus (the
/// closing dialog hands focus back to the screen as it goes).
Future<String?> _askForCode(BuildContext context) async {
  final route = DialogRoute<String>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => const _CodeDialog(),
  );
  final code = await Navigator.of(context).push(route);
  await route.completed;
  return code;
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _next() {
    final code = InviteCode.clean(_code.text);
    if (code == null) {
      setState(() => _error = tr.sharingNotACode);
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return _dialog(
        context,
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr.sharingEnterCode, style: g.display(48, weight: FontWeight.w800)),
          const SizedBox(height: 24),
          TvTextField(
            controller: _code,
            label: tr.sharingCodeFieldLabel,
            hint: InviteCode.display('AB3K9Q'),
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            onSubmitted: (_) => _next(),
          ),
          if (_error != null) ...[const SizedBox(height: 12), _Note(_error!, error: true)],
          const SizedBox(height: 32),
          ButtonRow(children: [
            TvButton(label: tr.cancel, onPressed: () => Navigator.pop(context)),
            TvButton(label: tr.add, icon: Icons.arrow_forward, onPressed: _next),
          ]),
        ]));
  }
}

/// Opens Sharing for an invite link's code once a profile is watching
/// (share-accounts, "Invite links open the app"): straight away on an adult
/// profile, which keeps the code through setup; a kid profile is told to
/// switch, and the code waits for an adult profile.
class SharingInviteHost extends StatefulWidget {
  const SharingInviteHost({super.key, required this.household, required this.navigator, required this.child});

  final Household household;
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  State<SharingInviteHost> createState() => _SharingInviteHostState();
}

class _SharingInviteHostState extends State<SharingInviteHost> {
  ShareService? get _service => widget.household.sharing;
  AppState? _app;

  /// The code this host last acted on, so it acts once per code and profile.
  (String, String)? _handled;

  /// The kid profile's message, or Sharing opened from a link, is up.
  bool _showing = false;

  /// The TV screen can arrive under the message and take focus; it goes
  /// back to the message.
  late final _keepFocus = KeepFocusOnTop(active: () => _showing);

  @override
  void initState() {
    super.initState();
    _service?.pendingCode.addListener(_check);
    widget.household.addListener(_householdChanged);
    _keepFocus.start();
    _householdChanged();
  }

  @override
  void dispose() {
    _service?.pendingCode.removeListener(_check);
    widget.household.removeListener(_householdChanged);
    _app?.removeListener(_check);
    _keepFocus.stop();
    super.dispose();
  }

  void _householdChanged() {
    final app = widget.household.app;
    if (app != _app) {
      _app?.removeListener(_check);
      _app = app?..addListener(_check);
    }
    _check();
  }

  void _check() {
    final service = _service;
    final code = service?.pendingCode.value;
    final profile = widget.household.current;
    if (service == null) return;
    if (code == null || profile == null || _app?.phase != AppPhase.ready || SharingScreen.isOpen) return;
    if (_handled == (code, profile.id)) return;
    _handled = (code, profile.id);
    // After a frame, which a link arriving in the background may not bring.
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = widget.navigator.currentContext;
      if (context == null || !context.mounted) return;
      if (profile.isKid) {
        _showing = true;
        try {
          await showMessage(context, title: tr.sharingAddFriend, message: tr.sharingSwitchToAdult);
        } finally {
          _showing = false;
        }
        return;
      }
      _showing = true;
      try {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SharingScreen()));
      } finally {
        _showing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _presenceLabel(PresenceSetting v) => switch (v) {
      PresenceSetting.friends => tr.sharingFriends,
      PresenceSetting.off => tr.off,
    };
