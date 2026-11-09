import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_scope.dart';
import '../../app_state.dart';
import '../../channels/channel.dart';
import '../../theme/tv_theme.dart';
import '../../server/media_server.dart';
import 'nightingale_mark.dart';
import '../../l10n/tr.dart';

/// Renders any [ChannelIcon] kind, centered in a [width]×[size] box.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo(
      {super.key, required this.icon, required this.size, this.width, this.fallbackText, this.app, this.alignment = Alignment.center});

  final ChannelIcon icon;

  /// Height of the logo box (and width, unless [width] is given). Show logos
  /// are wide, so rows give them a wider box than the square icons need.
  final double size;
  final double? width;

  /// Shown in a badge if an image fails to load.
  final String? fallbackText;

  /// Where show logos and uploads come from; the [AppScope]'s by default
  /// (offscreen rendering has no scope).
  final AppState? app;

  /// Where a logo narrower than the box sits in it.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    // Built-in icons and badges need no app (or scope).
    AppState app() => this.app ?? AppScope.of(context);
    final Widget child = switch (icon.kind) {
      ChannelIconKind.builtin => BuiltinIcon(iconKey: icon.value, size: size * 0.82, color: Color(icon.color)),
      ChannelIconKind.badge => StationBadge(
          text: icon.value, shape: icon.shape, color: Color(icon.color), size: size),
      // A server's show logo, from the server the id is on (multi-server).
      ChannelIconKind.jellyfin => app().clientOf(icon.value) == null
          ? _fallback(context)
          : Image.network(
              app().clientOf(icon.value)!.imageUri(icon.value, ImageKind.logo, maxHeight: 160).toString(),
              headers: app().clientOf(icon.value)!.authHeaders,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => _fallback(context),
            ),
      ChannelIconKind.custom => _customImage(context, app().icons.fileFor(icon.value)),
      ChannelIconKind.remote => Image.network(
          icon.value,
          headers: _headersFor(icon.value, [for (final s in app().servers.all) ?s.client]),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => _fallback(context),
        ),
    };
    return SizedBox(width: width ?? size, height: size, child: Align(alignment: alignment, child: child));
  }

  /// A sign-in goes only to its own server (any of the profile's).
  static Map<String, String>? _headersFor(String url, List<MediaServer> clients) =>
      clients.where((c) => url.startsWith(c.serverUrl)).firstOrNull?.authHeaders;

  Widget _customImage(BuildContext context, File file) {
    if (file.path.endsWith('.svg')) {
      return SvgPicture.file(file,
          fit: BoxFit.contain, placeholderBuilder: (_) => const SizedBox.shrink());
    }
    return Image.file(file,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _fallback(context));
  }

  Widget _fallback(BuildContext context) => StationBadge(
        text: _initials(fallbackText ?? tr.tv),
        shape: BadgeShape.roundedSquare,
        color: context.guide.accent,
        size: size,
      );

  static String _initials(String name) {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 4));
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }
}

/// A generic TV-station style badge: short call letters on a shape.
class StationBadge extends StatelessWidget {
  const StationBadge({
    super.key,
    required this.text,
    required this.shape,
    required this.color,
    required this.size,
  });

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
      BadgeShape.shield => BeveledRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(size * 0.4))),
    };
    return Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(
        color: color,
        shape: border,
        shadows: const [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      alignment: shape == BadgeShape.shield ? const Alignment(0, -0.3) : Alignment.center,
      child: FittedBox(
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          style: context.guide.display(size * 0.42, weight: FontWeight.w800, color: onColor),
        ),
      ),
    );
  }
}
