import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../channels/channel.dart';
import '../l10n/tr.dart';
import '../platform/platform_info.dart';
import '../server/youtube/google_sign_in.dart';
import '../server/youtube/youtube_api.dart';
import '../server/youtube/youtube_client_config.dart';
import '../server/youtube/youtube_links.dart';
import '../server/youtube/youtube_server.dart';
import '../theme/tv_theme.dart';
import 'menu_screen.dart' show confirm;
import 'widgets/adaptive.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// The addresses the YouTube sign-in names (youtube-subscriptions D3, D14).
abstract final class YouTubeLinks {
  static const terms = YouTubeAddresses.terms;
  static const termsShort = YouTubeAddresses.termsShort;
  static const privacy = YouTubeAddresses.privacy;
  static const privacyShort = YouTubeAddresses.privacyShort;
  static const clientGuide = YouTubeAddresses.clientGuide;
  static const clientGuideShort = YouTubeAddresses.clientGuideShort;
  static const device = YouTubeAddresses.device;
  static const deviceShort = YouTubeAddresses.deviceShort;
  static const webViewStore = 'https://play.google.com/store/apps/details?id=com.google.android.webview';
  static const webViewStoreShort = 'play.google.com · Android System WebView';

  /// Phones and PCs open links; a TV shows the QR code only.
  static bool get canOpen => PlatformInfo.hasTouch || PlatformInfo.isDesktop;
}

/// A QR code with the short address under it, and on phones and Linux a
/// button that opens it.
class LinkQr extends StatelessWidget {
  const LinkQr({super.key, required this.url, required this.label, required this.short, this.size = 160});

  final String url;
  final String label;
  final String short;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(10),
        color: Colors.white,
        child: QrImageView(data: url, size: size, padding: EdgeInsets.zero, backgroundColor: Colors.white),
      ),
      const SizedBox(height: 10),
      Text(label, textAlign: TextAlign.center, style: g.body(22, weight: FontWeight.w600)),
      Text(short, textAlign: TextAlign.center, style: g.body(20, color: g.textDim)),
      if (YouTubeLinks.canOpen) ...[
        const SizedBox(height: 8),
        TvButton(label: label, icon: Icons.open_in_new, onPressed: () => unawaited(PlatformInfo.openUrl(url))),
      ],
    ]);
  }
}

/// The consent before the code (D3): signing in means agreeing to
/// YouTube's Terms of Service and the app's privacy policy.
class YouTubeConsent extends StatelessWidget {
  const YouTubeConsent({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(tr.youTube, style: g.display(56, weight: FontWeight.w800)),
      const SizedBox(height: 16),
      Text(tr.youTubeTerms, style: g.body(26, color: g.textDim)),
      const SizedBox(height: 24),
      Wrap(spacing: 32, runSpacing: 24, children: [
        LinkQr(url: YouTubeLinks.terms, label: tr.youTubeTermsOfService, short: YouTubeLinks.termsShort, size: 140),
        LinkQr(url: YouTubeLinks.privacy, label: tr.privacyPolicy, short: YouTubeLinks.privacyShort, size: 140),
      ]),
    ]);
  }
}

/// The code for google.com/device, on the Plex link-code layout, with a QR
/// code of the address (D3).
class YouTubeCodeStep extends StatelessWidget {
  const YouTubeCodeStep({super.key, required this.code, required this.codeBox, required this.onCancel});

  final DeviceCode? code;
  final Widget Function(String code) codeBox;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final c = code;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(tr.youTubeEnterCode(YouTubeLinks.deviceShort), style: g.body(26, color: g.textDim)),
      const SizedBox(height: 24),
      if (c != null) codeBox(c.userCode),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: QrImageView(
              data: c?.verificationUrl ?? YouTubeLinks.device, size: 120, padding: EdgeInsets.zero, backgroundColor: Colors.white),
        ),
        const SizedBox(width: 20),
        Expanded(child: Text(tr.waitingForThe, style: g.body(24, color: g.textDim))),
      ]),
      const SizedBox(height: 24),
      if (YouTubeLinks.canOpen) ...[
        TvButton(
            label: tr.openGoogleDevice,
            icon: Icons.open_in_new,
            expand: true,
            onPressed: () => unawaited(PlatformInfo.openUrl(c?.verificationUrl ?? YouTubeLinks.device))),
        const SizedBox(height: 20),
      ],
      TvButton(label: tr.cancel, icon: Icons.close, expand: true, autofocus: true, onPressed: onCancel),
    ]);
  }
}

