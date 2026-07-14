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

/// Converts a possibly-null raw event content map into a
/// `Map<String, dynamic>`. Safe coercion from the SDK's loosely-typed
/// `Map<dynamic, dynamic>` into something strongly-keyed.
Map<String, dynamic> stringKeyMap(Object? raw) {
  if (raw is! Map) return <String, dynamic>{};
  final out = <String, dynamic>{};
  raw.forEach((k, v) => out[k.toString()] = v);
  return out;
}

/// Reads a `List<String>` from [content][key] when [content] is a
/// non-null `Map<String, dynamic>` and the value is a `List`.
///
/// Returns an empty list for any shape mismatch or when [content]
/// is null. Used throughout the app to read pinned event ids from
/// `m.room.pinned_events` state content.
List<String> stringListFromMap(Map<String, dynamic>? content, String key) {
  final raw = content?[key];
  return raw is List ? raw.cast<String>() : <String>[];
}

/// Convenience: reads pinned event IDs from a room's state.
/// Returns an empty list when the state is missing or malformed.
List<String> pinnedEventIds(Room room) {
  final state = room.getState('m.room.pinned_events');
  final raw = state?.content['pinned'];
  return raw is List ? raw.cast<String>() : <String>[];
}
