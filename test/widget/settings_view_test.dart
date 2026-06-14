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
import 'package:moonrelay/src/settings/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_utils.dart';

void main() {
  group('SettingsView', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('displays theme mode radio buttons', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SettingsView(),
        ),
      );

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('displays chat display type radio buttons', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SettingsView(),
        ),
      );

      expect(find.text('Modern'), findsOneWidget);
      expect(find.text('IRC'), findsOneWidget);
      expect(find.text('Bubbles'), findsOneWidget);
    });

    testWidgets('displays use system titlebar checkbox', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SettingsView(),
        ),
      );

      expect(find.text('Use system titlebar'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('displays back button in app bar', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SettingsView(),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays "Settings" title', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const SettingsView(),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
