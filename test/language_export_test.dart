import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/export/broadcast_art.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/lineup_server.dart';
import 'package:nightingale_tv/export/xmltv_writer.dart';
import 'package:nightingale_tv/export/m3u_writer.dart';
import 'package:nightingale_tv/l10n/tr.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_language_export');
    app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 20}, movies: 20));
  });

  tearDown(() async {
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  final urls = ExportUrls(Uri.parse('http://tv:5004'));
  String guide() => buildXmltv(channels: app.channels, scheduleFor: app.scheduleFor, library: app.library, urls: urls, now: DateTime.now());

  test('a guide in Spanish keeps its category values', () {
    final xml = runInLanguage('es', guide);
    expect(xml, contains('<category>Movie</category>'));
    expect(xml, isNot(contains('<category>Película</category>')));
  });

  test('two profiles at once get their own card text', () async {
    Future<List<String>> card(String language) => runInLanguage(language, () async {
          final out = <String>[];
          for (var i = 0; i < 5; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
            final standBy = const StandByCard.rightBack();
            out.add('${standBy.key}=${standBy.text}');
          }
          return out;
        });
    final both = await Future.wait([card('de'), card('fr')]);
    expect(both[0].toSet(), {'standby|Wir sind gleich zurück|de=Wir sind gleich zurück'});
    expect(both[1].toSet(), {'standby|Nous revenons tout de suite|fr=Nous revenons tout de suite'});
  });

  test('an off-air card and the off-air guide entry are in the profile\'s language', () {
    expect(runInLanguage('de', () => tr.offTheAir), 'SENDEPAUSE');
    expect(runInLanguage('de', () => OffAirCard(next: (when: '19:00', title: 'Cartoons')).message), 'Wieder auf Sendung 19:00 mit Cartoons');
  });

  test('a lineup server answers in its profile\'s language', () async {
    final server = LineupServer(
      profileId: 'p',
      appFor: () => app,
      profileName: () => 'p',
      language: () => 'de',
      export: const ProfileExport(exported: true, port: 1, deviceId: '7B8AF336', deviceAuth: 'x'),
    );
    await server.start(port: 0);
    addTearDown(server.stop);
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.get('127.0.0.1', server.port!, '/xmltv.xml');
    final response = await request.close();
    final body = await response.transform(const SystemEncoding().decoder).join();
    expect(body, contains('<programme'));
    expect(body, contains('<category>Movie</category>'));
  });
}
