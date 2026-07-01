// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
  ThemeMode _themeMode = ThemeMode.system;
  MoonrelayThemeOption _themeOption = MoonrelayThemeOption.indigo;
  DisplayType _displayType = DisplayType.modern;

  // Layout state
  bool _leftSidebarVisible = true;
  double _leftSidebarWidth = 320.0;
  LeftPaneChoice _leftPaneChoice = LeftPaneChoice.rooms;
  bool _rightSidebarVisible = true;
  double _rightSidebarWidth = 280.0;
  RightPaneChoice _rightPaneChoice = RightPaneChoice.roomInfo;
  bool _headerReversed = false;
  bool _showStateEvents = true;
  bool _showStatusBar = true;
  bool _showTrayIcon = true;
  bool _closeToTray = false;
  bool _minimizeToTray = false;
  bool _startMinimized = false;
  double _fontSize = 16.0;
  double _uiScale = 1.0;
  bool _notificationsEnabled = true;
  SettingsController(this._settingsService);

  ThemeMode get themeMode => _themeMode;
  MoonrelayThemeOption get themeOption => _themeOption;
  DisplayType get displayType => _displayType;

  // Layout getters
  bool get leftSidebarVisible => _leftSidebarVisible;
  double get leftSidebarWidth => _leftSidebarWidth;
  LeftPaneChoice get leftPaneChoice => _leftPaneChoice;
  bool get rightSidebarVisible => _rightSidebarVisible;
  double get rightSidebarWidth => _rightSidebarWidth;
  RightPaneChoice get rightPaneChoice => _rightPaneChoice;
  bool get headerReversed => _headerReversed;
  bool get showStateEvents => _showStateEvents;
  bool get showStatusBar => _showStatusBar;
  bool get showTrayIcon => _showTrayIcon;
  bool get closeToTray => _closeToTray;
  bool get minimizeToTray => _minimizeToTray;
  bool get startMinimized => _startMinimized;
  double get fontSize => _fontSize;
  double get uiScale => _uiScale;
  bool get notificationsEnabled => _notificationsEnabled;
  Future<void> loadSettings() async {
    final snapshot = await _settingsService.loadAll();
    _themeMode = snapshot.themeMode;
    _themeOption = snapshot.themeOption;
    _displayType = snapshot.displayType;

    // Layout settings
    _leftSidebarVisible = snapshot.leftSidebarVisible;
    _leftSidebarWidth = snapshot.leftSidebarWidth;
    _leftPaneChoice = snapshot.leftPaneChoice;
    _rightSidebarVisible = snapshot.rightSidebarVisible;
    _rightSidebarWidth = snapshot.rightSidebarWidth;
    _rightPaneChoice = snapshot.rightPaneChoice;
    _headerReversed = snapshot.headerReversed;
    _showStateEvents = snapshot.showStateEvents;
    _showStatusBar = snapshot.showStatusBar;
    _showTrayIcon = snapshot.showTrayIcon;
    _closeToTray = snapshot.closeToTray;
    _minimizeToTray = snapshot.minimizeToTray;
    _startMinimized = snapshot.startMinimized;
    _fontSize = snapshot.fontSize;
    _uiScale = snapshot.uiScale;
    _notificationsEnabled = snapshot.notificationsEnabled;
    notifyListeners();
  }

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

  Future<void> updateShowTrayIcon(bool value) async {
    if (value != _showTrayIcon) {
      _showTrayIcon = value;
      notifyListeners();
      await _settingsService.updateShowTrayIcon(value);
    }
  }

  Future<void> updateCloseToTray(bool value) async {
    if (value != _closeToTray) {
      _closeToTray = value;
      notifyListeners();
      await _settingsService.updateCloseToTray(value);
    }
  }

  Future<void> updateMinimizeToTray(bool value) async {
    if (value != _minimizeToTray) {
      _minimizeToTray = value;
      notifyListeners();
      await _settingsService.updateMinimizeToTray(value);
    }
  }

  Future<void> updateStartMinimized(bool value) async {
    if (value != _startMinimized) {
      _startMinimized = value;
      notifyListeners();
      await _settingsService.updateStartMinimized(value);
    }
  }

  Future<void> updateShowStatusBar(bool value) async {
    if (value != _showStatusBar) {
      _showStatusBar = value;
      notifyListeners();
      await _settingsService.updateShowStatusBar(value);
    }
  }

  Future<void> updateNotificationsEnabled(bool value) async {
    if (value != _notificationsEnabled) {
      _notificationsEnabled = value;
      notifyListeners();
      await _settingsService.updateNotificationsEnabled(value);
    }
  }

  Future<void> updateFontSize(double size) async {
    size = size.clamp(10.0, 28.0);
    if (size != _fontSize) {
      _fontSize = size;
      notifyListeners();
      await _settingsService.updateFontSize(size);
    }
  }

  Future<void> updateUiScale(double scale) async {
    scale = scale.clamp(0.7, 2.0);
    if (scale != _uiScale) {
      _uiScale = scale;
      notifyListeners();
      await _settingsService.updateUiScale(scale);
    }
  }
}
