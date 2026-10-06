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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/appearance_and_layout_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_utils.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('selecting an accent recolors without touching density',
      (tester) async {
    final controller = createTestSettingsController();
    expect(controller.selectedAccentId, MoonrelayAccents.defaultAccentId);
    expect(controller.density, LayoutDensity.comfortable);

    await tester.pumpWidget(
      wrapWithProviders(
        settingsController: controller,
        child: const HubAppearanceLayoutSettings(),
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(HubAppearanceLayoutSettings)),
    )!;
    final skyTile = find.widgetWithText(
      RadioListTile<String>,
      localizedAccent(MoonrelayAccents.nubium, l10n),
    );
    // The page is one scroll view now, so a control below the fold is not in
    // the tree until it is reached. `ensureVisible` cannot bring a finder into
    // existence; scrolling until it does is the version that works here.
    await tester.scrollUntilVisible(skyTile, 120);
    await tester.tap(skyTile);
    await tester.pump();

    expect(controller.selectedAccentId, MoonrelayAccents.nubium.id);
    expect(controller.selectedAccent, same(MoonrelayAccents.nubium));
    // Accents own the hue only; geometry settings survive the switch.
    expect(controller.density, LayoutDensity.comfortable);
  });

  testWidgets('selecting a density chip keeps the accent', (tester) async {
    final controller = createTestSettingsController();
    await controller.updateSelectedAccent(MoonrelayAccents.aristarchus.id);

    await tester.pumpWidget(
      wrapWithProviders(
        settingsController: controller,
        child: const HubAppearanceLayoutSettings(),
      ),
    );
    await tester.pump();

    final compactChip = find.widgetWithText(ChoiceChip, 'Compact');
    await tester.scrollUntilVisible(compactChip, 120);
    await tester.tap(compactChip);
    await tester.pump();

    expect(controller.density, LayoutDensity.compact);
    expect(controller.selectedAccentId, MoonrelayAccents.aristarchus.id);
  });
}
