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
import 'package:moonrelay/src/helpers/date_time_extension.dart';

/// Renders a Matrix state event as a centred, muted timeline item.
///
/// The description focuses on the event type and includes the user display
/// name for membership changes (e.g. "Alice joined").  Optionally displays
/// the event timestamp to the right of the description.
class StateEvents extends StatelessWidget {
  const StateEvents({
    super.key,
    required this.event,
    this.time,
    this.showTimestamp = true,
  });

  /// The state event to render.
  final Event event;

  /// An optional explicit timestamp.  Defaults to [event.originServerTs].
  final DateTime? time;

  /// Whether to show a formatted timestamp next to the description.
  final bool showTimestamp;

  DateTime get _effectiveTime => time ?? event.originServerTs;

  @override
  Widget build(BuildContext context) {
    final mutedColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    final description = _description(event.type);
    final timeStr =
        showTimestamp ? '  ${_effectiveTime.localizedTimeShort(context)}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Center(
        child: Text(
          '$description$timeStr',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: mutedColor,
          ),
        ),
      ),
    );
  }

  /// Builds a description for common state event types, including the
  /// user display name for membership changes.
  String _description(String type) {
    try {
      switch (type) {
        case 'm.room.member':
          final membership = event.content['membership']?.toString() ?? '';
          final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
          switch (membership) {
            case 'join':
              return '$senderName joined';
            case 'leave':
              return '$senderName left';
            case 'ban':
              final targetDisplayName =
                  event.content['displayname']?.toString();
              if (targetDisplayName != null &&
                  targetDisplayName != senderName) {
                return '$senderName banned $targetDisplayName';
              }
              return '$senderName banned';
            case 'invite':
              final invited =
                  event.content['displayname']?.toString() ?? 'a user';
              return '$senderName invited $invited';
            case 'knock':
              return '$senderName knocked';
            default:
              return '$senderName membership changed: $membership';
          }
        case 'm.room.name':
          return 'Room name changed';
        case 'm.room.topic':
          return 'Room topic changed';
        case 'm.room.avatar':
          return 'Room avatar changed';
        case 'm.room.create':
          return 'Room created';
        case 'm.room.encryption':
          return 'Encryption enabled';
        case 'm.room.pinned_events':
          return 'Pinned messages changed';
        case 'm.room.canonical_alias':
          return 'Main address changed';
        case 'm.room.power_levels':
          return 'Power levels changed';
        case 'm.room.tombstone':
          return 'Room upgraded';
        default:
          return type;
      }
    } catch (_) {
      return type;
    }
  }
}
