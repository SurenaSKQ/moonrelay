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

import 'package:azhi_main/src/screens/loginPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import 'package:logger/logger.dart';
import 'room_page.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  static const routeName = '/chatScreen';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  void _logout() async {
    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);
    try {
      await client.logout();
      mounted
          ? Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const LoginPage(),
              ),
              (route) => false,
            )
          : throw "Build context async failure widget not mounted";
    } catch (e) {
      log.e("Logout error",
          error: e, time: DateTime.now(), stackTrace: StackTrace.current);
      mounted
          ? ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
              ),
            )
          : throw "Build context async failure widget not mounted";
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context, listen: false);

    void _join(Room room) async {
      try {
        if (room.membership != Membership.join) {
          await room.join();
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoomPage(room: room),
          ),
        );
      } catch (e) {
        Provider.of<Logger>(context).f(
          "Failed to join",
          error: e,
          stackTrace: StackTrace.current,
          time: DateTime.now(),
        );
        // FIXME: Better error and localization
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: client.onSync.stream,
        builder: (context, _) => ListView.builder(
          itemCount: client.rooms.length,
          itemBuilder: (context, i) => ListTile(
            leading: CircleAvatar(
              foregroundImage: client.rooms[i].avatar == null
                  ? null
                  : NetworkImage(client.rooms[i].avatar!
                      .getThumbnail(
                        client,
                        width: 56,
                        height: 56,
                      )
                      .toString()),
            ),
            title: Row(
              children: [
                Expanded(
                    child: Text(client.rooms[i].getLocalizedDisplayname())),
                if (client.rooms[i].notificationCount > 0)
                  Material(
                    borderRadius: BorderRadius.circular(99),
                    color: Colors.red,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Text(client.rooms[i].notificationCount.toString()),
                    ),
                  )
              ],
            ),
            subtitle: Text(
              client.rooms[i].lastEvent?.body ?? 'No messages',
              maxLines: 1,
            ),
            onTap: () => _join(client.rooms[i]),
          ),
        ),
      ),
    );
  }
}
