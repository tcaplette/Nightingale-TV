import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_scope.dart';
import '../remote/remote_control.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'menu_screen.dart' show confirm;
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// Turn the phone remote on or off, pair phones, and show whether phones can
/// reach it (remote-setup). Phones can pair only while this screen is open.
class PhoneRemoteScreen extends StatefulWidget {
  const PhoneRemoteScreen({super.key});

  /// What the QR code opens: the remote with the pairing code in the
  /// fragment, which never reaches the server.
  static String qrData(Uri url, String? code) =>
      code == null ? '$url' : '${url.replace(path: '/', fragment: 'pair=$code')}';

  @override
  State<PhoneRemoteScreen> createState() => _PhoneRemoteScreenState();
}

class _PhoneRemoteScreenState extends State<PhoneRemoteScreen> {
  late final RemoteControl _remote = HouseholdScope.read(context).remote!;

  /// Android closes pairing when the app is hidden; it opens again here.
  late final _lifecycle = AppLifecycleListener(onShow: () => _remote.openPairing());

  @override
  void initState() {
    super.initState();
    _lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _remote.openPairing();
      _remote.checkFirewall();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _remote.closePairing();
    super.dispose();
  }

  Future<void> _removeAll() async {
    final ok = await confirm(context,
        title: tr.removeAllPhones,
        message: tr.everyPairedPhone,
        action: tr.removeAll);
    if (ok) await _remote.removeAllPairings();
  }

  @override
  Widget build(BuildContext context) {
    final remote = _remote;
    final g = context.guide;
    return ListenableBuilder(
      listenable: remote,
      builder: (context, _) {
        final url = remote.url;
        final running = remote.error == null && url != null;
        final blocked = running && remote.status == RemoteStatus.blocked;
        final code = remote.pairingCode;
        return TvPage(
          title: tr.phoneRemote,
          hints: tr.moveOkSelectEsc,
          onBack: () => Navigator.of(context).pop(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(120, 48, 120, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.useYourPhoneAs,
                            style: g.body(30, color: g.textDim),
                          ),
                          const SizedBox(height: 36),
                          FocusTraversalGroup(
                            child: Wrap(
                              spacing: 12,
                              children: [
                                TvToggle(
                                  label: tr.onLabel2,
                                  radio: true,
                                  autofocus: true,
                                  on: remote.enabled,
                                  onPressed: () => remote.setEnabled(true),
                                ),
                                TvToggle(
                                  label: tr.off,
                                  radio: true,
                                  on: !remote.enabled,
                                  onPressed: () => remote.setEnabled(false),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),
                          if (remote.error != null)
                            Text(remote.error!, style: g.body(28, weight: FontWeight.w600, color: g.nowLine))
                          else if (url != null) ...[
                            _StatusLine(remote: remote),
                            const SizedBox(height: 28),
                            if (blocked) ...[
                              _BlockedSteps(remote: remote),
                              const SizedBox(height: 36),
                            ],
                            Opacity(
                              opacity: blocked ? 0.3 : 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr.onYourPhoneOpen,
                                      style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                                  const SizedBox(height: 8),
                                  Text('$url', style: g.display(64, weight: FontWeight.w800)),
                                  if (code != null) ...[
                                    const SizedBox(height: 12),
                                    Text.rich(TextSpan(children: [
                                      TextSpan(text: tr.andEnter, style: g.body(28, color: g.textDim)),
                                      TextSpan(
                                          text: '${code.substring(0, 3)} ${code.substring(3)}',
                                          style: g.display(48, weight: FontWeight.w800, color: g.accent)),
                                    ])),
                                  ],
                                  const SizedBox(height: 12),
                                  Text(tr.orScanThe,
                                      style: g.body(26, color: g.textDim)),
                                ],
                              ),
                            ),
                            if (!blocked) ...[
                              const SizedBox(height: 28),
                              _Tips(remote: remote),
                            ],
                          ] else
                            Text(tr.theRemoteIs, style: g.body(28, color: g.textDim)),
                        ],
                      ),
                    ),
                    if (running) ...[
                      const SizedBox(width: 80),
                      _Qr(data: PhoneRemoteScreen.qrData(url, code), blocked: blocked),
                    ],
                  ],
                ),
                const SizedBox(height: 56),
                _PairedPhones(remote: remote, onRemoveAll: _removeAll),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.remote});

  final RemoteControl remote;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final (color, text) = switch (remote.status) {
      RemoteStatus.working => (
          const Color(0xFF3DDC84),
          switch (remote.pairings.firstOrNull) {
            final p? => tr.workingLastUsed(p.name, formatTime(p.lastUsed)),
            null => tr.working,
          }
        ),
      RemoteStatus.notConfirmed => (const Color(0xFFFFB020), tr.notConfirmedYet),
      RemoteStatus.blocked => (g.nowLine, tr.blockedByThis),
    };
    return Row(children: [
      Container(width: 22, height: 22, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 16),
      Flexible(child: Text(text, style: g.body(30, weight: FontWeight.w700))),
    ]);
  }
}

