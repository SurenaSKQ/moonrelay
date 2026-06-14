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

import 'dart:async';

import 'package:badges/badges.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// A scrollable list of rooms, optionally filtered by [roomFilter].
///
/// If [roomFilter] is `null`, every room the user is a member of is shown.
/// Otherwise only rooms for which the predicate returns `true` are shown —
/// this is used by the navigation pane to display direct chats, all rooms,
/// or rooms belonging to a specific space.
class RoomsPane extends StatelessWidget {
  /// An optional filter predicate. Return `true` to include a room.
  final bool Function(Room room)? roomFilter;

  const RoomsPane({
    super.key,
    this.roomFilter,
  });

  @override
  Widget build(BuildContext context) {
    void join(Room room) async {
      final log = Provider.of<Logger>(context, listen: false);
      try {
        if (room.membership != Membership.join) {
          final result = await withRetry(
            () => room.join(),
            maxRetries: 1,
            timeout: kDefaultTimeout,
            log: log,
            label: 'joinRoom',
          );
          if (result is RetryFailed) {
            throw (result).error;
          }
        }
        if (!context.mounted) return;
        context.pushReplacement('/main/rooms/${room.id}');
      } catch (e) {
        log.f(
          'Failed to join',
          error: e,
          stackTrace: StackTrace.current,
          time: DateTime.now(),
        );
        if (!context.mounted) return;
        final message = e is TimeoutException
            ? 'Could not join room: The server did not respond in time.'
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.error),
                Text(message),
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
        builder: (context, _) {
          // Re-filter on every sync to pick up new rooms.
          final Iterable<Room> currentRooms = roomFilter != null
              ? client.rooms.where(roomFilter!)
              : client.rooms;

          return ListView.builder(
            itemCount: currentRooms.length,
            itemBuilder: (context, index) {
              final Room room = currentRooms.elementAt(index);
              return ListTile(
                // FIXME: Avatar & Badge
                leading: Badge(
                  showBadge: room.hasNewMessages,
                  badgeStyle: BadgeStyle(
                    badgeColor: Theme.of(context).primaryColor,
                    shape: BadgeShape.circle,
                  ),
                  badgeContent: Icon(
                    Icons.notifications,
                    size: 8,
                  ),
                  child: (room.avatar == null)
                      ? CircleAvatar(
                          child: Text(
                            room
                                .getLocalizedDisplayname()
                                .toUpperCase()
                                .split(RegExp(' +'))
                                .map((s) => s[0])
                                .take(2)
                                .join(),
                          ),
                        )
                      : FutureBuilder(
                          future: withTimeoutOrFallback(
                            () => room.avatar!.getThumbnailUri(
                              client,
                              method: ThumbnailMethod.scale,
                              height: 56,
                              width: 56,
                            ),
                            timeout: kDefaultTimeout,
                            fallback: null,
                          ),
                          builder: (context, asyncSnapshot) {
                            if (asyncSnapshot.hasData &&
                                asyncSnapshot.data != null) {
                              return CircleAvatar(
                                backgroundImage: NetworkImage(
                                  asyncSnapshot.data.toString(),
                                  headers: {
                                    'authorization':
                                        'Bearer ${client.accessToken}',
                                  },
                                ),
                              );
                            }
                            return CircleAvatar(
                              child: Text(
                                room
                                    .getLocalizedDisplayname()
                                    .toUpperCase()
                                    .split(RegExp(' +'))
                                    .map((s) => s[0])
                                    .take(2)
                                    .join(),
                              ),
                            );
                          },
                        ),
                ),

                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.getLocalizedDisplayname(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w300, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  room.lastEvent?.body ?? 'No messages',
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 16,
                  ),
                ),
                onTap: () => join(room),
              );
            },
          );
        },
      ),
    );
  }
}
