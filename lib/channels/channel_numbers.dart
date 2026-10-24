import 'dart:math';

import 'channel.dart';

/// Channel numbers, owned in one place so generated and live channels never
/// share one (live-tv-sources D7).
abstract final class ChannelNumbers {
  /// The lowest number from [from] up that isn't in [taken].
  static int nextFree(Set<int> taken, {int from = 1}) {
    var n = max(from, 1);
    while (taken.contains(n)) {
      n++;
    }
    return n;
  }

  /// Where a new source's live channels start: the first multiple of 100
  /// above the highest number in [used].
  static int liveBlockStart(Iterable<int> used) {
    final highest = used.fold(0, max);
    return (highest ~/ 100 + 1) * 100;
  }

  /// Numbers [channels] in their order from [start] up, skipping [taken].
  static void numberSkipping(List<Channel> channels, Set<int> taken, {int start = 2}) {
    var next = start;
    for (final c in channels) {
      c.number = nextFree(taken, from: next);
      next = c.number + 1;
    }
  }

  /// The number after the highest generated (not live) channel in
  /// [channels], skipping numbers anything holds: where a new generated
  /// channel goes.
  static int nextGenerated(Iterable<Channel> channels) {
    final taken = {for (final c in channels) c.number};
    final highest = channels.where((c) => !c.isLive).fold(1, (n, c) => max(n, c.number));
    return nextFree(taken, from: highest + 1);
  }
}
