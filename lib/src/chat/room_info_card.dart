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
import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/sync_indicator.dart';

/// A Material 3 room header bar that reactively displays the room's name,
/// topic, avatar, and member count.
///
/// Listens to room state changes so that the topic and name stay in sync
/// without requiring a manual rebuild. When the topic is missing or fails to
/// load a friendly placeholder is shown instead.
///
/// Tapping the name opens the info tab, or the pane as a bottom sheet on the
/// single-pane shell.
class ChatRoomHeader extends StatefulWidget {
  const ChatRoomHeader({
    super.key,
    required this.room,
    this.paneTab,
    this.onPaneToggle,
    this.onPaneSheetRequested,
    this.pinnedCount = 0,
    this.pinnedFilterActive = false,
    this.onTogglePinnedFilter,
    this.defaultPaneTab = RoomPaneTab.info,
  });

  final Room room;

  /// Which tab the room's side pane is showing, or null when it is closed.
  ///
  /// The header carries a button per pane tab, so it has to know which one is
  /// open to draw the pressed state. It used to know only about "search",
  /// because the search panel was a separate column with its own toggle and the
  /// pane's tabs were behind the header's tap gesture.
  final RoomPaneTab? paneTab;

  /// Opens or closes the pane on a given tab.
  final void Function(RoomPaneTab tab)? onPaneToggle;

  /// Opens the pane as a bottom sheet.
  ///
  /// Set on the single-pane shell, where there is no room beside the
  /// conversation to put a 280-pixel column in. Null on the desktop shells,
  /// where the pane is inline and the tab buttons drive it directly.
  final VoidCallback? onPaneSheetRequested;

  /// How many events this room has pinned.
  ///
  /// Passed in rather than read from `CurrentRoom`, which holds a pinned list
  /// of its own for whichever room it last saw. Two lists for one room means
  /// the header can offer a pin control for a room with no pins while the pane
  /// says it has none.
  final int pinnedCount;

  /// Whether the timeline is currently filtered to pinned events.
  ///
  /// Constructor parameters for the same reason as [pinnedCount], and because
  /// this button used to read a flag from `CurrentRoom` that no filter used.
  /// It toggled its own icon and tooltip and the timeline carried on showing
  /// everything, which is the one failure a filter control cannot have.
  final bool pinnedFilterActive;

  /// Toggles the timeline's pinned-only filter.
  ///
  /// Null hides the control. A header mounted somewhere that owns no timeline
  /// has nothing to filter, and a button that filters nothing is worse than no
  /// button.
  final VoidCallback? onTogglePinnedFilter;

  /// Which tab the pane button opens when it is not already open.
  ///
  /// The pane does not restore itself any more, so this is what the user's
  /// "which tab does the room pane open on" preference now decides. It is a
  /// parameter rather than a read of `SettingsController` because the header is
  /// a plain widget with no settings dependency, and because a caller mounting
  /// it outside `RoomPage` should be able to say what it wants instead of
  /// silently picking up whatever the preference happens to hold.
  final RoomPaneTab defaultPaneTab;

  @override
  State<ChatRoomHeader> createState() => _ChatRoomHeaderState();
}

