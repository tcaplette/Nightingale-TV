import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/media_server.dart';

/// Every request a Jellyfin profile sends, exactly as the Jellyfin-only
/// client sent them before servers became pluggable (media-servers spec:
/// "Jellyfin requests are unchanged"): method, path, query in order,
/// headers and body.
void main() {
  late List<http.Request> sent;
  JellyfinClient client() {
    sent = [];
    return JellyfinClient(
      serverUrl: 'https://jf.example:8920',
      deviceId: 'nightingaletv-0a1b',
      deviceName: 'Living room',
      accessToken: 'tok',
      userId: 'u1',
      httpClient: MockClient((r) async {
        sent.add(r);
        if (r.url.path == '/UserViews') {
          return http.Response(
              jsonEncode({
                'Items': [
                  {'Id': 'tv', 'Name': 'TV', 'CollectionType': 'tvshows'},
                  {'Id': 'mu', 'Name': 'Music', 'CollectionType': 'music'},
                ]
              }),
              200);
        }
        if (r.url.path.endsWith('/PlaybackInfo')) {
          return http.Response(
              jsonEncode({
                'MediaSources': [
                  {
                    'Id': 'e1',
                    'SupportsDirectPlay': false,
                    'TranscodingUrl': '/videos/e1/stream.ts?DeviceId=nightingaletv-0a1b&MediaSourceId=e1'
                        '&api_key=tok&VideoCodec=h264&TranscodeReasons=ContainerBitrateExceedsLimit',
                  }
                ]
              }),
              200);
        }
        if (r.url.path == '/Items') return http.Response(jsonEncode({'Items': [], 'TotalRecordCount': 0}), 200);
        return http.Response('', 204);
      }),
    );
  }

  const auth = 'MediaBrowser Client="Nightingale TV", Device="Living room", DeviceId="nightingaletv-0a1b", '
      'Version="${JellyfinClient.clientVersion}", Token="tok"';

  String line(http.Request r) => '${r.method} ${r.url}';

  test('every request carries the same headers', () async {
    await client().checkSession();
    expect(sent.single.headers, {'Authorization': auth, 'Accept': 'application/json'});
    expect(line(sent.single), 'GET https://jf.example:8920/Users/Me');
  });

  test('a library refresh', () async {
    final c = client();
    await c.fetchLibraryIndex(pools: [
      CommercialPool(id: 'p', name: 'Ads', roots: [const PoolRoot(itemId: 'ads', libraryId: 'ads', label: 'Ads')]),
    ]);
    expect(sent.map(line), [
      'GET https://jf.example:8920/UserViews?userId=u1',
      'GET https://jf.example:8920/Items?ParentId=ads&Recursive=true&IncludeItemTypes=Movie%2CEpisode%2CVideo%2CMusicVideo%2CTrailer'
          '&IsMissing=false&Fields=Chapters%2CEtag&EnableImages=false&EnableUserData=false&userId=u1&StartIndex=0&Limit=500',
      'GET https://jf.example:8920/Items?ParentId=tv&Recursive=true&ImageTypeLimit=1&IncludeItemTypes=Series'
          '&Fields=Genres%2COfficialRating&userId=u1&StartIndex=0&Limit=500',
      'GET https://jf.example:8920/Items?ParentId=tv&Recursive=true&ImageTypeLimit=1&IncludeItemTypes=Episode&IsMissing=false'
          '&Fields=Overview%2CChapters%2CEtag%2CDateCreated&EnableImages=false&EnableUserData=false&userId=u1&StartIndex=0&Limit=500',
      'GET https://jf.example:8920/Items?ParentId=tv&Recursive=true&ImageTypeLimit=1&IncludeItemTypes=Movie'
          '&Fields=Overview%2CGenres%2COfficialRating%2CChapters%2CEtag&EnableImages=false&EnableUserData=false&userId=u1&StartIndex=0&Limit=500',
      'GET https://jf.example:8920/Items?ParentId=tv&Recursive=true&ImageTypeLimit=1&IncludeItemTypes=MusicVideo&IsMissing=false'
          '&Fields=Genres%2CProductionYear%2CArtists%2CAlbumArtist%2CAlbum%2CAlbumId%2COfficialRating%2CEtag%2CMediaSources'
          '&EnableImages=false&EnableUserData=false&userId=u1&StartIndex=0&Limit=500',
      'GET https://jf.example:8920/Items?ParentId=mu&Recursive=true&ImageTypeLimit=1&IncludeItemTypes=Audio&IsMissing=false'
          '&Fields=Genres%2CProductionYear%2CArtists%2CAlbumArtist%2CAlbum%2CAlbumId%2COfficialRating%2CEtag%2CMediaSources'
          '&EnableImages=false&EnableUserData=false&userId=u1&StartIndex=0&Limit=500',
    ]);
  });

  test('the folder picker', () async {
    await client().folderTree('ads');
    expect(sent.map(line), [
      'GET https://jf.example:8920/Items?ParentId=ads&Recursive=true&IncludeItemTypes=Folder%2CSeries%2CSeason%2CBoxSet'
          '&Fields=ParentId&EnableImages=false&EnableUserData=false&userId=u1&StartIndex=0&Limit=500',
    ]);
  });

  test('tuning and surfing: the original file, keep-warm, artwork, segments', () async {
    final c = client();
    expect('${c.streamUri('e1')}', 'https://jf.example:8920/Videos/e1/stream?static=true&mediaSourceId=e1');
    expect('${c.pingUri}', 'https://jf.example:8920/System/Ping');
    expect('${c.imageUri('s1', ImageKind.primary, maxHeight: 640)}',
        'https://jf.example:8920/Items/s1/Images/Primary?maxHeight=640&quality=90');
    expect('${c.imageUri('s1', ImageKind.logo, maxHeight: 160)}',
        'https://jf.example:8920/Items/s1/Images/Logo?maxHeight=160&quality=90');
    expect(c.authHeaders, {'Authorization': auth});
    await c.commercialSegments('e1');
    expect(line(sent.single), 'GET https://jf.example:8920/MediaSegments/e1?includeSegmentTypes=Commercial');
  });

  test('a transcode: the decision, the job, the stop and the reports', () async {
    final c = client();
    final d = await c.playbackDecision('e1', maxBitrate: 4000000, startAt: const Duration(seconds: 30));
    final decision = sent.single;
    expect(line(decision), 'POST https://jf.example:8920/Items/e1/PlaybackInfo');
    expect(decision.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(decision.body), {
      'UserId': 'u1',
      'MediaSourceId': 'e1',
      'MaxStreamingBitrate': 4000000,
      'StartTimeTicks': 300000000,
      'AutoOpenLiveStream': false,
      'EnableDirectPlay': true,
      'EnableDirectStream': true,
      'EnableTranscoding': true,
      'AllowVideoStreamCopy': true,
      'AllowAudioStreamCopy': true,
      'DeviceProfile': JellyfinClient.deviceProfile(4000000),
    });
    final job = await c.transcodeUri(d.transcodeTemplate!, playSessionId: 'job1', startAt: const Duration(seconds: 90));
    expect('$job',
        'https://jf.example:8920/videos/e1/stream.ts?DeviceId=nightingaletv-0a1b&MediaSourceId=e1&VideoCodec=h264'
        '&TranscodeReasons=ContainerBitrateExceedsLimit&PlaySessionId=job1&StartTimeTicks=900000000');
    expect(sent, hasLength(1), reason: 'a Jellyfin job needs no request of its own');

    await c.stopTranscode('job1');
    expect(line(sent.last), 'DELETE https://jf.example:8920/Videos/ActiveEncodings?deviceId=nightingaletv-0a1b&playSessionId=job1');
    const report = PlaybackReport(
        itemId: 'e1',
        playSessionId: 'job1',
        position: Duration(seconds: 95),
        playMethod: PlayMethod.transcode,
        runtime: Duration(minutes: 22));
    await c.reportPlaybackStart(report);
    await c.reportPlaybackProgress(report);
    await c.reportPlaybackStopped(report);
    expect(sent.skip(2).map(line), [
      'POST https://jf.example:8920/Sessions/Playing',
      'POST https://jf.example:8920/Sessions/Playing/Progress',
      'POST https://jf.example:8920/Sessions/Playing/Stopped',
    ]);
    // The runtime Plex needs isn't sent to Jellyfin.
    expect(jsonDecode(sent.last.body), {
      'ItemId': 'e1',
      'MediaSourceId': 'e1',
      'PlaySessionId': 'job1',
      'PositionTicks': 950000000,
      'IsPaused': false,
      'CanSeek': false,
      'PlayMethod': 'Transcode',
    });
  });

  test('a forced conversion with an Android profile', () async {
    final profile = {'Name': 'x', 'MaxStreamingBitrate': 1000000000};
    await client().playbackDecision('e1', forceTranscode: true, profile: profile);
    expect(jsonDecode(sent.single.body), {
      'UserId': 'u1',
      'MediaSourceId': 'e1',
      'MaxStreamingBitrate': 1000000000,
      'StartTimeTicks': 0,
      'AutoOpenLiveStream': false,
      'EnableDirectPlay': false,
      'EnableDirectStream': false,
      'EnableTranscoding': true,
      'AllowVideoStreamCopy': false,
      'AllowAudioStreamCopy': false,
      'DeviceProfile': profile,
    });
  });

  test('sign-out, and the saved sign-in', () async {
    await client().logout();
    expect(line(sent.single), 'POST https://jf.example:8920/Sessions/Logout');
    expect(sent.single.body, '{}');
    const session = ServerSession(
        serverUrl: 'https://jf.example:8920',
        serverName: 'Den',
        userId: 'u1',
        userName: 'howard',
        accessToken: 'tok',
        deviceId: 'nightingaletv-0a1b',
        serverId: 'sid');
    // session.json as before: no kind, no Plex fields.
    expect(session.toJson(), {
      'serverUrl': 'https://jf.example:8920',
      'serverName': 'Den',
      'userId': 'u1',
      'userName': 'howard',
      'accessToken': 'tok',
      'deviceId': 'nightingaletv-0a1b',
      'serverId': 'sid',
    });
    expect(ServerSession.fromJson(session.toJson()).kind, ServerKind.jellyfin);
  });
}
