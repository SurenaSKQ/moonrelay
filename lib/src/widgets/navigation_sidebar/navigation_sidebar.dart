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
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/space_hierarchy.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/sidebar_profile_pill.dart';
import 'package:moonrelay/src/widgets/space_rooms_tree.dart';
import 'package:moonrelay/src/widgets/menu_row.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/room_search_field.dart';

/// The navigation sidebar of the full (wide) dashboard shell.
///
/// Unifies what used to be three separate columns into a single sidebar:
///
///  * the user profile pill and the command palette button (moved out of
///    the window header),
///  * the Home / All / Add-Room destination rows,
///  * the spaces list (with the existing user-defined grouping, ordering,
///    context menus, and drag-and-drop reorder logic),
///  * the destination-filtered rooms list below it.
///
/// The spaces region and the rooms region scroll independently so the
/// existing [RoomsPane] / [SpaceRoomsPane] widgets can be reused
/// verbatim instead of re-implementing their sync-pulse-driven state.
class NavigationSidebar extends StatefulWidget {
  const NavigationSidebar({super.key});

  @override
  State<NavigationSidebar> createState() => _NavigationSidebarState();
}

class _NavigationSidebarState extends State<NavigationSidebar> {
  /// Space ids observed so far; used to detect newly-joined spaces for
  /// the auto-grouping pass.  Ported unchanged from the navigation rail.
  Set<String> _knownIds = {};

  // The drag-hover field went with the space rows.  Reordering is still
  // possible, on the rail icons; a 72px column has no room for the drop
  // highlight the old rows drew, which is the one part of the move that costs
  // something.

  /// Set when a new space arrived and the auto-group pass is still due.
  bool _pendingAutoGroup = false;

  /// Cached set of space room ids, refreshed only when the sync pulse
  /// advances.  Ported unchanged from the navigation rail.
  Set<String>? _cachedSpaceIds;
  int _cachedSpaceIdsVersion = -1;

