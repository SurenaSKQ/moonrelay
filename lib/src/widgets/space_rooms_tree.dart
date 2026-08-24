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
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// Maximum nesting depth before we stop rendering deeper subspaces
/// to avoid performance issues with deeply nested trees.
const int _maxDepth = 10;

/// A hierarchical tree view of rooms within a space, displayed in the
/// left sidebar when a specific space is selected.
///
/// Child rooms are shown as tappable list tiles. Child subspaces are
/// shown as expandable/collapsible groups with visual indentation that
/// increases at each nesting level. Subspaces render their own children
/// recursively via additional [SpaceRoomsTree] instances.
///
/// The expand/collapse state is maintained centrally in the top-level
/// instance so that toggling a subspace does not reset sibling trees.
class SpaceRoomsPane extends StatefulWidget {
  const SpaceRoomsPane({super.key, required this.space, required this.client});

  /// The root space whose children should be displayed.
  final Room space;

  final Client client;

  @override
  State<SpaceRoomsPane> createState() => _SpaceRoomsPaneState();
}

class _SpaceRoomsPaneState extends State<SpaceRoomsPane> {
  /// Room IDs of subspaces that are currently expanded (at any depth).
  final Set<String> _expanded = {};

  /// Last [SyncPulse.version] observed at build time. The build re-
  /// triggers when the pulse advances; we compare against the previous
  /// value so a build caused by another field doesn't double-refresh.
  int _lastPulseVersion = -1;

  /// Pulse we're subscribed to, captured on mount. Used in dispose to
  /// detach the listener cleanly.
  SyncPulse? _pulse;

  @override
  void initState() {
    super.initState();
    // Auto-expand the first level of subspaces on load.
    _autoExpandFirstLevel();
    // Register for sync pulse ticks so we can re-render on the next
    // coalesced sync. We do this in a post-frame callback because
    // SyncPulse may not be available during the first frame (e.g.
    // splash-screen transition, or a widget test that doesn't mount
    // a pulse provider).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pulse = maybeSyncPulse(context);
      if (pulse != null) {
        _pulse = pulse;
        pulse.addListener(_onPulse);
      }
    });
  }

  void _onPulse() {
    if (!mounted) return;
    final pulse = _pulse;
    if (pulse == null) return;
    if (pulse.version == _lastPulseVersion) return;
    _lastPulseVersion = pulse.version;
    setState(() {});
  }

  void _autoExpandFirstLevel() {
    for (final child in widget.space.spaceChildren) {
      final roomId = child.roomId;
      if (roomId == null) continue;
      final room = widget.client.getRoomById(roomId);
      if (room != null && room.isSpace) {
        _expanded.add(roomId);
      }
    }
  }

  @override
  void dispose() {
    _pulse?.removeListener(_onPulse);
    super.dispose();
  }

  void _toggle(String roomId) {
    setState(() {
      if (_expanded.contains(roomId)) {
        _expanded.remove(roomId);
      } else {
        _expanded.add(roomId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // We rebuild via the [SyncPulse] listener registered in [initState],
    // so [build] itself doesn't need to subscribe. The dependency on
    // [widget.space.spaceChildren] and [widget.client] is implicit via
    // the read below; any sync-driven change invalidates the cached
    // child list through the listener.
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final children = widget.space.spaceChildren;

    // Collect renderable items, filtering out null room IDs.
    final items = <_TreeItem>[];
    for (final child in children) {
      final roomId = child.roomId;
      if (roomId == null) continue;
      final childRoom = widget.client.getRoomById(roomId);
      if (childRoom != null) {
        items.add(
            _TreeItem(room: childRoom, isSuggested: child.suggested == true));
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(t.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.folderOpen,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: t.opacityDisabled),
              ),
              SizedBox(height: t.spaceMd),
              Text(
                l10n.spaceNoChildren,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final item in items)
          _buildTreeItem(context, item, 0, scheme, l10n),
      ],
    );
  }

  Widget _buildTreeItem(
    BuildContext context,
    _TreeItem item,
    int depth,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    if (depth > _maxDepth) return const SizedBox.shrink();

    final room = item.room;

    if (room.isSpace) {
      final isExpanded = _expanded.contains(room.id);
      final displayName = room.getLocalizedDisplayname();
      final subspaceChildren = _getChildren(room);

      // Only include non-space children for room count subtitle.
      final roomCount =
          subspaceChildren.where((c) => c != null && !c.isSpace).length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -- Subspace header --------------------------------------
          _SubspaceHeader(
            displayName: displayName,
            depth: depth,
            isExpanded: isExpanded,
            roomCount: roomCount,
            scheme: scheme,
            onTap: () => _toggle(room.id),
            onDoubleTap: () => context.push('/main/space/${room.id}'),
          ),

          // -- Children (if expanded) -------------------------------
          if (isExpanded)
            ...subspaceChildren.whereType<Room>().map(
                  (child) => _buildTreeItem(
                    context,
                    _TreeItem(room: child),
                    depth + 1,
                    scheme,
                    l10n,
                  ),
                ),
        ],
      );
    }

    // -- Regular room tile ------------------------------------------
    return _RoomTile(
      room: room,
      depth: depth,
      isSuggested: item.isSuggested,
      scheme: scheme,
      l10n: l10n,
      client: widget.client,
    );
  }

  /// Returns all child [Room] objects for [space] that the user has joined.
  List<Room?> _getChildren(Room space) {
    return space.spaceChildren.map((c) {
      final roomId = c.roomId;
      if (roomId == null) return null;
      return widget.client.getRoomById(roomId);
    }).toList();
  }
}

