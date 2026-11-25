import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/tr.dart';
import '../../server/youtube/youtube_client_config.dart';
import '../../server/youtube/youtube_links.dart';
import '../api_client.dart';
import '../app.dart';
import '../browser.dart';
import '../widgets/common.dart';

/// YouTube on a profile in the web admin (docker-youtube D2, D3): the
/// user's own Google client, the code for google.com/device, the
/// subscription picker and the server colour, as on the TV.
///
/// [againKey]: a new client on that YouTube server (Google client, Sign in
/// again). [channelsOf]: only the picker for that server (Channels).
Future<void> youTubeDialog(BuildContext context, String profileId,
        {String? againKey, String? channelsOf, String? title}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: YouTubeSetup(
            profileId: profileId,
            againKey: againKey,
            channelsOf: channelsOf,
            title: title,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );

enum _Stage { client, code, picker, color, done }

/// The YouTube steps, inside a dialog (or the Add a server dialog).
class YouTubeSetup extends StatefulWidget {
  const YouTubeSetup({super.key, required this.profileId, this.againKey, this.channelsOf, this.title, required this.onClose});

  final String profileId;
  final String? againKey;
  final String? channelsOf;
  final String? title;
  final VoidCallback onClose;

  @override
  State<YouTubeSetup> createState() => _YouTubeSetupState();
}

class _YouTubeSetupState extends State<YouTubeSetup> {
  late _Stage _stage = widget.channelsOf == null ? _Stage.client : _Stage.picker;
  final _id = TextEditingController();
  final _secret = TextEditingController();
  final _search = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _closed = false;

  /// The sign-in under way, and the code shown.
  String? _run;
  Map<String, Object?>? _code;

  /// The YouTube server the picker and colour step work on.
  String? _key;
  Map<String, Object?>? _colorStep;
  String? _color;

  /// A first add: closing the picker before Done takes the server away, as
  /// Back on the TV's picker does.
  bool _firstAdd = false;

  List<Map<String, Object?>>? _subscriptions;
  Set<String> _checked = {};
  Set<String> _before = {};

  String get _base => 'profiles/${widget.profileId}';

  /// The API; read once, so waits that outlive a frame never look it up.
  late final ApiClient _api = context.api;

  @override
  void initState() {
    super.initState();
    _api;
    for (final c in [_id, _secret, _search]) {
      c.addListener(() => setState(() {}));
    }
    if (widget.channelsOf case final key?) {
      _key = key;
      unawaited(_loadSubscriptions());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _id.dispose();
    _secret.dispose();
    _search.dispose();
    super.dispose();
  }

  /// [call], asking for the profile's (or a grown-up's) PIN once when the
  /// server wants it; the refusal's message otherwise.
  Future<Object?> _call(Future<Object?> Function() call) async {
    for (var tries = 0; tries < 2; tries++) {
      try {
        return await call();
      } on ApiException catch (e) {
        if (tries == 0 && e.needs != null && e.needs != 'signIn' && mounted) {
          if (await unlock(context, widget.profileId, grownUp: e.needs == 'grownUp')) continue;
          throw ApiException(e.status, '');
        }
        rethrow;
      }
    }
    return null;
  }

  Future<void> _step(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } on ApiException catch (e) {
      if (mounted && e.message.isNotEmpty) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- The client step -------------------------------------------------------

  Future<void> _upload() async {
    final file = await openFile(acceptedTypeGroups: [const XTypeGroup(label: 'JSON', extensions: ['json'])]);
    if (file == null) return;
    GoogleClient? client;
    try {
      client = GoogleClient.fromDownload(jsonDecode(await file.readAsString()));
    } on Object {
      client = null;
    }
    if (!mounted) return;
    setState(() {
      if (client == null) {
        _error = tr.clientFileNotRead;
      } else {
        _id.text = client.id;
        _secret.text = client.secret;
        _error = null;
      }
    });
  }

  bool get _canContinue => _id.text.trim().isNotEmpty && _secret.text.trim().isNotEmpty && !_busy;

  Future<void> _start() => _step(() async {
        final body = {'clientId': _id.text.trim(), 'clientSecret': _secret.text.trim()};
        final again = widget.againKey;
        final r = (await _call(() => _api.post(
            again == null ? '$_base/youtube/start' : '$_base/servers/$again/youtube/client', body)))! as Map<String, Object?>;
        if (!mounted) return;
        setState(() {
          _run = r['run'] as String;
          _code = r;
          _stage = _Stage.code;
        });
        unawaited(_wait(r['run'] as String));
      });

  // ---- The code step ---------------------------------------------------------

  /// Waits for Google's answer, one long request after another.
  Future<void> _wait(String run) async {
    while (!_closed && _run == run && _stage == _Stage.code) {
      Map<String, Object?> r;
      try {
        r = (await _api.get('$_base/youtube/start/$run', {'code': '${_code?['userCode'] ?? ''}'}))!
            as Map<String, Object?>;
      } on ApiException catch (e) {
        if (_closed || _run != run) return;
        if (e.status == 404) {
          setState(() {
            _stage = _Stage.client;
            _error = tr.signInWasCancelled;
          });
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      if (_closed || _run != run || !mounted) return;
      switch (r['state']) {
        case 'expired':
          setState(() {
            _code = r;
            _error = r['error'] as String?;
          });
        case 'pending':
          if (r['error'] case final String error) setState(() => _error = error);
        case 'cancelled':
          setState(() {
            _run = null;
            _stage = _Stage.client;
            _error = r['error'] as String?;
          });
          return;
        case 'done':
          final key = r['serverKey'] as String;
          _colorStep = (r['color'] as Map?)?.cast<String, Object?>();
          if (widget.againKey != null) {
            setState(() => _stage = _Stage.done);
            return;
          }
          setState(() {
            _key = key;
            _firstAdd = key != 'main';
            _stage = _Stage.picker;
            _error = null;
          });
          await _loadSubscriptions();
          return;
      }
    }
  }

  Future<void> _cancelRun() async {
    final run = _run;
    _run = null;
    if (run != null) {
      try {
        await _api.delete('$_base/youtube/start/$run');
      } on ApiException {
        // Already over.
      }
    }
  }

  // ---- The picker ------------------------------------------------------------

  Future<void> _loadSubscriptions() => _step(() async {
        final r = (await _call(() => _api.get('$_base/servers/$_key/youtube/channels')))! as Map<String, Object?>;
        final subs = (r['subscriptions'] as List).cast<Map<String, Object?>>();
        if (!mounted) return;
        setState(() {
          _subscriptions = subs;
          _checked = {for (final s in subs) if (s['checked'] == true) s['id'] as String};
          _before = {..._checked};
        });
      });

  Future<void> _done() async {
    final subs = _subscriptions ?? const [];
    final removed = [
      for (final s in subs)
        if (_before.contains(s['id']) && !_checked.contains(s['id'])) '${s['title']}'
    ];
    if (removed.isNotEmpty) {
      final ok = await confirm(context,
          title: tr.youTubeChannelsTitle, message: tr.removeYouTubeChannels(joinNames(removed)), action: tr.remove);
      if (!ok || !mounted) return;
    }
    await _step(() async {
      await _call(() => _api.put('$_base/servers/$_key/youtube/channels', {
            'ids': [for (final s in subs) if (_checked.contains(s['id'])) s['id']],
          }));
      if (!mounted) return;
      _firstAdd = false;
      setState(() {
        _stage = _colorStep != null && widget.channelsOf == null ? _Stage.color : _Stage.done;
        _color = _colorStep?['selected'] as String?;
      });
      if (_stage == _Stage.done && widget.channelsOf != null) widget.onClose();
    });
  }

  // ---- The colour step -------------------------------------------------------

  Future<void> _chooseColor() => _step(() async {
        await _call(() => _api.post('$_base/youtube/start/$_run/color', {'name': _color}));
        _run = null;
        if (mounted) setState(() => _stage = _Stage.done);
      });

  Future<void> _close() async {
    _closed = true;
    switch (_stage) {
      case _Stage.code || _Stage.color:
        unawaited(_cancelRun());
      case _Stage.picker when _firstAdd && _key != null:
        // Left before Done on a first add: the sign-in goes, as on the TV.
        unawaited(_cancelRun());
        unawaited(_api.delete('$_base/servers/$_key').then((_) {}, onError: (Object _) {}));
      default:
        break;
    }
    widget.onClose();
  }

  // ---- Layout ----------------------------------------------------------------

  Widget _link(String label, String url) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(label),
          onPressed: () => openLink(url),
        ),
      );

  List<Widget> _clientStep(TextTheme text) => [
        Text(tr.ownClientTitle, style: text.titleLarge),
        const SizedBox(height: 12),
        for (final (i, s) in [
          tr.ownClientStep1,
          tr.ownClientStep2,
          tr.ownClientStep3,
          tr.ownClientStep4,
          tr.ownClientStep5,
          tr.ownClientStep6,
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 24, child: Text('${i + 1}.')),
              Expanded(child: Text(s)),
            ]),
          ),
        _link(tr.ownClientGuide(YouTubeAddresses.clientGuideShort), YouTubeAddresses.clientGuide),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('client-id'),
          controller: _id,
          autofocus: true,
          decoration: InputDecoration(labelText: tr.clientId),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('client-secret'),
          controller: _secret,
          obscureText: true,
          decoration: InputDecoration(labelText: tr.clientSecret),
          onSubmitted: (_) {
            if (_canContinue) unawaited(_start());
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            key: const ValueKey('upload-client'),
            icon: const Icon(Icons.upload_file),
            label: Text(tr.uploadJsonFile),
            onPressed: _busy ? null : _upload),
        const SizedBox(height: 8),
        FilledButton(
            key: const ValueKey('client-continue'),
            onPressed: _canContinue ? _start : null,
            child: Text(tr.continueStep)),
      ];

  List<Widget> _codeStep(TextTheme text) {
    final code = _code ?? const {};
    return [
      Text(tr.youTube, style: text.titleLarge),
      const SizedBox(height: 8),
      Text(tr.youTubeTerms),
      Wrap(children: [
        _link(tr.youTubeTermsOfService, YouTubeAddresses.terms),
        _link(tr.privacyPolicy, YouTubeAddresses.privacy),
      ]),
      const SizedBox(height: 8),
      Text(tr.youTubeEnterCode(YouTubeAddresses.deviceShort)),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SelectableText('${code['userCode'] ?? ''}',
              key: const ValueKey('youtube-code'),
              // Screen readers read the code too.
              semanticsLabel: '${code['userCode'] ?? ''}',
              style: text.displaySmall?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w700)),
        ),
      ),
      Row(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(6),
          child: QrImageView(data: YouTubeAddresses.device, size: 112, padding: EdgeInsets.zero, backgroundColor: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _link(tr.openGoogleDevice, YouTubeAddresses.device),
            Text(tr.waitingForThe),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      OutlinedButton(
        key: const ValueKey('code-cancel'),
        onPressed: () async {
          await _cancelRun();
          if (mounted) setState(() => _stage = _Stage.client);
        },
        child: Text(tr.cancel),
      ),
    ];
  }

  List<Widget> _pickerStep(TextTheme text) {
    final subs = _subscriptions;
    final query = _search.text.trim().toLowerCase();
    final rows = [
      for (final s in subs ?? const <Map<String, Object?>>[])
        if (query.isEmpty || '${s['title']}'.toLowerCase().contains(query)) s
    ];
    return [
      Text(tr.youTubeChannelsTitle, style: text.titleLarge),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('subscription-search'),
        controller: _search,
        decoration: InputDecoration(labelText: tr.searchSubscriptions, prefixIcon: const Icon(Icons.search)),
      ),
      const SizedBox(height: 8),
      FilledButton(
          key: const ValueKey('picker-done'), onPressed: _busy || subs == null ? null : _done, child: Text(tr.done)),
      const SizedBox(height: 8),
      if (subs != null && rows.isEmpty) Text(subs.isEmpty ? tr.noSubscriptions : tr.noSubscriptionsMatch),
      // Only the rows on screen are built, so an account with hundreds of
      // subscriptions doesn't fetch every avatar at once.
      if (rows.isNotEmpty)
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.5).clamp(220.0, 520.0),
          child: ListView.builder(
            key: const ValueKey('subscriptions'),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final s = rows[i];
              return CheckboxListTile(
                key: ValueKey('sub-${s['id']}'),
                contentPadding: EdgeInsets.zero,
                value: _checked.contains(s['id']),
                onChanged: _busy
                    ? null
                    : (v) => setState(() => v == true ? _checked.add(s['id'] as String) : _checked.remove(s['id'])),
                secondary: _Avatar(profileId: widget.profileId, url: s['avatar'] as String?, title: '${s['title']}'),
                title: Text('${s['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: s['subscribed'] == false ? Text(tr.notSubscribed) : null,
              );
            },
          ),
        ),
    ];
  }

  List<Widget> _colorStepView(TextTheme text) {
    final color = _colorStep ?? const {};
    final palette = (color['palette'] as List? ?? const []).cast<Map>();
    return [
      Text(tr.guideColorTitle('${color['name'] ?? ''}'), style: text.titleLarge),
      Text(tr.guideColorHelp, style: text.bodySmall),
      const SizedBox(height: 12),
      RadioGroup<String>(
        groupValue: _color,
        onChanged: (v) {
          if (!_busy) setState(() => _color = v);
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
          onPressed: _busy || _color == null ? null : _chooseColor,
          child: Text(tr.done)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final children = switch (_stage) {
      _Stage.client => _clientStep(text),
      _Stage.code => _codeStep(text),
      _Stage.picker => _pickerStep(text),
      _Stage.color => _colorStepView(text),
      _Stage.done => [
          Text(tr.done, style: text.titleMedium),
          const SizedBox(height: 8),
          Text(tr.theLibraryIs),
          const SizedBox(height: 16),
          FilledButton(key: const ValueKey('youtube-finished'), onPressed: widget.onClose, child: Text(tr.done)),
        ],
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        key: ValueKey('youtube-${_stage.name}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(widget.title ?? tr.youTube, style: text.labelLarge)),
            IconButton(tooltip: tr.close, icon: const Icon(Icons.close), onPressed: _close),
          ]),
          ...children,
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          ErrorText(_error),
        ]),
      ),
    );
  }
}

/// A subscription's avatar, fetched through the server.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profileId, required this.url, required this.title});
  final String profileId;
  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final initial = CircleAvatar(radius: 20, child: Text(title.isEmpty ? '?' : title.characters.first));
    final u = url;
    if (u == null) return initial;
    return ClipOval(
      child: Image.network(context.api.href('profiles/$profileId/youtube/avatar', {'url': u}),
          width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => initial),
    );
  }
}
