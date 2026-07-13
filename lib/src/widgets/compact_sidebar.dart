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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// Filter buckets available in the unified compact sidebar.
enum _CompactSidebarFilter {
  /// Direct-message rooms (Matrix `is_direct_chat`).
  friends,

  /// Every room the user is a member of, regardless of type.
  all,

  /// Spaces only.
  spaces,
}

/// A unified, narrow sidebar that combines navigation, rooms, and
/// spaces in a single column.
///
/// This is the sidebar used when the dashboard has been shrunk to a
/// compact size either because the user picked [LayoutMode.compact]
/// or because [DashboardLayout] decided the window is too narrow for
/// the full multi-pane layout.  Unlike the wide layout, which shows a
/// separate far-left rail, a wide left pane, and an optional right
/// pane, the compact sidebar gives up the rail entirely and folds
/// navigation into a small icon row at the top of the same column.
class CompactSidebar extends StatefulWidget {
  /// The fixed width the sidebar should request.  Defaults to
  /// [LayoutBreakpoints.defaultLeftSidebarWidth] but is clamped at
  /// construction time so callers can override it.
  final double? width;

  const CompactSidebar({super.key, this.width});

  @override
  State<CompactSidebar> createState() => _CompactSidebarState();
}

class _CompactSidebarState extends State<CompactSidebar> {
  _CompactSidebarFilter _filter = _CompactSidebarFilter.all;
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _syncSub = _clientOrNull(context)?.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-attach the sync listener if the client changed (e.g. login
    // switch).  Listening twice would cause duplicate rebuilds.
    final client = _clientOrNull(context);
    if (client == null) return;
    _syncSub?.cancel();
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Client? _clientOrNull(BuildContext context) {
    try {
      return Provider.of<Client>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _setFilter(_CompactSidebarFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final client = _clientOrNull(context);
    final l10n = AppLocalizations.of(context)!;

    final width = widget.width ?? 320.0;

    final rooms =
        client == null ? const <Room>[] : _filteredRooms(client.rooms, _filter);

    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNavigationRow(scheme, l10n),
            Divider(height: 1, color: scheme.outlineVariant),
            _buildFilterRow(scheme, l10n),
            const Divider(height: 1),
            Expanded(child: _buildList(rooms, scheme, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRow(
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    // The icon row at the top of the compact sidebar exposes only
    // actions that don't already live in the segmented filter below
    // it.  The "Home" / "All" navigation destinations are reachable
    // through the Friends / Rooms filter pills, so we deliberately
    // don't duplicate them as a top-row icon.
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          _NavIconButton(
            icon: LucideIcons.plus,
            tooltip: l10n.addRoom,
            selected: false,
            onTap: () => context.push('/main/addroom'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(ColorScheme scheme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SegmentedButton<_CompactSidebarFilter>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 12),
          visualDensity: VisualDensity.compact,
        ),
        segments: [
          ButtonSegment(
            value: _CompactSidebarFilter.friends,
            label: Text(l10n.friends),
            icon: const Icon(LucideIcons.user, size: 14),
          ),
          ButtonSegment(
            value: _CompactSidebarFilter.all,
            label: Text(l10n.rooms),
            icon: const Icon(LucideIcons.messageSquare, size: 14),
          ),
          ButtonSegment(
            value: _CompactSidebarFilter.spaces,
            label: Text(l10n.spaces),
            icon: const Icon(LucideIcons.layoutGrid, size: 14),
          ),
        ],
        selected: {_filter},
        onSelectionChanged: (set) {
          if (set.isNotEmpty) _setFilter(set.first);
        },
      ),
    );
  }

  Widget _buildList(
    List<Room> rooms,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    if (rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.noRoomsYet,
            style: TextStyle(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _CompactRoomTile(room: room, scheme: scheme);
      },
    );
  }

  static List<Room> _filteredRooms(
      List<Room> rooms, _CompactSidebarFilter filter) {
    switch (filter) {
      case _CompactSidebarFilter.friends:
        return rooms.where((r) => r.isDirectChat).toList(growable: false);
      case _CompactSidebarFilter.all:
        return rooms.where((r) => !r.isSpace).toList(growable: false);
      case _CompactSidebarFilter.spaces:
        return rooms.where((r) => r.isSpace).toList(growable: false);
    }
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor:
            selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
      ),
    );
  }
}

class _CompactRoomTile extends StatelessWidget {
  const _CompactRoomTile({required this.room, required this.scheme});

  final Room room;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final displayName = room.getLocalizedDisplayname();
    final subtitle = room.lastEvent?.body;
    final unread = room.notificationCount;

    return InkWell(
      onTap: () => context.push('/main/rooms/${room.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: AvatarFromUriOrFallbackImage(
                client: room.client,
                avatarUri: room.avatar,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread.toString(),
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}