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

import 'package:window_manager/window_manager.dart';

import 'package:moonrelay/src/settings/settings_controller.dart';

/// Applies the window title bar style matching [settings.useOsTitleBar].
///
/// When the user opts into OS decorations the native title bar and caption
/// buttons are restored; otherwise the frame hides them so Moonrelay can
/// render its own slim header.  The call is safe to repeat (e.g. at boot
/// and again when the setting flips at runtime); the plugin is a no-op
/// when the window is not ready or the platform does not support it.
Future<void> applyWindowChrome(SettingsController settings) async {
  try {
    await windowManager.setTitleBarStyle(
      settings.useOsTitleBar ? TitleBarStyle.normal : TitleBarStyle.hidden,
      windowButtonVisibility: settings.useOsTitleBar,
    );
  } catch (_) {
    // The window manager plugin is not available on every platform
    // (e.g. mobile); the setting only matters on desktop.
  }
}
