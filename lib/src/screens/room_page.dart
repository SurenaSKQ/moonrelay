// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.

import 'package:azhi_main/src/chat/chat_box.dart';
import 'package:azhi_main/src/chat/chat_timeline.dart';
import 'package:azhi_main/src/chat/room_info_card.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:matrix/matrix.dart';

class AzhiRoomPage extends StatefulWidget {
  final Room room;
  const AzhiRoomPage({super.key, required this.room});
  @override
  State<AzhiRoomPage> createState() => _AzhiRoomPageState();
}

class _AzhiRoomPageState extends State<AzhiRoomPage> {
  @override
  Widget build(BuildContext context) {
    return mt.Scaffold(
      backgroundColor: FluentTheme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          RoomInfoCard(room: widget.room),
          const SizedBox(
            height: 4,
          ),
          const Divider(
            direction: Axis.horizontal,
          ),
          Expanded(
            child: AzhiChatTimeline(room: widget.room),
          ),
          const Divider(
            direction: Axis.vertical,
            size: 1,
          ),
          ChatBox(room: widget.room),
        ],
      ),
    );
  }
}
