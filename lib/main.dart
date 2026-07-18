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

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/app.dart';
import 'src/boot.dart';
import 'src/encryption/encryption_service.dart';
import 'src/helpers/account_manager.dart';
import 'src/helpers/app_shutdown.dart';
import 'src/helpers/app_version.dart';
import 'src/helpers/current_room.dart';
import 'src/helpers/log_service.dart';
import 'src/helpers/navigation_state.dart';
import 'src/helpers/service_registry.dart';
import 'src/init_logger.dart';
import 'src/localization/app_localizations.dart';
import 'src/services/deep_link_service.dart';
import 'src/services/auto_update_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/tray_service.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/space_preferences.dart';
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
const int kDbSchemaVersion = 2;

// -----------------------------------------------------------------------------
// Init state  populated by the boot pipeline, consumed by the app on success
// -----------------------------------------------------------------------------

class _AppState {
  const _AppState({
    required this.sdk,
    required this.log,
    required this.logService,
    required this.settingsController,
    required this.spacePreferences,
    required this.encryptionService,
    required this.accountManager,
    required this.currentRoom,
    required this.notificationService,
    required this.deepLinkService,
    required this.registry,
    required this.autoUpdateService,
  });

  final Client sdk;
  final Logger log;
  final LogService logService;
  final SettingsController settingsController;
  final SpacePreferences spacePreferences;
  final EncryptionService encryptionService;
  final AccountManager accountManager;
  final CurrentRoom currentRoom;
  final NotificationService? notificationService;
  final DeepLinkService deepLinkService;
  final ServiceRegistry registry;
  final AutoUpdateService autoUpdateService;
}

// -----------------------------------------------------------------------------
// Init pipeline
// -----------------------------------------------------------------------------

/// Runs the full boot pipeline via [runBootPipeline] in [boot.dart].
Future<_AppState> _initialize({
  required void Function(String) onStatus,
  required void Function() onWaitingForFirstSync,
  required Logger log,
  required LogService logService,
}) async {
  // Load saved accounts first  the boot pipeline needs them to know
  // which database to open.
  final accountManager = AccountManager(log: log);
  await accountManager.load();
  log.i('Found ${accountManager.accounts.length} saved account(s)');

  final ctx = await runBootPipeline(
    schemaVersion: kDbSchemaVersion,
    log: log,
    logService: logService,
    accountManager: accountManager,
    onStatus: onStatus,
    onWaitingForFirstSync: onWaitingForFirstSync,
  );

  return _AppState(
    sdk: ctx.client,
    log: ctx.log,
    logService: ctx.logService,
    settingsController: ctx.settingsController,
    spacePreferences: ctx.spacePreferences,
    encryptionService: ctx.encryptionService,
    accountManager: ctx.accountManager,
    currentRoom: ctx.currentRoom,
    notificationService: ctx.notificationService,
    deepLinkService: ctx.deepLinkService,
    registry: ctx.registry,
    autoUpdateService: ctx.autoUpdateService,
  );
}

// -----------------------------------------------------------------------------
// Root widget  swaps between splash and the real app via setState
// -----------------------------------------------------------------------------

class MoonrelayBootstrap extends StatefulWidget {
  const MoonrelayBootstrap({super.key});

  @override
  State<MoonrelayBootstrap> createState() => _MoonrelayBootstrapState();
}

class _MoonrelayBootstrapState extends State<MoonrelayBootstrap> {
  _AppState? _appState;
  String? _errorTitle;
  String? _errorBody;

  /// Key used to grab a typed reference to the [SplashScreen] state from
  /// outside its widget tree.  The init pipeline runs before any widget
  /// is mounted, so we look it up via this key once the splash has been
  /// displayed.
  final GlobalKey<SplashScreenState> _splashKey =
      GlobalKey<SplashScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    // -- Step 0: Log service (lightweight, run it first) ------
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

    // -- Step 0b: App version (platform channel; fire-and-forget) --
    // Cheap and parallel to the rest of boot; the UI shows a fallback
    // version until this completes.
    await AppVersion.init();

    // -- Steps 1-7: heavy init with status callbacks -----------
    try {
      final state = await _initialize(
        onStatus: (msg) {
          log.t(msg);
          // Forward the boot-pipeline status into the splash widget so
          // the user sees "Loading database…" instead of a frozen
          // spinner.  The splash guards against unmounted state
          // internally, but we still check for a null key during the
          // first frame.
          _splashKey.currentState?.updateStatus(msg);
        },
        onWaitingForFirstSync: () {
          // Stay on the splash until the first `/sync` response
          // arrives so the user never sees an empty rooms pane.
          _splashKey.currentState?.markWaitingForSync();
        },
        log: log,
        logService: logService,
      );
      if (!mounted) return;
      _splashKey.currentState?.markDone();
      setState(() => _appState = state);

      // Register the unified shutdown callback so every close path
      // (window close button, tray "Quit", system close) tears down
      // services in the correct order before destroying the window.
      MoonShutdown.register(() => performShutdown(
            client: state.sdk,
            log: state.log,
            logService: state.logService,
            registry: state.registry,
            trayService: TrayService.instance,
          ));

      // -- Startup update check ----------------------------------
      if (state.settingsController.checkForUpdates) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _performStartupUpdateCheck(state);
        });
      }
    } catch (e) {
      log.f('Initialization failed', error: e);
      if (!mounted) return;
      _splashKey.currentState?.markError('Initialization Failed', '$e');
      setState(() {
        _errorTitle = 'Initialization Failed';
        _errorBody = '$e';
      });
    }
  }

  /// Checks for updates on startup and shows a dialog if available.
  void _performStartupUpdateCheck(_AppState state) {
    final log = state.log;
    log.t('Startup update check');
    state.autoUpdateService.check().then((result) {
      if (!mounted || !result.available) return;
      // Use a post-frame callback since we may be called during
      // initial render.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showUpdateDialog(context, result);
      });
    }).catchError((e) {
      log.w('Startup update check failed', error: e);
    });
  }

  /// Shows the update-available dialog using the current context.
  void _showUpdateDialog(BuildContext dialogContext, UpdateCheckResult result) {
    final l10n = AppLocalizations.of(dialogContext)!;
    showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: Theme.of(ctx).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(l10n.updateAvailable),
          ],
        ),
        content: Text(
          l10n.updateAvailableBody(result.latestVersion, result.currentVersion),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.updateLater),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _launchUpdateUrl(result.releaseUrl);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l10n.updateDownload),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // -- Error state -------------------------------------------
    if (_errorTitle != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
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

    // -- Success state  the real app --------------------------
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
          ChangeNotifierProvider<AccountManager>.value(
              value: _appState!.accountManager),
          ChangeNotifierProvider<EncryptionService>.value(
              value: _appState!.encryptionService),
          ChangeNotifierProvider<SpacePreferences>.value(
              value: _appState!.spacePreferences),
          ChangeNotifierProvider<CurrentRoom>.value(
              value: _appState!.currentRoom),
          if (_appState!.notificationService != null)
            Provider<NotificationService>.value(
                value: _appState!.notificationService!),
          Provider<DeepLinkService>.value(value: _appState!.deepLinkService),
          Provider<AutoUpdateService>.value(
              value: _appState!.autoUpdateService),
        ],
        child: const MoonrelayApp(),
      );
    }

    // -- Loading state  the splash screen ---------------------
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: SplashScreen(key: _splashKey),
    );
  }
}

// -----------------------------------------------------------------------------
// Entry point
// -----------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoonrelayBootstrap());
}
