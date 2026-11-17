import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/watch_party.dart';

ShareProfile partyProfile(String id, String name) => ShareProfile(userId: id, name: name, handle: name.toLowerCase());

class FakeRoom implements PartyRoom {
  final sent = <(String, Map<String, Object?>)>[];
  final timelines = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Future<void> send(String event, Map<String, Object?> payload) async => sent.add((event, payload));

  @override
  Future<void> sendTimeline(Map<String, Object?> payload) async => timelines.add(payload);

  @override
  Future<void> close() async => closed = true;
}

/// The sharing backend for one account, in memory.
class FakePartyBackend implements PartyBackend {
  FakePartyBackend(this.me, this.clock, {this.offset = Duration.zero});

  final ShareProfile me;
  final DateTime Function() clock;

  /// The backend's clock less this device's.
  final Duration offset;

  PartyInfo? joinInfo;
  PartyJoinStatus joinStatus = PartyJoinStatus.ok;
  bool leaveEnds = true;
  final leaves = <({String party, bool hostGone})>[];
  final starts = <({String channel, Map<String, Object?> state, List<String> invite, bool link})>[];
  final states = <Map<String, Object?>>[];
  final room = FakeRoom();
  void Function(String event, Map<String, dynamic> payload)? onMessage;
  void Function(String user, bool left)? onMember;
  List<PartyInvite> invites = [];
  void Function()? invitesChanged;

  @override
  bool get started => true;
  @override
  String? get userId => me.userId;
  @override
  Future<ShareProfile?> profile() async => me;
  @override
  Future<({DateTime server, Duration rtt})> serverTime() async =>
      (server: clock().add(offset).toUtc(), rtt: const Duration(milliseconds: 0));

  @override
  Future<PartyStarted> startParty(
      {required String channelName, required Map<String, Object?> state, List<String> invite = const [], bool link = false}) async {
    starts.add((channel: channelName, state: state, invite: invite, link: link));
    return (
      party: PartyInfo(id: 'p1', host: me.userId, channelName: channelName, state: state, ended: false, members: [me]),
      invite: link ? FriendInvite('ABCDEF', DateTime(2030)) : null,
    );
  }

  @override
  Future<FriendInvite?> inviteToParty(String party, {List<String> invite = const [], bool link = false}) async => null;

  @override
  Future<(PartyJoinStatus, PartyInfo?)> joinParty(String party) async => (joinStatus, joinInfo);

  @override
  Future<bool> leaveParty(String party, {bool hostGone = false}) async {
    leaves.add((party: party, hostGone: hostGone));
    return leaveEnds;
  }

  @override
  Future<void> writePartyState(String party, Map<String, Object?> state) async => states.add(state);

  @override
  Future<List<ShareProfile>> partyMembers(String party) async => joinInfo?.members ?? [me];

  @override
  Future<List<PartyInvite>> partyInvites() async => invites;


  @override
  Future<PartyRoom> openPartyRoom(String party,
      {required void Function(String event, Map<String, dynamic> payload) onMessage,
      required void Function(String user, bool left) onMember}) async {
    this.onMessage = onMessage;
    this.onMember = onMember;
    return room;
  }

  @override
  Future<void> watchPartyInvites(void Function() onChange) async => invitesChanged = onChange;

  @override
  Future<void> stopWatchingPartyInvites() async => invitesChanged = null;
}

