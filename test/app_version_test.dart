import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_version.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';

void main() {
  test('appVersion is pubspec.yaml\'s version', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final pubspec = line.substring('version:'.length).trim().split('+').first;
    expect(appVersion, pubspec, reason: 'bump lib/app_version.dart with pubspec.yaml');
  });

  test('servers are told the app\'s version', () {
    expect(JellyfinClient.clientVersion, appVersion);
  });
}
