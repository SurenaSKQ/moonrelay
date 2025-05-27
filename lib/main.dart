// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <http://www.gnu.org/licenses/>.

// This is the application entry point. It servers the purpose of intializing vital data.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:logger/logger.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'src/init_logger.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'src/app.dart';
import 'package:path/path.dart' as p;

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

  Logger log = await initializeLog();

  try {
    sqfliteFfiInit();
  } catch (e) {
    log.f('SQFLite FFi has caused an exception. Report this on our CodeBerg.',
        error: e);
    if (kDebugMode) {
      print(
          'SQFLite FFi has caused an exception. Report this on our CodeBerg.');
    }
  }

  databaseFactory = databaseFactoryFfi;

  // TODO: This will need rework for multiplatform.
  // Initialize the SDK Client object and do necessary initializations.
  // Support Emoji and Number sequence verification (future: QR code)
  // Definitely use isolates to offload compute from main thread
  final sdk = Client(
    'Project Azhi',
    databaseBuilder: (_) async {
      try {
        final dbdir = await getApplicationSupportDirectory();
        const String dbname = 'azhiDB.db';
        final database = await sql.openDatabase(p.join(dbdir.path, dbname));
        final dbobj = MatrixSdkDatabase('azhi',
            database: database, sqfliteFactory: databaseFactoryFfi);
        await dbobj.open();
        return dbobj;
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
        log.f(
          "Failed to initialize database",
          error: e,
          stackTrace: StackTrace.current,
          time: DateTime.now(),
        );
        exit(-1);
      }
    },
    verificationMethods: {
      KeyVerificationMethod.numbers,
      KeyVerificationMethod.emoji,
      // TODO[epic=longterm] QRCode
      //KeyVerificationMethod.qrScan
    },
    nativeImplementations: NativeImplementationsIsolate(compute),
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

  if (isDesktop) {
    await flutter_acrylic.Window.initialize();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await flutter_acrylic.Window.hideWindowControls();
    }

    await flutter_acrylic.Window.setEffect(
        effect: flutter_acrylic.WindowEffect.transparent);

    await WindowManager.instance.ensureInitialized();
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setMinimumSize(const Size(500, 600));
      await windowManager.show();
      await windowManager.setPreventClose(true);
      await windowManager.setSkipTaskbar(false);
    });
  }

  // Set up the SettingsController, which will glue user settings to multiple widgets.
  final settingsController = SettingsController(SettingsService());
  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();
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
        )
      ],
      child: const ChatSpacesApp(),
    ),
  );
}
