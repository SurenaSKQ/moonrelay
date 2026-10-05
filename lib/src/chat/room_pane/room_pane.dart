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

// The room's side pane: one widget, one room, one owner.
//
// This replaces two things. `RightPaneHost` and `RightSidebarContent`, which
// lived under the dashboard and found out which room they were describing by
// watching a global `CurrentRoom`; and `InRoomSearchPanel`, which lived under
// the room page as a second right-hand column beside the first.
//
// Both were a 320-pixel column beside the same timeline, both had a header, and
// neither knew about the other. A room with a search open had two of them.
//
// The widget is now a pure function of its arguments. `room` is required and
// non-null, [tab] says what to show, and nothing inside reads a provider to
// discover which room it is in. That is the whole point: the pane's state is
// [RoomPage]'s state, so it can be read in one place, and a pane that renders
// the wrong room is a type error rather than a race.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';
import 'package:moonrelay/src/chat/room_pane/tabs/members_tab.dart';
import 'package:moonrelay/src/chat/room_pane/tabs/pinned_tab.dart';
import 'package:moonrelay/src/chat/room_pane/tabs/room_info_tab.dart';
import 'package:moonrelay/src/chat/room_pane/tabs/search_tab.dart';
import 'package:moonrelay/src/chat/room_pane/tabs/threads_tab.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// The room's side pane.
///
/// Every tab receives [room] and the room's [pinnedEventIds] directly rather
/// than going through `CurrentRoom`, which is what lets this widget be mounted
/// in a test with a mock room and no providers at all.
class RoomPane extends StatelessWidget {
  const RoomPane({
    super.key,
    required this.room,
    required this.tab,
    required this.pinnedEventIds,
    required this.pinnedFilterActive,
    required this.onSelectTab,
    required this.onClose,
    this.onJumpToEvent,
    this.onTogglePinnedFilter,
  });

  /// The room this pane describes. Non-null by construction.
  final Room room;

  /// What to show. [RoomPaneTab.none] renders nothing useful, so callers close
  /// the pane rather than selecting it.
  final RoomPaneTab tab;

  /// The room's pinned event ids, resolved by the owner.
  ///
  /// Passed in rather than read from `CurrentRoom` so that the pinned filter and
  /// the list that toggles it cannot disagree about which room's pins they are
  /// talking about. They used to: the timeline filtered on
  /// `CurrentRoom.pinnedEventIds` and the pane toggled `CurrentRoom`'s flag, both
  /// derived from whichever room that global happened to hold.
  final List<String> pinnedEventIds;

  /// Whether the timeline is filtered to pinned messages.
  final bool pinnedFilterActive;

  final void Function(RoomPaneTab tab) onSelectTab;

  /// Closes the pane entirely.
  final VoidCallback onClose;

  /// Jump the timeline to an event, for the search tab.
  final void Function(String eventId)? onJumpToEvent;

  /// Toggles the timeline's pinned-only filter.
  final VoidCallback? onTogglePinnedFilter;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).moonrelay;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      // One step below the conversation, per the surface ramp: the rail is
      // darkest, the room list mid, the conversation light, and the detail pane
      // below the conversation rather than beside it in the same plane.
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: BorderDirectional(
          start: BorderSide(color: ext.layers.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PaneHeader(
            tab: tab,
            roomName: room.getLocalizedDisplayname(),
            onSelectTab: onSelectTab,
            onClose: onClose,
          ),
          Divider(height: 1, color: ext.layers.hairline),
          Expanded(
            child: switch (tab) {
              RoomPaneTab.none => const SizedBox.shrink(),
              RoomPaneTab.info => RoomInfoTab(
                  room: room,
                  pinnedEventIds: pinnedEventIds,
                  pinnedFilterActive: pinnedFilterActive,
                  onTogglePinnedFilter: onTogglePinnedFilter,
                  onOpenPinnedTab: () => onSelectTab(RoomPaneTab.pinned),
                ),
              RoomPaneTab.members => MembersTab(room: room),
              // Room-keyed, because every one of these holds a fetcher or a
              // cache that was built from the room it mounted with. `ThreadsTab`
              // in particular has no `didUpdateWidget`, so without this key a
              // room switch would leave it showing the previous room's threads.
              RoomPaneTab.threads =>
                ThreadsTab(key: ValueKey(room.id), room: room),
              RoomPaneTab.pinned => PinnedTab(
                  key: ValueKey(room.id),
                  room: room,
                  pinnedEventIds: pinnedEventIds,
                  pinnedFilterActive: pinnedFilterActive,
                  onTogglePinnedFilter: onTogglePinnedFilter ?? () {},
                ),
              RoomPaneTab.search => SearchTab(
                  key: ValueKey(room.id),
                  room: room,
                  onJumpToEvent: onJumpToEvent,
                ),
            },
          ),
          // A footer rather than a second strip inside each tab: the pane's
          // height budget is the same for every tab, and a footer that only
          // exists for one of them moves that tab's list by the footer's height.
          if (tab == RoomPaneTab.search)
            _SearchHint(label: l10n.roomPaneSearchHint),
        ],
      ),
    );
  }
}

