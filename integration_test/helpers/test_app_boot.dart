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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vdz;
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:moonrelay/src/app.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/services/deep_link_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';

import 'mock_matrix_http_client.dart';

/// Boots the app for integration tests with a [MockMatrixHttpClient].
///
/// Call once per test file inside `IntegrationTestWidgetsFlutterBinding`
/// scope. Returns a widget tree ready for `tester.pumpWidget()`.
///
/// The [mockHttp] is attached to the Matrix [Client] so all Matrix API calls
/// are intercepted. Configure handlers/routes on it before calling this.
Future<Widget> buildTestApp({
  required MockMatrixHttpClient mockHttp,
}) async {
  SharedPreferences.setMockInitialValues({});

  // -- 1. Native init (works on desktop test runner) ----------
  // Vodozemac (native crypto)  needed by Client.init()
  try {
    await vdz.init();
  } catch (e) {
    // If running on headless CI without native libs, skip.
    // The Client init below will handle missing crypto gracefully.
  }

  // SQLite FFI  needed for the SDK database
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // -- 2. Database (temp file, cleaned up on next run) --------
  final dbDir = await getTemporaryDirectory();
  final dbPath = '${dbDir.path}/moonrelay_e2e_test.db';
  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    await dbFile.delete();
  }
  final database = await sql.openDatabase(dbPath);
  final sdkDb = await MatrixSdkDatabase.init(
    'moonrelay_test',
    database: database,
    sqfliteFactory: databaseFactoryFfi,
  );
  await sdkDb.open();

  // -- 3. Matrix Client with mocked HTTP ---------------------
  final client = Client(
    'Moonrelay (E2E Test)',
    httpClient: mockHttp,
    database: sdkDb,
    verificationMethods: {
      KeyVerificationMethod.numbers,
      KeyVerificationMethod.emoji,
    },
  );
  await client.init();

  // -- 4. Services -------------------------------------------
  final log = Logger();
  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();

  final spacePreferences = SpacePreferences(SettingsService());
  await spacePreferences.load();

  final encryptionService = EncryptionService(client: client, logger: log);
  final currentRoom = CurrentRoom();
  final accountManager = AccountManager(log: log);
  await accountManager.load();

  // Wire clientFactory for account switching (uses same mock HTTP)
  accountManager.clientFactory = (StoredAccount account) async {
    final innerDb = await sql.openDatabase(
      '${dbDir.path}/moonrelay_${account.userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}.db',
    );
    final innerSdkDb = await MatrixSdkDatabase.init(
      'moonrelay_test_${account.userId}',
      database: innerDb,
      sqfliteFactory: databaseFactoryFfi,
    );
    await innerSdkDb.open();
    final newClient = Client(
      'Moonrelay (E2E Test)',
      httpClient: mockHttp,
      database: innerSdkDb,
      verificationMethods: {
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.emoji,
      },
    );
    await newClient.init();
    return newClient;
  };

  // -- 5. Build provider tree (matches main.dart exactly) ----
  return MultiProvider(
    providers: [
      Provider<Client>.value(value: client),
      Provider<Logger>.value(value: log),
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController,
      ),
      ChangeNotifierProvider<NavigationState>(
        create: (_) => NavigationState(),
      ),
      ChangeNotifierProvider<LayoutShellController>(
        create: (_) => LayoutShellController(),
      ),
      ChangeNotifierProvider<AccountManager>.value(value: accountManager),
      ChangeNotifierProvider<EncryptionService>.value(value: encryptionService),
      ChangeNotifierProvider<SpacePreferences>.value(value: spacePreferences),
      ChangeNotifierProvider<CurrentRoom>.value(value: currentRoom),
      Provider<DeepLinkService>.value(value: DeepLinkService(log: log)),
    ],
    child: const MoonrelayApp(),
  );
}
