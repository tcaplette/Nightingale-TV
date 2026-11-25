/// A channel's call letters for a badge: "Laugh Track" → "LT", "Toons" →
/// "Toon". A Japanese or Chinese name has no spaces between words, so it
/// gives its first two characters: ホラー映画 → ホラ, 喜剧频道 → 喜剧
/// (cjk-languages D8). [none] is for a name with nothing in it.
String channelInitials(String name, {required String none}) {
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return none;
  if (_cjk.hasMatch(name)) return String.fromCharCodes(words.join().runes.take(2));
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 4));
  return words.take(3).map((w) => w[0]).join().toUpperCase();
}

/// Kana, Han and the CJK punctuation between them.
final _cjk = RegExp(r'[぀-ヿ㐀-鿿豈-﫿]');
