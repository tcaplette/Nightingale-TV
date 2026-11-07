import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/subtitles.dart';
import 'package:nightingale_tv/server/languages.dart';
import 'package:nightingale_tv/server/media_server.dart';

SubtitleTrack track(String id, String? language,
        {bool isDefault = false, bool forced = false, bool external = false, String? title}) =>
    SubtitleTrack(
        id: id,
        codec: 'subrip',
        language: language,
        title: title,
        isDefault: isDefault,
        isForced: forced,
        isExternal: external,
        position: external ? null : int.parse(id));

void main() {
  group('the choice order (subtitles D1)', () {
    test('the preferred language first, its default-flagged track first', () {
      final tracks = [track('0', 'eng'), track('1', 'fre'), track('2', 'fre', isDefault: true)];
      expect(chooseSubtitle(tracks, preferred: 'fre')!.id, '2');
    });

    test('in the preferred language, embedded before external', () {
      final tracks = [track('9', 'spa', external: true), track('1', 'spa')];
      expect(chooseSubtitle(tracks, preferred: 'spa')!.id, '1');
    });

    test('a forced track in the preferred language only when nothing else matches', () {
      final forcedFirst = [track('0', 'eng', forced: true, isDefault: true), track('1', 'eng')];
      expect(chooseSubtitle(forcedFirst, preferred: 'eng')!.id, '1');
      final onlyForced = [track('0', 'jpn'), track('1', 'eng', forced: true)];
      expect(chooseSubtitle(onlyForced, preferred: 'eng')!.id, '1');
    });

    test('no preferred language, or none matching: the default-flagged track', () {
      final tracks = [track('0', 'eng'), track('1', 'ger', isDefault: true)];
      expect(chooseSubtitle(tracks)!.id, '1');
      expect(chooseSubtitle(tracks, preferred: 'ita')!.id, '1');
    });

    test('then a track in the device language, then the first', () {
      final tracks = [track('0', 'eng'), track('1', 'spa')];
      expect(chooseSubtitle(tracks, device: 'es')!.id, '1');
      expect(chooseSubtitle(tracks, device: 'ja')!.id, '0');
    });

    test('forced tracks come last outside the preferred language', () {
      final tracks = [track('0', 'eng', forced: true, isDefault: true), track('1', 'eng')];
      expect(chooseSubtitle(tracks)!.id, '1');
      expect(chooseSubtitle([track('0', 'eng', forced: true)])!.id, '0');
    });

    test('preferred and device codes of any form match', () {
      final tracks = [track('0', 'eng'), track('1', 'ger')];
      expect(chooseSubtitle(tracks, preferred: 'deu')!.id, '1');
      expect(chooseSubtitle(tracks, device: 'de')!.id, '1');
    });

    test('nothing to choose from', () => expect(chooseSubtitle(const [], preferred: 'eng'), isNull));
  });

  test('languages normalize to one code each', () {
    expect([for (final c in ['en', 'EN-us', 'eng', 'deu', 'ger', 'fra', 'und', null]) normalizeLanguage(c)],
        ['eng', 'eng', 'eng', 'ger', 'ger', 'fre', null, null]);
    expect(languageName('es'), 'Spanish');
    expect(languageName('tlh'), 'TLH');
  });

  test('labels: language, title, External, Forced', () {
    expect(subtitleLabel(track('0', 'eng')), 'English');
    expect(subtitleLabel(track('0', 'eng', title: 'SDH')), 'English (SDH)');
    expect(subtitleLabel(track('0', 'eng', title: 'English')), 'English');
    expect(subtitleLabel(track('0', 'spa', external: true)), 'Spanish · External');
    expect(subtitleLabel(track('0', 'jpn', forced: true)), 'Japanese · Forced');
    expect(subtitleLabel(track('0', null)), 'Unknown language');
  });

  group('the saved preference (subtitles spec)', () {
    test('saved per profile with the playback settings', () {
      const s = PlaybackSettings(captions: true, captionLanguage: 'eng');
      final back = PlaybackSettings.fromJson(s.toJson());
      expect((back.captions, back.captionLanguage), (true, 'eng'));
      expect(back, s);
    });

    test('settings saved before this change load with captions off and no language', () {
      final old = PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'bitrate': 8000, 'volumeLeveling': false});
      expect((old.captions, old.captionLanguage), (false, null));
    });

    test('Off keeps the language; captions change no playback decision', () {
      const on = PlaybackSettings(captions: true, captionLanguage: 'fre');
      final off = on.copyWith(captions: false);
      expect((off.captions, off.captionLanguage), (false, 'fre'));
      expect(off.decidesLike(on), isTrue);
      expect(on.copyWith(captionLanguage: () => null).captionLanguage, isNull);
    });
  });
}
