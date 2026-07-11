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
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/app_shutdown.dart';
import 'package:moonrelay/src/services/notification_service.dart';

/// Manages the system tray icon and background behaviour for Moonrelay.
///
/// Provides a tray icon with:
/// - Tooltip showing unread notification count (mentions take priority
///   over general unread so the user can spot them at a glance)
/// - Context menu with Show/Hide and Quit actions
/// - Left-click toggles window visibility
///
/// Call [init] once after the Matrix [Client] is ready.
///
/// ## Failure handling
///
/// Tray icon setup can fail (sandboxed Linux, locked-down Windows
/// corporate installs, missing `path_provider` permission). When
/// [_setup] throws, [_init] clears [_instance] and returns — the
/// rest of the app's window-management code paths
/// ([showWindow], [hideWindow], [toggleWindow], [quit]) still work
/// via direct [windowManager] calls in [AppFrame]. Callers that
/// want to show a "tray unavailable" menu item in the UI should
/// gate it on [isAvailable].
///
/// ## Account switching
///
/// The tray used to keep a stale `Client` reference across account
/// switches, freezing the unread count on the old account. The
/// service now looks up the active client via [AccountManager] on
/// every sync tick, so the badge reflects whatever account is
/// currently active. The sync subscription is re-bound on switch.
class TrayService with tray.TrayListener {
  static TrayService? _instance;

  /// The global singleton, or `null` if init failed.
  static TrayService? get instance => _instance;

  final Logger _log;
  final AccountManager _accountManager;

  /// Currently bound Matrix client, or `null` when no account is
  /// active. The service re-resolves this on every account switch.
  Client? _client;

  /// The sync subscription for the bound [Client]. Re-bound on every
  /// account switch so the tray badge tracks the live session.
  StreamSubscription? _syncSubscription;

  /// The temp file holding the tray icon, cleaned up on [quit].
  File? _iconFile;

  int _unreadCount = 0;
  int _highlightCount = 0;
  bool _available = false;

  TrayService._(this._accountManager, this._log);

  /// Whether the tray icon is alive and registered. Callers (the
  /// AppFrame minimise/close branch, the tray settings page) should
  /// gate any "Open in tray" UI affordances on this flag.
  bool get isAvailable => _available;

  /// Initialise the tray. Returns `true` on success, `false` if the
  /// icon could not be set up (sandbox / locked-down Windows).
  static Future<bool> init({
    required AccountManager accountManager,
    required Logger log,
  }) async {
    final service = TrayService._(accountManager, log);
    final ok = await service._setup();
    if (ok) {
      _instance = service;
      service._bindAccountManager();
    } else {
      _instance = null;
      log.w('Tray service unavailable; cleared singleton');
    }
    return ok;
  }

  Future<bool> _setup() async {
    String? iconPath;
    try {
      // Listen first so we receive callbacks only after the icon is
      // registered. The previous version listened before the icon was
      // confirmed, which left the service registering for events
      // from a non-existent icon.
      tray.trayManager.addListener(this);

      // Load the tray icon from assets and write it to a temp file so
      // that the platform plugin can access it via a file system path.
      // Windows requires .ico format; other platforms use .png.
      final String iconName = Platform.isWindows
          ? 'assets/images/logo.ico'
          : 'assets/images/logo.png';
      final String ext = Platform.isWindows ? 'ico' : 'png';
      final ByteData byteData = await rootBundle.load(iconName);

      // The icon must live on a path the platform plugin can read.
      // On a sandboxed Linux user, the temp directory can fail (e.g.
      // due to a permission revocation mid-session). We surface the
      // failure cleanly and clean the file up on quit so the per-boot
      // trash stays bounded.
      final Directory tmpDir = await getTemporaryDirectory();
      final File iconFile =
          File('${tmpDir.path}/moonrelay_tray_icon.$ext');
      await iconFile.writeAsBytes(byteData.buffer.asUint8List());
      iconPath = iconFile.path;
      _iconFile = iconFile;

      await tray.trayManager.setIcon(iconPath);
      await tray.trayManager.setToolTip('Moonrelay');
      await _updateMenu();
      _refreshBadge();

      _available = true;
      _log.i('Tray service initialised');
      return true;
    } catch (e) {
      _log.w('Tray service init failed', error: e);
      _available = false;
      // Clean up any partial state so callers don't observe a stuck
      // singleton. If `addListener` succeeded before the icon threw,
      // remove it so we don't accumulate listeners across retries.
      try {
        tray.trayManager.removeListener(this);
      } catch (_) {}
      try {
        if (iconPath != null) {
          await File(iconPath).delete();
        }
      } catch (_) {}
      _iconFile = null;
      return false;
    }
  }

