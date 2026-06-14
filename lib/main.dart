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

// This is the application entry point. It servers the purpose of intializing vital data.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vdz;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'src/helpers/navigation_state.dart';
import 'src/init_logger.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'src/app.dart';
import 'package:path/path.dart' as p;
import 'src/encryption/encryption_service.dart';

/// Checks if the current environment is a desktop environment.
bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Better error handling (application-wide item)
  // TODO: Deffered loading, loading screen, etc.

  // ignore: avoid_print
  print("Starting log.");
  Logger log = await initializeLog();

  log.t("Now awaiting vodozemac initialization");
  try {
    await vdz.init();
  } catch (e) {
    log.f("Vodozemac failed", error: e);
    if (kDebugMode) {
      print(e);
    }
    exit(-2);
  }

  log.t("Now awaiting sqflite initialization");

  try {
    sqfliteFfiInit();
  } catch (e) {
    log.f('SQFLite FFi has caused an exception. Please report this issue.',
        error: e);
    if (kDebugMode) {
      print(e);
    }
    exit(-1);
  }

  databaseFactory = databaseFactoryFfi;

  // TODO: This will need rework for multiplatform.
  // Initialize the SDK Client object and do necessary initializations.
  // Support Emoji and Number sequence verification (future: QR code)
  // Definitely use isolates to offload compute from main thread

  final dbdir = await getApplicationSupportDirectory();
  log.t("Database directory recieved as ${dbdir.toString()}");
  const String dbname = 'moonrelay.db';
  log.t("Now awaiting sql database opening");
  final database = await sql.openDatabase(p.join(dbdir.path, dbname));
  log.t("Database opened as ${database.toString()}");
  log.t("Now awaiting Matrix SDK Database initialization");
  final dbobj = await MatrixSdkDatabase.init('moonrelay',
      database: database, sqfliteFactory: databaseFactoryFfi);
  log.i("Matrix SDK database initialized");
  log.t("awaiting opening Matrix SDK Database");
  await dbobj.open();
  log.t("Matrix SDK Database opened");

  log.t("Initiating client");
  final sdk = Client(
    'Moonrelay',
    database: dbobj,
    verificationMethods: {
      KeyVerificationMethod.numbers,
      KeyVerificationMethod.emoji,
      // TODO[epic=longterm] QRCode
      //KeyVerificationMethod.qrScan
    },
    nativeImplementations: NativeImplementations.dummy,
  );
  await sdk.init();

  // if it's not on the web (=if on desktop or mobile), load the accent color
  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform)) {
    SystemTheme.accentColor.load();
  }

  // Set up the SettingsController, which will glue user settings to multiple widgets.
  final settingsController = SettingsController(SettingsService());
  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  if (isDesktop) {
    await WindowManager.instance.ensureInitialized();
    windowManager.waitUntilReadyToShow().then((_) async {
      if (!settingsController.useSystemTitlebar) {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
      }

      await windowManager.setMinimumSize(const Size(500, 600));
      await windowManager.show();
      await windowManager.setPreventClose(true);
      await windowManager.setSkipTaskbar(false);
    });
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(
          create: (context) => sdk,
        ),
        Provider(
          create: (_) => log,
        ),
        ChangeNotifierProvider(
          create: (context) => settingsController,
        ),
        ChangeNotifierProvider(
          create: (context) => NavigationState(),
        ),
        ChangeNotifierProvider(
          create: (context) => EncryptionService(
            client: sdk,
            logger: log,
          ),
        ),
      ],
      child: const MoonrelayApp(),
    ),
  );
}
