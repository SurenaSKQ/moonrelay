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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/helpers/space_hierarchy.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_widgets.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/rail_group_header.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/space_context_menu.dart';
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

    // `client.rooms` is read without listening, so subscribing to the client
    // would rebuild the rail on every sync tick, every verification update
    // and every room mutation. The pulse is the one thing worth rebuilding
    // for, because it is the only signal that a space was joined, and the
    // rail is the only place a space appears. The value is discarded on
    // purpose: the rebuild is the side effect.
    context.select<SyncPulse, int>((p) => p.version);

    final spacePrefs = context.watch<SpacePreferences>();
    final items = buildNavItems(
      client.rooms,
      collapsedGroupIds: spacePrefs.collapsedGroups,
      spaceGroups: spacePrefs.spaceGroups,
      order: spacePrefs.spaceOrder,
    );

    final nav = context.watch<NavigationState>();

    return SpacesRail(
      items: items,
      selectedId: nav.isSpace ? nav.selectedId : null,
      isSpaceSelected: nav.isSpace,
      isHomeSelected: nav.isHome,
      isAllSelected: nav.isAll,
      onSelectHome: () {
        nav.selectHome();
        context.go(MoonRoutePaths.roomListTemplate);
      },
      onSelectAll: () {
        nav.selectAll();
        context.go(MoonRoutePaths.roomListTemplate);
      },
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
/// ## Where "Home" and "All Rooms" live
///
/// The mockup puts them at the top of the rail, above a divider, and so does
/// this. They used to be reachable only from a two-way toggle inside the room
/// pane, which is the wrong place for them twice over: they choose *what the
/// room pane lists*, so they belong beside the things that change the room
/// pane rather than inside it, and a toggle cannot show which of the three
/// destinations is current while the list below it is showing a space's
/// rooms. In the rail they are peers of the spaces, which is what they are.
///
/// ## The morph
///
/// The active icon changes from a circle to a rounded square. It is a small
/// thing and it is the whole reason the rail reads as designed rather than
/// as a column of letters: a shape that is both a circle and a square is
/// being told it is the selected one by geometry rather than by a colour
/// swatch, which means the colour is free to be the accent without also
/// being the only signal.
class SpacesRail extends StatefulWidget {
  const SpacesRail({
    super.key,
    required this.items,
    required this.selectedId,
    required this.isSpaceSelected,
    required this.isHomeSelected,
    required this.isAllSelected,
    required this.onSelectHome,
    required this.onSelectAll,
    required this.onSelect,
    required this.onCreateSpace,
  });

  /// Groups and standalone spaces, already grouped, labelled and ordered by
  /// [buildNavItems].
  final List<NavSpaceItem> items;

  /// Room id of the space currently open, or `null` when the user is looking
  /// at rooms or direct chats rather than at a space.
  final String? selectedId;

  /// Whether [selectedId] names a space at all.
  ///
  /// Separate from [selectedId] because the id is null both when nothing is
  /// selected and when the selection is a chat rather than a space, and the
  /// rail needs to tell those apart to decide whether to show an indicator.
  final bool isSpaceSelected;

  /// Whether the room pane is listing direct chats.
  final bool isHomeSelected;

  /// Whether the room pane is listing every room.
  final bool isAllSelected;

  final VoidCallback onSelectHome;
  final VoidCallback onSelectAll;
  final void Function(Room space) onSelect;
  final VoidCallback onCreateSpace;

  @override
  State<SpacesRail> createState() => _SpacesRailState();
}

class _SpacesRailState extends State<SpacesRail> {
  /// The id of the thing a dragged space or group is currently over.
  ///
  /// Local rather than in [SpacePreferences] because it is transient by
  /// nature: it is empty the moment the drag ends, and persisting it would
  /// mean writing to `SharedPreferences` twice per drag.
  String? _hoverId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final layers = ext.layers;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final motion = Motion.of(context);

    // The active client, read once and passed down.
    //
    // The icons used to reach through `space.client` instead. That couples a
    // view to whichever client its room happens to belong to rather than the
    // one the app is logged in as, which is the wrong one to resolve a
    // thumbnail against during an account switch: the avatar 401s and the
    // rail quietly falls back to letters, which is exactly the bug this
    // change is fixing one level down.
    final client = Provider.of<Client>(context, listen: false);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: MoonrelayDesignTokens.navRailWidth,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: t.spaceSm),
              child: Column(
                children: [
                  _RailDestinationIcon(
                    icon: LucideIcons.house,
                    tooltip: l10n.friends,
                    selected: widget.isHomeSelected,
                    onTap: widget.onSelectHome,
                    motion: motion,
                    railActive: layers.railActive,
                  ),
                  _RailDestinationIcon(
                    icon: LucideIcons.messagesSquare,
                    tooltip: l10n.rooms,
                    selected: widget.isAllSelected,
                    onTap: widget.onSelectAll,
                    motion: motion,
                    railActive: layers.railActive,
                  ),
                  // The one rule in the rail. It separates the two built-in
                  // destinations, which exist on every account, from the
                  // user's own spaces, which are the part that varies and the
                  // part that scrolls. Without it the two read as one list
                  // that happens to start with two fixed entries.
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: t.spaceXs),
                    child: Container(
                      width: MoonrelayDesignTokens.spaceIconSize * 0.66,
                      height: t.borderWidthMedium * 2,
                      decoration: BoxDecoration(
                        color: scheme.onSurface
                            .withValues(alpha: t.opacitySubtle),
                        borderRadius: BorderRadius.circular(t.radiusFull),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: t.spaceSm),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return switch (item) {
                    NavSpaceGroup() => _groupBlock(item, client),
                    NavSpaceLeaf() => _leaf(item.space, grouped: false, client: client),
                  };
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
                onTap: widget.onCreateSpace,
                motion: motion,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A group: its header, then its children inside a spine.
  ///
  /// The spine is a border on the block rather than a drawn line, which is
  /// what keeps it the height of its contents without measuring anything. The
  /// block's insets are chosen so the child icons land on exactly the same
  /// pixels as a standalone icon: the rail is 72 wide, the block starts 2 in,
  /// its rule is 2 wide, and its padding is 8, so the children start at 12,
  /// which is where an ungrouped icon starts.
  Widget _groupBlock(NavSpaceGroup group, Client client) {
    final t = Theme.of(context).moonrelay.tokens;
    final hairline = Theme.of(context).moonrelay.layers.hairline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RailGroupHeader(
          groupId: group.id,
          label: group.parentSpaceName ?? AppLocalizations.of(context)!.spaceGroup,
          count: group.children.length,
          expanded: group.isExpanded,
          dropHovered: _hoverId != null && _hoverId == group.id,
          onToggleCollapsed: () =>
              context.read<SpacePreferences>().toggleGroupCollapsed(group.id),
          onHoverChanged: (id) => setState(() => _hoverId = id),
          onDrop: (dragged) => _dropOn(group.id, dragged),
          onContextMenu: () {},
        ),
        if (group.isExpanded)
          Container(
            margin: EdgeInsets.symmetric(horizontal: t.spaceXxs),
            padding: EdgeInsetsDirectional.only(start: t.spaceSm),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: hairline, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in group.children)
                  _leaf(child.space, grouped: true, client: client),
              ],
            ),
          ),
      ],
    );
  }

  /// A standalone space icon, or one nested inside a group block.
  Widget _leaf(Room space, {required bool grouped, required Client client}) {
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;
    final selected = widget.isSpaceSelected && widget.selectedId == space.id;

    Widget icon = _RailSpaceIcon(
      client: client,
      space: space,
      selected: selected,
      onTap: () => widget.onSelect(space),
      tooltip: _tooltipFor(space),
      motion: Motion.of(context),
      railActive: theme.moonrelay.layers.railActive,
      size: MoonrelayDesignTokens.spaceIconSize,
    );

    icon = DraggableIcon(
      data: space.id,
      feedback: DragFeedback(
        theme: theme,
        label: space.getLocalizedDisplayname(),
        uri: space.avatar,
      ),
      ghost: Opacity(opacity: 0.3, child: icon),
      onDragEnd: () => setState(() => _hoverId = null),
      child: icon,
    );

    icon = SpaceDragTarget(
      id: space.id,
      hover: _hoverId == space.id,
      onEnter: (data) {
        if (data == space.id) return false;
        setState(() => _hoverId = space.id);
        return true;
      },
      onLeave: () {
        if (mounted) setState(() => _hoverId = null);
      },
      onDrop: (dragged) => _dropOn(space.id, dragged),
      margin: EdgeInsets.zero,
      child: icon,
    );

    return SpaceContextMenu.forSpace(
      space: space,
      inGroup: grouped,
      onOpen: () {},
      child: Padding(
        // A grouped icon needs no horizontal inset: the block's own padding
        // already put it on the right column. An ungrouped one is centred by
        // hand, because the rail's children are stretch-aligned.
        padding: EdgeInsets.symmetric(
          horizontal: grouped ? 0 : 12,
          vertical: t.spaceXxs,
        ),
        child: icon,
      ),
    );
  }

  /// Resolves a drop, which means one of four different things depending on
  /// what was dropped onto what.
  ///
  /// Grouped onto a group means "join it"; group onto a space means "move
  /// above this space", because there is no box to drop into; two spaces
  /// means "make a group of the two". The old sidebar's three cases are the
  /// same and were correct, the only change being that the rail has to derive
  /// the intent from the payload prefix instead of from which builder it was
  /// in.
  void _dropOn(String targetId, String draggedId) {
    if (targetId == draggedId) return;
    final prefs = context.read<SpacePreferences>();
    setState(() => _hoverId = null);

    final draggedIsGroup = isGroupId(draggedId);
    final targetIsGroup = isGroupId(targetId);

    if (draggedIsGroup && targetIsGroup) {
      _moveGroupAbove(prefs, draggedId, targetId);
    } else if (draggedIsGroup) {
      _moveGroupAbove(prefs, draggedId, targetId);
    } else if (targetIsGroup) {
      prefs.addToGroup(targetId, draggedId);
    } else {
      prefs.createGroup(
        '_grp_${DateTime.now().millisecondsSinceEpoch}',
        [draggedId, targetId],
      );
    }
  }

  /// Moves group [groupId] so it sits immediately before [targetId].
  void _moveGroupAbove(SpacePreferences prefs, String groupId, String targetId) {
    final order = List<String>.of(prefs.spaceOrder);
    final from = order.indexOf(groupId);
    final to = order.indexOf(targetId);
    if (from < 0 || to < 0 || from == to) return;
    order.removeAt(from);
    // Removing the source first shifts every later index down by one, so a
    // forward move needs its destination adjusted or the group lands after
    // the row it was dropped on.
    order.insert(to > from ? to - 1 : to, groupId);
    prefs.updateSpaceOrder(order);
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

/// The behaviour every tile in the rail shares: hover, selection, the morph,
/// and the leading indicator.
///
/// This was inline in [_RailSpaceIcon] and is now here because the rail grew a
/// second kind of tile. Home and All Rooms have to look and feel like the
/// spaces next to them or the column reads as two widgets that happen to be
/// adjacent, and the cheapest way to guarantee that is to make it impossible
/// for them to differ.
///
/// ## Hover is the accent, not a grey wash
///
/// Hovering fills the tile with the accent and turns the glyph white, the same
/// as selection. It used to be the neutral hover step instead, on the theory
/// that a neutral preview is calmer. The result is that hovering told you
/// nothing about whether the thing was reachable: it looked like the same
/// slightly-lighter disc that an unselected tile already was, forty-eight
/// pixels of affordance spent on no information. Filling with the accent also
/// means the selected state is a *continuation* of hover rather than a
/// different kind of state, which is what makes the pair learnable.
class _RailTile extends StatefulWidget {
  const _RailTile({
    required this.selected,
    required this.onTap,
    required this.tooltip,
    required this.motion,
    required this.railActive,
    required this.size,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String tooltip;
  final Motion motion;

  /// The accent this tile's rail is currently using. Passed in rather than
  /// read from the theme extension because the drag feedback and the grouped
  /// variants need to agree with the tile they are overlaying.
  final Color railActive;

  /// Tile edge length. Grouped spaces are smaller than standalone ones, and
  /// the indicator has to scale with the tile rather than sit at a fixed
  /// height, or it looks detached from a 40px icon.
  final double size;

  final Widget child;

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  bool _hovered = false;

  /// Whether the tile is drawn in its accent state.
  ///
  /// Selection wins over hover, matching the mockup: hovering the tile you are
  /// already on should not flicker it to a preview state.
  bool get _lit => widget.selected || _hovered;

  /// At rest a circle; lit, a rounded square.
  ///
  /// A third of the tile for selection and a quarter for hover. The gap is
  /// deliberate: the shape is the signal that says *this is the current
  /// destination*, and a hover that reaches the same radius would be claiming
  /// the same thing.
  BorderRadius get _radius {
    final fraction = widget.selected ? 0.33 : 0.25;
    return BorderRadius.circular(widget.size * fraction);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;
    final scheme = theme.colorScheme;

    // The indicator sits outside the tile's own box, hanging off the rail's
    // leading edge. Putting it inside would need the tile to shrink, and the
    // tile is already the only thing identifying the space.
    //
    // Height carries the same signal as fill and radius, so all three agree:
    // full height for selection, half for hover, none otherwise.
    final indicatorHeight = widget.selected
        ? widget.size * 0.83
        : (_hovered ? widget.size * 0.42 : 0.0);

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
            if (indicatorHeight > 0)
              PositionedDirectional(
                start: -MoonrelayDesignTokens.railIndicatorInset,
                top: (widget.size - indicatorHeight) / 2,
                child: AnimatedContainer(
                  duration: widget.motion.duration(t.durationFast),
                  curve: widget.motion.curve(t.curveDecelerate),
                  width: t.borderWidthThick * 2,
                  height: indicatorHeight,
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
              // Its own node, not merged into a neighbour's.
              //
              // The rail is a stack of icon-only tiles and nothing else, so
              // without this each tile's label merges into the next and a
              // screen reader announces a run of spaces as one button with a
              // pile of names. It also means "selected" can be read per tile,
              // which is the one thing this column exists to communicate.
              container: true,
              child: InkResponse(
                onTap: widget.onTap,
                radius: widget.size * 0.6,
                child: AnimatedContainer(
                  duration: widget.motion.duration(t.durationFast),
                  curve: widget.motion.curve(t.curveDecelerate),
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    // At rest, the room list's step rather than the
                    // conversation's. The tile sits on the rail, which is two
                    // steps darker than the conversation, and using the
                    // conversation's step made an unselected space the
                    // brightest thing in the column, which is the wrong tile
                    // to be drawing the eye.
                    color: _lit ? widget.railActive : scheme.surfaceContainer,
                    borderRadius: _radius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One space in the rail: an avatar inside a [_RailTile].
class _RailSpaceIcon extends StatelessWidget {
  const _RailSpaceIcon({
    required this.client,
    required this.space,
    required this.selected,
    required this.onTap,
    required this.tooltip,
    required this.motion,
    required this.railActive,
    required this.size,
  });

  final Client client;
  final Room space;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;
  final Motion motion;
  final Color railActive;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _RailTile(
      selected: selected,
      onTap: onTap,
      tooltip: tooltip,
      motion: motion,
      railActive: railActive,
      size: size,
      child: _SpaceIconImage(client: client, space: space, size: size),
    );
  }
}

/// One of the two built-in destinations, above the rail's divider.
///
/// Identical to a space tile in every respect but its content, which is the
/// point: they sit in the same column and are selected the same way, so they
/// are the same widget.
class _RailDestinationIcon extends StatelessWidget {
  const _RailDestinationIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.motion,
    required this.railActive,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final Motion motion;
  final Color railActive;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).moonrelay.tokens;
    return _RailTile(
      selected: selected,
      onTap: onTap,
      tooltip: tooltip,
      motion: motion,
      railActive: railActive,
      size: MoonrelayDesignTokens.spaceIconSize,
      child: Center(
        child: Icon(
          icon,
          size: t.iconSizeLarge,
          // The glyph turns white with the fill rather than staying put. On a
          // tile that is already the accent, a `onSurfaceVariant` glyph is the
          // only thing that keeps the icon legible at all, and it is a
          // different grey from the white the space avatars use beside it.
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
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
///
/// The image goes through [AvatarFromUriOrFallbackImage] rather than a bare
/// `Image.network`. It used to be a bare `Image.network`, which sent no
/// `Authorization` header, so every space whose avatar the homeserver does
/// not serve publicly answered 401 and the rail fell back to its letter. The
/// sidebar's space rows had always passed the bearer token, so moving spaces
/// into the rail silently removed the pictures from them: the same spaces,
/// the same avatars, and a column of initials where images used to be. The
/// shared widget also resolves a thumbnail URI, memoizes it per
/// `(client, uri, size)`, and shares one round trip between every icon asking
/// for the same avatar, none of which a bare `Image.network` did.
class _SpaceIconImage extends StatelessWidget {
  const _SpaceIconImage({
    required this.client,
    required this.space,
    required this.size,
  });

  final Client client;
  final Room space;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uri = space.avatar;

    // The letter is passed as the placeholder rather than as an error path,
    // so it is what shows both before the avatar arrives and if it never
    // does. The parent clips this to the morphing radius, so the shared
    // widget's own circle does not fight the shape change.
    return AvatarFromUriOrFallbackImage(
      client: client,
      avatarUri: uri,
      radius: size / 2,
      placeholder: _initials(theme, scheme),
    );
  }

  Widget _initials(ThemeData theme, ColorScheme scheme) {
    final label = space.getLocalizedDisplayname().trim();
    final initial = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: theme.moonrelay.tokens.iconSizeLarge,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The rail's create button: a dashed ring, so it cannot be mistaken for a
/// destination.
///
/// It used to be a filled rounded square in the accent, which is a tile like
/// any other and invited exactly the click it does not honour: it is not a
/// place, it is an action. The dashed outline says "not a destination" without
/// needing a different icon or a label, and the green is the one colour in the
/// rail that is not the selection colour, so it never reads as "you are here".
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

  /// The ring and the glyph. Green is borrowed from the presence palette's
  /// "online" step rather than invented, so it is a colour the app already
  /// means something by.
  static const Color _addColour = Color(0xFF23A559);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;
    final size = MoonrelayDesignTokens.spaceIconSize * 0.6;
    // Inset from the tile edge so the ring is not flush with the glyph, which
    // at this size would touch it.
    const stroke = 2.0;

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
            radius: size * 0.6,
            child: SizedBox(
              width: MoonrelayDesignTokens.spaceIconSize,
              height: MoonrelayDesignTokens.spaceIconSize,
              child: Center(
                child: CustomPaint(
                  painter: _DashedCirclePainter(
                    colour: _addColour,
                    stroke: stroke,
                    radius: (size - stroke) / 2,
                  ),
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Icon(
                      icon,
                      size: t.iconSizeLarge,
                      color: _addColour,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed circle.
///
/// Flutter has no dashed border, and a solid ring would be the tile treatment
/// again. The dashes are drawn by walking the circumference in arc length so
/// they are evenly spaced regardless of the radius, and the seam is hidden by
/// starting at twelve o'clock, where a dash boundary is least visible on a
/// shape this small.
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({
    required this.colour,
    required this.stroke,
    required this.radius,
  });

  final Color colour;
  final double stroke;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final centre = Offset(size.width / 2, size.height / 2);
    // Dash and gap in arc length. Six dashes reads as a dashed line rather
    // than as a dotted one at this size; four reads as a beaded ring.
    const dashes = 6;
    final circumference = 2 * math.pi * radius;
    final step = circumference / dashes;
    final dash = step * 0.55;

    final rect = Rect.fromCircle(center: centre, radius: radius);
    for (var i = 0; i < dashes; i++) {
      final start = -math.pi / 2 + i * step;
      canvas.drawArc(rect, start, dash / radius, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) =>
      old.colour != colour || old.stroke != stroke || old.radius != radius;
}


