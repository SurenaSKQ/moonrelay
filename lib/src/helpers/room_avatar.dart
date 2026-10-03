// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:matrix/matrix.dart';

/// The avatar a list row should show for [room].
///
/// ## Why this is not `room.avatar`
///
/// The SDK's `Room.avatar` prefers the *room's* `m.room.avatar` state event
/// and only falls back to the counterpart's profile avatar when the room has
/// none:
///
/// ```dart
/// final avatarUrl = getState(EventTypes.RoomAvatar)?.content['url'];
/// if (avatarUrl != null) return Uri.tryParse(avatarUrl);
/// final directChatMatrixID = this.directChatMatrixID;
/// if (directChatMatrixID != null) {
///   return unsafeGetUserFromMemoryOrFallback(directChatMatrixID).avatarUrl;
/// }
/// ```
///
/// That ordering is right for a room and wrong for a one-to-one list row.
/// Clients set `m.room.avatar` on a direct chat to the avatar of whoever
/// *started* the conversation, as that client saw it at the time. So every DM
/// you opened yourself stores *your* avatar as the room's avatar, and the
/// friend never overwrites it because it is not their room to rename. The row
/// then shows your face next to their name.
///
/// It shows up on some conversations rather than all of them, which is what
/// makes it look like a rendering bug instead of a data one: it is the DMs
/// you initiated, and it is unaffected by which homeserver you are on.
///
/// The name was never affected, which is the tell. `getLocalizedDisplayname`
/// ignores `m.room.name` for a direct chat and computes the name from the
/// counterpart, so the label was always right while the picture next to it was
/// not. A wrong name and a wrong avatar would have pointed at the profile
/// lookup; a right name and a wrong avatar points at the avatar lookup, and
/// that is where this is.
///
/// ## What it does instead
///
/// For a direct chat, use the counterpart's profile avatar and nothing else.
/// Not the room avatar as a fallback: for a DM the room avatar *is* the
/// wrong picture, so falling back to it would reintroduce the bug precisely
/// when the counterpart has no avatar of their own. A DM row with no
/// counterpart avatar shows the counterpart's initial, which is right, and
/// which is what the room's letter fallback already did for every other
/// reason a thumbnail fails to load.
///
/// Group rooms and spaces are untouched: they have no counterpart, and the
/// room's own avatar is exactly what should be shown.
Uri? avatarForRoomList(Room room) {
  final counterpartId = room.directChatMatrixID;
  if (counterpartId == null) return room.avatar;
  // `unsafeGetUserFromMemoryOrFallback`, not `getUserByMXIDSync`: the SDK
  // renamed it and deprecated the old name. "Unsafe" here means it answers
  // from the local member cache and fires a background profile request when
  // it misses, which is what we want: the name beside this avatar is computed
  // the same way, so if the name is on screen the counterpart is in memory
  // and this is a cache hit. On a miss the row shows the counterpart's
  // initial for one frame and the avatar appears when the request lands,
  // which is the same degradation the SDK's own fallback has.
  return room.unsafeGetUserFromMemoryOrFallback(counterpartId).avatarUrl;
}