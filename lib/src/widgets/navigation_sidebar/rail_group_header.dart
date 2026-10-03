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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_widgets.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/space_context_menu.dart';

/// A group of spaces in the icon rail: a compact header that collapses its
/// children, drags as a unit, and accepts a dropped space.
///
/// ## Why a header at all, in a 72px column
///
/// The old sidebar drew a full-width bordered box around each group's rows.
/// That shape has no 72px equivalent: a box needs room for a label beside its
/// contents, and there is none. So the group's two jobs are split across two
/// vertical affordances instead of sharing one box:
///
/// - **This header** owns the group's identity and its collapsed state. It is
///   the only thing in the rail that is about the group rather than about a
///   space, which is what makes it the place to hang "move up", "ungroup all",
///   and the collapse toggle.
/// - **A spine beside the children** owns membership. The old box said "these
///   icons are in that group" with an outline; a vertical rule says the same
///   thing in two pixels of width instead of two sides plus two corners,
///   which is what lets the icons stay in the same column as ungrouped ones.
///
/// Collapsing is worth more here than it was in the sidebar. Twelve spaces in
/// one column is twelve rows of scrolling; a user with four groups can
/// collapse to four headers, and the count on each header says what is behind
/// it without opening it.
///
/// ## The label
///
/// A group derived from the Matrix hierarchy is keyed `_grp_<parent id>`, so
/// it has a real name and the header shows it. A group the user made by
/// dragging two spaces together has no name, and rather than calling every
/// such group "Group" the caller passes a generic label in.
class RailGroupHeader extends StatelessWidget {
  const RailGroupHeader({
    super.key,
    required this.groupId,
    required this.label,
    required this.count,
    required this.expanded,
    required this.dropHovered,
    required this.onToggleCollapsed,
    required this.onHoverChanged,
    required this.onDrop,
    required this.onContextMenu,
  });

  /// The header's fixed height, so collapsed and expanded groups lay their
  /// headers out on the same grid.
  static const double height = 28.0;

  /// The group's id, which is also its drag payload.
  final String groupId;

  /// Name to show, never empty: the caller resolves the parent's name and
  /// falls back to a generic label when there is none.
  final String label;

  /// How many spaces are in the group. Shown whether or not it is collapsed,
  /// because a collapsed group that hides its count is indistinguishable
  /// from an empty one and finding out means expanding it again.
  final int count;

  final bool expanded;

  /// Whether something is currently hovering this header as a drop target.
  final bool dropHovered;

  final VoidCallback onToggleCollapsed;

  /// Called with the group id when a drag enters, and `null` when it leaves.
  final ValueChanged<String?> onHoverChanged;

  /// Something was dropped on the header. Whether that means "join this group"
  /// or "move above this group" depends on the payload, so the rail decides.
  final ValueChanged<String> onDrop;

  /// Right click or long press.
  final VoidCallback onContextMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final layers = ext.layers;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // The rail is icon-only and this row has no room to print its label, so
    // the tooltip is what recovers it. Same reasoning as the space icons, and
    // the same string is the accessible name.
    final hint = l10n.spaceGroupCount(count, label);

    final row = Tooltip(
      message: hint,
      excludeFromSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          button: true,
          expanded: expanded,
          label: hint,
          child: InkWell(
            onTap: onToggleCollapsed,
            child: Container(
              height: height,
              margin: EdgeInsets.symmetric(horizontal: t.spaceXxs),
              padding: EdgeInsetsDirectional.only(
                start: t.spaceSm,
                end: t.spaceSm,
              ),
              decoration: BoxDecoration(
                // A fill rather than an outline: a border here would have to
                // be drawn inside the same 72px the icons use, and it would
                // sit next to the spine instead of around the header.
                color: dropHovered
                    ? scheme.primary.withValues(alpha: t.opacityFocusRing)
                    : layers.hover,
                borderRadius: BorderRadius.circular(t.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    expanded ? LucideIcons.folderOpen : LucideIcons.folder,
                    size: t.iconSizeSmall,
                    color:
                        dropHovered ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  SizedBox(width: t.spaceXs),
                  // The count is the only text in the rail, so it is set in
                  // the mono family. Lining figures in a proportional face
                  // change width between glyphs and a row of them looks
                  // ragged as the numbers count up.
                  Expanded(
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: ext.monoFontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dropHovered
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Icon(
                    expanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return SpaceDragTarget(
      id: groupId,
      hover: dropHovered,
      // A group cannot be dropped onto itself, which would otherwise look
      // like it worked and leave the order unchanged.
      onEnter: (data) {
        if (data == groupId) return false;
        onHoverChanged(data);
        return true;
      },
      onLeave: () => onHoverChanged(null),
      onDrop: onDrop,
      margin: EdgeInsets.zero,
      child: SpaceContextMenu.forGroup(
        groupId: groupId,
        onOpen: onContextMenu,
        child: DraggableIcon(
          data: groupId,
          feedback: DragFeedback(theme: theme, label: hint),
          ghost: Opacity(
            opacity: 0.3,
            child: SizedBox(
              width: MoonrelayDesignTokens.navRailWidth,
              height: height,
              child: row,
            ),
          ),
          child: row,
        ),
      ),
    );
  }
}
