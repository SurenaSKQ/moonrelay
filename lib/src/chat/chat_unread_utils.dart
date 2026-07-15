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

import 'package:matrix/matrix.dart';

/// True when [event] should count toward the unread total: regular
/// chat messages, stickers, and any future message-type event.  State
/// events (member changes, topic edits, encryption, etc.) return
/// `false` because they are bookkeeping the SDK manages on the user's
/// behalf and don't warrant a "jump to unread" nudge.
bool isMessageLikeEvent(Event event) {
  return event.type == EventTypes.Message ||
      event.type == EventTypes.Sticker;
}

/// Counts the number of unread events in [events], skipping state
/// events so they don't trigger the jump-to-unread FAB.
///
/// The list is expected in newest-first order (matching
/// [Timeline.events]).  An event counts as "unread" when it is
/// positioned newer than [fullyReadEventId] in the cache.  When no
/// marker is set (a fresh account that has never opened the room has
/// nothing to anchor the count against) the entire visible window
/// counts as unread.
///
/// State events (member joins, room renames, topic changes, etc.) are
/// intentionally excluded -- they are not messages the user needs to
/// "catch up on" in the same way as regular messages, and including
/// them caused the FAB to surface in rooms where there is genuinely no
/// unread chat content.  The jump target inherits the same rule: when
/// the user invokes it, the destination is the first real message after
/// the marker, not the first state event.
int countUnreadInWindow(List<Event>? events, String fullyReadEventId) {
  if (events == null || events.isEmpty) return 0;
  var count = 0;
  // When the marker is empty we treat every visible event as unread.
  // Still skip state events so a room with only state activity (e.g.
  // membership churn) does not pretend to have unread messages.
  if (fullyReadEventId.isEmpty) {
    for (final ev in events) {
      if (isMessageLikeEvent(ev)) count++;
    }
    return count;
  }
  for (final ev in events) {
    if (ev.eventId == fullyReadEventId) break;
    if (isMessageLikeEvent(ev)) count++;
  }
  return count;
}
