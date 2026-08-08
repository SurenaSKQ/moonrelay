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

import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/space_hierarchy.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/sidebar_actions.dart';
import 'package:moonrelay/src/widgets/sidebar_profile_pill.dart';
import 'package:moonrelay/src/widgets/space_rooms_tree.dart';

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

  /// Space/group id currently hovered by a drag, highlighted as a drop
  /// target.
  String? _dragHoverId;

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

  bool _inGroup(SpacePreferences sp, String id) =>
      sp.spaceGroups.values.any((v) => v.contains(id));

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
    final spacePrefs = context.watch<SpacePreferences>();

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
        final items = buildNavItems(client.rooms,
            collapsedGroupIds: spacePrefs.collapsedGroups,
            spaceGroups: spacePrefs.spaceGroups,
            order: spacePrefs.spaceOrder);

        return Material(
          color: scheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(scheme),
              const Divider(height: 1),
              _buildNavRows(l10n, nav, scheme),
              const Divider(height: 1),
              if (items.isNotEmpty) ...[
                Expanded(
                  child: _buildSpacesList(
                      context, items, nav, theme, spacePrefs, l10n),
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: _buildRoomsSection(context, nav, scheme, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  // -- Header: profile pill + command palette ---------------------------

  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SidebarProfilePill(),
          SizedBox(height: 6),
          SidebarCommandPaletteButton(),
        ],
      ),
    );
  }

  // -- Navigation destination rows ---------------------------------------

  Widget _buildNavRows(
    AppLocalizations l10n,
    NavigationState nav,
    ColorScheme scheme,
  ) {
    return Container(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavRow(
            icon: LucideIcons.home,
            label: l10n.navigationHome,
            selected: nav.isHome,
            onTap: nav.selectHome,
          ),
          _NavRow(
            icon: LucideIcons.messageCircle,
            label: l10n.navigationAll,
            selected: nav.isAll,
            onTap: nav.selectAll,
          ),
          _NavRow(
            icon: LucideIcons.plus,
            label: l10n.addRoom,
            selected: false,
            onTap: () => context.push('/main/addroom'),
          ),
        ],
      ),
    );
  }

  // -- Spaces region ------------------------------------------------------

  Widget _buildSpacesList(
    BuildContext ctx,
    List<NavSpaceItem> items,
    NavigationState nav,
    ThemeData theme,
    SpacePreferences spacePrefs,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: l10n.spaces),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: items
                .map((item) => switch (item) {
                      NavSpaceLeaf(:final space) => _buildLeaf(
                          ctx, space, nav, theme, spacePrefs, l10n),
                      NavSpaceGroup(
                        :final groupId,
                        :final children,
                        :final isExpanded
                      ) =>
                        _buildGroup(ctx, groupId, children, isExpanded, nav,
                            theme, spacePrefs, l10n),
                    })
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaf(BuildContext ctx, Room space, NavigationState nav,
      ThemeData theme, SpacePreferences spacePrefs, AppLocalizations l10n) {
    final sel = nav.isSpace && nav.selectedId == space.id;
    final hover = _dragHoverId == space.id;
    final inG = _inGroup(spacePrefs, space.id);
    return _SDT(
      id: space.id,
      hover: hover,
      onEnter: (_) {
        setState(() => _dragHoverId = space.id);
        return true;
      },
      onLeave: () {
        if (mounted) setState(() => _dragHoverId = null);
      },
      onDrop: (id) {
        setState(() => _dragHoverId = null);
        if (id == space.id) return; // prevent self-grouping
        if (id.startsWith('_grp_')) {
          // Group dropped on leaf = reorder group before this leaf.
          final order = List<String>.of(spacePrefs.spaceOrder);
          final srcIdx = order.indexOf(id);
          final dstIdx = order.indexOf(space.id);
          if (srcIdx >= 0 && dstIdx >= 0 && srcIdx != dstIdx) {
            order.removeAt(srcIdx);
            final adjustedDst = dstIdx > srcIdx ? dstIdx - 1 : dstIdx;
            order.insert(adjustedDst, id);
            spacePrefs.updateSpaceOrder(order);
          }
        } else {
          spacePrefs.createGroup(
              '_grp_${DateTime.now().millisecondsSinceEpoch}', [id, space.id]);
        }
      },
      child: _DraggableIcon(
        data: space.id,
        feedback: _DFeedback(
            theme: theme,
            label: space.getLocalizedDisplayname(),
            uri: space.avatar),
        ghost: Opacity(
            opacity: 0.3,
            child: _SpaceRow(space: space, selected: sel, theme: theme)),
        child: _SCMenu(
          ctx: ctx,
          space: space,
          inGroup: inG,
          spacePrefs: spacePrefs,
          l10n: l10n,
          nav: nav,
          child: _SpaceRow(space: space, selected: sel, theme: theme),
        ),
      ),
    );
  }

  Widget _buildGroup(
    BuildContext ctx,
    String gid,
    List<NavSpaceLeaf> children,
    bool expanded,
    NavigationState nav,
    ThemeData theme,
    SpacePreferences spacePrefs,
    AppLocalizations l10n,
  ) {
    final scheme = theme.colorScheme;
    final hover = _dragHoverId == gid;
    return _SDT(
      id: gid,
      hover: hover,
      onEnter: (_) {
        setState(() => _dragHoverId = gid);
        return true;
      },
      onLeave: () {
        if (mounted) setState(() => _dragHoverId = null);
      },
      onDrop: (id) {
        setState(() => _dragHoverId = null);
        if (id.startsWith('_grp_')) {
          // Group-to-group drop = reorder: move dropped group before this one.
          final order = List<String>.of(spacePrefs.spaceOrder);
          final srcIdx = order.indexOf(id);
          final dstIdx = order.indexOf(gid);
          if (srcIdx >= 0 && dstIdx >= 0 && srcIdx != dstIdx) {
            order.removeAt(srcIdx);
            final adjustedDst = dstIdx > srcIdx ? dstIdx - 1 : dstIdx;
            order.insert(adjustedDst, id);
            spacePrefs.updateSpaceOrder(order);
          }
        } else {
          spacePrefs.addToGroup(gid, id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SCMenu(
                ctx: ctx,
                spacePrefs: spacePrefs,
                l10n: l10n,
                nav: nav,
                groupId: gid,
                child: _GroupRow(
                  gid: gid,
                  expanded: expanded,
                  count: children.length,
                  scheme: scheme,
                  onTap: () => spacePrefs.toggleGroupCollapsed(gid),
                  onDragEnd: () {
                    if (mounted) setState(() => _dragHoverId = null);
                  },
                ),
              ),
              if (expanded)
                ...children.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child:
                          _buildLeaf(ctx, c.space, nav, theme, spacePrefs, l10n),
                    )),
              if (!expanded && children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${children.length}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Rooms region -------------------------------------------------------

  Widget _buildRoomsSection(
    BuildContext context,
    NavigationState nav,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final Client client;
    try {
      client = Provider.of<Client>(context, listen: false);
    } catch (_) {
      return const SizedBox.shrink();
    }

    final String title;
    Widget body;
    if (nav.isSpace) {
      final Room? space = client.getRoomById(nav.selectedId);
      if (space == null) {
        title = l10n.spaces;
        body = const SizedBox.shrink();
      } else {
        title = space.getLocalizedDisplayname();
        body = SpaceRoomsPane(space: space, client: client);
      }
    } else {
      title = nav.isHome ? l10n.friends : l10n.rooms;
      body = RoomsPane(roomFilter: (Room room) {
        if (nav.isHome) return room.isDirectChat;
        return !room.isSpace;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: title),
        Expanded(child: body),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Small uppercase-style section header used above the spaces and rooms
/// regions.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Full-width navigation destination row (Home / All / Add Room).
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A space row in the spaces region: avatar, name, and a selected tint.
class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    required this.space,
    required this.selected,
    required this.theme,
  });

  final Room space;
  final bool selected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return _RowShell(
      selected: selected,
      child: Row(
        children: [
          _SpaceAvatar(space: space, theme: theme),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              space.getLocalizedDisplayname(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Group header row (folder icon, label, count, collapse chevron).  The
/// group is draggable when collapsed so users can reorder it.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.gid,
    required this.expanded,
    required this.count,
    required this.scheme,
    required this.onTap,
    required this.onDragEnd,
  });

  final String gid;
  final bool expanded;
  final int count;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(LucideIcons.folder, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Group',
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ),
            Icon(
              expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
    if (expanded) return row;
    return _DraggableIcon(
      data: gid,
      feedback: _DFeedback(theme: Theme.of(context), label: 'Group', uri: null),
      ghost: Opacity(opacity: 0.3, child: row),
      onDragEnd: onDragEnd,
      child: row,
    );
  }
}

/// Shared row shell: selected tint and rounded highlight.
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color:
              selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: child,
      ),
    );
  }
}

/// Returns the initials from [name], suitable for avatar fallbacks.
String _initials(String name) {
  if (name.isEmpty) return '#';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name[0].toUpperCase();
}

/// 28px space avatar with initials fallback.
class _SpaceAvatar extends StatelessWidget {
  const _SpaceAvatar({required this.space, required this.theme});

  final Room space;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final uri = space.avatar;
    final label = space.getLocalizedDisplayname();
    if (uri == null) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.1),
        child: Text(
          _initials(label),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final client = Provider.of<Client>(context, listen: false);
    return FutureBuilder<Uri>(
      future: withTimeoutOrFallback(
        () => uri.getThumbnailUri(client,
            method: ThumbnailMethod.scale, width: 28, height: 28),
        timeout: kDefaultTimeout,
        fallback: uri,
      ),
      builder: (context, snap) => snap.hasData
          ? CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(snap.data.toString(),
                  headers: {'authorization': 'Bearer ${client.accessToken}'}),
              onBackgroundImageError: (_, __) {},
            )
          : CircleAvatar(
              radius: 14,
              backgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.1),
              child: Text(
                _initials(label),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Drag-and-drop helpers  ported unchanged from the navigation rail
// ═══════════════════════════════════════════════════════════════════════════

class _DraggableIcon extends StatelessWidget {
  const _DraggableIcon({
    required this.data,
    required this.feedback,
    required this.ghost,
    required this.child,
    this.onDragEnd,
  });

  final String data;
  final Widget feedback, ghost, child;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) => Draggable<String>(
        data: data,
        feedback: feedback,
        childWhenDragging: ghost,
        onDragEnd: onDragEnd != null ? (_) => onDragEnd!() : null,
        child: child,
      );
}

class _SDT extends StatelessWidget {
  const _SDT({
    required this.id,
    required this.hover,
    required this.onEnter,
    required this.onLeave,
    required this.onDrop,
    required this.child,
  });

  final String id;
  final bool hover;
  final bool Function(String) onEnter;
  final VoidCallback onLeave;
  final void Function(String) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => onEnter(d.data),
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, _, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: hover
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.primary, width: 2.5),
                color: scheme.primary.withValues(alpha: 0.12),
              )
            : null,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: child,
      ),
    );
  }
}

