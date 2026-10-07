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

// The room's side pane, presented as a bottom sheet on the single-pane shell.
//
// One widget, two presentations. The pane is the same `RoomPane` with the same
// room and the same state; only its container differs. That is the point of the
// refactor: previously the sheet and the inline column were two separate hosts
// of a shared body, and the sheet's host had its own hardcoded `LayoutSize`,
// so the two could disagree about what size they were.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';

/// Shows [room]'s side pane in a bottom sheet.
///
/// The initial [tab] is whatever the caller had open, so opening the sheet from
/// a pinned message while the pinned tab was showing does not throw the user
/// back to the info tab.
Future<void> showRoomPaneSheet(
  BuildContext context, {
  required Room room,
  required RoomPaneTab initialTab,
  required List<String> pinnedEventIds,
  required bool pinnedFilterActive,
  required void Function(RoomPaneTab) onSelectTab,
  required VoidCallback onTogglePinnedFilter,
  void Function(String eventId)? onJumpToEvent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      // 85% rather than the old 90%: a sheet that reaches a tenth of the way
      // down from the top of a phone covers the room header entirely, so there
      // is nothing left on screen to say which room the pane belongs to.
      final double height = MediaQuery.sizeOf(sheetContext).height * 0.85;
      return SizedBox(
        height: height,
        child: RoomPane(
          room: room,
          tab: initialTab,
          pinnedEventIds: pinnedEventIds,
          pinnedFilterActive: pinnedFilterActive,
          onSelectTab: (RoomPaneTab tab) {
            onSelectTab(tab);
            Navigator.of(sheetContext).maybePop();
          },
          // The sheet has no timeline beside it, so there is nothing to scroll.
          // Closing is the honest response to a jump the user cannot see.
          onJumpToEvent: onJumpToEvent == null
              ? null
              : (String eventId) {
                  onJumpToEvent(eventId);
                  Navigator.of(sheetContext).maybePop();
                },
          onTogglePinnedFilter: onTogglePinnedFilter,
          onClose: () => Navigator.of(sheetContext).maybePop(),
        ),
      );
    },
    barrierColor: Colors.black54,
  );
}
