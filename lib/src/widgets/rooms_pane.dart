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

import 'package:adwaita_icons/adwaita_icons.dart';
import 'package:badges/badges.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:go_router/go_router.dart';
import 'package:libadwaita/libadwaita.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

class RoomsPane extends StatelessWidget {
  const RoomsPane({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    void join(Room room) async {
      try {
        if (room.membership != Membership.join) {
          await room.join();
        }
        context.pushReplacement('/main/rooms/${room.id}');
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
    return Material(
      child: StreamBuilder(
        stream: client.onSync.stream,
        builder: (context, _) => ListView.builder(
          itemCount: client.rooms.length,
          itemBuilder: (context, index) => ListTile(
            // FIXME: Avatar & Badge
            leading: Badge(
              showBadge: client.rooms[index].hasNewMessages,
              badgeStyle: BadgeStyle(
                badgeColor: Theme.of(context).primaryColor,
                shape: BadgeShape.circle,
              ),
              badgeContent: Icon(
                Icons.notifications,
                size: 8,
              ),
              child: (client.rooms[index].avatar == null)
                  ? AdwAvatar(
                      child: Text(
                        client.rooms[index]
                            .getLocalizedDisplayname()
                            .toUpperCase()
                            .split(RegExp(' +'))
                            .map((s) => s[0])
                            .take(2)
                            .join(),
                      ),
                    )
                  : FutureBuilder(
                      future: client.rooms[index].avatar!.getThumbnailUri(
                          client,
                          method: ThumbnailMethod.scale,
                          height: 56,
                          width: 56),
                      builder: (context, asyncSnapshot) {
                        if (asyncSnapshot.hasError) {
                          return AdwAvatar(
                            child: Text(
                              client.rooms[index]
                                  .getLocalizedDisplayname()
                                  .toUpperCase()
                                  .split(RegExp(' +'))
                                  .map((s) => s[0])
                                  .take(2)
                                  .join(),
                            ),
                          );
                        }
                        if (asyncSnapshot.hasData) {
                          return AdwAvatar(
                            backgroundImage: NetworkImage(
                              asyncSnapshot.data.toString(),
                              headers: {
                                "authorization": "Bearer ${client.accessToken}"
                              },
                            ),
                            child: const Text(''),
                          );
                        } else {
                          return CircularProgressIndicator();
                        }
                      },
                    ),
            ),

            title: Row(
              children: [
                Expanded(
                  child: Text(
                    client.rooms[index].getLocalizedDisplayname(),
                    style: const TextStyle(
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.w300,
                        fontSize: 18),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              client.rooms[index].lastEvent?.body ?? 'No messages',
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'Rubic',
                fontWeight: FontWeight.w300,
                fontSize: 16,
              ),
            ),
            onTap: () => join(client.rooms[index]),
          ),
        ),
      ),
    );
  }
}
