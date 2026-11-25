import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../playback/tuner.dart';
import '../theme/tv_theme.dart';
import 'playback_screen.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// The Quality button's word (player-options): "Auto" on a YouTube channel,
/// where YouTube chooses; otherwise the cap in effect, "Original" or
/// "{N} Mbps".
String qualityButtonValue(Tuner tuner) {
  if (tuner.channel?.isYouTube == true) return tr.playerQualityAuto;
  return qualityValue(tuner.app.capInEffect);
}

/// "Original" with no cap, else "{N} Mbps".
String qualityValue(int? capKbps) => capKbps == null ? tr.playerQualityOriginal : tr.playerQualityMbps(capKbps ~/ 1000);

/// Whether the Quality button can be pressed: not on a YouTube channel.
bool qualityAvailable(Tuner tuner) => tuner.channel?.isYouTube != true;

/// The quality picker (player-options D4), modelled on the sleep and captions
/// pickers: the Maximum streaming bitrate presets in order, the cap in effect
/// ticked and focused (Original while converting is off). Picking one saves
/// it ([AppState.setQuality]), closes, and applies it at once
/// ([Tuner.applyQuality]) when the cap in effect changed. Back closes with
/// no change. Returns the toast to show ("Quality: 8 Mbps"), or null when
/// nothing was picked.
Future<String?> showQualityPicker(BuildContext context, Tuner tuner) async {
  final app = tuner.app;
  final inEffect = app.capInEffect;
  final chosen = await showDialog<BitratePreset>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final g = context.guide;
      return Dialog(
        backgroundColor: g.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(g.radius * 2),
          side: BorderSide(color: g.cellBorder, width: 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(dialogPadding(context)),
          child: SizedBox(
            width: dialogWidth(context, 720, padding: dialogPadding(context)),
            child: dialogBody(
              context,
              FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr.playerQuality, style: g.display(48, weight: FontWeight.w800)),
                    const SizedBox(height: 24),
                    if (app.plexRelay) ...[
                      Text(PlaybackScreen.relayNotice, style: g.body(26, color: g.nowLine)),
                      const SizedBox(height: 20),
                    ],
                    for (final preset in PlaybackSettings.presets) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TvToggle(
                          label: preset.label,
                          radio: true,
                          on: preset.kbps == inEffect,
                          autofocus: preset.kbps == inEffect,
                          onPressed: () => Navigator.pop(context, preset),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  if (chosen == null) return null;
  await app.setQuality(chosen);
  unawaited(tuner.applyQuality(inEffect));
  return tr.playerQualityValue(qualityValue(chosen.kbps));
}
