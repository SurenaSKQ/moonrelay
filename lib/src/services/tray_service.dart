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

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

/// Manages the system tray icon and background behaviour for Moonrelay.
///
/// Provides a tray icon with:
/// - Tooltip showing unread notification count
/// - Context menu with Show/Hide and Quit actions
/// - Left-click toggles window visibility
///
/// Call [init] once after the Matrix [Client] is ready.
class TrayService with tray.TrayListener {
  static TrayService? _instance;

  /// The global singleton, or `null` if not initialised.
  static TrayService? get instance => _instance;

  final Client _client;
  final Logger _log;
  int _unreadCount = 0;

  TrayService._(this._client, this._log);

  /// Create the tray icon, set up the context menu, and start listening for
  /// unread count updates from the Matrix sync stream.
  static Future<void> init({
    required Client client,
    required Logger log,
  }) async {
    _instance = TrayService._(client, log);
    await _instance!._setup();
  }

  Future<void> _setup() async {
    try {
      tray.trayManager.addListener(this);

      // Load the tray icon from assets and write it to a temp file so that
      // the platform plugin can access it via a file system path.
      // Windows requires .ico format; other platforms use .png.
      final String iconName = Platform.isWindows
          ? 'assets/images/logo.ico'
          : 'assets/images/logo.png';
      final String ext = Platform.isWindows ? 'ico' : 'png';
      final ByteData byteData = await rootBundle.load(iconName);
      final Directory tmpDir = await getTemporaryDirectory();
      final File iconFile = File('${tmpDir.path}/moonrelay_tray_icon.$ext');
      await iconFile.writeAsBytes(byteData.buffer.asUint8List());
      await tray.trayManager.setIcon(iconFile.path);

      await tray.trayManager.setToolTip('Moonrelay');
      await _updateMenu();
      _updateUnreadCount();

      // Watch the Matrix sync stream for unread count changes.
      _client.onSync.stream.listen((_) => _updateUnreadCount());

      _log.i('Tray service initialised');
    } catch (e) {
      _log.w('Tray service initialisation failed', error: e);
    }
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

  void _updateUnreadCount() {
    final int total = _client.rooms
        .where((r) => r.membership == Membership.join)
        .fold<int>(0, (sum, r) => sum + r.notificationCount);
    if (total != _unreadCount) {
      _unreadCount = total;
      tray.trayManager.setToolTip(
        total > 0 ? 'Moonrelay ($total)' : 'Moonrelay',
      );
    }
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

  /// Destroy the tray icon and terminate the application.
  Future<void> quit() async {
    try {
      await tray.trayManager.destroy();
    } catch (_) {}
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
