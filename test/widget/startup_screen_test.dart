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

void main() {
  group('StartupScreen', () {
    testWidgets('renders login and sign up buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StartupScreen(),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sign Up!'), findsOneWidget);
    });

    testWidgets('renders the app tagline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StartupScreen(),
        ),
      );

      expect(
        find.text('The Public Benefit Messenger'),
        findsOneWidget,
      );
    });

    testWidgets('renders license and DMCA notice', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StartupScreen(),
        ),
      );

      // License notice comes from AppLocalizations
      expect(
        find.textContaining('GNU Affero General Public License'),
        findsOneWidget,
      );
      // DMCA notice is hardcoded
      expect(
        find.textContaining('DMCA'),
        findsOneWidget,
      );
    });

    testWidgets('renders Privacy Policy and Licenses buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StartupScreen(),
        ),
      );

      expect(find.text('Privacy and Your Data'), findsOneWidget);
      expect(find.text('Licenses'), findsOneWidget);
    });

    testWidgets('has a Column layout with Wrap for buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StartupScreen(),
        ),
      );

      // Two ElevatedButtons in a Wrap
      expect(find.byType(ElevatedButton), findsNWidgets(2));
      expect(find.byType(Wrap), findsWidgets);
    });
  });
}
