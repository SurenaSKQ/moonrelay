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

// Where the palette's candidates come from.
//
// The settings pages used to be a hand-written list of eight paths in
// `palette_commands.dart`. There are thirteen settings sub-items. So five pages
// were unreachable from the palette, and the list also named a ninth
// (`/hub/settings/network`) that has never existed, which rendered an empty
// page with a confident title.
//
// That is fixed at the root rather than by making the list longer: the pages
// come from [buildSettingsNavigationItems], which is the same builder the hub
// screen renders its own overview from. A new settings page is now in the
// palette because it exists, not because someone remembered.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_result.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';
import 'package:provider/provider.dart';

/// Reads the settings controller, or null when there is none.
///
/// The palette is pushed on the root navigator and can be built in a test
/// without the app's providers, so the toggle action has to survive having no
/// settings controller. It fails closed, doing nothing, rather than throwing.
SettingsController? paletteSettingsOrNull(BuildContext context) {
  try {
    return context.read<SettingsController>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Opens the hub at [category], optionally at one of its sub-items.
///
/// `push`, so the chat the palette was opened over is still underneath and the
/// hub's back button returns to it. This is what a modal overlay used to do;
/// the difference is that the hub is a real location, so a palette entry and
/// the hub's own navigation end up at the same route rather than only one of
/// them working.
void openHub(BuildContext context, {String? category, String? sub}) {
  context.push(hubPath(category: category, sub: sub));
}

/// Supplies the palette's local candidates, and converts remote hits into
/// results.
///
/// A class rather than a bag of top-level functions because it takes the
/// `Client` and the settings controller, and passing those through four
/// signatures is how the old list builders ended up reading `context` in
/// places that had none.
class PaletteSources {
  const PaletteSources();

  /// Actions with no page of their own: things that toggle rather than open.
  ///
  /// Everything that *is* a page comes from [pages] instead. Keeping the two
  /// lists apart is the point: a search that offers "Toggle Right Sidebar"
  /// among the pages is offering an action shaped like a destination.
  List<PaletteResult> actions(AppLocalizations l10n) =>
      <PaletteResult>[_toggleSidebar(l10n)];

  /// Every hub page, derived from the hub's own navigation.
  ///
  /// The categories come first, then the settings sub-items, because that is
  /// the order the hub itself presents them in and a search result list that
  /// disagreed with the thing it searches for would be its own small puzzle.
  List<PaletteResult> pages(AppLocalizations l10n) {
    return <PaletteResult>[
      for (final MapEntry<String, String> category in _categories(l10n).entries)
        PaletteResult(
          source: PaletteSource.page,
          title: category.value,
          icon: _categoryIcon(category.key),
          keywords: <String>[category.key],
          run: (BuildContext context) =>
              openHub(context, category: category.key),
        ),
      for (final HubNavigationItem item in buildSettingsNavigationItems(l10n))
        if (item.key != null)
          PaletteResult(
            source: PaletteSource.page,
            title: item.label,
            icon: item.icon,
            // The key as a keyword is what lets `keyb` find "Keyboard
            // Shortcuts" without the word "keybind" appearing in the interface
            // anywhere.
            keywords: <String>[item.key!, l10n.appSettings],
            run: (BuildContext context) => openHub(
              context,
              category: HubRouteKeys.settings,
              sub: item.key,
            ),
          ),
    ];
  }

  /// Joined rooms and spaces, as candidates.
  ///
  /// Unfiltered by the query. Scoring decides which of them match, and a source
  /// that pre-filters with `contains` would then throw away the fuzzy hits that
  /// scoring exists to find.
  List<PaletteResult> joinedRooms(Client client) {
    // `client.rooms` throws before the first sync rather than returning an
    // empty list, so a palette opened in the first second of the app would
    // throw on open. Losing the room list is survivable; losing the palette is
    // not.
    final List<Room> rooms;
    try {
      rooms = client.rooms;
    } on Object {
      return const <PaletteResult>[];
    }
    return <PaletteResult>[
      for (final Room room in rooms)
        if (room.id.isNotEmpty)
          PaletteResult.room(room, (BuildContext context) {
            RecentActivity.instance.recordRoom(room.id);
            openRoom(context, room.id);
          }),
    ];
  }

  Map<String, String> _categories(AppLocalizations l10n) => <String, String>{
        HubRouteKeys.accounts: l10n.accounts,
        HubRouteKeys.settings: l10n.appSettings,
        HubRouteKeys.about: l10n.about,
      };

  IconData _categoryIcon(String key) => switch (key) {
        HubRouteKeys.accounts => LucideIcons.userRound,
        HubRouteKeys.settings => LucideIcons.settings,
        HubRouteKeys.about => LucideIcons.info,
        _ => LucideIcons.circle,
      };

  /// The one action that is not a page.
  ///
  /// The other seven used to be here, and five of them were things this module
  /// can now derive, which is how "Add a Room" survived the route it pointed at
  /// being deleted.
  PaletteResult _toggleSidebar(AppLocalizations l10n) => PaletteResult(
        source: PaletteSource.action,
        title: l10n.commandPaletteToggleRightSidebar,
        icon: LucideIcons.panelRight,
        keywords: <String>[
          l10n.commandPaletteToggleRightSidebar,
          'sidebar',
          'panel',
          'pane',
        ],
        run: (BuildContext context) {
          final SettingsController? settings = paletteSettingsOrNull(context);
          if (settings == null) return;
          settings.setRightSidebarVisible(!settings.rightSidebarVisible);
        },
      );
}

/// Converts user-directory hits into results.
List<PaletteResult> paletteUserResults(List<Profile> users) => <PaletteResult>[
      for (final Profile user in users)
        PaletteResult(
          source: PaletteSource.user,
          title: user.displayName ?? user.userId,
          subtitle: user.userId,
          icon: LucideIcons.userRound,
          keywords: <String>[user.userId],
          run: (BuildContext context) {
            final encoded = Uri.encodeComponent(user.userId);
            context.go('/profile/$encoded');
          },
        ),
    ];

/// Converts message-search hits into results.
List<PaletteResult> paletteMessageResults(List<MessageSearchResult> messages) =>
    <PaletteResult>[
      for (final MessageSearchResult message in messages)
        PaletteResult(
          source: PaletteSource.message,
          title: _oneLine(message.event.body),
          subtitle: message.room.getLocalizedDisplayname(),
          icon: LucideIcons.messageSquare,
          // The room id and the sender are both worth matching: a message is
          // often found by who sent it rather than by what it said, and the
          // subtitle is the only place the sender's name appears.
          keywords: <String>[
            message.room.id,
            message.event.senderFromMemoryOrFallback.displayName ?? '',
          ].where((String value) => value.isNotEmpty).toList(growable: false),
          run: (BuildContext context) {
            RecentActivity.instance.recordRoom(message.room.id);
            openRoom(context, message.room.id);
          },
        ),
    ];

/// Converts public-rooms directory hits into results.
///
/// A space here is a room whose `room_type` is `m.space`, which is the same
/// rule the Explore page uses and for the same reason: the public room
/// directory has no room-type filter, so the distinction is made over the
/// response. A chunk with no `room_type` is a room, never a space.
///
/// Every one of these navigates to the preview route rather than the room
/// route, because the user is not in them. `/main/rooms/:roomid` goes through
/// `RoomResolver`, which looks the room up among joined rooms and would spin
/// forever on a room that is not joined.
List<PaletteResult> paletteDirectoryResults(
  List<PublishedRoomsChunk> chunks,
  AppLocalizations l10n,
) =>
    <PaletteResult>[
      for (final PublishedRoomsChunk chunk in chunks)
        if (chunk.roomId.isNotEmpty)
          PaletteResult(
            source: chunk.roomType == 'm.space'
                ? PaletteSource.space
                : PaletteSource.room,
            title: chunk.name ?? chunk.canonicalAlias ?? chunk.roomId,
            subtitle: l10n.paletteDirectoryMembers(chunk.numJoinedMembers),
            icon: chunk.roomType == 'm.space'
                ? LucideIcons.boxes
                : LucideIcons.globe,
            // The alias and the topic are both searchable but neither is worth a
            // second line. The topic in particular is the field a public room uses
            // to describe itself, so it is frequently the only thing in the response
            // that a user searching for a subject would match against.
            keywords: <String>[
              chunk.roomId,
              if (chunk.canonicalAlias != null) chunk.canonicalAlias!,
              if (chunk.topic != null) chunk.topic!,
            ].where((String value) => value.isNotEmpty).toList(growable: false),
            run: (BuildContext context) =>
                context.go('/main/room_preview/${chunk.roomId}'),
          ),
    ];

/// The message body on one line, for a row that is 48 pixels tall.
///
/// Truncating here rather than in the widget keeps the text the user matched
/// against the text they can see. A row that renders an ellipsis while
/// matching against the full body is a palette that finds a message and then
/// shows a fragment that does not contain what was typed.
String _oneLine(String body) {
  final String flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= 140 ? flat : '${flat.substring(0, 139)}…';
}
