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

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/global_shortcut_listener.dart';

// -----------------------------------------------------------------------------
// What the keyboard does, in one list
// -----------------------------------------------------------------------------

/// Where a shortcut applies.
///
/// The distinction is load bearing and was missing. The keybind settings page
/// put `Ctrl+F` and `Ctrl+Shift+M` under a heading reading "Global
/// shortcuts", and neither is global: `Ctrl+F` focuses the search field of
/// whichever room is open, and `Ctrl+Shift+M` collapses the sidebar of
/// whichever room is open. Someone reading that page would reasonably expect
/// both to work on the welcome screen, and neither does.
enum ShortcutScope {
  /// Fires anywhere in the app, including where there is no room.
  global,

  /// Fires only while a room's conversation has focus.
  room,

  /// Fires only while the composer is accepting text.
  composer,
}

/// One bindable chord and what it does.
class ShortcutReferenceEntry {
  const ShortcutReferenceEntry({
    required this.keys,
    required this.description,
    required this.scope,
    this.layoutDependent = false,
  });

  /// The chord as the reader sees it, `Ctrl+Shift+P`.
  final List<String> keys;

  /// Resolved from [AppLocalizations] through a function rather than stored as
  /// a string, so this file needs neither a `BuildContext` nor a localization
  /// lookup to be a top-level value.
  final String Function(AppLocalizations l10n) description;

  final ShortcutScope scope;

  /// True for a chord that only fires on some keyboard layouts.
  ///
  /// `Ctrl+Shift+?` is `Ctrl+Shift+/` on a US layout, so the reference says so
  /// rather than letting a reader on another layout conclude the app is broken.
  final bool layoutDependent;
}

/// Every shortcut the app binds.
///
/// Two readers, one list: the cheat sheet and the keybind settings page both
/// render this, and neither holds its own copy. They had held two, they
/// disagreed, and the disagreement was invisible, because nothing compared
/// them. The settings page was missing `Esc`, listed the room-scoped pair as
/// global, and carried a stray fragment of a comment about `Ctrl+Shift+R`,
/// which no longer exists, immediately above the chord that replaced it.
///
/// The global chords are read from [ShortcutChord] rather than retyped, so the
/// label in the reference and the key that actually fires come from one
/// declaration. `Ctrl+Shift+R` is absent on purpose: it was listed as a
/// sidebar toggle, was never bound to anything, and was removed rather than
/// rebound, because the pane it would have opened belongs to one room and a
/// global chord would have to guess which.
List<ShortcutReferenceEntry> shortcutReference() => <ShortcutReferenceEntry>[
      ShortcutReferenceEntry(
        keys: ShortcutChord.commandPalette.keys,
        description: (AppLocalizations l10n) => l10n.shortcutOpenCommandPalette,
        scope: ShortcutScope.global,
      ),
      ShortcutReferenceEntry(
        keys: ShortcutChord.showShortcuts.keys,
        description: (AppLocalizations l10n) => l10n.shortcutShowShortcuts,
        scope: ShortcutScope.global,
        layoutDependent: true,
      ),
      ShortcutReferenceEntry(
        keys: const <String>['Ctrl', 'F'],
        description: (AppLocalizations l10n) => l10n.shortcutInRoomSearch,
        scope: ShortcutScope.room,
      ),
      ShortcutReferenceEntry(
        keys: const <String>['Ctrl', 'Shift', 'M'],
        description: (AppLocalizations l10n) => l10n.shortcutToggleLeftSidebar,
        scope: ShortcutScope.room,
      ),
      ShortcutReferenceEntry(
        keys: const <String>['Ctrl', 'B'],
        description: (AppLocalizations l10n) => l10n.shortcutBold,
        scope: ShortcutScope.composer,
      ),
      ShortcutReferenceEntry(
        keys: const <String>['Ctrl', 'I'],
        description: (AppLocalizations l10n) => l10n.shortcutItalic,
        scope: ShortcutScope.composer,
      ),
      ShortcutReferenceEntry(
        keys: const <String>['Ctrl', 'E'],
        description: (AppLocalizations l10n) => l10n.shortcutCode,
        scope: ShortcutScope.composer,
      ),
      ShortcutReferenceEntry(
        keys: const <String>['Enter'],
        description: (AppLocalizations l10n) => l10n.shortcutSendMessage,
        scope: ShortcutScope.composer,
      ),
      ShortcutReferenceEntry(
        keys: const <String>['Shift', 'Enter'],
        description: (AppLocalizations l10n) => l10n.shortcutNewline,
        scope: ShortcutScope.composer,
      ),
      ShortcutReferenceEntry(
        keys: const <String>['Esc'],
        description: (AppLocalizations l10n) => l10n.shortcutCloseOverlay,
        scope: ShortcutScope.global,
      ),
    ];

/// The entries for one scope, in list order.
List<ShortcutReferenceEntry> shortcutsInScope(
  List<ShortcutReferenceEntry> all,
  ShortcutScope scope,
) =>
    all.where((ShortcutReferenceEntry e) => e.scope == scope).toList(
          growable: false,
        );
