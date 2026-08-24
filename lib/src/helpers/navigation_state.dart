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

import 'package:flutter/foundation.dart';

/// Sentinel IDs for the built-in navigation destinations.
const String _navHomeId = '___home___';
const String _navAllId = '___all___';

/// Tracks the active navigation destination for the space/chat switcher.
///
/// The navigation pane (leftmost bar) lets the user choose between
/// "Home" (direct messages), "All Channels" (every room), or a
/// specific "Space". When the selection changes, the rooms pane
/// updates to show only the relevant rooms.
class NavigationState extends ChangeNotifier {
  String _selectedId = _navAllId;

  /// The raw ID of the selected destination.
  /// - `___home___` -> direct messages
  /// - `___all___`  -> every room
  /// - Any other value -> a space room ID
  String get selectedId => _selectedId;

  /// Whether the "Home" (direct messages) destination is active.
  bool get isHome => _selectedId == _navHomeId;

  /// Whether the "All Channels" destination is active.
  bool get isAll => _selectedId == _navAllId;

  /// Whether a specific space is selected (not home and not all).
  bool get isSpace => !isHome && !isAll;

  /// Switch to the Home (direct messages) view.
  void selectHome() {
    if (_selectedId != _navHomeId) {
      _selectedId = _navHomeId;
      notifyListeners();
    }
  }

  /// Switch to the All Channels view (shows every room).
  void selectAll() {
    if (_selectedId != _navAllId) {
      _selectedId = _navAllId;
      notifyListeners();
    }
  }

  /// Switch to a specific space, identified by its room [spaceId].
  void selectSpace(String spaceId) {
    if (_selectedId != spaceId) {
      _selectedId = spaceId;
      notifyListeners();
    }
  }
}
