import 'package:moonrelay/src/settings/display_type.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_service.dart';

/// A class that many Widgets can interact with to read user settings, update
/// user settings, or listen to user settings changes.
///
/// Controllers glue Data Services to Flutter Widgets. The SettingsController
/// uses the SettingsService to store and retrieve user settings.
class SettingsController with ChangeNotifier, WindowListener {
  final SettingsService _settingsService;
  late ThemeMode _themeMode;
  late DisplayType _displayType;
  // late AccentColor _accentColor;
  late bool _useSystemTitlebar;

  SettingsController(this._settingsService) {
    loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  DisplayType get displayType => _displayType;
  // AccentColor get accentColor => _accentColor;
  bool get useSystemTitlebar => _useSystemTitlebar;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _displayType = await _settingsService.displayType();
    // _accentColor = await _settingsService.accentColor();
    _useSystemTitlebar = await _settingsService.useSystemTitlebar();

    notifyListeners();
  }

  Future<void> updateUseOfSystemTitlebar(bool useSystemTitlebar) async {
    if (useSystemTitlebar != _useSystemTitlebar) {
      _useSystemTitlebar = useSystemTitlebar;
      notifyListeners();
      if (useSystemTitlebar) {
        windowManager.setTitleBarStyle(TitleBarStyle.normal);
      } else {
        windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }
      await _settingsService.updateTitlebarStatus(useSystemTitlebar);
    }
  }

  // Future<void> updateAccentColor(AccentColor newAccentColor) async {
  //   if (newAccentColor != _accentColor) {
  //     _accentColor = newAccentColor;
  //     notifyListeners();
  //     await _settingsService.updateAccentColor(newAccentColor);
  //   }
  // }

  Future<void> updateThemeMode(ThemeMode newThemeMode) async {
    if (newThemeMode != _themeMode) {
      _themeMode = newThemeMode;
      notifyListeners();
      await _settingsService.updateThemeMode(newThemeMode);
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
