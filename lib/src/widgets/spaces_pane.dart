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

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

class SpacesPane extends StatelessWidget {
  const SpacesPane({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    void join(Room room) async {
      try {
        if (room.membership != Membership.join) {
          await room.join();
        }
        context.push('/rooms/${room.id}');
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
            content: Column(
              children: [
                Text(AppLocalizations.of(context)!.error),
                Text(e.toString()),
              ],
            ),
          ),
        );
      }
    }

    Client client = Provider.of<Client>(context);

    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: client.onSync.stream,
            builder: (context, _) => ListView.builder(
              itemCount: client.rooms.length,
              itemBuilder: (context, index) => ListTile(
                leading: CircleAvatar(
                  foregroundImage: client.rooms[index].avatar == null
                      ? null
                      : NetworkImage(
                          client.rooms[index].avatar.toString(),
                        ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.rooms[index].getLocalizedDisplayname(),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  client.rooms[index].lastEvent?.body ?? 'No messages',
                  maxLines: 1,
                ),
                trailing: (client.rooms[index].notificationCount > 0)
                    ? badges.Badge(
                        child: Text(
                          client.rooms[index].notificationCount.toString(),
                        ),
                      )
                    : null,
                onTap: () => join(client.rooms[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
