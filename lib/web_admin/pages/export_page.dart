import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app.dart';
import '../widgets/common.dart';
import '../../l10n/tr.dart';

/// Live TV export (admin): each profile's export, port and URLs, and the
/// quality, stream limit, encoder and discovery. Status refreshes every 3
/// seconds while it's open.
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  Map<String, Object?>? _status, _settings;
  String? _error;
  Timer? _poll;
  final _ports = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load(statusOnly: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool statusOnly = false}) async {
    try {
      final api = context.api;
      final status = (await api.get('status'))! as Map<String, Object?>;
      final settings = statusOnly && _settings != null ? _settings : (await api.get('export'))! as Map<String, Object?>;
      if (!mounted) return;
      setState(() {
        _status = status;
        _settings = settings;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _put(String path, Map<String, Object?> body) async {
    final r = await attempt(context, () => context.api.put(path, body), onConflict: _load);
    if (r != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status, settings = _settings;
    if (status == null || settings == null) {
      return PageBody(title: tr.liveTvExport2, children: [
        if (_error == null) const Center(child: CircularProgressIndicator()) else ErrorText(_error),
      ]);
    }
    final profiles = (status['profiles'] as List).cast<Map<String, Object?>>();
    final limit = settings['streamLimit'] as int?;
    return PageBody(title: tr.liveTvExport2, children: [
      Section(children: [
        Text(tr.eachExportedProfile),
        const SizedBox(height: 8),
        Text(status['encoder'] == null ? tr.streamingNow('${status['streams']}') : tr.streamingNowEncoding('${status['streams']}', '${status['encoder']}')),
        if (status['discoveryMessage'] != null) Text(status['discoveryMessage'] as String),
      ]),
      for (final p in profiles) _profile(context, p),
      Section(title: tr.settings, children: [
        Text(tr.quality2, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [for (final q in (settings['qualities'] as List).cast<String>()) ButtonSegment(value: q, label: Text(q))],
          selected: {settings['quality'] as String},
          onSelectionChanged: (s) => _put('export', {'quality': s.single}),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          initialValue: limit,
          decoration: InputDecoration(
              labelText: tr.streamsAtOnce2,
              helperText: limit == null ? tr.automaticOnThis('${settings['streamLimitInUse']}') : null),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(tr.automatic)),
            for (var n = 1; n <= 16; n++) DropdownMenuItem<int?>(value: n, child: Text('$n')),
          ],
          onChanged: (v) => _put('export', {'streamLimit': v}),
        ),
        const SizedBox(height: 16),
        Text(tr.encoder2, style: Theme.of(context).textTheme.labelLarge),
        RadioGroup<String>(
          groupValue: settings['encoder'] as String,
          onChanged: (v) => _put('export', {'encoder': v}),
          child: Column(children: [
            for (final e in (settings['encoders'] as List).cast<Map>())
              RadioListTile<String>(
                  contentPadding: EdgeInsets.zero, value: e['id'] as String, title: Text(e['label'] as String)),
          ]),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr.discovery2),
          subtitle: Text(tr.letsPlexAnd),
          value: settings['discovery'] == true,
          onChanged: (v) => _put('export', {'discovery': v}),
        ),
      ]),
    ]);
  }

  Widget _profile(BuildContext context, Map<String, Object?> p) {
    final id = p['id'] as String;
    final exported = p['exported'] == true;
    final port = _ports.putIfAbsent(id, () => TextEditingController(text: '${p['port'] ?? ''}'));
    return Section(title: p['name'] as String, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(tr.exportThisProfile),
        value: exported,
        onChanged: (v) => _put('profiles/$id/export', {'exported': v}),
      ),
      if (exported) ...[
        Row(children: [
          Expanded(
            child: TextField(
              controller: port,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr.port),
              onSubmitted: (v) {
                final n = int.tryParse(v.trim());
                if (n != null) _put('profiles/$id/export', {'port': n});
              },
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              final n = int.tryParse(port.text.trim());
              if (n != null) _put('profiles/$id/export', {'port': n});
            },
            child: Text(tr.changePort),
          ),
        ]),
        if (p['url'] != null) ...[
          CopyField(label: tr.tunerAddress, value: p['url'] as String),
          CopyField(label: 'M3U', value: p['m3u'] as String),
          CopyField(label: tr.xmltv, value: p['xmltv'] as String),
        ],
      ],
      if (p['problem'] != null) ErrorText(p['problem'] as String),
    ]);
  }
}
