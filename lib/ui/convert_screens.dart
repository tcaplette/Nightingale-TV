import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../convert/convert_helper.dart';
import '../convert/convert_helpers.dart';
import '../l10n/tr.dart';
import '../server/smb/smb_server.dart';
import '../theme/tv_theme.dart';
import 'channel_groups_screen.dart' show askName;
import 'menu_screen.dart' show showMessage;
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// Menu → Convert for other TVs, on the Linux app (smb-conversion D9):
/// on or off, the pairing code, and the paired TVs.
class ConvertForOthersScreen extends StatelessWidget {
  const ConvertForOthersScreen({super.key, required this.helper});

  final ConvertHelper helper;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return ListenableBuilder(
      listenable: helper,
      builder: (context, _) => TvPage(
        title: tr.convertForOthers,
        hints: tr.moveOkSelectEscBack,
        onBack: () => Navigator.of(context).pop(),
        child: FocusTraversalGroup(
          child: ListView(
            padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
            children: [
              Text(tr.convertForOthersHelp, style: g.body(24, color: g.textDim)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: TvToggle(label: tr.convertForOthers, on: helper.on, autofocus: true, onPressed: () => helper.setOn(!helper.on)),
              ),
              if (helper.code case final code? when helper.on) ...[
                const SizedBox(height: 24),
                Text(tr.convertCode(code), style: g.display(56, weight: FontWeight.w800, color: g.accent)),
              ],
              const SizedBox(height: 28),
              Text(tr.convertPairedTvs, style: g.display(36)),
              const SizedBox(height: 12),
              if (helper.pairings.isEmpty) Text(tr.convertNoTvs, style: g.body(24, color: g.textDim)),
              for (final p in helper.pairings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Expanded(child: Text(p.name, style: g.body(28))),
                    TvButton(label: tr.remove, icon: Icons.delete, danger: true, onPressed: () => helper.removePairing(p.id)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Servers → Convert on other Nightingale TVs: the helpers this device is
/// paired with, finding and pairing one, and the shares one still lacks.
class ConvertHelpersScreen extends StatefulWidget {
  const ConvertHelpersScreen({super.key});

  @override
  State<ConvertHelpersScreen> createState() => _ConvertHelpersScreenState();
}

class _ConvertHelpersScreenState extends State<ConvertHelpersScreen> {
  List<({Uri url, String name, String id})>? _found;
  bool _busy = false;
  final _missing = <String, List<String>>{};
  final _down = <String>{};

  ConvertHelpers get _helpers => HouseholdScope.read(context).convertHelpers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  /// Which of this profile's shares each helper lacks.
  Future<void> _check() async {
    final app = AppScope.read(context);
    final shares = {
      for (final s in app.servers.all)
        if (s.client case final SmbServer share) share.serverId: s.name
    };
    for (final h in _helpers.helpers) {
      final info = await _helpers.info(h, fresh: true);
      if (!mounted) return;
      setState(() {
        if (info == null) {
          _down.add(h.id);
        } else {
          _down.remove(h.id);
          _missing[h.id] = [for (final e in shares.entries) if (!info.shares.contains(e.key)) e.value];
        }
      });
    }
  }

  Future<void> _find() async {
    setState(() => _busy = true);
    final found = await _helpers.find();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _found = found;
    });
    if (found.isEmpty) await showMessage(context, title: tr.convertFind, message: tr.convertNoneFound);
  }

  Future<void> _pair(Uri url, String name) async {
    final code = await askName(context, title: tr.convertEnterCode(name), action: tr.convertPair);
    if (code == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await _helpers.pair(url, code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _found = null;
    });
    if (!ok) {
      await showMessage(context, title: tr.convertHelpers, message: tr.convertWrongCode(name));
    } else {
      await _check();
    }
  }

  Future<void> _typed() async {
    final typed = await askName(context, title: tr.convertAddress, action: tr.connect);
    final url = typed == null ? null : ConvertHelpers.parseAddress(typed);
    if (url == null || !mounted) return;
    final about = await _helpers.about(url);
    if (!mounted) return;
    if (about == null) {
      await showMessage(context, title: tr.convertHelpers, message: tr.convertNoneFound);
      return;
    }
    await _pair(about.url, about.name);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return ListenableBuilder(
      listenable: _helpers,
      builder: (context, _) => TvPage(
        title: tr.convertHelpers,
        hints: tr.moveOkSelectEscBack,
        onBack: () => Navigator.of(context).pop(),
        child: FocusTraversalGroup(
          child: ListView(
            padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
            children: [
              Text(tr.convertHelpersHelp, style: g.body(24, color: g.textDim)),
              const SizedBox(height: 20),
              Wrap(spacing: 16, runSpacing: 14, children: [
                TvButton(label: tr.convertFind, icon: Icons.search, autofocus: true, onPressed: _busy ? null : _find),
                TvButton(label: tr.convertTypeAddress, icon: Icons.keyboard, onPressed: _busy ? null : _typed),
              ]),
              if (_busy) ...[const SizedBox(height: 16), Center(child: CircularProgressIndicator(color: g.accent))],
              for (final f in _found ?? const <({Uri url, String name, String id})>[])
                if (!_helpers.helpers.any((h) => h.id == f.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TvButton(label: '${tr.convertPair}: ${f.name}', icon: Icons.link, onPressed: () => _pair(f.url, f.name)),
                  ),
              const SizedBox(height: 28),
              for (final h in _helpers.helpers)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: g.panel,
                      borderRadius: BorderRadius.circular(g.radius * 2),
                      border: Border.all(color: g.cellBorder, width: 2)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.name, style: g.display(36, weight: FontWeight.w800)),
                    Text('${h.url.host}:${h.url.port}', style: g.body(22, color: g.textDim)),
                    if (_down.contains(h.id)) Text(tr.convertNotAnswering(h.name), style: g.body(22, color: g.nowLine)),
                    for (final share in _missing[h.id] ?? const <String>[])
                      Text(tr.convertAddShareOn(share, h.name), style: g.body(22, color: g.accent)),
                    const SizedBox(height: 12),
                    TvButton(label: tr.remove, icon: Icons.delete, danger: true, onPressed: () => _helpers.remove(h.id)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
