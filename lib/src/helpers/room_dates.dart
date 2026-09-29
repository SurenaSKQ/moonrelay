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

/// The `created_at` of [room]'s `m.room.create` event, or `null` when the
/// room predates the field, the event has not synced yet, or the value is
/// unparseable.
///
/// Shared by the room and space settings screens and the room details page,
/// which all show the same "Created" row.
DateTime? roomCreatedAt(Room room) {
  final raw = room.getState(EventTypes.RoomCreate)?.content.tryGet('created_at');
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// A stable, sortable `YYYY-MM-DD` rendering of [date].
///
/// Deliberately locale-independent: the creation date is a fact about the
/// room, not something to localise, and a date that reorders itself when the
/// user switches language is worse than a slightly odd one.
String formatIsoDay(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
