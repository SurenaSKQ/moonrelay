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


/// Hides the OS title bar and caption buttons so Moonrelay can draw its own.
///
/// Called once per frame at boot rather than on a settings change, because
/// there is no longer a setting: the app's title bar is not optional. The OS
/// bar and the in-app one draw the same thirty pixels, so drawing both would
/// either waste a strip or leave the window with two of them.
///
/// Safe to repeat and safe to call before the window exists; the plugin is a
/// no-op on mobile, where there is no title bar to hide.
Future<void> applyWindowChrome() async {
  try {
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  } catch (_) {
    // The window manager plugin is not available on every platform
    // (e.g. mobile); the setting only matters on desktop.
  }
}


