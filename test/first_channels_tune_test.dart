// The TV screen shown before there are channels (a share's first files still
// being read, smb-sources) tunes the first channel once channels come, as
// any start does; after that, refreshes leave the channel alone.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

import 'fake_playback.dart';
import 'portrait_harness.dart';

/// A server whose library is [index], with no network.
class _Library extends FakeClient {
  _Library(this.index) : super([]);
  LibraryIndex index;

  @override
  Future<LibraryIndex> fetchLibraryIndex(
          {List<CommercialPool> pools = const [],
          Set<String> channelRoots = const {},
          bool providerIds = false,
          void Function(String status)? onStatus,
          void Function(List<ServerLibrary> libraries)? onLibraries}) async =>
      index;
}

void main() {
  for (final (name, window) in [('TV', const Size(1920, 1080)), ('phone', const Size(412, 915))]) {
    testWidgets('$name: no channels at first, then channel 1 tunes when they come', (tester) async {
      runAs(window.height > window.width ? TargetPlatform.android : TargetPlatform.linux);
      setWindow(tester, window);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('nightingale_tv/orientation'), (call) async => null);
      final h = await PortraitHarness.start(tester, library: LibraryIndex.empty);
      expect(h.app.channels, isEmpty);
      await h.show(tester, const TvScreen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.tuner.channel, isNull);

      final server = _Library(portraitLibrary());
      h.app.client = server;
      await tester.runAsync(h.app.refreshLibrary);
      for (var i = 0; i < 30 && h.tuner.channel == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(h.app.channels, isNotEmpty);
      expect(h.tuner.channel?.id, h.app.channels.first.id);
      await h.end(tester);
    });
  }

  testWidgets('only the first channels tune: a later refresh leaves the channel watched', (tester) async {
    runAs(TargetPlatform.linux);
    setWindow(tester, const Size(1920, 1080));
    final h = await PortraitHarness.start(tester, library: LibraryIndex.empty);
    await h.show(tester, const TvScreen());
    await tester.pump(const Duration(milliseconds: 300));
    h.app.client = _Library(portraitLibrary());
    await tester.runAsync(h.app.refreshLibrary);
    // A later refresh with the channel already tuned changes nothing.
    final second = h.app.channels.last;
    await tester.runAsync(() => h.tuner.tune(second));
    await tester.runAsync(h.app.refreshLibrary);
    await tester.pump();
    expect(h.tuner.channel?.id, second.id);
    await h.end(tester);
  });
}
