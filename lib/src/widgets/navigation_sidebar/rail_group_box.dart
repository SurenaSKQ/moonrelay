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

/// A group of spaces in the icon rail, drawn as a translucent box.
///
/// ## Why a box, and not a header and a spine
///
/// This replaces a two-part arrangement: a labelled header row above the
/// group's icons, and a two-pixel vertical rule beside them. The reasoning
/// behind that arrangement was that a 72px column has no room for a group's
/// label, so identity and membership had to be split across two vertical
/// affordances to share the width.
///
/// The redesign settles it the other way: a group is a *box*, and its children
/// shrink to fit inside it. Forty-eight becomes forty, which is what pays for
/// the four pixels of padding on each side, and the box is then fifty-six wide
/// in a seventy-two column with eight to spare. The label does not come back,
/// because there is still nowhere to print it; the name lives in the hover
/// tooltip, which is where a rail's names have to live anyway.
///
/// So the box replaces the spine honestly, and the header is gone because the
/// two things it did are now done by the box: membership by the enclosure,
/// and collapse by a chevron that appears on hover.
///
/// ## Collapse
///
/// Collapsing a group shows its first space alone with a count badge, not an
/// empty row. An empty row is indistinguishable from a group that failed to
/// load, and the count is the one fact worth keeping visible; a collapsed group
/// that hides its count is indistinguishable from an empty one.
///
/// ## The label
///
/// A group derived from the Matrix hierarchy is keyed `_grp_<parent id>`, so
/// it has a real name and the tooltip shows it. A group the user made by
/// dragging two spaces together has no name, and rather than calling every
/// such group "Group" the caller passes a generic label in.
class RailGroupBox extends StatefulWidget {
  const RailGroupBox({
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
    required this.children,
    required this.collapsedPreview,
  });

/// Edge length of a space icon inside the box.
  ///
  /// Stated here rather than derived from [MoonrelayDesignTokens.spaceIconSize]
  /// because the relationship is a design decision, not a scale: eight pixels
  /// off the icon buys four of padding on each side and a four-pixel gap, and
  /// any larger and the box stops fitting the rail.
  static const double childSize = 40.0;

  /// The box's width: the largest child plus a gutter on each side.
  static double get boxWidth => childSize + 8;

  /// The corner radius, which grows on hover.
  static const double radius = 16;
  static const double hoveredRadius = 24;

  /// The box's fill and corner radius for the current states.
  ///
  /// Taken out of [build] so the visual contract is checkable. Reaching into
  /// the rendered tree for "the container with a translucent fill inside
  /// RailGroupBox" finds several candidates and asserts on whichever it picked
  /// first, which is a test that passes for the wrong reason.
  static ({Color fill, BorderRadius radius}) decorationFor({
    required ThemeData theme,
    required bool hovered,
    required bool dropHovered,
  }) {
    final t = theme.moonrelay.tokens;
    final scheme = theme.colorScheme;
    // A white wash rather than an outline, and brighter on hover.
    //
    // An outline here would have to fit inside fifty-six pixels and would close
    // a shape whose children are already rounded squares, so the box would read
    // as a card inside a card. A wash at five percent says "these belong
    // together" without drawing a second outline, and at ten percent on hover
    // it doubles as the drop-target feedback.
    final fill = dropHovered
        ? scheme.primary.withValues(alpha: t.opacityFocusRing)
        : scheme.onSurface.withValues(
            alpha: hovered ? 0.10 : 0.05,
          );
    return (
      fill: fill,
      radius: BorderRadius.circular(hovered ? hoveredRadius : radius),
    );
  }

  /// The group's id, which is also its drag payload.
  final String groupId;

  /// Name to show, never empty: the caller resolves the parent's name and
  /// falls back to a generic label when there is none.
  final String label;

  /// How many spaces are in the group. Shown whether or not it is collapsed,
  /// because a collapsed group that hides its count is indistinguishable from
  /// an empty one and finding out means expanding it again.
  final int count;

  final bool expanded;

  /// Whether something is currently hovering this box as a drop target.
  final bool dropHovered;

  final VoidCallback onToggleCollapsed;

  /// Called with the group id when a drag enters, and `null` when it leaves.
  final ValueChanged<String?> onHoverChanged;

  /// Something was dropped on the group. Whether that means "join this group"
  /// or "move above this group" depends on the payload, so the rail decides.
  final ValueChanged<String> onDrop;

  /// Right click or long press.
  final VoidCallback onContextMenu;

  /// The group's spaces, rendered only while [expanded].
  final List<Widget> children;

  /// The icon shown in place of [children] while collapsed.
  final Widget collapsedPreview;

  @override
  State<RailGroupBox> createState() => _RailGroupBoxState();
}

class _RailGroupBoxState extends State<RailGroupBox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;
    final l10n = AppLocalizations.of(context)!;
    final look = RailGroupBox.decorationFor(
      theme: theme,
      hovered: _hovered,
      dropHovered: widget.dropHovered,
    );

    // The rail is icon-only, so the tooltip is what recovers the name, and it
    // is the same string a screen reader gets.
    final hint = l10n.spaceGroupCount(widget.count, widget.label);

    final box = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        container: true,
        label: hint,
        expanded: widget.expanded,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
AnimatedContainer(
              duration: t.durationFast,
              curve: t.curveStandard,
              width: RailGroupBox.boxWidth,
              margin: EdgeInsets.symmetric(
                horizontal:
                    (MoonrelayDesignTokens.navRailWidth - RailGroupBox.boxWidth) / 2,
              ),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: look.fill,
                borderRadius: look.radius,
              ),
              child: widget.expanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final child in widget.children) child,
                      ],
                    )
                  : widget.collapsedPreview,
            ),
            // The collapse control, revealed on hover.
            //
            // It cannot be permanent: there is no room beside the box, and a
            // chevron permanently in the corner of every group would be eight
            // more marks in a column that is already all marks. Hover is the
            // only moment the user has told us they are looking at this
            // particular group.
            if (_hovered)
              PositionedDirectional(
                top: -6,
                end: -4,
                child: _CollapseButton(
                  expanded: widget.expanded,
                  onTap: widget.onToggleCollapsed,
                  tooltip: widget.expanded
                      ? l10n.collapseGroup
                      : l10n.expandGroup,
                ),
              ),
          ],
        ),
      ),
    );

    return SpaceDragTarget(
      id: widget.groupId,
      hover: widget.dropHovered,
      // A group cannot be dropped onto itself, which would otherwise look
      // like it worked and leave the order unchanged.
      onEnter: (data) {
        if (data == widget.groupId) return false;
        widget.onHoverChanged(data);
        return true;
      },
      onLeave: () => widget.onHoverChanged(null),
      onDrop: widget.onDrop,
      margin: EdgeInsets.zero,
      child: SpaceContextMenu.forGroup(
        groupId: widget.groupId,
        onOpen: widget.onContextMenu,
        child: DraggableIcon(
          data: widget.groupId,
          feedback: DragFeedback(theme: theme, label: hint),
          ghost: Opacity(
            opacity: 0.3,
            child: SizedBox(
              width: MoonrelayDesignTokens.navRailWidth,
              child: box,
            ),
          ),
          child: box,
        ),
      ),
    );
  }
}

/// The group's collapse control.
class _CollapseButton extends StatelessWidget {
  const _CollapseButton({
    required this.expanded,
    required this.onTap,
    required this.tooltip,
  });

  final bool expanded;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        button: true,
        label: tooltip,
        child: Material(
          color: scheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 20,
              height: 20,
              child: Icon(
                expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
