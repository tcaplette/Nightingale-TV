import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../channels/channel.dart';
import '../icons/custom_icons.dart';
import '../icons/icon_catalog.dart';
import '../platform/device_images.dart';
import '../platform/platform_info.dart';
import 'device_image_picker_screen.dart';
import '../theme/tv_theme.dart';
import 'menu_screen.dart';
import 'widgets/channel_logo.dart';
import 'widgets/tv_focus.dart';

enum _Tab {
  builtin('Built-in', Icons.apps),
  badges('Badges', Icons.badge),
  shows('Show logos', Icons.live_tv),
  mine('My icons', Icons.upload_file);

  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Pick a channel icon. Pops with the chosen [ChannelIcon].
class IconPickerScreen extends StatefulWidget {
  const IconPickerScreen({super.key, required this.channel});

  final Channel channel;

  @override
  State<IconPickerScreen> createState() => _IconPickerScreenState();
}

class _IconPickerScreenState extends State<IconPickerScreen> {
  _Tab _tab = _Tab.builtin;
  late int _color = widget.channel.icon.kind == ChannelIconKind.builtin ||
          widget.channel.icon.kind == ChannelIconKind.badge
      ? widget.channel.icon.color
      : iconColors.first;
  BadgeShape _shape = BadgeShape.roundedSquare;
  late final _badgeText = TextEditingController(
    text: widget.channel.icon.kind == ChannelIconKind.badge
        ? widget.channel.icon.value
        : _callLetters(widget.channel.name),
  );
  List<String> _custom = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.channel.icon.kind == ChannelIconKind.badge) _shape = widget.channel.icon.shape;
    _loadCustom();
  }

  @override
  void dispose() {
    _badgeText.dispose();
    super.dispose();
  }

  Future<void> _loadCustom() async {
    final list = await AppScope.read(context).icons.list();
    if (mounted) setState(() => _custom = list);
  }

  void _choose(ChannelIcon icon) => Navigator.of(context).pop(icon);

  Future<void> _upload() async {
    setState(() => _error = null);
    try {
      final icons = AppScope.read(context).icons;
      final name = PlatformInfo.isAndroid && !await DeviceImages.hasDocumentPicker()
          ? await _pickOnDevice(icons)
          : await icons.pickAndImport();
      if (name == null) return;
      await _loadCustom();
      _choose(ChannelIcon(kind: ChannelIconKind.custom, value: name));
    } on CustomIconException catch (e) {
      setState(() => _error = e.message);
    }
  }

  /// Android TVs have no document picker: choose from the device's own
  /// pictures in the app instead.
  Future<String?> _pickOnDevice(CustomIconStore icons) async {
    final image = await Navigator.of(context)
        .push<DeviceImage>(MaterialPageRoute(builder: (_) => const DeviceImagePickerScreen()));
    if (image == null) return null;
    final Uint8List bytes;
    try {
      bytes = await DeviceImages.read(image, limit: CustomIconStore.maxSourceBytes);
    } on PlatformException {
      throw CustomIconException('Couldn\'t read that picture. Try another one.');
    }
    return icons.importBytes(bytes, image.name);
  }

  static String _callLetters(String name) {
    final words = name.split(RegExp(r'[\s&]+')).where((w) => w.isNotEmpty).toList();
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 4)).toUpperCase();
    return words.take(4).map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvPage(
      title: 'Icon for ${widget.channel.name}',
      hints: '◀▶▲▼ Move    OK Choose    ESC Cancel',
      onBack: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(80, 28, 80, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FocusTraversalGroup(
              child: Row(
                children: [
                  for (final t in _Tab.values) ...[
                    _TabButton(
                      tab: t,
                      selected: t == _tab,
                      autofocus: t == _Tab.builtin,
                      onSelected: () => setState(() => _tab = t),
                    ),
                    const SizedBox(width: 14),
                  ],
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: g.body(26, color: g.nowLine)),
              ),
            const SizedBox(height: 24),
            Expanded(child: FocusTraversalGroup(child: _body(context))),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (_tab) {
      case _Tab.builtin:
        return ListView(
          children: [
            _ColorRow(selected: _color, onSelected: (c) => setState(() => _color = c)),
            for (final group in iconCatalog.entries) ...[
              const SizedBox(height: 20),
              _SectionTitle(group.key),
              _TileWrap(children: [
                for (final entry in group.value.entries)
                  _IconTile(
                    onPressed: () => _choose(ChannelIcon.builtin(entry.key, color: _color)),
                    child: Icon(entry.value, size: 76, color: Color(_color)),
                  ),
              ]),
            ],
          ],
        );
      case _Tab.badges:
        final g = context.guide;
        return ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 560,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TvTextField(controller: _badgeText, label: 'Call letters (up to 5)'),
                      const SizedBox(height: 24),
                      _SectionTitle('Shape'),
                      Wrap(spacing: 14, runSpacing: 14, children: [
                        for (final s in BadgeShape.values)
                          _IconTile(
                            selected: s == _shape,
                            onPressed: () => setState(() => _shape = s),
                            child: StationBadge(text: 'TV', shape: s, color: Color(_color), size: 96),
                          ),
                      ]),
                      const SizedBox(height: 24),
                      _ColorRow(selected: _color, onSelected: (c) => setState(() => _color = c)),
                    ],
                  ),
                ),
                const SizedBox(width: 80),
                Expanded(
                  child: Column(
                    children: [
                      _SectionTitle('Preview'),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: _badgeText,
                        builder: (context, _) => StationBadge(
                          text: _badgeText.text.trim().isEmpty ? 'TV' : _badgeText.text.trim(),
                          shape: _shape,
                          color: Color(_color),
                          size: 280,
                        ),
                      ),
                      const SizedBox(height: 40),
                      TvButton(
                        label: 'Use this badge',
                        icon: Icons.check,
                        onPressed: () {
                          final typed = _badgeText.text.trim();
                          final text = typed.isEmpty ? 'TV' : typed;
                          _choose(ChannelIcon(
                            kind: ChannelIconKind.badge,
                            value: text.length > 5 ? text.substring(0, 5) : text,
                            color: _color,
                            shape: _shape,
                          ));
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Generic badges only. Upload a real network logo under "My icons".',
                          textAlign: TextAlign.center, style: g.body(22, color: g.textDim)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      case _Tab.shows:
        final app = AppScope.read(context);
        final shows = app.library.series.where((s) => s.hasLogo).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (shows.isEmpty) return _Empty('None of your shows have a logo image in Jellyfin.');
        return ListView(children: [
          _TileWrap(children: [
            for (final s in shows)
              _IconTile(
                wide: true,
                label: s.name,
                onPressed: () => _choose(ChannelIcon(kind: ChannelIconKind.jellyfin, value: s.id)),
                child: ChannelLogo(
                  icon: ChannelIcon(kind: ChannelIconKind.jellyfin, value: s.id),
                  size: 150,
                  fallbackText: s.name,
                ),
              ),
          ]),
        ]);
      case _Tab.mine:
        final app = AppScope.read(context);
        final g = context.guide;
        return ListView(children: [
          Text('PNG, JPG, WebP, GIF or SVG. Big images are shrunk to 512 px automatically.',
              style: g.body(24, color: g.textDim)),
          const SizedBox(height: 20),
          _TileWrap(children: [
            _IconTile(
              label: 'Upload image…',
              onPressed: _upload,
              child: Icon(Icons.add_photo_alternate, size: 76, color: g.accent),
            ),
            for (final name in _custom)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconTile(
                    onPressed: () => _choose(ChannelIcon(kind: ChannelIconKind.custom, value: name)),
                    child: ChannelLogo(
                      icon: ChannelIcon(kind: ChannelIconKind.custom, value: name),
                      size: 120,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TvFocusable(
                    onPressed: () async {
                      final ok = await confirm(context,
                          title: 'Delete this icon?',
                          message: 'Channels using it go back to a default icon.',
                          action: 'Delete');
                      if (!ok) return;
                      await app.deleteCustomIcon(name);
                      await _loadCustom();
                    },
                    builder: (context, focused) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: focused ? g.nowLine : Colors.transparent,
                        borderRadius: BorderRadius.circular(g.radius),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_outline, size: 22, color: focused ? Colors.white : g.textDim),
                        const SizedBox(width: 6),
                        Text('Delete', style: g.body(20, color: focused ? Colors.white : g.textDim)),
                      ]),
                    ),
                  ),
                ],
              ),
          ]),
        ]);
    }
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.selected, required this.onSelected, this.autofocus = false});

  final _Tab tab;
  final bool selected;
  final VoidCallback onSelected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvFocusable(
      autofocus: autofocus,
      onPressed: onSelected,
      // Moving onto a tab switches to it, like TV apps.
      onFocusChanged: (f) {
        if (f && !selected) onSelected();
      },
      builder: (context, focused) {
        final fg = focused ? g.onFocus : (selected ? g.accent : g.text);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: focused ? g.focus : (selected ? g.cellBorder : g.cell),
            borderRadius: BorderRadius.circular(g.radius * 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(tab.icon, size: 30, color: fg),
            const SizedBox(width: 12),
            Text(tab.label, style: g.display(30, weight: FontWeight.w700, color: fg)),
          ]),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text.toUpperCase(), style: g.display(26, weight: FontWeight.w800, color: g.accent)),
    );
  }
}

class _TileWrap extends StatelessWidget {
  const _TileWrap({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 14, children: children);
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.child, required this.onPressed, this.label, this.selected = false, this.wide = false});

  final Widget child;
  final VoidCallback onPressed;
  final String? label;
  final bool selected;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvFocusable(
      onPressed: onPressed,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: wide ? 260 : 140,
        height: label == null ? 140 : 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: focused ? g.cellBorder : g.cell,
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(
            color: focused ? g.focus : (selected ? g.accent : Colors.transparent),
            width: focused ? 5 : 3,
          ),
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: child)),
            if (label != null)
              Text(label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: g.body(20, color: focused ? g.text : g.textDim)),
          ],
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Color'),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final c in iconColors)
            TvFocusable(
              onPressed: () => onSelected(c),
              builder: (context, focused) => Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: focused ? context.guide.focus : (c == selected ? Colors.white : Colors.black26),
                    width: focused || c == selected ? 5 : 2,
                  ),
                ),
                child: c == selected ? const Icon(Icons.check, color: Colors.black54, size: 32) : null,
              ),
            ),
        ]),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(message, style: context.guide.body(28, color: context.guide.textDim)));
}
