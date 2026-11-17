import '../playback/tuner.dart';
import 'watch_party.dart';

/// Pause, skip, restart and Live as the viewer pressed them (timeshift,
/// "Timeshift in a watch party"): in a party they act on the whole party,
/// through [party]; otherwise on [tuner] alone, as before.
class Transport {
  const Transport(this.tuner, this.party);

  final Tuner tuner;
  final WatchParty? party;

  bool get _inParty => party?.active ?? false;

  Future<void> togglePause() async {
    if (_inParty) {
      party!.togglePause();
    } else {
      await tuner.togglePause();
    }
  }

  Future<void> pause() async {
    if (_inParty) {
      party!.act('pause');
    } else {
      await tuner.pause();
    }
  }

  Future<void> resume() async {
    if (_inParty) {
      party!.act('resume');
    } else {
      await tuner.resume();
    }
  }

  void skip(Duration by) {
    if (_inParty) {
      party!.act('skip', by: by);
    } else {
      tuner.skip(by);
    }
  }

  /// A drag on the seek bar: in a party, a skip by the distance dragged.
  void seekTo(DateTime target) {
    if (_inParty) {
      party!.act('skip', by: target.difference(tuner.seekTarget ?? tuner.viewNow()));
    } else {
      tuner.seekTo(target);
    }
  }

  Future<void> restart() async {
    if (_inParty) {
      party!.act('restart');
    } else {
      await tuner.restart();
    }
  }

  Future<void> goLive() async {
    if (_inParty) {
      party!.act('live');
    } else {
      await tuner.goLive();
    }
  }
}
