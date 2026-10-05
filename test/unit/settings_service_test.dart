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
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';
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

    group('persistence', () {
      test('values persist across service instances', () async {
        // Set value in first instance
        await service.updateThemeMode(ThemeMode.dark);
        await service.updateDisplayType(DisplayType.bubbles);

        // Read in new instance (SharedPreferences mock is global)
        final service2 = SettingsService();
        expect(await service2.themeMode(), ThemeMode.dark);
        expect(await service2.displayType(), DisplayType.bubbles);
      });
    });

    // A stored enum index that no longer names a live value is the normal
    // consequence of removing or reordering a value in one of these enums,
    // not a corrupt-preferences case. These readers run during boot, so an
    // unguarded `values[index]` turned every such user into a failed launch
    // rather than a reset preference.
    group('out-of-range persisted enum indices fall back', () {
      const String layoutModeKey = 'layout_mode';
      const String rightPaneKey = 'right_pane_choice';
      const String themeModeKey = 'theme_mode';
      const String displayTypeKey = 'display_type';

      test('layoutMode() returns auto for an index past the end', () async {
        SharedPreferences.setMockInitialValues({layoutModeKey: 99});
        expect(await service.layoutMode(), LayoutMode.auto);
      });

      test('layoutMode() returns auto for a negative index', () async {
        SharedPreferences.setMockInitialValues({layoutModeKey: -1});
        expect(await service.layoutMode(), LayoutMode.auto);
      });

      test('the batch snapshot does not throw on a stale layout mode',
          () async {
        SharedPreferences.setMockInitialValues({layoutModeKey: 42});
        final snapshot = await service.loadAll();
        expect(snapshot.layoutMode, LayoutMode.auto);
      });

      test('rightPaneChoice() returns roomInfo for a stale index', () async {
        SharedPreferences.setMockInitialValues({rightPaneKey: 77});
        expect(await service.roomPaneTab(), RoomPaneTab.info);
      });

      test('the batch snapshot does not throw on a stale right pane', () async {
        SharedPreferences.setMockInitialValues({rightPaneKey: 77});
        final snapshot = await service.loadAll();
        expect(snapshot.roomPaneTab, RoomPaneTab.info);
      });

      test('themeMode() returns system for a stale index', () async {
        SharedPreferences.setMockInitialValues({themeModeKey: 9});
        expect(await service.themeMode(), ThemeMode.system);
      });

      test('displayType() returns modern for a stale index', () async {
        SharedPreferences.setMockInitialValues({displayTypeKey: 9});
        expect(await service.displayType(), DisplayType.modern);
      });

      test('a valid index is still honoured, not treated as stale', () async {
        SharedPreferences.setMockInitialValues({layoutModeKey: 1});
        expect(await service.layoutMode(), isNot(LayoutMode.auto));
      });
    });
  });
}
