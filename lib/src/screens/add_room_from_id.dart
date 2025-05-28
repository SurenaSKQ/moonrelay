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
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

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
    return ScaffoldPage(
      header: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () => context.pop(),
      ),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              "Search for the room you wish to join:",
              style: FluentTheme.of(context).typography.bodyLarge,
            ),
            const SizedBox(
              height: 8.0,
            ),
            InfoLabel(
              label: "Room ID or Alias",
              child: TextBox(
                controller: _roomIdController,
              ),
            ),
            const SizedBox(
              height: 8.0,
            ),
            Text(
              "Enter the server to join through:",
              style: FluentTheme.of(context).typography.bodyLarge,
            ),
            Text(
              "If left empty, your own homeserver will be used.",
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(
              height: 8.0,
            ),
            InfoLabel(
              label: "Server",
              child: TextBox(
                controller: _serverController,
              ),
            ),
            OutlinedButton(
              child: const Row(
                children: [Icon(FluentIcons.add), Text("Add Room")],
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
