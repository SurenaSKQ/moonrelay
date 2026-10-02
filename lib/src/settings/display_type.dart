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

/// How a message row is laid out.
///
/// The ordinal is persisted (`SharedPreferences` stores the index), so the
/// declaration order is part of the on-disk format. Inserting a value in
/// the middle would silently reinterpret every user's saved choice.
///
/// User-facing names for these live in the ARB as `displayModern`,
/// `displayIrc`, and `displayBubbles`, and the settings page reads them
/// there. There used to be a `DisplayTypeExtension.label` returning the
/// English strings directly; nothing referenced it, so a rename would have
/// been a silent no-op on every language but English.
enum DisplayType {
  modern,
  irc,
  bubbles,
}
