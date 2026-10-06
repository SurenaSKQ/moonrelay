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

// A room: the conversation, and the pane that describes it.
//
// The side pane lives here now. It used to be a row child of `DashboardView`,
// a sibling of the route content, which meant the pane that describes a room
// was built by the shell that contains rooms. Three consequences, all of them
// the kind of bug that comes from state living one level above where it is used:
//
//   - The pane learned which room to describe from `CurrentRoom`, a global. The
//     pane was mounted even on the home dashboard, where there is no room, and
//     rendered an empty state next to a conversation that was not there.
//   - Which tab was showing lived in `SettingsController`, so it was global
//     state for a per-room decision, and it persisted a choice the user made
//     once in whichever room they happened to be in.
//   - The in-room search was a *second* right-hand column inside this widget,
//     with its own header, its own fixed width and its own idea of which room
//     it was for. Two panes, two owners.
//
// Now there is one pane, it takes `widget.room`, and its state is the four
// fields below. Nothing in this subtree reads a provider to find out which room
// it is in.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/chat/room_pane/resize_handle.dart';
import 'package:moonrelay/src/chat/room_info_card.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane_sheet.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';
import 'package:moonrelay/src/chat/typing_indicator.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/json_utils.dart';
import 'package:moonrelay/src/helpers/lifecycle_generation.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

class RoomPage extends StatefulWidget {
  final Room room;
  final String? threadRootEventId;

  /// Event to focus on open, from an event permalink.  Consumed once:
  /// the timeline clears it so a later rebuild does not re-jump.
  final String? focusEventId;

