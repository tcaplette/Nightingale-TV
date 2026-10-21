import '../channels/channel.dart';

/// URLs an exported profile serves, from its base address.
extension type const ExportUrls(Uri base) {
  Uri get m3u => base.replace(path: '/lineup.m3u');
  Uri get xmltv => base.replace(path: '/xmltv.xml');
  Uri get lineupJson => base.replace(path: '/lineup.json');
  Uri get deviceXml => base.replace(path: '/device.xml');
  Uri stream(Channel c) => base.replace(path: '/stream/${c.number}.ts');
  Uri logo(Channel c) => base.replace(path: '/logos/${c.number}.png');
  Uri image(String itemId) => base.replace(path: '/images/$itemId.jpg');
}

/// The extended M3U playlist of [channels] (visible ones, in number order),
/// for Jellyfin's M3U tuner and IPTV players. Each entry's `group-title` is
/// [groupOf] it (its channel group, lineup-export), else the profile's.
String buildM3u(
    {required List<Channel> channels,
    required ExportUrls urls,
    required String profileName,
    String? Function(Channel c)? groupOf}) {
  final out = StringBuffer('#EXTM3U url-tvg="${urls.xmltv}" x-tvg-url="${urls.xmltv}"\n');
  final fallback = profileGroup(profileName);
  for (final c in channels) {
    final name = _attr(c.name);
    final group = _attr(groupOf?.call(c) ?? fallback);
    out
      ..write('#EXTINF:-1 tvg-id="${c.number}" tvg-chno="${c.number}" tvg-name="$name" ')
      ..write('tvg-logo="${urls.logo(c)}" group-title="$group",${_title(c.name)}\n')
      ..write('${urls.stream(c)}\n');
  }
  return out.toString();
}

/// The group of channels in no group of their own.
String profileGroup(String profileName) => 'Nightingale TV · $profileName';

/// Attribute values can't hold a double quote or a line break.
String _attr(String s) => s.replaceAll('"', "'").replaceAll(RegExp(r'[\r\n]+'), ' ');

/// The display name ends the line.
String _title(String s) => s.replaceAll(RegExp(r'[\r\n]+'), ' ');
