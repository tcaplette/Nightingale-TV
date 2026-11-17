import 'package:flutter/foundation.dart';

import 'share_client.dart';

/// The six party reactions, in the party row's order (watch-together,
/// "Reactions").
const partyReactions = ['😂', '😮', '❤️', '👏', '😱', '🍿'];

/// A member sends at most one reaction per [every]; extra presses are
/// ignored. The sender's app and every receiver apply it, so a member
/// sending faster (another app, the phone remote) shows no more than that.
class ReactionLimiter {
  ReactionLimiter({this.every = const Duration(seconds: 1), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Duration every;
  final DateTime Function() _clock;
  final _last = <String, DateTime>{};

  /// Whether [who] may react now; if so, it counts as their reaction.
  bool allow(String who) {
    final now = _clock();
    final last = _last[who];
    if (last != null && now.difference(last) < every) return false;
    _last[who] = now;
    return true;
  }

  void clear() => _last.clear();
}

/// A reaction on screen: the emoji rising with its sender's avatar for
/// [shownFor] (D8).
@immutable
class FloatingReaction {
  const FloatingReaction({required this.id, required this.emoji, required this.from, required this.at});

  static const shownFor = Duration(seconds: 3);

  final int id;
  final String emoji;

  /// The sender's profile, when it's known.
  final ShareProfile? from;
  final DateTime at;
}