/// The own Google client form (D10): the fields, Open file, the steps with
/// the guide's QR code, and the buttons.
class GoogleClientForm extends StatefulWidget {
  const GoogleClientForm({super.key, required this.onUse, this.onUseShared, this.sharedTooMany = false, this.busy = false});

  /// Use this client.
  final ValueChanged<GoogleClient> onUse;

  /// Use Nightingale TV's client; null when the build has none, or it's
  /// the one used now.
  final VoidCallback? onUseShared;

  /// Use Nightingale TV's client is offered but greyed: the server's
  /// channels would take the profile above its limit (youtube-shared-client
  /// D6).
  final bool sharedTooMany;
  final bool busy;

  @override
  State<GoogleClientForm> createState() => _GoogleClientFormState();
}

class _GoogleClientFormState extends State<GoogleClientForm> {
  final _id = TextEditingController();
  final _secret = TextEditingController();
  String? _note;

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  /// Linux and phones: Google's downloaded client file.
  bool get _canOpenFile => PlatformInfo.isDesktop || PlatformInfo.hasTouch;

  Future<void> _openFile() async {
    final file = await openFile(
        acceptedTypeGroups: PlatformInfo.isAndroid ? const [] : [XTypeGroup(label: 'JSON', extensions: const ['json'])]);
    if (file == null) return;
    GoogleClient? client;
    try {
      client = GoogleClient.fromDownload(jsonDecode(utf8.decode(await file.readAsBytes())));
    } on Object {
      client = null;
    }
    if (!mounted) return;
    setState(() {
      if (client == null) {
        _note = tr.clientFileNotRead;
      } else {
        _note = null;
        _id.text = client.id;
        _secret.text = client.secret;
      }
    });
  }

  void _use() {
    final id = _id.text.trim(), secret = _secret.text.trim();
    if (id.isEmpty || secret.isEmpty) {
      setState(() => _note = tr.clientFileNotRead);
      return;
    }
    widget.onUse(GoogleClient(id: id, secret: secret, own: true));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final steps = [
      tr.ownClientStep1,
      tr.ownClientStep2,
      tr.ownClientStep3,
      tr.ownClientStep4,
      tr.ownClientStep5,
      tr.ownClientStep6,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(tr.ownClientTitle, style: g.display(40)),
      const SizedBox(height: 20),
      for (final (i, s) in steps.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('${i + 1}. $s', style: g.body(22, color: g.textDim)),
        ),
      const SizedBox(height: 12),
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: QrImageView(data: YouTubeLinks.clientGuide, size: 110, padding: EdgeInsets.zero, backgroundColor: Colors.white),
        ),
        const SizedBox(width: 20),
        Expanded(child: Text(tr.ownClientGuide(YouTubeLinks.clientGuideShort), style: g.body(22, color: g.textDim))),
      ]),
      const SizedBox(height: 24),
      TvTextField(key: const ValueKey('client-id'), controller: _id, label: tr.clientId, autofocus: true),
      const SizedBox(height: 16),
      TvTextField(key: const ValueKey('client-secret'), controller: _secret, label: tr.clientSecret, obscure: true),
      if (_note != null) ...[
        const SizedBox(height: 12),
        Text(_note!, style: g.body(22, color: g.nowLine)),
      ],
      const SizedBox(height: 20),
      if (_canOpenFile) ...[
        TvButton(label: tr.openClientFile, icon: Icons.file_open, expand: true, onPressed: widget.busy ? null : _openFile),
        const SizedBox(height: 16),
      ],
      TvButton(label: tr.useThisClient, icon: Icons.arrow_forward, expand: true, onPressed: widget.busy ? null : _use),
      if (widget.onUseShared case final shared?) ...[
        const SizedBox(height: 16),
        TvButton(
            key: const ValueKey('use-shared-client'),
            label: tr.useSharedClient,
            icon: Icons.restart_alt,
            expand: true,
            onPressed: widget.busy || widget.sharedTooMany ? null : shared),
        if (widget.sharedTooMany) ...[
          const SizedBox(height: 8),
          Text(tr.youTubeSharedTooMany(AppState.youTubeSharedLimit), style: g.body(22, color: g.textDim)),
        ],
      ],
    ]);
  }
}

