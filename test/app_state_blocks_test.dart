import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_state');
    app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 10, 'Beta': 8, 'Gamma': 6}));
  });

  tearDown(() => dir.delete(recursive: true));

  test('a new block starts empty and needs content', () {
    final block = app.newBlock();
    expect(block.days, {DateTime.saturday});
    expect(app.blockPlaylist(block), isEmpty);
  });

  test('saving builds the playlist, persists, and reloads', () async {
    final block = app.newBlock()
      ..title = 'Cartoons'
      ..source = const ChannelSource(seriesKeys: ['alpha|2000']);
    await app.saveBlock(block);
    expect(app.blocks.single.playlist, hasLength(10));

    final reloaded = AppState(app.storage);
    await reloaded.start();
    expect(reloaded.blocks.single.title, 'Cartoons');
    expect(reloaded.blocks.single.playlist, hasLength(10));
  });

  test('renaming keeps the lineup; changing content restarts it', () async {
    final block = app.newBlock()
      ..title = 'Cartoons'
      ..source = const ChannelSource(seriesKeys: ['alpha|2000']);
    await app.saveBlock(block);
    final oldAnchor = DateTime(2026, 1, 3);
    block.anchor = oldAnchor;

    final renamed = block.copy()..title = 'Toons';
    await app.saveBlock(renamed);
    expect(app.blocks.single.anchor, oldAnchor);

    final changed = renamed.copy()..source = const ChannelSource(seriesKeys: ['beta|2000']);
    await app.saveBlock(changed);
    expect(app.blocks.single.anchor, isNot(oldAnchor));
    expect(app.blocks.single.playlist, hasLength(8));
  });

  test('clashing blocks on the same channel are detected', () async {
    final first = app.newBlock()
      ..title = 'Morning'
      ..source = const ChannelSource(seriesKeys: ['alpha|2000']);
    await app.saveBlock(first);
    final second = app.newBlock()
      ..title = 'Late morning'
      ..startMinute = 11 * 60
      ..endMinute = 13 * 60
      ..source = const ChannelSource(seriesKeys: ['beta|2000']);
    expect(app.blockConflict(second)?.title, 'Morning');
    second.startMinute = 12 * 60;
    expect(app.blockConflict(second), isNull);
  });

  test('block channels survive a lineup reset; deleting a block restores the channel', () async {
    final ch = await app.createBlockChannel('Cartoon Planet');
    expect(ch.blockOnly, isTrue);
    expect(ch.number, greaterThan(app.channels.where((c) => c != ch).map((c) => c.number).reduce((a, b) => a > b ? a : b)));
    final block = app.newBlock()
      ..title = 'Cartoon Planet'
      ..channelId = ch.id
      ..source = const ChannelSource(seriesKeys: ['gamma|2000']);
    await app.saveBlock(block);
    expect(app.scheduleFor(ch)!.blocks, hasLength(1));

    await app.resetChannels();
    expect(app.channelById(ch.id)?.blockOnly, isTrue);

    final regular = app.channels.first;
    final takeover = app.newBlock()
      ..channelId = regular.id
      ..title = 'Takeover'
      ..source = const ChannelSource(seriesKeys: ['gamma|2000']);
    await app.saveBlock(takeover);
    expect(app.scheduleFor(regular)!.blocks, hasLength(1));
    await app.deleteBlock(takeover);
    expect(app.scheduleFor(regular)!.blocks, isEmpty);
  });

  test('signing out clears blocks', () async {
    await app.saveBlock(app.newBlock()
      ..title = 'Cartoons'
      ..source = const ChannelSource(seriesKeys: ['alpha|2000']));
    await app.signOut();
    expect(app.blocks, isEmpty);
    expect(File('${dir.path}/blocks.json').existsSync(), isFalse);
  });
}
