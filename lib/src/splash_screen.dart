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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vdz;
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'encryption/encryption_service.dart';
import 'helpers/log_service.dart';
import 'helpers/navigation_state.dart';
import 'init_logger.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_service.dart';

/// Shown on cold start while the application initialises its native
/// crypto engine, database, and Matrix SDK client.
///
/// If any step fails the screen transitions to an error view which
/// the user can dismiss (exit) or retry.  On success the main
/// [MoonrelayApp] is rendered.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // ── State machine ─────────────────────────────────────────────────

  /// `null` → still running; `true` → success; `false` → error.
  bool? _done;

  /// Human-readable status shown under the spinner.
  String _status = 'Preparing…';

  /// If [_done] == `false`, contains the error detail.
  String _errorTitle = '';
  String _errorBody = '';

  bool _didInit = false;

  // Values that survive the build once initialised.
  LogService? _logService;
  Logger? _log;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  // ── Initialisation pipeline ───────────────────────────────────────

  Future<void> _start() async {
    try {
      await _pipe();
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e, s) {
      if (!mounted) return;
      _log?.e('SplashScreen: init failed', error: e, stackTrace: s);
      setState(() {
        _done = false;
        _errorTitle = 'Initialization Failed';
        _errorBody = '$e';
      });
    }
  }

  Future<void> _pipe() async {
    // ── 0. Log service ──────────────────────────────────────────
    _setStatus('Starting log service…');
    _logService = await initializeLog();
    _log = _logService!.logger;

    // ── 1. Vodozemac (native crypto) ────────────────────────────
    _setStatus('Initializing encryption engine…');
    try {
      await vdz.init();
    } catch (e) {
      _log!.f('Vodozemac failed', error: e);
      _showError(
        'Encryption Engine Failed',
        'The encryption library (Vodozemac) could not be initialized. '
            'This usually means your platform is missing required native '
            'libraries. Moonrelay requires end-to-end encryption support '
            'to function.\n\nError: $e',
      );
      return;
    }

    // ── 2. SQLite FFI ───────────────────────────────────────────
    _setStatus('Initializing database…');
    try {
      sqfliteFfiInit();
    } catch (e) {
      _log!.f('SQLite FFI failed', error: e);
      _showError(
        'Database Engine Failed',
        'The SQLite native library could not be loaded. Your platform '
            'may be missing required system libraries.\n\nError: $e',
      );
      return;
    }
    databaseFactory = databaseFactoryFfi;

    // ── 3. Open database & Matrix SDK store ─────────────────────
    _setStatus('Opening database…');
    final dbdir = await getApplicationSupportDirectory();
    const String dbname = 'moonrelay.db';
    final database = await sql.openDatabase(p.join(dbdir.path, dbname));
    final dbobj = await MatrixSdkDatabase.init('moonrelay',
        database: database, sqfliteFactory: databaseFactoryFfi);
    await dbobj.open();

    // ── 4. Matrix client ────────────────────────────────────────
    _setStatus('Starting network client…');
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
      _log!.e('Client.init() failed', error: e);
      _showError(
        'Connection Failed',
        'Could not initialise the Matrix client. The homeserver may be '
            'unreachable or the stored session may be corrupted.\n\n'
            'Error: $e',
      );
      return;
    }

    // ── 5. Theming & window ─────────────────────────────────────
    _setStatus('Loading preferences…');
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
      // Show the window now so the user sees progress.
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
    _setStatus('Preparing encryption…');
    final encryptionService = EncryptionService(client: sdk, logger: _log!);
    if (sdk.isLogged()) {
      await encryptionService.init();
    }

    // ── 7. Hand over to the main app ────────────────────────────
    if (!mounted) return;
    // Replace the splash screen with the real app via Navigator.
    // Because we are the root we use a pushReplacement to swap.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            Provider<Client>.value(value: sdk),
            Provider<Logger>.value(value: _log!),
            Provider<LogService>.value(value: _logService!),
            ChangeNotifierProvider<SettingsController>.value(
                value: settingsController),
            ChangeNotifierProvider<NavigationState>(
              create: (_) => NavigationState(),
            ),
            ChangeNotifierProvider<EncryptionService>.value(
                value: encryptionService),
          ],
          child: const MoonrelayApp(),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  void _setStatus(String msg) {
    _log?.t(msg);
    if (mounted) {
      setState(() => _status = msg);
    }
  }

  void _showError(String title, String body) {
    if (!mounted) return;
    setState(() {
      _done = false;
      _errorTitle = title;
      _errorBody = body;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: Scaffold(
        backgroundColor: scheme.surface,
        body: Center(
          child: _done == false ? _buildError(scheme) : _buildLoading(scheme),
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.moon, size: 64, color: scheme.primary),
        const SizedBox(height: 32),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _status,
          style: TextStyle(
            fontSize: 15,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildError(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.alertOctagon, size: 56, color: scheme.error),
          const SizedBox(height: 24),
          Text(
            _errorTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SelectableText(
              _errorBody,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _done = null;
                    _status = 'Retrying…';
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) => _start());
                },
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: const Text('Retry'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => exit(0),
                icon: const Icon(LucideIcons.logOut, size: 18),
                label: const Text('Exit'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Whether the current platform is a desktop OS.
bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}
