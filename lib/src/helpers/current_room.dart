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
import 'package:matrix/matrix.dart';

/// A [ChangeNotifier] that tracks the currently-active room so that
/// sibling widgets such as the right sidebar can render room-specific
/// content without having to parse route state.
///
/// [RoomPage] sets this on mount; [DashboardLayout] reads it to build
/// the room-info and members sidebars.
class CurrentRoom extends ChangeNotifier {
  Room? _room;

  /// The currently-active room, or `null` if no room is selected.
  Room? get room => _room;

  /// Whether the timeline should show only pinned messages.
  bool _pinnedFilterActive = false;

  bool get pinnedFilterActive => _pinnedFilterActive;

  /// The event IDs of the currently pinned messages, derived from room
  /// state `m.room.pinned_events`.
  List<String> get pinnedEventIds {
    final r = _room;
    if (r == null) return [];
    final state = r.getState('m.room.pinned_events');
    if (state == null) return [];
    final pinned = state.content['pinned'];
    if (pinned is List) return pinned.cast<String>();
    return [];
  }

  /// Toggle the pinned-only filter on the timeline.
  void togglePinnedFilter() {
    _pinnedFilterActive = !_pinnedFilterActive;
    notifyListeners();
  }

  /// Disable the pinned-only filter.
  void disablePinnedFilter() {
    if (!_pinnedFilterActive) return;
    _pinnedFilterActive = false;
    notifyListeners();
  }

  /// Update the active room.  Passing the same instance is a no-op.
  void setRoom(Room? room) {
    if (room == _room) return;
    _room = room;
    _pinnedFilterActive = false;
    notifyListeners();
  }
}
