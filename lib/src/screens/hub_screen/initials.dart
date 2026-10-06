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

/// Initials for the three places in the hub that show who someone is.
///
/// All three wrote it themselves and two of them could throw. The pattern was
/// `split(RegExp(' +')).map((s) => s[0]).take(2)`, which reads the first
/// character of every word and indexes an empty string when there are no
/// words: a blank display name, or one that is only spaces. A Matrix user may
/// have no display name at all, so that was reachable on the hub's own front
/// door.
///
/// The third version indexed a Matrix id with a fixed offset: the navigation
/// header did `userId.substring(1, 2)`, which throws on `@a:example.org`,
/// and the blocked-users list did
/// `userId.replaceAll('@', '').substring(0, 1)`, which throws when the
/// localpart is empty. One-character localparts are legal and rare, which is
/// exactly why they survived so long.
///
/// Every circle in the hub therefore derives its letters from here, so there is
/// one implementation and it can be tested without a widget tree.
library;

/// Up to two initials from a display name, uppercased.
///
/// Returns `?` when there is no word to take a letter from.
String matrixInitials(String? displayName) {
  final words = (displayName ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  return words.take(2).map((String w) => w[0].toUpperCase()).join();
}

/// The first letter of a Matrix user id's localpart, uppercased.
///
/// The localpart is what is between the `@` and the first `:`, and reading a
/// fixed index instead of that range is the whole bug: index 1 is the `@`'s
/// neighbour, which for `@:example.org` is the `:` of the domain, so the
/// circle showed a colon.
///
/// One letter, as it was. An id is a longer string than a display name and the
/// circle is the size of one, so the second character was never available to
/// be helpful. Returns `?` when there is no letter to show at all.
String matrixIdInitial(String? userId) {
  final id = userId ?? '';
  final int start = id.startsWith('@') ? 1 : 0;
  final int end = id.indexOf(':', start);
  final local = end < 0 ? id.substring(start) : id.substring(start, end);
  if (local.isEmpty) return '?';
  return local[0].toUpperCase();
}
