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

// Application entry point.  A single MaterialApp is created, its `home`
// is the [SplashScreen] while initialisation runs, then the entire
// widget tree is swapped to [MoonrelayApp] once everything is ready.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vdz;
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'src/splash_screen.dart';

/// Current schema version for the local database.
///
/// Increment this whenever the Matrix SDK or our local store layout
/// changes in a backward-incompatible way.  The init pipeline will
/// drop the old database and the user will be prompted to log in
/// again with a clean slate.
///
/// During heavy development this is bumped on every release to avoid
/// subtle migration bugs.
const int kDbSchemaVersion = 1;

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
// Init state — populated by the init pipeline, consumed by the app on success
// ─────────────────────────────────────────────────────────────────────────────

class _AppState {
  const _AppState({
    required this.sdk,
    required this.log,
    required this.logService,
    required this.settingsController,
    required this.encryptionService,
  });

  final Client sdk;
  final Logger log;
  final LogService logService;
  final SettingsController settingsController;
  final EncryptionService encryptionService;
}

// ─────────────────────────────────────────────────────────────────────────────
// Init pipeline
// ─────────────────────────────────────────────────────────────────────────────

/// Runs all blocking initialisation steps.  Each step updates [onStatus] so
/// the splash screen can show progress.  Returns an [_AppState] on success
/// or throws on failure.
Future<_AppState> _initialize({
  required void Function(String) onStatus,
  required Logger log,
  required LogService logService,
}) async {
  // ── 1. Vodozemac (native crypto) ────────────────────────────
  onStatus('Initializing encryption engine…');
  log.t('Initializing Vodozemac…');
  try {
    await vdz.init();
  } catch (e) {
    log.f('Vodozemac failed', error: e);
    rethrow;
  }

  // ── 2. SQLite FFI ───────────────────────────────────────────
  onStatus('Initializing database…');
  log.t('Initializing SQLite FFI…');
  try {
    sqfliteFfiInit();
  } catch (e) {
    log.f('SQLite FFI failed', error: e);
    rethrow;
  }
  databaseFactory = databaseFactoryFfi;

  // ── 3. Database schema version check ────────────────────────
  // During heavy development we wipe the database on every version
  // bump so that subtle SDK migration bugs never accumulate.
  onStatus('Checking database version…');
  const String dbname = 'moonrelay.db';
  const String _schemaVersionKey = 'db_schema_version';
  final prefs = await SharedPreferences.getInstance();
  final int? storedVersion = prefs.getInt(_schemaVersionKey);
  final dbdir = await getApplicationSupportDirectory();
  final String dbPath = p.join(dbdir.path, dbname);

  if (storedVersion == null || storedVersion != kDbSchemaVersion) {
    log.i(
      'Database schema version changed ($storedVersion → $kDbSchemaVersion); '
      'wiping old database',
    );
    if (await File(dbPath).exists()) {
      try {
        await sql.deleteDatabase(dbPath);
      } catch (_) {
        // best-effort
      }
    }
    await prefs.clear();
    await prefs.setInt(_schemaVersionKey, kDbSchemaVersion);
  }

  // ── 4. Open database & Matrix SDK store ─────────────────────
  onStatus('Opening database…');
  log.t('Opening database…');
  final database = await sql.openDatabase(dbPath);
  final dbobj = await MatrixSdkDatabase.init('moonrelay',
      database: database, sqfliteFactory: databaseFactoryFfi);
  await dbobj.open();

  // ── 5. Matrix client ────────────────────────────────────────
  onStatus('Starting network client…');
  log.t('Starting Matrix client…');
  final sdk = Client(
    'Moonrelay (Alpha)',
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
    log.e('Client.init() failed', error: e);
    rethrow;
  }

  // ── 6. Theming & window ─────────────────────────────────────
  onStatus('Loading preferences…');
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

  // ── 7. Encryption service ───────────────────────────────────
  onStatus('Preparing encryption…');
  log.t('Initializing encryption…');
  final encryptionService = EncryptionService(client: sdk, logger: log);
  if (sdk.isLogged()) {
    await encryptionService.init();
  }

  log.i('Initialization complete');
  return _AppState(
    sdk: sdk,
    log: log,
    logService: logService,
    settingsController: settingsController,
    encryptionService: encryptionService,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Root widget — swaps between splash and the real app via setState
// ─────────────────────────────────────────────────────────────────────────────

class MoonrelayBootstrap extends StatefulWidget {
  const MoonrelayBootstrap({super.key});

  @override
  State<MoonrelayBootstrap> createState() => _MoonrelayBootstrapState();
}

class _MoonrelayBootstrapState extends State<MoonrelayBootstrap> {
  _AppState? _appState;
  String? _errorTitle;
  String? _errorBody;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    // ── Step 0: Log service (lightweight, run it first) ──────
    LogService logService;
    Logger log;
    try {
      logService = await initializeLog();
      log = logService.logger;
      log.t('Moonrelay booting');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorTitle = 'Log initialization failed';
        _errorBody = '$e';
      });
      return;
    }

    // ── Steps 1-7: heavy init with status callbacks ───────────
    try {
      final state = await _initialize(
        onStatus: (msg) {
          log.t(msg);
          // The splash can't receive status updates until we know
          // the widget tree is stable.  We update the splash via
          // its GlobalKey below.
        },
        log: log,
        logService: logService,
      );
      if (!mounted) return;
      setState(() => _appState = state);
    } catch (e) {
      log.f('Initialization failed', error: e);
      if (!mounted) return;
      setState(() {
        _errorTitle = 'Initialization Failed';
        _errorBody = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Error state ───────────────────────────────────────────
    if (_errorTitle != null) {
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
                    _errorTitle!,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SelectableText(
                      _errorBody!,
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

    // ── Success state — the real app ──────────────────────────
    if (_appState != null) {
      return MultiProvider(
        providers: [
          Provider<Client>.value(value: _appState!.sdk),
          Provider<Logger>.value(value: _appState!.log),
          Provider<LogService>.value(value: _appState!.logService),
          ChangeNotifierProvider<SettingsController>.value(
              value: _appState!.settingsController),
          ChangeNotifierProvider<NavigationState>(
            create: (_) => NavigationState(),
          ),
          ChangeNotifierProvider<EncryptionService>.value(
              value: _appState!.encryptionService),
        ],
        child: const MoonrelayApp(),
      );
    }

    // ── Loading state — the splash screen ─────────────────────
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoonrelayBootstrap());
}
