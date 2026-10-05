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
import 'package:moonrelay/src/widgets/menu_row.dart';
import 'package:provider/provider.dart';

/// Right-click and long-press menu for a space or a space group.
///
/// Reads [SpacePreferences], [Client], and [NavigationState] from the context
/// rather than taking them as fields. The previous version was handed a
/// `BuildContext` *as a field*, alongside the very providers it was going to
/// read from it, which meant a caller had to keep three objects in sync with
/// the tree they were built in, and holding a `BuildContext` past the frame
/// that created it is the thing that produces "looked up a deactivated
/// widget's ancestor" crashes.
///
/// This class used to be dead code. The rail that replaced the sidebar's
/// space list left it with no call site, which meant the whole of space
/// grouping was unreachable in the shipped app while the commit that removed
/// the list described the menu as still working. It is called from both the
/// rail's space icons and its group headers now.
class SpaceContextMenu extends StatefulWidget {
  const SpaceContextMenu._({
    required this.onOpen,
    required this.child,
    this.space,
    this.inGroup = false,
    this.groupId,
  });

  /// Menu for a space icon. [inGroup] is true for an icon drawn inside a
  /// group's block, which is the only thing that makes "remove from group"
  /// apply; a standalone leaf is in no group by construction.
  factory SpaceContextMenu.forSpace({
    required Widget child,
    required Room space,
    required VoidCallback onOpen,
    bool inGroup = false,
  }) =>
      SpaceContextMenu._(
          space: space, inGroup: inGroup, onOpen: onOpen, child: child);

  /// Menu for a group's header.
  factory SpaceContextMenu.forGroup({
    required Widget child,
    required String groupId,
    required VoidCallback onOpen,
  }) =>
      SpaceContextMenu._(groupId: groupId, onOpen: onOpen, child: child);

  final Room? space;
  final bool inGroup;
  final String? groupId;
  final Widget child;

  /// Invoked when the menu opens, so the caller can move the caret to the
  /// widget that was actually touched. Long press carries a position and
  /// right click on some platforms does not, so the caller remembers the last
  /// pointer position it saw.
  final VoidCallback onOpen;

  @override
  State<SpaceContextMenu> createState() => _SpaceContextMenuState();
}

class _SpaceContextMenuState extends State<SpaceContextMenu> {
  /// Where the menu opens, in global coordinates.
  Offset _tapPosition = Offset.zero;

  /// Wraps a set of related entries with a leading divider, but only if
  /// something has already been added.
  ///
  /// Dropping this into the builder is what removed the leading rule on a
  /// group's menu. It cannot produce two rules in a row for the same reason
  /// the message menu's does not.
  static List<PopupMenuEntry<String>> _grouped(
    List<PopupMenuEntry<String>> entries,
  ) {
    if (entries.isEmpty) return entries;
    return [const MoonrelayMenuDivider(), ...entries];
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onLongPressStart: (details) {
          _tapPosition = details.globalPosition;
          widget.onOpen();
          _show(context);
        },
        // Fires on desktop right click. Records the position without opening
        // the menu, because `onSecondaryTap` carries none and the menu would
        // otherwise open at wherever the pointer last was.
        onSecondaryTapDown: (details) => _tapPosition = details.globalPosition,
        onSecondaryTap: () {
          widget.onOpen();
          _show(context);
        },
        child: widget.child,
      );

  Future<void> _show(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = context.read<SpacePreferences>();
    final isGroup = widget.groupId != null;
    final space = widget.space;

    // The menu is positioned against the overlay, which is the whole screen
    // rather than the rail, so a group header near the bottom of a short
    // window would otherwise place its menu off the edge.
    final overlay = Overlay.of(context, rootOverlay: true)
        .context
        .findRenderObject()! as RenderBox;

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(_tapPosition, _tapPosition),
        Offset.zero & overlay.size,
      ),
      // The rail is 72px wide, so this menu is the one place in the app whose
      // labels are known to be long ("Sort spaces into groups") against a
      // popup that clamps itself to 280.
      constraints: moonrelayMenuConstraints(),
      items: [
        if (space != null)
          MoonrelayMenuItem<String>(
            value: 'open',
            icon: LucideIcons.externalLink,
            label: l10n.openSpace,
          ),
        // Built as groups rather than with dividers sprinkled between the
        // `if`s. The group case used to open with an unconditional
        // `PopupMenuDivider`, because `space` is null for a group and the
        // first block is therefore skipped, so a group header's menu began
        // with a rule and nothing above it.
        if (space != null && !widget.inGroup)
          ..._grouped([
            MoonrelayMenuItem<String>(
              value: 'up',
              icon: LucideIcons.arrowUp,
              label: l10n.moveSpaceUp,
            ),
            MoonrelayMenuItem<String>(
              value: 'dn',
              icon: LucideIcons.arrowDown,
              label: l10n.moveSpaceDown,
            ),
          ]),
        if (isGroup)
          ..._grouped([
            MoonrelayMenuItem<String>(
              value: 'gup',
              icon: LucideIcons.arrowUp,
              label: l10n.moveGroupUp,
            ),
            MoonrelayMenuItem<String>(
              value: 'gdn',
              icon: LucideIcons.arrowDown,
              label: l10n.moveGroupDown,
            ),
            MoonrelayMenuItem<String>(
              value: 'ug_all',
              icon: LucideIcons.ungroup,
              label: l10n.ungroupAllSpaces,
            ),
          ]),
        if (widget.inGroup)
          MoonrelayMenuItem<String>(
            value: 'ungroup',
            icon: LucideIcons.ungroup,
            label: l10n.removeFromGroup,
          ),
        ..._grouped([
          MoonrelayMenuItem<String>(
            value: 'sort',
            icon: LucideIcons.folders,
            label: l10n.sortSpacesIntoGroups,
          ),
          MoonrelayMenuItem<String>(
            value: 'reset',
            icon: LucideIcons.rotateCcw,
            label: l10n.resetSpaceLayout,
          ),
        ]),
      ],
    );

    if (selection == null || !context.mounted) return;
    final groupId = widget.groupId;
    final target = space;

    switch (selection) {
      case 'open':
        if (target == null) return;
        context.read<NavigationState>().selectSpace(target.id);
        context.push('/main/space/${target.id}');
      case 'up':
        if (target != null) await prefs.moveUp(target.id);
      case 'dn':
        if (target != null) await prefs.moveDown(target.id);
      case 'gup':
        if (groupId != null) await prefs.moveUp(groupId);
      case 'gdn':
        if (groupId != null) await prefs.moveDown(groupId);
      case 'ungroup':
        if (target != null) await prefs.removeFromGroup(target.id);
      case 'ug_all':
        if (groupId != null) await prefs.ungroupAll(groupId);
      case 'sort':
        await prefs.sortIntoGroups(
          computeAutoGroups(Provider.of<Client>(context, listen: false).rooms),
        );
      case 'reset':
        await prefs.resetSpaceLayout();
    }
  }
}
