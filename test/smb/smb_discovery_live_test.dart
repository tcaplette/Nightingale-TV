import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/smb/smb_discovery.dart';

import 'mdns_responder.dart';

/// Discovery on this PC's network: the Samba container answers NetBIOS
/// (`NTVSAMBA`), and the WS-Discovery container answers as a Windows
/// computer (`NTV-WINDOWS`).
void main() {
  test('finds the test hosts by mDNS, WS-Discovery and NetBIOS', () async {
    // A share announced over mDNS, as a NAS does.
    final nas = MdnsResponder(instance: 'Test NAS', host: 'testnas', address: InternetAddress('10.99.0.7'), port: 1445);
    await nas.start();
    addTearDown(nas.stop);
    final d = SmbDiscovery(duration: const Duration(seconds: 6));
    addTearDown(d.dispose);
    await d.start();
    await Future<void>.delayed(const Duration(seconds: 6));
    final names = {for (final h in d.current) h.label};
    // ignore: avoid_print
    print([for (final h in d.current) '${h.address} ${h.label}']);
    expect(names, contains('NTV-WINDOWS'));
    expect(names, contains('NTVSAMBA'));
    expect(d.current.where((h) => h.name == 'Test NAS').single.port, 1445);
    expect(d.running, isFalse);
    // Each host once.
    expect(d.current.map((h) => h.address).toSet().length, d.current.length);
  }, skip: Platform.environment['SMB_LIVE'] != '1', timeout: const Timeout(Duration(seconds: 30)));
}
