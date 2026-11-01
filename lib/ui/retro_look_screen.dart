import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../channels/channel.dart';
import '../icons/custom_icons.dart';
import '../platform/device_images.dart';
import '../platform/platform_info.dart';
import '../playback/device_effects.dart';
import '../theme/tv_theme.dart';
import 'device_image_picker_screen.dart';
import 'menu_screen.dart';
import 'widgets/broadcast_cards.dart';
import 'widgets/crt_effects.dart';
import 'widgets/overlay_style.dart';
import 'widgets/retro_frame.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// Said wherever these settings are changed.
const retroExportNote = "These settings apply on screens running the app. They don't apply to Live TV export.";

/// A picture for a full-screen use (an offline card, a surround): the file
/// picker, or the device's own pictures on a TV with none. Its name in the
/// custom logos folder, or null when none was picked.
Future<String?> pickFullScreenImage(BuildContext context) async {
  final icons = AppScope.read(context).icons;
  if (PlatformInfo.isAndroid && !await DeviceImages.hasDocumentPicker()) {
    if (!context.mounted) return null;
    // Android TVs have no document picker: the device's own pictures.
    final image = await Navigator.of(context)
        .push<DeviceImage>(MaterialPageRoute(builder: (_) => const DeviceImagePickerScreen()));
    if (image == null) return null;
    final Uint8List bytes;
    try {
      bytes = await DeviceImages.read(image, limit: CustomIconStore.maxSourceBytes);
    } on PlatformException {
      throw CustomIconException('Couldn\'t read that picture. Try another one.');
    }
    return icons.importOfflineBytes(bytes, image.name);
  }
  return icons.pickAndImportOffline();
}

