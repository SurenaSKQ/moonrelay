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

const double _paneWidth = 80;
const double _iconSize = 56;
// unused
const double _iconRadius = 18;

class NavigationPane extends StatefulWidget {
  const NavigationPane({super.key});
  @override
  State<NavigationPane> createState() => _NavigationPaneState();
}

class _NavigationPaneState extends State<NavigationPane> {
  Set<String> _knownSpaceIds = {};
  String? _dragHoverId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = Provider.of<Client>(context);
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
        _detectNewSpaces(client.rooms, settings, l10n);

        return Container(
          width: _paneWidth,
          color: theme.colorScheme.surfaceContainerLow,
          child: Column(children: [
            const SizedBox(height: 8),
            _NavIconButton(
                icon: LucideIcons.home,
                label: l10n.navigationHome,
                isSelected: nav.isHome,
                onTap: nav.selectHome,
                theme: theme,
                useTooltip: true),
            _NavIconButton(
                icon: LucideIcons.messageCircle,
                label: l10n.navigationAll,
                isSelected: nav.isAll,
                onTap: nav.selectAll,
                theme: theme,
                useTooltip: true),
            _NavIconButton(
                icon: LucideIcons.plus,
                label: l10n.addRoom,
                isSelected: false,
                onTap: () => context.push('/main/addroom'),
                theme: theme,
                useTooltip: true),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                    height: 2,
                    width: 40,
                    decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(1)))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4),
                children: navItems
                    .map((item) => switch (item) {
                          NavSpaceLeaf(:final space) => _buildDraggableLeaf(
                              context, space, nav, theme, settings, l10n),
                          NavSpaceGroup(
                            :final groupId,
                            :final children,
                            :final isExpanded
                          ) =>
                            _buildGroup(context, groupId, children, isExpanded,
                                nav, theme, settings, l10n),
                        })
                    .toList(),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _detectNewSpaces(Iterable<Room> rooms, SettingsController settings,
      AppLocalizations l10n) {
    final ids = rooms.where((r) => r.isSpace).map((r) => r.id).toSet();
    final newIds = ids.difference(_knownSpaceIds);
    _knownSpaceIds = ids;
    if (newIds.isNotEmpty) {
      final auto = computeAutoGroups(rooms);
      final rel = <String, List<String>>{};
      for (final e in auto.entries) {
        if (newIds.contains(e.key) || e.value.any((c) => newIds.contains(c))) {
          rel[e.key] = e.value;
        }
      }
      if (rel.isNotEmpty) settings.sortIntoGroups(rel);
    }
  }

  // ── Leaf ────────────────────────────────────────────────────────

  Widget _buildDraggableLeaf(BuildContext ctx, Room space, NavigationState nav,
      ThemeData theme, SettingsController settings, AppLocalizations l10n) {
    final sel = nav.isSpace && nav.selectedId == space.id;
    final hovered = _dragHoverId == space.id;
    return _SpaceDragTarget(
      id: space.id,
      isHovered: hovered,
      onWillAccept: (id) {
        setState(() => _dragHoverId = space.id);
        return true;
      },
      onLeave: () {
        if (mounted) setState(() => _dragHoverId = null);
      },
      onAccept: (id) {
        setState(() => _dragHoverId = null);
        settings.createGroup(
            '_grp_${DateTime.now().millisecondsSinceEpoch}', [id, space.id]);
      },
      child: LongPressDraggable<String>(
        data: space.id,
        feedback: _DragFeedback(
            theme: theme,
            label: space.getLocalizedDisplayname(),
            avatarUri: space.avatar),
        childWhenDragging:
            Opacity(opacity: 0.25, child: iconLeaf(sel, space, theme)),
        child: _SpaceContextMenu(
            ctx: ctx,
            space: space,
            settings: settings,
            l10n: l10n,
            nav: nav,
            child: iconLeaf(sel, space, theme)),
      ),
    );
  }

  Widget iconLeaf(bool sel, Room space, ThemeData theme) => _NavIconButton(
        icon: LucideIcons.folder,
        label: space.getLocalizedDisplayname(),
        isSelected: sel,
        size: _iconSize,
        borderRadius: _iconRadius,
        theme: theme,
        avatarUri: space.avatar,
        useTooltip: false,
      );

  // ── Group ────────────────────────────────────────────────────────

