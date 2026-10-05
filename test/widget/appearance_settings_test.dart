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
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for the previously-dead appearance settings:
/// - LayoutDensity now flows into the ThemeData visualDensity.
/// - The UI-scale slider now drives the root MediaQuery textScaler.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LayoutDensity -> VisualDensity', () {
    test('comfortable maps to standard', () {
      final theme = MoonrelayTheme.light(
        MoonrelayAccents.defaultAccent.seedColor,
        density: LayoutDensity.comfortable,
      );
      expect(theme.visualDensity, VisualDensity.standard);
    });

    test('compact maps to compact', () {
      final theme = MoonrelayTheme.dark(
        MoonrelayAccents.defaultAccent.seedColor,
        density: LayoutDensity.compact,
      );
      expect(theme.visualDensity, VisualDensity.compact);
    });

    test('defaults to comfortable when omitted', () {
      final theme = MoonrelayTheme.light(
        MoonrelayAccents.defaultAccent.seedColor,
      );
      expect(theme.visualDensity, VisualDensity.standard);
    });

    test('cards use the shared corner radius', () {
      expect(
        MoonrelayTheme.light(MoonrelayAccents.defaultAccent.seedColor)
            .cardTheme
            .shape,
        isA<RoundedRectangleBorder>().having(
          (s) => s.borderRadius,
          'radius',
          BorderRadius.circular(MoonrelayDesignTokens.baseCornerRadius),
        ),
      );
    });

    test('accent seed drives the color scheme', () {
      final light = MoonrelayTheme.light(MoonrelayAccents.frigoris.seedColor);
      final vista = MoonrelayTheme.light(MoonrelayAccents.nubium.seedColor);
      expect(vista.colorScheme.primary, isNot(light.colorScheme.primary));
    });
  });

  group('UI scale', () {
    /// Mirrors the MediaQuery wrapping introduced in app.dart's builder.
    Widget root(TextScaler scaler, Widget child) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: child,
        ),
      );
    }

    testWidgets('uiScale scales text via MediaQuery textScaler',
        (tester) async {
      final controller = SettingsController(SettingsService());
      await controller.updateUiScale(2.0);

      double scaleOf(double font) {
        return MediaQuery.of(tester.element(find.byType(Text)))
            .textScaler
            .scale(font);
      }

      await tester.pumpWidget(
        root(
          TextScaler.linear(controller.uiScale),
          const Text('probe'),
        ),
      );

      expect(scaleOf(16.0), 32.0);
    });

    test('updateUiScale writes the persisted value', () async {
      final controller = SettingsController(SettingsService());
      expect(controller.uiScale, 1.0);
      await controller.updateUiScale(1.5);
      expect(controller.uiScale, 1.5);
      // Clamping to the slider's declared range.
      await controller.updateUiScale(5.0);
      expect(controller.uiScale, 2.0);
    });
  });
}
