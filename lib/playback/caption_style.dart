import 'dart:math';

import 'package:flutter/painting.dart';

import 'caption_size.dart';

/// The one look of text captions, on Android and Linux. Only the size varies.
TextStyle captionTextStyle(CaptionSize size) => TextStyle(
      height: 1.4,
      fontSize: size.px,
      letterSpacing: 0,
      wordSpacing: 0,
      color: const Color(0xffffffff),
      fontWeight: FontWeight.normal,
      backgroundColor: const Color(0xaa000000),
    );

/// Around the caption text, inside the box the picture is in.
const captionPadding = EdgeInsets.fromLTRB(16, 0, 16, 24);

/// How much captions shrink in a box smaller than the canvas (the guide's
/// preview, the portrait picture); never more than 1.
double captionBoxScale(Size box) => sqrt((box.width * box.height / (1920 * 1080)).clamp(0.0, 1.0));
