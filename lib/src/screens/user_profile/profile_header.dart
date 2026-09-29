// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.client,
    required this.avatarUri,
    required this.displayName,
    required this.userId,
    required this.presence,
    required this.scheme,
    required this.l10n,
  });

  final Client client;
  final Uri? avatarUri;
  final String displayName;
  final String userId;
  final CachedPresence? presence;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  String _formatLastSeen(BuildContext context, CachedPresence presence) {
    final ts = presence.lastActiveTimestamp;
    if (ts == null) return '';
    final timeStr = ts.relativeTimeShort(context);
    return switch (presence.presence) {
      PresenceType.online => l10n.activeAgo(timeStr),
      _ => l10n.lastSeenAgo(timeStr),
    };
  }

  @override
  Widget build(BuildContext context) {
    final presenceLabel = switch (presence?.presence) {
      PresenceType.online => l10n.presenceOnline,
      PresenceType.offline => l10n.presenceOffline,
      PresenceType.unavailable => l10n.presenceUnavailable,
      null => null,
    };
    final presenceColor = switch (presence?.presence) {
      PresenceType.online => const Color(0xFF2ECC71),
      PresenceType.unavailable => const Color(0xFFF39C12),
      PresenceType.offline => scheme.onSurfaceVariant,
      _ => scheme.onSurfaceVariant,
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              children: [
                AvatarFromUriOrFallbackImage(
                  client: client,
                  avatarUri: avatarUri,
                  radius: 44,
                ),
                if (presenceLabel != null)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: presenceColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.surface,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Display name
          Text(
            displayName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Matrix ID
          GestureDetector(
            onLongPress: () {
              // TODO: copy to clipboard
            },
            child: Text(
              userId,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Presence badge
          if (presenceLabel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: presenceColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: presenceColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    presenceLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: presenceColor,
                    ),
                  ),
                ],
              ),
            ),
            // Last seen / active time
            if (presence!.lastActiveTimestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatLastSeen(context, presence!),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
