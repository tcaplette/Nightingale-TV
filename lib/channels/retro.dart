/// A channel's retro look (retro-presentation): picture shape, what surrounds
/// a 4:3 frame, the CRT effect and the overlay theme. Shared with the web
/// admin, so plain Dart.
library;

/// How the picture sits on the screen.
enum PictureShape {
  original,

  /// A centred 4:3 frame, the picture filling it and cropped at its long sides.
  fill43,

  /// A centred 4:3 frame, the whole picture inside it.
  fit43;

  String get label => switch (this) {
        original => 'Original',
        fill43 => '4:3 fill',
        fit43 => '4:3 fit',
      };

  bool get isTube => this != original;

  static PictureShape? parse(Object? name) => values.where((v) => v.name == name).firstOrNull;
}

/// What the screen shows outside a 4:3 frame.
enum Surround {
  black,
  charcoal,

  /// The color of the channel's icon.
  channel,

  /// A picture from the custom logos folder.
  image;

  String get label => switch (this) {
        black => 'Black',
        charcoal => 'Charcoal',
        channel => 'Channel color',
        image => 'Image',
      };

  static Surround? parse(Object? name) => values.where((v) => v.name == name).firstOrNull;
}

/// The strength of one part of a CRT effect.
enum CrtLevel {
  off,
  low,
  medium,
  high;

  String get label => switch (this) {
        off => 'Off',
        low => 'Low',
        medium => 'Medium',
        high => 'High',
      };

  static CrtLevel? parse(Object? name) => values.where((v) => v.name == name).firstOrNull;
}

enum CrtColor {
  natural,
  warm,
  faded,
  vivid;

  String get label => switch (this) {
        natural => 'Natural',
        warm => 'Warm',
        faded => 'Faded',
        vivid => 'Vivid',
      };

  static CrtColor? parse(Object? name) => values.where((v) => v.name == name).firstOrNull;
}

/// What a CRT effect is made of.
class CrtValues {
  const CrtValues({
    this.scanlines = CrtLevel.off,
    this.lines = 480,
    this.mask = CrtLevel.off,
    this.vignette = CrtLevel.off,
    this.curvature = CrtLevel.off,
    this.glow = CrtLevel.off,
    this.color = CrtColor.natural,
  });

  /// The line counts there are.
  static const lineCounts = [240, 480];

  final CrtLevel scanlines;
  final int lines;
  final CrtLevel mask;
  final CrtLevel vignette;
  final CrtLevel curvature;
  final CrtLevel glow;
  final CrtColor color;

  /// Curvature or glow is on: it needs the shader tier.
  bool get usesShader => curvature != CrtLevel.off || glow != CrtLevel.off;

  CrtValues copyWith({
    CrtLevel? scanlines,
    int? lines,
    CrtLevel? mask,
    CrtLevel? vignette,
    CrtLevel? curvature,
    CrtLevel? glow,
    CrtColor? color,
  }) =>
      CrtValues(
        scanlines: scanlines ?? this.scanlines,
        lines: lines ?? this.lines,
        mask: mask ?? this.mask,
        vignette: vignette ?? this.vignette,
        curvature: curvature ?? this.curvature,
        glow: glow ?? this.glow,
        color: color ?? this.color,
      );

  Map<String, Object?> toJson() => {
        'scanlines': scanlines.name,
        'lines': lines,
        'mask': mask.name,
        'vignette': vignette.name,
        'curvature': curvature.name,
        'glow': glow.name,
        'color': color.name,
      };

  /// Anything missing or unknown reads as Living room's value.
  factory CrtValues.fromJson(Object? json) {
    const d = CrtStyle.startingCustom;
    if (json is! Map) return d;
    return CrtValues(
      scanlines: CrtLevel.parse(json['scanlines']) ?? d.scanlines,
      lines: lineCounts.contains(json['lines']) ? json['lines'] as int : d.lines,
      mask: CrtLevel.parse(json['mask']) ?? d.mask,
      vignette: CrtLevel.parse(json['vignette']) ?? d.vignette,
      curvature: CrtLevel.parse(json['curvature']) ?? d.curvature,
      glow: CrtLevel.parse(json['glow']) ?? d.glow,
      color: CrtColor.parse(json['color']) ?? d.color,
    );
  }

