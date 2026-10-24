/// Playlist, guide and stream URLs often hold the IPTV provider's user name
/// and password (live-tv-sources "Source privacy").
library;

/// [url] for logs and diagnostics: without its query string, fragment and
/// user information. Text that isn't a URL becomes "(not a URL)".
String scrubUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !u.hasScheme) return '(not a URL)';
  final port = u.hasPort ? ':${u.port}' : '';
  return '${u.scheme}://${u.host}$port${u.path}';
}

/// Query names that carry a secret.
final _secretParam = RegExp(r'^(pass(word|wd)?|pwd|token|key|api[_-]?key|auth|secret|sig(nature)?)$', caseSensitive: false);

/// [url] for showing in the UI: the password in its user information and
/// secret query values (password, token, key…) replaced with dots.
String maskUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !u.hasScheme) return url;
  var info = u.userInfo;
  final colon = info.indexOf(':');
  if (colon >= 0) info = '${info.substring(0, colon)}:••••';
  final query = u.hasQuery
      ? [
          for (final part in u.query.split('&'))
            if (part.contains('='))
              _secretParam.hasMatch(Uri.decodeQueryComponent(part.substring(0, part.indexOf('='))))
                  ? '${part.substring(0, part.indexOf('='))}=••••'
                  : part
            else
              part,
        ].join('&')
      : null;
  final port = u.hasPort ? ':${u.port}' : '';
  final auth = info.isEmpty ? '' : '$info@';
  return '${u.scheme}://$auth${u.host}$port${u.path}${query == null ? '' : '?$query'}${u.hasFragment ? '#${u.fragment}' : ''}';
}

/// Every URL in [text] scrubbed (see [scrubUrl]), for messages that quote
/// one.
String scrubUrlsIn(String text) =>
    text.replaceAllMapped(RegExp(r'''[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s'"<>]+'''), (m) {
      // Punctuation after a URL belongs to the sentence.
      final url = m[0]!;
      final trailing = RegExp(r'[.,;:!?)\]]+$').firstMatch(url)?[0] ?? '';
      return scrubUrl(url.substring(0, url.length - trailing.length)) + trailing;
    });
