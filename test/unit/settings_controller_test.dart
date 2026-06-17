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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsController', () {
    late SettingsController controller;
    late SettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SettingsService();
      controller = SettingsController(service);
    });

    setUp(() async {
      // The constructor calls loadSettings() without await, so we ensure
      // it completes before each test.
      await controller.loadSettings();
    });

    test('loads default values', () {
      expect(controller.themeMode, ThemeMode.system);
      expect(controller.displayType, DisplayType.modern);
    });

    test('loadSettings loads persisted values', () async {
      // First, set values via service
      await service.updateThemeMode(ThemeMode.dark);
      await service.updateDisplayType(DisplayType.irc);

      // Create a new controller and load
      final newController = SettingsController(service);
      await newController.loadSettings();

      expect(newController.themeMode, ThemeMode.dark);
      expect(newController.displayType, DisplayType.irc);
    });

    test('updateThemeMode changes the theme and persists', () async {
      expect(controller.themeMode, ThemeMode.system);

      await controller.updateThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      // Verify persistence
      expect(await service.themeMode(), ThemeMode.dark);
    });

    test('updateDisplayType changes the display type and persists', () async {
      expect(controller.displayType, DisplayType.modern);

      await controller.updateDisplayType(DisplayType.bubbles);
      expect(controller.displayType, DisplayType.bubbles);
      expect(await service.displayType(), DisplayType.bubbles);
    });

    test('notifies listeners when theme mode changes', () async {
      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      await controller.updateThemeMode(ThemeMode.dark);
      expect(notificationCount, greaterThanOrEqualTo(1));
    });

    test('notifies listeners when display type changes', () async {
      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      await controller.updateDisplayType(DisplayType.irc);
      expect(notificationCount, greaterThanOrEqualTo(1));
    });

    test('does not notify listeners when theme mode is unchanged', () async {
      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      // Set to dark first
      await controller.updateThemeMode(ThemeMode.dark);
      final firstCount = notificationCount;
      // Try setting to dark again (no change)
      await controller.updateThemeMode(ThemeMode.dark);
      expect(notificationCount, firstCount);
    });

    test('does not notify listeners when display type is unchanged', () async {
      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      await controller.updateDisplayType(DisplayType.irc);
      final firstCount = notificationCount;
      // Try setting to irc again (no change)
      await controller.updateDisplayType(DisplayType.irc);
      expect(notificationCount, firstCount);
    });
  });
}
