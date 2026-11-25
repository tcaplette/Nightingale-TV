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
    expect(runInLanguage('ko', () => currentLanguage), 'fr');
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
    expect(supportedLanguage('ko'), isNull);
    expect(languageFromHeader('pl;q=0.9, it-IT;q=0.8, en;q=0.5'), 'it');
    expect(languageFromHeader('ko'), isNull);
    expect(languageFromHeader(null), isNull);
  });

  test('Japanese and Chinese tags resolve by script and region (cjk-languages D1)', () {
    const table = {
      'ja': 'ja', 'ja-JP': 'ja', 'JA_jp': 'ja',
      'zh': 'zh-Hans', 'zh-CN': 'zh-Hans', 'zh-SG': 'zh-Hans', 'zh-Hans': 'zh-Hans', 'zh-Hans-HK': 'zh-Hans', 'zh_Hans_CN': 'zh-Hans',
      'yue-Hans': 'zh-Hans', 'yue-Hans-CN': 'zh-Hans',
      'zh-TW': 'zh-Hant', 'zh-Hant': 'zh-Hant', 'zh-Hant-TW': 'zh-Hant', 'zh_Hant_TW': 'zh-Hant',
      'zh-HK': 'zh-Hant-HK', 'zh-MO': 'zh-Hant-HK', 'zh-Hant-HK': 'zh-Hant-HK', 'zh-Hant-MO': 'zh-Hant-HK', 'zh_Hant_HK': 'zh-Hant-HK',
      'yue': 'zh-Hant-HK', 'yue-HK': 'zh-Hant-HK', 'yue-Hant': 'zh-Hant-HK', 'yue-Hant-HK': 'zh-Hant-HK',
      'en': 'en', 'de': 'de', 'fr': 'fr', 'es': 'es', 'pt': 'pt', 'it': 'it',
    };
    for (final MapEntry(:key, :value) in table.entries) {
      expect(supportedLanguage(key), value, reason: key);
    }
    for (final tag in ['ko', 'ko-KR', 'pl', 'xx', '']) {
      expect(supportedLanguage(tag), isNull, reason: tag);
    }
    // Every supported tag is its own language.
    for (final language in supportedLanguages) {
      expect(supportedLanguage(language), language);
    }
    expect(languageFromHeader('zh-TW,zh;q=0.9'), 'zh-Hant');
    expect(languageFromHeader('ko-KR, zh-HK;q=0.8'), 'zh-Hant-HK');
  });

  test('locales and intl locales carry script and region', () {
    expect(localeOf('de').toLanguageTag(), 'de');
    expect(localeOf('ja').toLanguageTag(), 'ja');
    expect(localeOf('zh-Hans').toLanguageTag(), 'zh-Hans');
    expect(localeOf('zh-Hant').toLanguageTag(), 'zh-Hant');
    expect(localeOf('zh-Hant-HK').toLanguageTag(), 'zh-Hant-HK');
    expect([for (final l in supportedLanguages) intlLocaleOf(l)],
        ['en', 'de', 'fr', 'es', 'pt', 'it', 'ja', 'zh', 'zh_TW', 'zh_HK']);
  });

  test('each Chinese tag reads its own ARB file', () {
    expect(stringsFor('zh-Hant-HK').profiles, '個人檔案');
    expect(stringsFor('zh-Hant').profiles, '設定檔');
    expect(stringsFor('zh-Hans').profiles, '个人资料');
    expect(stringsFor('zh-Hant-HK').localeName, 'zh_Hant_HK');
    expect(stringsFor('zh-Hant').localeName, 'zh_Hant');
    expect(stringsFor('zh-Hans').localeName, 'zh');
    expect(stringsFor('ja').localeName, 'ja');
  });

  test('lists join with the language\'s own separator', () {
    expect(joinNames(['Sam', 'Alex', 'Kim']), 'Sam, Alex and Kim');
    expect(joinNames(['Sam', 'Alex']), 'Sam and Alex');
    expect(runInLanguage('ja', () => joinNames(['サム', 'アレックス', 'キム'])), 'サム、アレックスとキム');
  });
}
