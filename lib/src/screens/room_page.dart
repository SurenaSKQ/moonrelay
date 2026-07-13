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

import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/chat/in_room_search_panel.dart';
import 'package:moonrelay/src/chat/room_info_card.dart';
import 'package:moonrelay/src/chat/typing_indicator.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class RoomPage extends StatefulWidget {
  final Room room;
  final String? threadRootEventId;
  const RoomPage({super.key, required this.room, this.threadRootEventId});
  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  /// The event the user is currently replying to (or null).
  final ValueNotifier<Event?> _replyTarget = ValueNotifier(null);

  /// Whether the in-room search panel is visible.
  bool _showInRoomSearch = false;

  /// Key used by [InRoomSearchPanel] to drive the timeline scroll position.
  /// Exposed so a tap on a search result can move the chat viewport to the
  /// matching event.
  final GlobalKey<ChatTimelineState> _timelineKey =
      GlobalKey<ChatTimelineState>();

  /// Navigates to the thread view for [event].
  void _onThread(Event event) {
    context.push(
      '/main/rooms/${widget.room.id}/thread/${event.eventId}',
    );
  }

  /// Stable filter function for pinned-only timeline view.
  bool _pinnedFilter(Event event) {
    final ids = context.read<CurrentRoom>().pinnedEventIds;
    return ids.contains(event.eventId);
  }

  /// Scrolls the timeline to the event with [eventId] when the user
  /// taps a search result.  Closes the search panel first so the
  /// timeline is visible.
  void _jumpFromSearch(String eventId) {
    setState(() => _showInRoomSearch = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timelineKey.currentState?.jumpToEvent(eventId);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CurrentRoom>().setRoom(widget.room);
      }
    });
  }

  @override
  void didUpdateWidget(RoomPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<CurrentRoom>().setRoom(widget.room);
          // Close search when switching rooms
          setState(() => _showInRoomSearch = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _replyTarget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRoom = context.watch<CurrentRoom>();
    final pinnedFilterActive = currentRoom.pinnedFilterActive;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
            threadRootEventId: widget.threadRootEventId,
          ),
        ],
      ),
    );
  }
}
