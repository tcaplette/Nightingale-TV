import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nightingale_tv/icons/custom_icons.dart';

void main() {
  late Directory dir;
  late CustomIconStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('icons');
    store = CustomIconStore(Directory('${dir.path}/logos')..createSync());
  });
  tearDown(() => dir.delete(recursive: true));

  test('large images are shrunk to 512 px PNGs and deduplicated', () async {
    final source = File('${dir.path}/big.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 2000, height: 1000)));
    final name = await store.import(source);
    expect(name, endsWith('.png'));
    final stored = img.decodePng(store.fileFor(name).readAsBytesSync())!;
    expect((stored.width, stored.height), (512, 256));
    expect(await store.import(source), name, reason: 'same image, same file');
    expect(await store.list(), [name]);
  });

  test('SVGs are kept; junk is rejected', () async {
    final svg = File('${dir.path}/logo.svg')
      ..writeAsStringSync('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"/>');
    expect(await store.import(svg), endsWith('.svg'));
    final junk = File('${dir.path}/fake.png')..writeAsStringSync('not an image');
    expect(store.import(junk), throwsA(isA<CustomIconException>()));
  });
}
