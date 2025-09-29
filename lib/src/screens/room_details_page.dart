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

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

///The information screen of a page
/// Needs a complete redesign: Use the room header widget as a hero widget to do an animation
/// Also needs a new widget for user list; needs to show room controls; some additional information about the room
class RoomInformations extends StatefulWidget {
  const RoomInformations({super.key, required this.room});
  final Room room;

  @override
  State<RoomInformations> createState() => _RoomInformationsState();
}

class _RoomInformationsState extends State<RoomInformations> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(
                    width: 24,
                  ),
                  // FIXME Add a fallback image for rooms
                  AvatarFromUriOrFallbackImage(
                    client: widget.room.client,
                    avatarUri: widget.room.avatar,
                  ),
                  const SizedBox(
                    width: 32,
                  ),
                  Column(
                    children: [
                      Text(
                        widget.room.getLocalizedDisplayname(),
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(
                        height: 6.0,
                      ),
                      Text(
                        "Room ID: ${widget.room.id}",
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(
                height: 24,
              ),
              Flexible(flex: 4, child: RoomParticipantsList(room: widget.room))
            ],
          ),
        ),
      ),
    );
  }
}

//FIXME: Needs localizations
class RoomParticipantsList extends StatelessWidget {
  const RoomParticipantsList({super.key, required this.room});
  final Room room;

  // Disclaimer: This is a stub widget with a lot of code copied from FluffyChat
  // DEFINITELY needs a complete rewrite
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: room.client.onRoomState.stream.where(
        (event) => event.roomId == room.id,
      ),
      builder: (context, snapshot) {
        var members = room.getParticipants().toList()
          ..sort((b, a) => a.powerLevel.compareTo(b.powerLevel));
        members = members.take(10).toList();
        final actualMembersCount = (room.summary.mInvitedMemberCount ?? 0) +
            (room.summary.mJoinedMemberCount ?? 0);
        final canRequestMoreMembers = members.length < actualMembersCount;
        final iconColor = Theme.of(context).colorScheme.primary;
        final displayName = room.getLocalizedDisplayname();
        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final membershipBatch = switch (members[index].membership) {
              Membership.ban => "Banned",
              Membership.invite => "Invited",
              Membership.join => null,
              Membership.knock => "Wants to enter",
              Membership.leave => "Left the chat",
            };
            final permissionBatch = members[index].powerLevel == 100
                ? "Administrator"
                : members[index].powerLevel >= 50
                    ? "Moderator"
                    : '';
            return ListTile(
              title: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      members[index].calcDisplayname(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (permissionBatch.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      child: Text(
                        permissionBatch,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  membershipBatch == null
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text(membershipBatch)),
                        ),
                ],
              ),
              subtitle: Text(members[index].id),
              leading: AvatarFromUriOrFallbackImage(
                client: room.client,
                avatarUri: members[index].avatarUrl,
              ),
            );
          },
        );
      },
    );
  }
}
