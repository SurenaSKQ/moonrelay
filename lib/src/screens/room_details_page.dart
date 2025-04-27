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
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.back),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(
                  width: 24,
                ),
                widget.room.avatar == null
                    ? Text(
                        widget.room
                            .getLocalizedDisplayname()
                            .toUpperCase()
                            .split(RegExp(' +'))
                            .map((s) => s[0])
                            .take(2)
                            .join(),
                      )
                    : CircleAvatar(
                        maxRadius: 32,
                        foregroundImage: NetworkImage(
                          widget.room.avatar!
                              .getThumbnail(
                                widget.room.client,
                                animated: true,
                                width: 128,
                                height: 128,
                              )
                              .toString(),
                        ),
                      ),
                const SizedBox(
                  width: 32,
                ),
                Column(
                  children: [
                    Text(
                      widget.room.getLocalizedDisplayname(),
                      style: FluentTheme.of(context).typography.title,
                    ),
                    const SizedBox(
                      height: 6.0,
                    ),
                    Text(
                      "Room ID: ${widget.room.id}",
                      style: FluentTheme.of(context).typography.subtitle,
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
        final iconColor = FluentTheme.of(context).accentColor;
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
                        color: FluentTheme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FluentTheme.of(context).accentColor,
                        ),
                      ),
                      child: Text(
                        permissionBatch,
                        style: TextStyle(
                          fontSize: 14,
                          color: FluentTheme.of(context).accentColor,
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
              leading: CircleAvatar(
                foregroundImage: members[index].avatarUrl == null
                    ? null
                    : NetworkImage(
                        members[index]
                            .avatarUrl!
                            .getThumbnail(
                              room.client,
                              width: 56,
                              height: 56,
                            )
                            .toString(),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