// --- Data ---------------------------------------------------------------------

/// An item in the tree: either a regular room or a subspace.
class _TreeItem {
  const _TreeItem({required this.room, this.isSuggested = false});
  final Room room;
  final bool isSuggested;
}

// --- Subspace header ----------------------------------------------------------

/// A tappable header row for a subspace in the tree.
///
/// Shows the subspace name, child count, and an expand/collapse chevron.
/// The background is subtly tinted to visually separate groups, and
/// indentation increases with [depth].
class _SubspaceHeader extends StatelessWidget {
  const _SubspaceHeader({
    required this.displayName,
    required this.depth,
    required this.isExpanded,
    required this.roomCount,
    required this.scheme,
    required this.onTap,
    required this.onDoubleTap,
  });

  final String displayName;
  final int depth;
  final bool isExpanded;
  final int roomCount;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    // Gradually decrease the background tint intensity as depth increases.
    final bgAlpha = (20 - depth * 3).clamp(4, 20);
    final leftBorderColor = HSLColor.fromColor(scheme.primary)
        .withLightness((0.4 + depth * 0.06).clamp(0.4, 0.7))
        .toColor();

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: EdgeInsets.only(
          left: 8.0 + depth * 20.0,
          right: 8,
          top: 10,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: bgAlpha / 255.0),
          border: Border(
            left: BorderSide(color: leftBorderColor, width: 3),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(t.radiusXs),
          child: Row(
            children: [
              Icon(
                isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: t.iconSizeSmall,
                color: scheme.onSurfaceVariant,
              ),
              SizedBox(width: t.spaceXs),
              Icon(
                LucideIcons.folder,
                size: t.iconSizeSmall,
                color: scheme.primary,
              ),
              SizedBox(width: t.spaceSm),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (roomCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color:
                        scheme.outlineVariant.withValues(alpha: t.opacityDisabled),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                  ),
                  child: Text(
                    '$roomCount',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Room tile ----------------------------------------------------------------

/// A compact room list tile used inside the space tree.
///
/// Styled consistently with [RoomsPane] but more compact to fit
/// the hierarchical layout.
class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.depth,
    required this.isSuggested,
    required this.scheme,
    required this.l10n,
    required this.client,
  });

  final Room room;
  final int depth;
  final bool isSuggested;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final Client client;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _joinRoom(context, room),
      child: Padding(
        padding: EdgeInsets.only(
          left: 8.0 + depth * 20.0,
          right: 12,
          top: 6,
          bottom: 6,
        ),
        child: Row(
          children: [
            // -- Avatar with unread dot -----------------------------
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                children: [
                  Positioned.fill(child: _buildAvatar(room, client)),
                  if (room.hasNewMessages)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // -- Name and subtitle ----------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.getLocalizedDisplayname(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (room.lastEvent?.body != null || isSuggested)
                    Text(
                      isSuggested ? l10n.suggested : room.lastEvent!.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 12,
                        color: isSuggested
                            ? scheme.tertiary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Room room, Client client) {
    if (room.avatar == null) {
      return CircleAvatar(
        radius: 16,
        child: Text(
          _extractInitials(room.getLocalizedDisplayname()),
          style: const TextStyle(fontSize: 11),
        ),
      );
    }

    return FutureBuilder<Uri?>(
      future: withTimeoutOrFallback(
        () => room.avatar!.getThumbnailUri(
          client,
          method: ThumbnailMethod.scale,
          height: 44,
          width: 44,
        ),
        timeout: kDefaultTimeout,
        fallback: null,
      ),
      builder: (context, asyncSnapshot) {
        final uri = asyncSnapshot.data;
        if (uri != null) {
          return CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(
              uri.toString(),
              headers: {
                'authorization': 'Bearer ${client.accessToken}',
              },
            ),
            onBackgroundImageError: (_, __) {},
          );
        }
        return CircleAvatar(
          radius: 16,
          child: Text(
            _extractInitials(room.getLocalizedDisplayname()),
            style: const TextStyle(fontSize: 11),
          ),
        );
      },
    );
  }

  /// Extracts up to two initials from [displayName], falling back to '?'
  /// for empty or whitespace-only names.
  static String _extractInitials(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed
        .toUpperCase()
        .split(RegExp(' +'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join();
  }
}

/// Joins the [room] (if not already a member) and navigates to it.
Future<void> _joinRoom(BuildContext context, Room room) async {
  final log = Provider.of<Logger>(context, listen: false);
  try {
    if (room.membership != Membership.join) {
      final result = await withRetry(
        () => room.join(),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'treeJoinRoom',
      );
      if (result is RetryFailed) {
        throw (result).error;
      }
    }
    if (!context.mounted) return;
    context.pushReplacement('/main/rooms/${room.id}');
  } catch (e) {
    log.f(
      'Failed to join',
      error: e,
      stackTrace: StackTrace.current,
      time: DateTime.now(),
    );
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message =
        e is TimeoutException ? l10n.couldNotJoinRoomTimeout : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.error),
            Text(message),
          ],
        ),
      ),
    );
  }
}
