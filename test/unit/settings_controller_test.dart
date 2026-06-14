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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stubs the `window_manager` platform channel so tests that interact
/// with [WindowListener] methods don't crash.
void _stubWindowManagerChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'addListener':
        case 'removeListener':
        case 'setPreventClose':
        case 'setTitleBarStyle':
        case 'show':
        case 'setMinimumSize':
        case 'setSkipTaskbar':
        case 'waitUntilReadyToShow':
        case 'destroy':
        case 'isPreventClose':
          return null;
        default:
          return null;
      }
    },
  );
}

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
      expect(controller.useSystemTitlebar, false);
    });

    test('loadSettings loads persisted values', () async {
      // First, set values via service
      await service.updateThemeMode(ThemeMode.dark);
      await service.updateDisplayType(DisplayType.irc);
      await service.updateTitlebarStatus(true);

      // Create a new controller and load
      final newController = SettingsController(service);
      await newController.loadSettings();

      expect(newController.themeMode, ThemeMode.dark);
      expect(newController.displayType, DisplayType.irc);
      expect(newController.useSystemTitlebar, true);
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

    testWidgets('updateUseOfSystemTitlebar changes the value and persists',
        (tester) async {
      _stubWindowManagerChannel();

      expect(controller.useSystemTitlebar, false);

      await controller.updateUseOfSystemTitlebar(true);
      expect(controller.useSystemTitlebar, true);
      expect(await service.useSystemTitlebar(), true);
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

    testWidgets('notifies listeners when titlebar status changes',
        (tester) async {
      _stubWindowManagerChannel();

      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      await controller.updateUseOfSystemTitlebar(true);
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

    testWidgets('does not notify when titlebar status is unchanged',
        (tester) async {
      _stubWindowManagerChannel();

      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      await controller.updateUseOfSystemTitlebar(true);
      final firstCount = notificationCount;
      await controller.updateUseOfSystemTitlebar(true);
      expect(notificationCount, firstCount);
    });
  });
}
