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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vdz;
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'encryption/encryption_service.dart';
import 'helpers/account_manager.dart';
import 'helpers/current_room.dart';
import 'helpers/log_service.dart';
import 'helpers/platform.dart';
import 'services/database_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/tray_service.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_service.dart';
import 'settings/space_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BootContext — result of the boot pipeline
// ─────────────────────────────────────────────────────────────────────────────

/// All initialized services produced by the boot pipeline.
class BootContext {
  BootContext({
    required this.log,
    required this.logService,
    required this.accountManager,
    required this.databaseService,
    required this.client,
    required this.settingsController,
    required this.spacePreferences,
    required this.encryptionService,
    required this.currentRoom,
    this.notificationService,
    required this.deepLinkService,
  });

  final Logger log;
  final LogService logService;
  final AccountManager accountManager;
  final DatabaseService databaseService;
  final Client client;
  final SettingsController settingsController;
  final SpacePreferences spacePreferences;
  final EncryptionService encryptionService;
  final CurrentRoom currentRoom;
  final NotificationService? notificationService;
  final DeepLinkService deepLinkService;
}

// ─────────────────────────────────────────────────────────────────────────────
// BootStep — single unit of the boot pipeline
// ─────────────────────────────────────────────────────────────────────────────

/// A single initialisation step in the boot pipeline.
///
/// Each step is a focused, testable class.  The pipeline runner calls
/// [run] in order, passing dependencies it may need.
abstract class BootStep<T> {
  const BootStep();

  /// Human-readable label shown in the splash screen.
  String get label;

  /// Execute this step and return its result.
  /// Throws on failure (aborts the pipeline).
  Future<T> run();
}

// ─────────────────────────────────────────────────────────────────────────────
// Pipeline runner
// ─────────────────────────────────────────────────────────────────────────────

