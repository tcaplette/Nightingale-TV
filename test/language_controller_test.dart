import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/language_controller.dart';
import 'package:nightingale_tv/l10n/tr.dart';

void main() {
  tearDown(() => activeLanguage = 'en');

  var device = <String>['en'];
  LanguageController make() => LanguageController(deviceLanguages: () => device);

  group('Automatic follows the device', () {
    test('a German device', () {
      device = ['de'];
      final c = make()..setProfile(active: true);
      expect(c.language, 'de');
      expect(activeLanguage, 'de');
    });

    test('an unsupported device language with a supported second choice', () {
      device = ['pl', 'it'];
      expect((make()..setProfile(active: true)).language, 'it');
    });

    test('no supported device language', () {
      device = ['ja'];
      expect((make()..setProfile(active: true)).language, 'en');
    });

    test('any Portuguese device', () {
      device = ['pt-PT'];
      expect((make()..setProfile(active: true)).language, 'pt');
    });

    test('follows a change of the device languages', () {
      device = ['en'];
      final c = make()..setProfile(active: true);
      var told = 0;
      c.addListener(() => told++);
      device = ['fr'];
      c.didChangeLocales(null);
      expect(c.language, 'fr');
      expect(told, 1);
    });
  });

  group('A profile choice', () {
    test('wins over the device, and tells listeners once', () {
      device = ['en'];
      final c = make()..setProfile(active: true);
      var told = 0;
      c.addListener(() => told++);
      c
        ..setProfile(active: true, choice: 'es')
        ..setProfile(active: true, choice: 'es');
      expect(c.language, 'es');
      expect(told, 1);
    });

    test('two profiles show their own languages', () {
      final c = make()..setProfile(active: true, choice: 'de');
      expect(c.language, 'de');
      c.setProfile(active: true, choice: 'it');
      expect(c.language, 'it');
    });
  });

  group('Screens before a profile is chosen', () {
    test('back at the profile picker: the last profile\'s language', () {
      device = ['en'];
      final saved = <String?>[];
      final c = make()..onLastChanged = saved.add;
      c
        ..setProfile(active: true, choice: 'it')
        ..setProfile(active: false);
      expect(c.language, 'it');
      expect(saved, ['it']);
    });

    test('the saved language comes back after a restart', () {
      device = ['en'];
      expect((make()..restoreLast('it')).language, 'it');
    });

    test('first launch follows the device', () {
      device = ['fr'];
      expect(make().language, 'fr');
    });

    test('an Automatic profile leaves the picker following the device', () {
      device = ['en'];
      final c = make()
        ..restoreLast('it')
        ..setProfile(active: true)
        ..setProfile(active: false);
      expect(c.language, 'en');
    });
  });
}
