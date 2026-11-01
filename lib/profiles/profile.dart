import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

enum ProfileKind { adult, kid }

/// How much a kid profile is allowed to watch, as the highest rating rank
/// it can see (see [ratingRank]).
enum KidRating {
  young(1, 'Young kids', 'TV-Y and TV-Y7'),
  kids(2, 'Kids', 'Up to TV-G and G'),
  older(3, 'Older kids', 'Up to TV-PG and PG');

  const KidRating(this.maxRank, this.label, this.description);

  final int maxRank;
  final String label;
  final String description;
}

/// Orders content ratings from youngest to most mature (US TV and film, plus
/// the common UK film ratings). Null for unknown ratings; kid profiles leave
/// those out, since there's no telling what they are.
int? ratingRank(String? rating) {
  if (rating == null) return null;
  var r = rating.trim().toUpperCase().replaceAll(' ', '-');
  if (r.startsWith('US-') || r.startsWith('GB-') || r.startsWith('UK-')) r = r.substring(3);
  return const {
    'TV-Y': 0,
    'TV-Y7': 1,
    'TV-Y7-FV': 1,
    'TV-G': 2,
    'G': 2,
    'U': 2,
    'TV-PG': 3,
    'PG': 3,
    'TV-14': 4,
    'PG-13': 4,
    '12': 4,
    '12A': 4,
    'TV-MA': 5,
    'R': 5,
    '15': 5,
    'NC-17': 6,
    '18': 6,
    'X': 6,
    'XXX': 6,
  }[r];
}

/// Someone who watches: their own Jellyfin sign-in, channels and settings.
class Profile {
  Profile({
    required this.id,
    required this.name,
    this.kind = ProfileKind.adult,
    this.rating = KidRating.kids,
    this.color = 0,
    this._pinHash,
    this._pinSalt,
  });

  final String id;
  String name;
  ProfileKind kind;

  /// Only used for kid profiles.
  KidRating rating;

  /// Index into the avatar palette.
  int color;

  /// A kid's rating limit was loosened; rescan the library next time.
  bool needsRescan = false;
  String? _pinHash;
  String? _pinSalt;

  bool get isKid => kind == ProfileKind.kid;
  bool get hasPin => _pinHash != null;

  /// The highest rating rank this profile may watch; null for no limit.
  int? get maxRatingRank => isKid ? rating.maxRank : null;

  static bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  /// Sets (or with null, removes) the PIN. Only a salted hash is kept.
  void setPin(String? pin) {
    if (pin == null) {
      _pinHash = _pinSalt = null;
      return;
    }
    assert(isValidPin(pin));
    final rng = Random.secure();
    _pinSalt = base64Url.encode(List.generate(16, (_) => rng.nextInt(256)));
    _pinHash = _hash(pin, _pinSalt!);
  }

  /// An independent copy, for editing without touching the original.
  Profile copy() => Profile.fromJson(toJson());

  bool checkPin(String pin) => _pinHash != null && _hash(pin, _pinSalt!) == _pinHash;

  static String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        if (isKid) 'rating': rating.name,
        'color': color,
        if (needsRescan) 'needsRescan': true,
        if (_pinHash != null) 'pinHash': _pinHash,
        if (_pinSalt != null) 'pinSalt': _pinSalt,
      };

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: ProfileKind.values.byName(j['kind'] as String? ?? 'adult'),
        rating: KidRating.values.byName(j['rating'] as String? ?? KidRating.kids.name),
        color: j['color'] as int? ?? 0,
        pinHash: j['pinHash'] as String?,
        pinSalt: j['pinSalt'] as String?,
      )..needsRescan = j['needsRescan'] as bool? ?? false;
}
