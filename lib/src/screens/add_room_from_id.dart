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
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/widgets/label.dart';
import 'package:provider/provider.dart';

// FIXME Text Styling
class AddRoomFromID extends StatefulWidget {
  const AddRoomFromID({super.key});

  @override
  State<AddRoomFromID> createState() => _AddRoomFromIDState();
}

class _AddRoomFromIDState extends State<AddRoomFromID> {
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();
  final bool _loading = false;

  Future<void> _addRoomFromID(
      Client client, String roomidOrAlias, String? server) async {
    client.joinRoom(roomidOrAlias);
  }

  @override
  Widget build(BuildContext context) {
    Client client = Provider.of<Client>(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              "Search for the room you wish to join:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            ),
            const SizedBox(
              height: 8.0,
            ),
            Label(
              label: "Room ID or Alias",
              child: TextField(
                controller: _roomIdController,
              ),
            ),
            const SizedBox(
              height: 8.0,
            ),
            Text(
              "Enter the server to join through:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            ),
            Text(
              "If left empty, your own homeserver will be used.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 8.0,
            ),
            Label(
              label: "Server",
              child: TextField(
                controller: _serverController,
              ),
            ),
            OutlinedButton(
              child: const Row(
                children: [Icon(LucideIcons.plus), Text("Add Room")],
              ),
              onPressed: () => _addRoomFromID(
                  client, _roomIdController.text, _serverController.text),
            ),
          ],
        ),
      ),
    );
  }
}
