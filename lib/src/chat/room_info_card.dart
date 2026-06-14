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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/screens/room_details_page.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

/// A Material 3 room header bar that reactively displays the room's name,
/// topic, avatar, and member count.
///
/// Listens to room state changes so that the topic and name stay in sync
/// without requiring a manual rebuild. When the topic is missing or fails to
/// load a friendly placeholder is shown instead.
///
/// Tapping the header navigates to the full [RoomInformations] page.
class ChatRoomHeader extends StatefulWidget {
  const ChatRoomHeader({super.key, required this.room});

  final Room room;

  @override
  State<ChatRoomHeader> createState() => _ChatRoomHeaderState();
}

class _ChatRoomHeaderState extends State<ChatRoomHeader> {
  late String _displayName;
  late String _topic;
  late int _memberCount;

  @override
  void initState() {
    super.initState();
    _syncRoomState();
  }

  @override
  void didUpdateWidget(ChatRoomHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _syncRoomState();
    }
  }

  /// Copies the current room values into local state so the build is fast
  /// and we can override them gracefully if needed.
  void _syncRoomState() {
    _displayName = widget.room.getLocalizedDisplayname();
    _topic = widget.room.topic;
    _memberCount = (widget.room.summary.mInvitedMemberCount ?? 0) +
        (widget.room.summary.mJoinedMemberCount ?? 0);
  }

  /// Navigate to the full room information page.
  void _openRoomInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RoomInformations(room: widget.room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<Object>(
      stream: widget.room.client.onRoomState.stream
          .where((event) => event.roomId == widget.room.id),
      builder: (context, snapshot) {
        // Re-read room state whenever the stream fires.
        _syncRoomState();

        final displayName =
            _displayName.isNotEmpty ? _displayName : widget.room.id;
        final topic = _topic.isNotEmpty
            ? _topic
            : 'No topic set'; // Fallback when topic is missing

        return GestureDetector(
          onTap: _openRoomInfo,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                // Room avatar
                AvatarFromUriOrFallbackImage(
                  client: widget.room.client,
                  avatarUri: widget.room.avatar,
                ),
                const SizedBox(width: 12),

                // Name + Topic
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topic,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Member count badge
                _MemberCountBadge(count: _memberCount, scheme: scheme),
                const SizedBox(width: 4),

                // Chevron indicating tappable
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A small badge showing the number of room members.
class _MemberCountBadge extends StatelessWidget {
  const _MemberCountBadge({
    required this.count,
    required this.scheme,
  });

  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_rounded,
            size: 14,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