  const RoomPage({
    super.key,
    required this.room,
    this.threadRootEventId,
    this.focusEventId,
  });
  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> with LifecycleGeneration {
  /// The event the user is currently replying to (or null).
  final ValueNotifier<Event?> _replyTarget = ValueNotifier(null);

  /// The event the user is currently editing (or null).
  final ValueNotifier<Event?> _editTarget = ValueNotifier(null);

  /// Which tab the side pane is showing, or null when it is closed.
  RoomPaneTab? _pane;

  /// This room's pinned event ids.
  ///
  /// Read from room state rather than from `CurrentRoom`, which held one list
  /// for whichever room it last saw, alongside a single global
  /// `pinnedFilterActive` flag. So toggling the pin filter in one room and
  /// switching to another left the flag set for the room you had not been in.
  List<String> _pinnedEventIds = const <String>[];

  bool _pinnedFilterActive = false;

  /// Drag width of the pane, or null when it is at the persisted width.
  ///
  /// Ephemeral during a drag and written to preferences on release, which is why
  /// it is a notifier rather than a settings field read in `build`.
  final ValueNotifier<double?> _paneWidth = ValueNotifier<double?>(null);

  /// Key used by [ChatTimeline] to drive the scroll position, so a tap on a
  /// search result can move the chat viewport to the matching event.
  final GlobalKey<ChatTimelineState> _timelineKey =
      GlobalKey<ChatTimelineState>();

  /// The permalink target still waiting to be handed to the timeline.
  String? _pendingFocus;

  bool get _isMobile => context.read<LayoutShellController>().isMobile;

  // -- Pane -------------------------------------------------------------

  void _openPane(RoomPaneTab tab) {
    final SettingsController settings = context.read<SettingsController>();
    setState(() => _pane = tab);
    // `search` is deliberately not persisted: it is a task in progress, not a
    // preference. Reopening a room with an abandoned query in it would be a bug.
    if (tab.restorable) unawaited(settings.setRoomPaneTab(tab));
  }

  void _closePane() => setState(() => _pane = null);

  /// Which tab the pane opens on when something opens it.
  ///
  /// This is the last reader of `SettingsController.roomPaneTab`, and it is why
  /// that preference is worth keeping now that the pane no longer restores
  /// itself. "Which tab the pane opens on" is a real question with a real
  /// answer, and the hub dropdown's subtitle says exactly this. What is *not* a
  /// real question is whether it should already be open, which is what the
  /// preference used to be asked to decide.
  RoomPaneTab get _defaultPaneTab {
    final RoomPaneTab stored =
        context.read<SettingsController>().roomPaneTab.restorableAs;
    return stored == RoomPaneTab.none ? RoomPaneTab.info : stored;
  }

  /// Opens [tab], or closes the pane if it is already showing it.
  ///
  /// Toggle rather than open, because the room header carries one button per
  /// pane tab and a button that only ever opens is a button that lies after the
  /// first press.
  void _togglePane(RoomPaneTab tab) {
    if (_pane == tab) {
      _closePane();
      return;
    }
    _openPane(tab);
  }

  void _togglePinnedFilter() {
    setState(() => _pinnedFilterActive = !_pinnedFilterActive);
  }

  void _onPaneDrag(double delta) {
    final double current =
        _paneWidth.value ?? context.read<SettingsController>().roomPaneWidth;
    _paneWidth.value = current - delta;
  }

  void _onPaneDragEnd() {
    final double? width = _paneWidth.value;
    if (width == null) return;
    _paneWidth.value = null;
    unawaited(context.read<SettingsController>().setRoomPaneWidth(width));
  }

  void _showPaneSheet() {
    final RoomPaneTab tab = _pane ?? _defaultPaneTab;
    unawaited(
      showRoomPaneSheet(
        context,
        room: widget.room,
        initialTab: tab,
        pinnedEventIds: _pinnedEventIds,
        pinnedFilterActive: _pinnedFilterActive,
        onSelectTab: _openPane,
        onTogglePinnedFilter: _togglePinnedFilter,
      ),
    );
  }

  // -- Timeline ---------------------------------------------------------

  void _onThread(Event event) {
    openRoomSubpage(
      context,
      widget.room.id,
      'thread/${Uri.encodeComponent(event.eventId)}',
    );
  }

  /// Stable filter function for the pinned-only timeline view.
  bool _pinnedFilter(Event event) => _pinnedEventIds.contains(event.eventId);

  /// Brings the event with [eventId] into view.
  ///
  /// Closes the pane first, not just the search tab: the jump moves the
  /// timeline, and leaving a result list covering the message the user just
  /// asked for is not a useful thing to do. The timeline may need to fetch a
  /// history window when the match is older than the local cache.
  void _jumpFromSearch(String eventId) {
    setState(() => _pane = null);
    final gen = beginAsync();
    // `addPostFrameCallback` wants a void callback, so the async jump is fired
    // and forgotten. It is guarded by `mounted` here and by a generation check
    // inside `ChatTimeline.jumpToEvent`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isStale(gen)) return;
      unawaited(_timelineKey.currentState?.jumpToEvent(eventId));
    });
  }

  /// Hands a permalinked event to the timeline once the room is mounted.
  ///
  /// Deferred by a frame because the timeline has not built its first list yet,
  /// and the jump may need to fetch a history window, which the timeline owns.
  void _focusPermalinkEvent() {
    final target = widget.focusEventId;
    if (target == null || target.isEmpty) return;
    // Consumed: a later rebuild must not re-jump the user back to a message
    // they have already scrolled away from.
    _pendingFocus = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final timeline = _timelineKey.currentState;
      if (timeline == null) return;
      unawaited(timeline.jumpToEvent(_pendingFocus));
    });
  }

  // -- Lifecycle --------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Defer the `CurrentRoom` update to after the current frame.
    //
    // `CurrentRoom` still exists, for the readers that are not in this subtree:
    // the room list's selected row, the home dashboard's recents, and the
    // notification service deciding which room you are already reading. It is
    // no longer how the side pane finds its room, which is the reason the deferral
    // was originally necessary.
    //
    // The generation capture stops a stale post-frame callback from an earlier
    // mount (GoRouter reuses this widget for a different room) overwriting the
    // new room's entry.
    final gen = beginAsync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isStale(gen)) return;
      context.read<CurrentRoom>().setRoom(widget.room);
      _focusPermalinkEvent();
      setState(() => _pinnedEventIds = pinnedEventIds(widget.room));
    });
  }

  @override
  void didUpdateWidget(RoomPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id == widget.room.id) return;

    // Bumping the generation invalidates the previous initState's pending
    // callbacks; the new ones capture the fresh generation so they survive.
    invalidate();
    final gen = beginAsync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isStale(gen)) return;
      context.read<CurrentRoom>().setRoom(widget.room);
      // A different room, so a different pane. The search query, the pin filter
      // and the member list all belonged to the room just left.
      //
      // The pane closes rather than reopens, and that is the whole point. This
      // State is reused across `:roomid` changes, because `RoomPage` is built
      // from a plain `builder:` with no key. It used to re-apply the persisted
      // `roomPaneTab` here, which meant changing rooms threw the pane back open
      // on a room you had not asked to see anything about, and closing the pane
      // did not help, because nothing anywhere could write `none`: the hub
      // dropdown offers `restorableOptions`, which excludes it.
      //
      // The persisted tab still means something, it is which tab the pane opens
      // on when you do open it, via [_defaultPaneTab]. Being closed is not a
      // preference, it is the absence of an action.
      setState(() {
        _pane = null;
        _pinnedEventIds = pinnedEventIds(widget.room);
        _pinnedFilterActive = false;
      });
    });
  }

  @override
  void dispose() {
    _replyTarget.dispose();
    _editTarget.dispose();
    _paneWidth.dispose();
    super.dispose();
  }

  // -- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isMobile = _isMobile;

    return Scaffold(
      // `surfaceContainerHigh`, not `surface`. The conversation is the
      // brightest of the panes, which is what makes it the thing the eye lands
      // on when it arrives at the window: the rail is darker, the room list is
      // mid, and the conversation is the light one.
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      // The conversation fills its column. Deliberately not capped and
      // deliberately not centred; `test/widget/room_page_layout_test.dart` pins
      // that, so the cap cannot quietly come back.
      body: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                ChatRoomHeader(
                  room: widget.room,
                  paneTab: _pane,
                  onPaneToggle: _togglePane,
                  onPaneSheetRequested: isMobile ? _showPaneSheet : null,
                  defaultPaneTab: _defaultPaneTab,
                  pinnedCount: _pinnedEventIds.length,
                  pinnedFilterActive: _pinnedFilterActive,
                  onTogglePinnedFilter: _togglePinnedFilter,
                ),
                Expanded(
                  child: ChatTimeline(
                    key: _timelineKey,
                    room: widget.room,
                    onReply: (event) => _replyTarget.value = event,
                    onThread: _onThread,
                    onEdit: (event) => _editTarget.value = event,
                    filterEvents: _pinnedFilterActive ? _pinnedFilter : null,
                  ),
                ),
                // `height: 1` explicitly, to match the rule above the sidebar's footer. The
                // theme sets `DividerThemeData.space` to the divider token's
                // `thickness`, which is `borderWidthThin`, so a `Divider` with
                // no `height` of its own is half a pixel of slot. The sidebar's
                // rule sets `height: 1` and therefore does not, which put the two
                // hairlines either side of this seam at different heights and
                // the bottom rows half a pixel out. Recorded in
                // `WORK_NEEDED.md`: the theme's `space` is the bug, but fixing
                // it there moves every divider in the app and is not this
                // change's business.
                const Divider(height: 1, thickness: 1),
                TypingIndicator(room: widget.room),
                ChatBox(
                  room: widget.room,
                  replyTarget: _replyTarget,
                  editTarget: _editTarget,
                  threadRootEventId: widget.threadRootEventId,
                ),
              ],
            ),
          ),
          // The pane is a sibling of the whole conversation column rather than of
          // the timeline inside it, so its 52px header bar lines up with
          // `ChatRoomHeader` and the conversation keeps its full column height.
          if (!isMobile && _pane != null) ...<Widget>[
            ResizeHandle(onDrag: _onPaneDrag, onDragEnd: _onPaneDragEnd),
            ValueListenableBuilder<double?>(
              valueListenable: _paneWidth,
              builder: (BuildContext context, double? drag, _) {
                final double width =
                    drag ?? context.read<SettingsController>().roomPaneWidth;
                return SizedBox(
                  width: width.clamp(
                    LayoutBreakpoints.minSidebarWidth,
                    double.infinity,
                  ),
                  child: RoomPane(
                    room: widget.room,
                    tab: _pane!,
                    pinnedEventIds: _pinnedEventIds,
                    pinnedFilterActive: _pinnedFilterActive,
                    onSelectTab: _togglePane,
                    onClose: _closePane,
                    onJumpToEvent: _jumpFromSearch,
                    onTogglePinnedFilter: _togglePinnedFilter,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