IconData _paneIcon(RoomPaneTab tab) => switch (tab) {
      RoomPaneTab.info => LucideIcons.info,
      RoomPaneTab.members => LucideIcons.users,
      RoomPaneTab.threads => LucideIcons.messagesSquare,
      RoomPaneTab.pinned => LucideIcons.pin,
      RoomPaneTab.search => LucideIcons.search,
      RoomPaneTab.none => LucideIcons.circle,
    };

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

  /// Opens the info tab, or the pane as a bottom sheet on the single-pane
  /// shell.
  ///
  /// It used to branch three ways and consult a visibility flag: open the sheet
  /// on mobile, do nothing when the dashboard's sidebar was already on room
  /// info, and otherwise navigate to the full room-information page. That page
  /// is gone and so is the flag, so there is one way in and no state to keep in
  /// step with anything.
  ///  /// It used to branch three ways: open the sheet on mobile, no-op when the
  /// dashboard's sidebar was already on room info, and otherwise navigate to
  /// the full page. With the pane owned by the room page, the middle branch is a
  /// statement about a pane that may not be mounted at all, so it is gone; the
  /// tab buttons next to the name are the visible way in, and this is the
  /// shorthand for the one most people want.
  void _onTap() {
    if (widget.onPaneSheetRequested != null) {
      widget.onPaneSheetRequested!();
      return;
    }
    final void Function(RoomPaneTab)? toggle = widget.onPaneToggle;
    if (toggle == null) return;
    toggle(RoomPaneTab.info);
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
                    // Always the token, never less. A narrow column used to
                    // subtract 4 here on the theory that a tighter bar suits a
                    // tighter pane, which re-created the exact mismatch the
                    // token exists to remove, 4px wide and only below a 400px
                    // conversation. The composer cannot compensate for it: it
                    // has no idea how wide the room is. What `tight` is for is
                    // the horizontal padding and the topic, both of which are
                    // free.
                    height: t.paneBarHeight,
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
                        _PinnedFilterButton(
                          count: widget.pinnedCount,
                          isActive: widget.pinnedFilterActive,
                          onToggle: widget.onTogglePinnedFilter,
                        ),

                        // In the single-pane shell the four detail panes have
                        // In the single-pane shell the pane has no room to
                        // live in, so one button opens it as a sheet. Without
                        // this, pinned messages in particular were unreachable
                        // below 600px.
                        if (widget.onPaneSheetRequested != null)
                          IconButton(
                            icon: Icon(
                              LucideIcons.panelsTopLeft,
                              size: iconSize,
                            ),
                            tooltip: AppLocalizations.of(context)!.roomPaneInfo,
                            visualDensity: density,
                            onPressed: widget.onPaneSheetRequested,
                            color: scheme.onSurfaceVariant,
                          ),

                        if (showMemberCount) ...[
                          _MemberCountBadge(
                              count: _memberCount, scheme: scheme),
                          SizedBox(width: t.spaceXs),
                        ],

                        // One button, and the pane's own strip does the tab switching.
                        //
                        // Five tab buttons were tried here first and overflowed
                        // a 52-pixel bar by 43 pixels, which is the right answer
                        // arriving the wrong way: the pane already carries a tab
                        // strip, so buttons in two places are two controls for
                        // one decision, and the bar that has to stay one height
                        // is the one that ran out of room.
                        if (widget.onPaneToggle != null)
                          IconButton(
                            icon: Icon(
                              _paneIcon(
                                  widget.paneTab ?? widget.defaultPaneTab),
                              size: iconSize,
                            ),
                            onPressed: () =>
                                widget.onPaneToggle!(widget.defaultPaneTab),
                            tooltip: localizedRoomPaneTab(
                              widget.defaultPaneTab,
                              AppLocalizations.of(context)!,
                            ),
                            visualDensity: density,
                            color: widget.paneTab != null
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
  const _PinnedFilterButton({
    required this.count,
    required this.isActive,
    required this.onToggle,
  });

  final int count;
  final bool isActive;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Fail closed on the callback before the condition on the count. A
    // control with nothing to toggle would draw itself as armed and do nothing.
    final toggle = onToggle;
    if (toggle == null) return const SizedBox.shrink();

    // Only show the button if there are pinned messages or the filter
    // is already active.
    if (count == 0 && !isActive) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        isActive ? Icons.push_pin : Icons.push_pin_outlined,
        size: 18,
      ),
      onPressed: toggle,
      tooltip: isActive
          ? AppLocalizations.of(context)!.showPinnedOnly
          : AppLocalizations.of(context)!.showAllMessages,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor:
            isActive ? scheme.primaryContainer : Colors.transparent,
        foregroundColor: isActive
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}
