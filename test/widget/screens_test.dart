// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen.dart';
import 'package:moonrelay/src/screens/licenses.dart';
import 'package:moonrelay/src/screens/privacy_policy.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

void main() {
  late MockClient client;
  late MockLogger logger;
  late SettingsController settingsController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = MockClient();
    logger = MockLogger();

    settingsController = SettingsController(SettingsService());
    await settingsController.loadSettings();

    when(() => client.userID).thenReturn('@test:matrix.org');
    when(() => logger.w(any())).thenReturn(null);
    when(() => client.getProfileFromUserId(any())).thenAnswer(
      (_) async => Profile(userId: '@test:matrix.org'),
    );
  });

  group('HubScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Client>.value(value: client),
            Provider<Logger>.value(value: logger),
            ChangeNotifierProvider<SettingsController>.value(
              value: settingsController,
            ),
            ChangeNotifierProvider<NavigationState>.value(
              value: NavigationState(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HubScreen(client: client),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HubScreen), findsOneWidget);
    });
  });

  group('LicensesScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Logger>.value(value: logger),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LicensesScreen(),
          ),
        ),
      );

      expect(find.byType(LicensesScreen), findsOneWidget);
    });
  });

  group('PrivacyPolicyPopupScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PrivacyPolicyPopupScreen(),
        ),
      );

      expect(find.byType(PrivacyPolicyPopupScreen), findsOneWidget);
    });
  });
}
