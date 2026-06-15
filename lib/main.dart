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

// Application entry point.  All heavy initialisation (Vodozemac, SQLite,
// Matrix SDK, etc.) happens in [main] before [runApp] is called so that
// the widgets are never rendered until the full provider tree is ready.
// If initialisation fails a minimal error-only UI is shown instead.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vdz;
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/encryption/encryption_service.dart';
import 'src/helpers/log_service.dart';
import 'src/helpers/navigation_state.dart';
import 'src/init_logger.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

/// Whether the current platform is a desktop OS.
bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

// ─────────────────────────────────────────────────────────────────────────────
// Initialisation pipeline — runs before the UI appears
// ─────────────────────────────────────────────────────────────────────────────

/// Return value of [_initialize].
///
/// On success all fields are non-null; on failure [errorTitle] and
/// [errorBody] are populated instead.
class _InitResult {
  final Client? sdk;
  final Logger? log;
  final LogService? logService;
  final SettingsController? settingsController;
  final EncryptionService? encryptionService;
  final String? errorTitle;
  final String? errorBody;

  const _InitResult._({
    this.sdk,
    this.log,
    this.logService,
    this.settingsController,
    this.encryptionService,
    this.errorTitle,
    this.errorBody,
  });

  factory _InitResult.ok({
    required Client sdk,
    required Logger log,
    required LogService logService,
    required SettingsController settingsController,
    required EncryptionService encryptionService,
  }) =>
      _InitResult._(
        sdk: sdk,
        log: log,
        logService: logService,
        settingsController: settingsController,
        encryptionService: encryptionService,
      );

  factory _InitResult.err(String title, String body) =>
      _InitResult._(errorTitle: title, errorBody: body);
}

Future<_InitResult> _initialize() async {
  // ── 0. Log service ──────────────────────────────────────────
  final logService = await initializeLog();
  final Logger log = logService.logger;

  void showError(String title, String body) {
    log.e('Init failed: $title\n$body');
  }

  // ── 1. Vodozemac (native crypto) ────────────────────────────
  log.t('Initializing Vodozemac…');
  try {
    await vdz.init();
  } catch (e) {
    showError('Encryption Engine Failed', '$e');
    return _InitResult.err(
      'Encryption Engine Failed',
      'The encryption library (Vodozemac) could not be initialized. '
          'This usually means your platform is missing required native '
          'libraries.\n\nError: $e',
    );
  }

  // ── 2. SQLite FFI ───────────────────────────────────────────
  log.t('Initializing SQLite FFI…');
  try {
    sqfliteFfiInit();
  } catch (e) {
    showError('Database Engine Failed', '$e');
    return _InitResult.err(
      'Database Engine Failed',
      'The SQLite native library could not be loaded.\n\nError: $e',
    );
  }
  databaseFactory = databaseFactoryFfi;

  // ── 3. Open database & Matrix SDK store ─────────────────────
  log.t('Opening database…');
  final dbdir = await getApplicationSupportDirectory();
  const String dbname = 'moonrelay.db';
  final database = await sql.openDatabase(p.join(dbdir.path, dbname));
  final dbobj = await MatrixSdkDatabase.init('moonrelay',
      database: database, sqfliteFactory: databaseFactoryFfi);
  await dbobj.open();

  // ── 4. Matrix client ────────────────────────────────────────
  log.t('Starting Matrix client…');
  final sdk = Client(
    'Moonrelay',
    database: dbobj,
    verificationMethods: {
      KeyVerificationMethod.numbers,
      KeyVerificationMethod.emoji,
    },
    nativeImplementations: NativeImplementationsIsolate(
      compute,
      vodozemacInit: vdz.init,
    ),
  );
  try {
    await sdk.init();
  } catch (e) {
    showError('Connection Failed', '$e');
    return _InitResult.err(
      'Connection Failed',
      'Could not initialise the Matrix client.\n\nError: $e',
    );
  }

  // ── 5. Theming & window ─────────────────────────────────────
  log.t('Loading preferences…');
  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform)) {
    SystemTheme.accentColor.load();
  }
  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();

  if (isDesktop) {
    await WindowManager.instance.ensureInitialized();
    await windowManager.waitUntilReadyToShow();
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
  }

  // ── 6. Encryption service ───────────────────────────────────
  log.t('Initializing encryption…');
  final encryptionService = EncryptionService(client: sdk, logger: log);
  if (sdk.isLogged()) {
    await encryptionService.init();
  }

  log.i('Initialization complete');
  return _InitResult.ok(
    sdk: sdk,
    log: log,
    logService: logService,
    settingsController: settingsController,
    encryptionService: encryptionService,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal error UI shown when init fails
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SelectableText(
                    body,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  onPressed: () => exit(0),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Exit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point — init first, then show either the error UI or the real app
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final result = await _initialize();

  if (result.sdk != null) {
    // ── Success — show the real app ──────────────────────────
    runApp(
      MultiProvider(
        providers: [
          Provider<Client>.value(value: result.sdk!),
          Provider<Logger>.value(value: result.log!),
          Provider<LogService>.value(value: result.logService!),
          ChangeNotifierProvider<SettingsController>.value(
              value: result.settingsController!),
          ChangeNotifierProvider<NavigationState>(
            create: (_) => NavigationState(),
          ),
          ChangeNotifierProvider<EncryptionService>.value(
              value: result.encryptionService!),
        ],
        child: const MoonrelayApp(),
      ),
    );
  } else {
    // ── Failure — show error UI ──────────────────────────────
    runApp(_ErrorApp(title: result.errorTitle!, body: result.errorBody!));
  }
}
