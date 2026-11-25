import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel_initials.dart';

void main() {
  test('Latin names give their call letters, as before', () {
    expect(channelInitials('Laugh Track', none: 'TV'), 'LT');
    expect(channelInitials('Toons', none: 'TV'), 'Toon');
    expect(channelInitials('the big classic movie', none: 'TV'), 'TBC');
    expect(channelInitials('  ', none: 'TV'), 'TV');
  });

  test('Japanese and Chinese names give their first two characters', () {
    expect(channelInitials('ホラー映画', none: 'TV'), 'ホラ');
    expect(channelInitials('喜剧频道', none: 'TV'), '喜剧');
    expect(channelInitials('80年代 コメディ', none: 'TV'), '80');
  });
}
