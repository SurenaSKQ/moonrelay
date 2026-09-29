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


import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';
import 'package:provider/provider.dart';

// -- Palette mode ------------------------------------------------------------

/// The active palette mode.  Determined by the leading character of
/// the input; the rest of the input is the *query*.
enum PaletteMode {
  /// Filter the static action list by substring.
  commands,

  /// Run a full backend search (rooms/spaces/messages/users/homeserver).
  search,

  /// Filter the in-app settings pages.
  settings,

  /// Restrict search to rooms/spaces.
  rooms,

  /// Restrict search to users.
  users,
}

// -- Search plumbing ---------------------------------------------------------

/// One slot in the parallel first-page fan-out.
///
/// The palette fires the message, homeserver and user-directory searches
/// at once so a slow homeserver does not hold up the others, which means
/// three independently-failable results arrive in one list. A null field
/// means that source failed or returned nothing; the palette shows the
/// rest rather than failing the whole query.
class InitialSearchResult {
  const InitialSearchResult({
    this.messages,
    this.homeserver,
    this.users,
  });

  const InitialSearchResult.empty()
      : messages = null,
        homeserver = null,
        users = null;

  final SearchPage<MessageSearchResult>? messages;
  final SearchPage<PublishedRoomsChunk>? homeserver;
  final SearchPage<Profile>? users;
}

// -- Result rows -------------------------------------------------------------

/// A single selectable row in the palette, carrying only how to run it.
///
/// The list builders own their own labels and icons, so the row itself
/// stays a dumb presentational wrapper and the palette does not have to
/// grow a variant per result kind.
class PaletteResult {
  PaletteResult(this.run);
  final VoidCallback run;
}

/// A settings page the palette can jump to, as a search result.
class SettingsEntry {
  SettingsEntry({
    required this.label,
    required this.description,
    required this.icon,
    required this.path,
  });
  final String label;
  final String description;
  final IconData icon;
  final String path;
}

/// A static command the palette can run.
class CommandAction {
  const CommandAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.callback,
  });
  final String key;
  final String label;
  final IconData icon;
  final void Function(BuildContext) callback;
}

// -- Settings lookup ---------------------------------------------------------

SettingsController? settingsControllerOrNull(BuildContext context) {
  try {
    return context.read<SettingsController>();
  } catch (_) {
    // The palette can be built in a test or a storybook without the app's
    // providers; the settings list is simply empty there.
    return null;
  }
}
