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

import 'dart:async';

import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/chat/in_room_search_panel/in_room_search_panel.dart';
import 'package:moonrelay/src/chat/room_info_card.dart';
import 'package:moonrelay/src/chat/typing_indicator.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/lifecycle_generation.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
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

  /// Whether the in-room search panel is visible.
  bool _showInRoomSearch = false;

  /// Key used by [InRoomSearchPanel] to drive the timeline scroll position.
  /// Exposed so a tap on a search result can move the chat viewport to the
  /// matching event.
  final GlobalKey<ChatTimelineState> _timelineKey =
      GlobalKey<ChatTimelineState>();

  /// Navigates to the thread view for [event].
  void _onThread(Event event) {
    openRoomSubpage(
      context,
      widget.room.id,
      'thread/${Uri.encodeComponent(event.eventId)}',
    );
  }

  /// Stable filter function for pinned-only timeline view.
  bool _pinnedFilter(Event event) {
    final ids = context.read<CurrentRoom>().pinnedEventIds;
    return ids.contains(event.eventId);
  }

  /// Brings the event with [eventId] into view when the user taps a
  /// search result.  Closes the search panel first so the timeline is
  /// visible.  The timeline may need to fetch a history window when the
  /// match is older than the local cache, hence the await.
  void _jumpFromSearch(String eventId) {
    setState(() => _showInRoomSearch = false);
    final gen = beginAsync();
    // `addPostFrameCallback` wants a void callback, so the async jump
    // is fired and forgotten here.  It is already guarded by `mounted`
    // and the generation check inside `ChatTimeline.jumpToEvent`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isStale(gen)) return;
      unawaited(_timelineKey.currentState?.jumpToEvent(eventId));
    });
  }

  @override
  void initState() {
    super.initState();
    // Defer the CurrentRoom update to after the current frame.
    // Calling setRoom here would fire during the parent's build phase
    // DashboardLayout has already read CurrentRoom for this frame and
    // the notifyListeners would only take effect on the next frame,
    // causing the right sidebar to lag one navigation behind.
    //
    // Capture the generation so a stale post-frame callback from an
    // earlier mount (e.g. when this widget is reused for a different
    // room via GoRouter's navigator caching) cannot overwrite the new
    // room's CurrentRoom entry.
    final gen = beginAsync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isStale(gen)) return;
      context.read<CurrentRoom>().setRoom(widget.room);
      _focusPermalinkEvent();
    });
  }

  /// Hands a permalinked event to the timeline once the room is mounted.
  ///
  /// Deferred by a frame because the timeline has not built its first
  /// list yet, and the jump may need to fetch a history window, which
  /// the timeline owns.
  void _focusPermalinkEvent() {
    final target = widget.focusEventId;
    if (target == null || target.isEmpty) return;
    // Consumed: a later rebuild must not re-jump the user back to a
    // message they have already scrolled away from.
    _pendingFocus = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final timeline = _timelineKey.currentState;
      if (timeline == null) return;
      unawaited(timeline.jumpToEvent(_pendingFocus));
    });
  }

  /// The permalink target still waiting to be handed to the timeline.
  String? _pendingFocus;

  @override
  void didUpdateWidget(RoomPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      // Bumping the generation invalidates the previous initState's
      // pending setRoom callback; the new one we schedule below
      // captures the fresh generation so it survives.
      invalidate();
      final gen = beginAsync();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || isStale(gen)) return;
        context.read<CurrentRoom>().setRoom(widget.room);
        // Close search when switching rooms
        setState(() => _showInRoomSearch = false);
      });
    }
  }

  @override
  void dispose() {
    _replyTarget.dispose();
    _editTarget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRoom = context.watch<CurrentRoom>();
    final pinnedFilterActive = currentRoom.pinnedFilterActive;

    return Scaffold(
      // `surfaceContainerHigh`, not `surface`. The conversation is the
      // brightest of the three panes, which is what makes it the thing the
      // eye lands on when it arrives at the window: the rail is darker, the
      // room list is mid, and the conversation is the light one. On the old
      // ramp the room pane and the app floor were the same value, so the
      // middle pane had no reason to exist visually.
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      // The room surface fills the pane. It is deliberately not capped and
      // deliberately not centred.
      //
      // It was, briefly: the whole room was constrained to a 760px column
      // and centred, on the reasoning that a 480px bubble in a full-width
      // list leaves a lot of empty surface on a wide monitor and that a
      // centred column would read as a deliberate measure. That is a
      // reading-page argument and this is not a reading page. A chat client
      // is a window onto a live conversation, and on a desktop the window
      // is the thing the user sized deliberately: the extra width is there
      // to be used, and an empty band beside the conversation reads as a
      // layout that ran out of ideas rather than as breathing room.
      //
      // `test/widget/room_page_measure_test.dart` now pins the opposite
      // invariant, so the cap cannot quietly come back.
      body: Column(
        children: [
          ChatRoomHeader(
            room: widget.room,
            onSearchToggle: () =>
                setState(() => _showInRoomSearch = !_showInRoomSearch),
            isSearchActive: _showInRoomSearch,
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ChatTimeline(
                    key: _timelineKey,
                    room: widget.room,
                    onReply: (event) => _replyTarget.value = event,
                    onThread: _onThread,
                    onEdit: (event) => _editTarget.value = event,
                    filterEvents: pinnedFilterActive ? _pinnedFilter : null,
                  ),
                ),
                if (_showInRoomSearch)
                  InRoomSearchPanel(
                    room: widget.room,
                    onClose: () => setState(() => _showInRoomSearch = false),
                    onJumpToEvent: _jumpFromSearch,
                    key: ValueKey('search_${widget.room.id}'),
                  ),
              ],
            ),
          ),
          const Divider(thickness: 1),
          TypingIndicator(room: widget.room),
          ChatBox(
            room: widget.room,
            replyTarget: _replyTarget,
            editTarget: _editTarget,
            threadRootEventId: widget.threadRootEventId,
          ),
        ],
      ),
    );
  }
}