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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/services/deep_link_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:provider/provider.dart';

import 'mocks.dart';

/// Creates a [SettingsController] backed by an in-memory [SettingsService],
/// with default values pre-populated so tests can use it immediately without
/// calling [SettingsController.loadSettings].
SettingsController createTestSettingsController() {
  final service = SettingsService();
  final controller = SettingsController(service);
  return controller;
}

/// A test wrapper that provides the full set of Providers needed by most
/// widgets in the app: [Client], [Logger], [SettingsController],
/// [AccountManager], [EncryptionService], [CurrentRoom], [NavigationState],
/// and [DeepLinkService].
Widget wrapWithProviders({
  required Widget child,
  Client? client,
  Logger? logger,
  SettingsController? settingsController,
  AccountManager? accountManager,
  EncryptionService? encryptionService,
  CurrentRoom? currentRoom,
  NavigationState? navigationState,
  DeepLinkService? deepLinkService,
}) {
  return MultiProvider(
    providers: [
      Provider<Client>.value(value: client ?? MockClient()),
      Provider<Logger>.value(value: logger ?? MockLogger()),
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController ?? createTestSettingsController(),
      ),
      ChangeNotifierProvider<AccountManager>.value(
        value: accountManager ?? MockAccountManager(),
      ),
      ChangeNotifierProvider<EncryptionService>.value(
        value: encryptionService ?? MockEncryptionService(),
      ),
      ChangeNotifierProvider<CurrentRoom>.value(
        value: currentRoom ?? CurrentRoom(),
      ),
      ChangeNotifierProvider<NavigationState>.value(
        value: navigationState ?? NavigationState(),
      ),
      Provider<DeepLinkService>.value(
        value: deepLinkService ?? MockDeepLinkService(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

/// Wraps [child] in a [MaterialApp] for widget tests that do not need
/// any Matrix or Logger providers.
Widget wrapWithMaterialApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}
