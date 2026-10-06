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

/// A [ChangeNotifier] that tracks the currently-active room, so that widgets
/// outside the room's own subtree can render room-specific content without
/// having to parse route state.
///
/// [RoomPage] sets this on mount. Its remaining readers are the room list's
/// selected row, the home dashboard's recents, and the notification service
/// deciding which room is already being read. The room's own pane stopped
/// reading it when the pane moved inside RoomPage, which is what left it a
/// global at all.
///
/// It used to carry the pinned-only timeline filter as well. The filter moved
/// into `RoomPage` with the rest of the room's own state, and the header's pin
/// button was the last reader of the old copy. It kept rendering its pressed
/// state from here while `ChatTimeline` filtered on `RoomPage`'s flag, so it
/// toggled an icon and left the timeline alone. Both copies are gone now rather
/// than left in step by hand.
class CurrentRoom extends ChangeNotifier {
  Room? _room;

  /// The currently-active room, or `null` if no room is selected.
  Room? get room => _room;

  /// Update the active room.  Passing the same instance is a no-op.
  void setRoom(Room? room) {
    if (room == _room) return;
    _room = room;
    notifyListeners();
  }
}
