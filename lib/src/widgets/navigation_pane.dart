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

const double _pw = 80;
const double _is = 56;
const double _ir = 18;

class NavigationPane extends StatefulWidget {
  const NavigationPane({super.key});
  @override
  State<NavigationPane> createState() => _NavigationPaneState();
}

class _NavigationPaneState extends State<NavigationPane> {
  Set<String> _knownIds = {};
  String? _dragHoverId;
  bool _pendingAutoGroup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPendingAutoGroup());
  }

  void _runPendingAutoGroup() {
    if (!_pendingAutoGroup || !mounted) return;
    _pendingAutoGroup = false;
    final s = context.read<SettingsController>();
    final c = context.read<Client>();
    final ids = c.rooms.where((r) => r.isSpace).map((r) => r.id).toSet();
    final newIds = ids.difference(_knownIds);
    _knownIds = ids;
    if (newIds.isEmpty) return;
    final auto = computeAutoGroups(c.rooms);
    final rel = <String, List<String>>{};
    for (final e in auto.entries) {
      if (newIds.contains(e.key) || e.value.any((x) => newIds.contains(x))) {
        rel[e.key] = e.value;
      }
    }
    if (rel.isNotEmpty) s.mergeIntoGroups(rel);
  }

  bool _inGroup(SettingsController s, String id) =>
      s.spaceGroups.values.any((v) => v.contains(id));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = Provider.of<Client>(context);
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();

    // Track new spaces (deferred to avoid setState during build).
    final ids = client.rooms.where((r) => r.isSpace).map((r) => r.id).toSet();
    final newIds = ids.difference(_knownIds);
    if (newIds.isNotEmpty) {
      _pendingAutoGroup = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _runPendingAutoGroup());
    }

    return Consumer<NavigationState>(
      builder: (context, nav, _) {
        final items = buildNavItems(client.rooms,
            collapsedGroupIds: settings.collapsedGroups,
            spaceGroups: settings.spaceGroups,
            order: settings.spaceOrder);

        return Container(
          width: _pw,
          color: theme.colorScheme.surfaceContainerLow,
          child: Column(children: [
            const SizedBox(height: 8),
            _NIB(
                icon: LucideIcons.home,
                label: l10n.navigationHome,
                sel: nav.isHome,
                onTap: nav.selectHome,
                theme: theme,
                tip: true),
            _NIB(
                icon: LucideIcons.messageCircle,
                label: l10n.navigationAll,
                sel: nav.isAll,
                onTap: nav.selectAll,
                theme: theme,
                tip: true),
            _NIB(
                icon: LucideIcons.plus,
                label: l10n.addRoom,
                sel: false,
                onTap: () => context.push('/main/addroom'),
                theme: theme,
                tip: true),
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
                    children: items
                        .map((item) => switch (item) {
                              NavSpaceLeaf(:final space) => _buildLeaf(
                                  context, space, nav, theme, settings, l10n),
                              NavSpaceGroup(
                                :final groupId,
                                :final children,
                                :final isExpanded
                              ) =>
                                _buildGroup(context, groupId, children,
                                    isExpanded, nav, theme, settings, l10n),
                            })
                        .toList())),
          ]),
        );
      },
    );
  }

  Widget _buildLeaf(BuildContext ctx, Room space, NavigationState nav,
      ThemeData theme, SettingsController settings, AppLocalizations l10n) {
    final sel = nav.isSpace && nav.selectedId == space.id;
    final hover = _dragHoverId == space.id;
    final inG = _inGroup(settings, space.id);
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
          final order = List<String>.of(settings.spaceOrder);
          final srcIdx = order.indexOf(id);
          final dstIdx = order.indexOf(space.id);
          if (srcIdx >= 0 && dstIdx >= 0 && srcIdx != dstIdx) {
            order.removeAt(srcIdx);
            final adjustedDst = dstIdx > srcIdx ? dstIdx - 1 : dstIdx;
            order.insert(adjustedDst, id);
            settings.setSpaceOrder(order);
          }
        } else {
          settings.createGroup(
              '_grp_${DateTime.now().millisecondsSinceEpoch}', [id, space.id]);
        }
      },
      child: _DraggableIcon(
        data: space.id,
        feedback: _DFeedback(
            theme: theme,
            label: space.getLocalizedDisplayname(),
            uri: space.avatar),
        ghost: Opacity(opacity: 0.25, child: _leafIcon(sel, space, theme)),
        child: _SCMenu(
            ctx: ctx,
            space: space,
            inGroup: inG,
            settings: settings,
            l10n: l10n,
            nav: nav,
            child: _leafIcon(sel, space, theme)),
      ),
    );
  }

  Widget _leafIcon(bool sel, Room s, ThemeData t) => _NIB(
      icon: LucideIcons.hash,
      label: s.getLocalizedDisplayname(),
      sel: sel,
      size: _is,
      radius: _ir,
      theme: t,
      avatar: s.avatar);

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
          final order = List<String>.of(settings.spaceOrder);
          final srcIdx = order.indexOf(id);
          final dstIdx = order.indexOf(gid);
          if (srcIdx >= 0 && dstIdx >= 0 && srcIdx != dstIdx) {
            order.removeAt(srcIdx);
            final adjustedDst = dstIdx > srcIdx ? dstIdx - 1 : dstIdx;
            order.insert(adjustedDst, id);
            settings.setSpaceOrder(order);
          }
        } else {
          settings.addToGroup(gid, id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            _SCMenu(
              ctx: ctx,
              settings: settings,
              l10n: l10n,
              nav: nav,
              groupId: gid,
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: GestureDetector(
                      onTap: () => settings.toggleGroupCollapsed(gid),
                      child: _groupIcon(theme, expanded, gid,
                          onDragEnd: () {
                        if (mounted) setState(() => _dragHoverId = null);
                      })),
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
                            color: scheme.onSurface)),
                  ),
                ),
              ]),
            ),
            if (expanded)
              ...children.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _buildLeaf(ctx, c.space, nav, theme, settings, l10n),
                  )),
            if (!expanded && children.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${children.length}',
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant))),
          ]),
        ),
      ),
    );
  }

  /// The group icon — draggable when collapsed so users can reorder groups.
  Widget _groupIcon(ThemeData theme, bool expanded, String gid,
      {VoidCallback? onDragEnd}) {
    final icon = _NIB(
        icon: LucideIcons.folder,
        label: 'Group',
        sel: false,
        size: _is,
        radius: _ir,
        theme: theme);
    if (expanded) return icon;
    // Wrap in Draggable when collapsed for reordering via drag.
    return _DraggableIcon(
      data: gid,
      feedback: _DFeedback(
          theme: theme, label: 'Group', uri: null),
      ghost: Opacity(opacity: 0.25, child: icon),
      onDragEnd: onDragEnd,
      child: icon,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Drag‑and‑drop: Draggable (desktop-friendly press-move)
// ═══════════════════════════════════════════════════════════════════════════

class _DraggableIcon extends StatelessWidget {
  const _DraggableIcon(
      {required this.data,
      required this.feedback,
      required this.ghost,
      required this.child,
      this.onDragEnd});
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

class _DFeedback extends StatelessWidget {
  const _DFeedback({required this.theme, required this.label, this.uri});
  final ThemeData theme;
  final String label;
  final Uri? uri;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: SizedBox(
            width: _is,
            height: _is,
            child: _NIB(
                icon: LucideIcons.folder,
                label: label,
                sel: false,
                size: _is,
                radius: _ir - 2,
                theme: theme,
                avatar: uri)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Context menu — tap navigates, long‑press/right‑click opens menu
// ═══════════════════════════════════════════════════════════════════════════

class _SCMenu extends StatefulWidget {
  const _SCMenu({
    required this.ctx,
    required this.settings,
    required this.l10n,
    required this.nav,
    this.space,
    this.inGroup = false,
    this.groupId,
    required this.child,
  });
  final BuildContext ctx;
  final SettingsController settings;
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
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
            _tapPosition.dx, _tapPosition.dy, 1, 1),
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
          if (widget.space != null) widget.settings.moveUp(widget.space!.id);
        case 'dn':
          if (widget.space != null) widget.settings.moveDown(widget.space!.id);
        case 'gup':
          if (widget.groupId != null) widget.settings.moveUp(widget.groupId!);
        case 'gdn':
          if (widget.groupId != null) widget.settings.moveDown(widget.groupId!);
        case 'ungroup':
          if (widget.space != null) widget.settings.removeFromGroup(widget.space!.id);
        case 'ug_all':
          if (widget.groupId != null) {
            for (final c in List.of(widget.settings.spaceGroups[widget.groupId] ?? [])) {
              widget.settings.removeFromGroup(c);
            }
          }
        case 'sort':
          final c = Provider.of<Client>(widget.ctx, listen: false);
          widget.settings.sortIntoGroups(computeAutoGroups(c.rooms));
        case 'reset':
          widget.settings.resetSpaceLayout();
      }
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Nav icon button
// ═══════════════════════════════════════════════════════════════════════════

class _NIB extends StatelessWidget {
  const _NIB({
    required this.icon,
    required this.label,
    required this.sel,
    required this.theme,
    this.onTap,
    this.avatar,
    this.size = _is,
    this.radius = _ir,
    this.tip = false,
  });
  final IconData icon;
  final String label;
  final bool sel;
  final VoidCallback? onTap;
  final ThemeData theme;
  final Uri? avatar;
  final double size, radius;
  final bool tip;

  @override
  Widget build(BuildContext context) {
    final sc = theme.colorScheme;
    final c = sel ? sc.primary : sc.onSurfaceVariant;
    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: sel ? sc.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(sel ? radius : radius - 4),
      ),
      child: avatar != null
          ? _SAvatar(uri: avatar!, s: size * 0.55)
          : Icon(icon, size: size * 0.46, color: c),
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3, horizontal: (_pw - size) / 2),
      child: tip
          ? Tooltip(
              message: label,
              preferBelow: false,
              child: GestureDetector(onTap: onTap, child: btn))
          : GestureDetector(onTap: onTap, child: btn),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Avatar
// ═══════════════════════════════════════════════════════════════════════════

class _SAvatar extends StatelessWidget {
  const _SAvatar({required this.uri, required this.s});
  final Uri uri;
  final double s;
  @override
  Widget build(BuildContext context) {
    final cl = Provider.of<Client>(context);
    return FutureBuilder<Uri>(
      future: withTimeoutOrFallback(
          () => uri.getThumbnailUri(cl,
              method: ThumbnailMethod.scale,
              width: s.round(),
              height: s.round()),
          timeout: kDefaultTimeout,
          fallback: uri),
      builder: (context, snap) => snap.hasData
          ? CircleAvatar(
              radius: s / 2,
              backgroundImage: NetworkImage(snap.data.toString(),
                  headers: {'authorization': 'Bearer ${cl.accessToken}'}),
              onBackgroundImageError: (_, __) {})
          : CircleAvatar(
              radius: s / 2,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(LucideIcons.folder,
                  size: s * 0.6,
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
