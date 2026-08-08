// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/appearance_settings.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/theme_spec.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_utils.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('selecting a theme updates the controller and resets density',
      (tester) async {
    final controller = createTestSettingsController();
    // Baseline before selection.
    expect(controller.selectedThemeId, MoonrelayThemes.defaultThemeId);
    expect(controller.density, LayoutDensity.comfortable);

    await tester.pumpWidget(
      wrapWithProviders(
        settingsController: controller,
        child: const HubAppearanceSettings(),
      ),
    );
    await tester.pump();

    final compactTile = find.widgetWithText(
        RadioListTile<String>, MoonrelayThemes.compact.label);
    await tester.ensureVisible(compactTile);
    await tester.tap(compactTile);
    await tester.pump();

    // A) the look switched to compact ...
    expect(controller.selectedThemeId, MoonrelayThemes.compact.id);
    // B) ... and density reset to the compact theme's default, proving a
    //    theme redefines the look and feel rather than just hue.
    expect(controller.density, LayoutDensity.compact);
  });

  testWidgets('selecting an accent keeps the look (no density reset)',
      (tester) async {
    final controller = createTestSettingsController();

    // Put the look on compact (compact density) first.
    await controller.updateSelectedTheme(MoonrelayThemes.compact.id);
    expect(controller.density, LayoutDensity.compact);

    await tester.pumpWidget(
      wrapWithProviders(
        settingsController: controller,
        child: const HubAppearanceSettings(),
      ),
    );
    await tester.pump();

    final skyTile =
        find.widgetWithText(RadioListTile<String>, MoonrelayAccents.sky.label);
    await tester.ensureVisible(skyTile);
    await tester.tap(skyTile);
    await tester.pump();

    // Accent change recolors the current look only.
    expect(controller.selectedAccentId, MoonrelayAccents.sky.id);
    expect(controller.selectedThemeId, MoonrelayThemes.compact.id);
    expect(controller.density, LayoutDensity.compact);
  });
}
