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
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/login_page.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';

void main() {
  group('LoginPage', () {
    late MockClient client;
    late MockLogger logger;

    setUp(() {
      client = MockClient();
      logger = MockLogger();

      // Stub window_manager method channels for test environment
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
              return null;
            default:
              return null;
          }
        },
      );
    });

    testWidgets('renders login form with all fields', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Client>.value(value: client),
            Provider<Logger>.value(value: logger),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginPage(),
          ),
        ),
      );

      expect(find.text('Login'), findsWidgets);
      expect(find.text('Homeserver'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('has a back button', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Client>.value(value: client),
            Provider<Logger>.value(value: logger),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginPage(),
          ),
        ),
      );

      // LoginPage uses LucideIcons.arrowLeft which renders as an Icon with Icons.arrow_back
      // We just verify a back navigation icon is present by checking the IconButton
      final backButtons = find.byType(IconButton);
      // There should be exactly one IconButton (the back button in AppBar)
      expect(backButtons, findsOneWidget);
    });

    testWidgets('has a homeserver text field with default value',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Client>.value(value: client),
            Provider<Logger>.value(value: logger),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginPage(),
          ),
        ),
      );

      final homeserverField = find.widgetWithText(TextField, 'matrix.org');
      expect(homeserverField, findsOneWidget);
    });
  });
}
