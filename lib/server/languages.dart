/// Language codes as servers and devices give them (ISO 639-1 `en`,
/// 639-2/B `ger`, 639-2/T `deu`, tags like `en-US`), normalized to one
/// code per language (639-2/B, as Jellyfin stores them), and their names.
library;

/// 639-1 → 639-2/B.
const _twoToThree = {
  'af': 'afr', 'am': 'amh', 'ar': 'ara', 'az': 'aze', 'be': 'bel', 'bg': 'bul', 'bn': 'ben', 'bo': 'tib',
  'bs': 'bos', 'ca': 'cat', 'cs': 'cze', 'cy': 'wel', 'da': 'dan', 'de': 'ger', 'el': 'gre', 'en': 'eng',
  'eo': 'epo', 'es': 'spa', 'et': 'est', 'eu': 'baq', 'fa': 'per', 'fi': 'fin', 'fil': 'fil', 'fo': 'fao',
  'fr': 'fre', 'ga': 'gle', 'gl': 'glg', 'gu': 'guj', 'he': 'heb', 'hi': 'hin', 'hr': 'hrv', 'hu': 'hun',
  'hy': 'arm', 'id': 'ind', 'is': 'ice', 'it': 'ita', 'iw': 'heb', 'ja': 'jpn', 'jv': 'jav', 'ka': 'geo',
  'kk': 'kaz', 'km': 'khm', 'kn': 'kan', 'ko': 'kor', 'ku': 'kur', 'ky': 'kir', 'la': 'lat', 'lb': 'ltz',
  'lo': 'lao', 'lt': 'lit', 'lv': 'lav', 'mi': 'mao', 'mk': 'mac', 'ml': 'mal', 'mn': 'mon', 'mr': 'mar',
  'ms': 'may', 'mt': 'mlt', 'my': 'bur', 'nb': 'nob', 'ne': 'nep', 'nl': 'dut', 'nn': 'nno', 'no': 'nor',
  'pa': 'pan', 'pl': 'pol', 'ps': 'pus', 'pt': 'por', 'ro': 'rum', 'ru': 'rus', 'si': 'sin', 'sk': 'slo',
  'sl': 'slv', 'so': 'som', 'sq': 'alb', 'sr': 'srp', 'sv': 'swe', 'sw': 'swa', 'ta': 'tam', 'te': 'tel',
  'tg': 'tgk', 'th': 'tha', 'tl': 'tgl', 'tr': 'tur', 'uk': 'ukr', 'ur': 'urd', 'uz': 'uzb', 'vi': 'vie',
  'yi': 'yid', 'yo': 'yor', 'zh': 'chi', 'zu': 'zul',
};

/// 639-2/T → 639-2/B, where they differ.
const _terminologic = {
  'bod': 'tib', 'ces': 'cze', 'cym': 'wel', 'deu': 'ger', 'ell': 'gre', 'eus': 'baq', 'fas': 'per',
  'fra': 'fre', 'hye': 'arm', 'isl': 'ice', 'kat': 'geo', 'mkd': 'mac', 'mri': 'mao', 'msa': 'may',
  'mya': 'bur', 'nld': 'dut', 'ron': 'rum', 'slk': 'slo', 'sqi': 'alb', 'zho': 'chi',
};

/// English names, by 639-2/B code.
const _names = {
  'afr': 'Afrikaans', 'alb': 'Albanian', 'amh': 'Amharic', 'ara': 'Arabic', 'arm': 'Armenian',
  'aze': 'Azerbaijani', 'baq': 'Basque', 'bel': 'Belarusian', 'ben': 'Bengali', 'bos': 'Bosnian',
  'bul': 'Bulgarian', 'bur': 'Burmese', 'cat': 'Catalan', 'chi': 'Chinese', 'cze': 'Czech', 'dan': 'Danish',
  'dut': 'Dutch', 'eng': 'English', 'epo': 'Esperanto', 'est': 'Estonian', 'fao': 'Faroese', 'fil': 'Filipino',
  'fin': 'Finnish', 'fre': 'French', 'geo': 'Georgian', 'ger': 'German', 'gle': 'Irish', 'glg': 'Galician',
  'gre': 'Greek', 'guj': 'Gujarati', 'heb': 'Hebrew', 'hin': 'Hindi', 'hrv': 'Croatian', 'hun': 'Hungarian',
  'ice': 'Icelandic', 'ind': 'Indonesian', 'ita': 'Italian', 'jav': 'Javanese', 'jpn': 'Japanese',
  'kan': 'Kannada', 'kaz': 'Kazakh', 'khm': 'Khmer', 'kir': 'Kyrgyz', 'kor': 'Korean', 'kur': 'Kurdish',
  'lao': 'Lao', 'lat': 'Latin', 'lav': 'Latvian', 'lit': 'Lithuanian', 'ltz': 'Luxembourgish',
  'mac': 'Macedonian', 'mal': 'Malayalam', 'mao': 'Maori', 'mar': 'Marathi', 'may': 'Malay', 'mlt': 'Maltese',
  'mon': 'Mongolian', 'nep': 'Nepali', 'nno': 'Norwegian Nynorsk', 'nob': 'Norwegian Bokmål', 'nor': 'Norwegian',
  'pan': 'Punjabi', 'per': 'Persian', 'pol': 'Polish', 'por': 'Portuguese', 'pus': 'Pashto', 'rum': 'Romanian',
  'rus': 'Russian', 'sin': 'Sinhala', 'slo': 'Slovak', 'slv': 'Slovenian', 'som': 'Somali', 'spa': 'Spanish',
  'srp': 'Serbian', 'swa': 'Swahili', 'swe': 'Swedish', 'tam': 'Tamil', 'tel': 'Telugu', 'tgk': 'Tajik',
  'tgl': 'Tagalog', 'tha': 'Thai', 'tib': 'Tibetan', 'tur': 'Turkish', 'ukr': 'Ukrainian', 'urd': 'Urdu',
  'uzb': 'Uzbek', 'vie': 'Vietnamese', 'wel': 'Welsh', 'yid': 'Yiddish', 'yor': 'Yoruba', 'zul': 'Zulu',
};

/// Codes that name no language.
const _none = {'', 'und', 'unk', 'mis', 'mul', 'zxx', 'xx', 'none', 'unknown'};

/// [code] as one code per language (`en`, `en-US`, `deu`, `ger` and `GER`
/// all come out as their 639-2/B code); null for none or unknown.
String? normalizeLanguage(String? code) {
  if (code == null) return null;
  final base = code.trim().toLowerCase().split(RegExp('[-_]')).first;
  if (_none.contains(base)) return null;
  if (base.length == 2) return _twoToThree[base] ?? base;
  return _terminologic[base] ?? base;
}

/// The language's English name ("English"); the code itself, upper case,
/// for one not in the table; null for none.
String? languageName(String? code) {
  final c = normalizeLanguage(code);
  if (c == null) return null;
  return _names[c] ?? c.toUpperCase();
}
