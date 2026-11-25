// Sharing with SMB shares, live (smb-sources 10.8): the app's own sharing
// code against the sharing backend, with tool/share_peer as the other user,
// and the archive Samba share (tool/test_servers) as the library.
//
//   SHARE_LIVE=1 SMB_PASSWORD=… flutter test test/smb/smb_sharing_live_test.dart \
//     --dart-define-from-file=sharing.env
// SHARE_A is the app's account (test-data.md account A), SHARE_B the peer
// (account B), SHARE_B_HANDLE its handle; A and B are friends.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_profile.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';
import 'package:nightingale_tv/sharing/channel_recipe.dart';
import 'package:nightingale_tv/sharing/channel_shares.dart';
import 'package:nightingale_tv/sharing/party_timeline.dart';
import 'package:nightingale_tv/sharing/presence.dart';
import 'package:nightingale_tv/sharing/recipe_matcher.dart';
import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/share_session_store.dart';
import 'package:nightingale_tv/sharing/sharing.dart';

final _env = Platform.environment;
final _live = _env['SHARE_LIVE'] == '1';

/// Runs the share peer; its output.
Future<String> peer(List<String> args) async {
  final r = await Process.run('dart', ['run', 'tool/share_peer/bin/share_peer.dart', ...args]);
  if (r.exitCode != 0) throw StateError('share_peer ${args.first}: ${r.stderr}');
  return '${r.stdout}';
}