  /// What's wrong with [json] as a set of values, for the admin API.
  static String? problemIn(Object? json) {
    if (json is! Map) return "That isn't a Custom style.";
    for (final key in const ['scanlines', 'mask', 'vignette', 'curvature', 'glow']) {
      if (json[key] != null && CrtLevel.parse(json[key]) == null) return 'Custom $key is off, low, medium or high.';
    }
    if (json['lines'] != null && !lineCounts.contains(json['lines'])) return 'Custom lines is 240 or 480.';
    if (json['color'] != null && CrtColor.parse(json['color']) == null) {
      return 'Custom color is natural, warm, faded or vivid.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CrtValues &&
      other.scanlines == scanlines &&
      other.lines == lines &&
      other.mask == mask &&
      other.vignette == vignette &&
      other.curvature == curvature &&
      other.glow == glow &&
      other.color == color;

  @override
  int get hashCode => Object.hash(scanlines, lines, mask, vignette, curvature, glow, color);
}

/// The CRT effect a channel shows.
enum CrtStyle {
  off,
  softTube,
  livingRoom,
  arcade,
  studioMonitor,

  /// The profile's own values.
  custom;

  String get label => switch (this) {
        off => 'Off',
        softTube => 'Soft tube',
        livingRoom => 'Living room',
        arcade => 'Arcade',
        studioMonitor => 'Studio monitor',
        custom => 'Custom',
      };

  /// Where Custom starts: Living room.
  static const startingCustom = CrtValues(
    scanlines: CrtLevel.medium,
    mask: CrtLevel.low,
    vignette: CrtLevel.medium,
    curvature: CrtLevel.low,
    glow: CrtLevel.low,
    color: CrtColor.warm,
  );

  /// What this style is made of, with [custom] the profile's Custom values.
  CrtValues valuesWith(CrtValues custom) => switch (this) {
        CrtStyle.off => const CrtValues(),
        softTube => const CrtValues(scanlines: CrtLevel.low, vignette: CrtLevel.low),
        livingRoom => startingCustom,
        arcade => const CrtValues(
            scanlines: CrtLevel.high,
            lines: 240,
            mask: CrtLevel.medium,
            vignette: CrtLevel.low,
            curvature: CrtLevel.medium,
            glow: CrtLevel.medium,
            color: CrtColor.vivid,
          ),
        studioMonitor => const CrtValues(scanlines: CrtLevel.medium, mask: CrtLevel.low),
        CrtStyle.custom => custom,
      };

  static CrtStyle? parse(Object? name) => values.where((v) => v.name == name).firstOrNull;
}

/// The look of the channel number, banner and other overlays.
enum OverlayThemeName {
  standard,
  vcr,
  cableBox,
  stationIdent;

  String get label => switch (this) {
        standard => 'Standard',
        vcr => 'VCR',
        cableBox => 'Cable box',
        stationIdent => 'Station ident',
      };

  static OverlayThemeName? parse(Object? name) => values.where((v) => v.name == name).firstOrNull;
}

/// Where an overlay theme's accent color comes from.
enum OverlayAccent {
  theme,
  channel;

  String get label => switch (this) {
        theme => 'Theme',
        channel => 'Channel color',
      };

  static OverlayAccent? parse(Object? name) => values.where((v) => v.name == name).firstOrNull;
}

/// A channel's own retro settings: each null follows the main setting.
class ChannelRetro {
  const ChannelRetro({this.shape, this.surround, this.surroundImage, this.crt, this.overlay});

  /// Follows the main setting for all of them.
  static const main = ChannelRetro();

  /// A new live channel: its full picture with no effect, since cropping or
  /// adding effects to a modern broadcast is rarely wanted (design D10).
  static const live = ChannelRetro(shape: PictureShape.original, crt: CrtStyle.off);

  final PictureShape? shape;
  final Surround? surround;

  /// A file in the custom logos folder, for [Surround.image].
  final String? surroundImage;
  final CrtStyle? crt;
  final OverlayThemeName? overlay;

  bool get followsMain => shape == null && surround == null && crt == null && overlay == null;

  ChannelRetro copyWith({
    PictureShape? Function()? shape,
    Surround? Function()? surround,
    String? Function()? surroundImage,
    CrtStyle? Function()? crt,
    OverlayThemeName? Function()? overlay,
  }) =>
      ChannelRetro(
        shape: shape != null ? shape() : this.shape,
        surround: surround != null ? surround() : this.surround,
        surroundImage: surroundImage != null ? surroundImage() : this.surroundImage,
        crt: crt != null ? crt() : this.crt,
        overlay: overlay != null ? overlay() : this.overlay,
      );

  Map<String, Object?> toJson() => {
        if (shape != null) 'shape': shape!.name,
        if (surround != null) 'surround': surround!.name,
        if (surroundImage != null) 'surroundImage': surroundImage,
        if (crt != null) 'crt': crt!.name,
        if (overlay != null) 'overlay': overlay!.name,
      };

  /// Anything missing or unknown follows the main setting.
  factory ChannelRetro.fromJson(Object? json) {
    if (json is! Map) return main;
    return ChannelRetro(
      shape: PictureShape.parse(json['shape']),
      surround: Surround.parse(json['surround']),
      surroundImage: json['surroundImage'] is String ? json['surroundImage'] as String : null,
      crt: CrtStyle.parse(json['crt']),
      overlay: OverlayThemeName.parse(json['overlay']),
    );
  }

  /// What's wrong with [json] as retro settings, for the admin API: null
  /// when every value in it is a known one.
  static String? problemIn(Object? json) {
    if (json == null) return null;
    if (json is! Map) return "Those aren't retro settings.";
    if (json['shape'] != null && PictureShape.parse(json['shape']) == null) {
      return 'The picture shape is original, fill43 or fit43.';
    }
    if (json['surround'] != null && Surround.parse(json['surround']) == null) {
      return 'The surround is black, charcoal, channel or image.';
    }
    if (json['surroundImage'] != null && json['surroundImage'] is! String) return 'The surround image is a file name.';
    if (json['crt'] != null && CrtStyle.parse(json['crt']) == null) {
      return 'The CRT effect is off, softTube, livingRoom, arcade, studioMonitor or custom.';
    }
    if (json['overlay'] != null && OverlayThemeName.parse(json['overlay']) == null) {
      return 'The overlay theme is standard, vcr, cableBox or stationIdent.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ChannelRetro &&
      other.shape == shape &&
      other.surround == surround &&
      other.surroundImage == surroundImage &&
      other.crt == crt &&
      other.overlay == overlay;

  @override
  int get hashCode => Object.hash(shape, surround, surroundImage, crt, overlay);
}

/// A profile's main retro settings, and its one Custom style.
class RetroSettings {
  const RetroSettings({
    this.shape = PictureShape.original,
    this.surround = Surround.black,
    this.surroundImage,
    this.crt = CrtStyle.off,
    this.overlay = OverlayThemeName.standard,
    this.custom = CrtStyle.startingCustom,
    this.accents = const {},
  });

  final PictureShape shape;
  final Surround surround;
  final String? surroundImage;
  final CrtStyle crt;
  final OverlayThemeName overlay;
  final CrtValues custom;

  /// Each theme's Accent option; a theme not in here uses its own.
  final Map<OverlayThemeName, OverlayAccent> accents;

  OverlayAccent accentOf(OverlayThemeName theme) => accents[theme] ?? OverlayAccent.theme;

  RetroSettings copyWith({
    PictureShape? shape,
    Surround? surround,
    String? Function()? surroundImage,
    CrtStyle? crt,
    OverlayThemeName? overlay,
    CrtValues? custom,
    Map<OverlayThemeName, OverlayAccent>? accents,
  }) =>
      RetroSettings(
        shape: shape ?? this.shape,
        surround: surround ?? this.surround,
        surroundImage: surroundImage != null ? surroundImage() : this.surroundImage,
        crt: crt ?? this.crt,
        overlay: overlay ?? this.overlay,
        custom: custom ?? this.custom,
        accents: accents ?? this.accents,
      );

  Map<String, Object?> toJson() => {
        'shape': shape.name,
        'surround': surround.name,
        if (surroundImage != null) 'surroundImage': surroundImage,
        'crt': crt.name,
        'overlay': overlay.name,
        'custom': custom.toJson(),
        'accents': {for (final e in accents.entries) e.key.name: e.value.name},
      };

  /// Anything missing or unknown reads as its default: profiles from before
  /// this setting look as they did.
  factory RetroSettings.fromJson(Object? json) {
    if (json is! Map) return const RetroSettings();
    final accents = json['accents'];
    return RetroSettings(
      shape: PictureShape.parse(json['shape']) ?? PictureShape.original,
      surround: Surround.parse(json['surround']) ?? Surround.black,
      surroundImage: json['surroundImage'] is String ? json['surroundImage'] as String : null,
      crt: CrtStyle.parse(json['crt']) ?? CrtStyle.off,
      overlay: OverlayThemeName.parse(json['overlay']) ?? OverlayThemeName.standard,
      custom: CrtValues.fromJson(json['custom']),
      accents: {
        if (accents is Map)
          for (final e in accents.entries)
            if ((OverlayThemeName.parse(e.key), OverlayAccent.parse(e.value)) case (final t?, final a?)) t: a,
      },
    );
  }

  /// What's wrong with [json] as main settings, for the admin API.
  static String? problemIn(Object? json) {
    if (json is! Map) return "Those aren't retro settings.";
    if (ChannelRetro.problemIn(json) case final problem?) return problem;
    if (json['custom'] != null) {
      if (CrtValues.problemIn(json['custom']) case final problem?) return problem;
    }
    final accents = json['accents'];
    if (accents != null) {
      if (accents is! Map) return 'The accents are a theme and theme or channel for each.';
      for (final e in accents.entries) {
        if (OverlayThemeName.parse(e.key) == null || OverlayAccent.parse(e.value) == null) {
          return 'The accents are a theme and theme or channel for each.';
        }
      }
    }
    return null;
  }
}

/// The look a channel has: its own settings over the main ones.
class ResolvedRetro {
  const ResolvedRetro({
    this.shape = PictureShape.original,
    this.surround = Surround.black,
    this.surroundImage,
    this.crt = CrtStyle.off,
    this.values = const CrtValues(),
    this.overlay = OverlayThemeName.standard,
    this.accent = OverlayAccent.theme,
  });

  factory ResolvedRetro.of(ChannelRetro own, RetroSettings main) {
    final crt = own.crt ?? main.crt;
    final overlay = own.overlay ?? main.overlay;
    return ResolvedRetro(
      shape: own.shape ?? main.shape,
      surround: own.surround ?? main.surround,
      // A channel's own image goes with its own surround.
      surroundImage: own.surround != null ? own.surroundImage : main.surroundImage,
      crt: crt,
      values: crt.valuesWith(main.custom),
      overlay: overlay,
      accent: main.accentOf(overlay),
    );
  }

  final PictureShape shape;
  final Surround surround;
  final String? surroundImage;
  final CrtStyle crt;
  final CrtValues values;
  final OverlayThemeName overlay;
  final OverlayAccent accent;

  Map<String, Object?> toJson() => {
        'shape': shape.name,
        'surround': surround.name,
        if (surroundImage != null) 'surroundImage': surroundImage,
        'crt': crt.name,
        'overlay': overlay.name,
        'accent': accent.name,
      };
}
