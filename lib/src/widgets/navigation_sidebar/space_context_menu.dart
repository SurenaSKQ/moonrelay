// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/space_hierarchy.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_rows.dart';
import 'package:provider/provider.dart';

class SpaceContextMenu extends StatefulWidget {
  const SpaceContextMenu({
    super.key,
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
  State<SpaceContextMenu> createState() => SpaceContextMenuState();
}

class SpaceContextMenuState extends State<SpaceContextMenu> {
  Offset _tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) => GestureDetector(
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
              child: NavListRow(LucideIcons.externalLink, widget.l10n.openSpace)),
        if (widget.space != null && !widget.inGroup)
          PopupMenuItem(
              value: 'up', child: NavListRow(LucideIcons.arrowUp, 'Move Up')),
        if (widget.space != null && !widget.inGroup)
          PopupMenuItem(
              value: 'dn', child: NavListRow(LucideIcons.arrowDown, 'Move Down')),
        if (widget.groupId != null)
          PopupMenuItem(
              value: 'gup', child: NavListRow(LucideIcons.arrowUp, 'Move Group Up')),
        if (widget.groupId != null)
          PopupMenuItem(
              value: 'gdn',
              child: NavListRow(LucideIcons.arrowDown, 'Move Group Down')),
        const PopupMenuDivider(),
        if (widget.inGroup)
          PopupMenuItem(
              value: 'ungroup',
              child: NavListRow(LucideIcons.ungroup, 'Remove from group')),
        if (widget.groupId != null)
          PopupMenuItem(
              value: 'ug_all', child: NavListRow(LucideIcons.ungroup, 'Ungroup all')),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'sort',
            child: NavListRow(LucideIcons.folders, 'Sort into groups')),
        PopupMenuItem(
            value: 'reset',
            child: NavListRow(LucideIcons.rotateCcw, 'Reset space layout')),
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
