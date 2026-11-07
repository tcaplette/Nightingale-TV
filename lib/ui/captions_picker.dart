import 'package:flutter/material.dart';

import '../playback/subtitles.dart';
import '../playback/tuner.dart';
import '../server/languages.dart';
import '../server/media_server.dart';
import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';

/// Said, disabled, when the program on screen has no subtitle tracks.
const noSubtitlesRow = 'No subtitles for this program';

/// Said, disabled, while the program's tracks are asked for.
const findingSubtitlesRow = 'Finding subtitles…';

/// The Captions button's label: "Captions" while off, "Captions: English"
/// while on (the track showing, else On).
String captionsButtonLabel(Tuner tuner) {
  if (!tuner.captions) return 'Captions';
  final shown = tuner.shownSubtitle;
  return 'Captions: ${shown == null ? 'On' : languageName(shown.language) ?? subtitleLabel(shown)}';
}

/// The captions picker (subtitles spec, "Captions picker"), modelled on the
/// sleep picker: Off, then each subtitle track of the program on screen,
/// focus on the current choice. On a live channel, Off and On. Choosing
/// sets the tuner's captions and closes the picker. D-pad, pointer and
/// touch all work it (TvToggle rows). True when a row was chosen.
Future<bool> showCaptionsPicker(BuildContext context, Tuner tuner) async {
  // The program's tracks are asked for now, captions on or off.
  final loading = tuner.isLive ? null : tuner.loadSubtitleTracks();
  final chosen = await showDialog<_Choice>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => ListenableBuilder(
      listenable: tuner,
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
      row(TvToggle(label: 'Off', radio: true, on: !on, autofocus: !on, onPressed: () => Navigator.pop(context, const _Off())));
      row(TvToggle(label: 'On', radio: true, on: on, autofocus: on, onPressed: () => Navigator.pop(context, const _LiveOn())));
    } else {
      final tracks = tuner.subtitleTracks;
      final shown = on ? tuner.shownSubtitle : null;
      row(TvToggle(
        label: 'Off',
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
                  Text('Captions', style: g.display(48, weight: FontWeight.w800)),
                  const SizedBox(height: 24),
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
