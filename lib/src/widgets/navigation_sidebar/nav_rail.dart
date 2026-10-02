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
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// Resolves the space list and wires selection and navigation, so
/// [SpacesRail] stays a pure view.
///
/// The rail is mounted as its own row child rather than being built inside
/// the sidebar, because the point of moving spaces out is that the room
/// pane gets the full height of the column. Keeping the two coupled would
/// reintroduce exactly the competition the rail exists to remove.
class SpacesRailHost extends StatelessWidget {
  const SpacesRailHost({super.key});

  @override
  Widget build(BuildContext context) {
    final Client client;
    try {
      client = Provider.of<Client>(context, listen: false);
    } catch (_) {
      // Absent during the logout transition. An empty rail is the honest
      // answer: there are no spaces to show because there is no client.
      return const SizedBox.shrink();
    }

    // Read, do not watch. Subscribing to the client would rebuild the rail
    // on every sync event, every verification update, and every room
    // mutation, all of which the room pane already handles.
    final spacePrefs = context.watch<SpacePreferences>();
    final spaces = buildSpaceOrder(
      client.rooms,
      order: spacePrefs.spaceOrder,
    );

    final nav = context.watch<NavigationState>();

    return SpacesRail(
      spaces: spaces,
      selectedId: nav.isSpace ? nav.selectedId : null,
      isSpaceSelected: nav.isSpace,
      onSelect: (space) {
        // Selecting a space both marks it in the rail and opens its home
        // page. `push` rather than `go` so returning from a space lands back
        // where the user was in the room list, which is the whole reason the
        // room list is still there.
        nav.selectSpace(space.id);
        context.push('/main/space/${space.id}');
      },
      onCreateSpace: () => openCreateRoom(context, asSpace: true),
    );
  }
}

/// Joined spaces in the user's chosen order, ungrouped.
///
/// A rail has no room for group boxes, so grouped spaces flatten into the
/// rail and their ordering is respected via the same [order] list the
/// sidebar used. Group membership itself is untouched: it still governs what
/// `computeAutoGroups` produces and what the context menu's "ungroup all"
/// and "sort into groups" act on. What is lost is the group box as a
/// *visual*, which is recorded in WORK_NEEDED.md.
List<Room> buildSpaceOrder(Iterable<Room> rooms, {required List<String> order}) {
  final spaces = rooms.where((r) => r.isSpace).toList();
  if (order.isEmpty) return spaces;

  final byId = {for (final s in spaces) s.id: s};
  final ordered = <Room>[];
  for (final id in order) {
    final room = byId.remove(id);
    if (room != null) ordered.add(room);
  }
  // Anything the user has not ordered yet keeps its natural order and lands
  // at the end, so a newly joined space appears rather than disappearing.
  ordered.addAll(byId.values);
  return ordered;
}

/// The slim, icon-only column of spaces down the left edge of the shell.
///
/// Spaces used to be a labelled, collapsible list inside the room pane,
/// stacked above the rooms. That put the two most important things in the app
/// in one vertical column competing for the same pixels: a user with twelve
/// spaces had roughly half the pane spent before reaching a single room, and
/// the room list, which is what they open the app to read, was pushed below
/// the fold.
///
/// Moving spaces out fixes that, and it also gives the layout somewhere to
/// put a fourth depth. The rail is the darkest of the three panes and the
/// room list the mid tone, so reading order runs dark to light left to right
/// and the eye lands on the conversation.
///
/// ## What a rail cannot do
///
/// A 72px column has room for an icon and a tooltip. It does not have room
/// for a space's name next to its icon, for the group boxes the sidebar used
/// to draw, or for a drag handle. So:
///
/// - The name comes back on hover, in a tooltip that also carries the room
///   count, which is more than the old row showed anyway.
/// - Group management stays in the space context menu, which already
///   carried "ungroup all", "sort into groups", and "reset layout", and
///   which is reachable from every icon here.
/// - Reordering is by drag, which still works on the icons themselves.
///
/// ## The morph
///
/// The active icon changes from a circle to a rounded square. It is a small
/// thing and it is the whole reason the rail reads as designed rather than
/// as a column of letters: a shape that is both a circle and a square is
/// being told it is the selected one by geometry rather than by a colour
/// swatch, which means the colour is free to be the accent without also
/// being the only signal.
class SpacesRail extends StatelessWidget {
  const SpacesRail({
    super.key,
    required this.spaces,
    required this.selectedId,
    required this.isSpaceSelected,
    required this.onSelect,
    required this.onCreateSpace,
  });

  /// Joined spaces, already in the user's chosen order.
  final List<Room> spaces;

  /// Room id of the space currently open, or `null` when the user is looking
  /// at rooms or direct chats rather than at a space.
  final String? selectedId;

  /// Whether [selectedId] names a space at all.
  ///
  /// Separate from [selectedId] because the id is null both when nothing is
  /// selected and when the selection is a chat rather than a space, and the
  /// rail needs to tell those apart to decide whether to show an indicator.
  final bool isSpaceSelected;

