import 'package:flutter/foundation.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';

/// A service that stores and retrieves user settings.
class SettingsService {
  static const _accentColorKey = 'accent_color';
  static const _themeModeKey = 'theme_mode';
  static const _windowEffectKey = 'window_effect';
  static const _displayTypeKey = 'display_type';
  static const _backgroundTransparencyScalarKey =
      'background_transparency_scalar';
  static const _useSystemTitlebarKey = 'system_title_bar';

  Future<bool> useSystemTitlebar() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? useSystem = prefs.getBool(_useSystemTitlebarKey);
    return useSystem ?? false;
  }

  Future<void> updateTitlebarStatus(bool useSystemTitlebar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSystemTitlebarKey, useSystemTitlebar);
  }

  // TODO Own accent color representation + serialization
  Future<AccentColor> accentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final int? accentColorIdx = prefs.getInt(_accentColorKey);
    return accentColorIdx != null
        ? Colors.accentColors[accentColorIdx]
        : systemAccentColor;
  }

  // REVIEW - Potential bug on accent colors not in list?
  Future<void> updateAccentColor(AccentColor accentColor) async {
    final prefs = await SharedPreferences.getInstance();
    final int index = Colors.accentColors.indexOf(accentColor);
    await prefs.setInt(_accentColorKey, index);
  }

  Future<ThemeMode> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final int? themeIndex = prefs.getInt(_themeModeKey);
    return themeIndex != null ? ThemeMode.values[themeIndex] : ThemeMode.system;
  }

  Future<void> updateThemeMode(ThemeMode theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, theme.index);
  }

  Future<WindowEffect> windowEffect() async {
    final prefs = await SharedPreferences.getInstance();
    final int? effectIndex = prefs.getInt(_windowEffectKey);
    return effectIndex != null
        ? WindowEffect.values[effectIndex]
        : WindowEffect.solid;
  }

  Future<void> updateWindowEffect(WindowEffect effect) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_windowEffectKey, effect.index);
  }

  Future<DisplayType> displayType() async {
    final prefs = await SharedPreferences.getInstance();
    final int? typeIndex = prefs.getInt(_displayTypeKey);
    return typeIndex != null
        ? DisplayType.values[typeIndex]
        : DisplayType.modern;
  }

  Future<void> updateDisplayType(DisplayType displayType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_displayTypeKey, displayType.index);
  }

  Future<int> backgroundTransparencyScalar() async {
    final prefs = await SharedPreferences.getInstance();
    final int? transparencyScalar =
        prefs.getInt(_backgroundTransparencyScalarKey);
    return transparencyScalar ?? 250;
  }

  Future<void> updateBackgroundTransparencyScalar(int scalar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_backgroundTransparencyScalarKey, scalar);
  }
}

AccentColor get systemAccentColor {
  if ((defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android) &&
      !kIsWeb) {
    return AccentColor.swatch({
      'darkest': SystemTheme.accentColor.darkest,
      'darker': SystemTheme.accentColor.darker,
      'dark': SystemTheme.accentColor.dark,
      'normal': SystemTheme.accentColor.accent,
      'light': SystemTheme.accentColor.light,
      'lighter': SystemTheme.accentColor.lighter,
      'lightest': SystemTheme.accentColor.lightest,
    });
  }
  return Colors.blue;
}