class _DFeedback extends StatelessWidget {
  const _DFeedback({required this.theme, required this.label, this.uri});

  final ThemeData theme;
  final String label;
  final Uri? uri;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (uri != null)
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(
                      uri.toString(),
                      headers: {
                        'authorization':
                            'Bearer ${Provider.of<Client>(context, listen: false).accessToken}',
                      },
                    ),
                    onBackgroundImageError: (_, __) {},
                  )
                else
                  const Icon(LucideIcons.folder, size: 22),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Context menu  tap navigates, long-press / right-click opens menu
// ═══════════════════════════════════════════════════════════════════════════

class _SCMenu extends StatefulWidget {
  const _SCMenu({
    required this.ctx,
    required this.spacePrefs,
    required this.l10n,
    required this.nav,
    this.space,
    this.inGroup = false,
    this.groupId,
    required this.child,
  });

  final BuildContext ctx;
  final SpacePreferences spacePrefs;
  final AppLocalizations l10n;
  final NavigationState nav;
  final Room? space;
  final bool inGroup;
  final String? groupId;
  final Widget child;

  @override
  State<_SCMenu> createState() => _SCMenuState();
}

class _SCMenuState extends State<_SCMenu> {
  Offset _tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          if (widget.space != null) {
            widget.nav.selectSpace(widget.space!.id);
            widget.ctx.push('/main/space/${widget.space!.id}');
          }
        },
        onLongPressStart: (details) {
          _tapPosition = details.globalPosition;
          _show(context);
        },
        onSecondaryTapDown: (details) {
          _tapPosition = details.globalPosition;
        },
        onSecondaryTap: () => _show(context),
        child: widget.child,
      );

  void _show(BuildContext context) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(_tapPosition.dx, _tapPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (widget.space != null)
          PopupMenuItem(
              value: 'open',
              child: _Row(LucideIcons.externalLink, widget.l10n.openSpace)),
        if (widget.space != null && !widget.inGroup)
          PopupMenuItem(
              value: 'up', child: _Row(LucideIcons.arrowUp, 'Move Up')),
        if (widget.space != null && !widget.inGroup)
          PopupMenuItem(
              value: 'dn', child: _Row(LucideIcons.arrowDown, 'Move Down')),
        if (widget.groupId != null)
          PopupMenuItem(
              value: 'gup', child: _Row(LucideIcons.arrowUp, 'Move Group Up')),
        if (widget.groupId != null)
          PopupMenuItem(
              value: 'gdn',
              child: _Row(LucideIcons.arrowDown, 'Move Group Down')),
        const PopupMenuDivider(),
        if (widget.inGroup)
          PopupMenuItem(
              value: 'ungroup',
              child: _Row(LucideIcons.ungroup, 'Remove from group')),
        if (widget.groupId != null)
          PopupMenuItem(
              value: 'ug_all', child: _Row(LucideIcons.ungroup, 'Ungroup all')),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'sort',
            child: _Row(LucideIcons.folders, 'Sort into groups')),
        PopupMenuItem(
            value: 'reset',
            child: _Row(LucideIcons.rotateCcw, 'Reset space layout')),
      ],
    ).then((v) {
      if (v == null || !widget.ctx.mounted) return;
      switch (v) {
        case 'open':
          if (widget.space != null) {
            widget.nav.selectSpace(widget.space!.id);
            widget.ctx.push('/main/space/${widget.space!.id}');
          }
        case 'up':
          if (widget.space != null) widget.spacePrefs.moveUp(widget.space!.id);
        case 'dn':
          if (widget.space != null) {
            widget.spacePrefs.moveDown(widget.space!.id);
          }
        case 'gup':
          if (widget.groupId != null) widget.spacePrefs.moveUp(widget.groupId!);
        case 'gdn':
          if (widget.groupId != null) {
            widget.spacePrefs.moveDown(widget.groupId!);
          }
        case 'ungroup':
          if (widget.space != null) {
            widget.spacePrefs.removeFromGroup(widget.space!.id);
          }
        case 'ug_all':
          if (widget.groupId != null) {
            for (final c in List.of(
                widget.spacePrefs.spaceGroups[widget.groupId] ?? [])) {
              widget.spacePrefs.removeFromGroup(c);
            }
          }
        case 'sort':
          final c = Provider.of<Client>(widget.ctx, listen: false);
          widget.spacePrefs.sortIntoGroups(computeAutoGroups(c.rooms));
        case 'reset':
          widget.spacePrefs.resetSpaceLayout();
      }
    });
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)]);
}
