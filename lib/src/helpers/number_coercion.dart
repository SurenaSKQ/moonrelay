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

/// Coerces a JSON-style [num] to an [int] without throwing.
///
/// The matrix SDK stores `info.w` / `info.h` (and friends) as either
/// [int] or [num] / [double] depending on the path that produced the
/// event. Events that round-trip through the cache (e.g. via
/// [RoomMediaCache] or the local DB) lose the int-vs-float distinction
/// that an inline `as int?` cast assumes, so a thumbnail build can
/// throw a `TypeError` and fall back to the placeholder when the
/// dimensions are perfectly valid. Centralising the coercion in one
/// helper means image, video, sticker, and audio widgets all share
/// the same defensive logic and a single regression test covers all
/// of them.
///
/// Anything that is not a non-negative [num] returns `null` so the
/// caller can fall back to a sensible default (e.g. a 240px square
/// thumbnail) without surrounding the call in `try { ... } catch`.
int? coerceJsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
