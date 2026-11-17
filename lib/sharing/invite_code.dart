import 'sharing.dart';

/// Invite codes (share-accounts, "Invite codes and links"): 6 characters
/// from an alphabet without look-alikes (no I, L, O, 0 or 1).
abstract final class InviteCode {
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 6;

  /// The dot shown in the middle of a code: `AB3K·9Q`.
  static const dot = '·';

  static final _valid = RegExp('^[$alphabet]{$length}\$');

  /// [input] as a code, in any case, with or without spaces, dots or the
  /// display dot; null when it isn't one.
  static String? clean(String input) {
    final code = input.toUpperCase().replaceAll(RegExp(r'[\s.·•\-_]'), '');
    return _valid.hasMatch(code) ? code : null;
  }

  /// `AB3K9Q` as `AB3K·9Q`.
  static String display(String code) => '${code.substring(0, 4)}$dot${code.substring(4)}';

  /// The invite link for [code]: `https://<host>/ntv/i/<CODE>`.
  static String link(String code, {String host = Sharing.host}) => 'https://$host/ntv/i/$code';

  /// The code in an invite link that opened the app, or null when the link
  /// isn't one: another host, another path or a malformed code.
  static String? fromLink(String link, {String host = Sharing.host}) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'https' || host.isEmpty || uri.host.toLowerCase() != host.toLowerCase()) {
      return null;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 3 || segments[0] != 'ntv' || segments[1] != 'i') return null;
    return clean(segments[2]);
  }
}
