/// The nightly new episode premiere slot (episode-premieres), per profile.
class PremiereSettings {
  const PremiereSettings({this.enabled = true, this.startMinute = 20 * 60, this.days = everyDay});

  static const everyDay = {1, 2, 3, 4, 5, 6, 7};

  final bool enabled;

  /// Minutes after local midnight, in 15-minute steps.
  final int startMinute;

  /// [DateTime.weekday] values the slot airs on.
  final Set<int> days;

  PremiereSettings copyWith({bool? enabled, int? startMinute, Set<int>? days}) => PremiereSettings(
        enabled: enabled ?? this.enabled,
        startMinute: startMinute ?? this.startMinute,
        days: days ?? this.days,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'start': startMinute,
        'days': days.toList()..sort(),
      };

  /// Missing or unreadable: on, at 8:00 PM, every day.
  factory PremiereSettings.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const PremiereSettings();
    final days = (json['days'] as List?)?.whereType<int>().where((d) => d >= 1 && d <= 7).toSet();
    final start = json['start'];
    return PremiereSettings(
      enabled: json['enabled'] as bool? ?? true,
      startMinute: start is int && start >= 0 && start < 24 * 60 ? start : 20 * 60,
      days: days ?? everyDay,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PremiereSettings &&
      other.enabled == enabled &&
      other.startMinute == startMinute &&
      other.days.length == days.length &&
      other.days.containsAll(days);

  @override
  int get hashCode => Object.hash(enabled, startMinute, Object.hashAllUnordered(days));
}
