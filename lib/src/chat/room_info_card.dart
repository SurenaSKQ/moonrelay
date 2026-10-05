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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/room_pane_sheet.dart';
import 'package:moonrelay/src/widgets/sync_indicator.dart';
import 'package:provider/provider.dart';

/// A Material 3 room header bar that reactively displays the room's name,
/// topic, avatar, and member count.
///
/// Listens to room state changes so that the topic and name stay in sync
/// without requiring a manual rebuild. When the topic is missing or fails to
/// load a friendly placeholder is shown instead.
///
/// Tap behaviour depends on the right-sidebar configuration:
/// - If the right sidebar is enabled and set to "Room Info"**, tapping
///   opens the sidebar (or does nothing if already open).
/// - Otherwise, tapping navigates to the full [RoomInformations] page.
class ChatRoomHeader extends StatefulWidget {
  const ChatRoomHeader({
    super.key,
    required this.room,
    this.onSearchToggle,
    this.isSearchActive = false,
  });

  final Room room;

  /// Called when the user taps the search button.
  final VoidCallback? onSearchToggle;

  /// Whether the in-room search panel is currently visible.
  final bool isSearchActive;

  @override
  State<ChatRoomHeader> createState() => _ChatRoomHeaderState();
}

class _ChatRoomHeaderState extends State<ChatRoomHeader> {
  late String _displayName;
  late String _topic;
  late int _memberCount;

  @override
  void initState() {
    super.initState();
    _syncRoomState();
  }

  @override
  void didUpdateWidget(ChatRoomHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _syncRoomState();
    }
  }

  /// Copies the current room values into local state so the build is fast
  /// and we can override them gracefully if needed.
  void _syncRoomState() {
    _displayName = widget.room.getLocalizedDisplayname();
    _topic = widget.room.topic;
    _memberCount = (widget.room.summary.mInvitedMemberCount ?? 0) +
        (widget.room.summary.mJoinedMemberCount ?? 0);
  }