/// A subscription's avatar, or a placeholder.
class YouTubeAvatar extends StatelessWidget {
  const YouTubeAvatar({super.key, this.url, this.size = 56});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final placeholder = Icon(Icons.smart_display, size: size * 0.7, color: g.textDim);
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? placeholder
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
      ),
    );
  }
}

/// The subscription picker (D5): title order, avatars, a search field, check
/// boxes, "n of 5" on Nightingale TV's client and Done. Picks the account no longer subscribes to
/// stay, marked Not subscribed.
class YouTubePicker extends StatefulWidget {
  const YouTubePicker({
    super.key,
    required this.subscriptions,
    required this.current,
    required this.others,
    required this.onDone,
    this.busy = false,
    this.error,
  });

  /// The account's subscriptions, in title order.
  final List<YouTubeSubscription> subscriptions;

  /// This server's picks now (its channels), in channel order.
  final List<YouTubeSubscription> current;

  /// The profile's channels on Nightingale TV's client from its other
  /// YouTube servers; null when this server has its own client, which has
  /// no limit (youtube-shared-client D6).
  final int? others;

  /// Done, with the picks; removed ones were confirmed.
  final ValueChanged<List<YouTubeSubscription>> onDone;
  final bool busy;
  final String? error;

  @override
  State<YouTubePicker> createState() => _YouTubePickerState();
}

class _YouTubePickerState extends State<YouTubePicker> {
  late final Set<String> _checked = {for (final s in widget.current) s.channelId};
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Channels on Nightingale TV's client with these picks; null on an own
  /// client.
  int? get _count => widget.others == null ? null : widget.others! + _checked.length;
  bool get _full => (_count ?? 0) >= AppState.youTubeSharedLimit;

  /// Every row: the subscriptions, then picks no longer subscribed to.
  List<({YouTubeSubscription sub, bool subscribed})> get _rows {
    final subscribed = {for (final s in widget.subscriptions) s.channelId};
    return [
      for (final s in widget.subscriptions) (sub: s, subscribed: true),
      for (final s in widget.current)
        if (!subscribed.contains(s.channelId)) (sub: s, subscribed: false),
    ];
  }

  void _toggle(String id) => setState(() => _checked.contains(id) ? _checked.remove(id) : _checked.add(id));

  Future<void> _done() async {
    final removed = [
      for (final s in widget.current)
        if (!_checked.contains(s.channelId)) s.title
    ];
    if (removed.isNotEmpty) {
      final ok = await confirm(context,
          title: tr.youTubeChannelsTitle, message: tr.removeYouTubeChannels(joinNames(removed)), action: tr.remove);
      if (!ok || !mounted) return;
    }
    final all = {for (final r in _rows) r.sub.channelId: r.sub};
    widget.onDone([for (final id in all.keys) if (_checked.contains(id)) all[id]!]);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final rows = [
      for (final r in _rows)
        if (_query.isEmpty || r.sub.title.toLowerCase().contains(_query)) r
    ];
    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text(tr.youTubeChannelsTitle, style: g.display(44))),
        if (_count case final count?)
          Text(tr.youTubePickedOf(count, AppState.youTubeSharedLimit),
              key: const ValueKey('picked-count'),
              style: g.display(34, weight: FontWeight.w700, color: _full ? g.nowLine : g.accent)),
      ]),
      const SizedBox(height: 20),
      TvTextField(key: const ValueKey('subscription-search'), controller: _search, label: tr.searchSubscriptions),
      const SizedBox(height: 20),
      ButtonRow(children: [
        TvButton(label: tr.done, icon: Icons.check, autofocus: true, onPressed: widget.busy ? null : _done),
      ]),
      if (widget.error != null) ...[
        const SizedBox(height: 16),
        Text(widget.error!, style: g.body(24, color: g.nowLine)),
      ],
      if (widget.busy) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
      const SizedBox(height: 24),
      if (rows.isEmpty)
        Text(widget.subscriptions.isEmpty ? tr.noSubscriptions : tr.noSubscriptionsMatch,
            style: g.body(26, color: g.textDim)),
    ]);
    return ListView.builder(
      padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(120, 32, 120, 48)),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        final r = rows[i - 1];
        final checked = _checked.contains(r.sub.channelId);
        final enabled = checked || !_full;
        return YouTubeCheckRow(
          key: ValueKey(r.sub.channelId),
          avatar: r.sub.avatarUrl,
          title: r.sub.title,
          subtitle: !r.subscribed
              ? tr.notSubscribed
              : enabled
                  ? null
                  : tr.youTubeSharedLimit(AppState.youTubeSharedLimit),
          checked: checked,
          onPressed: enabled && !widget.busy ? () => _toggle(r.sub.channelId) : null,
        );
      },
    );
  }
}

