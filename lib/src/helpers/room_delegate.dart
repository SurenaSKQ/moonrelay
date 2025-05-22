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

import 'package:fluent_ui/fluent_ui.dart';
import 'package:azhi_main/src/layouts/empty_space.dart';
import 'package:azhi_main/src/screens/room_page.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class RoomDelegate extends StatelessWidget {
  const RoomDelegate({super.key, required this.roomID});
  final String? roomID;

  @override
  Widget build(BuildContext context) {
    // listen could trigger a fault?
    Client client = Provider.of<Client>(context);
    if (roomID != null) {
      return (client.getRoomById(roomID!) != null)
          ? AzhiRoomPage(room: client.getRoomById(roomID!)!)
          : const EmptySpace();
    } else {
      return const EmptySpace();
    }
  }
}