void main() {
  late Directory dir;
  late LibraryIndex library;
  late ShareClient a;
  // The recipe the friend received, which they share back.
  Map<String, Object?>? received;
  final emailA = _env['SHARE_A'] ?? '', emailB = _env['SHARE_B'] ?? '', handleB = _env['SHARE_B_HANDLE'] ?? '';

  setUpAll(() async {
    if (!_live) return;
    IndexBuilder.useIsolate = false;
    dir = await Directory.systemTemp.createTemp('smb_sharing');
    // The archive share as the app's library.
    final storage = await AppStorage.at(Directory('${dir.path}/p'), logosDir: Directory('${dir.path}/logos'));
    final ready = <bool>[];
    final profile = SmbProfile(storage,
        profileName: () => 'Sam', hold: ValueNotifier(false), onFilesReady: (s, {required last}) => ready.add(last), onChanged: () {});
    final ref = await profile.secrets.put(SmbCredentials(user: 'smbtest', password: _env['SMB_PASSWORD'] ?? ''));
    profile.configOf('share-live')
      ..mappings = const [SmbMapping('Names/Movies', SmbFolderType.movies), SmbMapping('Home', SmbFolderType.homeVideos)]
      ..keepLocal = true;
    await profile.saveConfig('share-live');
    await SmbGateway.ensureStarted();
    final server = profile.client(ServerSession(
        kind: ServerKind.smb, serverUrl: 'smb://127.0.0.1:1445/archive', serverName: 'archive', serverId: 'share-live',
        userId: 'smbtest', userName: 'smbtest', accessToken: ref, deviceId: 'd'));
    library = await server.fetchLibraryIndex();
    // Every file read, then the library as the app builds it next.
    for (var i = 0; i < 600 && !ready.contains(true); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    server.rebuildNext();
    library = await server.fetchLibraryIndex();
    server.close();
    // The app's account, signed in with a code the backend made.
    a = ShareClient(profileId: 'p1', store: ShareSessionStore(storage), url: Sharing.url, key: Sharing.key);
    await a.start();
    final code = RegExp(r'\b\d{6}\b').firstMatch(await peer(['otp', emailA]))![0]!;
    expect(await a.verifyCode(emailA, code), isTrue);
  });

  tearDownAll(() async {
    if (!_live) return;
    await a.dispose();
    await SmbGateway.stop();
    await dir.delete(recursive: true);
  });

  test("a share's channel goes to a friend: its movies, nothing of its home videos", () async {
    final movies = library.movies.where((m) => !m.isHome).toList();
    final home = library.episodes.where((e) => e.isHome).toList();
    expect(movies, isNotEmpty);
    expect(home, isNotEmpty);
    final channel = Channel(
      id: 'c-share-live',
      number: 40,
      name: 'Share Night',
      icon: const ChannelIcon.builtin('movie'),
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: [...movies.map((m) => m.id), ...home.map((e) => e.id)],
      anchor: DateTime.now(),
    );
    final recipe = ChannelRecipe.fromChannel(channel, const [], library);
    // As the app sends it: a new id, to the friend's user id.
    final friend = (await a.friends()).friends.firstWhere((f) => f.handle == handleB);
    final sharedId = ChannelShares.newShareId();
    await a.shareChannels([(id: sharedId, name: channel.name, recipe: recipe.toJson())], to: [friend.userId]);
    addTearDown(() => peer(['remove-shared', emailA, sharedId]));
    // What the friend's app receives.
    final got = jsonDecode(await peer(['recipe', emailB, sharedId]).then((s) => s.substring(s.indexOf('{')))) as Map;
    received = got.cast<String, Object?>();
    final text = jsonEncode(got);
    for (final m in movies) {
      expect(text, contains(m.title), reason: 'the movie ${m.title} goes as a recipe item');
    }
    for (final e in home) {
      expect(text, isNot(contains(e.title)), reason: 'a home video never leaves the device');
      expect(text, isNot(contains(e.id)));
    }
    expect(text, isNot(contains('smb://')));
    expect(text, isNot(contains('archive')));
  }, skip: !_live, timeout: const Timeout(Duration(minutes: 2)));

  test("a friend's Jellyfin channel comes back and is rebuilt from the share", () async {
    // The friend (on Jellyfin) shares back what they received, as their app
    // would: a recipe of titles, years and ids, nothing of the share.
    final recipeBack = received?['recipe'] ?? received;
    final back = {...(recipeBack! as Map).cast<String, Object?>(), 'name': 'From Tyler'};
    final movies = library.movies.where((m) => !m.isHome).toList();
    final file = File('${dir.path}/back.json')..writeAsStringSync(jsonEncode(back));
    debugPrint('peer: ${await peer(['share-channels', emailB, file.path, '--to', _env['SHARE_A_HANDLE'] ?? ''])}');
    final share = (await a.channelShares()).where((s) => s.name == 'From Tyler' && !s.ended).last;
    addTearDown(() => peer(['remove-shared', emailB, share.sharedChannelId]));
    await a.setShareState(share.id, 'added');
    final got = (await a.sharedRecipe(share.sharedChannelId))!;
    final match = await RecipeMatcher.run(ChannelRecipe.fromJson(got.recipe), library);
    expect(match.matched, movies.length, reason: 'every movie found on the share');
    expect(match.playlist.toSet(), movies.map((m) => m.id).toSet());
  }, skip: !_live, timeout: const Timeout(Duration(minutes: 2)));

  test('a home video: friends see no title, a party shows "Home video"', () async {
    final home = library.episodes.firstWhere((e) => e.isHome);
    // Presence, as the app publishes it while a home video is on.
    final title = presenceTitle(ScheduledProgram(item: home, start: DateTime.now(), end: DateTime.now().add(home.runtime)));
    expect(title, isNull);
    await a.setWatching(Watching(title: title, channelName: 'Family', startedAt: DateTime.now()));
    addTearDown(() => a.setWatching(null));
    final rows = await peer(['presence', emailB]);
    expect(rows, contains('Family'));
    expect(rows, isNot(contains(home.title)));
    expect(rows, isNot(contains(home.seriesName ?? '-')));
    // A party's timeline item for it.
    final item = PartyItem.of(home, library)!;
    expect(item.item.ids, [homeVideoId]);
    expect(jsonEncode(item.item.toJson()), isNot(contains(home.title)));
  }, skip: !_live, timeout: const Timeout(Duration(minutes: 2)));
}
