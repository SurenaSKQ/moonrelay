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

// TODO[epic=very_logterm] Use fluent UI

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'src/init_logger.dart';

void main() async {
  // TODO: Better error handling (application-wide item)
  // TODO: Deffered loading, loading screen, etc.
  Logger log = await initializeLog();
  // Initialize the SDK Client object and do necessary initializations.
  // Using HiveDatabase in "support directory" for all user data
  // TODO[epic=longterm] use Isar? https://isar.dev/
  // Support Emoji and Number sequence verification (future: QR code)
  // Definitely use isolates to offload compute from main thread
  final sdkClient = Client(
    'Project Azhi',
    databaseBuilder: (_) async {
      try {
        final dbpath = await getApplicationSupportDirectory();
        final dbobj = HiveCollectionsDatabase('azhiDB', dbpath.path);
        await dbobj.open();
        return dbobj;
      } catch (e) {
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

  await sdkClient.init();
  // Set up the SettingsController, which will glue user settings to multiple widgets.
  final settingsController = SettingsController(SettingsService());
  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();
  runApp(
    AzhiStartApp(
        settingsController: settingsController, client: sdkClient, log: log),
  );
}
