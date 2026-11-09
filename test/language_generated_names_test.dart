import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/generated_names.dart';
import 'package:nightingale_tv/l10n/tr.dart';

void main() {
  String it(String Function() f) => runInLanguage('it', f);

  test('English shows every generated name as saved', () {
    for (final name in ['Kids Zone', 'Comedy Movies', 'Rock Radio', 'Laugh Track (Shows)', 'Movie Channel']) {
      expect(displayChannelName(name), name);
    }
  });

  test('a generated channel is shown in the current language', () {
    expect(it(() => displayChannelName('Movie Channel')), 'Canale Film');
    expect(it(() => displayChannelName('Comedy Movies')), 'Film Commedia');
    expect(it(() => displayChannelName('Rock Radio')), 'Radio Rock');
  });

  test('a kind suffix is translated, with its number', () {
    expect(it(() => displayChannelName('Laugh Track (Shows)')), 'Risate Registrate (Serie)');
    expect(it(() => displayChannelName('Comedy Movies (Movies 2)')), 'Film Commedia (Film 2)');
  });

  test('a channel named after a show only has its suffix translated', () {
    expect(it(() => displayChannelName('Cheers', showChannel: true)), 'Cheers');
    expect(it(() => displayChannelName('Cheers (Show)', showChannel: true)), 'Cheers (Serie)');
  });

  test('a name the user chose stays as written', () {
    expect(it(() => displayChannelName("Papa's Picks")), "Papa's Picks");
  });

  test('block titles', () {
    expect(it(() => displayBlockTitle('Movie Night')), 'Serata Cinema');
    expect(it(() => displayBlockTitle('Saturday Cartoons')), 'Saturday Cartoons');
  });

  test('decade, decade + genre and major genre channels (genre-decade-channels D6)', () {
    expect(it(() => displayChannelName('90s TV')), '90s TV');
    expect(it(() => displayChannelName('90s Comedy TV')), 'Commedia TV 90s');
    expect(it(() => displayChannelName('80s Action Movies')), 'Film Azione 80s');
    expect(it(() => displayChannelName('1910s Movies')), 'Film 1910s');
    expect(it(() => displayChannelName('Mystery & Thrills')), 'Mistero e Brividi');
    expect(it(() => displayChannelName('Sci-Fi TV')), 'Fantascienza TV');
    expect(it(() => displayChannelName('Thriller & Mystery Movies')), 'Film Thriller e mistero');
    expect(runInLanguage('de', () => displayChannelName('80s Action Movies')), '80s Action-Filme');
    // Names from before the major genres still show translated.
    expect(it(() => displayChannelName('Thrill TV')), isNot('Thrill TV'));
    expect(it(() => displayGenre('Sci-Fi & Fantasy')), 'Fantascienza e fantasy');
    for (final name in ['90s TV', '90s Comedy TV', '80s Action Movies', 'Mystery & Thrills', '2000s Movies']) {
      expect(displayChannelName(name), name, reason: 'English as saved');
    }
  });
}