/// The tab strip.
///
/// A segmented control rather than a dropdown, for the same reason the command
/// palette's is: four destinations that are peers, all reachable in one tap.
/// A dropdown would hide three of them behind a chevron, in a pane that is
/// already 280 pixels wide and has room for four icons.
class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.tab,
    required this.roomName,
    required this.onSelectTab,
    required this.onClose,
  });

  final RoomPaneTab tab;
  final String roomName;
  final void Function(RoomPaneTab) onSelectTab;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      height: t.paneBarHeight,
      padding: EdgeInsetsDirectional.only(start: t.spaceSm, end: t.spaceXs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                for (final RoomPaneTab candidate in RoomPaneTab.selectable) ...[
                  Expanded(
                    child: _PaneTab(
                      icon: _iconFor(candidate),
                      label: _labelFor(candidate, l10n),
                      selected: candidate == tab,
                      onTap: () => onSelectTab(candidate),
                    ),
                  ),
                  if (candidate != RoomPaneTab.selectable.last)
                    SizedBox(width: t.borderWidthThin * 2),
                ],
              ],
            ),
          ),
          _CloseButton(onTap: onClose, tooltip: l10n.close),
        ],
      ),
    );
  }

  static IconData _iconFor(RoomPaneTab tab) => switch (tab) {
        RoomPaneTab.info => LucideIcons.info,
        RoomPaneTab.members => LucideIcons.users,
        RoomPaneTab.threads => LucideIcons.messagesSquare,
        RoomPaneTab.pinned => LucideIcons.pin,
        RoomPaneTab.search => LucideIcons.search,
        RoomPaneTab.none => LucideIcons.circle,
      };

  static String _labelFor(RoomPaneTab tab, AppLocalizations l10n) =>
      switch (tab) {
        RoomPaneTab.info => l10n.roomPaneInfo,
        RoomPaneTab.members => l10n.roomPaneMembers,
        RoomPaneTab.threads => l10n.roomPaneThreads,
        RoomPaneTab.pinned => l10n.roomPanePinned,
        RoomPaneTab.search => l10n.roomPaneSearch,
        RoomPaneTab.none => '',
      };
}

class _PaneTab extends StatelessWidget {
  const _PaneTab({
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
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          // Selection is carried by a fill one step above the pane rather than
          // by colour alone, so the strip still reads in a theme where the
          // accent is close to the surface.
          color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(t.radiusSm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Icon(
                icon,
                size: t.iconSizeMedium,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: const Icon(LucideIcons.x, size: 16),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      color: scheme.onSurfaceVariant,
      // 32 rather than 48: the strip is 52 tall, so a 48 target plus padding
      // overflows it. The strip itself is the target's parent and the tab
      // strip's targets are full-height, so the close button is the one
      // control here that does not need the full minimum.
      constraints: BoxConstraints.tightFor(
        width: 32,
        height: t.paneBarHeight - t.spaceSm,
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: ext.layers.hover,
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceMd,
        vertical: t.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            LucideIcons.arrowDownUp,
            size: t.iconSizeSmall,
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(width: t.spaceSm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
