import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/server/media_server.dart';

// live-channel-repair 1: ordering by channel number never fails.
void main() {
  group('parseSourceNumber', () {
    test('reads ordinary numbers', () {
      expect(parseSourceNumber('2.1'), (2, 1));
      expect(parseSourceNumber('7'), (7, 0));
      expect(parseSourceNumber('4-1'), (4, 1));
      expect(parseSourceNumber(' 007 '), (7, 0));
      expect(parseSourceNumber('999999999'), (999999999, 0));
    });

    test('too long to be a channel number is no number, never a throw', () {
      expect(parseSourceNumber('4021733519837465190276453'), isNull); // 25 digits
      expect(parseSourceNumber('18446744073709551616'), isNull); // 20 digits
      expect(parseSourceNumber('9999999999'), isNull); // 10 digits
      expect(parseSourceNumber('5.1234567'), isNull); // minor over 6 digits
      expect(parseSourceNumber('5.123456'), (5, 123456));
      expect(parseSourceNumber('WXYZ'), isNull);
      expect(parseSourceNumber(null), isNull);
    });
  });

  test('a mixed list sorts in source order without throwing', () {
    LiveChannelInfo c(String? number, String name) => LiveChannelInfo(key: name, name: name, number: number);
    final list = [
      c('10', 'Ten'),
      c('4021733519837465190276453', 'Big'),
      c('3.1', 'Three'),
      c(null, 'Alpha'),
      c('2.2', 'TwoTwo'),
      c('18446744073709551616', 'Zed'),
      c('2.1', 'TwoOne'),
      c('5.1234567', 'Minor'),
    ]..sort(compareSourceOrder);
    expect([for (final i in list) i.name], ['TwoOne', 'TwoTwo', 'Three', 'Ten', 'Alpha', 'Big', 'Minor', 'Zed']);
  });

  group('naturalCompare', () {
    test('numbers in order at any length', () {
      final names = [
        'Season 10',
        'Clip 123456789012345678901234567890',
        'Season 2',
        'Clip 99',
        'Clip 123456789012345678901234567891',
      ]..sort(FolderNode.naturalCompare);
      expect(names, [
        'Clip 99',
        'Clip 123456789012345678901234567890',
        'Clip 123456789012345678901234567891',
        'Season 2',
        'Season 10',
      ]);
    });

    test('leading zeros compare by value, shorter spelling first on a tie', () {
      expect(FolderNode.naturalCompare('Part 7', 'Part 007'), lessThan(0));
      expect(FolderNode.naturalCompare('Part 007', 'Part 8'), lessThan(0));
      expect(FolderNode.naturalCompare('Part 0', 'Part 00'), lessThan(0));
      expect(FolderNode.naturalCompare('Part 10', 'Part 9'), greaterThan(0));
    });
  });
}
