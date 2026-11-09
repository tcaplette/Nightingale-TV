import 'package:flutter/foundation.dart';

import '../data/app_storage.dart';

/// The "Send error reports from this device" switch (error-reporting D3),
/// and the last report sent (D6). Saved in the app's data folder beside the
/// profiles, like [DeviceEffects]: it belongs to this device, not to a
/// profile or a backup.
class ReportSwitch extends ChangeNotifier {
  ReportSwitch._();

  static final instance = ReportSwitch._();

  static const file = 'error_reports.json';

  AppStorage? _storage;
  bool _on = true;
  String? _lastId;
  DateTime? _lastAt;

  /// On by default.
  bool get on => _on;

  /// The full event ID of the last report sent from this device.
  String? get lastId => _lastId;

  DateTime? get lastAt => _lastAt;

  /// The first 8 characters of [lastId], which GlitchTip finds a report by.
  String? get shortLastId => _lastId == null ? null : shortId(_lastId!);

  static String shortId(String id) {
    final plain = id.replaceAll('-', '');
    return plain.length <= 8 ? plain : plain.substring(0, 8);
  }

  Future<void> load(AppStorage storage) async {
    _storage = storage;
    final saved = await storage.readJson(file);
    _on = saved is! Map || saved['on'] != false;
    _lastId = saved is Map && saved['lastId'] is String ? saved['lastId'] as String : null;
    _lastAt = saved is Map && saved['lastAt'] is String ? DateTime.tryParse(saved['lastAt'] as String) : null;
    notifyListeners();
  }

  Future<void> setOn(bool on) async {
    if (on == _on) return;
    _on = on;
    notifyListeners();
    await _save();
  }

  /// A report was sent (its event ID, without dashes).
  Future<void> sent(String id, {DateTime? at}) async {
    _lastId = id;
    _lastAt = at ?? DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> _save() async =>
      _storage?.writeJson(file, {'on': _on, 'lastId': _lastId, 'lastAt': _lastAt?.toUtc().toIso8601String()});

  @visibleForTesting
  void reset() {
    _storage = null;
    _on = true;
    _lastId = null;
    _lastAt = null;
    notifyListeners();
  }
}
