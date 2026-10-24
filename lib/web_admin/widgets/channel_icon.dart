import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../channels/channel.dart';
import '../../icons/icon_catalog.dart';
import '../api_client.dart';
import '../app.dart';
import 'common.dart';

/// A channel's icon as the TV draws it: built-in icons and badges drawn
/// here, pictures (uploads, show logos, live source logos) from the setup
/// server.
class ChannelIconView extends StatelessWidget {
  const ChannelIconView(
      {super.key, required this.icon, required this.profileId, this.channelId, this.size = 40, this.fallbackText = 'TV'});

  final ChannelIcon icon;
  final String profileId;

  /// For a live source's logo, which only the channel can fetch.
  final String? channelId;
  final double size;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    Widget fallback() => StationBadge(text: _initials(fallbackText), shape: BadgeShape.roundedSquare, color: const Color(0xFFFFD23F), size: size);
    Widget picture(String url) => Image.network(url,
        fit: BoxFit.contain, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => fallback());
    final child = switch (icon.kind) {
      ChannelIconKind.builtin => Icon(iconForKey(icon.value), size: size * 0.82, color: Color(icon.color)),
      ChannelIconKind.badge => StationBadge(text: icon.value, shape: icon.shape, color: Color(icon.color), size: size),
      ChannelIconKind.custom => icon.value.endsWith('.svg')
          ? SvgPicture.network(api.href('profiles/$profileId/icons/${icon.value}'), fit: BoxFit.contain)
          : picture(api.href('profiles/$profileId/icons/${icon.value}')),
      ChannelIconKind.jellyfin => picture(api.href('profiles/$profileId/art/${icon.value}', {'kind': 'logo'})),
      ChannelIconKind.remote => channelId == null
          ? fallback()
          : picture(api.href('profiles/$profileId/channels/${Uri.encodeComponent(channelId!)}/logo')),
    };
    // On the TV's navy, as the guide shows them (yellow icons vanish on a
    // light page).
    return Semantics(
      label: 'Icon',
      child: Container(
        width: size * 1.6,
        height: size,
        padding: EdgeInsets.all(size * 0.06),
        decoration: BoxDecoration(color: const Color(0xFF0F2263), borderRadius: BorderRadius.circular(size * 0.15)),
        child: Center(child: child),
      ),
    );
  }

  static String _initials(String name) {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'TV';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 4));
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }
}

/// A generic station badge with call letters, as the TV draws it.
class StationBadge extends StatelessWidget {
  const StationBadge({super.key, required this.text, required this.shape, required this.color, required this.size});

  final String text;
  final BadgeShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > 0.5 ? const Color(0xFF0A1A4A) : Colors.white;
    final width = shape == BadgeShape.oval ? size : size * 0.9;
    final height = shape == BadgeShape.oval ? size * 0.6 : size * 0.9;
    final ShapeBorder border = switch (shape) {
      BadgeShape.roundedSquare => RoundedRectangleBorder(borderRadius: BorderRadius.circular(size * 0.18)),
      BadgeShape.circle => const CircleBorder(),
      BadgeShape.oval => const StadiumBorder(),
      BadgeShape.shield => BeveledRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(size * 0.4))),
    };
    return Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(color: color, shape: border),
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      alignment: shape == BadgeShape.shield ? const Alignment(0, -0.3) : Alignment.center,
      child: FittedBox(
        child: Text(text.toUpperCase(),
            maxLines: 1,
            style: TextStyle(
                fontFamily: 'BarlowCondensed', fontSize: size * 0.42, fontWeight: FontWeight.w800, color: onColor)),
      ),
    );
  }
}

