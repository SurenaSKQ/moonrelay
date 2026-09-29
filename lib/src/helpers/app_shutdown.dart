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

import 'package:logger/logger.dart';

import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/service_registry.dart';
import 'package:moonrelay/src/services/tray_service.dart';

import 'log_service.dart';

// -----------------------------------------------------------------------------
// MoonShutdown, globally-registered orderly shutdown
// -----------------------------------------------------------------------------

/// Provides a single shutdown entry point that all close paths (window
/// close button, tray "Quit", system close) use through a globally
/// registered callback.
///
/// The [register] method is called once from `main.dart` after the
/// boot pipeline completes, with the live service instances wired in
/// as a closure.  Every close path calls [call] (or simply
/// `MoonShutdown()`).
///
/// ## Why a static callback instead of Provider?
///
/// The tray service's quit handler is not inside the widget tree and
/// cannot use `context.read`.  A static registration avoids threading
/// service references through every close path.
class MoonShutdown {
  MoonShutdown._();

  static Future<void> Function()? _cb;

  /// Register the shutdown callback.  Called once from `main.dart`
  /// after boot with the live service instances captured in a closure.
  static void register(Future<void> Function() cb) {
    _cb = cb;
  }

  /// Run the shutdown sequence.  Safe to call multiple times; the
  /// callback is cleared after the first invocation.
  static Future<void> call() async {
    final cb = _cb;
    _cb = null; // ensure single-fire
    if (cb != null) await cb();
  }
}

// -----------------------------------------------------------------------------
// performShutdown: the actual teardown sequence
// -----------------------------------------------------------------------------

/// Runs an orderly teardown of every live service before the
/// application terminates.
///
/// [accountManager] is passed rather than a [Client] because the
/// account-scoped resources are replaced on every account switch: the
/// shutdown callback is registered once at boot, so a `Client` captured
/// in that closure is the boot client and is stale by the time the user
/// quits if they switched accounts. [AccountManager.shutdown] resolves
/// whatever is actually live.
///
/// Order matters: sync-heavy consumers are disposed first so they stop
/// reacting to events, then the [Client] is disposed, which tears down
/// the [NativeImplementationsIsolate] background isolate and crucially
/// joins the native OS threads that `vodozemac.dll` (Rust FFI) spawned
/// inside that isolate.  If we skipped this step, those orphaned threads
/// would keep the DLL loaded, preventing Windows from fully releasing
/// the process and locking the build output folder for the next
/// rebuild.
Future<void> performShutdown({
  required AccountManager accountManager,
  required Logger log,
  required LogService logService,
  required ServiceRegistry registry,
  TrayService? trayService,
}) async {
  log.i('Shutting down…');

  // -- 1. Tear down all registry services in reverse order ------
  // This handles NotificationService, DeepLinkService,
  // AutoUpdateService, and any other process-lifetime service that
  // registered during boot.  The EncryptionService and the Client are
  // deliberately absent: AccountManager owns those, and they get
  // swapped on account switch, so the registry would only ever hold a
  // disposed reference.
  await registry.shutdownAll(log);

  // -- 2. Account-scoped resources -------------------------------
  // Disposes the live EncryptionService, then the live Client.
  try {
    await accountManager.shutdown();
  } catch (e) {
    log.w('Account manager shutdown failed', error: e);
  }

  // -- 3. Tray icon cleanup --------------------------------------
  if (trayService != null) {
    try {
      await trayService.destroyTray();
    } catch (e) {
      log.w('TrayService cleanup failed', error: e);
    }
  }

  // -- 4. Close the log sink -------------------------------------
  // `dispose`, not `wipeLogs`: the process is about to end, and
  // `wipeLogs` exists to truncate while keeping logging alive.
  try {
    await logService.dispose();
  } catch (e) {
    log.w('Log teardown failed', error: e);
  }

  log.i('Shutdown complete');
}
