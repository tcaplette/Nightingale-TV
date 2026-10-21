import 'package:flutter/material.dart';

/// Built-in channel icons, grouped for the picker. Channels store the key, so
/// keys must never be renamed. (Referencing Icons.* constants directly keeps
/// icon-font tree shaking working.)
const iconCatalog = <String, Map<String, IconData>>{
  'TV & Movies': {
    'tv': Icons.tv,
    'live_tv': Icons.live_tv,
    'connected_tv': Icons.connected_tv,
    'movie': Icons.movie,
    'local_movies': Icons.local_movies,
    'theaters': Icons.theaters,
    'movie_filter': Icons.movie_filter,
    'videocam': Icons.videocam,
    'slideshow': Icons.slideshow,
    'satellite_alt': Icons.satellite_alt,
    'cell_tower': Icons.cell_tower,
    'radio': Icons.radio,
  },
  'Kids & Family': {
    'child_care': Icons.child_care,
    'family_restroom': Icons.family_restroom,
    'toys': Icons.toys,
    'smart_toy': Icons.smart_toy,
    'pets': Icons.pets,
    'cruelty_free': Icons.cruelty_free,
    'emoji_nature': Icons.emoji_nature,
    'cake': Icons.cake,
    'icecream': Icons.icecream,
    'sentiment_very_satisfied': Icons.sentiment_very_satisfied,
    'castle': Icons.castle,
    'school': Icons.school,
  },
  'Genres': {
    'animation': Icons.animation,
    'theater_comedy': Icons.theater_comedy,
    'bolt': Icons.bolt,
    'rocket_launch': Icons.rocket_launch,
    'auto_awesome': Icons.auto_awesome,
    'search': Icons.search,
    'local_police': Icons.local_police,
    'visibility': Icons.visibility,
    'nightlight': Icons.nightlight,
    'favorite': Icons.favorite,
    'explore': Icons.explore,
    'landscape': Icons.landscape,
    'account_balance': Icons.account_balance,
    'military_tech': Icons.military_tech,
    'casino': Icons.casino,
    'psychology': Icons.psychology,
  },
  'Music': {
    'music_note': Icons.music_note,
    'library_music': Icons.library_music,
    'headphones': Icons.headphones,
    'piano': Icons.piano,
    'mic': Icons.mic,
    'album': Icons.album,
    'music_video': Icons.music_video,
  },
  'Sports': {
    'sports_football': Icons.sports_football,
    'sports_basketball': Icons.sports_basketball,
    'sports_baseball': Icons.sports_baseball,
    'sports_soccer': Icons.sports_soccer,
    'sports_hockey': Icons.sports_hockey,
    'sports_motorsports': Icons.sports_motorsports,
    'emoji_events': Icons.emoji_events,
    'fitness_center': Icons.fitness_center,
  },
  'News & Weather': {
    'newspaper': Icons.newspaper,
    'public': Icons.public,
    'thunderstorm': Icons.thunderstorm,
    'wb_sunny': Icons.wb_sunny,
    'ac_unit': Icons.ac_unit,
    'campaign': Icons.campaign,
  },
  'Seasons & Holidays': {
    'celebration': Icons.celebration,
    'park': Icons.park,
    'local_florist': Icons.local_florist,
    'beach_access': Icons.beach_access,
    'eco': Icons.eco,
    'card_giftcard': Icons.card_giftcard,
  },
  'Other': {
    'star': Icons.star,
    'whatshot': Icons.whatshot,
    'diamond': Icons.diamond,
    'flight': Icons.flight,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'science': Icons.science,
    'history_edu': Icons.history_edu,
  },
};

final Map<String, IconData> _allIcons = {
  for (final group in iconCatalog.values) ...group,
};

IconData iconForKey(String key) => _allIcons[key] ?? Icons.live_tv;

/// Colors offered for icon tints and badge backgrounds (ARGB).
const iconColors = <int>[
  0xFFFFD23F, // guide yellow
  0xFFFFFFFF,
  0xFFFF6B35, // orange
  0xFFE63946, // red
  0xFFFF5DA2, // pink
  0xFFA06CD5, // purple
  0xFF4CC9F0, // sky
  0xFF3A86FF, // blue
  0xFF2EC4B6, // teal
  0xFF80ED99, // green
];
