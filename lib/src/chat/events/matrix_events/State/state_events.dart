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
import 'package:moonrelay/src/localization/app_localizations.dart';

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

    final description = _description(event.type, context);
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
  String _description(String type, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    try {
      switch (type) {
        case 'm.room.member':
          final membership = event.content['membership']?.toString() ?? '';
          final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
          switch (membership) {
            case 'join':
              return l10n.stateJoined(senderName);
            case 'leave':
              return l10n.stateLeft(senderName);
            case 'ban':
              final targetDisplayName =
                  event.content['displayname']?.toString();
              if (targetDisplayName != null &&
                  targetDisplayName != senderName) {
                return l10n.stateBanned(senderName, targetDisplayName);
              }
              return l10n.stateBannedSimple(senderName);
            case 'invite':
              final invited =
                  event.content['displayname']?.toString() ?? 'a user';
              return l10n.stateInvited(senderName, invited);
            case 'knock':
              return l10n.stateKnocked(senderName);
            default:
              return l10n.stateMembershipChanged(senderName, membership);
          }
        case 'm.room.name':
          return l10n.stateRoomNameChanged;
        case 'm.room.topic':
          return l10n.stateRoomTopicChanged;
        case 'm.room.avatar':
          return l10n.stateRoomAvatarChanged;
        case 'm.room.create':
          return l10n.stateRoomCreated;
        case 'm.room.encryption':
          return l10n.stateEncryptionEnabled;
        case 'm.room.pinned_events':
          return l10n.statePinnedMessagesChanged;
        case 'm.room.canonical_alias':
          return l10n.stateMainAddressChanged;
        case 'm.room.power_levels':
          return l10n.statePowerLevelsChanged;
        case 'm.room.tombstone':
          return l10n.stateRoomUpgraded;
        default:
          return type;
      }
    } catch (_) {
      return type;
    }
  }
}