  /// Most recent pulse version observed.  Compared against the current
  /// value in [build] (where `context.select` is legal) to detect sync
  /// ticks.
  int _syncVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPendingAutoGroup());
  }

  void _runPendingAutoGroup() {
    if (!_pendingAutoGroup || !mounted) return;
    _pendingAutoGroup = false;
    final sp = context.read<SpacePreferences>();
    final c = context.read<Client>();
    final ids = c.rooms.where((r) => r.isSpace).map((r) => r.id).toSet();
    final newIds = ids.difference(_knownIds);
    _knownIds = ids;
    if (newIds.isEmpty) return;
    final auto = computeAutoGroups(c.rooms);
    final rel = <String, List<String>>{};
    for (final e in auto.entries) {
      final spaceId = e.key.startsWith('_grp_') ? e.key.substring(5) : e.key;
      if (newIds.contains(spaceId) || e.value.any((x) => newIds.contains(x))) {
        rel[e.key] = e.value;
      }
    }
    if (rel.isNotEmpty) sp.mergeIntoGroups(rel);
  }

  // The auto-group bookkeeping below still runs even though this pane no longer
  // draws spaces.  It owns `SpacePreferences.spaceOrder` and `spaceGroups`,
  // which the rail's ordering reads and which the space context menu's group
  // actions mutate, so moving the *rendering* out of this file did not make
  // the data dead.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Client client;
    try {
      client = Provider.of<Client>(context);
    } catch (_) {
      // Client may be absent during logout transition; return empty
      // widget until the route changes away from the dashboard.
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final layers = MoonrelayThemeExtension.of(context).layers;
    // Listened to so the auto-group pass below stays in step with a join.  The
    // rail reads the same preference for ordering; this pane just needs to
    // know when to recompute the groups.
    context.watch<SpacePreferences>();

    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    if (pulseVersion != _syncVersion) {
      _syncVersion = pulseVersion;
    }

    // Refresh the cached space id set only when the sync pulse moves.
    if (_cachedSpaceIdsVersion != _syncVersion) {
      _cachedSpaceIdsVersion = _syncVersion;
      _cachedSpaceIds =
          client.rooms.where((r) => r.isSpace).map((r) => r.id).toSet();
      final newIds = _cachedSpaceIds!.difference(_knownIds);
      if (newIds.isNotEmpty) {
        _knownIds = _cachedSpaceIds!;
        _pendingAutoGroup = true;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _runPendingAutoGroup());
      }
    }

    return Consumer<NavigationState>(
      builder: (context, nav, _) {
        // Spaces are not built here any more. They live in the icon rail
        // beside this pane, which is the whole point of moving them: a user
        // with a dozen spaces was spending half this column on them before
        // reaching a single room, and the room list is what they opened the
        // app to read. The auto-group pass below still runs, because it feeds
        // the rail's ordering and the context menu's group actions.
        final roomsBody = _buildRoomsBody(context, nav);

        return Material(
          color: scheme.surfaceContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title bar, filter, rooms.
              //
              // There is no section header between the filter and the list.
              // It used to carry the region name and a collapse toggle, and it
              // was saying the thing the title bar directly above it already
              // says: both named the destination the rail has selected, so the
              // pane opened with the same word twice and a chevron that hid
              // the list the user came to read. Collapsing a room list is not a
              // thing anyone wants; hiding it behind a control to bring it back
              // is a worse way to spend a row than not having one.
              _buildTitleBar(scheme, l10n),
              const RoomSearchField(),
              Expanded(child: roomsBody),
              // The account is at the bottom, pinned, which is where every
              // other client puts it and where a user's thumb expects it.
              // At the top it was the first thing the pane showed and the
              // last thing anyone looked at.
              Divider(height: 1, color: layers.hairline),
              const _SidebarFooter(),
            ],
          ),
        );
      },
    );
  }

  /// The pane's title bar: what is being listed, and the actions for it.
  ///
  /// Clickable as a whole. It names the destination and it carries the only
  /// actions that apply to the destination rather than to one room, so making
  /// the reader aim at a `+` in the corner to find them was making the label a
  /// label. The whole bar is now the target, the title is the thing that says
  /// what will open, and a chevron says it is openable.
  ///
  /// Its height is [MoonrelayDesignTokens.paneBarHeight], shared with the
  /// composer. They were derived independently and drifted a few pixels apart,
  /// which is enough for the eye to read the conversation as sitting between
  /// two unrelated strips rather than inside a frame.
  Widget _buildTitleBar(ColorScheme scheme, AppLocalizations l10n) {
    final nav = context.watch<NavigationState>();
    final title = _destinationTitle(nav, l10n);
    final t = MoonrelayThemeExtension.of(context).tokens;
    final layers = MoonrelayThemeExtension.of(context).layers;

    return Material(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => _showDestinationMenu(nav, l10n),
        // The bar is furniture, and the list below it is the part that
        // scrolls. One hairline under it is what tells the eye so.
        child: Container(
          height: t.paneBarHeight,
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: layers.hairline),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    // The largest text in this pane. It names the thing the
                    // whole column is about, so it is set at header weight
                    // rather than at row weight.
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: t.spaceSm),
              // A chevron rather than an ellipsis. It says "this opens
              // something" rather than "there is more here", which is the
              // difference between a menu and a truncation.
              Icon(
                LucideIcons.chevronDown,
                size: t.iconSizeSmall,
                color: scheme.onSurfaceVariant.withValues(alpha: t.opacityMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The destination's own actions, from its header.
  ///
  /// Replaces the `+` that used to sit here. That button only ever opened the
  /// create form, which is one of four things a user might want from a room
  /// list, and putting it in the header meant the other three had nowhere to
  /// live. This menu carries the one that applies to the selected space and,
  /// when no space is selected, the ones that apply to the room list itself.
  void _showDestinationMenu(NavigationState nav, AppLocalizations l10n) {
    final client = Provider.of<Client>(context, listen: false);
    final space = nav.isSpace ? client.getRoomById(nav.selectedId) : null;

    final entries = <_DestinationAction>[
      if (space != null) ...[
        _DestinationAction(
          value: 'open',
          icon: LucideIcons.folderOpen,
          label: l10n.openSpace,
        ),
        _DestinationAction(
          value: 'settings',
          icon: LucideIcons.settings,
          label: l10n.spaceSettings,
        ),
        // The one the header's `+` used to be reachable next to, and the one
        // that most obviously belongs to a space rather than to a room.
        _DestinationAction(
          value: 'addRoom',
          icon: LucideIcons.plus,
          label: l10n.addRoomToSpace,
        ),
      ] else ...[
        _DestinationAction(
          value: 'create',
          icon: LucideIcons.plus,
          label: l10n.createRoomOrSpace,
        ),
        _DestinationAction(
          value: 'join',
          icon: LucideIcons.search,
          label: l10n.findRoomsAndSpaces,
        ),
      ],
    ];

    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()!
            as RenderBox;
    final anchor = (context.findRenderObject() as RenderBox?)
        ?.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          anchor ?? Offset.zero,
          anchor ?? Offset.zero,
        ),
        Offset.zero & overlay.size,
      ),
      constraints: moonrelayMenuConstraints(),
      items: [
        for (final action in entries)
          MoonrelayMenuItem<String>(
            value: action.value,
            icon: action.icon,
            label: action.label,
          ),
      ],
    ).then((selected) {
      if (selected == null || !mounted) return;
      switch (selected) {
        case 'open':
          if (space != null) context.push('/main/space/${space.id}');
        case 'settings':
          if (space != null) {
            context.push('/main/space/${space.id}/settings');
          }
        case 'addRoom':
          // The space's own settings, scrolled to the section that adds a
          // room. Sending someone to the create form here would create a new
          // room rather than adding an existing one, which is the opposite of
          // what the label says.
          if (space != null) {
            context.push('/main/space/${space.id}/settings');
          }
        case 'create':
          context.push(MoonRoutePaths.createRoomPath);
        case 'join':
          context.push(MoonRoutePaths.explorePath);
      }
    });
  }

  /// What the pane is currently listing.
  ///
  /// A space's own name when one is selected, so the bar is the same shape of
  /// statement whichever destination is active.
  String _destinationTitle(NavigationState nav, AppLocalizations l10n) {
    if (!nav.isSpace) {
      return nav.isHome ? l10n.friends : l10n.rooms;
    }
    try {
      final client = Provider.of<Client>(context, listen: false);
      final space = client.getRoomById(nav.selectedId);
      if (space != null) return space.getLocalizedDisplayname();
    } catch (_) {
      // No client during the logout transition. The generic title is the
      // honest answer: there is no space name to show because there is no
      // client to ask.
    }
    return l10n.spaces;
  }

  /// The `+` on the rooms section header.
  // -- Rooms region -------------------------------------------------------

  /// Computes the rooms body for the active navigation destination.
  ///
  /// [SpaceRoomsPane] for a selected space and a filtered [RoomsPane]
  /// otherwise. It no longer returns a title: the section header that consumed
  /// it is gone, and the title bar above reports the same thing from the same
  /// [NavigationState].
  Widget _buildRoomsBody(BuildContext context, NavigationState nav) {
    final Client client;
    try {
      client = Provider.of<Client>(context, listen: false);
    } catch (_) {
      // Client may be absent during the logout transition. An empty body is
      // the honest answer: there are no rooms to show because there is no
      // client to ask for them.
      return const SizedBox.shrink();
    }

    if (nav.isSpace) {
      final Room? space = client.getRoomById(nav.selectedId);
      if (space == null) return const SizedBox.shrink();
      return SpaceRoomsPane(space: space, client: client);
    }

    return RoomsPane(
      roomFilter: nav.isHome ? roomIsDirectChat : roomIsChat,
    );
  }
}

/// The pinned bottom strip of the navigation sidebar: the signed-in
/// account.
///
/// Split out rather than inlined in the column so its position is a
/// property of the footer and not of whatever the column happens to be
/// listing. It sits below both list sections, so it stays put when a
/// section is collapsed or a space is expanded.
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: const SidebarProfilePill(),
    );
  }
}

// Row widgets


// Drag-and-drop helpers: ported unchanged from the navigation rail

// Context menu: long-press / right-click opens the menu; the row itself
// owns the plain tap (see [_SpaceRow]).

/// One entry in the navigation pane's destination menu.
@immutable
class _DestinationAction {
  const _DestinationAction({
    required this.value,
    required this.icon,
    required this.label,
  });

  final String value;
  final IconData icon;
  final String label;
}