/// Picks a channel icon: the built-in catalog with a colour, a badge
/// (call letters, shape, colour), a show's logo, or an uploaded picture.
/// Returns the icon chosen, or null.
Future<ChannelIcon?> pickIcon(BuildContext context, {required String profileId, required ChannelIcon current}) =>
    showDialog<ChannelIcon>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
          child: _IconPicker(profileId: profileId, current: current),
        ),
      ),
    );

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.profileId, required this.current});
  final String profileId;
  final ChannelIcon current;

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  late int _color = widget.current.kind == ChannelIconKind.builtin || widget.current.kind == ChannelIconKind.badge
      ? widget.current.color
      : iconColors.first;
  late BadgeShape _shape = widget.current.kind == ChannelIconKind.badge ? widget.current.shape : BadgeShape.roundedSquare;
  late final _badge = TextEditingController(text: widget.current.kind == ChannelIconKind.badge ? widget.current.value : '');
  List<Map<String, Object?>>? _shows;
  List<String>? _custom;
  String? _error;
  bool _uploading = false;

  ApiClient get api => context.api;

  @override
  void initState() {
    super.initState();
    _loadPictures();
  }

  Future<void> _loadPictures() async {
    try {
      final catalog = (await api.get('profiles/${widget.profileId}/library/catalog'))! as Map;
      final icons = (await api.get('profiles/${widget.profileId}/icons'))! as Map;
      if (!mounted) return;
      setState(() {
        _shows = [for (final s in (catalog['shows'] as List).cast<Map<String, Object?>>()) if (s['hasLogo'] == true) s];
        _custom = (icons['icons'] as List).cast<String>();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _upload() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'], mimeTypes: ['image/*']),
    ]);
    if (file == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 << 20) throw ApiException(413, 'That picture is too big (5 MB at most).');
      final r = (await api.upload('profiles/${widget.profileId}/icons', bytes, query: {'name': file.name}))! as Map;
      if (mounted) Navigator.of(context).pop(ChannelIcon(kind: ChannelIconKind.custom, value: r['name'] as String));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _choose(ChannelIcon icon) => Navigator.of(context).pop(icon);

  Widget _tile({required Widget child, required VoidCallback onTap, String? label, bool selected = false}) => Tooltip(
        message: label ?? '',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: label == null ? 64 : 140,
            height: label == null ? 64 : 96,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                  width: selected ? 3 : 1),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(child: Center(child: child)),
              if (label != null) Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );

  Widget _colors() => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in iconColors)
          Semantics(
            label: 'Colour',
            selected: c == _color,
            button: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: c == _color ? Theme.of(context).colorScheme.primary : Colors.black26, width: c == _color ? 4 : 1),
                ),
              ),
            ),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 4,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
          child: Row(children: [
            Expanded(child: Text('Choose an icon', style: text.titleLarge)),
            IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
        const TabBar(isScrollable: true, tabs: [
          Tab(text: 'Built-in'),
          Tab(text: 'Badges'),
          Tab(text: 'Show logos'),
          Tab(text: 'My icons'),
        ]),
        ErrorText(_error),
        Expanded(
          child: TabBarView(children: [
            ListView(padding: const EdgeInsets.all(16), children: [
              _colors(),
              for (final group in iconCatalog.entries) ...[
                const SizedBox(height: 16),
                Text(group.key, style: text.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in group.value.entries)
                    _tile(
                      label: null,
                      onTap: () => _choose(ChannelIcon.builtin(e.key, color: _color)),
                      selected: widget.current.kind == ChannelIconKind.builtin && widget.current.value == e.key,
                      child: Icon(e.value, size: 40, color: Color(_color), semanticLabel: e.key.replaceAll('_', ' ')),
                    ),
                ]),
              ],
            ]),
            ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                controller: _badge,
                maxLength: 5,
                decoration: const InputDecoration(labelText: 'Call letters (up to 5)'),
                onChanged: (_) => setState(() {}),
              ),
              Text('Shape', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in BadgeShape.values)
                  _tile(
                    onTap: () => setState(() => _shape = s),
                    selected: s == _shape,
                    child: StationBadge(text: 'TV', shape: s, color: Color(_color), size: 44),
                  ),
              ]),
              const SizedBox(height: 16),
              _colors(),
              const SizedBox(height: 16),
              Center(
                child: StationBadge(
                    text: _badge.text.trim().isEmpty ? 'TV' : _badge.text.trim(), shape: _shape, color: Color(_color), size: 120),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Use this badge'),
                  onPressed: () {
                    final typed = _badge.text.trim();
                    final value = typed.isEmpty ? 'TV' : typed;
                    _choose(ChannelIcon(
                        kind: ChannelIconKind.badge,
                        value: value.length > 5 ? value.substring(0, 5) : value,
                        color: _color,
                        shape: _shape));
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text('Generic badges only. Upload a real network logo under "My icons".', textAlign: TextAlign.center),
            ]),
            _shows == null
                ? const Center(child: CircularProgressIndicator())
                : _shows!.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('None of your shows have a logo image on your server.')))
                    : ListView(padding: const EdgeInsets.all(16), children: [
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final s in _shows!)
                            _tile(
                              label: s['name'] as String,
                              onTap: () => _choose(ChannelIcon(kind: ChannelIconKind.jellyfin, value: s['id'] as String)),
                              child: ChannelIconView(
                                icon: ChannelIcon(kind: ChannelIconKind.jellyfin, value: s['id'] as String),
                                profileId: widget.profileId,
                                fallbackText: s['name'] as String,
                              ),
                            ),
                        ]),
                      ]),
            ListView(padding: const EdgeInsets.all(16), children: [
              const Text('PNG, JPG, WebP, GIF or SVG. Big images are shrunk to 512 px automatically.'),
              const SizedBox(height: 8),
              Row(children: [
                FilledButton.icon(
                    icon: const Icon(Icons.upload), label: const Text('Upload image…'), onPressed: _uploading ? null : _upload),
                if (_uploading) const Padding(padding: EdgeInsets.only(left: 12), child: Busy(text: 'Uploading…')),
              ]),
              const SizedBox(height: 16),
              if (_custom != null)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final name in _custom!)
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      _tile(
                        onTap: () => _choose(ChannelIcon(kind: ChannelIconKind.custom, value: name)),
                        child: ChannelIconView(
                            icon: ChannelIcon(kind: ChannelIconKind.custom, value: name), profileId: widget.profileId),
                      ),
                      TextButton(
                        onPressed: () async {
                          final ok = await confirm(context,
                              title: 'Delete this icon?',
                              message: 'Channels using it go back to a built-in icon.',
                              action: 'Delete');
                          if (!ok || !context.mounted) return;
                          final r = await attempt(context, () => api.delete('profiles/${widget.profileId}/icons/$name'),
                              profileId: widget.profileId);
                          if (r is Map && mounted) setState(() => _custom = (r['icons'] as List).cast<String>());
                        },
                        child: const Text('Delete'),
                      ),
                    ]),
                ]),
            ]),
          ]),
        ),
      ]),
    );
  }
}
