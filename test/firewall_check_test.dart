import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/remote/firewall_check.dart';

typedef Answer = ({int exitCode, String stdout});

void main() {
  /// Every command run, to check `ufw` and `sudo` are never among them.
  final ran = <String>[];

  setUp(ran.clear);
  tearDown(PlatformInfo.debugReset);

  /// firewalld running with [zones] (interface → zone), [defaultZone], and
  /// the zone's open [services] and [ports]. [fail] answers every query
  /// (not --state) with that exit code and no output.
  FirewallCheck firewalld({
    String defaultZone = 'public',
    Map<String, String> zones = const {},
    Set<String> services = const {},
    Set<String> ports = const {},
    bool installed = false,
    int? fail,
    bool hang = false,
  }) =>
      FirewallCheck(
        linux: true,
        read: (path) async => installed && path == FirewallCheck.firewalldServiceFile ? '<service/>' : null,
        run: (exe, args) async {
          ran.add('$exe ${args.join(' ')}');
          final a = args.last;
          if (a == '--state') return (exitCode: 0, stdout: 'running\n');
          if (hang) return Completer<Answer>().future;
          if (fail != null) return (exitCode: fail, stdout: '');
          if (a == '--get-default-zone') return (exitCode: 0, stdout: '$defaultZone\n');
          if (a.startsWith('--get-zone-of-interface=')) {
            final zone = zones[a.split('=').last];
            return zone == null ? (exitCode: 2, stdout: 'no zone\n') : (exitCode: 0, stdout: '$zone\n');
          }
          bool yes(Set<String> set) => set.contains(a.split('=').last);
          if (a.startsWith('--query-service=')) {
            return yes(services) ? (exitCode: 0, stdout: 'yes\n') : (exitCode: 1, stdout: 'no\n');
          }
          if (a.startsWith('--query-port=')) {
            return yes(ports) ? (exitCode: 0, stdout: 'yes\n') : (exitCode: 1, stdout: 'no\n');
          }
          return (exitCode: 2, stdout: '');
        },
      );

  FirewallCheck noFirewalld({String? ufwConf, bool ufwProfile = false}) => FirewallCheck(
        linux: true,
        read: (path) async => switch (path) {
          FirewallCheck.ufwConf => ufwConf,
          FirewallCheck.ufwProfileFile when ufwProfile => '[Nightingale TV Remote]',
          _ => null,
        },
        run: (exe, args) async {
          ran.add('$exe ${args.join(' ')}');
          throw const FormatException('firewall-cmd: not found');
        },
      );

  tearDown(() {
    for (final c in ran) {
      expect(c, isNot(contains('ufw')));
      expect(c, isNot(contains('sudo')));
    }
  });

  group('firewalld', () {
    test('port closed → Blocked, with the port command', () async {
      final s = await firewalld().check(8642, interface: 'wlan0');
      expect(s.kind, FirewallKind.firewalld);
      expect(s.open, isFalse);
      expect(s.blocked, isTrue);
      expect(s.fixCommand(8642), 'sudo firewall-cmd --permanent --add-port=8642/tcp && sudo firewall-cmd --reload');
    });

    test('open by the service', () async {
      final s = await firewalld(installed: true, services: {FirewallCheck.firewalldService}).check(8642);
      expect(s.open, isTrue);
      expect(s.blocked, isFalse);
      expect(s.fixCommand(8642), isNull);
    });

    test('open by the port', () async {
      final s = await firewalld(ports: {'8643/tcp'}).check(8643);
      expect(s.open, isTrue);
      expect(s.blocked, isFalse);
    });

    test('a trusted zone is open', () async {
      final s = await firewalld(zones: {'eth0': 'trusted'}).check(8642, interface: 'eth0');
      expect(s.open, isTrue);
      expect(ran.where((c) => c.contains('--query')), isEmpty);
    });

    test('the LAN interface\'s zone, named in the command when not the default', () async {
      final s = await firewalld(zones: {'wlan0': 'home'}, installed: true).check(8642, interface: 'wlan0');
      expect(s.zone, 'home');
      expect(s.blocked, isTrue);
      expect(ran, contains('firewall-cmd --zone=home --query-port=8642/tcp'));
      expect(s.fixCommand(8642),
          'sudo firewall-cmd --permanent --zone=home --add-service=nightingale-tv-remote && sudo firewall-cmd --reload');
    });

    test('the package\'s service on the default zone gives the short command', () async {
      final s = await firewalld(installed: true).check(8642, interface: 'wlan0');
      expect(s.zone, 'public');
      expect(s.fixCommand(8642),
          'sudo firewall-cmd --permanent --add-service=nightingale-tv-remote && sudo firewall-cmd --reload');
    });

    test('a permission error is unknown, never Blocked, with the firewalld command', () async {
      final s = await firewalld(fail: 11).check(8642, interface: 'wlan0');
      expect(s.kind, FirewallKind.firewalld);
      expect(s.open, isNull);
      expect(s.blocked, isFalse);
      expect(s.fixCommand(8642), contains('firewall-cmd'));
    });

    test('a query that takes over 3 seconds is unknown', () {
      fakeAsync((async) {
        FirewallState? s;
        firewalld(hang: true).check(8642).then((r) => s = r);
        async.elapse(const Duration(seconds: 10));
        expect(s, isNotNull);
        expect(s!.open, isNull);
        expect(s!.blocked, isFalse);
      });
    });
  });

  group('ufw', () {
    test('enabled → on with rules unknown, port command without the package', () async {
      final s = await noFirewalld(ufwConf: '# comment\nENABLED=yes\nLOGLEVEL=low\n').check(8643);
      expect(s.kind, FirewallKind.ufw);
      expect(s.open, isNull);
      expect(s.blocked, isFalse);
      expect(s.fixCommand(8643), 'sudo ufw allow 8643/tcp');
    });

    test('the profile command when the package installed it', () async {
      final s = await noFirewalld(ufwConf: 'ENABLED=yes\n', ufwProfile: true).check(8642);
      expect(s.fixCommand(8642), 'sudo ufw allow "Nightingale TV Remote"');
      expect(s.fixCommand(9000), 'sudo ufw allow 9000/tcp', reason: 'outside the profile\'s ports');
    });

    test('disabled is no firewall', () async {
      final s = await noFirewalld(ufwConf: 'ENABLED=no\n').check(8642);
      expect(s.kind, FirewallKind.none);
    });
  });

  test('no firewall', () async {
    final s = await noFirewalld().check(8642);
    expect(s.kind, FirewallKind.none);
    expect(s.blocked, isFalse);
    expect(s.fixCommand(8642), isNull);
  });

  test('Android has none and runs nothing', () async {
    PlatformInfo.debugOverride = TargetPlatform.android;
    final s = await FirewallCheck(
      run: (exe, args) async => fail('ran $exe on Android'),
      read: (path) async => fail('read $path on Android'),
    ).check(8642);
    expect(s.kind, FirewallKind.none);
    expect(s.fixCommand(8642), isNull);
  });
}
