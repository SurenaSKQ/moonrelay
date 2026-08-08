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
import 'package:moonrelay/src/settings/skins.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_utils.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('selecting a skin updates the controller and resets density',
      (tester) async {
    final controller = createTestSettingsController();
    // Baseline before selection.
    expect(controller.selectedSkinId, MoonrelaySkins.defaultSkinId);
    expect(controller.density, LayoutDensity.comfortable);

    await tester.pumpWidget(
      wrapWithProviders(
        settingsController: controller,
        child: const HubAppearanceSettings(),
      ),
    );
    await tester.pump();

    final compactTile = find.widgetWithText(
        RadioListTile<String>, MoonrelaySkins.compact.label);
    await tester.ensureVisible(compactTile);
    await tester.tap(compactTile);
    await tester.pump();

    // A) the skin switched to compact.
    expect(controller.selectedSkinId, MoonrelaySkins.compact.id);
    // B) density was reset to the compact skin's default (compact), proving
    //    the skin redefines the entire look and feel rather than just hue.
    expect(controller.density, LayoutDensity.compact);
  });
}
