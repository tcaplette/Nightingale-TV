import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/transfer_page.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/remote/remote_page.dart';

void main() {
  for (final language in supportedLanguages) {
    test('the remote and transfer pages resolve every key in $language', () {
      runInLanguage(language, () {
        for (final (page, texts) in [(remotePageHtml(), remotePageTexts()), (transferPageHtml(), transferPageTexts())]) {
          expect(page, isNot(contains('@@')), reason: 'a key with no text');
          expect(page, isNot(contains('/*TEXTS*/')));
          expect(page, contains('<html lang="$language">'));
          expect(page, contains('const LANG = "$language"'));
          expect(texts.values.where((v) => v.isEmpty), isEmpty);
          final keys = RegExp(r'\bT\.(\w+)').allMatches(page).map((m) => m[1]!).toSet();
          expect(keys.where((k) => !texts.containsKey(k)), isEmpty, reason: 'scripts read every key from T');
        }
      });
    });
  }

  test('the remote page reads as German, and follows a change of language', () {
    final page = runInLanguage('de', remotePageHtml);
    expect(page, contains('>Zurück<'));
    expect(page, contains('>TV-Guide<'));
    expect(page, contains('s.language !== LANG'));
  });

  test('the transfer page is translated', () {
    expect(runInLanguage('it', transferPageHtml), contains('Scarica backup'));
  });
}