  final void Function(Room space) onSelect;
  final VoidCallback onCreateSpace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final layers = ext.layers;
    final l10n = AppLocalizations.of(context)!;
    final motion = Motion.of(context);

return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: MoonrelayDesignTokens.navRailWidth,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: t.spaceSm),
                itemCount: spaces.length,
                itemBuilder: (context, index) {
                  final space = spaces[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: t.spaceXxs,
                      horizontal: (MoonrelayDesignTokens.navRailWidth -
                              MoonrelayDesignTokens.spaceIconSize) /
                          2,
                    ),
                    child: _RailSpaceIcon(
                      space: space,
                      selected: isSpaceSelected && selectedId == space.id,
                      onTap: () => onSelect(space),
                      tooltip: _tooltipFor(space),
                      motion: motion,
                      railActive: layers.railActive,
                    ),
                  );
                },
              ),
            ),
            Divider(height: t.borderWidthThin, color: layers.hairline),
            // Pushed to the bottom of the rail so it never drifts up as
            // spaces are joined. A create button that moves is a create
            // button nobody finds twice.
            Padding(
              padding: EdgeInsets.symmetric(vertical: t.spaceSm),
              child: _RailActionIcon(
                icon: LucideIcons.plus,
                tooltip: l10n.addSpace,
                onTap: onCreateSpace,
                motion: motion,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The hover label: name, and how much is in it.
  ///
  /// The room count was never on the sidebar row, so this is more
  /// information than the rail replaced rather than less.
  String _tooltipFor(Room space) {
    final name = space.getLocalizedDisplayname();
    final count = space.spaceChildren.length;
    if (count == 0) return name;
    return '$name  ·  $count';
  }
}

/// One space in the rail: an avatar that morphs between a circle and a
/// rounded square, plus the leading indicator for the selected one.
class _RailSpaceIcon extends StatefulWidget {
  const _RailSpaceIcon({
    required this.space,
    required this.selected,
    required this.onTap,
    required this.tooltip,
    required this.motion,
    required this.railActive,
  });

  final Room space;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;
  final Motion motion;
  final Color railActive;

  @override
  State<_RailSpaceIcon> createState() => _RailSpaceIconState();
}

class _RailSpaceIconState extends State<_RailSpaceIcon> {
  bool _hovered = false;

  /// At rest a circle; hovered or selected, a rounded square.
  ///
  /// Sixteen is half of the icon, which makes it a disc, and a touch under
  /// half is what makes the corners read. The transition is the micro-
  /// interaction the shape change is there to justify.
  BorderRadius get _radius {
    final t = MoonrelayThemeExtension.of(context).tokens;
    if (widget.selected) {
      return BorderRadius.circular(MoonrelayDesignTokens.spaceIconSize * 0.33);
    }
    if (_hovered) {
      return BorderRadius.circular(MoonrelayDesignTokens.spaceIconSize * 0.25);
    }
    return BorderRadius.circular(t.radiusFull);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final layers = ext.layers;
    final scheme = theme.colorScheme;

    // The indicator sits outside the icon's own box, hanging off the rail's
    // leading edge. Putting it inside would need the icon to shrink, and the
    // icon is already the only thing identifying the space.
    return Tooltip(
      message: widget.tooltip,
      // The label below is the single source of the accessible name. A
      // Tooltip adds its own semantics node by default, so without this a
      // screen reader announces the name twice: once as the label and once as
      // the hint.
      excludeFromSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.selected)
              PositionedDirectional(
                start: -MoonrelayDesignTokens.railIndicatorInset,
                top: (MoonrelayDesignTokens.spaceIconSize * 0.5) - 12,
                child: Container(
                  width: t.borderWidthThick * 2,
                  height: 24,
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(t.radiusMd),
                      right: Radius.circular(t.radiusMd),
                    ),
                  ),
                ),
              ),
            Semantics(
              button: true,
              selected: widget.selected,
              label: widget.tooltip,
              child: InkResponse(
                onTap: widget.onTap,
                radius: MoonrelayDesignTokens.spaceIconSize * 0.6,
                child: AnimatedContainer(
                  duration: widget.motion.duration(t.durationFast),
                  curve: widget.motion.curve(t.curveDecelerate),
                  width: MoonrelayDesignTokens.spaceIconSize,
                  height: MoonrelayDesignTokens.spaceIconSize,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? widget.railActive
                        : _hovered
                            ? layers.hover
                            : scheme.surfaceContainerHigh,
                    borderRadius: _radius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _SpaceIconImage(space: widget.space, selected: widget.selected),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The space's avatar, or its first letter.
///
/// Clipped by the parent so it inherits the circle-to-square morph for free;
/// without that, the image would stay circular inside a square frame while
/// the empty state changed shape, and the two states would look like
/// different components.
class _SpaceIconImage extends StatelessWidget {
  const _SpaceIconImage({required this.space, required this.selected});

  final Room space;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uri = space.avatar;

    if (uri != null) {
      return Image.network(
        uri.toString(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initials(scheme, selected),
      );
    }
    return _initials(scheme, selected);
  }

  Widget _initials(ColorScheme scheme, bool selected) {
    final label = space.getLocalizedDisplayname().trim();
    final initial = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The rail's create button, which shares the icon's metrics so it lines up
/// with the spaces above it.
class _RailActionIcon extends StatelessWidget {
  const _RailActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.motion,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;
    final layers = theme.moonrelay.layers;
    final scheme = theme.colorScheme;

    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          button: true,
          label: tooltip,
          child: InkResponse(
            onTap: onTap,
            radius: MoonrelayDesignTokens.spaceIconSize * 0.6,
            child: Container(
              width: MoonrelayDesignTokens.spaceIconSize * 0.6,
              height: MoonrelayDesignTokens.spaceIconSize * 0.6,
              decoration: BoxDecoration(
                color: layers.hover,
                borderRadius: BorderRadius.circular(t.radiusMd),
              ),
              child: Icon(icon, size: t.iconSizeLarge, color: scheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}