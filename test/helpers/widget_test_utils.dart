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
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:provider/provider.dart';

import 'mocks.dart';

/// Creates a [SettingsController] backed by an in-memory [SettingsService]
/// that uses mock SharedPreferences (call [setUpMockSharedPreferences] first).
SettingsController createTestSettingsController() {
  final service = SettingsService();
  final controller = SettingsController(service);
  // Load synchronously in tests — SharedPreferences must be mocked before
  // calling this.
  return controller;
}

/// A test wrapper that provides [Client], [Logger], and [SettingsController]
/// via [MultiProvider], so that widgets under test can access them with
/// `Provider.of<T>(context)`.
///
/// [overrides] can be used to replace the default test providers.
Widget wrapWithProviders({
  required Widget child,
  Client? client,
  Logger? logger,
  SettingsController? settingsController,
}) {
  return MultiProvider(
    providers: [
      Provider<Client>.value(value: client ?? MockClient()),
      Provider<Logger>.value(value: logger ?? MockLogger()),
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController ?? createTestSettingsController(),
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
