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

/// Renders Matrix state events (membership changes, room metadata updates,
/// encryption toggles, etc.) as centred, muted timeline items with suitable
/// icons per event type.
class StateEvents extends StatelessWidget {
  const StateEvents({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withOpacity(0.55);

    // Resolve the display name of the sender.
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _iconForType(event.type),
            size: 14,
            color: mutedColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _description(event.type, senderName),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Rubik',
                color: mutedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a suitable Fluent icon for the given Matrix event type.
  IconData _iconForType(String type) {
    switch (type) {
      case 'm.room.member':
        return Icons.people;
      case 'm.room.name':
        return Icons.edit;
      case 'm.room.topic':
        return Icons.info;
      case 'm.room.avatar':
        return Icons.camera_alt;
      case 'm.room.create':
        return Icons.add;
      case 'm.room.encryption':
        return Icons.lock;
      case 'm.room.pinned_events':
        return Icons.push_pin;
      case 'm.room.canonical_alias':
        return Icons.link;
      case 'm.room.power_levels':
        return Icons.shield;
      case 'm.room.tombstone':
        return Icons.arrow_upward;
      default:
        return Icons.info;
    }
  }

  /// Builds a human-readable description for common state events.
  String _description(String type, String senderName) {
    try {
      switch (type) {
        case 'm.room.member':
          final membership = event.content['membership']?.toString() ?? '';
          final displayName =
              event.content['displayname']?.toString() ?? 'Unknown';
          final prevContent = event.unsigned?['prev_content'] as Map?;
          final prevMembership = prevContent?['membership']?.toString();

          switch (membership) {
            case 'join':
              if (prevMembership == 'invite') {
                return '$senderName accepted the invitation';
              }
              return '$senderName joined the room';
            case 'leave':
              if (prevMembership == 'ban') {
                return '$senderName was unbanned';
              }
              return '$senderName left the room';
            case 'ban':
              return '$senderName was banned';
            case 'invite':
              return '$senderName invited $displayName';
            case 'knock':
              return '$senderName knocked';
            default:
              return '$senderName membership changed: $membership';
          }

        case 'm.room.name':
          final newName = event.content['name']?.toString() ?? '';
          if (newName.isEmpty) {
            return '$senderName removed the room name';
          }
          return '$senderName changed the room name to "$newName"';

        case 'm.room.topic':
          final newTopic = event.content['topic']?.toString() ?? '';
          if (newTopic.isEmpty) {
            return '$senderName removed the room topic';
          }
          return '$senderName changed the topic to "$newTopic"';

        case 'm.room.avatar':
          final hasUrl = event.content['url'] != null ||
              event.content['avatar_url'] != null;
          if (hasUrl) {
            return '$senderName changed the room avatar';
          }
          return '$senderName removed the room avatar';

        case 'm.room.create':
          final creator = event.content['creator']?.toString() ?? senderName;
          return '$creator created this room';

        case 'm.room.encryption':
          return '$senderName enabled encryption';

        case 'm.room.pinned_events':
          final pinned = event.content['pinned'] is List
              ? (event.content['pinned'] as List).length
              : 0;
          if (pinned == 0) {
            return '$senderName unpinned all messages';
          }
          return '$senderName pinned $pinned message${pinned == 1 ? "" : "s"}';

        case 'm.room.canonical_alias':
          final alias = event.content['alias']?.toString() ?? '';
          if (alias.isEmpty) {
            return '$senderName removed the main address';
          }
          return '$senderName set the main address to $alias';

        case 'm.room.power_levels':
          return '$senderName changed the power levels';

        case 'm.room.tombstone':
          final newRoom = event.content['replacement_room']?.toString() ?? '';
          if (newRoom.isNotEmpty) {
            return '$senderName upgraded the room';
          }
          return '$senderName shut down the room';

        default:
          return '${event.type} changed by $senderName';
      }
    } catch (_) {
      return '${event.type} changed by $senderName';
    }
  }
}
