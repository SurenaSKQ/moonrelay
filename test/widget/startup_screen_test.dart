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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/startup_screen.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:provider/provider.dart';

void main() {
  group('StartupScreen', () {
    Widget _buildApp() {
      return ChangeNotifierProvider<SettingsController>.value(
        value: SettingsController(SettingsService()),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StartupScreen(),
        ),
      );
    }

    testWidgets('renders login and sign up buttons', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('renders the app tagline', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(
        find.text('The Public Benefit Messenger'),
        findsOneWidget,
      );
    });

    testWidgets('renders Privacy Policy and Licenses buttons', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.text('Privacy and Your Data'), findsOneWidget);
      expect(find.text('Licenses'), findsOneWidget);
    });

    testWidgets('has a Column layout with Wrap for buttons', (tester) async {
      await tester.pumpWidget(_buildApp());

      // One FilledButton (Sign In) and one OutlinedButton (Create Account), footer has TextButtons
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(Wrap), findsWidgets);
    });
  });
}
