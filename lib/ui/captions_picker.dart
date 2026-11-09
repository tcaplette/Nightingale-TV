import 'package:flutter/material.dart';

import '../playback/caption_size.dart';
import '../playback/caption_style.dart';
import '../playback/subtitles.dart';
import '../playback/tuner.dart';
import '../server/languages.dart';
import '../server/media_server.dart';
import '../theme/tv_theme.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// Said, disabled, when the program on screen has no subtitle tracks.
String get noSubtitlesRow => tr.noSubtitlesFor;

/// Said, disabled, while the program's tracks are asked for.
String get findingSubtitlesRow => tr.findingSubtitles;

/// Over the sizes' place while the server draws the captions in.
String get burnedInCaptionsNote => tr.theServerDraws;

/// The line drawn at the size captions appear on the picture.
String get captionSampleText => tr.sampleCaption;

/// The Captions button's label: "Captions" while off, "Captions: English"
/// while on (the track showing, else On).
String captionsButtonLabel(Tuner tuner) {
  if (!tuner.captions) return tr.captions;
  final shown = tuner.shownSubtitle;
  return tr.captionsValue(shown == null ? tr.onLabel2 : languageName(shown.language) ?? subtitleLabel(shown));
}

/// The captions picker (subtitles spec, "Captions picker"), modelled on the
/// sleep picker: the size, then Off and each subtitle track of the program
/// on screen, focus on the current choice. On a live channel, Off and On.
/// Choosing a track sets the tuner's captions and closes the picker; choosing
/// a size applies it and leaves the picker open. D-pad, pointer and touch
/// all work it (TvToggle rows). True when a track row was chosen.
Future<bool> showCaptionsPicker(BuildContext context, Tuner tuner) async {
  // The program's tracks are asked for now, captions on or off.
  final loading = tuner.isLive ? null : tuner.loadSubtitleTracks();
  final chosen = await showDialog<_Choice>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([tuner, tuner.app.captionSize]),
      builder: (context, _) => _CaptionsDialog(tuner: tuner, loading: loading),
    ),
  );
  if (chosen == null) return false;
  switch (chosen) {
    case _Off():
      if (tuner.isLive) {
        await tuner.setCaptions(false);
      } else {
        await tuner.pickSubtitle(null);
      }
    case _LiveOn():
      await tuner.setCaptions(true);
    case _Track(:final track):
      await tuner.pickSubtitle(track);
  }
  return true;
}

sealed class _Choice {
  const _Choice();
}

final class _Off extends _Choice {
  const _Off();
}

final class _LiveOn extends _Choice {
  const _LiveOn();
}

final class _Track extends _Choice {
  const _Track(this.track);
  final SubtitleTrack track;
}

class _CaptionsDialog extends StatelessWidget {
  const _CaptionsDialog({required this.tuner, required this.loading});

  final Tuner tuner;
  final Future<List<SubtitleTrack>?>? loading;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final on = tuner.captions;
    final rows = <Widget>[];
    void row(Widget child) => rows.addAll([Align(alignment: Alignment.centerLeft, child: child), const SizedBox(height: 10)]);
    void note(String text) => row(TvToggle(label: text, radio: true, on: false, onPressed: null));

    if (tuner.isLive) {
      row(TvToggle(label: tr.off, radio: true, on: !on, autofocus: !on, onPressed: () => Navigator.pop(context, const _Off())));
      row(TvToggle(label: tr.onLabel2, radio: true, on: on, autofocus: on, onPressed: () => Navigator.pop(context, const _LiveOn())));
    } else {
      final tracks = tuner.subtitleTracks;
      final shown = on ? tuner.shownSubtitle : null;
      row(TvToggle(
        label: tr.off,
        radio: true,
        on: !on,
        // Focus on the current choice; Off when the track showing isn't listed.
        autofocus: shown == null || !(tracks ?? const []).contains(shown),
        onPressed: () => Navigator.pop(context, const _Off()),
      ));
      if (tracks == null) {
        note(findingSubtitlesRow);
      } else if (tracks.isEmpty) {
        note(noSubtitlesRow);
      } else {
        for (final t in tracks) {
          row(TvToggle(
            label: subtitleLabel(t),
            radio: true,
            on: t == shown,
            autofocus: t == shown,
            onPressed: () => Navigator.pop(context, _Track(t)),
          ));
        }
      }
    }

    final app = tuner.app;
    final inForce = app.captionSize.value;
    final layout = ScreenLayout.of(context);
    // The picture fills the width upright, so captions shrink with it.
    final sampleScale = layout.isPortrait ? layout.canvas.width / 1920 : 1.0;

    return Dialog(
      backgroundColor: g.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(g.radius * 2),
        side: BorderSide(color: g.cellBorder, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(dialogPadding(context)),
        child: SizedBox(
          width: dialogWidth(context, 1040, padding: dialogPadding(context)),
          // Scrolls on every platform: a program can have dozens of tracks.
          child: SingleChildScrollView(
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.captions, style: g.display(48, weight: FontWeight.w800)),
                  const SizedBox(height: 24),
                  Text(tr.size, style: g.display(30, weight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  if (tuner.captionsBurnedIn)
                    Text(burnedInCaptionsNote, style: g.body(26, color: g.textDim))
                  else ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final size in CaptionSize.values)
                          TvToggle(
                            label: size.label,
                            radio: true,
                            on: size == inForce,
                            onPressed: () => app.setPlayback(app.settings.playback.copyWith(captionSize: () => size)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // As tall as Extra large, so the rows below don't move.
                    SizedBox(
                      height: CaptionSize.extraLarge.px * 1.4 * sampleScale,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(captionSampleText, style: captionTextStyle(inForce), textScaler: TextScaler.linear(sampleScale)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ...rows,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