/// A command to type in a terminal, in a monospace box.
class _Command extends StatelessWidget {
  const _Command(this.command);

  final String command;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(g.radius),
        border: Border.all(color: g.cellBorder, width: 2),
      ),
      child: Text(command,
          style: TextStyle(fontFamily: 'monospace', fontSize: 26, color: g.text, fontWeight: FontWeight.w600)),
    );
  }
}

class _BlockedSteps extends StatelessWidget {
  const _BlockedSteps({required this.remote});

  final RemoteControl remote;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final command = remote.fixCommand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.thisComputersFirewall,
          style: g.body(28, color: g.textDim),
        ),
        if (command != null) ...[
          const SizedBox(height: 16),
          _Command(command),
        ],
        const SizedBox(height: 16),
        Text(tr.thenChooseCheck, style: g.body(28, color: g.textDim)),
        const SizedBox(height: 24),
        TvButton(label: tr.checkAgain, icon: Icons.refresh, onPressed: remote.checkFirewall),
      ],
    );
  }
}

/// Not confirmed yet: what usually keeps a phone from connecting.
class _Tips extends StatelessWidget {
  const _Tips({required this.remote});

  final RemoteControl remote;

  @override
  Widget build(BuildContext context) {
    if (remote.status == RemoteStatus.working) return const SizedBox.shrink();
    final g = context.guide;
    final command = remote.fixCommand;
    final tips = <Widget>[
      if (command != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.ifThePhone, style: g.body(26, color: g.textDim)),
            const SizedBox(height: 12),
            _Command(command),
          ],
        ),
      Text(tr.thePhoneHas,
          style: g.body(26, color: g.textDim)),
      Text(tr.someWiFi, style: g.body(26, color: g.textDim)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, tip) in tips.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 40, child: Text('${i + 1}.', style: g.body(26, weight: FontWeight.w700, color: g.accent))),
            Expanded(child: tip),
          ]),
        ],
      ],
    );
  }
}

class _Qr extends StatelessWidget {
  const _Qr({required this.data, required this.blocked});

  final String data;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: blocked ? 0.3 : 1,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(g.radius * 2)),
            child: QrImageView(key: ValueKey(data), data: data, size: 420, backgroundColor: Colors.white),
          ),
        ),
        if (blocked)
          Container(
            width: 400,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: g.nowLine, borderRadius: BorderRadius.circular(g.radius)),
            child: Text(tr.blockedByThis,
                textAlign: TextAlign.center, style: g.display(30, weight: FontWeight.w800)),
          ),
      ],
    );
  }
}

class _PairedPhones extends StatelessWidget {
  const _PairedPhones({required this.remote, required this.onRemoveAll});

  final RemoteControl remote;
  final VoidCallback onRemoveAll;

  static const _actionWidth = 340.0;

  /// A row's Remove button from the list's right edge (padding and border).
  static const _rowInset = 16.0;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final phones = remote.pairings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.pairedPhones, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 16),
        if (phones.isEmpty)
          Text(tr.noPhonesPaired, style: g.body(28, color: g.textDim))
        else ...[
          for (final p in phones)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 14, _rowInset - 2, 14),
                decoration: BoxDecoration(
                  color: g.cell,
                  borderRadius: BorderRadius.circular(g.radius * 2),
                  border: Border.all(color: g.cellBorder, width: 2),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: g.display(32, weight: FontWeight.w700)),
                      Text(tr.pairedLastUsed(formatMoment(p.paired), formatRecent(p.lastUsed)),
                          style: g.body(24, color: g.textDim)),
                    ]),
                  ),
                  SizedBox(
                    width: _actionWidth,
                    child: TvButton(label: tr.remove, expand: true, onPressed: () => remote.removePairing(p.id)),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          // Lined up under the Remove buttons (same width, same edges), so
          // ▼ walks down one column from anywhere above.
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: _rowInset),
              child: SizedBox(
                width: _actionWidth,
                child: TvButton(label: tr.removeAll, danger: true, expand: true, onPressed: onRemoveAll),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