  /// Hooks up the active-client change subscription. Called once at
  /// [init] time; on account switch the [AccountManager] notifies and
  /// we rebind the sync listener.
  void _bindAccountManager() {
    _accountManager.addListener(_onActiveAccountChanged);
    _bindClient(_accountManager.client);
  }

  void _onActiveAccountChanged() {
    _bindClient(_accountManager.client);
  }

  void _bindClient(Client? client) {
    _syncSubscription?.cancel();
    _syncSubscription = null;
    _client = client;
    if (client == null) {
      _unreadCount = 0;
      _highlightCount = 0;
      _refreshBadge();
      return;
    }
    _syncSubscription = client.onSync.stream.listen((_) {
      _refreshBadge();
    });
    _refreshBadge();
  }

  Future<void> _updateMenu() async {
    await tray.trayManager.setContextMenu(tray.Menu(
      items: [
        tray.MenuItem(key: 'show', label: 'Show Moonrelay'),
        tray.MenuItem.separator(),
        tray.MenuItem(key: 'quit', label: 'Quit'),
      ],
    ));
  }

  /// Re-reads the unread + highlight totals from the bound client and
  /// pushes a new tooltip to the tray. Honours [NotificationService]'s
  /// mute set so a muted room does not contribute to the badge.
  void _refreshBadge() {
    final client = _client;
    if (client == null) {
      _unreadCount = 0;
      _highlightCount = 0;
      _updateTooltip();
      return;
    }
    final mutedIds = NotificationService.mutedRoomsSnapshot;

    int unread = 0;
    int highlight = 0;
    for (final room in client.rooms) {
      if (room.membership != Membership.join) continue;
      if (mutedIds.contains(room.id)) continue;
      final unreadForRoom = room.notificationCount;
      if (unreadForRoom > 0) unread += unreadForRoom;
      final highlightForRoom = room.highlightCount;
      if (highlightForRoom > 0) highlight += highlightForRoom;
    }
    _unreadCount = unread;
    _highlightCount = highlight;
    _updateTooltip();
  }

  /// Updates the tray tooltip. We prefer highlighting over plain
  /// unread in the badge copy so a mention stays distinct from "I
  /// scrolled past a few messages".
  void _updateTooltip() {
    if (!_available) return;
    final String label;
    if (_highlightCount > 0) {
      label = 'Moonrelay (!$_highlightCount)';
    } else if (_unreadCount > 0) {
      label = 'Moonrelay ($_unreadCount)';
    } else {
      label = 'Moonrelay';
    }
    tray.trayManager.setToolTip(label);
  }

  /// Bring the main window to the foreground.
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Hide the main window without quitting the application.
  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  /// Show the window if hidden, or hide it if visible.
  Future<void> toggleWindow() async {
    if (await windowManager.isVisible()) {
      await hideWindow();
    } else {
      await showWindow();
    }
  }

  /// Clean up tray resources without destroying the window.
  ///
  /// Called by [performShutdown] during orderly app shutdown.  The
  /// tray icon and temp file are removed and the sync subscription is
  /// cancelled, but the window is left intact for the shutdown
  /// coordinator to destroy after all services have been torn down.
  Future<void> destroyTray() async {
    try {
      if (_available) await tray.trayManager.destroy();
    } catch (_) {}
    final File? file = _iconFile;
    _iconFile = null;
    if (file != null) {
      try {
        await file.delete();
      } catch (_) {}
    }
    _syncSubscription?.cancel();
    _syncSubscription = null;
    _available = false;
  }

  /// Destroy the tray icon, remove temp file, run the orderly
  /// shutdown sequence, and terminate the application.
  Future<void> quit() async {
    await destroyTray();
    await MoonShutdown.call();
    await windowManager.destroy();
  }

  // ── TrayListener callbacks ─────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // On Linux, AppIndicator shows the context menu natively on right-click.
    // The tray_manager plugin doesn't implement popUpContextMenu on Linux,
    // so we skip the call entirely.
    if (!Platform.isLinux) {
      tray.trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayMenuItemClick(tray.MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showWindow();
      case 'quit':
        quit();
    }
  }
}
