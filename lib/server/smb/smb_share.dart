import 'dart:typed_data';

/// Why a share couldn't be used (smb-sources).
enum SmbErrorKind {
  /// The host didn't answer, or the connection was lost.
  unreachable,

  /// The user name or password is wrong.
  wrongSignIn,

  /// The host (or share) lets no guest in: it wants a user name.
  guestsRefused,

  /// Signed in, but not allowed there.
  noAccess,

  /// The share, folder or file isn't there.
  gone,

  other,
}

class SmbException implements Exception {
  const SmbException(this.kind, this.message);

  final SmbErrorKind kind;

  /// For the log; never shown, and never holding a password.
  final String message;

  @override
  String toString() => 'SmbException(${kind.name}): $message';
}

/// A share's address: `smb://host[:port]/share`.
class SmbAddress {
  const SmbAddress({required this.host, this.port = defaultPort, this.share = ''});

  static const defaultPort = 445;

  final String host;
  final int port;

  /// Empty for a host alone (its shares are listed next).
  final String share;

  SmbAddress withShare(String share) => SmbAddress(host: host, port: port, share: share);

  bool get _v6 => host.contains(':');

  /// `host`, or `host:port` when the port isn't the usual one.
  String get authority => [_v6 ? '[$host]' : host, if (port != defaultPort) '$port'].join(':');

  /// How the SMB library takes it.
  String get target => authority;

  String get url => share.isEmpty ? 'smb://$authority' : 'smb://$authority/$share';

  /// Whether [input] is an SMB address by its form (`smb://…`, `\\…`), as
  /// opposed to a media server's.
  static bool looksLike(String input) {
    final s = input.trim().toLowerCase();
    return s.startsWith('smb:') || s.startsWith(r'\\') || s.startsWith('cifs:');
  }

  /// [input] as an address: `smb://host/share`, `smb://host:port/share`,
  /// `\\host\share`, `host/share` or `host`. Anything after the share is
  /// left out, and so is a user name. Null when it isn't one.
  static SmbAddress? parse(String input) {
    var s = input.trim().replaceAll(r'\', '/').replaceFirst(RegExp(r'^(smb|cifs):', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^/+'), '');
    final parts = s.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    var authority = parts.first;
    final at = authority.lastIndexOf('@');
    if (at >= 0) authority = authority.substring(at + 1);
    final m = RegExp(r'^(?:\[([0-9a-fA-F:.%a-zA-Z]+)\]|([^\s:\[\]]+))(?::(\d{1,5}))?$').firstMatch(authority);
    if (m == null) return null;
    final port = m[3] == null ? defaultPort : int.parse(m[3]!);
    if (port < 1 || port > 65535) return null;
    final share = parts.length > 1 ? _decode(parts[1]) : '';
    return SmbAddress(host: m[1] ?? m[2]!, port: port, share: share);
  }

  static String _decode(String part) {
    if (!part.contains('%')) return part;
    try {
      return Uri.decodeComponent(part);
    } on ArgumentError {
      return part;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SmbAddress &&
      other.host.toLowerCase() == host.toLowerCase() &&
      other.port == port &&
      other.share.toLowerCase() == share.toLowerCase();

  @override
  int get hashCode => Object.hash(host.toLowerCase(), port, share.toLowerCase());

  @override
  String toString() => url;
}

/// How a share is signed in to. [password] is only ever in memory.
class SmbCredentials {
  const SmbCredentials({required this.user, required this.password, this.domain = ''});

  /// A guest: no user name.
  const SmbCredentials.guest()
      : user = '',
        password = '',
        domain = '';

  final String user;
  final String password;
  final String domain;

  bool get isGuest => user.isEmpty;

  @override
  String toString() => isGuest ? 'guest' : 'user with a password';
}

/// A file or folder of a share.
class SmbEntry {
  const SmbEntry({
    required this.name,
    required this.isFolder,
    this.size = 0,
    this.modified,
    this.created,
    this.hidden = false,
    this.fileId = 0,
  });

  final String name;
  final bool isFolder;
  final int size;
  final DateTime? modified;
  final DateTime? created;

  /// Hidden or system, as the host marks it.
  final bool hidden;

  /// The host's own id for it; 0 when it gives none.
  final int fileId;
}

/// A share of a host, for picking one.
class SmbShareInfo {
  const SmbShareInfo(this.name, {this.comment = ''});

  final String name;
  final String comment;
}

/// An open file, read at any position.
abstract interface class SmbReader {
  int get size;

  /// Up to [length] bytes at [offset]; fewer only at the end of the file.
  Future<Uint8List> read(int offset, int length);

  Future<void> close();
}

/// A connected share (design D2). Paths are relative to it, with `/`
/// between folders, and `''` is its root. Everything throws [SmbException].
abstract interface class SmbShare {
  /// Connected with SMB1 (old and not encrypted).
  bool get smb1;

  Future<List<SmbEntry>> list(String path);

  Future<SmbEntry> stat(String path);

  Future<SmbReader> open(String path);

  /// Replaces [path] with [data].
  Future<void> write(String path, Uint8List data);

  /// Renames [from] to [to], replacing it.
  Future<void> rename(String from, String to);

  /// Makes folder [path] and the ones above it; fine when it's there.
  Future<void> makeFolder(String path);

  Future<void> delete(String path);

  Future<void> close();
}

extension SmbShareReads on SmbShare {
  /// A whole small file (up to [limit] bytes).
  Future<Uint8List> readAll(String path, {int limit = 8 << 20}) async {
    final reader = await open(path);
    try {
      return await reader.read(0, reader.size < limit ? reader.size : limit);
    } finally {
      await reader.close();
    }
  }
}

/// Joins share paths.
String smbJoin(String folder, String name) => folder.isEmpty ? name : '$folder/$name';
