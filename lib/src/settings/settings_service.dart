import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service that stores and retrieves user settings.
class SettingsService {
  // static const _accentColorKey = 'accent_color';
  static const _themeModeKey = 'theme_mode';
  static const _themeOptionKey = 'theme_option';
  static const _displayTypeKey = 'display_type';
  static const _useSystemTitlebarKey = 'system_title_bar';

  // Layout keys
  static const _leftSidebarVisibleKey = 'left_sidebar_visible';
  static const _leftSidebarWidthKey = 'left_sidebar_width';
  static const _leftPaneChoiceKey = 'left_pane_choice';
  static const _rightSidebarVisibleKey = 'right_sidebar_visible';
  static const _rightSidebarWidthKey = 'right_sidebar_width';
  static const _rightPaneChoiceKey = 'right_pane_choice';
  static const _headerReversedKey = 'header_reversed';
  static const _showStateEventsKey = 'show_state_events';
  static const _showStatusBarKey = 'show_status_bar';
  static const _showTrayIconKey = 'show_tray_icon';
  static const _closeToTrayKey = 'close_to_tray';
  static const _minimizeToTrayKey = 'minimize_to_tray';
  static const _startMinimizedKey = 'start_minimized';
  static const _pinnedSpacesKey = 'pinned_spaces';
  static const _spaceOrderKey = 'space_order';
  static const _collapsedGroupsKey = 'collapsed_groups';

  Future<bool> useSystemTitlebar() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? useSystem = prefs.getBool(_useSystemTitlebarKey);
    return useSystem ?? false;
  }

  Future<void> updateTitlebarStatus(bool useSystemTitlebar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSystemTitlebarKey, useSystemTitlebar);
  }

  Future<MoonrelayThemeOption> themeOption() async {
    final prefs = await SharedPreferences.getInstance();
    final int? index = prefs.getInt(_themeOptionKey);
    return index != null
        ? MoonrelayThemeOption.values[index]
        : MoonrelayThemeOption.indigo;
  }

  Future<void> updateThemeOption(MoonrelayThemeOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeOptionKey, option.index);
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
    return prefs.getBool(_rightSidebarVisibleKey) ?? true;
  }

  Future<void> updateRightSidebarVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rightSidebarVisibleKey, visible);
  }

  Future<bool> headerReversed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_headerReversedKey) ?? false;
  }

  Future<void> updateHeaderReversed(bool reversed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_headerReversedKey, reversed);
  }

  Future<bool> showStateEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showStateEventsKey) ?? true;
  }

  Future<void> updateShowStateEvents(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showStateEventsKey, value);
  }

  Future<bool> showStatusBar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showStatusBarKey) ?? true;
  }

  Future<void> updateShowStatusBar(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showStatusBarKey, value);
  }

  // ── Tray & background ───────────────────────────────────────────────

  Future<bool> showTrayIcon() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showTrayIconKey) ?? true;
  }

  Future<void> updateShowTrayIcon(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTrayIconKey, value);
  }

  Future<bool> closeToTray() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_closeToTrayKey) ?? false;
  }

  Future<void> updateCloseToTray(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_closeToTrayKey, value);
  }

  Future<bool> minimizeToTray() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_minimizeToTrayKey) ?? false;
  }

  Future<void> updateMinimizeToTray(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_minimizeToTrayKey, value);
  }

  Future<bool> startMinimized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_startMinimizedKey) ?? false;
  }

  Future<void> updateStartMinimized(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startMinimizedKey, value);
  }

  // ── Pinned spaces ───────────────────────────────────────────────────

  /// Loads the set of manually pinned subspace room IDs.
  Future<Set<String>> pinnedSpaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pinnedSpacesKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((id) => id.isNotEmpty).toSet();
  }

  /// Persists the set of pinned subspace room IDs.
  Future<void> updatePinnedSpaces(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinnedSpacesKey, ids.join(','));
  }

  // ── Space order ──────────────────────────────────────────────────────

  Future<List<String>> spaceOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_spaceOrderKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((id) => id.isNotEmpty).toList();
  }

  Future<void> updateSpaceOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spaceOrderKey, order.join(','));
  }

  // ── Collapsed groups ─────────────────────────────────────────────────

  Future<Set<String>> collapsedGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_collapsedGroupsKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((id) => id.isNotEmpty).toSet();
  }

  Future<void> updateCollapsedGroups(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collapsedGroupsKey, ids.join(','));
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
    return index != null
        ? RightPaneChoice.values[index]
        : RightPaneChoice.roomInfo;
  }

  Future<void> updateRightPaneChoice(RightPaneChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rightPaneChoiceKey, choice.index);
  }

  // ── Space groups ──────────────────────────────────────────────────

  Future<Map<String, List<String>>> spaceGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('space_groups');
    if (raw == null || raw.isEmpty) return {};
    final map = <String, List<String>>{};
    for (final entry in raw.split('|')) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        map[parts[0]] =
            parts[1].split(',').where((id) => id.isNotEmpty).toList();
      }
    }
    return map;
  }

  Future<void> updateSpaceGroups(Map<String, List<String>> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = groups.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => '${e.key}:${e.value.join(',')}')
        .join('|');
    await prefs.setString('space_groups', encoded);
  }
}
