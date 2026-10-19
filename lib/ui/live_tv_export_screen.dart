import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_scope.dart';
import '../export/export_service.dart';
import '../export/export_settings.dart';
import '../export/m3u_writer.dart';
import '../profiles/profile.dart';
import '../theme/tv_theme.dart';
import 'pin_dialog.dart';
import 'widgets/tv_focus.dart';

/// Live TV export: serve profiles' lineups to Plex, Jellyfin and IPTV apps.
class LiveTvExportScreen extends StatelessWidget {
  const LiveTvExportScreen({super.key});

  static const intro = 'Watch your channels in Plex, Jellyfin or any IPTV app on your home network. '
      'Nightingale TV has to stay open for them to play.';
  static const homeNetworkNotice = 'Anyone on your home network can watch this lineup.';
  static const discoveryUnavailable = "Automatic discovery isn't available on this PC. "
      'Add the tuner in Plex or Jellyfin by its address.';

  @override
  Widget build(BuildContext context) {
    final household = HouseholdScope.of(context);
    final service = household.export!;
    final g = context.guide;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final s = service.settings;
        Widget heading(String text) => Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 14),
              child: Text(text, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
            );
        Widget radio(String label, bool on, VoidCallback onPressed) => Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 10),
              child: TvToggle(label: label, radio: true, on: on, onPressed: onPressed),
            );
        return TvPage(
          title: 'Live TV export',
          hints: '▲▼ Move    OK Select    ESC Back',
          onBack: () => Navigator.of(context).pop(),
          child: FocusTraversalGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(100, 40, 100, 60),
              children: [
                SizedBox(width: 1200, child: Text(intro, style: g.body(28, color: g.textDim))),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TvToggle(
                    label: 'Live TV export',
                    on: s.enabled,
                    autofocus: true,
                    onPressed: () => service.setEnabled(!s.enabled),
                  ),
                ),
                if (s.enabled) ...[
                  heading('LINEUPS'),
                  for (final p in household.profiles) _ProfileExport(service: service, profile: p),
                  heading('QUALITY'),
                  Wrap(children: [
                    for (final q in ExportQuality.values) radio(q.label, s.quality == q, () => service.setQuality(q)),
                  ]),
                  heading('STREAMS AT ONCE'),
                  Wrap(children: [
                    radio('Automatic', s.streamLimit == null, () => service.setStreamLimit(null)),
                    for (final n in ExportSettings.streamLimitChoices)
                      radio('$n', s.streamLimit == n, () => service.setStreamLimit(n)),
                  ]),
                  Text('Now: ${service.streamLimit} at once. Each channel being watched elsewhere is one stream.',
                      style: g.body(24, color: g.textDim)),
                  heading('ENCODER'),
                  Wrap(children: [
                    radio('Automatic', s.encoder == ExportEncoderChoice.automatic,
                        () => service.setEncoder(ExportEncoderChoice.automatic)),
                    radio('Processor only', s.encoder == ExportEncoderChoice.processorOnly,
                        () => service.setEncoder(ExportEncoderChoice.processorOnly)),
                  ]),
                  Text('Encoder in use: ${service.encoderInUse?.label ?? 'checking…'}',
                      style: g.body(24, color: g.textDim)),
                  heading('DISCOVERY'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvToggle(
                      label: 'Let Plex find it automatically',
                      on: s.discovery,
                      onPressed: () => service.setDiscovery(!s.discovery),
                    ),
                  ),
                  if (service.discoveryUnavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(discoveryUnavailable, style: g.body(24, weight: FontWeight.w600, color: g.nowLine)),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One profile's toggle, address, links and status.
class _ProfileExport extends StatefulWidget {
  const _ProfileExport({required this.service, required this.profile});

  final ExportService service;
  final Profile profile;

  @override
  State<_ProfileExport> createState() => _ProfileExportState();
}

class _ProfileExportState extends State<_ProfileExport> {
  late final _port = TextEditingController(text: '${widget.service.settings.profiles[widget.profile.id]?.port ?? ''}');
  String? _portError;

  @override
  void dispose() {
    _port.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool exported) async {
    final p = widget.profile;
    if (!exported && p.hasPin) {
      final ok = await askPin(context, title: 'PIN for ${p.name}', check: p.checkPin);
      if (!ok) return;
    }
    await widget.service.setProfileExported(p.id, !exported);
    final port = widget.service.settings.profiles[p.id]?.port;
    if (port != null && mounted) setState(() => _port.text = '$port');
  }

  Future<void> _savePort() async {
    final port = int.tryParse(_port.text.trim());
    final problem = port == null
        ? 'Enter a port number.'
        : await widget.service.setPort(widget.profile.id, port);
    if (mounted) setState(() => _portError = problem);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final service = widget.service;
    final p = widget.profile;
    final exported = service.settings.isExported(p.id);
    final address = service.addressOf(p.id);
    final problem = service.problemText(p.id);
    final running = [for (final r in service.streams.running) if (r.profileId == p.id) r];
    Widget copy(String label, Uri url) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 160, child: Text(label, style: g.body(24, weight: FontWeight.w600))),
            Flexible(child: Text('$url', style: g.body(24))),
            const SizedBox(width: 24),
            TvButton(
              label: 'Copy',
              icon: Icons.copy,
              onPressed: () => Clipboard.setData(ClipboardData(text: '$url')),
            ),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TvToggle(
              label: '${p.name}${p.isKid ? ' (kid)' : ''}: export this lineup',
              on: exported,
              onPressed: () => _toggle(exported),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(LiveTvExportScreen.homeNetworkNotice, style: g.body(22, color: g.textDim)),
          ),
          if (exported && address != null) ...[
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(problem, style: g.body(24, weight: FontWeight.w600, color: g.nowLine)),
              ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy('Tuner', address),
                      copy('M3U', ExportUrls(address).m3u),
                      copy('XMLTV', ExportUrls(address).xmltv),
                      const SizedBox(height: 8),
                      Row(children: [
                        SizedBox(width: 260, child: TvTextField(controller: _port, label: 'Port', onSubmitted: (_) => _savePort())),
                        const SizedBox(width: 12),
                        TvButton(label: 'Save port', onPressed: _savePort),
                      ]),
                      if (_portError != null)
                        Text(_portError!, style: g.body(22, weight: FontWeight.w600, color: g.nowLine)),
                      const SizedBox(height: 8),
                      Text(
                        running.isEmpty
                            ? 'Not streaming. ${service.streams.running.length} of ${service.streamLimit} streams in use.'
                            : 'Streaming channel${running.length > 1 ? 's' : ''} '
                                '${running.map((r) => r.channel.number).join(', ')} to '
                                '${running.fold(0, (n, r) => n + r.viewers)} viewer(s). '
                                '${service.streams.running.length} of ${service.streamLimit} streams in use.',
                        style: g.body(24, color: g.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(g.radius * 2)),
                  child: QrImageView(data: '${ExportUrls(address).m3u}', size: 220, backgroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