/// React to a tap on the room header.
///
/// On the dashboard the right sidebar is the room's detail surface, so if
/// it is visible and already on room info there is nothing to open. In the
/// single-pane shell there is no right sidebar at all, so the same four
/// panes are presented as a sheet instead of falling through to the
/// full-page room details, which is the desktop page reused on a phone.
void _onTap() {
  final settings = context.read<SettingsController>();
  final shell = context.read<LayoutShellController>();

  if (shell.isMobile) {
    showRoomPaneSheet(context, room: widget.room);
    return;
  }

  if (settings.rightSidebarVisible &&
      settings.rightPaneChoice == RightPaneChoice.roomInfo) {
    // Sidebar is already open and on room_info: no-op.
    // Otherwise (sidebar hidden, or on different pane): open it.
    return;
  }

  // Fall back to full-page navigation.
  _openRoomInfo();
}

  /// Navigate to the room info page via go_router.
  void _openRoomInfo() {
    openRoomSubpage(context, widget.room.id, 'profile/roomDetails');
  }

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = ext.tokens;
    final layers = ext.layers;

    return StreamBuilder<Object>(
      stream: widget.room.client.onRoomState.stream
          .where((event) => event.roomId == widget.room.id),
      builder: (context, snapshot) {
        // Re-read room state whenever the stream fires.
        _syncRoomState();

        final displayName =
            _displayName.isNotEmpty ? _displayName : widget.room.id;
        final topic = _topic.isNotEmpty
            ? _topic
            : AppLocalizations.of(context)!.noTopicSet;

        // Adapt the header to the *pane's* width, not the window's. The
        // chat column is a sibling of the sidebars, so at a 1100px window
        // it can be under 500px wide; measuring the window packed three
        // controls into a 470px column and squeezed the room name out.
        //
        // Each control is gated by what it costs rather than by one shared
        // band, because they are not the same kind of thing:
        //  - the sync indicator and the pinned toggle each render nothing at
        //    all when they have nothing to report, so hiding them by width
        //    only removes a capability from the user who can least afford to
        //    lose it, and costs no space when they are quiet
        //  - the member badge and the topic line are always-present
        //    furniture, so they are what gives way when the pane is narrow
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final tight = width < 400;
            final showTopic = width >= 480;
            final showMemberCount = width >= 440;
            // Read, not watched: the shell commits in
            // `_AdaptiveMainLayout`'s build, which is an ancestor and has
            // already run, so the value is fresh without a subscription.
            final isSinglePane = context.read<LayoutShellController>().isMobile;
            final avatarRadius = tight ? 14.0 : 16.0;
            final nameFontSize = tight ? 14.0 : 15.0;
            final hPadding = tight ? t.spaceSm : t.spaceMd;
            final iconSize = tight ? 16.0 : 18.0;
            final density = tight
                ? const VisualDensity(horizontal: -2, vertical: -2)
                : VisualDensity.compact;

            // The room header is the primary way out of the message pane in the
            // single-pane shell, and it looked exactly like the surrounding
            // fill. InkWell gives it the ink, hover and keyboard focus that a
            // bare GestureDetector omitted; the fill moves to a Material so
            // the splash has something to paint into.
            //
            // Glassy: the fill sits between the main pane and the rail steps
            // rather than on either of them, so the header reads as a sheet
            // lying over the conversation rather than as the top edge of it.
            //
            // There is no `BackdropFilter` any more. It was there to sell the
            // translucency, and it cost a per-frame readback of the whole pane
            // underneath on a bar that repaints on every sync: the jank showed
            // up as scroll stutter in the timeline rather than as a slow
            // header, which is a bad place to pay for decoration. A flat fill at
            // the conversation's own step does the same job, because there is
            // nothing behind the header to blur except more header.
            return Container(
              color: scheme.surfaceContainerHigh,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _onTap,
                  child: Container(
                    // A fixed height rather than one derived from the avatar, so the
                    // bar is the same height whether or not a topic is
                    // showing. A header that grows when a room has a topic
                    // moves the top of the conversation, which is the one
                    // place in a chat client where content must not shift.
                    //
                    // It reads paneBarHeight so it matches the bar at the
                    // bottom of the same pane. It was a bare 48, and the
                    // composer was a bare 52, which is the whole reason the
                    // conversation had no frame.
                    //
                    // 	ight narrows the horizontal padding and drops the
                    // topic, so the bar needs no extra height for it.
                    height: tight ? t.paneBarHeight - 4 : t.paneBarHeight,
                    padding: EdgeInsets.symmetric(horizontal: hPadding),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: layers.hairline),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Room avatar
                        AvatarFromUriOrFallbackImage(
                          client: widget.room.client,
                          avatarUri: widget.room.avatar,
                          radius: avatarRadius,
                        ),
                        SizedBox(width: hPadding),

                        // Name, then the topic on the same line.
                        //
                        // The topic used to sit under the name, which made the
                        // bar two lines tall and put the room's subject directly
                        // above the first message instead of beside the name it
                        // belongs to. One line with a rule between them is what
                        // lets the bar stay 48 pixels, and it lets the topic
                        // take all the width the actions do not need.
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showTopic) ...[
                          SizedBox(width: t.spaceSm),
                          // The one vertical rule in the chat. It is a
                          // `Divider` rather than a `Container` because it is
                          // the only rule here and giving it the token's own
                          // hairline keeps it from becoming a second one.
                          SizedBox(
                            height: nameFontSize + 4,
                            child: VerticalDivider(
                              width: t.borderWidthMedium,
                              thickness: t.borderWidthThin,
                              color: layers.hairline,
                            ),
                          ),
                          SizedBox(width: t.spaceSm),
                          Flexible(
                            child: Text(
                              topic,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        SizedBox(width: tight ? t.spaceXs : t.spaceSm),

                        // Sync status. Silent unless something is actually
                        // wrong or unusually slow; see SyncIndicator for why a
                        // long-poll in flight is not worth reporting. It
                        // collapses to nothing when quiet, so it is never
                        // gated on width.
                        SyncIndicator(client: widget.room.client),

                        // Pinned messages toggle. Also self-hiding when the
                        // room has no pinned messages, and an action rather
                        // than furniture, so it stays reachable at every width.
                        _PinnedFilterButton(room: widget.room),

                        // In the single-pane shell the four detail panes have
                        // no sidebar to live in, so they are reachable only
                        // from here. Without this, pinned messages in
                        // particular were unreachable below 600px.
                        if (isSinglePane)
                          IconButton(
                            icon: Icon(
                              LucideIcons.panelsTopLeft,
                              size: iconSize,
                            ),
                            tooltip: AppLocalizations.of(context)!.roomInfo,
                            visualDensity: density,
                            onPressed: () =>
                                showRoomPaneSheet(context, room: widget.room),
                            color: scheme.onSurfaceVariant,
                          ),

                        if (showMemberCount) ...[
                          _MemberCountBadge(count: _memberCount, scheme: scheme),
                          SizedBox(width: t.spaceXs),
                        ],

                        // In-room search toggle
                        IconButton(
                          icon: Icon(
                            widget.isSearchActive
                                ? LucideIcons.searchX
                                : LucideIcons.search,
                            size: iconSize,
                          ),
                          onPressed: widget.onSearchToggle,
                          tooltip: AppLocalizations.of(context)!.searchInRoom,
                          visualDensity: density,
                          color: widget.isSearchActive
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),

                        // Settings gear: navigate to room settings
                        IconButton(
                          icon: Icon(
                            LucideIcons.settings,
                            size: iconSize,
                          ),
                          onPressed: () => openRoomSubpage(
                              context, widget.room.id, 'settings'),
                          tooltip: AppLocalizations.of(context)!.roomSettings,
                          visualDensity: density,
                          color: scheme.onSurfaceVariant,
                        ),

                        // Chevron indicating tappable
                        Icon(
                          Icons.chevron_right_rounded,
                          size: tight ? 16 : 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A small badge showing the number of room members.
class _MemberCountBadge extends StatelessWidget {
  const _MemberCountBadge({
    required this.count,
    required this.scheme,
  });

  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spaceSm, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_rounded,
            size: 14,
            color: scheme.onSecondaryContainer,
          ),
          SizedBox(width: t.spaceXs),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A toggle button that filters the timeline to show only pinned messages.
///
/// Shows an active (filled) style when the pinned filter is on and an
/// inactive (outlined) style when off, so the user knows they can tap
/// again to return to the full timeline.
class _PinnedFilterButton extends StatelessWidget {
  const _PinnedFilterButton({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentRoom = context.watch<CurrentRoom>();
    final isActive = currentRoom.pinnedFilterActive;
    final hasPinned = currentRoom.pinnedEventIds.isNotEmpty;

    // Only show the button if there are pinned messages or the filter
    // is already active.
    if (!hasPinned && !isActive) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        isActive ? Icons.push_pin : Icons.push_pin_outlined,
        size: 18,
      ),
      onPressed: () => currentRoom.togglePinnedFilter(),
      tooltip: isActive
          ? AppLocalizations.of(context)!.showPinnedOnly
          : AppLocalizations.of(context)!.showAllMessages,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor:
            isActive ? scheme.primaryContainer : Colors.transparent,
        foregroundColor:
            isActive ? scheme.onPrimaryContainer : scheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}