  Widget _buildGroup(
      BuildContext ctx,
      String gid,
      List<NavSpaceLeaf> children,
      bool expanded,
      NavigationState nav,
      ThemeData theme,
      SettingsController settings,
      AppLocalizations l10n) {
    final scheme = theme.colorScheme;
    final first = children.isNotEmpty ? children.first.space : null;
    final hovered = _dragHoverId == gid;

    return _SpaceDragTarget(
      id: gid,
      isHovered: hovered,
      onWillAccept: (id) {
        setState(() => _dragHoverId = gid);
        return true;
      },
      onLeave: () {
        if (mounted) setState(() => _dragHoverId = null);
      },
      onAccept: (id) {
        setState(() => _dragHoverId = null);
        settings.addToGroup(gid, id);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(children: [
          // Group container — rounded box with tinted background
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: Column(children: [
              // Group header with expand toggle
              _SpaceContextMenu(
                ctx: ctx,
                settings: settings,
                l10n: l10n,
                nav: nav,
                groupId: gid,
                child: Stack(children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _NavIconButton(
                      icon: LucideIcons.folder,
                      label: first?.getLocalizedDisplayname() ?? 'Group',
                      isSelected: false,
                      size: _iconSize,
                      borderRadius: _iconRadius,
                      theme: theme,
                      avatarUri: first?.avatar,
                      useTooltip: false,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: GestureDetector(
                      onTap: () => settings.toggleGroupCollapsed(gid),
                      child: Container(
                        width: 18,
                        height: 18,
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
              // Children
              if (expanded)
                ...children.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _buildDraggableLeaf(
                          ctx, c.space, nav, theme, settings, l10n),
                    )),
              if (!expanded && children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${children.length}',
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Drag‑and‑drop
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
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => onWillAccept(d.data),
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: isHovered
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.primary, width: 2.5),
                color: scheme.primary.withValues(alpha: 0.12),
              )
            : null,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
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
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: SizedBox(
          width: _iconSize,
          height: _iconSize,
          child: _NavIconButton(
              icon: LucideIcons.folder,
              label: label,
              isSelected: false,
              size: _iconSize,
              borderRadius: _iconRadius - 2,
              theme: theme,
              avatarUri: avatarUri),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Context menu
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          if (space != null) {
            nav.selectSpace(space!.id);
            ctx.push('/main/space/${space!.id}');
          }
        },
        onSecondaryTap: () => _showMenu(context),
        child: child,
      );

  void _showMenu(BuildContext context) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(_paneWidth, 0, _paneWidth + 52, 0),
      items: [
        if (space != null)
          PopupMenuItem(
              value: 'open',
              child: _Row(LucideIcons.externalLink, l10n.openSpace)),
        if (space != null)
          PopupMenuItem(
              value: 'up', child: _Row(LucideIcons.arrowUp, 'Move Up')),
        if (space != null)
          PopupMenuItem(
              value: 'dn', child: _Row(LucideIcons.arrowDown, 'Move Down')),
        const PopupMenuDivider(),
        if (space != null && groupId == null)
          PopupMenuItem(
              value: 'ungroup',
              child: _Row(LucideIcons.ungroup, 'Remove from group')),
        if (groupId != null)
          PopupMenuItem(
              value: 'ungroup_all',
              child: _Row(LucideIcons.ungroup, 'Ungroup all')),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'sort',
            child: _Row(LucideIcons.folders, 'Sort into groups')),
      ],
    ).then((v) {
      if (v == null || !ctx.mounted) return;
      switch (v) {
        case 'open':
          if (space != null) {
            nav.selectSpace(space!.id);
            ctx.push('/main/space/${space!.id}');
          }
        case 'up':
          if (space != null) settings.moveUp(space!.id);
        case 'dn':
          if (space != null) settings.moveDown(space!.id);
        case 'ungroup':
          if (space != null) settings.removeFromGroup(space!.id);
        case 'ungroup_all':
          if (groupId != null) {
            for (final c in List.of(settings.spaceGroups[groupId] ?? []))
              settings.removeFromGroup(c);
          }
        case 'sort':
          final c = Provider.of<Client>(ctx, listen: false);
          settings.sortIntoGroups(computeAutoGroups(c.rooms));
      }
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Icon button – with NO Tooltip for draggable items to avoid LongPress conflict
// ═══════════════════════════════════════════════════════════════════════════

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.theme,
    this.onTap,
    
    this.avatarUri,
    this.size = _iconSize,
    this.borderRadius = _iconRadius,
    this.useTooltip = false,
  });
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final ThemeData theme;
  final Uri? avatarUri;
  final double size, borderRadius;
  final bool useTooltip;

  @override
  Widget build(BuildContext context) {
    final sc = theme.colorScheme;
    final c = isSelected ? sc.primary : sc.onSurfaceVariant;
    final btn = GestureDetector(
      onTap: onTap,
      
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
    );
    if (useTooltip) {
      return Padding(
        padding: EdgeInsets.symmetric(
            vertical: 3, horizontal: (_paneWidth - size) / 2),
        child: Tooltip(message: label, preferBelow: false, child: btn),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: 3, horizontal: (_paneWidth - size) / 2),
      child: btn,
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
          fallback: uri),
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

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)]);
}
