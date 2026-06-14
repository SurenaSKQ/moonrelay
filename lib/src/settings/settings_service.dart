import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service that stores and retrieves user settings.
class SettingsService {
  // static const _accentColorKey = 'accent_color';
  static const _themeModeKey = 'theme_mode';
  static const _displayTypeKey = 'display_type';
  static const _useSystemTitlebarKey = 'system_title_bar';

  // Layout keys
  static const _leftSidebarVisibleKey = 'left_sidebar_visible';
  static const _leftSidebarWidthKey = 'left_sidebar_width';
  static const _leftPaneChoiceKey = 'left_pane_choice';
  static const _rightSidebarVisibleKey = 'right_sidebar_visible';
  static const _rightSidebarWidthKey = 'right_sidebar_width';
  static const _rightPaneChoiceKey = 'right_pane_choice';

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
  // Future<AccentColor> accentColor() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final int? accentColorIdx = prefs.getInt(_accentColorKey);
  //   return accentColorIdx != null
  //       ? Colors.accentColors[accentColorIdx]
  //       : systemAccentColor;
  // }

  // REVIEW - Potential bug on accent colors not in list?
  // Future<void> updateAccentColor(AccentColor accentColor) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final int index = Colors.accentColors.indexOf(accentColor);
  //   await prefs.setInt(_accentColorKey, index);
  // }

  Future<ThemeMode> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final int? themeIndex = prefs.getInt(_themeModeKey);
    return themeIndex != null ? ThemeMode.values[themeIndex] : ThemeMode.system;
  }

  Future<void> updateThemeMode(ThemeMode theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, theme.index);
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

  // ── Layout settings ──────────────────────────────────────────────────

  Future<bool> leftSidebarVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_leftSidebarVisibleKey) ?? true;
  }

  Future<void> updateLeftSidebarVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_leftSidebarVisibleKey, visible);
  }

  Future<double> leftSidebarWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_leftSidebarWidthKey) ?? 320.0;
  }

  Future<void> updateLeftSidebarWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_leftSidebarWidthKey, width);
  }

  Future<LeftPaneChoice> leftPaneChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final int? index = prefs.getInt(_leftPaneChoiceKey);
    return index != null ? LeftPaneChoice.values[index] : LeftPaneChoice.rooms;
  }

  Future<void> updateLeftPaneChoice(LeftPaneChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leftPaneChoiceKey, choice.index);
  }

  Future<bool> rightSidebarVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rightSidebarVisibleKey) ?? false;
  }

  Future<void> updateRightSidebarVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rightSidebarVisibleKey, visible);
  }

  Future<double> rightSidebarWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rightSidebarWidthKey) ?? 280.0;
  }

  Future<void> updateRightSidebarWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rightSidebarWidthKey, width);
  }

  Future<RightPaneChoice> rightPaneChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final int? index = prefs.getInt(_rightPaneChoiceKey);
    return index != null ? RightPaneChoice.values[index] : RightPaneChoice.none;
  }

  Future<void> updateRightPaneChoice(RightPaneChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rightPaneChoiceKey, choice.index);
  }
}

// AccentColor get systemAccentColor {
//   if ((defaultTargetPlatform == TargetPlatform.windows ||
//           defaultTargetPlatform == TargetPlatform.android) &&
//       !kIsWeb) {
//     return AccentColor.swatch({
//       'darkest': SystemTheme.accentColor.darkest,
//       'darker': SystemTheme.accentColor.darker,
//       'dark': SystemTheme.accentColor.dark,
//       'normal': SystemTheme.accentColor.accent,
//       'light': SystemTheme.accentColor.light,
//       'lighter': SystemTheme.accentColor.lighter,
//       'lightest': SystemTheme.accentColor.lightest,
//     });
//   }
//   return Colors.blue;
// }
