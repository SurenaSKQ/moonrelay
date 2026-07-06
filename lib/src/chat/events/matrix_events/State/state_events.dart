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

/// Renders a Matrix state event as a centred timeline item.
///
/// Membership changes (join, leave, kick, ban, invite, knock) are shown with
/// a leading icon and a colour that reflects the action type.  Moderation
/// actions (kick, ban) are visually distinct from normal joins/leaves and
/// always include the target user's display name.
///
/// Other state events (room name, topic, etc.) are shown as muted text.
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
    final cs = Theme.of(context).colorScheme;
    final mutedColor = cs.onSurface.withValues(alpha: 0.5);

    final (icon, color, description) = _decoratedDescription(context);
    final effectiveColor = color ?? mutedColor;

    final timeStr =
        showTimestamp ? '  ${_effectiveTime.localizedTimeShort(context)}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: effectiveColor),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                '$description$timeStr',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: effectiveColor,
                  fontWeight: color != null ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a description for common state event types and returns
  /// an optional icon + colour for visual distinction.
  ///
  /// Returns a tuple of `(IconData?, Color?, String)`.
  (IconData?, Color?, String) _decoratedDescription(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    try {
      switch (event.type) {
        case 'm.room.member':
          return _describeMembership(context, l10n);
        case 'm.room.name':
          return (Icons.edit_outlined, null, l10n.stateRoomNameChanged);
        case 'm.room.topic':
          return (Icons.subject_outlined, null, l10n.stateRoomTopicChanged);
        case 'm.room.avatar':
          return (Icons.photo_outlined, null, l10n.stateRoomAvatarChanged);
        case 'm.room.create':
          return (null, null, l10n.stateRoomCreated);
        case 'm.room.encryption':
          return (Icons.lock_outlined, null, l10n.stateEncryptionEnabled);
        case 'm.room.pinned_events':
          return (Icons.push_pin_outlined, null,
              l10n.statePinnedMessagesChanged);
        case 'm.room.canonical_alias':
          return (Icons.link_outlined, null, l10n.stateMainAddressChanged);
        case 'm.room.power_levels':
          return (Icons.shield_outlined, null, l10n.statePowerLevelsChanged);
        case 'm.room.tombstone':
          return (Icons.upgrade_outlined, null, l10n.stateRoomUpgraded);
        case 'm.key.verification.request':
          final reqSenderName =
              event.senderFromMemoryOrFallback.calcDisplayname();
          return (Icons.verified_user_outlined, null,
              l10n.stateVerificationRequest(reqSenderName));
        case 'm.key.verification.start':
          return (Icons.verified_user_outlined, null,
              l10n.stateVerificationStart);
        case 'm.key.verification.done':
          return (Icons.verified_outlined, null, l10n.stateVerificationDone);
        case 'm.key.verification.cancel':
          return (Icons.cancel_outlined, null, l10n.stateVerificationCancel);
        case String t when t.startsWith('m.key.verification.'):
          return (Icons.verified_user_outlined, null,
              l10n.stateVerificationEvent);
        default:
          return (null, null, event.type);
      }
    } catch (_) {
      return (null, null, event.type);
    }
  }

  /// Resolves membership changes with full context: detects kicks and always
  /// shows the target user for moderation actions.
  (IconData?, Color?, String) _describeMembership(
      BuildContext context, AppLocalizations l10n) {
    final membership = event.content['membership']?.toString() ?? '';
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();

    switch (membership) {
      case 'join':
        return (Icons.login_rounded, null, l10n.stateJoined(senderName));

      case 'leave':
        // A kick is a 'leave' where the sender differs from the state key =
        // the moderator sent the leave on behalf of the target.
        if (event.stateKey != null && event.stateKey != event.senderId) {
          final targetName = _targetDisplayName(context);
          return (Icons.person_remove_outlined,
              Theme.of(context).colorScheme.tertiary,
              l10n.stateKicked(senderName, targetName));
        }
        return (Icons.logout_rounded, null, l10n.stateLeft(senderName));

      case 'ban':
        final targetDisplayName = _targetDisplayName(context);
        if (targetDisplayName != senderName) {
          return (Icons.block_outlined,
              Theme.of(context).colorScheme.error,
              l10n.stateBanned(senderName, targetDisplayName));
        }
        return (Icons.block_outlined,
            Theme.of(context).colorScheme.error,
            l10n.stateBannedSimple(senderName));

      case 'invite':
        final invited = event.content['displayname']?.toString() ?? 'a user';
        return (Icons.person_add_outlined, null,
            l10n.stateInvited(senderName, invited));

      case 'knock':
        return (Icons.door_front_door_outlined, null,
            l10n.stateKnocked(senderName));

      default:
        return (null, null,
            l10n.stateMembershipChanged(senderName, membership));
    }
  }

  /// Resolves the target user's display name for moderation events.
  ///
  /// For kicks and bans, the `stateKey` is the Matrix ID of the affected
  /// user.  We first try the `displayname` field in the event content
  /// (which the homeserver includes), then fall back to a display name
  /// lookup from the room's member list, and finally use the Matrix ID.
  String _targetDisplayName(BuildContext context) {
    // Prefer the displayname from the event content (most reliable).
    final contentName = event.content['displayname']?.toString();
    if (contentName != null && contentName.isNotEmpty) return contentName;

    // Try to look up the user by state key in the room's member list.
    if (event.stateKey != null) {
      try {
        final user =
            event.room.unsafeGetUserFromMemoryOrFallback(event.stateKey!);
        final displayName = user.displayName;
        if (displayName != null && displayName.isNotEmpty) return displayName;
        return event.stateKey!;
      } catch (_) {
        // Fall through to the Matrix ID fallback.
      }
    }

    // Fallback: use the raw Matrix ID.
    return event.stateKey ?? 'someone';
  }
}