/// A picker row: check box, avatar and title; without [onPressed] it can't
/// take focus and [subtitle] says why.
class YouTubeCheckRow extends StatelessWidget {
  const YouTubeCheckRow(
      {super.key, required this.avatar, required this.title, this.subtitle, required this.checked, this.onPressed});

  final String? avatar;
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: focused ? g.focus : g.cell,
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
          ),
          child: Row(children: [
            Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 40, color: !enabled ? g.textDim : focused ? g.onFocus : g.accent),
            const SizedBox(width: 20),
            YouTubeAvatar(url: avatar),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.display(30, weight: FontWeight.w700, color: focused ? g.onFocus : (enabled ? g.text : g.textDim))),
                if (subtitle != null) Text(subtitle!, style: g.body(22, color: focused ? g.onFocus : g.textDim)),
              ]),
            ),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: enabled ? TvFocusable(onPressed: onPressed, builder: (context, focused) => body(focused)) : body(false),
    );
  }
}

/// This server's picks as the picker shows them, from its channels.
List<YouTubeSubscription> currentPicks(AppState app, String key) => [
      for (final c in app.youTubeChannels)
        if (c.youtube!.serverKey == key)
          YouTubeSubscription(
              channelId: c.youtube!.channelId,
              title: c.name,
              avatarUrl: c.icon.kind == ChannelIconKind.remote ? c.icon.value : null),
    ];

/// Servers → YouTube → Channels: the picker for an added (or main)
/// YouTube server, its subscriptions loaded once per opening.
class YouTubeChannelsScreen extends StatefulWidget {
  const YouTubeChannelsScreen({super.key, required this.serverKey});

  final String serverKey;

  @override
  State<YouTubeChannelsScreen> createState() => _YouTubeChannelsScreenState();
}

class _YouTubeChannelsScreenState extends State<YouTubeChannelsScreen> {
  late final AppState _app = AppScope.read(context);
  List<YouTubeSubscription>? _subs;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  YouTubeServer? get _server => _app.youtube.serverOf(widget.serverKey);

  Future<void> _load() async {
    final server = _server;
    if (server == null) return;
    final blocked = server.quotaBlockedUntil;
    if (blocked != null) {
      setState(() => _error = tr.youTubeDailyLimit(formatClock(context, blocked)));
      return;
    }
    try {
      final subs = await server.subscriptions();
      if (mounted) setState(() => _subs = subs);
    } on YouTubeQuotaException {
      final until = server.quotaBlockedUntil;
      if (mounted && until != null) setState(() => _error = tr.youTubeDailyLimit(formatClock(context, until)));
    } on Object {
      if (mounted) setState(() => _error = tr.couldNotReachGoogle);
    }
  }

  Future<void> _done(List<YouTubeSubscription> picks) async {
    setState(() => _busy = true);
    try {
      await _app.setYouTubePicks(widget.serverKey, picks);
      if (mounted) Navigator.of(context).pop();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final subs = _subs;
    final others = _app.youTubeOwnClient(widget.serverKey) ? null : _app.youTubeSharedCount(except: widget.serverKey);
    return TvPage(
      title: tr.youTubeChannelsTitle,
      hints: tr.moveOkSelectEsc,
      onBack: () => Navigator.of(context).maybePop(),
      child: subs == null
          ? Center(
              child: _error == null
                  ? CircularProgressIndicator(color: g.accent)
                  : Padding(
                      padding: const EdgeInsets.all(60),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center, style: g.body(28)),
                        const SizedBox(height: 24),
                        TvButton(label: tr.done, icon: Icons.check, autofocus: true, onPressed: () => Navigator.of(context).pop()),
                      ]),
                    ))
          : YouTubePicker(
              subscriptions: subs,
              current: currentPicks(_app, widget.serverKey),
              others: others,
              busy: _busy,
              error: _error,
              onDone: (picks) => unawaited(_done(picks)),
            ),
    );
  }
}

/// [time] as the device shows clock times (12 or 24 hours).
String formatClock(BuildContext context, DateTime time) =>
    TimeOfDay.fromDateTime(time.toLocal()).format(context);
