import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';

/// Removing the copy an older tool/install.sh put in the home folder, once
/// the app runs from the Linux package.
void main() {
  late Directory home;
  late Directory copy;
  late File desktop;
  late File icon;
  late File settings;
  const id = 'com.coffeehauslabs.nightingale_tv';
  const packaged = '/opt/nightingale-tv/nightingale_tv';

  setUp(() async {
    home = await Directory.systemTemp.createTemp('nightingale_tv_home');
    copy = Directory('${home.path}/.local/opt/nightingale-tv');
    desktop = File('${home.path}/.local/share/applications/$id.desktop');
    icon = File('${home.path}/.local/share/icons/hicolor/scalable/apps/$id.svg');
    settings = File('${home.path}/.local/share/$id/profiles.json');
    for (final file in [File('${copy.path}/nightingale_tv'), desktop, icon, settings]) {
      await file.create(recursive: true);
    }
  });

  tearDown(() async {
    await Process.run('chmod', ['-R', 'u+w', home.path]);
    await home.delete(recursive: true);
  });

  test('running from the package removes the old copy, menu entry and icon', () async {
    await AppStorage.removeUserCopies(home.path, packaged);
    expect(copy.existsSync(), isFalse);
    expect(desktop.existsSync(), isFalse);
    expect(icon.existsSync(), isFalse);
  });

  test('settings and other menu entries are kept', () async {
    final other = File('${home.path}/.local/share/applications/other.desktop');
    await other.create();
    await AppStorage.removeUserCopies(home.path, packaged);
    expect(settings.existsSync(), isTrue);
    expect(other.existsSync(), isTrue);
  });

  test('running from anywhere else removes nothing', () async {
    for (final exe in [
      '${copy.path}/nightingale_tv',
      '/home/me/Nightingale-TV/build/linux/x64/release/bundle/nightingale_tv',
      '/app/nightingale_tv',
      '/opt/nightingale-tv-old/nightingale_tv',
    ]) {
      await AppStorage.removeUserCopies(home.path, exe);
      expect(copy.existsSync(), isTrue, reason: exe);
      expect(desktop.existsSync(), isTrue, reason: exe);
      expect(icon.existsSync(), isTrue, reason: exe);
    }
  });

  test('nothing to remove is fine', () async {
    final empty = await Directory.systemTemp.createTemp('nightingale_tv_empty');
    addTearDown(() => empty.delete(recursive: true));
    await AppStorage.removeUserCopies(empty.path, packaged);
  });

  test('a copy it cannot delete is left without failing start-up', () async {
    await File('${copy.path}/lib/libapp.so').create(recursive: true);
    await Process.run('chmod', ['a-w', '${copy.path}/lib']);
    await AppStorage.removeUserCopies(home.path, packaged);
    expect(desktop.existsSync(), isFalse, reason: 'the rest is still removed');
    expect(icon.existsSync(), isFalse);
  });
}
