import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/tr.dart';

void main() {
  tearDown(() => activeLanguage = 'en');

  test('code that sets no language gets English', () {
    expect(tr.sleepTimer, 'Sleep timer');
  });

  test('tr follows the app language', () {
    activeLanguage = 'de';
    expect(tr.sleepTimer, 'Sleep-Timer');
  });

  test('a zone overrides the app language, and an unsupported one is ignored', () {
    activeLanguage = 'fr';
    expect(runInLanguage('it', () => currentLanguage), 'it');
    expect(runInLanguage('ja', () => currentLanguage), 'fr');
    expect(runInLanguage(null, () => currentLanguage), 'fr');
  });

  test('concurrent async work keeps its own language', () async {
    final seen = <String, List<String>>{'de': [], 'it': []};
    Future<void> worker(String language) => runInLanguage(language, () async {
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(Duration(milliseconds: i.isEven ? 1 : 0));
            seen[language]!.add(tr.languageTitle);
          }
        });
    await Future.wait([worker('de'), worker('it')]);
    expect(seen['de']!.toSet(), {'Sprache'});
    expect(seen['it']!.toSet(), {'Lingua'});
  });

  test('tags resolve to a supported language', () {
    expect(supportedLanguage('de-AT'), 'de');
    expect(supportedLanguage('pt_PT'), 'pt');
    expect(supportedLanguage('ja'), isNull);
    expect(languageFromHeader('pl;q=0.9, it-IT;q=0.8, en;q=0.5'), 'it');
    expect(languageFromHeader('ja'), isNull);
    expect(languageFromHeader(null), isNull);
  });
}
