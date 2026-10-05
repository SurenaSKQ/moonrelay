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

// What the room's side pane is showing.
//
// This was `RightPaneChoice`, in `layout_settings.dart`, with four values and a
// fifth one that lived somewhere else entirely. Two names for one thing is how
// two panes end up competing for the same 320 pixels of a conversation.
//
// The search is the fifth value and it is the point of the merge. It used to be
// a separate `InRoomSearchPanel` rendered as a second column beside the first,
// so a room with the side pane open and a search running had two right-hand
// columns and two owners, and the search one had to guess which room it was
// describing from a global.
//
// [search] is the only value that is not persisted, because it is the only one
// that means "the user is mid-task" rather than "the user prefers this tab".
// Reopening a room with a stale search half-filled from the last session would
// be a bug, so [restorable] is what the settings layer is allowed to store.

/// A tab in the room's side pane.
enum RoomPaneTab {
  /// No pane. The conversation gets the whole width.
  none,

  /// Room details: topic, id, type, encryption, members count.
  info,

  /// The member list, with its own search field.
  members,

  /// Threads started in this room.
  threads,

  /// Pinned messages.
  pinned,

  /// Full-text search within this room.
  search;

  /// The tabs the user can pick, in the order the strip shows them.
  ///
  /// [none] is absent because "close the pane" is what the close button and the
  /// room header's search toggle already do; offering it as a fifth target
  /// would be a tab you cannot leave by tapping the tab.
  static const List<RoomPaneTab> selectable = <RoomPaneTab>[
    info,
    members,
    threads,
    pinned,
    search,
  ];

  /// Whether this value may be written to preferences.
  ///
  /// [search] may not. Everything else is a preference that should survive a
  /// restart; a search is a task, not a preference.
  bool get restorable => this != RoomPaneTab.search;

  /// The value to store and restore, collapsing [search] to [none].
  RoomPaneTab get restorableAs => restorable ? this : RoomPaneTab.none;
}
