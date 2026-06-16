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
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService', () {
    late SettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SettingsService();
    });

    group('themeMode', () {
      test('defaults to ThemeMode.system', () async {
        final mode = await service.themeMode();
        expect(mode, ThemeMode.system);
      });

      test('returns stored ThemeMode', () async {
        await service.updateThemeMode(ThemeMode.dark);
        final mode = await service.themeMode();
        expect(mode, ThemeMode.dark);
      });

      test('returns updated value after multiple changes', () async {
        await service.updateThemeMode(ThemeMode.light);
        expect(await service.themeMode(), ThemeMode.light);

        await service.updateThemeMode(ThemeMode.dark);
        expect(await service.themeMode(), ThemeMode.dark);

        await service.updateThemeMode(ThemeMode.system);
        expect(await service.themeMode(), ThemeMode.system);
      });
    });

    group('displayType', () {
      test('defaults to DisplayType.modern', () async {
        final type = await service.displayType();
        expect(type, DisplayType.modern);
      });

      test('returns stored DisplayType', () async {
        await service.updateDisplayType(DisplayType.irc);
        final type = await service.displayType();
        expect(type, DisplayType.irc);
      });

      test('returns updated value after multiple changes', () async {
        await service.updateDisplayType(DisplayType.bubbles);
        expect(await service.displayType(), DisplayType.bubbles);

        await service.updateDisplayType(DisplayType.modern);
        expect(await service.displayType(), DisplayType.modern);
      });
    });

    group('useSystemTitlebar', () {
      test('defaults to false', () async {
        final useSystem = await service.useSystemTitlebar();
        expect(useSystem, false);
      });

      test('returns true after setting to true', () async {
        await service.updateTitlebarStatus(true);
        final useSystem = await service.useSystemTitlebar();
        expect(useSystem, true);
      });

      test('returns false after setting to false', () async {
        await service.updateTitlebarStatus(true);
        expect(await service.useSystemTitlebar(), true);

        await service.updateTitlebarStatus(false);
        expect(await service.useSystemTitlebar(), false);
      });
    });

    group('persistence', () {
      test('values persist across service instances', () async {
        // Set value in first instance
        await service.updateThemeMode(ThemeMode.dark);
        await service.updateDisplayType(DisplayType.bubbles);
        await service.updateTitlebarStatus(true);

        // Read in new instance (SharedPreferences mock is global)
        final service2 = SettingsService();
        expect(await service2.themeMode(), ThemeMode.dark);
        expect(await service2.displayType(), DisplayType.bubbles);
        expect(await service2.useSystemTitlebar(), true);
      });
    });
  });
}
