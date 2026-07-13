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

/// How chat list rows and message bubbles are spaced.
///
/// Compact density removes vertical padding across rooms, message rows,
/// list tiles, and the command palette so more content fits on screen.
enum LayoutDensity {
  comfortable,
  compact,
}

/// How the user wants the app to handle incoming automatic media downloads.
enum AutoDownloadPolicy {
  always,
  wifi,
  never,
}

/// What key sequence sends a message in the chat composer.
enum SendShortcut {
  enter,
  cmdEnter,
  both,
}

/// What happens on the first click of the tray icon.
enum TrayClickAction {
  toggle,
  show,
  openUnread,
}

/// Minimum log severity that should be persisted to disk.
enum LogLevel {
  all,
  trace,
  debug,
  info,
  warning,
  error,
  fatal,
}

/// How animated UI transitions should feel.
enum MotionLevel {
  /// Honour the boolean toggle as-is (current behaviour).
  on,

  /// Off  every animation becomes `Duration.zero`.
  off,
}