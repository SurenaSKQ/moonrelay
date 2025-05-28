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

import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class CreateNewRoom extends StatefulWidget {
  const CreateNewRoom({super.key});

  @override
  State<CreateNewRoom> createState() => _CreateNewRoomState();
}

class _CreateNewRoomState extends State<CreateNewRoom> {
  @override
  Widget build(BuildContext context) {
    Client client = Provider.of<Client>(context);
    client.createRoom();
    return const Placeholder();
  }
}
