import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/smb/smb_discovery.dart';

void main() {
  test('a WS-Discovery answer, with and without its addresses', () {
    const match = '<soap:Envelope><soap:Body><wsd:ProbeMatches><wsd:ProbeMatch><wsa:EndpointReference>'
        '<wsa:Address>urn:uuid:1dae16f7-478d</wsa:Address></wsa:EndpointReference>'
        '<wsd:XAddrs>http://192.168.1.9:5357/1dae16f7-478d</wsd:XAddrs></wsd:ProbeMatch></wsd:ProbeMatches></soap:Body></soap:Envelope>';
    final m = SmbDiscovery.parseProbeMatch(match)!;
    expect(m.endpoint, 'urn:uuid:1dae16f7-478d');
    expect(m.addresses.single.toString(), 'http://192.168.1.9:5357/1dae16f7-478d');
    final bare = SmbDiscovery.parseProbeMatch(match.replaceAll(RegExp(r'<wsd:XAddrs>.*</wsd:XAddrs>'), ''), from: '10.0.0.5')!;
    expect(bare.addresses.single.toString(), 'http://10.0.0.5:5357/1dae16f7-478d');
    expect(SmbDiscovery.parseProbeMatch('<wsd:Hello/>'), isNull);
    expect(SmbDiscovery.parseComputerName('<pub:Computer>OFFICE-PC/Workgroup:WORKGROUP</pub:Computer>'), 'OFFICE-PC');
    expect(SmbDiscovery.parseComputerName('<x/>'), isNull);
    expect(SmbDiscovery.probe('id'), contains('<wsd:Types>wsdp:Device</wsd:Types>'));
  });

  test('a NetBIOS node status answer', () {
    Uint8List answer(List<(String, int, bool)> names) {
      final b = BytesBuilder()
        ..add([0, 1, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0])
        ..addByte(0x20)
        ..add([0x43, 0x4B, ...List.filled(30, 0x41)])
        ..addByte(0)
        ..add([0, 0x21, 0, 1, 0, 0, 0, 0])
        ..add([0, names.length * 18 + 47])
        ..addByte(names.length);
      for (final (name, suffix, group) in names) {
        b
          ..add(name.padRight(15).codeUnits)
          ..addByte(suffix)
          ..add([group ? 0x84 : 0x04, 0]);
      }
      b.add(List.filled(46, 0));
      return b.toBytes();
    }

    expect(SmbDiscovery.parseNodeStatus(answer([('NAS', 0x00, false), ('WORKGROUP', 0x00, true), ('NAS', 0x20, false)])), 'NAS');
    expect(SmbDiscovery.parseNodeStatus(answer([('WORKGROUP', 0x00, true), ('PRINTER', 0x00, false)])), 'PRINTER');
    expect(SmbDiscovery.parseNodeStatus(Uint8List(10)), isNull);
    final q = SmbDiscovery.nodeStatus(0x1234);
    expect((q[0], q[1], q.length), (0x12, 0x34, 50));
  });
}
