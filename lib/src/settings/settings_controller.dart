import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/theme.dart';
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
  late MoonrelayThemeOption _themeOption;
  late DisplayType _displayType;
  // late AccentColor _accentColor;
  late bool _useSystemTitlebar;

  // Layout state
  late bool _leftSidebarVisible;
  late double _leftSidebarWidth;
  late LeftPaneChoice _leftPaneChoice;
  late bool _rightSidebarVisible;
  late double _rightSidebarWidth;
  late RightPaneChoice _rightPaneChoice;
  late bool _headerReversed;
  late bool _showStateEvents;

  SettingsController(this._settingsService) {
    loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  MoonrelayThemeOption get themeOption => _themeOption;
  DisplayType get displayType => _displayType;
  // AccentColor get accentColor => _accentColor;
  bool get useSystemTitlebar => _useSystemTitlebar;

  // Layout getters
  bool get leftSidebarVisible => _leftSidebarVisible;
  double get leftSidebarWidth => _leftSidebarWidth;
  LeftPaneChoice get leftPaneChoice => _leftPaneChoice;
  bool get rightSidebarVisible => _rightSidebarVisible;
  double get rightSidebarWidth => _rightSidebarWidth;
  RightPaneChoice get rightPaneChoice => _rightPaneChoice;
  bool get headerReversed => _headerReversed;
  bool get showStateEvents => _showStateEvents;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _themeOption = await _settingsService.themeOption();
    _displayType = await _settingsService.displayType();
    // _accentColor = await _settingsService.accentColor();
    _useSystemTitlebar = await _settingsService.useSystemTitlebar();

    // Layout settings
    _leftSidebarVisible = await _settingsService.leftSidebarVisible();
    _leftSidebarWidth = await _settingsService.leftSidebarWidth();
    _leftPaneChoice = await _settingsService.leftPaneChoice();
    _rightSidebarVisible = await _settingsService.rightSidebarVisible();
    _rightSidebarWidth = await _settingsService.rightSidebarWidth();
    _rightPaneChoice = await _settingsService.rightPaneChoice();
    _headerReversed = await _settingsService.headerReversed();
    _showStateEvents = await _settingsService.showStateEvents();

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

  Future<void> updateThemeOption(MoonrelayThemeOption option) async {
    if (option != _themeOption) {
      _themeOption = option;
      notifyListeners();
      await _settingsService.updateThemeOption(option);
    }
  }

  Future<void> updateDisplayType(DisplayType newDisplayType) async {
    if (newDisplayType != _displayType) {
      _displayType = newDisplayType;
      notifyListeners();
      await _settingsService.updateDisplayType(newDisplayType);
    }
  }

  // ── Layout mutators ──────────────────────────────────────────────────

  Future<void> setLeftSidebarVisible(bool visible) async {
    if (visible != _leftSidebarVisible) {
      _leftSidebarVisible = visible;
      notifyListeners();
      await _settingsService.updateLeftSidebarVisible(visible);
    }
  }

  Future<void> setLeftSidebarWidth(double width) async {
    width = width.clamp(200.0, 600.0);
    if (width != _leftSidebarWidth) {
      _leftSidebarWidth = width;
      notifyListeners();
      await _settingsService.updateLeftSidebarWidth(width);
    }
  }

  Future<void> setLeftPaneChoice(LeftPaneChoice choice) async {
    if (choice != _leftPaneChoice) {
      _leftPaneChoice = choice;
      // Show the sidebar automatically if a non-none pane is selected
      if (choice != LeftPaneChoice.none && !_leftSidebarVisible) {
        _leftSidebarVisible = true;
        await _settingsService.updateLeftSidebarVisible(true);
      }
      if (choice == LeftPaneChoice.none && _leftSidebarVisible) {
        _leftSidebarVisible = false;
        await _settingsService.updateLeftSidebarVisible(false);
      }
      notifyListeners();
      await _settingsService.updateLeftPaneChoice(choice);
    }
  }

  Future<void> toggleLeftSidebar() async {
    await setLeftSidebarVisible(!_leftSidebarVisible);
  }

  Future<void> setRightSidebarVisible(bool visible) async {
    if (visible != _rightSidebarVisible) {
      _rightSidebarVisible = visible;
      notifyListeners();
      await _settingsService.updateRightSidebarVisible(visible);
    }
  }

  Future<void> setRightSidebarWidth(double width) async {
    width = width.clamp(200.0, 500.0);
    if (width != _rightSidebarWidth) {
      _rightSidebarWidth = width;
      notifyListeners();
      await _settingsService.updateRightSidebarWidth(width);
    }
  }

  Future<void> setRightPaneChoice(RightPaneChoice choice) async {
    if (choice != _rightPaneChoice) {
      _rightPaneChoice = choice;
      if (choice != RightPaneChoice.none && !_rightSidebarVisible) {
        _rightSidebarVisible = true;
        await _settingsService.updateRightSidebarVisible(true);
      }
      if (choice == RightPaneChoice.none && _rightSidebarVisible) {
        _rightSidebarVisible = false;
        await _settingsService.updateRightSidebarVisible(false);
      }
      notifyListeners();
      await _settingsService.updateRightPaneChoice(choice);
    }
  }

  Future<void> toggleRightSidebar() async {
    await setRightSidebarVisible(!_rightSidebarVisible);
  }

  Future<void> updateHeaderReversed(bool reversed) async {
    if (reversed != _headerReversed) {
      _headerReversed = reversed;
      notifyListeners();
      await _settingsService.updateHeaderReversed(reversed);
    }
  }

  Future<void> updateShowStateEvents(bool value) async {
    if (value != _showStateEvents) {
      _showStateEvents = value;
      notifyListeners();
      await _settingsService.updateShowStateEvents(value);
    }
  }
}
