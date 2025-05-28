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
import 'package:moonrelay/src/helpers/color_palette.dart';
import 'package:moonrelay/src/layouts/custom_scaffold.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';

class RoomPage extends StatefulWidget {
  final Room room;
  const RoomPage({super.key, required this.room});
  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      backgroundColor: MoonrelayColorPalette.ordinaryDarkGrey,
      content: Stack(children: [
        Column(
          children: [
            Expanded(
              child: ChatTimeline(room: widget.room),
            ),
            const Divider(
              direction: Axis.vertical,
              size: 1,
            ),
            ChatBox(room: widget.room),
          ],
        ),
        RoomInfoCard(room: widget.room),
      ]),
    );
  }
}
