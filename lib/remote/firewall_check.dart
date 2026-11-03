import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../platform/platform_info.dart';

/// Runs a command and returns its exit code and output.
typedef CommandRunner = Future<({int exitCode, String stdout})> Function(String executable, List<String> args);

/// A file's text, or null when it's missing or unreadable.
typedef FileReader = Future<String?> Function(String path);

enum FirewallKind { none, firewalld, ufw }

/// What this computer's firewall says about the remote's port (remote-setup
/// D3). Only firewalld can answer for certain; ufw's rules need root.
class FirewallState {
  const FirewallState({
    required this.kind,
    this.open,
    this.zone,
    this.defaultZone = true,
    this.profileInstalled = false,
  });

  static const none = FirewallState(kind: FirewallKind.none);

  final FirewallKind kind;

  /// True or false when firewalld answered; null when unknown.
  final bool? open;

  /// The firewalld zone of the LAN interface, when known.
  final String? zone;

  /// Whether [zone] is firewalld's default zone (so `--zone` can be left out).
  final bool defaultZone;

  /// Whether the `.deb`'s firewall profile for [kind] is installed.
  final bool profileInstalled;

  /// Known for certain to close the port.
  bool get blocked => kind == FirewallKind.firewalld && open == false;

  /// The one-line command that lets phones in on [port], or null when
  /// there's no firewall to fix (or it's known to be open).
  String? fixCommand(int port) {
    // The packaged profiles cover the remote's ports, 8642 to 8651.
    final named = profileInstalled && port >= 8642 && port <= 8651;
    switch (kind) {
      case FirewallKind.none:
        return null;
      case FirewallKind.firewalld:
        if (open == true) return null;
        final z = zone != null && !defaultZone ? ' --zone=$zone' : '';
        final what = named ? '--add-service=${FirewallCheck.firewalldService}' : '--add-port=$port/tcp';
        return 'sudo firewall-cmd --permanent$z $what && sudo firewall-cmd --reload';
      case FirewallKind.ufw:
        return named ? 'sudo ufw allow "${FirewallCheck.ufwProfile}"' : 'sudo ufw allow $port/tcp';
    }
  }
}

/// Asks this computer's firewall about the remote's port, without root
/// (remote-setup D3). It never runs `ufw` or `sudo`.
class FirewallCheck {
  FirewallCheck({CommandRunner? run, FileReader? read, bool? linux})
      : _run = run ?? _runCommand,
        _read = read ?? _readFile,
        _linux = linux ?? (!PlatformInfo.isAndroid && Platform.isLinux);

  static const firewalldService = 'nightingale-tv-remote';
  static const ufwProfile = 'Nightingale TV Remote';
  static const ufwProfileFile = '/etc/ufw/applications.d/nightingale-tv';
  static const firewalldServiceFile = '/usr/lib/firewalld/services/nightingale-tv-remote.xml';
  static const ufwConf = '/etc/ufw/ufw.conf';
  static const timeout = Duration(seconds: 3);

  final CommandRunner _run;
  final FileReader _read;

  /// Android has no inbound firewall, so only Linux is checked.
  final bool _linux;

  /// The firewall's answer for [port] on the interface named [interface].
  Future<FirewallState> check(int port, {String? interface}) async {
    if (!_linux) return FirewallState.none;
    final state = await _cmd(['--state']);
    if (state != null && state.exitCode == 0 && state.stdout.trim() == 'running') {
      return _firewalld(port, interface);
    }
    final ufw = await _read(ufwConf);
    if (ufw != null && RegExp(r'^\s*ENABLED\s*=\s*"?yes"?\s*$', multiLine: true).hasMatch(ufw)) {
      return FirewallState(kind: FirewallKind.ufw, profileInstalled: await _read(ufwProfileFile) != null);
    }
    return FirewallState.none;
  }

  Future<FirewallState> _firewalld(int port, String? interface) async {
    final installed = await _read(firewalldServiceFile) != null;
    FirewallState result({bool? open, String? zone, bool isDefault = true}) => FirewallState(
        kind: FirewallKind.firewalld, open: open, zone: zone, defaultZone: isDefault, profileInstalled: installed);

    final byDefault = await _cmd(['--get-default-zone']);
    final defaultZone = byDefault != null && byDefault.exitCode == 0 ? byDefault.stdout.trim() : null;
    String? zone;
    if (interface != null) {
      final r = await _cmd(['--get-zone-of-interface=$interface']);
      if (r != null && r.exitCode == 0 && r.stdout.trim().isNotEmpty) zone = r.stdout.trim();
    }
    zone ??= defaultZone;
    if (zone == null || zone.isEmpty) return result();
    final isDefault = defaultZone == null || zone == defaultZone;
    if (zone == 'trusted') return result(open: true, zone: zone, isDefault: isDefault);

    // Only "no" (exit 1) is an answer; anything else is a failure.
    bool? query(({int exitCode, String stdout})? r) => r == null
        ? null
        : r.exitCode == 0
            ? true
            : r.exitCode == 1 && r.stdout.trim() == 'no'
                ? false
                : null;
    // Without the package the service doesn't exist, so it isn't asked about.
    if (installed) {
      final service = query(await _cmd(['--zone=$zone', '--query-service=$firewalldService']));
      if (service == true) return result(open: true, zone: zone, isDefault: isDefault);
      if (service == null) return result(zone: zone, isDefault: isDefault);
    }
    final open = query(await _cmd(['--zone=$zone', '--query-port=$port/tcp']));
    return result(open: open, zone: zone, isDefault: isDefault);
  }

  /// Runs `firewall-cmd`; null when it's missing, fails to start or takes
  /// longer than [timeout].
  Future<({int exitCode, String stdout})?> _cmd(List<String> args) async {
    try {
      return await _run('firewall-cmd', args).timeout(timeout);
    } on Object {
      return null;
    }
  }

  static Future<({int exitCode, String stdout})> _runCommand(String executable, List<String> args) async {
    final process = await Process.start(executable, args);
    final out = process.stdout.transform(utf8.decoder).join();
    process.stderr.drain<void>().ignore();
    try {
      final code = await process.exitCode.timeout(timeout);
      return (exitCode: code, stdout: await out);
    } on TimeoutException {
      process.kill();
      rethrow;
    }
  }

  static Future<String?> _readFile(String path) async {
    try {
      return await File(path).readAsString();
    } on Object {
      return null;
    }
  }
}
