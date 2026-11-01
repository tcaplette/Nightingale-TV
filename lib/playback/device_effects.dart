import 'package:flutter/foundation.dart';

import '../data/app_storage.dart';

/// The "Effects on this device" switch (retro-presentation D8): saved in the
/// app's data folder, beside the profiles, so it belongs to this device and
/// not to a profile or a backup. Also holds what this run found out about
/// the renderer.
class DeviceEffects extends ChangeNotifier {
  DeviceEffects._();

  static final instance = DeviceEffects._();

  static const _file = 'device_effects.json';

  AppStorage? _storage;
  bool _on = true;
  bool _shaderTurnedOff = false;

  /// Off turns off every CRT effect here.
  bool get on => _on;

  /// Curvature and glow couldn't keep up: off until the app restarts.
  bool get shaderTurnedOff => _shaderTurnedOff;

  Future<void> load(AppStorage storage) async {
    _storage = storage;
    final saved = await storage.readJson(_file);
    _on = saved is! Map || saved['on'] != false;
    notifyListeners();
  }

  Future<void> setOn(bool on) async {
    if (on == _on) return;
    _on = on;
    notifyListeners();
    await _storage?.writeJson(_file, {'on': on});
  }

  void turnOffShader() {
    if (_shaderTurnedOff) return;
    _shaderTurnedOff = true;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _storage = null;
    _on = true;
    _shaderTurnedOff = false;
    notifyListeners();
  }
}