/// One setting's heading and radio buttons.
class RetroRadios<T> extends StatelessWidget {
  const RetroRadios({
    super.key,
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onPick,
    this.autofocus = false,
    this.note,
    this.disabled = false,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onPick;
  final bool autofocus;

  /// Under the heading ("Not available on this device").
  final String? note;

  /// Shown but not selectable.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: g.display(24, weight: FontWeight.w800, color: disabled ? g.textDim : g.accent)),
          if (note != null) Text(note!, style: g.body(22, color: g.textDim)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (i, v) in values.indexed)
                TvToggle(
                  label: label(v),
                  radio: true,
                  autofocus: autofocus && i == 0,
                  on: v == selected,
                  onPressed: disabled ? null : () => onPick(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A channel's RETRO LOOK rows in Channels & icons: the four settings, each
/// with "Main setting (current value)".
class ChannelRetroSection extends StatelessWidget {
  const ChannelRetroSection({super.key, required this.channel});

  final Channel channel;

  Future<void> _pickSurroundImage(BuildContext context) async {
    final app = AppScope.read(context);
    try {
      final name = await pickFullScreenImage(context);
      if (name == null) return;
      await app.setChannelRetro(
          channel, channel.retro.copyWith(surround: () => Surround.image, surroundImage: () => name));
    } on CustomIconException catch (e) {
      if (context.mounted) await showMessage(context, title: 'Surround image', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final own = channel.retro;
    final main = app.settings.retro;
    String mainLabel(String value) => 'Main setting ($value)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text('RETRO LOOK', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
        const SizedBox(height: 6),
        Text(retroExportNote, style: g.body(22, color: g.textDim)),
        const SizedBox(height: 14),
        RetroRadios<PictureShape?>(
          title: 'PICTURE SHAPE',
          values: [null, ...PictureShape.values],
          selected: own.shape,
          label: (v) => v?.label ?? mainLabel(main.shape.label),
          onPick: (v) => app.setChannelRetro(channel, own.copyWith(shape: () => v)),
        ),
        RetroRadios<Surround?>(
          title: 'SURROUND',
          values: [null, ...Surround.values],
          selected: own.surround,
          label: (v) => v?.label ?? mainLabel(main.surround.label),
          onPick: (v) {
            if (v == Surround.image) {
              _pickSurroundImage(context);
            } else {
              app.setChannelRetro(channel, own.copyWith(surround: () => v, surroundImage: () => null));
            }
          },
        ),
        RetroRadios<CrtStyle?>(
          title: 'CRT EFFECT',
          values: [null, ...CrtStyle.values],
          selected: own.crt,
          label: (v) => v?.label ?? mainLabel(main.crt.label),
          onPick: (v) => app.setChannelRetro(channel, own.copyWith(crt: () => v)),
        ),
        RetroRadios<OverlayThemeName?>(
          title: 'OVERLAY THEME',
          values: [null, ...OverlayThemeName.values],
          selected: own.overlay,
          label: (v) => v?.label ?? mainLabel(main.overlay.label),
          onPick: (v) => app.setChannelRetro(channel, own.copyWith(overlay: () => v)),
        ),
      ],
    );
  }
}

/// The main picture shape, surround, CRT effect and overlay theme, the Custom
/// style and this device's switch, with a live preview.
class RetroLookScreen extends StatefulWidget {
  const RetroLookScreen({super.key});

  static const switchLabel = 'Effects on this device';
  static const switchHelp = 'Off turns off all CRT effects on this device only. Picture shape, surround and overlay '
      'themes stay as they are.';
  static const notAvailable = 'Not available on this device';

  @override
  State<RetroLookScreen> createState() => _RetroLookScreenState();
}

class _RetroLookScreenState extends State<RetroLookScreen> {
  @override
  void initState() {
    super.initState();
    // Whether to mark curvature and glow as unavailable.
    CrtShader.instance.ensureLoaded();
  }

  Future<void> _pickSurroundImage(AppState app) async {
    try {
      final name = await pickFullScreenImage(context);
      if (name == null) return;
      await app.setMainRetro(app.settings.retro.copyWith(surround: Surround.image, surroundImage: () => name));
    } on CustomIconException catch (e) {
      if (mounted) await showMessage(context, title: 'Surround image', message: e.message);
    }
  }

  List<Widget> _controls(AppState app) {
    final g = context.guide;
    final main = app.settings.retro;
    final custom = main.custom;
    void set(RetroSettings retro) => app.setMainRetro(retro);
    void setCustom(CrtValues values) => set(main.copyWith(custom: values));
    final device = DeviceEffects.instance;
    final shaderOk = CrtShader.instance.available.value != false;
    Widget level(String title, CrtLevel value, ValueChanged<CrtLevel> onPick, {bool off = false}) =>
        RetroRadios<CrtLevel>(
          title: title,
          values: CrtLevel.values,
          selected: value,
          label: (v) => v.label,
          onPick: onPick,
          disabled: off,
          note: off ? RetroLookScreen.notAvailable : null,
        );
    return [
      Text(retroExportNote, style: g.body(22, color: g.textDim)),
      const SizedBox(height: 18),
      RetroRadios<PictureShape>(
        title: 'PICTURE SHAPE',
        autofocus: true,
        values: PictureShape.values,
        selected: main.shape,
        label: (v) => v.label,
        onPick: (v) => set(main.copyWith(shape: v)),
      ),
      RetroRadios<Surround>(
        title: 'SURROUND',
        values: Surround.values,
        selected: main.surround,
        label: (v) => v.label,
        onPick: (v) {
          if (v == Surround.image) {
            _pickSurroundImage(app);
          } else {
            set(main.copyWith(surround: v, surroundImage: () => null));
          }
        },
      ),
      RetroRadios<CrtStyle>(
        title: 'CRT EFFECT',
        values: CrtStyle.values,
        selected: main.crt,
        label: (v) => v.label,
        onPick: (v) => set(main.copyWith(crt: v)),
      ),
      RetroRadios<OverlayThemeName>(
        title: 'OVERLAY THEME',
        values: OverlayThemeName.values,
        selected: main.overlay,
        label: (v) => v.label,
        onPick: (v) => set(main.copyWith(overlay: v)),
      ),
      RetroRadios<OverlayAccent>(
        title: 'ACCENT (${main.overlay.label.toUpperCase()})',
        values: OverlayAccent.values,
        selected: main.accentOf(main.overlay),
        label: (v) => v.label,
        onPick: (v) => set(main.copyWith(accents: {...main.accents, main.overlay: v})),
      ),
      Text('CUSTOM CRT STYLE', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 14),
      level('SCANLINES', custom.scanlines, (v) => setCustom(custom.copyWith(scanlines: v))),
      RetroRadios<int>(
        title: 'LINES',
        values: CrtValues.lineCounts,
        selected: custom.lines,
        label: (v) => '$v',
        onPick: (v) => setCustom(custom.copyWith(lines: v)),
      ),
      level('MASK', custom.mask, (v) => setCustom(custom.copyWith(mask: v))),
      level('VIGNETTE', custom.vignette, (v) => setCustom(custom.copyWith(vignette: v))),
      level('CURVATURE', custom.curvature, (v) => setCustom(custom.copyWith(curvature: v)), off: !shaderOk),
      level('GLOW', custom.glow, (v) => setCustom(custom.copyWith(glow: v)), off: !shaderOk),
      RetroRadios<CrtColor>(
        title: 'COLOR',
        values: CrtColor.values,
        selected: custom.color,
        label: (v) => v.label,
        onPick: (v) => setCustom(custom.copyWith(color: v)),
      ),
      Text('THIS DEVICE', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: TvToggle(
          label: RetroLookScreen.switchLabel,
          on: device.on,
          onPressed: () => device.setOn(!device.on),
        ),
      ),
      const SizedBox(height: 12),
      Text(RetroLookScreen.switchHelp, style: g.body(24, color: g.textDim)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final layout = ScreenLayout.of(context);
    return TvPage(
      title: 'Retro look',
      hints: '▲▼◀▶ Move    OK Select    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: ListenableBuilder(
        listenable: Listenable.merge([DeviceEffects.instance, CrtShader.instance.available]),
        builder: (context, _) {
          final list = FocusTraversalGroup(
            child: ListView(
              padding: layout.pagePadding(const EdgeInsets.fromLTRB(100, 32, 40, 40)),
              children: _controls(app),
            ),
          );
          final preview = RetroPreview(retro: ResolvedRetro.of(ChannelRetro.main, app.settings.retro), app: app);
          if (layout.isPortrait) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeFocus(child: AspectRatio(aspectRatio: 16 / 9, child: preview)),
                Expanded(child: list),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: list),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 32, 80, 0),
                child: ExcludeFocus(child: SizedBox(width: 800, height: 450, child: preview)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A built-in test picture with [retro] drawn on it, on the TV's canvas so the
/// overlays have their real proportions.
class RetroPreview extends StatelessWidget {
  const RetroPreview({super.key, required this.retro, this.app, this.channelNumber = 3});

  final ResolvedRetro retro;
  final AppState? app;
  final int channelNumber;

  /// The sample channel's icon: a color for the Channel color choices.
  static const sampleIcon = ChannelIcon(kind: ChannelIconKind.badge, value: 'TV', color: 0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        child: SizedBox.fromSize(
          size: ScreenLayout.tvCanvas,
          child: OverlayThemeScope.of(
            retro: retro,
            icon: sampleIcon,
            child: RetroFrame(
              retro: retro,
              icon: sampleIcon,
              app: app,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(painter: _TestPicturePainter()),
                  Positioned(top: 60, right: 90, child: ChannelNumberOsd(text: '$channelNumber')),
                  Positioned(left: 90, bottom: 70, child: _SamplePanel()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A corner card in the theme, as the Up next card looks.
class _SamplePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final g = OverlayStyle.of(context);
    return Container(
      width: 560,
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      decoration: g.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UP NEXT  ·  8:00 PM', style: g.display(24, weight: FontWeight.w800, color: g.accent)),
          const SizedBox(height: 4),
          Text('Test Pattern', maxLines: 1, style: g.display(40, weight: FontWeight.w800)),
          Text('Your channel, your look', maxLines: 1, style: g.body(24, color: g.textDim)),
        ],
      ),
    );
  }
}

/// Color bars over a gray ramp, the classic way to judge a picture.
class _TestPicturePainter extends CustomPainter {
  const _TestPicturePainter();

  static const _bars = [
    Color(0xFFC0C0C0),
    Color(0xFFC0C000),
    Color(0xFF00C0C0),
    Color(0xFF00C000),
    Color(0xFFC000C0),
    Color(0xFFC00000),
    Color(0xFF0000C0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / _bars.length;
    final barHeight = size.height * 0.72;
    for (final (i, c) in _bars.indexed) {
      canvas.drawRect(Rect.fromLTWH(i * barWidth, 0, barWidth + 1, barHeight), Paint()..color = c);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, barHeight, size.width, size.height - barHeight),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF000000), Color(0xFFFFFFFF)])
            .createShader(Rect.fromLTWH(0, barHeight, size.width, size.height - barHeight)),
    );
  }

  @override
  bool shouldRepaint(_TestPicturePainter oldDelegate) => false;
}
