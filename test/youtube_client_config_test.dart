// youtube-shared-client 1.3, 4.4: the shared Google client comes from the
// bundled asset; a missing or bad file leaves it null, and server mode never
// loads it.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

const _download = '{"installed":{"client_id":"shared-id.apps.googleusercontent.com",'
    '"project_id":"p","client_secret":"shared-secret","token_uri":"https://oauth2.googleapis.com/token"}}';

void main() {
  tearDown(() => GoogleClient.loadShared(bundle: _Bundle(const {})));

  test('a valid client file becomes the shared client, not an own one', () async {
    await GoogleClient.loadShared(bundle: _Bundle({GoogleClient.sharedAsset: _download}));
    final shared = GoogleClient.shared!;
    expect(shared.id, 'shared-id.apps.googleusercontent.com');
    expect(shared.secret, 'shared-secret');
    expect(shared.own, isFalse);
  });

  test('no file: no shared client', () async {
    await GoogleClient.loadShared(bundle: _Bundle({GoogleClient.sharedAsset: _download}));
    await GoogleClient.loadShared(bundle: _Bundle(const {}));
    expect(GoogleClient.shared, isNull);
  });

  test('a malformed file: no shared client', () async {
    for (final bad in ['{not json', '[]', '{"installed":{"client_id":"x"}}', '{"installed":{"client_id":"","client_secret":""}}']) {
      await GoogleClient.loadShared(bundle: _Bundle({GoogleClient.sharedAsset: bad}));
      expect(GoogleClient.shared, isNull, reason: bad);
    }
  });

  test('server mode leaves it null with the file in place', () async {
    await GoogleClient.loadShared(serverMode: true, bundle: _Bundle({GoogleClient.sharedAsset: _download}));
    expect(GoogleClient.shared, isNull);
  });

  test('the override still wins for tests', () async {
    GoogleClient.sharedOverride = const GoogleClient(id: 'o', secret: 's');
    addTearDown(() => GoogleClient.sharedOverride = null);
    await GoogleClient.loadShared(bundle: _Bundle(const {}));
    expect(GoogleClient.shared?.id, 'o');
  });
}
