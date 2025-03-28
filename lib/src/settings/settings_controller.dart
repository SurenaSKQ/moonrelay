import 'package:azhi_main/src/settings/display_type.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/window_effect.dart';

import 'settings_service.dart';

/// A class that many Widgets can interact with to read user settings, update
/// user settings, or listen to user settings changes.
///
/// Controllers glue Data Services to Flutter Widgets. The SettingsController
/// uses the SettingsService to store and retrieve user settings.
class SettingsController with ChangeNotifier {
  final SettingsService _settingsService;
  late ThemeMode _themeMode;
  late WindowEffect _windowEffect;
  late DisplayType _displayType;

  SettingsController(this._settingsService) {
    loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  WindowEffect get windowEffect => _windowEffect;
  DisplayType get displayType => _displayType;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _windowEffect = await _settingsService.windowEffect();
    _displayType = await _settingsService.displayType();

    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode newThemeMode) async {
    if (newThemeMode != _themeMode) {
      _themeMode = newThemeMode;
      notifyListeners();
      await _settingsService.updateThemeMode(newThemeMode);
    }
  }

  Future<void> updateWindowEffect(WindowEffect newWindowEffect) async {
    if (newWindowEffect != _windowEffect) {
      _windowEffect = newWindowEffect;
      notifyListeners();
      await _settingsService.updateWindowEffect(newWindowEffect);
    }
  }

  Future<void> updateDisplayType(DisplayType newDisplayType) async {
    if (newDisplayType != _displayType) {
      _displayType = newDisplayType;
      notifyListeners();
      await _settingsService.updateDisplayType(newDisplayType);
    }
  }
}
