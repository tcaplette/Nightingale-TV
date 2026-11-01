import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_state.dart';
import '../../channels/channel.dart';
import 'crt_effects.dart';

/// The picture's frame (retro-presentation D5): a centred 4:3 tube with its
/// own [MediaQuery] size and the surround outside it, or the whole space.
/// The tree is the same for every look, so changing look never rebuilds what
/// plays in [child].
class RetroFrame extends StatelessWidget {
  const RetroFrame({super.key, required this.retro, required this.child, this.icon, this.app, this.effects = true});

  final ResolvedRetro retro;

  /// The channel's icon, for the Channel color surround.
  final ChannelIcon? icon;

  /// For the Image surround's file.
  final AppState? app;

  /// Draws the CRT effect on the tube (the guide preview doesn't: design D7).
  final bool effects;
  final Widget child;

  /// How the video fits in the frame.
  static BoxFit fitFor(PictureShape shape) => shape == PictureShape.fill43 ? BoxFit.cover : BoxFit.contain;

  /// The frame of [shape] in a space of [full].
  static Size frameIn(PictureShape shape, Size full) {
    if (!shape.isTube) return full;
    final width = full.height * 4 / 3;
    return width <= full.width ? Size(width, full.height) : Size(full.width, full.width * 3 / 4);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = frameIn(retro.shape, constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            retro.shape.isTube ? _surround() : const SizedBox.shrink(),
            Center(
              child: SizedBox.fromSize(
                size: frame,
                child: ClipRect(
                  clipBehavior: retro.shape.isTube ? Clip.hardEdge : Clip.none,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: frame),
                    child: CrtLayers(values: effects ? retro.values : const CrtValues(), child: child),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _surround() {
    switch (retro.surround) {
      case Surround.black:
        return const ColoredBox(color: Colors.black);
      case Surround.charcoal:
        return const ColoredBox(color: Color(0xFF26282C));
      case Surround.channel:
        return ColoredBox(color: channelColor(icon) ?? Colors.black);
      case Surround.image:
        final file = retro.surroundImage == null ? null : app?.icons.fileFor(retro.surroundImage!);
        if (file == null || !file.existsSync()) return const ColoredBox(color: Colors.black);
        const black = ColoredBox(color: Colors.black);
        return ColoredBox(
          color: Colors.black,
          child: retro.surroundImage!.endsWith('.svg')
              ? SvgPicture.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => black)
              : Image.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => black),
        );
    }
  }
}

/// The color setting of [icon], when it has one.
Color? channelColor(ChannelIcon? icon) => switch (icon?.kind) {
      ChannelIconKind.builtin || ChannelIconKind.badge => Color(icon!.color),
      _ => null,
    };
