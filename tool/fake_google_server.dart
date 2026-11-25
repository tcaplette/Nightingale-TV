// A fake Google for live checks of YouTube channels without a Google
// sign-in (youtube-subscriptions): every code is approved at once, and the
// catalog is real, embeddable public videos, so YouTube's own player plays
// them. Run the app with --dart-define=NTV_GOOGLE_FAKE=http://<host>:<port>.
//
//   dart run tool/fake_google_server.dart [port]
//
// The own client it accepts is "own-client" / "own-client-secret"; it also
// accepts the app's bundled client (assets/youtube/client/).
import 'dart:convert';
import 'dart:io';

import '../integration_test/fake_google.dart';

/// Real public videos (Blender Foundation open movies and YouTube's own
/// developer video), with their real lengths.
const _videos = {
  'UCblenderOpenMovies01': ('Blender Open Movies', [
    ('mN0zPOpADL4', 'Agent 327: Operation Barbershop', 232),
    ('WhWc3b3KhnY', 'Spring - Blender Open Movie', 464),
    ('R6MlUcmOul8', 'Tears of Steel - Blender VFX Open Movie', 734),
    ('eRsGyueVLvQ', 'Sintel - Open Movie by Blender Foundation', 888),
  ]),
  'UCbigBuckBunnyClassic': ('Big Buck Bunny Classics', [
    ('YE7VzlLtp-4', 'Big Buck Bunny', 597),
    ('TLkA0RELQ1g', 'Elephants Dream', 654),
    ('aqz-KE-bpKQ', 'Big Buck Bunny 60fps 4K', 635),
  ]),
  'UCyoutubeDevelopers01': ('YouTube Developers', [
    ('M7lc1UVf-VE', 'YouTube Developers Live: Embedded Web Player Customization', 1344),
  ]),
};

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8765 : int.parse(args.first);
  final google = await FakeGoogle.startOn(port);
  var day = 0;
  for (final MapEntry(key: id, value: (title, videos)) in _videos.entries) {
    google.channels[id] = FakeChannel(id, title, videos: [
      for (final (vid, name, seconds) in videos)
        FakeVideo(vid, title: name, length: Duration(seconds: seconds), published: DateTime.utc(2026, 11, 20 - day++)),
    ]);
  }
  // Five more subscriptions with no videos yet, for the shared client's
  // 5-channel limit (youtube-shared-client).
  final extras = [for (var i = 1; i <= 5; i++) 'UCliveCheckExtra0$i'];
  for (final (i, id) in extras.indexed) {
    google.channels[id] = FakeChannel(id, 'Extra Channel ${i + 1}', videos: []);
  }
  // The app's bundled client too, so a build carrying it signs in here.
  final bundled = File('assets/youtube/client/nightingale-tv-youtube.json');
  if (bundled.existsSync()) {
    for (final section in (jsonDecode(bundled.readAsStringSync()) as Map).values) {
      if (section case {'client_id': final String id, 'client_secret': final String secret}) {
        google
          ..clients.add(id)
          ..clientSecrets[id] = secret;
      }
    }
  }
  google
    ..clients.add('shared-client')
    ..accounts['live'] = FakeAccount('live', title: 'Live Check', subscriptions: [..._videos.keys, ...extras])
    ..approveAs = 'live';
  stdout.writeln('fake Google on ${google.url}');
}
