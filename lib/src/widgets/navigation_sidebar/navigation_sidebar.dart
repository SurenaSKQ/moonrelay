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
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/sidebar_profile_pill.dart';
import 'package:moonrelay/src/widgets/space_rooms_tree.dart';
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
  // something.  Recorded in WORK_NEEDED.md.

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

  /// The pane's title bar: what is being listed, and the one thing you can do
  /// that is not a room.
  ///
  /// On the darker rail step with a hairline under it, which is the mockup's
  /// arrangement and the reason it works: the bar is furniture rather than
  /// content, and reading it as furniture is what tells the eye the list below
  /// is the part that scrolls.
  Widget _buildTitleBar(ColorScheme scheme, AppLocalizations l10n) {
    final nav = context.watch<NavigationState>();
    final title = _destinationTitle(nav, l10n);

    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                // The largest text in this pane. It names the thing the whole
                // column is about, so it is set at header weight rather than
                // at row weight.
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: scheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // No palette control here. It is a window-level action, not a
          // destination and not something that filters this pane, so it lives
          // in the title bar where it is reachable from every screen rather
          // than only from the one that happens to have a sidebar. See
          // [WindowTitleBar].
          _addRoomButton(l10n),
        ],
      ),
    );
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
  ///
  /// Sized to a 22px box so the row it sits in keeps the height of the
  /// section headers it now shares a line with.
  Widget _addRoomButton(AppLocalizations l10n) {
    return SizedBox(
      width: 22,
      height: 22,
      child: IconButton(
        icon: const Icon(LucideIcons.plus, size: 14),
        tooltip: l10n.addRoom,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 22, height: 22),
        onPressed: () => context.push('/main/addroom'),
      ),
    );
  }

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

// -----------------------------------------------------------------------------
// Row widgets
// -----------------------------------------------------------------------------


// ===========================================================================
// Drag-and-drop helpers: ported unchanged from the navigation rail
// ===========================================================================

// ===========================================================================
// Context menu: long-press / right-click opens the menu; the row itself
// owns the plain tap (see [_SpaceRow]).
// ===========================================================================