/// Runs the full boot pipeline, calling [onStatus] before each step.
///
/// Returns a fully-initialized [BootContext] on success, or throws on
/// the first step failure.
///
/// [onWaitingForFirstSync] is invoked after the local pipeline
/// finishes when the SDK session is logged in but no synced rooms
/// have arrived yet.  The splash screen uses it to stay visible
/// while the first `/sync` response is in flight, preventing an
/// empty rooms pane from flashing in and out.
Future<BootContext> runBootPipeline({
  required int schemaVersion,
  required Logger log,
  required LogService logService,
  required AccountManager accountManager,
  required void Function(String) onStatus,
  void Function()? onWaitingForFirstSync,
}) async {
  // ── 1. Vodozemac (native crypto) ────────────────────────────
  onStatus('Initializing encryption engine…');
  log.t('Boot: Vodozemac');
  try {
    await vdz.init();
  } catch (e) {
    log.f('Vodozemac failed', error: e);
    rethrow;
  }

  // ── 2. SQLite FFI ───────────────────────────────────────────
  onStatus('Initializing database…');
  log.t('Boot: SQLite FFI');
  try {
    sqfliteFfiInit();
  } catch (e) {
    log.f('SQLite FFI failed', error: e);
    rethrow;
  }
  databaseFactory = databaseFactoryFfi;

  // ── 3. Open database ────────────────────────────────────────
  onStatus('Opening database…');
  log.t('Boot: Database');
  final dbService = DatabaseService(schemaVersion: schemaVersion, log: log);
  final String dbName = accountManager.activeAccount?.databaseName ??
      'moonrelay.db';
  final dbobj = await dbService.openDatabaseFor(dbName);

  // ── 4. Create Matrix Client ─────────────────────────────────
  onStatus('Starting network client…');
  log.t('Boot: Matrix Client');
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

  // ── 5. Theme & Settings ─────────────────────────────────────
  onStatus('Loading preferences…');
  log.t('Boot: Settings');
  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform)) {
    SystemTheme.accentColor.load();
  }
  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();

  final spacePreferences = SpacePreferences(SettingsService());
  await spacePreferences.load();

  // ── 6. Window Manager ───────────────────────────────────────
  if (isDesktop) {
    await WindowManager.instance.ensureInitialized();
    await windowManager.waitUntilReadyToShow();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setMinimumSize(
      Size(settingsController.windowMinWidth, settingsController.windowMinHeight),
    );
    if (!settingsController.startMinimized) {
      await windowManager.show();
    }
    await windowManager.setPreventClose(true);
    await windowManager.setSkipTaskbar(false);
  }

  // ── 7. Encryption service ───────────────────────────────────
  onStatus('Preparing encryption…');
  log.t('Boot: Encryption');
  final encryptionService = EncryptionService(client: sdk, logger: log);
  if (sdk.isLogged()) {
    await encryptionService.init();
  }

  // ── 8. CurrentRoom ──────────────────────────────────────────
  final currentRoom = CurrentRoom();

  // ── 9. Notification service ─────────────────────────────────
  // DeepLinkService is created before NotificationService so that
  // tapping a notification can navigate to the corresponding room
  // through it. The previous build ignored `NotificationResponse.payload`
  // and only brought the window forward, which made DMs useless when
  // more than one was unread.
  NotificationService? notificationService;
  DeepLinkService? deepLinkService;

  // We always stand up the deep-link service: not just for live
  // sessions, but also so a `matrix:` URI the user opens at startup
  // (before any login) lands on the right page.
  onStatus('Setting up deep link handler…');
  log.t('Boot: DeepLink');
  deepLinkService = DeepLinkService(log: log);
  try {
    await deepLinkService.init();
  } catch (e) {
    log.w('Deep link service init failed', error: e);
  }

  if (sdk.isLogged()) {
    onStatus('Starting notification service…');
    log.t('Boot: Notifications');
    try {
      notificationService = await NotificationService.init(
        client: sdk,
        settings: settingsController,
        currentRoom: currentRoom,
        log: log,
        deepLinkService: deepLinkService,
      );
    } catch (e) {
      log.w('Notification service init failed', error: e);
    }
  }

  // ── 10. Tray service ────────────────────────────────────────
  if (isDesktop && settingsController.showTrayIcon) {
    onStatus('Setting up system tray…');
    log.t('Boot: Tray');
    try {
      await TrayService.init(accountManager: accountManager, log: log);
    } catch (e) {
      log.w('Tray service init failed', error: e);
    }
  }

  // ── 11. Wire up AccountManager ──────────────────────────────
  // ── 11. Wire up AccountManager ──────────────────────────────
  // Initialise the persisted active-account → live client association
  // so widgets bound to `Provider<Client>` see the same pair after a
  // hot-restart. The early-init branch in 9 handles the logged-out
  // case (notification service skipped).
  log.t('Boot: AccountManager wiring');
  if (accountManager.activeAccount != null && sdk.isLogged()) {
    await accountManager.setActiveAccountDirect(
      accountManager.activeAccount!,
      client: sdk,
      encryptionService: encryptionService,
    );
  } else if (accountManager.activeAccount != null) {
    log.w(
      'Boot: stored active account exists but SDK session is not logged in; '
      'skipping setActiveAccountDirect so the user lands on the welcome '
      'screen instead of a stale session',
    );
  }

  accountManager.clientFactory = (StoredAccount account) async {
    final innerDb = await dbService.openDatabaseFor(account.databaseName);
    final client = Client(
      'Moonrelay (Alpha)',
      database: innerDb,
      verificationMethods: {
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.emoji,
      },
      nativeImplementations: NativeImplementationsIsolate(
        compute,
        vodozemacInit: vdz.init,
      ),
    );
    await client.init();
    return client;
  };

  accountManager.onClientReady = (client) async {
    if (client.isLogged()) {
      final enc = EncryptionService(client: client, logger: log);
      await enc.init();
    }
  };

  log.i('Initialization complete');

  // ── Wait for first sync ─────────────────────────────────────
  // If the SDK is logged in, hold the splash visible until either
  // the first `/sync` response arrives or a short timeout elapses.
  // Without this the splash swaps to the main app, which renders an
  // empty rooms pane for a beat before the first sync lands.
  if (sdk.isLogged() && onWaitingForFirstSync != null) {
    onWaitingForFirstSync();
    final hasRooms = sdk.rooms.isNotEmpty;
    if (!hasRooms) {
      try {
        await sdk.onSync.stream.first.timeout(
          const Duration(seconds: 8),
        );
      } on TimeoutException {
        log.w('Boot: timed out waiting for first sync; '
            'proceeding with whatever the client has');
      } catch (e) {
        log.w('Boot: error waiting for first sync', error: e);
      }
    }
  }

  return BootContext(
    log: log,
    logService: logService,
    accountManager: accountManager,
    databaseService: dbService,
    client: sdk,
    settingsController: settingsController,
    spacePreferences: spacePreferences,
    encryptionService: encryptionService,
    currentRoom: currentRoom,
    notificationService: notificationService,
    deepLinkService: deepLinkService,
  );
}
