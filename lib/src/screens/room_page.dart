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
import 'package:moonrelay/src/chat/room_info_card.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class RoomPage extends StatefulWidget {
  final Room room;
  const RoomPage({super.key, required this.room});
  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  /// The event the user is currently replying to (or null).
  final ValueNotifier<Event?> _replyTarget = ValueNotifier(null);

  @override
  void dispose() {
    _replyTarget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          ChatRoomHeader(room: widget.room),
          Expanded(
            child: ChatTimeline(
              room: widget.room,
              onReply: (event) => _replyTarget.value = event,
            ),
          ),
          const Divider(thickness: 1),
          ChatBox(
            room: widget.room,
            replyTarget: _replyTarget,
          ),
        ],
      ),
    );
  }
}
