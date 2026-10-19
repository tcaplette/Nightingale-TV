import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../channels/channel.dart';
import 'lineup_server.dart';
import 'm3u_writer.dart';
import 'xmltv_writer.dart';

/// How an emulated tuner introduces itself.
typedef HdHomeRunIdentity = ({String manufacturer, String modelNumber, String firmwareName, String firmwareVersion});

/// Values that name Nightingale TV. Used unless Plex or Jellyfin turn out
/// to need [genericIdentity] (design D10, tasks 1.4).
const HdHomeRunIdentity honestIdentity = (
  manufacturer: 'Nightingale TV',
  modelNumber: 'NTV-1',
  firmwareName: 'nightingale_tv',
  firmwareVersion: '20261018',
);

/// The generic tuner values tools like this commonly report.
const HdHomeRunIdentity genericIdentity = (
  manufacturer: 'Silicondust',
  modelNumber: 'HDTC-2US',
  firmwareName: 'hdhomeruntc_atsc',
  firmwareVersion: '20170930',
);

/// The identity the tuner endpoints report.
const HdHomeRunIdentity tunerIdentity = honestIdentity;

/// The UPnP id of a device, derived from its DeviceID so it never changes.
String deviceUuid(String deviceId) {
  final h = md5.convert(utf8.encode('nightingale-tv:$deviceId')).toString();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// The HDHomeRun HTTP endpoints of one exported profile.
DeviceEndpoints hdHomeRunEndpoints({required int Function() tunerCount, HdHomeRunIdentity identity = tunerIdentity}) =>
    (request, server, lineup) async {
      final response = request.response;
      final urls = LineupServer.urlsFor(request);
      switch (request.uri.path) {
        case '/discover.json':
          LineupServer.json(response, discoverJson(server, urls, tunerCount(), identity));
        case '/lineup.json':
          LineupServer.json(response, lineupJson(lineup, urls));
        case '/lineup_status.json':
          LineupServer.json(response, lineupStatus);
        case '/lineup.post':
          // The lineup is always current: a scan has nothing to do.
          response.statusCode = HttpStatus.ok;
        case '/device.xml':
          response.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
          response.write(deviceXml(server, urls, identity));
        default:
          return false;
      }
      return true;
    };

String friendlyName(LineupServer server) => 'Nightingale TV (${server.profileName()})';

Map<String, Object?> discoverJson(LineupServer server, ExportUrls urls, int tunerCount, HdHomeRunIdentity identity) => {
      'FriendlyName': friendlyName(server),
      'Manufacturer': identity.manufacturer,
      'ModelNumber': identity.modelNumber,
      'FirmwareName': identity.firmwareName,
      'FirmwareVersion': identity.firmwareVersion,
      'DeviceID': server.export.deviceId,
      'DeviceAuth': server.export.deviceAuth,
      'BaseURL': '${urls.base}',
      'LineupURL': '${urls.lineupJson}',
      'TunerCount': tunerCount,
    };

List<Map<String, Object?>> lineupJson(List<Channel> lineup, ExportUrls urls) => [
      for (final c in lineup) {'GuideNumber': '${c.number}', 'GuideName': c.name, 'URL': '${urls.stream(c)}', 'HD': 1},
    ];

const lineupStatus = {'ScanInProgress': 0, 'ScanPossible': 1, 'Source': 'Cable', 'SourceList': ['Cable']};

String deviceXml(LineupServer server, ExportUrls urls, HdHomeRunIdentity identity) => '''
<?xml version="1.0" encoding="UTF-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <URLBase>${xmlEscape('${urls.base}')}</URLBase>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaServer:1</deviceType>
    <friendlyName>${xmlEscape(friendlyName(server))}</friendlyName>
    <manufacturer>${xmlEscape(identity.manufacturer)}</manufacturer>
    <modelName>${xmlEscape(identity.modelNumber)}</modelName>
    <modelNumber>${xmlEscape(identity.modelNumber)}</modelNumber>
    <serialNumber>${server.export.deviceId}</serialNumber>
    <UDN>uuid:${deviceUuid(server.export.deviceId)}</UDN>
  </device>
</root>
''';
