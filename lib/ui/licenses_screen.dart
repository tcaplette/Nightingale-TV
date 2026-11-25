import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/tv_theme.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import 'youtube_screens.dart' show LinkQr, YouTubeLinks;

/// Menu → Licences: the software the app is built with and each one's
/// licence, by D-pad, air mouse or touch (Flutter's own licence page isn't
/// made for a remote).
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  Map<String, List<String>>? _byPackage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final out = <String, List<String>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final text = entry.paragraphs.map((p) => '${'  ' * p.indent.clamp(0, 8)}${p.text}').join('\n\n');
      for (final p in entry.packages) {
        out.putIfAbsent(p, () => []).add(text);
      }
    }
    if (mounted) setState(() => _byPackage = Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()))));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final packages = _byPackage;
    return TvPage(
      title: tr.licencesTitle,
      hints: tr.moveOkSelectEscBack,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            Text(tr.licencesHelp, style: g.body(24, color: g.textDim)),
            const SizedBox(height: 20),
            // The privacy policy, always in reach, and the own-client guide
            // (youtube-subscriptions D14).
            Wrap(spacing: 32, runSpacing: 24, children: [
              LinkQr(url: YouTubeLinks.privacy, label: tr.privacyPolicy, short: YouTubeLinks.privacyShort, size: 140),
              LinkQr(url: YouTubeLinks.clientGuide, label: tr.ownClientTitle, short: YouTubeLinks.clientGuideShort, size: 140),
            ]),
            const SizedBox(height: 28),
            if (packages == null) Center(child: CircularProgressIndicator(color: g.accent)),
            for (final (i, e) in (packages?.entries ?? const <MapEntry<String, List<String>>>[]).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TvButton(
                  label: e.key,
                  expand: true,
                  autofocus: i == 0,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => _LicenseText(package: e.key, texts: e.value))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LicenseText extends StatelessWidget {
  const _LicenseText({required this.package, required this.texts});

  final String package;
  final List<String> texts;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    // Each part is a focus stop, so the D-pad scrolls through the text.
    final parts = [for (final t in texts) ...t.split('\n\n')];
    return TvPage(
      title: package,
      hints: tr.moveOkSelectEscBack,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            for (final (i, p) in parts.indexed)
              TvFocusable(
                autofocus: i == 0,
                onPressed: () {},
                builder: (context, focused) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: focused ? g.focus : Colors.transparent, width: 4)),
                  ),
                  child: Text(p, style: g.body(22, color: focused ? g.text : g.textDim)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
