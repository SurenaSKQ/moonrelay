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
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/space_hierarchy.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

class NavigationPane extends StatefulWidget {
  const NavigationPane({super.key});
  @override
  State<NavigationPane> createState() => _NavigationPaneState();
}

class _NavigationPaneState extends State<NavigationPane> {
  Set<String> _knownSpaceIds = {};
  String? _dragHoverId; // target ID being hovered during group drag

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Client client = Provider.of<Client>(context);
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();

    return Consumer<NavigationState>(
      builder: (context, nav, _) {
        final navItems = buildNavItems(
          client.rooms,
          collapsedGroupIds: settings.collapsedGroups,
          spaceGroups: settings.spaceGroups,
          order: settings.spaceOrder,
        );

        // Detect new spaces and auto-group them.
        _detectNewSpaces(client.rooms, settings, l10n);

        return Container(
          width: 68,
          color: theme.colorScheme.surfaceContainerLow,
          child: Column(children: [
            const SizedBox(height: 8),
            _NavIconButton(
                icon: LucideIcons.home,
                label: l10n.navigationHome,
                isSelected: nav.isHome,
                onTap: nav.selectHome,
                theme: theme),
            _NavIconButton(
                icon: LucideIcons.messageCircle,
                label: l10n.navigationAll,
                isSelected: nav.isAll,
                onTap: nav.selectAll,
                theme: theme),
            _NavIconButton(
                icon: LucideIcons.plus,
                label: l10n.addRoom,
                isSelected: false,
                onTap: () => context.push('/main/addroom'),
                theme: theme),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                    height: 2,
                    width: 32,
                    decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(1)))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4),
                children: navItems.map((item) {
                  return switch (item) {
                    NavSpaceLeaf(:final space) => _buildDraggableLeaf(
                        context, space, nav, theme, settings, l10n),
                    NavSpaceGroup(
                      :final groupId,
                      :final children,
                      :final isExpanded
                    ) =>
                      _buildGroup(context, groupId, children, isExpanded, nav,
                          theme, settings, l10n),
                  };
                }).toList(),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _detectNewSpaces(Iterable<Room> rooms, SettingsController settings,
      AppLocalizations l10n) {
    final allSpaceIds = rooms.where((r) => r.isSpace).map((r) => r.id).toSet();
    final newIds = allSpaceIds.difference(_knownSpaceIds);
    _knownSpaceIds = allSpaceIds;
    if (newIds.isNotEmpty) {
      // Collect all new spaces and their children for auto‑grouping.
      final autoGroups = computeAutoGroups(rooms);
      final relevantNewGroups = <String, List<String>>{};
      for (final e in autoGroups.entries) {
        if (newIds.contains(e.key) || e.value.any((c) => newIds.contains(c))) {
          relevantNewGroups[e.key] = e.value;
        }
      }
      if (relevantNewGroups.isNotEmpty) {
        settings.sortIntoGroups(relevantNewGroups);
      }
    }
  }

  // ── Leaf (standalone space) with drag support ─────────────────────

  Widget _buildDraggableLeaf(BuildContext ctx, Room space, NavigationState nav,
      ThemeData theme, SettingsController settings, AppLocalizations l10n) {
    final sel = nav.isSpace && nav.selectedId == space.id;
    final isHovered = _dragHoverId == space.id;
    return _SpaceDragTarget(
      id: space.id,
      isHovered: isHovered,
      onWillAccept: (id) {
        setState(() => _dragHoverId = space.id);
        return true;
      },
      onLeave: () {
        if (mounted) setState(() => _dragHoverId = null);
      },
      onAccept: (id) {
        setState(() => _dragHoverId = null);
        final gid = '_grp_${DateTime.now().millisecondsSinceEpoch}';
        settings.createGroup(gid, [id, space.id]);
      },
      child: LongPressDraggable<String>(
        data: space.id,
        feedback: _DragFeedback(
            theme: theme,
            label: space.getLocalizedDisplayname(),
            avatarUri: space.avatar),
        childWhenDragging:
            Opacity(opacity: 0.3, child: _leafIcon(sel, space, theme)),
        child: _SpaceContextMenu(
            ctx: ctx,
            space: space,
            settings: settings,
            l10n: l10n,
            nav: nav,
            child: _leafIcon(sel, space, theme)),
      ),
    );
  }

  Widget _leafIcon(bool sel, Room space, ThemeData theme) {
    return _NavIconButton(
      key: ValueKey(space.id),
      icon: LucideIcons.folder,
      label: space.getLocalizedDisplayname(),
      isSelected: sel,
      size: 52,
      borderRadius: 16,
      theme: theme,
      avatarUri: space.avatar,
    );
  }

  // ── Group widget ──────────────────────────────────────────────────

  Widget _buildGroup(
      BuildContext ctx,
      String groupId,
      List<NavSpaceLeaf> children,
      bool expanded,
      NavigationState nav,
      ThemeData theme,
      SettingsController settings,
      AppLocalizations l10n) {
    final scheme = theme.colorScheme;
    final firstChild = children.isNotEmpty ? children.first.space : null;
    final sel = false; // groups don't match nav selection
    final isHovered = _dragHoverId == groupId;

    return _SpaceDragTarget(
      id: groupId,
      isHovered: isHovered,
      onWillAccept: (id) {
        setState(() => _dragHoverId = groupId);
        return true;
      },
      onLeave: () {
        if (mounted) setState(() => _dragHoverId = null);
      },
      onAccept: (id) {
        setState(() => _dragHoverId = null);
        settings.addToGroup(groupId, id);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Column(children: [
          // Group header with expand toggle
          _SpaceContextMenu(
            ctx: ctx,
            settings: settings,
            l10n: l10n,
            nav: nav,
            groupId: groupId,
            child: Stack(children: [
              _NavIconButton(
                key: ValueKey(groupId),
                icon: LucideIcons.folder,
                label: firstChild?.getLocalizedDisplayname() ?? 'Group',
                isSelected: sel,
                size: 52,
                borderRadius: 16,
                theme: theme,
                avatarUri: firstChild?.avatar,
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: GestureDetector(
                  onTap: () => settings.toggleGroupCollapsed(groupId),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3)
                        ]),
                    child: Icon(
                        expanded
                            ? LucideIcons.chevronDown
                            : LucideIcons.chevronRight,
                        size: 12,
                        color: scheme.onSurface),
                  ),
                ),
              ),
            ]),
          ),
          if (expanded)
            ...children.map((c) =>
                _buildDraggableLeaf(ctx, c.space, nav, theme, settings, l10n)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Drag‑and‑drop widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SpaceDragTarget extends StatelessWidget {
  const _SpaceDragTarget({
    required this.id,
    required this.isHovered,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
    required this.child,
  });
  final String id;
  final bool isHovered;
  final bool Function(String) onWillAccept;
  final VoidCallback onLeave;
  final void Function(String) onAccept;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => onWillAccept(d.data),
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: isHovered
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                )
              : null,
          child: child,
        );
      },
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback(
      {required this.theme, required this.label, this.avatarUri});
  final ThemeData theme;
  final String label;
  final Uri? avatarUri;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 52,
        height: 52,
        child: _NavIconButton(
          icon: LucideIcons.folder,
          label: label,
          isSelected: false,
          size: 52,
          borderRadius: 14,
          theme: theme,
          avatarUri: avatarUri,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Right‑click context menu wrapper
// ═══════════════════════════════════════════════════════════════════════════

class _SpaceContextMenu extends StatelessWidget {
  const _SpaceContextMenu({
    required this.ctx,
    required this.settings,
    required this.l10n,
    required this.nav,
    this.space,
    this.groupId,
    required this.child,
  });
  final BuildContext ctx;
  final SettingsController settings;
  final AppLocalizations l10n;
  final NavigationState nav;
  final Room? space;
  final String? groupId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (space != null) {
          nav.selectSpace(space!.id);
          ctx.push('/main/space/${space!.id}');
        }
      },
      onSecondaryTap: () => _showMenu(context),
      child: child,
    );
  }

  void _showMenu(BuildContext context) {
    final items = <PopupMenuEntry<String>>[
      if (space != null)
        PopupMenuItem(
            value: 'open',
            child: _MenuRow(
                icon: LucideIcons.externalLink, label: l10n.openSpace)),
      if (space != null)
        PopupMenuItem(
            value: 'move_up',
            child: _MenuRow(icon: LucideIcons.arrowUp, label: 'Move Up')),
      if (space != null)
        PopupMenuItem(
            value: 'move_down',
            child: _MenuRow(icon: LucideIcons.arrowDown, label: 'Move Down')),
      const PopupMenuDivider(),
      if (space != null && groupId == null)
        PopupMenuItem(
            value: 'ungroup',
            child: _MenuRow(
                icon: LucideIcons.ungroup, label: 'Remove from group')),
      if (groupId != null)
        PopupMenuItem(
            value: 'ungroup_all',
            child: _MenuRow(icon: LucideIcons.ungroup, label: 'Ungroup all')),
      const PopupMenuDivider(),
      PopupMenuItem(
          value: 'sort_groups',
          child:
              _MenuRow(icon: LucideIcons.folders, label: 'Sort into groups')),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(68, 0, 68 + 52, 0),
      items: items,
    ).then((v) {
      if (v == null || !ctx.mounted) return;
      switch (v) {
        case 'open':
          if (space != null) {
            nav.selectSpace(space!.id);
            ctx.push('/main/space/${space!.id}');
          }
        case 'move_up':
          if (space != null) settings.moveUp(space!.id);
        case 'move_down':
          if (space != null) settings.moveDown(space!.id);
        case 'ungroup':
          if (space != null) settings.removeFromGroup(space!.id);
        case 'ungroup_all':
          if (groupId != null) {
            for (final c in List.of(settings.spaceGroups[groupId] ?? []))
              settings.removeFromGroup(c);
          }
        case 'sort_groups':
          final client = Provider.of<Client>(ctx, listen: false);
          settings.sortIntoGroups(computeAutoGroups(client.rooms));
      }
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Icon button
// ═══════════════════════════════════════════════════════════════════════════

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.theme,
    this.onTap,
    this.onSecondaryTap,
    this.avatarUri,
    this.size = 52,
    this.borderRadius = 16,
  });
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap, onSecondaryTap;
  final ThemeData theme;
  final Uri? avatarUri;
  final double size, borderRadius;

  @override
  Widget build(BuildContext context) {
    final sc = theme.colorScheme;
    final c = isSelected ? sc.primary : sc.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2, horizontal: (68 - size) / 2),
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          onSecondaryTap: onSecondaryTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isSelected
                  ? sc.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                  isSelected ? borderRadius : borderRadius - 4),
            ),
            child: Center(
              child: avatarUri != null
                  ? _SpaceAvatar(uri: avatarUri!, size: size * 0.55)
                  : Icon(icon, size: size * 0.46, color: c),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Avatar
// ═══════════════════════════════════════════════════════════════════════════

class _SpaceAvatar extends StatelessWidget {
  const _SpaceAvatar({required this.uri, required this.size});
  final Uri uri;
  final double size;

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context);
    return FutureBuilder<Uri>(
      future: withTimeoutOrFallback(
        () => uri.getThumbnailUri(client,
            method: ThumbnailMethod.scale,
            width: size.round(),
            height: size.round()),
        timeout: kDefaultTimeout,
        fallback: uri,
      ),
      builder: (context, s) => s.hasData
          ? CircleAvatar(
              radius: size / 2,
              backgroundImage: NetworkImage(s.data.toString(),
                  headers: {'authorization': 'Bearer ${client.accessToken}'}),
              onBackgroundImageError: (_, __) {})
          : CircleAvatar(
              radius: size / 2,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(LucideIcons.folder,
                  size: size * 0.6,
                  color: Theme.of(context).colorScheme.onPrimaryContainer)),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)]);
}
